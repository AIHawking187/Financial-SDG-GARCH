# Residual Extraction Component
# Extracts residuals from fitted GARCH models for NF training

cat("Extracting residuals from fitted GARCH models...\n")

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

# Run the residual extraction script
source("scripts/model_fitting/extract_residuals.R")

cat("✓ Residual extraction completed\n")
