# Install R packages with CRAN mirror set
cat("=== INSTALLING R PACKAGES FOR FINANCIAL-SDG-GARCH ===\n")

# Set CRAN mirror
options(repos = c(CRAN = "https://cran.rstudio.com/"))
cat("✅ CRAN mirror set to: https://cran.rstudio.com/\n")

# List of required packages
required_packages <- c(
  "rugarch",
  "quantmod", 
  "xts",
  "PerformanceAnalytics",
  "FinTS",
  "tidyverse",
  "dplyr",
  "tidyr", 
  "stringr",
  "ggplot2",
  "openxlsx",
  "moments",
  "tseries",
  "forecast",
  "lmtest"
)

cat("Installing required R packages...\n")

# Install packages
for (pkg in required_packages) {
  cat("Installing", pkg, "...\n")
  tryCatch({
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
      install.packages(pkg, dependencies = TRUE)
      cat("  ✅", pkg, "installed successfully\n")
    } else {
      cat("  ✓", pkg, "already installed\n")
    }
  }, error = function(e) {
    cat("  ❌ Error installing", pkg, ":", e$message, "\n")
  })
}

# Check installation
cat("\n=== INSTALLATION CHECK ===\n")
missing_packages <- character(0)

for (pkg in required_packages) {
  if (require(pkg, character.only = TRUE, quietly = TRUE)) {
    cat("✅", pkg, "is available\n")
  } else {
    cat("❌", pkg, "is missing\n")
    missing_packages <- c(missing_packages, pkg)
  }
}

# Environment check
cat("\n=== ENVIRONMENT CHECK ===\n")
cat("R version:", R.version.string, "\n")
cat("Platform:", R.version$platform, "\n")
cat("Working directory:", getwd(), "\n")

# Check if data file exists
if (file.exists("./data/processed/raw (FX + EQ).csv")) {
  cat("✅ Data file found\n")
} else {
  cat("❌ Data file not found: ./data/processed/raw (FX + EQ).csv\n")
}

# Check if required directories exist
required_dirs <- c("scripts", "outputs", "results", "nf_generated_residuals")
for (dir in required_dirs) {
  if (dir.exists(dir)) {
    cat("✅ Directory exists:", dir, "\n")
  } else {
    cat("❌ Directory missing:", dir, "\n")
  }
}

# Summary
cat("\n=== INSTALLATION SUMMARY ===\n")
if (length(missing_packages) == 0) {
  cat("🎉 ALL PACKAGES INSTALLED SUCCESSFULLY!\n")
  cat("Your environment is ready to run the NF-GARCH pipeline.\n")
  cat("\nNext steps:\n")
  cat("1. Run quick test: Rscript scripts/simulation_forecasting/simulate_nf_garch_quick_test.R\n")
  cat("2. Run full pipeline: run_all.bat (Windows) or ./run_all.sh (Linux/Mac)\n")
} else {
  cat("⚠️  Some packages are missing:", paste(missing_packages, collapse = ", "), "\n")
  cat("Please install them manually or check your internet connection.\n")
}

