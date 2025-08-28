# Value-at-Risk Backtesting Analysis
# This script implements comprehensive VaR calculation and backtesting procedures
# for GARCH-family models to assess risk measurement accuracy and model validation

set.seed(123)  # Ensure reproducibility

# Load required libraries for VaR analysis and statistical testing
library(openxlsx)
library(quantmod)
library(tseries)
library(rugarch)
library(xts)
library(PerformanceAnalytics)
library(FinTS)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(forecast)

cat("Starting Value-at-Risk Backtesting Analysis...\n")

# Data Import and Preprocessing
# Load financial time series data and prepare for VaR analysis

# Load price data and convert to proper time series format
raw_price_data <- read.csv("./data/processed/raw (FX + EQ).csv", row.names = 1)
raw_price_data$Date <- lubridate::ymd(rownames(raw_price_data))
rownames(raw_price_data) <- NULL
raw_price_data <- raw_price_data %>% dplyr::select(Date, everything())

# Extract time index and price matrix for processing
date_index <- raw_price_data$Date
price_data_matrix <- raw_price_data[, !(names(raw_price_data) %in% "Date")]

# Define asset tickers for equity and foreign exchange instruments
equity_tickers <- c("NVDA", "MSFT", "PG", "CAT", "WMT", "AMZN")
fx_names <- c("EURUSD", "GBPUSD", "GBPCNY", "USDZAR", "GBPZAR", "EURZAR")

# Convert price series to XTS objects for time series analysis
equity_xts <- lapply(equity_tickers, function(ticker) {
  xts(price_data_matrix[[ticker]], order.by = date_index)
})
names(equity_xts) <- equity_tickers

fx_xts <- lapply(fx_names, function(ticker) {
  xts(price_data_matrix[[ticker]], order.by = date_index)
})
names(fx_xts) <- fx_names

# Calculate log returns for volatility and risk modeling
equity_returns <- lapply(equity_xts, function(x) CalculateReturns(x)[-1, ])
fx_returns <- lapply(fx_xts, function(x) diff(log(x))[-1, ])

# Model Specifications and VaR Parameters
# Define GARCH model specifications and VaR confidence levels for risk assessment

generate_spec <- function(model, dist = "sstd", submodel = NULL) {
  # Create GARCH model specification for VaR calculation
  # Uses ARMA(0,0) mean model and GARCH(1,1) variance model
  ugarchspec(
    mean.model = list(armaOrder = c(0,0)),
    variance.model = list(model = model, garchOrder = c(1,1), submodel = submodel),
    distribution.model = dist
  )
}

# Define GARCH model variants for comprehensive risk assessment
models <- list(
  sGARCH_norm = list(model = "sGARCH", dist = "norm"),      # Standard GARCH with normal errors
  sGARCH_sstd = list(model = "sGARCH", dist = "sstd"),      # Standard GARCH with skewed Student-t
  eGARCH = list(model = "eGARCH", dist = "sstd"),           # Exponential GARCH for asymmetric effects
  gjrGARCH = list(model = "gjrGARCH", dist = "sstd"),       # GJR-GARCH for leverage effects
  TGARCH = list(model = "fGARCH", dist = "sstd", submodel = "TGARCH")  # Threshold GARCH for regime effects
)

# Define confidence levels for VaR calculation (95% and 99% levels)
confidence_levels <- c(0.95, 0.99)

# VaR Calculation Functions
# Implement various VaR estimation methods for comprehensive risk assessment

calculate_historical_var <- function(returns, confidence_level) {
  # Calculate historical VaR using empirical quantiles
  # This method makes no distributional assumptions
  quantile(returns, 1 - confidence_level, na.rm = TRUE)
}

calculate_parametric_var <- function(returns, confidence_level) {
  # Calculate parametric VaR assuming normal distribution
  # Uses sample mean and standard deviation with normal quantiles
  mean_return <- mean(returns, na.rm = TRUE)
  std_return <- sd(returns, na.rm = TRUE)
  z_score <- qnorm(1 - confidence_level)
  mean_return + z_score * std_return
}

calculate_garch_var <- function(returns, model_spec, confidence_level) {
  # Calculate GARCH-based VaR using conditional volatility dynamics
  # Incorporates time-varying volatility for more accurate risk measurement
  tryCatch({
    # Fit GARCH model to capture volatility clustering
    fit <- ugarchfit(model_spec, data = returns, solver = "hybrid")
    
    # Extract conditional volatility estimates
    sigma <- sigma(fit)
    
    # Extract conditional mean estimates
    mu <- fitted(fit)
    
    # Calculate VaR using the fitted distribution
    if (fit@model$modeldesc$distribution == "norm") {
      z_score <- qnorm(1 - confidence_level)
    } else if (fit@model$modeldesc$distribution == "sstd") {
      z_score <- rugarch::qdist("sstd", 1 - confidence_level, 
                               mu = 0, sigma = 1, 
                               skew = coef(fit)["skew"], 
                               shape = coef(fit)["shape"])
    } else {
      z_score <- qnorm(1 - confidence_level)  # fallback to normal
    }
    
    mu + z_score * sigma
    
  }, error = function(e) {
    cat("Error in GARCH VaR calculation:", e$message, "\n")
    rep(NA, length(returns))
  })
}

#### Backtesting Functions ####

# Kupiec test for VaR backtesting
kupiec_test <- function(actual_returns, var_forecasts, confidence_level) {
  # Count violations
  violations <- sum(actual_returns < var_forecasts, na.rm = TRUE)
  total_obs <- sum(!is.na(var_forecasts))
  
  if (total_obs == 0) return(list(p_value = NA, test_stat = NA, violations = 0, total = 0))
  
  # Expected violation rate
  expected_rate <- 1 - confidence_level
  actual_rate <- violations / total_obs
  
  # Likelihood ratio test
  if (violations > 0 && violations < total_obs) {
    lr_stat <- -2 * log(((1 - expected_rate)^(total_obs - violations) * expected_rate^violations) /
                       ((1 - actual_rate)^(total_obs - violations) * actual_rate^violations))
    p_value <- 1 - pchisq(lr_stat, df = 1)
  } else {
    lr_stat <- NA
    p_value <- NA
  }
  
  list(
    p_value = p_value,
    test_stat = lr_stat,
    violations = violations,
    total = total_obs,
    violation_rate = actual_rate,
    expected_rate = expected_rate
  )
}

# Christoffersen test for independence of violations
christoffersen_test <- function(actual_returns, var_forecasts) {
  # Create violation series
  violations <- as.numeric(actual_returns < var_forecasts)
  
  # Remove NA values
  valid_violations <- violations[!is.na(violations)]
  
  if (length(valid_violations) < 10) {
    return(list(p_value = NA, test_stat = NA))
  }
  
  # Count transitions
  n00 <- sum(diff(valid_violations) == 0 & valid_violations[-length(valid_violations)] == 0)
  n01 <- sum(diff(valid_violations) == 1 & valid_violations[-length(valid_violations)] == 0)
  n10 <- sum(diff(valid_violations) == -1 & valid_violations[-length(valid_violations)] == 1)
  n11 <- sum(diff(valid_violations) == 0 & valid_violations[-length(valid_violations)] == 1)
  
  # Calculate probabilities
  p01 <- n01 / (n00 + n01)
  p11 <- n11 / (n10 + n11)
  p <- (n01 + n11) / (n00 + n01 + n10 + n11)
  
  # Likelihood ratio test
  if (p01 > 0 && p01 < 1 && p11 > 0 && p11 < 1 && p > 0 && p < 1) {
    lr_stat <- -2 * log(((1 - p)^(n00 + n10) * p^(n01 + n11)) /
                       ((1 - p01)^n00 * p01^n01 * (1 - p11)^n10 * p11^n11))
    p_value <- 1 - pchisq(lr_stat, df = 1)
  } else {
    lr_stat <- NA
    p_value <- NA
  }
  
  list(
    p_value = p_value,
    test_stat = lr_stat,
    p01 = p01,
    p11 = p11,
    p = p
  )
}

# Dynamic Quantile test
dynamic_quantile_test <- function(actual_returns, var_forecasts, lags = 4) {
  # Create violation series
  violations <- as.numeric(actual_returns < var_forecasts)
  
  # Remove NA values
  valid_violations <- violations[!is.na(violations)]
  
  if (length(valid_violations) < lags + 10) {
    return(list(p_value = NA, test_stat = NA))
  }
  
  # Create lagged variables
  y <- valid_violations[(lags + 1):length(valid_violations)]
  X <- matrix(1, nrow = length(y), ncol = lags + 1)
  
  for (i in 1:lags) {
    X[, i + 1] <- valid_violations[i:(length(valid_violations) - lags + i - 1)]
  }
  
  # Fit logistic regression
  tryCatch({
    model <- glm(y ~ X[, -1], family = binomial(link = "logit"))
    
    # Likelihood ratio test
    null_model <- glm(y ~ 1, family = binomial(link = "logit"))
    lr_stat <- deviance(null_model) - deviance(model)
    p_value <- 1 - pchisq(lr_stat, df = lags)
    
    list(
      p_value = p_value,
      test_stat = lr_stat,
      model = model
    )
  }, error = function(e) {
    list(p_value = NA, test_stat = NA)
  })
}

#### Perform VaR Analysis ####

perform_var_analysis <- function(returns_data, asset_name, asset_type) {
  cat("Performing VaR analysis for", asset_name, "(", asset_type, ")\n")
  
  # Remove any NA values
  clean_returns <- na.omit(returns_data)
  
  if (length(clean_returns) < 252) {  # At least one year of data
    cat("  Insufficient data for", asset_name, "\n")
    return(NULL)
  }
  
  # Split data: 80% for training, 20% for testing
  n <- length(clean_returns)
  train_size <- floor(0.8 * n)
  train_data <- clean_returns[1:train_size]
  test_data <- clean_returns[(train_size + 1):n]
  
  var_results <- list()
  
  # Test each model
  for (model_name in names(models)) {
    cat("  Testing", model_name, "...\n")
    
    model_results <- list()
    
    for (conf_level in confidence_levels) {
      # Calculate different VaR methods
      historical_var <- calculate_historical_var(train_data, conf_level)
      parametric_var <- calculate_parametric_var(train_data, conf_level)
      
      # GARCH VaR
      spec <- do.call(generate_spec, models[[model_name]])
      garch_var_train <- calculate_garch_var(train_data, spec, conf_level)
      garch_var_test <- calculate_garch_var(test_data, spec, conf_level)
      
      # Backtesting
      kupiec_hist <- kupiec_test(test_data, rep(historical_var, length(test_data)), conf_level)
      kupiec_param <- kupiec_test(test_data, rep(parametric_var, length(test_data)), conf_level)
      kupiec_garch <- kupiec_test(test_data, garch_var_test, conf_level)
      
      christ_hist <- christoffersen_test(test_data, rep(historical_var, length(test_data)))
      christ_param <- christoffersen_test(test_data, rep(parametric_var, length(test_data)))
      christ_garch <- christoffersen_test(test_data, garch_var_test)
      
      dq_hist <- dynamic_quantile_test(test_data, rep(historical_var, length(test_data)))
      dq_param <- dynamic_quantile_test(test_data, rep(parametric_var, length(test_data)))
      dq_garch <- dynamic_quantile_test(test_data, garch_var_test)
      
      model_results[[paste0("conf_", conf_level)]] <- list(
        historical = list(
          var = historical_var,
          kupiec = kupiec_hist,
          christoffersen = christ_hist,
          dq = dq_hist
        ),
        parametric = list(
          var = parametric_var,
          kupiec = kupiec_param,
          christoffersen = christ_param,
          dq = dq_param
        ),
        garch = list(
          var_train = garch_var_train,
          var_test = garch_var_test,
          kupiec = kupiec_garch,
          christoffersen = christ_garch,
          dq = dq_garch
        )
      )
    }
    
    var_results[[model_name]] <- model_results
  }
  
  return(var_results)
}

# Create output directories
output_dir <- "outputs/var_backtest/figures"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Process all assets
all_var_results <- list()

# Process equity assets
for (ticker in names(equity_returns)) {
  all_var_results[[ticker]] <- perform_var_analysis(equity_returns[[ticker]], ticker, "Equity")
}

# Process FX assets
for (fx in names(fx_returns)) {
  all_var_results[[fx]] <- perform_var_analysis(fx_returns[[fx]], fx, "FX")
}

#### Create Summary Tables ####

create_var_summary_table <- function(var_results_list) {
  summary_data <- data.frame()
  
  for (asset_name in names(var_results_list)) {
    if (is.null(var_results_list[[asset_name]])) next
    
    asset_results <- var_results_list[[asset_name]]
    
    for (model_name in names(asset_results)) {
      model_results <- asset_results[[model_name]]
      
      for (conf_name in names(model_results)) {
        conf_level <- as.numeric(strsplit(conf_name, "_")[[1]][2])
        conf_results <- model_results[[conf_name]]
        
        # Historical VaR results
        if (!is.null(conf_results$historical)) {
          summary_data <- rbind(summary_data, data.frame(
            Asset = asset_name,
            Model = paste0(model_name, "_Historical"),
            Confidence_Level = conf_level,
            VaR_Method = "Historical",
            Violations = conf_results$historical$kupiec$violations,
            Total_Obs = conf_results$historical$kupiec$total,
            Violation_Rate = conf_results$historical$kupiec$violation_rate,
            Expected_Rate = conf_results$historical$kupiec$expected_rate,
            Kupiec_PValue = conf_results$historical$kupiec$p_value,
            Christoffersen_PValue = conf_results$historical$christoffersen$p_value,
            DQ_PValue = conf_results$historical$dq$p_value
          ))
        }
        
        # Parametric VaR results
        if (!is.null(conf_results$parametric)) {
          summary_data <- rbind(summary_data, data.frame(
            Asset = asset_name,
            Model = paste0(model_name, "_Parametric"),
            Confidence_Level = conf_level,
            VaR_Method = "Parametric",
            Violations = conf_results$parametric$kupiec$violations,
            Total_Obs = conf_results$parametric$kupiec$total,
            Violation_Rate = conf_results$parametric$kupiec$violation_rate,
            Expected_Rate = conf_results$parametric$kupiec$expected_rate,
            Kupiec_PValue = conf_results$parametric$kupiec$p_value,
            Christoffersen_PValue = conf_results$parametric$christoffersen$p_value,
            DQ_PValue = conf_results$parametric$dq$p_value
          ))
        }
        
        # GARCH VaR results
        if (!is.null(conf_results$garch)) {
          summary_data <- rbind(summary_data, data.frame(
            Asset = asset_name,
            Model = paste0(model_name, "_GARCH"),
            Confidence_Level = conf_level,
            VaR_Method = "GARCH",
            Violations = conf_results$garch$kupiec$violations,
            Total_Obs = conf_results$garch$kupiec$total,
            Violation_Rate = conf_results$garch$kupiec$violation_rate,
            Expected_Rate = conf_results$garch$kupiec$expected_rate,
            Kupiec_PValue = conf_results$garch$kupiec$p_value,
            Christoffersen_PValue = conf_results$garch$christoffersen$p_value,
            DQ_PValue = conf_results$garch$dq$p_value
          ))
        }
      }
    }
  }
  
  return(summary_data)
}

# Create summary table
var_summary_table <- create_var_summary_table(all_var_results)

# Save results
output_table_dir <- "outputs/var_backtest/tables"
dir.create(output_table_dir, recursive = TRUE, showWarnings = FALSE)

write.csv(var_summary_table, paste0(output_table_dir, "/var_backtest_summary.csv"), row.names = FALSE)

#### Create Visualization Plots ####

# 1. Violation Rate Comparison
create_violation_rate_plot <- function(summary_table) {
  # Filter for GARCH models only
  garch_data <- summary_table[grepl("_GARCH$", summary_table$Model), ]
  
  p <- ggplot(garch_data, aes(x = Asset, y = Violation_Rate, fill = Model)) +
    geom_bar(stat = "identity", position = "dodge") +
    geom_hline(aes(yintercept = Expected_Rate), linetype = "dashed", color = "red") +
    facet_wrap(~Confidence_Level, scales = "free_y") +
    labs(title = "VaR Violation Rates by Model and Asset",
         x = "Asset", y = "Violation Rate", fill = "Model") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggsave(paste0(output_dir, "/violation_rates_comparison.png"), p, width = 12, height = 8, dpi = 300)
}

# 2. Backtest Results Heatmap
create_backtest_heatmap <- function(summary_table) {
  # Filter for GARCH models and 95% confidence level
  garch_95 <- summary_table[grepl("_GARCH$", summary_table$Model) & summary_table$Confidence_Level == 0.95, ]
  
  # Create heatmap data
  heatmap_data <- garch_95 %>%
    select(Asset, Model, Kupiec_PValue, Christoffersen_PValue, DQ_PValue) %>%
    gather(Test, PValue, Kupiec_PValue:DQ_PValue)
  
  p <- ggplot(heatmap_data, aes(x = Asset, y = Test, fill = PValue)) +
    geom_tile() +
    scale_fill_gradient2(low = "red", mid = "yellow", high = "green", 
                        midpoint = 0.05, limits = c(0, 0.1)) +
    labs(title = "VaR Backtest Results (95% Confidence Level)",
         x = "Asset", y = "Test", fill = "P-Value") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggsave(paste0(output_dir, "/backtest_results_heatmap.png"), p, width = 10, height = 6, dpi = 300)
}

# Generate plots
create_violation_rate_plot(var_summary_table)
create_backtest_heatmap(var_summary_table)

#### Model Performance Summary ####

# Calculate model performance metrics
model_performance <- var_summary_table %>%
  filter(grepl("_GARCH$", Model)) %>%
  group_by(Model, Confidence_Level) %>%
  summarise(
    Avg_Violation_Rate = mean(Violation_Rate, na.rm = TRUE),
    Avg_Kupiec_PValue = mean(Kupiec_PValue, na.rm = TRUE),
    Avg_Christoffersen_PValue = mean(Christoffersen_PValue, na.rm = TRUE),
    Avg_DQ_PValue = mean(DQ_PValue, na.rm = TRUE),
    Pass_Kupiec = sum(Kupiec_PValue > 0.05, na.rm = TRUE),
    Pass_Christoffersen = sum(Christoffersen_PValue > 0.05, na.rm = TRUE),
    Pass_DQ = sum(DQ_PValue > 0.05, na.rm = TRUE),
    Total_Assets = n(),
    .groups = 'drop'
  )

write.csv(model_performance, paste0(output_table_dir, "/model_performance_summary.csv"), row.names = FALSE)

#### Print Summary ####

cat("\n=== VAR BACKTESTING ANALYSIS SUMMARY ===\n")
cat("Total assets tested:", length(all_var_results), "\n")
cat("Models tested:", length(models), "\n")
cat("Confidence levels:", paste(confidence_levels, collapse = ", "), "\n")

cat("\n=== MODEL PERFORMANCE SUMMARY ===\n")
print(model_performance)

cat("\n=== BACKTEST RESULTS SUMMARY ===\n")
cat("Assets with valid GARCH models:", sum(!sapply(all_var_results, is.null)), "\n")
cat("Total VaR calculations:", nrow(var_summary_table), "\n")

cat("\nOutput files saved to:", output_dir, "\n")
cat("Summary tables saved to:", output_table_dir, "\n")

cat("\nVaR backtesting analysis complete!\n")

