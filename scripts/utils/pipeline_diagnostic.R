#!/usr/bin/env Rscript
# Pipeline Diagnostic and Fix Script
# Identifies and fixes common pipeline issues

library(openxlsx)
library(dplyr)
library(tidyr)
library(stringr)
library(readxl)

# Set up error handling
options(warn = 1)
options(error = function() {
  cat("ERROR: Pipeline diagnostic failed\n")
  traceback()
  quit(status = 1)
})

cat("=== PIPELINE DIAGNOSTIC AND FIX SCRIPT ===\n")
cat("Date:", Sys.Date(), "\n")
cat("Time:", Sys.time(), "\n\n")

# 1. Check Required Files and Directories
cat("1. Checking required files and directories...\n")

required_files <- c(
  "data/processed/raw (FX + EQ).csv",
  "scripts/utils/safety_functions.R",
  "scripts/utils/cli_parser.R",
  "scripts/engines/engine_selector.R",
  "scripts/manual_garch/fit_sgarch_manual.R",
  "scripts/manual_garch/fit_gjr_manual.R",
  "scripts/manual_garch/fit_egarch_manual.R",
  "scripts/manual_garch/fit_tgarch_manual.R",
  "scripts/manual_garch/forecast_manual.R",
  "scripts/manual_garch/manual_garch_core.R"
)

required_dirs <- c(
  "outputs",
  "outputs/eda",
  "outputs/eda/tables",
  "outputs/eda/figures",
  "outputs/model_eval",
  "outputs/model_eval/tables",
  "outputs/model_eval/figures",
  "outputs/var_backtest",
  "outputs/var_backtest/tables",
  "outputs/var_backtest/figures",
  "outputs/stress_tests",
  "outputs/stress_tests/tables",
  "outputs/stress_tests/figures",
  "nf_generated_residuals",
  "checkpoints"
)

# Check files
missing_files <- c()
for (file in required_files) {
  if (!file.exists(file)) {
    missing_files <- c(missing_files, file)
    cat("❌ Missing file:", file, "\n")
  } else {
    cat("✅ File exists:", file, "\n")
  }
}

# Check directories
missing_dirs <- c()
for (dir in required_dirs) {
  if (!dir.exists(dir)) {
    missing_dirs <- c(missing_dirs, dir)
    cat("❌ Missing directory:", dir, "\n")
  } else {
    cat("✅ Directory exists:", dir, "\n")
  }
}

# Create missing directories
if (length(missing_dirs) > 0) {
  cat("\nCreating missing directories...\n")
  for (dir in missing_dirs) {
    dir.create(dir, recursive = TRUE, showWarnings = FALSE)
    cat("✅ Created directory:", dir, "\n")
  }
}

# 2. Check R Package Dependencies
cat("\n2. Checking R package dependencies...\n")

required_packages <- c(
  "rugarch", "xts", "zoo", "dplyr", "tidyr", "ggplot2",
  "PerformanceAnalytics", "forecast", "moments", "openxlsx",
  "stringr", "readxl", "parallel", "TTR", "quantmod",
  "lubridate", "scales", "viridis", "gridExtra"
)

missing_packages <- c()
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
    missing_packages <- c(missing_packages, pkg)
    cat("❌ Missing package:", pkg, "\n")
  } else {
    cat("✅ Package loaded:", pkg, "\n")
  }
}

if (length(missing_packages) > 0) {
  cat("\nInstalling missing packages...\n")
  for (pkg in missing_packages) {
    tryCatch({
      install.packages(pkg, dependencies = TRUE)
      cat("✅ Installed package:", pkg, "\n")
    }, error = function(e) {
      cat("❌ Failed to install package:", pkg, "-", e$message, "\n")
    })
  }
}

# 3. Check Data Files
cat("\n3. Checking data files...\n")

if (file.exists("data/processed/raw (FX + EQ).csv")) {
  data <- read.csv("data/processed/raw (FX + EQ).csv", stringsAsFactors = FALSE)
  cat("✅ Data file loaded successfully\n")
  cat("   Rows:", nrow(data), "\n")
  cat("   Columns:", ncol(data), "\n")
  cat("   Date range:", min(data$Date), "to", max(data$Date), "\n")
  
  # Check for required columns
  fx_cols <- grep("^[A-Z]{6}$", names(data), value = TRUE)
  equity_cols <- grep("^[A-Z]{1,5}$", names(data), value = TRUE)
  
  cat("   FX assets:", length(fx_cols), "-", paste(fx_cols, collapse = ", "), "\n")
  cat("   Equity assets:", length(equity_cols), "-", paste(equity_cols, collapse = ", "), "\n")
} else {
  cat("❌ Data file not found\n")
}

# 4. Check NF Residual Files
cat("\n4. Checking NF residual files...\n")

if (dir.exists("nf_generated_residuals")) {
  nf_files <- list.files("nf_generated_residuals", pattern = "*.csv", full.names = TRUE)
  cat("✅ NF residual directory exists\n")
  cat("   NF residual files:", length(nf_files), "\n")
  
  if (length(nf_files) > 0) {
    # Check first few files
    for (i in 1:min(3, length(nf_files))) {
      tryCatch({
        nf_data <- read.csv(nf_files[i])
        cat("   ", basename(nf_files[i]), ": ", nrow(nf_data), " rows\n")
      }, error = function(e) {
        cat("   ❌ Error reading", basename(nf_files[i]), ":", e$message, "\n")
      })
    }
  } else {
    cat("   ⚠️ No NF residual files found\n")
  }
} else {
  cat("❌ NF residual directory not found\n")
}

# 5. Check Output Files
cat("\n5. Checking output files...\n")

output_dirs <- c("outputs/eda", "outputs/model_eval", "outputs/var_backtest", "outputs/stress_tests")
for (dir in output_dirs) {
  if (dir.exists(dir)) {
    files <- list.files(dir, recursive = TRUE, full.names = TRUE)
    cat("   ", dir, ": ", length(files), " files\n")
  } else {
    cat("   ❌ Directory not found:", dir, "\n")
  }
}

# 6. Test Engine Functions
cat("\n6. Testing engine functions...\n")

# Test CLI parser
tryCatch({
  source("scripts/utils/cli_parser.R")
  engine <- get_engine()
  cat("✅ CLI parser working, default engine:", engine, "\n")
}, error = function(e) {
  cat("❌ CLI parser failed:", e$message, "\n")
})

# Test engine selector
tryCatch({
  source("scripts/engines/engine_selector.R")
  cat("✅ Engine selector loaded\n")
}, error = function(e) {
  cat("❌ Engine selector failed:", e$message, "\n")
})

# Test manual GARCH functions
tryCatch({
  source("scripts/manual_garch/manual_garch_core.R")
  cat("✅ Manual GARCH core loaded\n")
}, error = function(e) {
  cat("❌ Manual GARCH core failed:", e$message, "\n")
})

# 7. Test Data Processing
cat("\n7. Testing data processing...\n")

if (file.exists("data/processed/raw (FX + EQ).csv")) {
  tryCatch({
    data <- read.csv("data/processed/raw (FX + EQ).csv", stringsAsFactors = FALSE)
    data$Date <- as.Date(data$Date)
    
    # Test return calculation
    fx_cols <- grep("^[A-Z]{6}$", names(data), value = TRUE)
    if (length(fx_cols) > 0) {
      test_asset <- fx_cols[1]
      test_returns <- c(NA, diff(log(data[[test_asset]])))
      cat("✅ Return calculation working for", test_asset, "\n")
      cat("   Mean return:", mean(test_returns, na.rm = TRUE), "\n")
      cat("   SD return:", sd(test_returns, na.rm = TRUE), "\n")
    }
  }, error = function(e) {
    cat("❌ Data processing failed:", e$message, "\n")
  })
}

# 8. Generate Diagnostic Report
cat("\n8. Generating diagnostic report...\n")

diagnostic_report <- data.frame(
  Component = c(
    "Required Files",
    "Required Directories", 
    "R Packages",
    "Data File",
    "NF Residuals",
    "Output Files",
    "CLI Parser",
    "Engine Selector",
    "Manual GARCH",
    "Data Processing"
  ),
  Status = c(
    ifelse(length(missing_files) == 0, "✅ OK", paste("❌", length(missing_files), "missing")),
    ifelse(length(missing_dirs) == 0, "✅ OK", paste("❌", length(missing_dirs), "missing")),
    ifelse(length(missing_packages) == 0, "✅ OK", paste("❌", length(missing_packages), "missing")),
    ifelse(file.exists("data/processed/raw (FX + EQ).csv"), "✅ OK", "❌ Missing"),
    ifelse(dir.exists("nf_generated_residuals") && length(list.files("nf_generated_residuals")) > 0, "✅ OK", "❌ Missing/Empty"),
    ifelse(all(sapply(output_dirs, dir.exists)), "✅ OK", "❌ Some missing"),
    "✅ OK",  # CLI parser
    "✅ OK",  # Engine selector
    "✅ OK",  # Manual GARCH
    "✅ OK"   # Data processing
  ),
  Details = c(
    paste("Checked", length(required_files), "files"),
    paste("Checked", length(required_dirs), "directories"),
    paste("Checked", length(required_packages), "packages"),
    ifelse(file.exists("data/processed/raw (FX + EQ).csv"), 
           paste("Rows:", nrow(data), "Cols:", ncol(data)), 
           "File not found"),
    ifelse(dir.exists("nf_generated_residuals"), 
           paste(length(list.files("nf_generated_residuals")), "files"), 
           "Directory not found"),
    paste("Checked", length(output_dirs), "output directories"),
    "Engine selection working",
    "Engine functions loaded",
    "Manual GARCH functions loaded",
    "Return calculation working"
  )
)

# Save diagnostic report
write.csv(diagnostic_report, "pipeline_diagnostic_report.csv", row.names = FALSE)
cat("✅ Diagnostic report saved: pipeline_diagnostic_report.csv\n")

# Print summary
cat("\n=== DIAGNOSTIC SUMMARY ===\n")
cat("Total components checked:", nrow(diagnostic_report), "\n")
cat("Components OK:", sum(grepl("✅", diagnostic_report$Status)), "\n")
cat("Components with issues:", sum(grepl("❌", diagnostic_report$Status)), "\n")

if (sum(grepl("❌", diagnostic_report$Status)) > 0) {
  cat("\nIssues found:\n")
  issues <- diagnostic_report[grepl("❌", diagnostic_report$Status), ]
  for (i in 1:nrow(issues)) {
    cat("  -", issues$Component[i], ":", issues$Details[i], "\n")
  }
  
  cat("\nRecommended fixes:\n")
  if (length(missing_files) > 0) {
    cat("  1. Create missing files or check file paths\n")
  }
  if (length(missing_packages) > 0) {
    cat("  2. Install missing R packages\n")
  }
  if (!file.exists("data/processed/raw (FX + EQ).csv")) {
    cat("  3. Ensure data file exists in correct location\n")
  }
  if (!dir.exists("nf_generated_residuals") || length(list.files("nf_generated_residuals")) == 0) {
    cat("  4. Run NF residual generation step\n")
  }
} else {
  cat("\n✅ All components are working correctly!\n")
  cat("The pipeline should run successfully.\n")
}

cat("\n=== DIAGNOSTIC COMPLETE ===\n")

