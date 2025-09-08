#!/usr/bin/env Rscript
# Safety Functions for NF-GARCH Pipeline
# Provides essential safety checks and utility functions

# Set global options for safety
options(warn = 1)  # Show warnings immediately
options(error = function() {
  cat("ERROR: Pipeline execution failed\n")
  traceback()
  quit(status = 1)
})

# Safety check functions
check_required_packages <- function() {
  required_packages <- c(
    "rugarch", "xts", "zoo", "dplyr", "tidyr", "ggplot2", 
    "PerformanceAnalytics", "forecast", "moments", "openxlsx",
    "stringr", "readxl", "parallel", "TTR", "quantmod"
  )
  
  missing_packages <- c()
  for (pkg in required_packages) {
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
      missing_packages <- c(missing_packages, pkg)
    }
  }
  
  if (length(missing_packages) > 0) {
    stop("Missing required packages: ", paste(missing_packages, collapse = ", "))
  }
  
  cat("✓ All required packages are available\n")
}

check_data_files <- function() {
  required_files <- c(
    "data/processed/raw (FX + EQ).csv",
    "data/processed/ts_cv_folds/"
  )
  
  missing_files <- c()
  for (file in required_files) {
    if (!file.exists(file)) {
      missing_files <- c(missing_files, file)
    }
  }
  
  if (length(missing_files) > 0) {
    warning("Missing data files: ", paste(missing_files, collapse = ", "))
  } else {
    cat("✓ All required data files are available\n")
  }
}

check_output_directories <- function() {
  required_dirs <- c(
    "outputs",
    "outputs/model_eval",
    "outputs/model_eval/figures",
    "outputs/model_eval/tables",
    "outputs/var_backtest",
    "outputs/var_backtest/figures", 
    "outputs/var_backtest/tables",
    "outputs/stress_tests",
    "outputs/stress_tests/figures",
    "outputs/stress_tests/tables",
    "outputs/eda",
    "outputs/eda/figures",
    "outputs/eda/tables"
  )
  
  for (dir in required_dirs) {
    if (!dir.exists(dir)) {
      dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    }
  }
  
  cat("✓ Output directories created/verified\n")
}

# Memory and performance safety
set_memory_limits <- function() {
  # Set memory limits for large datasets
  options(max.print = 1000)
  options(width = 120)
  
  # Set parallel processing limits
  if (require(parallel, quietly = TRUE)) {
    num_cores <- min(detectCores() - 1, 4)  # Leave one core free
    options(mc.cores = num_cores)
    cat("✓ Parallel processing set to", num_cores, "cores\n")
  }
}

# Data validation functions
validate_data <- function(data, name = "data") {
  if (is.null(data)) {
    stop("Data is NULL: ", name)
  }
  
  if (nrow(data) == 0) {
    warning("Data has 0 rows: ", name)
    return(FALSE)
  }
  
  if (ncol(data) == 0) {
    warning("Data has 0 columns: ", name)
    return(FALSE)
  }
  
  # Check for all NA columns
  na_cols <- sapply(data, function(x) all(is.na(x)))
  if (any(na_cols)) {
    warning("Columns with all NA values: ", paste(names(data)[na_cols], collapse = ", "))
  }
  
  cat("✓ Data validation passed for:", name, "(", nrow(data), "rows,", ncol(data), "cols)\n")
  return(TRUE)
}

# Model convergence safety
check_model_convergence <- function(fit, model_name = "model") {
  if (is.null(fit)) {
    warning("Model fit is NULL:", model_name)
    return(FALSE)
  }
  
  # Check for convergence
  if (exists("convergence", where = fit)) {
    if (fit$convergence != 0) {
      warning("Model did not converge:", model_name, "convergence code:", fit$convergence)
      return(FALSE)
    }
  }
  
  # Check for valid coefficients
  if (exists("coef", where = fit)) {
    if (any(is.na(fit$coef))) {
      warning("Model has NA coefficients:", model_name)
      return(FALSE)
    }
  }
  
  cat("✓ Model convergence check passed for:", model_name, "\n")
  return(TRUE)
}

# File I/O safety
safe_save <- function(data, file_path, type = "csv") {
  tryCatch({
    dir.create(dirname(file_path), recursive = TRUE, showWarnings = FALSE)
    
    if (type == "csv") {
      write.csv(data, file_path, row.names = FALSE)
    } else if (type == "rds") {
      saveRDS(data, file_path)
    } else if (type == "xlsx") {
      if (require(openxlsx, quietly = TRUE)) {
        wb <- createWorkbook()
        addWorksheet(wb, "Data")
        writeData(wb, "Data", data)
        saveWorkbook(wb, file_path, overwrite = TRUE)
      } else {
        stop("openxlsx package required for Excel files")
      }
    }
    
    cat("✓ Data saved successfully to:", file_path, "\n")
  }, error = function(e) {
    stop("Failed to save data to", file_path, ":", e$message)
  })
}

safe_load <- function(file_path, type = "csv") {
  tryCatch({
    if (!file.exists(file_path)) {
      stop("File does not exist:", file_path)
    }
    
    if (type == "csv") {
      data <- read.csv(file_path, stringsAsFactors = FALSE)
    } else if (type == "rds") {
      data <- readRDS(file_path)
    } else if (type == "xlsx") {
      if (require(openxlsx, quietly = TRUE)) {
        data <- read.xlsx(file_path)
      } else {
        stop("openxlsx package required for Excel files")
      }
    }
    
    cat("✓ Data loaded successfully from:", file_path, "\n")
    return(data)
  }, error = function(e) {
    stop("Failed to load data from", file_path, ":", e$message)
  })
}

# Pipeline initialization
initialize_pipeline <- function() {
  cat("=== INITIALIZING NF-GARCH PIPELINE ===\n")
  
  # Set seeds for reproducibility
  set.seed(123)
  Sys.setenv(CUDA_VISIBLE_DEVICES = "")
  Sys.setenv(TORCH_CUDNN_V8_API_DISABLED = "1")
  
  # Run safety checks
  check_required_packages()
  check_data_files()
  check_output_directories()
  set_memory_limits()
  
  cat("✓ Pipeline initialization complete\n")
}

# Error recovery
recover_from_error <- function(error_msg, context = "") {
  cat("ERROR in", context, ":", error_msg, "\n")
  cat("Attempting to recover...\n")
  
  # Clean up any temporary files
  temp_files <- list.files(pattern = "temp_", full.names = TRUE)
  if (length(temp_files) > 0) {
    file.remove(temp_files)
    cat("✓ Cleaned up temporary files\n")
  }
  
  # Return FALSE to indicate error occurred
  return(FALSE)
}

# Export functions for use in other scripts
if (!interactive()) {
  cat("✓ Safety functions loaded\n")
}

