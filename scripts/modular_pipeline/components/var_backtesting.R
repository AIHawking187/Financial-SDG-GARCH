# VaR Backtesting Component
# Runs VaR backtesting for both standard and NF-GARCH models

cat("Running VaR backtesting...\n")

# Load processed data if available
data_file <- "modular_results/processed_data.rds"
if (file.exists(data_file)) {
  data <- readRDS(data_file)
  fx_returns <- data$fx_returns
  equity_returns <- data$equity_returns
  date_index <- data$date_index
} else {
  # Fallback to direct loading
  source("scripts/modular_pipeline/components/data_preparation.R")
}

# Run the VaR backtesting script
source("scripts/evaluation/var_backtesting.R")

# Run the NFGARCH VaR backtesting script
source("scripts/evaluation/nfgarch_var_backtesting.R")

cat("✓ VaR backtesting completed\n")
