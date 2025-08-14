# Stress Testing Script
# This script evaluates GARCH model performance under various stress scenarios
# including historical crises and hypothetical shocks

set.seed(123)

# Libraries
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

cat("Starting Stress Testing Analysis...\n")

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

#### Model Specifications ####

generate_spec <- function(model, dist = "sstd", submodel = NULL) {
  ugarchspec(
    mean.model = list(armaOrder = c(0,0)),
    variance.model = list(model = model, garchOrder = c(1,1), submodel = submodel),
    distribution.model = dist
  )
}

# Define models to test
models <- list(
  sGARCH_norm = list(model = "sGARCH", dist = "norm"),
  sGARCH_sstd = list(model = "sGARCH", dist = "sstd"),
  eGARCH = list(model = "eGARCH", dist = "sstd"),
  gjrGARCH = list(model = "gjrGARCH", dist = "sstd"),
  TGARCH = list(model = "fGARCH", dist = "sstd", submodel = "TGARCH")
)

#### Define Stress Scenarios ####

# Historical crisis periods
historical_crises <- list(
  financial_crisis_2008 = list(
    name = "2008 Financial Crisis",
    start_date = as.Date("2008-09-01"),
    end_date = as.Date("2009-03-31"),
    description = "Global financial crisis following Lehman Brothers collapse"
  ),
  covid_crisis_2020 = list(
    name = "2020 COVID-19 Crisis",
    start_date = as.Date("2020-02-15"),
    end_date = as.Date("2020-04-30"),
    description = "Market crash due to COVID-19 pandemic"
  ),
  dotcom_bubble_2000 = list(
    name = "2000 Dot-com Bubble",
    start_date = as.Date("2000-03-01"),
    end_date = as.Date("2000-12-31"),
    description = "Technology stock bubble burst"
  )
)

# Hypothetical stress scenarios
hypothetical_scenarios <- list(
  extreme_volatility = list(
    name = "Extreme Volatility Shock",
    shock_multiplier = 3.0,
    description = "3x increase in volatility"
  ),
  market_crash = list(
    name = "Market Crash Scenario",
    return_shock = -0.20,
    description = "20% negative return shock"
  ),
  volatility_persistence = list(
    name = "Volatility Persistence",
    persistence_multiplier = 2.0,
    description = "Doubled volatility persistence"
  )
)

#### Stress Testing Functions ####

# Calculate stress period statistics
calculate_stress_stats <- function(returns, start_date, end_date) {
  # Convert dates to match the data
  if (is.character(start_date)) start_date <- as.Date(start_date)
  if (is.character(end_date)) end_date <- as.Date(end_date)
  
  # Find the closest dates in the data
  all_dates <- index(returns)
  start_idx <- which.min(abs(all_dates - start_date))
  end_idx <- which.min(abs(all_dates - end_date))
  
  if (start_idx >= end_idx) {
    return(list(
      mean_return = NA,
      volatility = NA,
      max_drawdown = NA,
      var_95 = NA,
      var_99 = NA,
      skewness = NA,
      kurtosis = NA,
      n_observations = 0
    ))
  }
  
  stress_returns <- returns[start_idx:end_idx]
  
  list(
    mean_return = mean(stress_returns, na.rm = TRUE),
    volatility = sd(stress_returns, na.rm = TRUE),
    max_drawdown = maxDrawdown(stress_returns)[1],
    var_95 = quantile(stress_returns, 0.05, na.rm = TRUE),
    var_99 = quantile(stress_returns, 0.01, na.rm = TRUE),
    skewness = skewness(stress_returns, na.rm = TRUE),
    kurtosis = kurtosis(stress_returns, na.rm = TRUE),
    n_observations = length(stress_returns)
  )
}

# Test model stability under stress
test_model_stability <- function(returns, model_spec, stress_periods) {
  stability_results <- list()
  
  for (period_name in names(stress_periods)) {
    period <- stress_periods[[period_name]]
    
    # Calculate stress statistics
    stress_stats <- calculate_stress_stats(returns, period$start_date, period$end_date)
    
    if (stress_stats$n_observations < 10) {
      stability_results[[period_name]] <- list(
        convergence = FALSE,
        error = "Insufficient data"
      )
      next
    }
    
    # Try to fit model on stress period
    stress_returns <- returns[index(returns) >= period$start_date & index(returns) <= period$end_date]
    
    tryCatch({
      fit <- ugarchfit(model_spec, data = stress_returns, solver = "hybrid")
      
      # Check convergence
      convergence <- fit@fit$convergence == 0
      
      # Calculate model diagnostics
      residuals <- residuals(fit)
      standardized_residuals <- residuals / sigma(fit)
      
      # Ljung-Box test on standardized residuals
      lb_test <- Box.test(standardized_residuals, lag = 12, type = "Ljung-Box")
      
      # ARCH-LM test
      arch_test <- ArchTest(standardized_residuals, lags = 12)
      
      stability_results[[period_name]] <- list(
        convergence = convergence,
        stress_stats = stress_stats,
        model_fit = fit,
        lb_pvalue = lb_test$p.value,
        arch_pvalue = arch_test$p.value,
        aic = infocriteria(fit)[1],
        bic = infocriteria(fit)[2],
        log_likelihood = fit@fit$LLH
      )
      
    }, error = function(e) {
      stability_results[[period_name]] <<- list(
        convergence = FALSE,
        error = e$message
      )
    })
  }
  
  return(stability_results)
}

# Apply hypothetical shocks
apply_hypothetical_shocks <- function(returns, model_spec, scenarios) {
  shock_results <- list()
  
  # Fit model on full data first
  tryCatch({
    full_fit <- ugarchfit(model_spec, data = returns, solver = "hybrid")
    
    for (scenario_name in names(scenarios)) {
      scenario <- scenarios[[scenario_name]]
      
      # Apply different types of shocks
      if (scenario_name == "extreme_volatility") {
        # Increase volatility by multiplier
        original_sigma <- sigma(full_fit)
        shocked_sigma <- original_sigma * scenario$shock_multiplier
        
        # Calculate shocked returns (approximate)
        shocked_returns <- returns * scenario$shock_multiplier
        
        # Try to refit model
        tryCatch({
          shocked_fit <- ugarchfit(model_spec, data = shocked_returns, solver = "hybrid")
          
          shock_results[[scenario_name]] <- list(
            success = TRUE,
            original_aic = infocriteria(full_fit)[1],
            shocked_aic = infocriteria(shocked_fit)[1],
            original_bic = infocriteria(full_fit)[2],
            shocked_bic = infocriteria(shocked_fit)[2],
            original_llh = full_fit@fit$LLH,
            shocked_llh = shocked_fit@fit$LLH
          )
        }, error = function(e) {
          shock_results[[scenario_name]] <<- list(
            success = FALSE,
            error = e$message
          )
        })
        
      } else if (scenario_name == "market_crash") {
        # Add negative return shock
        shocked_returns <- returns + scenario$return_shock
        
        tryCatch({
          shocked_fit <- ugarchfit(model_spec, data = shocked_returns, solver = "hybrid")
          
          shock_results[[scenario_name]] <- list(
            success = TRUE,
            original_aic = infocriteria(full_fit)[1],
            shocked_aic = infocriteria(shocked_fit)[1],
            original_bic = infocriteria(full_fit)[2],
            shocked_bic = infocriteria(shocked_fit)[2],
            original_llh = full_fit@fit$LLH,
            shocked_llh = shocked_fit@fit$LLH
          )
        }, error = function(e) {
          shock_results[[scenario_name]] <<- list(
            success = FALSE,
            error = e$message
          )
        })
        
      } else {
        # Default case
        shock_results[[scenario_name]] <- list(
          success = FALSE,
          error = "Scenario not implemented"
        )
      }
    }
    
  }, error = function(e) {
    for (scenario_name in names(scenarios)) {
      shock_results[[scenario_name]] <- list(
        success = FALSE,
        error = paste("Base model failed:", e$message)
      )
    }
  })
  
  return(shock_results)
}

#### Perform Stress Testing ####

perform_stress_testing <- function(returns_data, asset_name, asset_type) {
  cat("Performing stress testing for", asset_name, "(", asset_type, ")\n")
  
  # Remove any NA values
  clean_returns <- na.omit(returns_data)
  
  if (length(clean_returns) < 500) {  # Need sufficient data for stress testing
    cat("  Insufficient data for", asset_name, "\n")
    return(NULL)
  }
  
  stress_results <- list()
  
  # Test each model
  for (model_name in names(models)) {
    cat("  Testing", model_name, "...\n")
    
    spec <- do.call(generate_spec, models[[model_name]])
    
    # Historical crisis testing
    historical_results <- test_model_stability(clean_returns, spec, historical_crises)
    
    # Hypothetical scenario testing
    hypothetical_results <- apply_hypothetical_shocks(clean_returns, spec, hypothetical_scenarios)
    
    stress_results[[model_name]] <- list(
      historical = historical_results,
      hypothetical = hypothetical_results
    )
  }
  
  return(stress_results)
}

# Create output directories
output_dir <- "outputs/stress_tests/figures"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Process all assets
all_stress_results <- list()

# Process equity assets
for (ticker in names(equity_returns)) {
  all_stress_results[[ticker]] <- perform_stress_testing(equity_returns[[ticker]], ticker, "Equity")
}

# Process FX assets
for (fx in names(fx_returns)) {
  all_stress_results[[fx]] <- perform_stress_testing(fx_returns[[fx]], fx, "FX")
}

#### Create Summary Tables ####

create_stress_summary_table <- function(stress_results_list) {
  summary_data <- data.frame()
  
  for (asset_name in names(stress_results_list)) {
    if (is.null(stress_results_list[[asset_name]])) next
    
    asset_results <- stress_results_list[[asset_name]]
    
    for (model_name in names(asset_results)) {
      model_results <- asset_results[[model_name]]
      
      # Historical crisis results
      for (crisis_name in names(model_results$historical)) {
        crisis_result <- model_results$historical[[crisis_name]]
        
        if (!is.null(crisis_result$convergence)) {
          summary_data <- rbind(summary_data, data.frame(
            Asset = asset_name,
            Model = model_name,
            Scenario_Type = "Historical",
            Scenario_Name = crisis_name,
            Convergence = crisis_result$convergence,
            N_Observations = ifelse(!is.null(crisis_result$stress_stats), 
                                  crisis_result$stress_stats$n_observations, 0),
            Mean_Return = ifelse(!is.null(crisis_result$stress_stats), 
                               crisis_result$stress_stats$mean_return, NA),
            Volatility = ifelse(!is.null(crisis_result$stress_stats), 
                              crisis_result$stress_stats$volatility, NA),
            Max_Drawdown = ifelse(!is.null(crisis_result$stress_stats), 
                                crisis_result$stress_stats$max_drawdown, NA),
            VaR_95 = ifelse(!is.null(crisis_result$stress_stats), 
                          crisis_result$stress_stats$var_95, NA),
            LB_PValue = ifelse(!is.null(crisis_result$lb_pvalue), 
                             crisis_result$lb_pvalue, NA),
            ARCH_PValue = ifelse(!is.null(crisis_result$arch_pvalue), 
                               crisis_result$arch_pvalue, NA),
            AIC = ifelse(!is.null(crisis_result$aic), crisis_result$aic, NA),
            BIC = ifelse(!is.null(crisis_result$bic), crisis_result$bic, NA),
            Log_Likelihood = ifelse(!is.null(crisis_result$log_likelihood), 
                                  crisis_result$log_likelihood, NA)
          ))
        }
      }
      
      # Hypothetical scenario results
      for (scenario_name in names(model_results$hypothetical)) {
        scenario_result <- model_results$hypothetical[[scenario_name]]
        
        summary_data <- rbind(summary_data, data.frame(
          Asset = asset_name,
          Model = model_name,
          Scenario_Type = "Hypothetical",
          Scenario_Name = scenario_name,
          Convergence = scenario_result$success,
          N_Observations = NA,
          Mean_Return = NA,
          Volatility = NA,
          Max_Drawdown = NA,
          VaR_95 = NA,
          LB_PValue = NA,
          ARCH_PValue = NA,
          AIC = ifelse(!is.null(scenario_result$shocked_aic), 
                      scenario_result$shocked_aic, NA),
          BIC = ifelse(!is.null(scenario_result$shocked_bic), 
                      scenario_result$shocked_bic, NA),
          Log_Likelihood = ifelse(!is.null(scenario_result$shocked_llh), 
                                scenario_result$shocked_llh, NA)
        ))
      }
    }
  }
  
  return(summary_data)
}

# Create summary table
stress_summary_table <- create_stress_summary_table(all_stress_results)

# Save results
output_table_dir <- "outputs/stress_tests/tables"
dir.create(output_table_dir, recursive = TRUE, showWarnings = FALSE)

write.csv(stress_summary_table, paste0(output_table_dir, "/stress_test_summary.csv"), row.names = FALSE)

#### Create Visualization Plots ####

# 1. Model Convergence Under Stress
create_convergence_plot <- function(summary_table) {
  # Filter for historical scenarios
  historical_data <- summary_table[summary_table$Scenario_Type == "Historical", ]
  
  # Calculate convergence rates
  convergence_summary <- historical_data %>%
    group_by(Model, Scenario_Name) %>%
    summarise(
      Convergence_Rate = mean(Convergence, na.rm = TRUE),
      .groups = 'drop'
    )
  
  p <- ggplot(convergence_summary, aes(x = Model, y = Convergence_Rate, fill = Scenario_Name)) +
    geom_bar(stat = "identity", position = "dodge") +
    labs(title = "Model Convergence Under Historical Stress Scenarios",
         x = "Model", y = "Convergence Rate", fill = "Stress Scenario") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggsave(paste0(output_dir, "/model_convergence_stress.png"), p, width = 10, height = 6, dpi = 300)
}

# 2. Volatility Comparison Under Stress
create_volatility_comparison <- function(summary_table) {
  # Filter for historical scenarios with valid volatility data
  historical_data <- summary_table[summary_table$Scenario_Type == "Historical" & 
                                   !is.na(summary_table$Volatility), ]
  
  p <- ggplot(historical_data, aes(x = Asset, y = Volatility, fill = Model)) +
    geom_bar(stat = "identity", position = "dodge") +
    facet_wrap(~Scenario_Name, scales = "free_y") +
    labs(title = "Volatility Under Historical Stress Scenarios",
         x = "Asset", y = "Volatility", fill = "Model") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggsave(paste0(output_dir, "/volatility_stress_comparison.png"), p, width = 12, height = 8, dpi = 300)
}

# 3. Model Performance Heatmap
create_performance_heatmap <- function(summary_table) {
  # Calculate average AIC across scenarios
  performance_data <- summary_table %>%
    filter(!is.na(AIC)) %>%
    group_by(Model, Scenario_Type) %>%
    summarise(
      Avg_AIC = mean(AIC, na.rm = TRUE),
      .groups = 'drop'
    )
  
  p <- ggplot(performance_data, aes(x = Model, y = Scenario_Type, fill = Avg_AIC)) +
    geom_tile() +
    scale_fill_gradient2(low = "green", mid = "yellow", high = "red", 
                        midpoint = median(performance_data$Avg_AIC, na.rm = TRUE)) +
    labs(title = "Model Performance Under Stress (Average AIC)",
         x = "Model", y = "Scenario Type", fill = "AIC") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggsave(paste0(output_dir, "/model_performance_heatmap.png"), p, width = 10, height = 6, dpi = 300)
}

# Generate plots
create_convergence_plot(stress_summary_table)
create_volatility_comparison(stress_summary_table)
create_performance_heatmap(stress_summary_table)

#### Model Robustness Analysis ####

# Calculate model robustness scores
model_robustness <- stress_summary_table %>%
  group_by(Model) %>%
  summarise(
    Convergence_Rate = mean(Convergence, na.rm = TRUE),
    Avg_AIC = mean(AIC, na.rm = TRUE),
    Avg_BIC = mean(BIC, na.rm = TRUE),
    Avg_Log_Likelihood = mean(Log_Likelihood, na.rm = TRUE),
    Pass_LB_Test = sum(LB_PValue > 0.05, na.rm = TRUE),
    Pass_ARCH_Test = sum(ARCH_PValue > 0.05, na.rm = TRUE),
    Total_Tests = n(),
    .groups = 'drop'
  ) %>%
  mutate(
    Robustness_Score = (Convergence_Rate + 
                       (Pass_LB_Test + Pass_ARCH_Test) / (2 * Total_Tests)) / 2
  ) %>%
  arrange(desc(Robustness_Score))

write.csv(model_robustness, paste0(output_table_dir, "/model_robustness_scores.csv"), row.names = FALSE)

#### Print Summary ####

cat("\n=== STRESS TESTING ANALYSIS SUMMARY ===\n")
cat("Total assets tested:", length(all_stress_results), "\n")
cat("Models tested:", length(models), "\n")
cat("Historical scenarios:", length(historical_crises), "\n")
cat("Hypothetical scenarios:", length(hypothetical_scenarios), "\n")

cat("\n=== MODEL ROBUSTNESS RANKING ===\n")
print(model_robustness)

cat("\n=== STRESS TEST RESULTS SUMMARY ===\n")
cat("Assets with valid stress tests:", sum(!sapply(all_stress_results, is.null)), "\n")
cat("Total stress test scenarios:", nrow(stress_summary_table), "\n")
cat("Successful model fits:", sum(stress_summary_table$Convergence, na.rm = TRUE), "\n")

cat("\nOutput files saved to:", output_dir, "\n")
cat("Summary tables saved to:", output_table_dir, "\n")

cat("\nStress testing analysis complete!\n")

