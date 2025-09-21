#!/usr/bin/env Rscript
# Consolidated Results Consolidation Module
# This file combines all consolidation functionality into a single, unified module
# Replaces: consolidate_results.R, consolidate_results_improved.R, consolidate_results_final.R, etc.

# Load required libraries
library(openxlsx)
library(dplyr)
library(tidyr)
library(stringr)
library(readxl)

# Load configuration and utilities
source("scripts/core/config.R")
source("scripts/core/utils.R")

# =============================================================================
# CORE CONSOLIDATION FUNCTIONS
# =============================================================================

# Main consolidation function
consolidate_results <- function(
  output_type = c("all", "performance", "backtesting", "stress_tests"),
  output_format = c("excel", "csv", "rds"),
  enforce_schema = TRUE,
  fill_missing = TRUE
) {
  # Unified consolidation function that handles all cases
  
  output_type <- match.arg(output_type)
  output_format <- match.arg(output_format)
  
  cat("=== CONSOLIDATING PIPELINE RESULTS ===\n")
  cat("Output type:", output_type, "\n")
  cat("Output format:", output_format, "\n")
  
  # Initialize results storage
  all_results <- list()
  
  # Load all available data
  all_results <- load_all_pipeline_data()
  
  # Process based on output type
  if (output_type == "all" || output_type == "performance") {
    all_results$performance <- consolidate_performance_data(all_results)
  }
  
  if (output_type == "all" || output_type == "backtesting") {
    all_results$backtesting <- consolidate_backtesting_data(all_results)
  }
  
  if (output_type == "all" || output_type == "stress_tests") {
    all_results$stress_tests <- consolidate_stress_testing_data(all_results)
  }
  
  # Always process all data types for comprehensive output
  if (output_type == "all") {
    all_results$performance <- consolidate_performance_data(all_results)
    all_results$backtesting <- consolidate_backtesting_data(all_results)
    all_results$stress_tests <- consolidate_stress_testing_data(all_results)
    all_results$stylized_facts <- consolidate_stylized_facts_data(all_results)
    all_results$model_ranking <- consolidate_model_ranking_data(all_results)
  }
  
  # Enforce schemas if requested
  if (enforce_schema) {
    all_results <- enforce_output_schemas(all_results)
  }
  
  # Fill missing values if requested
  if (fill_missing) {
    all_results <- fill_missing_values(all_results)
  }
  
  # Format and save output
  result <- format_and_save_output(all_results, output_format, output_type)
  
  cat("✓ Consolidation completed successfully\n")
  return(result)
}

# Load all pipeline data
load_all_pipeline_data <- function() {
  # Load all available pipeline data
  
  all_data <- list()
  
  # 1. Load GARCH Model Fitting Results
  cat("Loading GARCH model fitting results...\n")
  tryCatch({
    # Load from CSV files in outputs/model_eval/tables/
    model_eval_dir <- "outputs/model_eval/tables"
    if (dir.exists(model_eval_dir)) {
      # Load model ranking
      ranking_file <- file.path(model_eval_dir, "model_ranking.csv")
      if (file.exists(ranking_file)) {
        all_data$model_ranking <- read.csv(ranking_file)
        cat("✓ Loaded model ranking\n")
      }
      
      # Load forecast accuracy (as performance data)
      forecast_file <- file.path(model_eval_dir, "forecast_accuracy_summary.csv")
      if (file.exists(forecast_file)) {
        all_data$forecast_performance <- read.csv(forecast_file)
        cat("✓ Loaded forecast performance\n")
      }
      
      # Load stylized facts
      stylized_file <- file.path(model_eval_dir, "stylized_facts_summary.csv")
      if (file.exists(stylized_file)) {
        all_data$stylized_facts <- read.csv(stylized_file)
        cat("✓ Loaded stylized facts\n")
      }
    }
  }, error = function(e) {
    cat("⚠️ Could not load GARCH fitting results:", e$message, "\n")
  })
  
  # 2. Load NF-GARCH Results
  cat("Loading NF-GARCH results...\n")
  nf_files <- list.files(pattern = "NF_GARCH_Results_.*\\.xlsx", full.names = TRUE)
  
  for (file in nf_files) {
    engine_name <- str_extract(file, "(?<=NF_GARCH_Results_)[^.]+")
    tryCatch({
      sheets <- excel_sheets(file)
      for (sheet in sheets) {
        nf_data <- read_excel(file, sheet = sheet)
        nf_data$Engine <- engine_name
        nf_data$Model_Type <- "NF-GARCH"
        nf_data$Sheet_Name <- sheet
        
        all_data[[paste0("nf_garch_", engine_name, "_", sheet)]] <- nf_data
      }
      cat("✓ Loaded NF-GARCH results for", engine_name, "engine\n")
    }, error = function(e) {
      cat("⚠️ Could not load NF-GARCH results from", file, ":", e$message, "\n")
    })
  }
  
  # 3. Load Forecasting Results
  cat("Loading forecasting results...\n")
  tryCatch({
    forecast_files <- list.files("outputs/model_eval/tables", pattern = ".*forecast.*\\.csv", full.names = TRUE)
    for (file in forecast_files) {
      forecast_data <- read.csv(file)
      file_name <- basename(file)
      all_data[[paste0("forecast_", file_name)]] <- forecast_data
    }
    cat("✓ Loaded forecasting results\n")
  }, error = function(e) {
    cat("⚠️ Could not load forecasting results:", e$message, "\n")
  })
  
  # 4. Load VaR Backtesting Results
  cat("Loading VaR backtesting results...\n")
  tryCatch({
    var_files <- list.files("outputs/var_backtest/tables", pattern = ".*\\.csv", full.names = TRUE)
    for (file in var_files) {
      var_data <- read.csv(file)
      file_name <- basename(file)
      all_data[[paste0("var_", file_name)]] <- var_data
    }
    cat("✓ Loaded VaR backtesting results\n")
  }, error = function(e) {
    cat("⚠️ Could not load VaR backtesting results:", e$message, "\n")
  })
  
  # 5. Load Stress Testing Results
  cat("Loading stress testing results...\n")
  tryCatch({
    stress_files <- list.files("outputs/stress_tests/tables", pattern = ".*\\.csv", full.names = TRUE)
    for (file in stress_files) {
      stress_data <- read.csv(file)
      file_name <- basename(file)
      all_data[[paste0("stress_", file_name)]] <- stress_data
    }
    cat("✓ Loaded stress testing results\n")
  }, error = function(e) {
    cat("⚠️ Could not load stress testing results:", e$message, "\n")
  })
  
  return(all_data)
}

# Consolidate performance data
consolidate_performance_data <- function(all_data) {
  # Consolidate model performance data
  
  performance_data <- list()
  
  # Extract performance metrics from various sources
  if ("chrono_split" %in% names(all_data)) {
    chrono_data <- all_data$chrono_split
    if (nrow(chrono_data) > 0) {
      performance_data$chrono_performance <- chrono_data %>%
        select(Model, Asset, AIC, BIC, LogLikelihood, MSE, MAE) %>%
        mutate(Source = "Chronological Split")
    }
  }
  
  if ("cv_split" %in% names(all_data)) {
    cv_data <- all_data$cv_split
    if (nrow(cv_data) > 0) {
      performance_data$cv_performance <- cv_data %>%
        select(Model, Asset, AIC, BIC, LogLikelihood, MSE, MAE) %>%
        mutate(Source = "Cross-Validation")
    }
  }
  
  # Combine NF-GARCH performance data
  nf_performance <- list()
  for (key in names(all_data)) {
    if (grepl("^nf_garch_", key) && "Model" %in% colnames(all_data[[key]])) {
      nf_data <- all_data[[key]]
      if (nrow(nf_data) > 0) {
        # Extract performance metrics if available
        if (all(c("Model", "Asset") %in% colnames(nf_data))) {
          nf_performance[[key]] <- nf_data %>%
            select(Model, Asset, any_of(c("AIC", "BIC", "LogLikelihood", "MSE", "MAE"))) %>%
            mutate(Source = "NF-GARCH")
        }
      }
    }
  }
  
  if (length(nf_performance) > 0) {
    performance_data$nf_performance <- bind_rows(nf_performance)
  }
  
  # Combine all performance data
  if (length(performance_data) > 0) {
    combined_performance <- bind_rows(performance_data)
    
    # Calculate average metrics by model and source
    avg_performance <- combined_performance %>%
      group_by(Model, Source) %>%
      summarise(
        Avg_AIC = mean(AIC, na.rm = TRUE),
        Avg_BIC = mean(BIC, na.rm = TRUE),
        Avg_LogLik = mean(LogLikelihood, na.rm = TRUE),
        Avg_MSE = mean(MSE, na.rm = TRUE),
        Avg_MAE = mean(MAE, na.rm = TRUE),
        .groups = "drop"
      )
    
    return(avg_performance)
  } else {
    return(data.frame())
  }
}

# Consolidate backtesting data
consolidate_backtesting_data <- function(all_data) {
  # Consolidate VaR backtesting data
  
  backtesting_data <- list()
  
  # Extract VaR backtesting results
  for (key in names(all_data)) {
    if (grepl("^var_", key) && nrow(all_data[[key]]) > 0) {
      var_data <- all_data[[key]]
      
      # Check if this looks like VaR backtesting data
      if (any(grepl("violation|var|confidence", tolower(colnames(var_data))))) {
        backtesting_data[[key]] <- var_data
      }
    }
  }
  
  # Combine NF-GARCH VaR results
  nf_var_data <- list()
  for (key in names(all_data)) {
    if (grepl("^nf_garch_", key) && nrow(all_data[[key]]) > 0) {
      nf_data <- all_data[[key]]
      
      # Check if this contains VaR information
      if (any(grepl("var|confidence|violation", tolower(colnames(nf_data))))) {
        nf_var_data[[key]] <- nf_data
      }
    }
  }
  
  if (length(nf_var_data) > 0) {
    backtesting_data$nf_var <- bind_rows(nf_var_data)
  }
  
  # Combine all backtesting data
  if (length(backtesting_data) > 0) {
    combined_backtesting <- bind_rows(backtesting_data)
    
    # Standardize column names
    combined_backtesting <- standardize_backtesting_columns(combined_backtesting)
    
    return(combined_backtesting)
  } else {
    return(data.frame())
  }
}

# Consolidate stress testing data
consolidate_stress_testing_data <- function(all_data) {
  # Consolidate stress testing data
  
  stress_data <- list()
  
  # Extract stress testing results
  for (key in names(all_data)) {
    if (grepl("^stress_", key) && nrow(all_data[[key]]) > 0) {
      stress_data[[key]] <- all_data[[key]]
    }
  }
  
  # Combine NF-GARCH stress results
  nf_stress_data <- list()
  for (key in names(all_data)) {
    if (grepl("^nf_garch_", key) && nrow(all_data[[key]]) > 0) {
      nf_data <- all_data[[key]]
      
      # Check if this contains stress testing information
      if (any(grepl("stress|scenario|convergence", tolower(colnames(nf_data))))) {
        nf_stress_data[[key]] <- nf_data
      }
    }
  }
  
  if (length(nf_stress_data) > 0) {
    stress_data$nf_stress <- bind_rows(nf_stress_data)
  }
  
  # Combine all stress testing data
  if (length(stress_data) > 0) {
    combined_stress <- bind_rows(stress_data)
    
    # Standardize column names
    combined_stress <- standardize_stress_columns(combined_stress)
    
    return(combined_stress)
  } else {
    return(data.frame())
  }
}

# Consolidate stylized facts data
consolidate_stylized_facts_data <- function(all_data) {
  # Consolidate stylized facts data
  
  stylized_data <- list()
  
  # Extract stylized facts results
  if ("stylized_facts" %in% names(all_data)) {
    stylized_data$stylized_facts <- all_data$stylized_facts
  }
  
  # Combine all stylized facts data
  if (length(stylized_data) > 0) {
    combined_stylized <- bind_rows(stylized_data)
    return(combined_stylized)
  } else {
    return(data.frame())
  }
}

# Consolidate model ranking data
consolidate_model_ranking_data <- function(all_data) {
  # Consolidate model ranking data
  
  ranking_data <- list()
  
  # Extract model ranking results
  if ("model_ranking" %in% names(all_data)) {
    ranking_data$model_ranking <- all_data$model_ranking
  }
  
  # Combine all model ranking data
  if (length(ranking_data) > 0) {
    combined_ranking <- bind_rows(ranking_data)
    return(combined_ranking)
  } else {
    return(data.frame())
  }
}

# =============================================================================
# SCHEMA ENFORCEMENT
# =============================================================================

# Enforce output schemas
enforce_output_schemas <- function(all_results) {
  # Enforce schemas for all output data
  
  cat("Enforcing output schemas...\n")
  
  # Enforce performance schema
  if ("performance" %in% names(all_results) && nrow(all_results$performance) > 0) {
    all_results$performance <- enforce_schema(all_results$performance, "Model_Performance_Summary")
  }
  
  # Enforce backtesting schema
  if ("backtesting" %in% names(all_results) && nrow(all_results$backtesting) > 0) {
    all_results$backtesting <- enforce_schema(all_results$backtesting, "VaR_Performance_Summary")
  }
  
  # Enforce stress testing schema
  if ("stress_tests" %in% names(all_results) && nrow(all_results$stress_tests) > 0) {
    all_results$stress_tests <- enforce_schema(all_results$stress_tests, "Stress_Test_Summary")
  }
  
  return(all_results)
}

# Enforce specific schema
enforce_schema <- function(data, schema_name) {
  # Enforce specific schema on data
  
  if (!schema_name %in% names(OUTPUT_SCHEMAS)) {
    stop("Unknown schema: ", schema_name)
  }
  
  required_cols <- OUTPUT_SCHEMAS[[schema_name]]
  actual_cols <- colnames(data)
  
  # Add missing columns with default values
  for (col in required_cols) {
    if (!col %in% actual_cols) {
      data[[col]] <- NA
    }
  }
  
  # Reorder columns to match schema
  data <- data[, required_cols, drop = FALSE]
  
  return(data)
}

# =============================================================================
# MISSING VALUE HANDLING
# =============================================================================

# Fill missing values
fill_missing_values <- function(all_results) {
  # Fill missing values in all results
  
  cat("Filling missing values...\n")
  
  for (key in names(all_results)) {
    if (is.data.frame(all_results[[key]]) && nrow(all_results[[key]]) > 0) {
      all_results[[key]] <- fill_missing_in_dataframe(all_results[[key]])
    }
  }
  
  return(all_results)
}

# Fill missing values in dataframe
fill_missing_in_dataframe <- function(data) {
  # Fill missing values in dataframe with appropriate defaults
  
  for (col in colnames(data)) {
    if (is.numeric(data[[col]])) {
      # For numeric columns, fill with 0
      data[[col]][is.na(data[[col]])] <- 0
    } else if (is.character(data[[col]])) {
      # For character columns, fill with "N/A"
      data[[col]][is.na(data[[col]])] <- "N/A"
    }
  }
  
  return(data)
}

# =============================================================================
# OUTPUT FORMATTING
# =============================================================================

# Format and save output
format_and_save_output <- function(all_results, output_format, output_type) {
  # Format and save consolidated results
  
  if (output_format == "excel") {
    return(save_to_excel(all_results, output_type))
  } else if (output_format == "csv") {
    return(save_to_csv(all_results, output_type))
  } else if (output_format == "rds") {
    return(save_to_rds(all_results, output_type))
  }
}

# Save to Excel
save_to_excel <- function(all_results, output_type) {
  # Save consolidated results to Excel
  
  # Create workbook
  wb <- createWorkbook()
  
  # Add sheets based on output type
  if (output_type == "all" || output_type == "performance") {
    if ("performance" %in% names(all_results) && nrow(all_results$performance) > 0) {
      addWorksheet(wb, "Model_Performance_Summary")
      writeData(wb, "Model_Performance_Summary", all_results$performance)
    }
  }
  
  if (output_type == "all" || output_type == "backtesting") {
    if ("backtesting" %in% names(all_results) && nrow(all_results$backtesting) > 0) {
      addWorksheet(wb, "VaR_Performance_Summary")
      writeData(wb, "VaR_Performance_Summary", all_results$backtesting)
    }
  }
  
  if (output_type == "all" || output_type == "stress_tests") {
    if ("stress_tests" %in% names(all_results) && nrow(all_results$stress_tests) > 0) {
      addWorksheet(wb, "Stress_Test_Summary")
      writeData(wb, "Stress_Test_Summary", all_results$stress_tests)
    }
  }
  
  # Add additional sheets for comprehensive output
  if (output_type == "all") {
    if ("stylized_facts" %in% names(all_results) && nrow(all_results$stylized_facts) > 0) {
      addWorksheet(wb, "Stylized_Facts_Summary")
      writeData(wb, "Stylized_Facts_Summary", all_results$stylized_facts)
    }
    
    if ("model_ranking" %in% names(all_results) && nrow(all_results$model_ranking) > 0) {
      addWorksheet(wb, "model_ranking")
      writeData(wb, "model_ranking", all_results$model_ranking)
    }
    
    # Add NFGARCH specific sheets
    if ("backtesting" %in% names(all_results) && nrow(all_results$backtesting) > 0) {
      addWorksheet(wb, "NFGARCH_VaR_Summary")
      writeData(wb, "NFGARCH_VaR_Summary", all_results$backtesting)
    }
    
    if ("stress_tests" %in% names(all_results) && nrow(all_results$stress_tests) > 0) {
      addWorksheet(wb, "NFGARCH_Stress_Summary")
      writeData(wb, "NFGARCH_Stress_Summary", all_results$stress_tests)
    }
  }
  
  # Save workbook with both expected names
  filename1 <- paste0("Consolidated_Results_", output_type, ".xlsx")
  filename2 <- "Consolidated_NF_GARCH_Results.xlsx"
  filename3 <- "Dissertation_Consolidated_Results.xlsx"
  
  saveWorkbook(wb, filename1, overwrite = TRUE)
  saveWorkbook(wb, filename2, overwrite = TRUE)
  saveWorkbook(wb, filename3, overwrite = TRUE)
  
  cat("✓ Excel files saved:", filename1, ",", filename2, ",", filename3, "\n")
  return(c(filename1, filename2, filename3))
}

# Save to CSV
save_to_csv <- function(all_results, output_type) {
  # Save consolidated results to CSV files
  
  filenames <- list()
  
  if (output_type == "all" || output_type == "performance") {
    if ("performance" %in% names(all_results) && nrow(all_results$performance) > 0) {
      filename <- paste0("Model_Performance_Summary_", output_type, ".csv")
      write.csv(all_results$performance, filename, row.names = FALSE)
      filenames$performance <- filename
    }
  }
  
  if (output_type == "all" || output_type == "backtesting") {
    if ("backtesting" %in% names(all_results) && nrow(all_results$backtesting) > 0) {
      filename <- paste0("VaR_Performance_Summary_", output_type, ".csv")
      write.csv(all_results$backtesting, filename, row.names = FALSE)
      filenames$backtesting <- filename
    }
  }
  
  if (output_type == "all" || output_type == "stress_tests") {
    if ("stress_tests" %in% names(all_results) && nrow(all_results$stress_tests) > 0) {
      filename <- paste0("Stress_Test_Summary_", output_type, ".csv")
      write.csv(all_results$stress_tests, filename, row.names = FALSE)
      filenames$stress_tests <- filename
    }
  }
  
  cat("✓ CSV files saved\n")
  return(filenames)
}

# Save to RDS
save_to_rds <- function(all_results, output_type) {
  # Save consolidated results to RDS file
  
  filename <- paste0("Consolidated_Results_", output_type, ".rds")
  saveRDS(all_results, filename)
  
  cat("✓ RDS file saved:", filename, "\n")
  return(filename)
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Standardize backtesting columns
standardize_backtesting_columns <- function(data) {
  # Standardize column names for backtesting data
  
  # Map common column names to standard schema
  col_mapping <- list(
    "Model" = c("Model", "model", "MODEL"),
    "Asset" = c("Asset", "asset", "ASSET", "Symbol"),
    "Confidence_Level" = c("Confidence_Level", "confidence_level", "Confidence", "confidence"),
    "Total_Obs" = c("Total_Obs", "total_obs", "Observations", "obs"),
    "Expected_Rate" = c("Expected_Rate", "expected_rate", "Expected", "expected"),
    "Violations" = c("Violations", "violations", "Violation_Count"),
    "Violation_Rate" = c("Violation_Rate", "violation_rate", "Rate"),
    "Kupiec_PValue" = c("Kupiec_PValue", "kupiec_pvalue", "Kupiec_P_Value"),
    "Christoffersen_PValue" = c("Christoffersen_PValue", "christoffersen_pvalue"),
    "DQ_PValue" = c("DQ_PValue", "dq_pvalue", "DQ_P_Value")
  )
  
  # Rename columns
  for (standard_name in names(col_mapping)) {
    possible_names <- col_mapping[[standard_name]]
    for (possible_name in possible_names) {
      if (possible_name %in% colnames(data)) {
        colnames(data)[colnames(data) == possible_name] <- standard_name
        break
      }
    }
  }
  
  return(data)
}

# Standardize stress testing columns
standardize_stress_columns <- function(data) {
  # Standardize column names for stress testing data
  
  # Map common column names to standard schema
  col_mapping <- list(
    "Model" = c("Model", "model", "MODEL"),
    "Asset" = c("Asset", "asset", "ASSET", "Symbol"),
    "Scenario_Type" = c("Scenario_Type", "scenario_type", "Scenario", "scenario"),
    "Scenario_Name" = c("Scenario_Name", "scenario_name", "Name", "name"),
    "Convergence_Rate" = c("Convergence_Rate", "convergence_rate", "Convergence", "convergence"),
    "Pass_LB_Test" = c("Pass_LB_Test", "pass_lb_test", "LB_Test", "lb_test"),
    "Pass_ARCH_Test" = c("Pass_ARCH_Test", "pass_arch_test", "ARCH_Test", "arch_test"),
    "Total_Tests" = c("Total_Tests", "total_tests", "Tests", "tests"),
    "Robustness_Score" = c("Robustness_Score", "robustness_score", "Score", "score")
  )
  
  # Rename columns
  for (standard_name in names(col_mapping)) {
    possible_names <- col_mapping[[standard_name]]
    for (possible_name in possible_names) {
      if (possible_name %in% colnames(data)) {
        colnames(data)[colnames(data) == possible_name] <- standard_name
        break
      }
    }
  }
  
  return(data)
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Main execution function
main <- function() {
  # Parse command line arguments
  args <- commandArgs(trailingOnly = TRUE)
  
  # Default parameters
  output_type <- "all"
  output_format <- "excel"
  
  # Parse arguments
  i <- 1
  while (i <= length(args)) {
    if (args[i] == "--type" && i + 1 <= length(args)) {
      output_type <- args[i + 1]
      i <- i + 2
    } else if (args[i] == "--format" && i + 1 <= length(args)) {
      output_format <- args[i + 1]
      i <- i + 2
    } else {
      i <- i + 1
    }
  }
  
  # Run consolidation
  tryCatch({
    result <- consolidate_results(
      output_type = output_type,
      output_format = output_format
    )
    cat("Consolidation completed successfully\n")
  }, error = function(e) {
    cat("ERROR: Consolidation failed:", e$message, "\n")
    quit(status = 1)
  })
}

# Run main function if script is executed directly
if (!interactive() && length(commandArgs(trailingOnly = TRUE)) > 0) {
  main()
}
