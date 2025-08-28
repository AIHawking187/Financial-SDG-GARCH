#!/usr/bin/env Rscript
# Modular Pipeline Orchestrator
# Allows independent execution of pipeline components with checkpointing

library(openxlsx)
library(dplyr)
library(tidyr)
library(stringr)
library(readxl)

# Source utilities
source("scripts/utils/conflict_resolution.R")
source("scripts/utils/cli_parser.R")
source("scripts/engines/engine_selector.R")

# Initialize pipeline
initialize_pipeline()

# Configuration
PIPELINE_CONFIG <- list(
  components = c(
    "nf_residual_generation", # Generate missing NF residuals
    "data_prep",           # Data loading and preprocessing
    "garch_fitting",       # Standard GARCH model fitting
    "residual_extraction", # Extract residuals for NF training
    "nf_training",         # Python NF model training
    "nf_evaluation",       # NF model evaluation
    "nf_garch_manual",     # NF-GARCH with manual engine
    "nf_garch_rugarch",    # NF-GARCH with rugarch engine
    "legacy_nf_garch",     # Legacy NF-GARCH simulation
    "forecasting",         # Forecasting evaluation
    "forecast_evaluation", # Evaluate forecasts (Wilcoxon)
    "var_backtesting",     # VaR backtesting
    "stress_testing",      # Stress testing
    "stylized_facts",      # Stylized facts analysis
    "final_summary",       # Generate final summary
    "consolidation"        # Final results consolidation
  ),
  dependencies = list(
    "data_prep" = "nf_residual_generation",
    "garch_fitting" = "data_prep",
    "residual_extraction" = "garch_fitting",
    "nf_training" = "residual_extraction",
    "nf_evaluation" = "nf_training",
    "nf_garch_manual" = c("nf_evaluation", "garch_fitting"),
    "nf_garch_rugarch" = c("nf_evaluation", "garch_fitting"),
    "legacy_nf_garch" = c("nf_evaluation", "garch_fitting"),
    "forecasting" = "garch_fitting",
    "forecast_evaluation" = "forecasting",
    "var_backtesting" = c("garch_fitting", "nf_garch_manual", "nf_garch_rugarch"),
    "stress_testing" = c("garch_fitting", "nf_garch_manual", "nf_garch_rugarch"),
    "stylized_facts" = c("garch_fitting", "nf_garch_manual", "nf_garch_rugarch"),
    "final_summary" = c("var_backtesting", "stress_testing", "stylized_facts"),
    "consolidation" = c("final_summary")
  ),
  checkpoint_dir = "checkpoints",
  results_dir = "modular_results"
)

# Create directories
dir.create(PIPELINE_CONFIG$checkpoint_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(PIPELINE_CONFIG$results_dir, showWarnings = FALSE, recursive = TRUE)

# Checkpoint management
checkpoint_file <- file.path(PIPELINE_CONFIG$checkpoint_dir, "pipeline_status.json")

save_checkpoint <- function(component, status = "completed", error = NULL) {
  if (file.exists(checkpoint_file)) {
    checkpoints <- jsonlite::fromJSON(checkpoint_file)
  } else {
    checkpoints <- list()
  }
  
  checkpoints[[component]] <- list(
    status = status,
    timestamp = Sys.time(),
    error = error
  )
  
  writeLines(jsonlite::toJSON(checkpoints, auto_unbox = TRUE, pretty = TRUE), checkpoint_file)
}

load_checkpoints <- function() {
  if (file.exists(checkpoint_file)) {
    jsonlite::fromJSON(checkpoint_file)
  } else {
    list()
  }
}

is_component_completed <- function(component) {
  checkpoints <- load_checkpoints()
  if (component %in% names(checkpoints)) {
    checkpoints[[component]]$status == "completed"
  } else {
    FALSE
  }
}

are_dependencies_met <- function(component) {
  deps <- PIPELINE_CONFIG$dependencies[[component]]
  if (is.null(deps)) return(TRUE)
  
  all(sapply(deps, is_component_completed))
}

# Component execution functions
run_nf_residual_generation <- function() {
  cat("=== RUNNING NF RESIDUAL GENERATION ===\n")
  
  tryCatch({
    system("python scripts/model_fitting/generate_missing_nf_residuals.py")
    save_checkpoint("nf_residual_generation")
    cat("✓ NF residual generation completed\n")
    
  }, error = function(e) {
    save_checkpoint("nf_residual_generation", "failed", e$message)
    stop("NF residual generation failed: ", e$message)
  })
}

run_data_prep <- function() {
  cat("=== RUNNING DATA PREPARATION ===\n")
  
  tryCatch({
    # Load and process data
    source("scripts/modular_pipeline/components/data_preparation.R")
    
    # Save processed data
    saveRDS(list(
      fx_returns = fx_returns,
      equity_returns = equity_returns,
      date_index = date_index
    ), file.path(PIPELINE_CONFIG$results_dir, "processed_data.rds"))
    
    save_checkpoint("data_prep")
    cat("✓ Data preparation completed\n")
    
  }, error = function(e) {
    save_checkpoint("data_prep", "failed", e$message)
    stop("Data preparation failed: ", e$message)
  })
}

run_garch_fitting <- function() {
  cat("=== RUNNING GARCH MODEL FITTING ===\n")
  
  tryCatch({
    source("scripts/modular_pipeline/components/garch_fitting.R")
    save_checkpoint("garch_fitting")
    cat("✓ GARCH fitting completed\n")
    
  }, error = function(e) {
    save_checkpoint("garch_fitting", "failed", e$message)
    stop("GARCH fitting failed: ", e$message)
  })
}

run_residual_extraction <- function() {
  cat("=== RUNNING RESIDUAL EXTRACTION ===\n")
  
  tryCatch({
    source("scripts/modular_pipeline/components/residual_extraction.R")
    save_checkpoint("residual_extraction")
    cat("✓ Residual extraction completed\n")
    
  }, error = function(e) {
    save_checkpoint("residual_extraction", "failed", e$message)
    stop("Residual extraction failed: ", e$message)
  })
}

run_nf_training <- function() {
  cat("=== RUNNING NF MODEL TRAINING ===\n")
  
  tryCatch({
    system("python scripts/modular_pipeline/components/nf_training.py")
    save_checkpoint("nf_training")
    cat("✓ NF training completed\n")
    
  }, error = function(e) {
    save_checkpoint("nf_training", "failed", e$message)
    stop("NF training failed: ", e$message)
  })
}

run_nf_evaluation <- function() {
  cat("=== RUNNING NF MODEL EVALUATION ===\n")
  
  tryCatch({
    system("python scripts/modular_pipeline/components/nf_evaluation.py")
    save_checkpoint("nf_evaluation")
    cat("✓ NF evaluation completed\n")
    
  }, error = function(e) {
    save_checkpoint("nf_evaluation", "failed", e$message)
    stop("NF evaluation failed: ", e$message)
  })
}

run_nf_garch_manual <- function() {
  cat("=== RUNNING NF-GARCH (MANUAL ENGINE) ===\n")
  
  tryCatch({
    system("Rscript scripts/simulation_forecasting/simulate_nf_garch_engine.R --engine manual")
    save_checkpoint("nf_garch_manual")
    cat("✓ NF-GARCH manual engine completed\n")
    
  }, error = function(e) {
    save_checkpoint("nf_garch_manual", "failed", e$message)
    stop("NF-GARCH manual engine failed: ", e$message)
  })
}

run_nf_garch_rugarch <- function() {
  cat("=== RUNNING NF-GARCH (RUGARCH ENGINE) ===\n")
  
  tryCatch({
    system("Rscript scripts/simulation_forecasting/simulate_nf_garch_engine.R --engine rugarch")
    save_checkpoint("nf_garch_rugarch")
    cat("✓ NF-GARCH rugarch engine completed\n")
    
  }, error = function(e) {
    save_checkpoint("nf_garch_rugarch", "failed", e$message)
    stop("NF-GARCH rugarch engine failed: ", e$message)
  })
}

run_forecasting <- function() {
  cat("=== RUNNING FORECASTING EVALUATION ===\n")
  
  tryCatch({
    source("scripts/modular_pipeline/components/forecasting_evaluation.R")
    save_checkpoint("forecasting")
    cat("✓ Forecasting evaluation completed\n")
    
  }, error = function(e) {
    save_checkpoint("forecasting", "failed", e$message)
    stop("Forecasting evaluation failed: ", e$message)
  })
}

run_var_backtesting <- function() {
  cat("=== RUNNING VAR BACKTESTING ===\n")
  
  tryCatch({
    source("scripts/modular_pipeline/components/var_backtesting.R")
    save_checkpoint("var_backtesting")
    cat("✓ VaR backtesting completed\n")
    
  }, error = function(e) {
    save_checkpoint("var_backtesting", "failed", e$message)
    stop("VaR backtesting failed: ", e$message)
  })
}

run_stress_testing <- function() {
  cat("=== RUNNING STRESS TESTING ===\n")
  
  tryCatch({
    source("scripts/modular_pipeline/components/stress_testing.R")
    save_checkpoint("stress_testing")
    cat("✓ Stress testing completed\n")
    
  }, error = function(e) {
    save_checkpoint("stress_testing", "failed", e$message)
    stop("Stress testing failed: ", e$message)
  })
}

run_stylized_facts <- function() {
  cat("=== RUNNING STYLIZED FACTS ANALYSIS ===\n")
  
  tryCatch({
    source("scripts/modular_pipeline/components/stylized_facts.R")
    save_checkpoint("stylized_facts")
    cat("✓ Stylized facts analysis completed\n")
    
  }, error = function(e) {
    save_checkpoint("stylized_facts", "failed", e$message)
    stop("Stylized facts analysis failed: ", e$message)
  })
}

run_legacy_nf_garch <- function() {
  cat("=== RUNNING LEGACY NF-GARCH SIMULATION ===\n")
  
  tryCatch({
    system("Rscript scripts/simulation_forecasting/simulate_nf_garch.R")
    save_checkpoint("legacy_nf_garch")
    cat("✓ Legacy NF-GARCH simulation completed\n")
    
  }, error = function(e) {
    save_checkpoint("legacy_nf_garch", "failed", e$message)
    stop("Legacy NF-GARCH simulation failed: ", e$message)
  })
}

run_forecast_evaluation <- function() {
  cat("=== RUNNING FORECAST EVALUATION ===\n")
  
  tryCatch({
    system("Rscript scripts/evaluation/wilcoxon_winrate_analysis.R")
    save_checkpoint("forecast_evaluation")
    cat("✓ Forecast evaluation completed\n")
    
  }, error = function(e) {
    save_checkpoint("forecast_evaluation", "failed", e$message)
    stop("Forecast evaluation failed: ", e$message)
  })
}

run_final_summary <- function() {
  cat("=== GENERATING FINAL SUMMARY ===\n")
  
  tryCatch({
    # Generate final summary
    system('Rscript -e "library(openxlsx); cat(\"=== NF-GARCH PIPELINE SUMMARY ===\\n\"); cat(\"Date:\", Sys.Date(), \"\\n\"); cat(\"Time:\", Sys.time(), \"\\n\\n\"); output_files <- list.files(\"outputs\", recursive = TRUE, full.names = TRUE); cat(\"Output files generated:\", length(output_files), \"\\n\"); nf_files <- list.files(\"nf_generated_residuals\", pattern = \"*.csv\", full.names = TRUE); cat(\"NF residual files:\", length(nf_files), \"\\n\"); result_files <- list.files(pattern = \"*Results*.xlsx\", full.names = TRUE); cat(\"Result files:\", length(result_files), \"\\n\"); cat(\"\\n=== PIPELINE COMPLETE ===\\n\")"')
    save_checkpoint("final_summary")
    cat("✓ Final summary completed\n")
    
  }, error = function(e) {
    save_checkpoint("final_summary", "failed", e$message)
    stop("Final summary failed: ", e$message)
  })
}

run_consolidation <- function() {
  cat("=== RUNNING RESULTS CONSOLIDATION ===\n")
  
  tryCatch({
    source("scripts/utils/consolidate_results.R")
    save_checkpoint("consolidation")
    cat("✓ Results consolidation completed\n")
    
  }, error = function(e) {
    save_checkpoint("consolidation", "failed", e$message)
    stop("Results consolidation failed: ", e$message)
  })
}

# Main execution function
run_component <- function(component) {
  cat("\n", strrep("=", 60), "\n")
  cat("EXECUTING COMPONENT:", component, "\n")
  cat(strrep("=", 60), "\n\n")
  
  # Check if already completed
  if (is_component_completed(component)) {
    cat("✓ Component", component, "already completed, skipping...\n")
    return(TRUE)
  }
  
  # Check dependencies
  if (!are_dependencies_met(component)) {
    cat("❌ Dependencies not met for", component, "\n")
    cat("Required dependencies:", paste(PIPELINE_CONFIG$dependencies[[component]], collapse = ", "), "\n")
    return(FALSE)
  }
  
  # Execute component
  switch(component,
    "nf_residual_generation" = run_nf_residual_generation(),
    "data_prep" = run_data_prep(),
    "garch_fitting" = run_garch_fitting(),
    "residual_extraction" = run_residual_extraction(),
    "nf_training" = run_nf_training(),
    "nf_evaluation" = run_nf_evaluation(),
    "nf_garch_manual" = run_nf_garch_manual(),
    "nf_garch_rugarch" = run_nf_garch_rugarch(),
    "legacy_nf_garch" = run_legacy_nf_garch(),
    "forecasting" = run_forecasting(),
    "forecast_evaluation" = run_forecast_evaluation(),
    "var_backtesting" = run_var_backtesting(),
    "stress_testing" = run_stress_testing(),
    "stylized_facts" = run_stylized_facts(),
    "final_summary" = run_final_summary(),
    "consolidation" = run_consolidation(),
    stop("Unknown component: ", component)
  )
  
  return(TRUE)
}

# Pipeline status functions
show_status <- function() {
  cat("\n=== PIPELINE STATUS ===\n")
  checkpoints <- load_checkpoints()
  
  for (component in PIPELINE_CONFIG$components) {
    if (component %in% names(checkpoints)) {
      status <- checkpoints[[component]]$status
      timestamp <- checkpoints[[component]]$timestamp
      cat(sprintf("%-20s: %s (%s)\n", component, status, timestamp))
    } else {
      cat(sprintf("%-20s: not started\n", component))
    }
  }
  cat("\n")
}

reset_component <- function(component) {
  checkpoints <- load_checkpoints()
  if (component %in% names(checkpoints)) {
    checkpoints[[component]] <- NULL
    writeLines(jsonlite::toJSON(checkpoints, auto_unbox = TRUE, pretty = TRUE), checkpoint_file)
    cat("✓ Reset component:", component, "\n")
  } else {
    cat("Component", component, "not found in checkpoints\n")
  }
}

# Main execution
if (!interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  
  if (length(args) == 0) {
    # Run full pipeline
    cat("Running full modular pipeline...\n")
    for (component in PIPELINE_CONFIG$components) {
      success <- run_component(component)
      if (!success) {
        cat("❌ Pipeline stopped at component:", component, "\n")
        break
      }
    }
  } else if (args[1] == "status") {
    show_status()
  } else if (args[1] == "reset" && length(args) > 1) {
    reset_component(args[2])
  } else if (args[1] == "run" && length(args) > 1) {
    # Run specific component
    component <- args[2]
    if (component %in% PIPELINE_CONFIG$components) {
      run_component(component)
    } else {
      cat("Unknown component:", component, "\n")
      cat("Available components:", paste(PIPELINE_CONFIG$components, collapse = ", "), "\n")
    }
  } else {
    cat("Usage:\n")
    cat("  Rscript run_modular_pipeline.R                    # Run full pipeline\n")
    cat("  Rscript run_modular_pipeline.R status             # Show status\n")
    cat("  Rscript run_modular_pipeline.R run <component>    # Run specific component\n")
    cat("  Rscript run_modular_pipeline.R reset <component>  # Reset component\n")
  }
}
