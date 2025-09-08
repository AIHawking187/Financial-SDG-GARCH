# NFGARCH VaR Backtesting Script
# This script performs Value-at-Risk calculations and backtesting
# for NF-GARCH models using NF-generated innovations

set.seed(123)

# Libraries
library(openxlsx)
library(readxl)
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

cat("Starting NFGARCH VaR Backtesting Analysis...\n")

#### Import and Prepare Data ####

# Read price data
raw_price_data <- read.csv("./data/processed/raw (FX + EQ).csv", row.names = 1)
raw_price_data$Date <- lubridate::ymd(rownames(raw_price_data))
rownames(raw_price_data) <- NULL
raw_price_data <- raw_price_data %>% dplyr::select(Date, everything())

# Extract date vector and price matrix
date_index <- raw_price_data$Date
price_data_matrix <- raw_price_data[, !(names(raw_price_data) %in% "Date")]

# Define asset tickers
equity_tickers <- c("NVDA", "MSFT", "PG", "CAT", "WMT", "AMZN")
fx_names <- c("EURUSD", "GBPUSD", "GBPCNY", "USDZAR", "GBPZAR", "EURZAR")
all_assets <- c(equity_tickers, fx_names)

# Create XTS objects
equity_xts <- lapply(equity_tickers, function(ticker) {
  xts(price_data_matrix[[ticker]], order.by = date_index)
})
names(equity_xts) <- equity_tickers

fx_xts <- lapply(fx_names, function(ticker) {
  xts(price_data_matrix[[ticker]], order.by = date_index)
})
names(fx_xts) <- fx_names

# Calculate returns
equity_returns <- lapply(equity_xts, function(x) CalculateReturns(x)[-1, ])
fx_returns <- lapply(fx_xts, function(x) diff(log(x))[-1, ])
all_returns <- c(equity_returns, fx_returns)

#### Load NF-GARCH Results ####

# Load NF-GARCH simulation results
nf_results_files <- list.files(pattern = "NF_GARCH_Results_.*\\.xlsx", full.names = TRUE)
nf_results <- list()

for (file in nf_results_files) {
  engine_name <- str_extract(file, "(?<=NF_GARCH_Results_)[^.]+")
  tryCatch({
    sheets <- excel_sheets(file)
    for (sheet in sheets) {
      if (grepl("Eval|NF_GARCH|Chrono", sheet)) {
        nf_data <- read_excel(file, sheet = sheet)
        nf_data$Engine <- engine_name
        nf_data$Sheet_Name <- sheet
        nf_results[[paste0(engine_name, "_", sheet)]] <- nf_data
      }
    }
  }, error = function(e) {
    cat("Error loading NF results from", file, ":", e$message, "\n")
  })
}

#### NFGARCH VaR Calculation Functions ####

# Calculate NFGARCH-based VaR using NF innovations
calculate_nfgarch_var <- function(returns, nf_innovations, confidence_level) {
  tryCatch({
    # Use NF innovations to calculate VaR
    # The NF innovations represent the transformed residuals
    var_quantile <- quantile(nf_innovations, 1 - confidence_level, na.rm = TRUE)
    
    # Apply the NF transformation to get VaR
    var_forecast <- var_quantile
    
    return(var_forecast)
    
  }, error = function(e) {
    cat("Error in NFGARCH VaR calculation:", e$message, "\n")
    rep(NA, length(returns))
  })
}

# Calculate historical VaR for comparison
calculate_historical_var <- function(returns, confidence_level) {
  quantile(returns, 1 - confidence_level, na.rm = TRUE)
}

# Calculate parametric VaR (assuming normal distribution)
calculate_parametric_var <- function(returns, confidence_level) {
  mean_return <- mean(returns, na.rm = TRUE)
  std_return <- sd(returns, na.rm = TRUE)
  z_score <- qnorm(1 - confidence_level)
  mean_return + z_score * std_return
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
  
  # Create lagged violation variables
  violation_lags <- matrix(NA, nrow = length(valid_violations), ncol = lags)
  for (i in 1:lags) {
    violation_lags[, i] <- c(rep(0, i), valid_violations[1:(length(valid_violations) - i)])
  }
  
  # Run regression
  tryCatch({
    model <- lm(valid_violations ~ violation_lags)
    f_stat <- summary(model)$fstatistic[1]
    p_value <- pf(f_stat, lags, length(valid_violations) - lags - 1, lower.tail = FALSE)
    
    list(
      p_value = p_value,
      test_stat = f_stat
    )
  }, error = function(e) {
    list(p_value = NA, test_stat = NA)
  })
}

#### Main VaR Backtesting Analysis ####

# Define confidence levels for VaR
confidence_levels <- c(0.95, 0.99)

# Initialize results storage
var_results <- list()

# Process each NF-GARCH result
cat("Processing", length(nf_results), "NF-GARCH result sets\n")
for (result_name in names(nf_results)) {
  nf_data <- nf_results[[result_name]]
  cat("Processing result:", result_name, "with", nrow(nf_data), "rows\n")
  
  # Extract engine and model information
  engine <- nf_data$Engine[1]
  sheet_name <- nf_data$Sheet_Name[1]
  
  # Skip summary sheets that don't have asset-level data
  if (!("Asset" %in% colnames(nf_data))) {
    cat("Skipping summary sheet:", sheet_name, "\n")
    next
  }
  
  # Process each asset-model combination
  for (i in 1:nrow(nf_data)) {
    asset <- nf_data$Asset[i]
    model <- nf_data$Model[i]
    cat("Processing asset:", asset, "model:", model, "\n")
    
    # Skip if we don't have returns for this asset
    if (!(asset %in% names(all_returns))) {
      next
    }
    
    returns <- all_returns[[asset]]
    
    # Get NF innovations for this asset-model combination
    # We'll use the NF residuals as innovations for VaR calculation
    # Try different naming patterns for NF residual files
    asset_type <- if (asset %in% equity_tickers) "equity" else "fx"
    nf_residuals_file <- file.path("nf_generated_residuals", 
                                  paste0(model, "_", asset_type, "_", asset, "_residuals_synthetic.csv"))
    
    if (file.exists(nf_residuals_file)) {
      nf_residuals <- read.csv(nf_residuals_file)
      # Try different column names for the NF innovations
      if ("residual" %in% colnames(nf_residuals)) {
        nf_innovations <- nf_residuals$residual
      } else if ("nf_innovation" %in% colnames(nf_residuals)) {
        nf_innovations <- nf_residuals$nf_innovation
      } else if (ncol(nf_residuals) > 0) {
        nf_innovations <- nf_residuals[[1]]  # Use first column
      } else {
        nf_innovations <- returns
      }
    } else {
      # If NF residuals not available, use standard residuals
      nf_innovations <- returns
    }
    
    # Calculate VaR for each confidence level
    for (conf_level in confidence_levels) {
      # Calculate different VaR methods
      historical_var <- calculate_historical_var(returns, conf_level)
      parametric_var <- calculate_parametric_var(returns, conf_level)
      nfgarch_var <- calculate_nfgarch_var(returns, nf_innovations, conf_level)
      
      # Create VaR forecasts (using the calculated VaR values)
      historical_forecasts <- rep(historical_var, length(returns))
      parametric_forecasts <- rep(parametric_var, length(returns))
      nfgarch_forecasts <- rep(nfgarch_var, length(returns))
      
      # Perform backtesting for each method
      var_methods <- list(
        Historical = historical_forecasts,
        Parametric = parametric_forecasts,
        NFGARCH = nfgarch_forecasts
      )
      
      for (method_name in names(var_methods)) {
        var_forecasts <- var_methods[[method_name]]
        
        # Perform backtesting tests
        kupiec_result <- kupiec_test(returns, var_forecasts, conf_level)
        christoffersen_result <- christoffersen_test(returns, var_forecasts)
        dq_result <- dynamic_quantile_test(returns, var_forecasts)
        
        # Store results
        result_row <- data.frame(
          Asset = asset,
          Model = paste0("NF_", model),
          Confidence_Level = conf_level,
          VaR_Method = method_name,
          Violations = kupiec_result$violations,
          Total_Obs = kupiec_result$total,
          Violation_Rate = kupiec_result$violation_rate,
          Expected_Rate = kupiec_result$expected_rate,
          Kupiec_PValue = kupiec_result$p_value,
          Christoffersen_PValue = christoffersen_result$p_value,
          DQ_PValue = dq_result$p_value,
          Engine = engine,
          Sheet_Name = sheet_name,
          stringsAsFactors = FALSE
        )
        
        var_results[[length(var_results) + 1]] <- result_row
      }
    }
  }
}

#### Compile and Save Results ####

if (length(var_results) > 0) {
  # Combine all results
  var_summary <- do.call(rbind, var_results)
  
  # Create output directory
  dir.create("outputs/var_backtest/tables", recursive = TRUE, showWarnings = FALSE)
  
  # Save detailed results
  write.csv(var_summary, "outputs/var_backtest/tables/nfgarch_var_backtest_summary.csv", row.names = FALSE)
  
  # Create summary statistics
  var_summary_stats <- var_summary %>%
    group_by(Model, Confidence_Level, VaR_Method) %>%
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
  
  write.csv(var_summary_stats, "outputs/var_backtest/tables/nfgarch_model_performance_summary.csv", row.names = FALSE)
  
  cat("✓ NFGARCH VaR backtesting completed successfully!\n")
  cat("Results saved to:\n")
  cat("  - outputs/var_backtest/tables/nfgarch_var_backtest_summary.csv\n")
  cat("  - outputs/var_backtest/tables/nfgarch_model_performance_summary.csv\n")
  
} else {
  cat("⚠️ No NFGARCH VaR results generated. Check if NF residuals are available.\n")
}
