# Debug script to verify NF residuals loading
# Run this before running script 4 to ensure everything is working

setwd("C:/Users/dullz/OneDrive/Documents/1. Education/3. University - Masters/Financial-SDG-GARCH")

# Load required libraries
library(dplyr)
library(stringr)

# Check if nf_generated_residuals directory exists
if (!dir.exists("nf_generated_residuals")) {
  stop("❌ nf_generated_residuals directory not found!")
}

# List all NF residual files
nf_files <- list.files("nf_generated_residuals", pattern = "*.csv", full.names = TRUE)
cat("📁 Found", length(nf_files), "NF residual files\n\n")

# Parse model and asset from file names
nf_residuals_map <- list()
for (f in nf_files) {
  fname <- basename(f)
  # Remove .csv extension and extract the key
  key <- stringr::str_replace(fname, "\\.csv$", "")
  
  # Read the residuals
  residuals_data <- read.csv(f)
  
  # Check if 'residual' column exists, otherwise use first column
  if ("residual" %in% names(residuals_data)) {
    nf_residuals_map[[key]] <- residuals_data$residual
  } else {
    nf_residuals_map[[key]] <- residuals_data[[1]]  # Use first column
  }
  
  cat("✅ Loaded:", key, "(", length(nf_residuals_map[[key]]), "residuals)\n")
}

cat("\n📊 Summary of loaded NF residuals:\n")
cat("Total keys:", length(names(nf_residuals_map)), "\n")

# Test key matching for specific assets and models
test_assets <- c("USDZAR", "EURUSD", "NVDA", "AMZN")
test_models <- c("sGARCH_norm", "sGARCH_sstd", "eGARCH", "gjrGARCH", "TGARCH")

cat("\n🔍 Testing key matching for specific assets and models:\n")
for (asset in test_assets) {
  for (model in test_models) {
    # Try different key patterns
    possible_keys <- c(
      paste0(model, "_fx_", asset, "_residuals_synthetic"),
      paste0("fx_", asset, "_residuals_", model, "_residuals_synthetic_synthetic"),
      paste0(model, "_", asset, "_residuals_synthetic"),
      paste0(model, "_equity_", asset, "_residuals_synthetic"),
      paste0("equity_", asset, "_residuals_", model, "_residuals_synthetic_synthetic")
    )
    
    found_key <- NULL
    for (k in possible_keys) {
      if (k %in% names(nf_residuals_map)) {
        found_key <- k
        break
      }
    }
    
    if (!is.null(found_key)) {
      cat("✅", asset, model, "→", found_key, "\n")
    } else {
      cat("❌", asset, model, "→ No match found\n")
    }
  }
}

# Show sample of residuals for verification
cat("\n📈 Sample of residuals from first few files:\n")
for (i in 1:min(5, length(names(nf_residuals_map)))) {
  key <- names(nf_residuals_map)[i]
  residuals <- nf_residuals_map[[key]]
  cat(key, ":", "mean =", round(mean(residuals, na.rm = TRUE), 4), 
      "sd =", round(sd(residuals, na.rm = TRUE), 4),
      "length =", length(residuals), "\n")
}

cat("\n🎯 Ready to run script 4! The NF residuals should now be properly loaded.\n")
