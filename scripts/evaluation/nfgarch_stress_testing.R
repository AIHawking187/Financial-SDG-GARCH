# NFGARCH Stress Testing Script
# This script performs stress testing on NF-GARCH models
# under extreme market scenarios

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

cat("Starting NFGARCH Stress Testing Analysis...\n")

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

#### Stress Testing Scenarios ####

# Define stress scenarios
stress_scenarios <- list(
  market_crash = list(
    name = "Market Crash",
    description = "Extreme negative returns across all assets",
    return_shock = -0.10,  # 10% daily loss
    volatility_shock = 3.0,  # 3x volatility increase
    correlation_shock = 0.8   # High correlation
  ),
  volatility_spike = list(
    name = "Volatility Spike",
    description = "Sudden increase in market volatility",
    return_shock = 0.0,     # No mean change
    volatility_shock = 5.0,  # 5x volatility increase
    correlation_shock = 0.6   # Moderate correlation
  ),
  correlation_breakdown = list(
    name = "Correlation Breakdown",
    description = "Loss of diversification benefits",
    return_shock = -0.05,    # 5% daily loss
    volatility_shock = 2.0,  # 2x volatility increase
    correlation_shock = 0.9   # Very high correlation
  ),
  flash_crash = list(
    name = "Flash Crash",
    description = "Rapid price movements followed by recovery",
    return_shock = -0.15,    # 15% daily loss
    volatility_shock = 4.0,  # 4x volatility increase
    correlation_shock = 0.7   # High correlation
  ),
  black_swan = list(
    name = "Black Swan Event",
    description = "Extreme tail event with unprecedented losses",
    return_shock = -0.20,    # 20% daily loss
    volatility_shock = 6.0,  # 6x volatility increase
    correlation_shock = 0.95  # Very high correlation
  )
)

#### NFGARCH Stress Testing Functions ####

# Calculate stress scenario impact on NFGARCH models
calculate_stress_impact <- function(returns, nf_innovations, scenario) {
  tryCatch({
    # Apply stress scenario to returns
    stressed_returns <- returns * (1 + scenario$return_shock)
    
    # Apply volatility shock to NF innovations
    stressed_innovations <- nf_innovations * scenario$volatility_shock
    
    # Calculate stressed VaR
    stressed_var_95 <- quantile(stressed_innovations, 0.05, na.rm = TRUE)
    stressed_var_99 <- quantile(stressed_innovations, 0.01, na.rm = TRUE)
    
    # Calculate stressed volatility
    stressed_volatility <- sd(stressed_innovations, na.rm = TRUE)
    
    # Calculate maximum drawdown under stress
    cumulative_returns <- cumprod(1 + stressed_returns)
    running_max <- cummax(cumulative_returns)
    drawdown <- (cumulative_returns - running_max) / running_max
    max_drawdown <- min(drawdown, na.rm = TRUE)
    
    # Calculate stress test statistics
    stress_stats <- list(
      stressed_var_95 = stressed_var_95,
      stressed_var_99 = stressed_var_99,
      stressed_volatility = stressed_volatility,
      max_drawdown = max_drawdown,
      return_shock = scenario$return_shock,
      volatility_shock = scenario$volatility_shock,
      correlation_shock = scenario$correlation_shock
    )
    
    return(stress_stats)
    
  }, error = function(e) {
    cat("Error in stress impact calculation:", e$message, "\n")
    return(NULL)
  })
}

# Calculate model robustness score
calculate_robustness_score <- function(baseline_stats, stress_stats) {
  tryCatch({
    # Calculate percentage changes
    var_95_change <- abs((stress_stats$stressed_var_95 - baseline_stats$var_95) / baseline_stats$var_95)
    var_99_change <- abs((stress_stats$stressed_var_99 - baseline_stats$var_99) / baseline_stats$var_99)
    vol_change <- abs((stress_stats$stressed_volatility - baseline_stats$volatility) / baseline_stats$volatility)
    
    # Calculate robustness score (lower is better)
    robustness_score <- (var_95_change + var_99_change + vol_change) / 3
    
    return(robustness_score)
    
  }, error = function(e) {
    cat("Error in robustness score calculation:", e$message, "\n")
    return(NA)
  })
}

# Calculate baseline statistics
calculate_baseline_stats <- function(returns, nf_innovations) {
  tryCatch({
    baseline_var_95 <- quantile(nf_innovations, 0.05, na.rm = TRUE)
    baseline_var_99 <- quantile(nf_innovations, 0.01, na.rm = TRUE)
    baseline_volatility <- sd(nf_innovations, na.rm = TRUE)
    
    return(list(
      var_95 = baseline_var_95,
      var_99 = baseline_var_99,
      volatility = baseline_volatility
    ))
    
  }, error = function(e) {
    cat("Error in baseline stats calculation:", e$message, "\n")
    return(NULL)
  })
}

#### Main Stress Testing Analysis ####

# Initialize results storage
stress_results <- list()

# Process each NF-GARCH result
for (result_name in names(nf_results)) {
  nf_data <- nf_results[[result_name]]
  
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
    
    # Skip if we don't have returns for this asset
    if (!(asset %in% names(all_returns))) {
      next
    }
    
    returns <- all_returns[[asset]]
    
    # Get NF innovations for this asset-model combination
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
    
    # Calculate baseline statistics
    baseline_stats <- calculate_baseline_stats(returns, nf_innovations)
    
    if (is.null(baseline_stats)) {
      next
    }
    
    # Test each stress scenario
    for (scenario_name in names(stress_scenarios)) {
      scenario <- stress_scenarios[[scenario_name]]
      
      # Calculate stress impact
      stress_stats <- calculate_stress_impact(returns, nf_innovations, scenario)
      
      if (is.null(stress_stats)) {
        next
      }
      
      # Calculate robustness score
      robustness_score <- calculate_robustness_score(baseline_stats, stress_stats)
      
      # Store results
      result_row <- data.frame(
        Asset = asset,
        Model = paste0("NF_", model),
        Scenario = scenario$name,
        Scenario_Description = scenario$description,
        Baseline_VaR_95 = baseline_stats$var_95,
        Baseline_VaR_99 = baseline_stats$var_99,
        Baseline_Volatility = baseline_stats$volatility,
        Stressed_VaR_95 = stress_stats$stressed_var_95,
        Stressed_VaR_99 = stress_stats$stressed_var_99,
        Stressed_Volatility = stress_stats$stressed_volatility,
        Max_Drawdown = stress_stats$max_drawdown,
        Return_Shock = stress_stats$return_shock,
        Volatility_Shock = stress_stats$volatility_shock,
        Correlation_Shock = stress_stats$correlation_shock,
        Robustness_Score = robustness_score,
        Engine = engine,
        Sheet_Name = sheet_name,
        stringsAsFactors = FALSE
      )
      
      stress_results[[length(stress_results) + 1]] <- result_row
    }
  }
}

#### Compile and Save Results ####

if (length(stress_results) > 0) {
  # Combine all results
  stress_summary <- do.call(rbind, stress_results)
  
  # Create output directory
  dir.create("outputs/stress_tests/tables", recursive = TRUE, showWarnings = FALSE)
  
  # Save detailed results
  write.csv(stress_summary, "outputs/stress_tests/tables/nfgarch_stress_test_summary.csv", row.names = FALSE)
  
  # Create summary statistics
  stress_summary_stats <- stress_summary %>%
    group_by(Model, Scenario) %>%
    summarise(
      Avg_Robustness_Score = mean(Robustness_Score, na.rm = TRUE),
      Avg_Max_Drawdown = mean(Max_Drawdown, na.rm = TRUE),
      Avg_Stressed_VaR_95 = mean(Stressed_VaR_95, na.rm = TRUE),
      Avg_Stressed_VaR_99 = mean(Stressed_VaR_99, na.rm = TRUE),
      Avg_Stressed_Volatility = mean(Stressed_Volatility, na.rm = TRUE),
      Total_Assets = n(),
      .groups = 'drop'
    ) %>%
    arrange(Avg_Robustness_Score)
  
  write.csv(stress_summary_stats, "outputs/stress_tests/tables/nfgarch_model_robustness_scores.csv", row.names = FALSE)
  
  # Create scenario comparison
  scenario_comparison <- stress_summary %>%
    group_by(Scenario) %>%
    summarise(
      Avg_Robustness_Score = mean(Robustness_Score, na.rm = TRUE),
      Avg_Max_Drawdown = mean(Max_Drawdown, na.rm = TRUE),
      Total_Models = n_distinct(Model),
      Total_Assets = n_distinct(Asset),
      .groups = 'drop'
    ) %>%
    arrange(Avg_Robustness_Score)
  
  write.csv(scenario_comparison, "outputs/stress_tests/tables/nfgarch_scenario_comparison.csv", row.names = FALSE)
  
  cat("✓ NFGARCH stress testing completed successfully!\n")
  cat("Results saved to:\n")
  cat("  - outputs/stress_tests/tables/nfgarch_stress_test_summary.csv\n")
  cat("  - outputs/stress_tests/tables/nfgarch_model_robustness_scores.csv\n")
  cat("  - outputs/stress_tests/tables/nfgarch_scenario_comparison.csv\n")
  
} else {
  cat("⚠️ No NFGARCH stress test results generated. Check if NF residuals are available.\n")
}
