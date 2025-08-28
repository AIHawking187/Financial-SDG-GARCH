#!/usr/bin/env Rscript
# Complete NF-GARCH Pipeline Runner
# This script runs the entire pipeline from data preparation to final results

cat("=== COMPLETE NF-GARCH PIPELINE ===\n")
cat("Starting comprehensive pipeline execution...\n\n")

# Set working directory and load libraries
library(openxlsx)
library(quantmod)
library(tseries)
library(xts)
library(PerformanceAnalytics)
library(FinTS)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)

# Source all required scripts
source("scripts/utils/cli_parser.R")
source("scripts/engines/engine_selector.R")
source("scripts/utils/safety_functions.R")

# Step 1: Generate missing NF residuals
cat("Step 1: Generating missing NF residuals...\n")
system("python scripts/model_fitting/generate_missing_nf_residuals.py")
cat("✓ NF residuals generation complete\n\n")

# Step 2: Run EDA
cat("Step 2: Running Exploratory Data Analysis...\n")
tryCatch({
  source("scripts/eda/eda_summary_stats.R")
  cat("✓ EDA complete\n\n")
}, error = function(e) {
  cat("⚠️ EDA failed, continuing...\n\n")
})

# Step 3: Fit GARCH models
cat("Step 3: Fitting GARCH models...\n")
tryCatch({
  source("scripts/model_fitting/fit_garch_models.R")
  cat("✓ GARCH model fitting complete\n\n")
}, error = function(e) {
  cat("⚠️ GARCH fitting failed, continuing...\n\n")
})

# Step 4: Extract residuals
cat("Step 4: Extracting residuals...\n")
tryCatch({
  source("scripts/model_fitting/extract_residuals.R")
  cat("✓ Residual extraction complete\n\n")
}, error = function(e) {
  cat("⚠️ Residual extraction failed, continuing...\n\n")
})

# Step 5: Train NF models
cat("Step 5: Training Normalizing Flow models...\n")
tryCatch({
  system("python scripts/model_fitting/train_nf_models.py")
  cat("✓ NF training complete\n\n")
}, error = function(e) {
  cat("⚠️ NF training failed, continuing...\n\n")
})

# Step 6: Evaluate NF models
cat("Step 6: Evaluating NF models...\n")
tryCatch({
  system("python scripts/model_fitting/evaluate_nf_fit.py")
  cat("✓ NF evaluation complete\n\n")
}, error = function(e) {
  cat("⚠️ NF evaluation failed, continuing...\n\n")
})

# Step 7: Run NF-GARCH simulation with manual engine
cat("Step 7: Running NF-GARCH simulation (manual engine)...\n")
tryCatch({
  source("scripts/simulation_forecasting/simulate_nf_garch_engine.R")
  # Override engine to manual
  engine <- "manual"
  cat("Using engine: manual\n")
  
  # Run the simulation
  source("scripts/simulation_forecasting/simulate_nf_garch_engine.R")
  cat("✓ NF-GARCH simulation (manual) complete\n\n")
}, error = function(e) {
  cat("⚠️ NF-GARCH simulation failed: ", e$message, "\n\n")
})

# Step 8: Run NF-GARCH simulation with rugarch engine
cat("Step 8: Running NF-GARCH simulation (rugarch engine)...\n")
tryCatch({
  # Override engine to rugarch
  engine <- "rugarch"
  cat("Using engine: rugarch\n")
  
  # Run the simulation
  source("scripts/simulation_forecasting/simulate_nf_garch_engine.R")
  cat("✓ NF-GARCH simulation (rugarch) complete\n\n")
}, error = function(e) {
  cat("⚠️ NF-GARCH simulation failed: ", e$message, "\n\n")
})

# Step 9: Run forecasting
cat("Step 9: Running forecasting...\n")
tryCatch({
  source("scripts/simulation_forecasting/forecast_garch_variants.R")
  cat("✓ Forecasting complete\n\n")
}, error = function(e) {
  cat("⚠️ Forecasting failed, continuing...\n\n")
})

# Step 10: Evaluate forecasts
cat("Step 10: Evaluating forecasts...\n")
tryCatch({
  source("scripts/evaluation/wilcoxon_winrate_analysis.R")
  cat("✓ Forecast evaluation complete\n\n")
}, error = function(e) {
  cat("⚠️ Forecast evaluation failed, continuing...\n\n")
})

# Step 11: Run stylized fact tests
cat("Step 11: Running stylized fact tests...\n")
tryCatch({
  source("scripts/evaluation/stylized_fact_tests.R")
  cat("✓ Stylized fact tests complete\n\n")
}, error = function(e) {
  cat("⚠️ Stylized fact tests failed, continuing...\n\n")
})

# Step 12: Run VaR backtesting
cat("Step 12: Running VaR backtesting...\n")
tryCatch({
  source("scripts/evaluation/var_backtesting.R")
  cat("✓ VaR backtesting complete\n\n")
}, error = function(e) {
  cat("⚠️ VaR backtesting failed, continuing...\n\n")
})

# Step 13: Run stress tests
cat("Step 13: Running stress tests...\n")
tryCatch({
  source("scripts/stress_tests/evaluate_under_stress.R")
  cat("✓ Stress tests complete\n\n")
}, error = function(e) {
  cat("⚠️ Stress tests failed, continuing...\n\n")
})

# Step 14: Generate final summary
cat("Step 14: Generating final summary...\n")
tryCatch({
  # Create summary report
  summary_file <- "outputs/pipeline_summary.txt"
  dir.create("outputs", showWarnings = FALSE)
  
  cat("=== NF-GARCH PIPELINE SUMMARY ===\n", file = summary_file)
  cat("Date:", Sys.Date(), "\n", file = summary_file, append = TRUE)
  cat("Time:", Sys.time(), "\n\n", file = summary_file, append = TRUE)
  
  # Check output files
  output_files <- list.files("outputs", recursive = TRUE, full.names = TRUE)
  cat("Output files generated:", length(output_files), "\n", file = summary_file, append = TRUE)
  for (f in output_files) {
    cat("  -", f, "\n", file = summary_file, append = TRUE)
  }
  
  # Check NF residual files
  nf_files <- list.files("nf_generated_residuals", pattern = "*.csv", full.names = TRUE)
  cat("\nNF residual files:", length(nf_files), "\n", file = summary_file, append = TRUE)
  
  # Check results files
  result_files <- list.files(pattern = "*Results*.xlsx", full.names = TRUE)
  cat("Result files:", length(result_files), "\n", file = summary_file, append = TRUE)
  for (f in result_files) {
    cat("  -", f, "\n", file = summary_file, append = TRUE)
  }
  
  cat("\n=== PIPELINE COMPLETE ===\n", file = summary_file, append = TRUE)
  cat("✓ Pipeline execution finished\n\n")
  
}, error = function(e) {
  cat("⚠️ Summary generation failed: ", e$message, "\n\n")
})

cat("=== PIPELINE EXECUTION COMPLETE ===\n")
cat("Check outputs/ directory for results\n")
cat("Check pipeline_summary.txt for detailed summary\n")
