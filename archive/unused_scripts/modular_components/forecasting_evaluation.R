# Forecasting Evaluation Component
# Runs forecasting evaluation for both standard and NF-GARCH models

cat("Running forecasting evaluation...\n")

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

# Run the forecasting evaluation script
source("scripts/simulation_forecasting/forecast_garch_variants.R")

cat("✓ Forecasting evaluation completed\n")
