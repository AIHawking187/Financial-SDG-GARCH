# GARCH Fitting Component
# Runs standard GARCH model fitting for both chronological and TS CV splits

cat("Running GARCH model fitting...\n")

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

# Run the standard GARCH fitting script
source("scripts/model_fitting/fit_garch_models.R")

cat("✓ GARCH fitting completed\n")
