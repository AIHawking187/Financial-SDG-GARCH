#!/usr/bin/env Rscript
# R Environment Setup and Validation Script
# This script helps set up the R environment and diagnose common issues

cat("=== Financial-SDG-GARCH R Environment Setup ===\n\n")

# Check R version
cat("1. R Version Check:\n")
cat("R version:", R.version.string, "\n")
if (as.numeric(R.version$major) < 4) {
  cat("WARNING: R version should be >= 4.0.0\n")
} else {
  cat("✓ R version is compatible\n")
}
cat("\n")

# Check if running from Rscript
cat("2. Execution Environment:\n")
if (interactive()) {
  cat("Running in interactive mode\n")
} else {
  cat("Running via Rscript ✓\n")
}
cat("\n")

# Required packages
required_packages <- c(
  "rugarch", "xts", "dplyr", "tidyr", "ggplot2", "quantmod",
  "tseries", "PerformanceAnalytics", "FinTS", "openxlsx",
  "stringr", "forecast", "transport", "fmsb", "moments"
)

cat("3. Package Installation Check:\n")
missing_packages <- c()
installed_packages <- c()

for (pkg in required_packages) {
  if (require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat("✓", pkg, "is installed\n")
    installed_packages <- c(installed_packages, pkg)
  } else {
    cat("✗", pkg, "is NOT installed\n")
    missing_packages <- c(missing_packages, pkg)
  }
}

cat("\n4. Installing Missing Packages:\n")
if (length(missing_packages) > 0) {
  cat("Installing missing packages...\n")
  for (pkg in missing_packages) {
    cat("Installing", pkg, "...\n")
    tryCatch({
      install.packages(pkg, dependencies = TRUE, quiet = TRUE)
      cat("✓", pkg, "installed successfully\n")
    }, error = function(e) {
      cat("✗ Failed to install", pkg, ":", e$message, "\n")
    })
  }
} else {
  cat("All required packages are already installed ✓\n")
}

cat("\n5. Package Loading Test:\n")
failed_loads <- c()
for (pkg in required_packages) {
  tryCatch({
    library(pkg, character.only = TRUE, quietly = TRUE)
    cat("✓", pkg, "loads successfully\n")
  }, error = function(e) {
    cat("✗", pkg, "failed to load:", e$message, "\n")
    failed_loads <- c(failed_loads, pkg)
  })
}

cat("\n6. System Information:\n")
cat("Platform:", R.version$platform, "\n")
cat("Operating System:", Sys.info()["sysname"], "\n")
cat("R Home Directory:", R.home(), "\n")
cat("Working Directory:", getwd(), "\n")

# Check if Rscript is in PATH
cat("\n7. Rscript Availability Check:\n")
rscript_check <- tryCatch({
  system("Rscript --version", intern = TRUE, ignore.stderr = TRUE)
  cat("✓ Rscript is available in PATH\n")
  TRUE
}, error = function(e) {
  cat("✗ Rscript not found in PATH\n")
  cat("  This may cause 'R command not found' errors\n")
  cat("  Solution: Add R installation directory to PATH\n")
  FALSE
})

cat("\n8. File Path Validation:\n")
required_files <- c(
  "./data/raw/raw (FX).csv",
  "./data/raw/raw (EQ).csv", 
  "./data/processed/raw (FX + EQ).csv"
)

for (file_path in required_files) {
  if (file.exists(file_path)) {
    cat("✓", file_path, "exists\n")
  } else {
    cat("✗", file_path, "NOT found\n")
  }
}

cat("\n=== Setup Summary ===\n")
if (length(missing_packages) == 0 && length(failed_loads) == 0 && rscript_check) {
  cat("✓ R environment is properly configured\n")
  cat("✓ All required packages are installed and loadable\n")
  cat("✓ Rscript is available\n")
  cat("\nYou can now run the Financial-SDG-GARCH pipeline!\n")
} else {
  cat("⚠ Some issues were found:\n")
  if (length(missing_packages) > 0) {
    cat("- Missing packages:", paste(missing_packages, collapse = ", "), "\n")
  }
  if (length(failed_loads) > 0) {
    cat("- Failed to load packages:", paste(failed_loads, collapse = ", "), "\n")
  }
  if (!rscript_check) {
    cat("- Rscript not available in PATH\n")
  }
  cat("\nPlease resolve these issues before running the pipeline.\n")
}

cat("\n=== Troubleshooting Tips ===\n")
cat("1. If Rscript not found: Add R installation directory to PATH\n")
cat("2. If packages fail to install: Check internet connection and CRAN access\n")
cat("3. If packages fail to load: Restart R session and try again\n")
cat("4. On Windows: Ensure R is installed in a path without spaces\n")
cat("5. Alternative execution: Use 'R --slave -e \"source('script.R')\"' instead of Rscript\n")
