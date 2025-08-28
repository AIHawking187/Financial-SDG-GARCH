# Stylized Facts Analysis Component
# Runs stylized facts analysis for both standard and NF-GARCH models

cat("Running stylized facts analysis...\n")

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

# Run the stylized facts analysis script
source("scripts/evaluation/stylized_fact_tests.R")

cat("✓ Stylized facts analysis completed\n")
