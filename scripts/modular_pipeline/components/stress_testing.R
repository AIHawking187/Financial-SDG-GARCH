# Stress Testing Component
# Runs stress testing for both standard and NF-GARCH models

cat("Running stress testing...\n")

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

# Run the stress testing script
source("scripts/stress_tests/evaluate_under_stress.R")

# Run the NFGARCH stress testing script
source("scripts/evaluation/nfgarch_stress_testing.R")

cat("✓ Stress testing completed\n")
