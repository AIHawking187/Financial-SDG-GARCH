#!/usr/bin/env Rscript
# Centralized Configuration for Financial-SDG-GARCH Pipeline
# This file consolidates all configuration settings in one place

# =============================================================================
# MODEL CONFIGURATION
# =============================================================================

# GARCH Model Specifications
GARCH_MODELS <- list(
  sGARCH_norm = list(
    model = "sGARCH",
    distribution = "norm",
    description = "Standard GARCH with Normal Distribution"
  ),
  sGARCH_sstd = list(
    model = "sGARCH", 
    distribution = "sstd",
    description = "Standard GARCH with Skewed Student-t Distribution"
  ),
  eGARCH = list(
    model = "eGARCH",
    distribution = "norm", 
    description = "Exponential GARCH with Normal Distribution"
  ),
  gjrGARCH = list(
    model = "gjrGARCH",
    distribution = "norm",
    description = "Glosten-Jagannathan-Runkle GARCH"
  ),
  TGARCH = list(
    model = "TGARCH", 
    distribution = "norm",
    description = "Threshold GARCH"
  )
)

# NF-GARCH Model Specifications  
NF_GARCH_MODELS <- list(
  "NF--sGARCH" = list(
    base_model = "sGARCH",
    description = "Normalizing Flow with Standard GARCH"
  ),
  "NF--eGARCH" = list(
    base_model = "eGARCH", 
    description = "Normalizing Flow with Exponential GARCH"
  ),
  "NF--gjrGARCH" = list(
    base_model = "gjrGARCH",
    description = "Normalizing Flow with GJR-GARCH"
  ),
  "NF--TGARCH" = list(
    base_model = "TGARCH",
    description = "Normalizing Flow with Threshold GARCH"
  )
)

# =============================================================================
# ASSET CONFIGURATION
# =============================================================================

# Asset Categories
ASSETS <- list(
  fx = c("EURUSD", "GBPUSD", "GBPCNY", "USDZAR", "GBPZAR", "EURZAR"),
  equity = c("X", "NVDA", "MSFT", "PG", "CAT", "WMT", "AMZN")
)

# All assets combined
ALL_ASSETS <- c(ASSETS$fx, ASSETS$equity)

# Asset metadata
ASSET_METADATA <- list(
  EURUSD = list(type = "fx", description = "Euro/US Dollar"),
  GBPUSD = list(type = "fx", description = "British Pound/US Dollar"),
  GBPCNY = list(type = "fx", description = "British Pound/Chinese Yuan"),
  USDZAR = list(type = "fx", description = "US Dollar/South African Rand"),
  GBPZAR = list(type = "fx", description = "British Pound/South African Rand"),
  EURZAR = list(type = "fx", description = "Euro/South African Rand"),
  X = list(type = "equity", description = "United States Steel Corporation"),
  NVDA = list(type = "equity", description = "NVIDIA Corporation"),
  MSFT = list(type = "equity", description = "Microsoft Corporation"),
  PG = list(type = "equity", description = "Procter & Gamble Company"),
  CAT = list(type = "equity", description = "Caterpillar Inc."),
  WMT = list(type = "equity", description = "Walmart Inc."),
  AMZN = list(type = "equity", description = "Amazon.com Inc.")
)

# =============================================================================
# OUTPUT SCHEMAS
# =============================================================================

# Excel sheet schemas for validation
OUTPUT_SCHEMAS <- list(
  Model_Performance_Summary = c(
    "Model", "Source", "Avg_AIC", "Avg_BIC", "Avg_LogLik", "Avg_MSE", "Avg_MAE"
  ),
  VaR_Performance_Summary = c(
    "Model", "Asset", "Confidence_Level", "Total_Obs", "Expected_Rate", 
    "Violations", "Violation_Rate", "Kupiec_PValue", "Christoffersen_PValue", "DQ_PValue"
  ),
  Stress_Test_Summary = c(
    "Model", "Asset", "Scenario_Type", "Scenario_Name", "Convergence_Rate",
    "Pass_LB_Test", "Pass_ARCH_Test", "Total_Tests", "Robustness_Score"
  ),
  NF_Winners_By_Asset = c(
    "Asset", "Winning_Model", "Split", "Metric", "Value"
  ),
  Distributional_Fit_Summary = c(
    "Model", "Asset", "Test_Type", "Statistic", "P_Value", "Decision"
  )
)

# =============================================================================
# PIPELINE CONFIGURATION
# =============================================================================

# Pipeline steps and dependencies
PIPELINE_STEPS <- list(
  nf_residual_generation = list(
    description = "Generate NF residuals",
    dependencies = c(),
    script = "scripts/core/nf_residuals.R"
  ),
  eda = list(
    description = "Exploratory Data Analysis",
    dependencies = c(),
    script = "scripts/core/eda.R"
  ),
  data_prep = list(
    description = "Data preparation and preprocessing",
    dependencies = c(),
    script = "scripts/core/data_prep.R"
  ),
  garch_fitting = list(
    description = "Fit classical GARCH models",
    dependencies = c("data_prep"),
    script = "scripts/core/garch_fitting.R"
  ),
  residual_extraction = list(
    description = "Extract GARCH residuals",
    dependencies = c("garch_fitting"),
    script = "scripts/core/residual_extraction.R"
  ),
  nf_training = list(
    description = "Train Normalizing Flow models",
    dependencies = c("residual_extraction"),
    script = "scripts/core/nf_training.R"
  ),
  nf_evaluation = list(
    description = "Evaluate NF models",
    dependencies = c("nf_training"),
    script = "scripts/core/nf_evaluation.R"
  ),
  nf_garch_manual = list(
    description = "NF-GARCH simulation with manual engine",
    dependencies = c("nf_evaluation"),
    script = "scripts/core/simulation.R"
  ),
  nf_garch_rugarch = list(
    description = "NF-GARCH simulation with rugarch engine", 
    dependencies = c("nf_evaluation"),
    script = "scripts/core/simulation.R"
  ),
  legacy_nf_garch = list(
    description = "Legacy NF-GARCH simulation",
    dependencies = c("nf_evaluation"),
    script = "scripts/core/simulation.R"
  ),
  forecasting = list(
    description = "Generate forecasts",
    dependencies = c("garch_fitting", "nf_evaluation"),
    script = "scripts/core/forecasting.R"
  ),
  forecast_evaluation = list(
    description = "Evaluate forecasts",
    dependencies = c("forecasting"),
    script = "scripts/core/forecast_evaluation.R"
  ),
  stylized_facts = list(
    description = "Compute stylized facts",
    dependencies = c("garch_fitting", "nf_evaluation"),
    script = "scripts/core/stylized_facts.R"
  ),
  var_backtesting = list(
    description = "VaR backtesting for classical models",
    dependencies = c("garch_fitting"),
    script = "scripts/core/backtesting.R"
  ),
  nfgarch_var_backtesting = list(
    description = "VaR backtesting for NF-GARCH models",
    dependencies = c("nf_garch_manual", "nf_garch_rugarch"),
    script = "scripts/core/backtesting.R"
  ),
  stress_testing = list(
    description = "Stress testing for classical models",
    dependencies = c("garch_fitting"),
    script = "scripts/core/stress_testing.R"
  ),
  nfgarch_stress_testing = list(
    description = "Stress testing for NF-GARCH models",
    dependencies = c("nf_garch_manual", "nf_garch_rugarch"),
    script = "scripts/core/stress_testing.R"
  ),
  final_summary = list(
    description = "Generate final summaries",
    dependencies = c("var_backtesting", "stress_testing", "nfgarch_var_backtesting", "nfgarch_stress_testing"),
    script = "scripts/core/summary.R"
  ),
  consolidation = list(
    description = "Consolidate all results",
    dependencies = c("final_summary"),
    script = "scripts/core/consolidation.R"
  ),
  validation = list(
    description = "Validate pipeline outputs",
    dependencies = c("consolidation"),
    script = "scripts/core/validation.R"
  )
)

# =============================================================================
# FILE PATHS
# =============================================================================

# Input data paths
DATA_PATHS <- list(
  raw_data = "data/processed/raw (FX + EQ).csv",
  nf_residuals_dir = "nf_generated_residuals",
  checkpoints_dir = "checkpoints"
)

# Output paths
OUTPUT_PATHS <- list(
  base_dir = "outputs",
  eda = "outputs/eda",
  model_eval = "outputs/model_eval", 
  var_backtest = "outputs/var_backtest",
  stress_tests = "outputs/stress_tests",
  consolidated_results = "outputs/Consolidated_NF_GARCH_Results.xlsx",
  dissertation_results = "outputs/Dissertation_Consolidated_Results.xlsx"
)

# =============================================================================
# SIMULATION PARAMETERS
# =============================================================================

# NF-GARCH simulation parameters
SIMULATION_PARAMS <- list(
  n_simulations = 1000,
  forecast_horizon = 10,
  confidence_levels = c(0.95, 0.99),
  seed = 12345
)

# =============================================================================
# VALIDATION PARAMETERS
# =============================================================================

# Validation thresholds
VALIDATION_THRESHOLDS <- list(
  min_rows_per_sheet = 1,
  max_missing_pct = 0.0,  # No missing values allowed
  min_assets_covered = 12,
  required_confidence_levels = c(0.95, 0.99)
)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Get all model names (classical + NF)
get_all_models <- function() {
  c(names(GARCH_MODELS), names(NF_GARCH_MODELS))
}

# Get classical models only
get_classical_models <- function() {
  names(GARCH_MODELS)
}

# Get NF models only  
get_nf_models <- function() {
  names(NF_GARCH_MODELS)
}

# Get assets by type
get_assets_by_type <- function(type) {
  if (type %in% names(ASSETS)) {
    return(ASSETS[[type]])
  } else {
    stop("Invalid asset type. Use 'fx' or 'equity'")
  }
}

# Validate schema compliance
validate_schema <- function(data, schema_name) {
  if (!schema_name %in% names(OUTPUT_SCHEMAS)) {
    stop("Unknown schema: ", schema_name)
  }
  
  required_cols <- OUTPUT_SCHEMAS[[schema_name]]
  actual_cols <- colnames(data)
  
  missing_cols <- setdiff(required_cols, actual_cols)
  if (length(missing_cols) > 0) {
    stop("Missing required columns for schema '", schema_name, "': ", 
         paste(missing_cols, collapse = ", "))
  }
  
  return(TRUE)
}

# Print configuration summary
print_config_summary <- function() {
  cat("=== FINANCIAL-SDG-GARCH CONFIGURATION SUMMARY ===\n")
  cat("Classical GARCH Models:", length(GARCH_MODELS), "\n")
  cat("NF-GARCH Models:", length(NF_GARCH_MODELS), "\n")
  cat("FX Assets:", length(ASSETS$fx), "\n")
  cat("Equity Assets:", length(ASSETS$equity), "\n")
  cat("Pipeline Steps:", length(PIPELINE_STEPS), "\n")
  cat("Output Schemas:", length(OUTPUT_SCHEMAS), "\n")
  cat("================================================\n")
}

# Load configuration
load_config <- function() {
  # This function can be called to ensure config is loaded
  invisible(NULL)
}

