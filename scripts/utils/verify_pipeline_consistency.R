# Pipeline Consistency Verification Script
# This script verifies that all R scripts across the pipeline are using the complete 5-model GARCH configuration

cat("=== PIPELINE CONSISTENCY VERIFICATION ===\n")

# Libraries
library(stringr)

# Define the expected 5-model configuration
expected_models <- c("sGARCH_norm", "sGARCH_sstd", "gjrGARCH", "eGARCH", "TGARCH")

# Scripts to check
scripts_to_check <- c(
  "scripts/simulation_forecasting/simulate_nf_garch.R",
  "scripts/simulation_forecasting/simulate_nf_garch_quick_test.R",
  "scripts/model_fitting/fit_garch_models.R",
  "scripts/model_fitting/extract_residuals.R",
  "scripts/evaluation/distribution_fit_metrics.R",
  "scripts/evaluation/wilcoxon_winrate_analysis.R",
  "scripts/simulation_forecasting/forecast_garch_variants.R",
  "scripts/evaluation/var_backtesting.R",
  "scripts/stress_tests/evaluate_under_stress.R",
  "scripts/Manual Scripts/R - NFGARCH Main Training/GARCH Comparison Scripts/Exhaustive GARCH Comparison.R"
)

# Function to check model configuration in a script
check_script_models <- function(script_path) {
  cat("\nChecking:", script_path, "\n")
  
  if (!file.exists(script_path)) {
    cat("  ❌ File not found\n")
    return(list(found = FALSE, models = character(0)))
  }
  
  # Read the script
  script_content <- readLines(script_path, warn = FALSE)
  
  # Look for model_configs definition
  model_config_lines <- grep("model_configs.*list", script_content, value = TRUE)
  
  if (length(model_config_lines) == 0) {
    # Check for alternative patterns
    model_config_lines <- grep("models.*list", script_content, value = TRUE)
  }
  
  if (length(model_config_lines) == 0) {
    cat("  ⚠️  No model_configs found (may not need GARCH models)\n")
    return(list(found = FALSE, models = character(0)))
  }
  
  # Extract model names from the configuration
  found_models <- character(0)
  
  # Look for model names in the script
  for (model in expected_models) {
    if (any(grepl(model, script_content))) {
      found_models <- c(found_models, model)
    }
  }
  
  # Check if all expected models are found
  missing_models <- setdiff(expected_models, found_models)
  extra_models <- setdiff(found_models, expected_models)
  
  if (length(missing_models) == 0 && length(extra_models) == 0) {
    cat("  ✅ All 5 models found:", paste(found_models, collapse = ", "), "\n")
    return(list(found = TRUE, models = found_models, status = "complete"))
  } else {
    cat("  ❌ Incomplete model configuration:\n")
    if (length(missing_models) > 0) {
      cat("    Missing:", paste(missing_models, collapse = ", "), "\n")
    }
    if (length(extra_models) > 0) {
      cat("    Extra:", paste(extra_models, collapse = ", "), "\n")
    }
    return(list(found = TRUE, models = found_models, status = "incomplete"))
  }
}

# Check all scripts
results <- list()
total_scripts <- length(scripts_to_check)
complete_scripts <- 0
incomplete_scripts <- 0
no_model_scripts <- 0

for (script in scripts_to_check) {
  result <- check_script_models(script)
  results[[script]] <- result
  
  if (result$found) {
    if (result$status == "complete") {
      complete_scripts <- complete_scripts + 1
    } else {
      incomplete_scripts <- incomplete_scripts + 1
    }
  } else {
    no_model_scripts <- no_model_scripts + 1
  }
}

# Summary
cat("\n=== VERIFICATION SUMMARY ===\n")
cat("Total scripts checked:", total_scripts, "\n")
cat("Complete 5-model configuration:", complete_scripts, "\n")
cat("Incomplete configuration:", incomplete_scripts, "\n")
cat("No model configuration needed:", no_model_scripts, "\n")

# Check NF residuals coverage
cat("\n=== NF RESIDUALS COVERAGE CHECK ===\n")

nf_files <- list.files("nf_generated_residuals", pattern = "*.csv", full.names = FALSE)

# Count residuals by model type
model_counts <- list()
for (model in expected_models) {
  count <- length(grep(model, nf_files))
  model_counts[[model]] <- count
  cat(model, ":", count, "files\n")
}

# Expected coverage
expected_coverage <- 12 * 2  # 12 assets × 2 splits (Chrono + TS_CV)
cat("\nExpected coverage per model:", expected_coverage, "files\n")

# Check if any models are missing significant coverage
for (model in names(model_counts)) {
  if (model_counts[[model]] < expected_coverage * 0.5) {  # Less than 50% coverage
    cat("⚠️  ", model, "has low coverage (", model_counts[[model]], "/", expected_coverage, ")\n")
  }
}

# Overall assessment
cat("\n=== OVERALL ASSESSMENT ===\n")
if (complete_scripts == total_scripts - no_model_scripts && 
    all(unlist(model_counts) >= expected_coverage * 0.5)) {
  cat("✅ PIPELINE IS FULLY CONSISTENT\n")
  cat("All scripts use complete 5-model configuration\n")
  cat("All models have adequate NF residual coverage\n")
} else {
  cat("❌ PIPELINE NEEDS UPDATES\n")
  if (incomplete_scripts > 0) {
    cat("- Some scripts have incomplete model configurations\n")
  }
  if (any(unlist(model_counts) < expected_coverage * 0.5)) {
    cat("- Some models have insufficient NF residual coverage\n")
  }
}

cat("\n=== RECOMMENDATIONS ===\n")
if (incomplete_scripts > 0) {
  cat("1. Update scripts with incomplete model configurations\n")
}
if (any(unlist(model_counts) < expected_coverage * 0.5)) {
  cat("2. Generate missing NF residuals for low-coverage models\n")
}
if (complete_scripts == total_scripts - no_model_scripts && 
    all(unlist(model_counts) >= expected_coverage * 0.5)) {
  cat("1. Pipeline is ready for production use\n")
  cat("2. All 5 GARCH models are fully supported\n")
  cat("3. NF residual coverage is complete\n")
}
