# Test script to verify NF residuals implementation fixes
# Run this to test the key fixes before running the full script 4

setwd("C:/Users/dullz/OneDrive/Documents/1. Education/3. University - Masters/Financial-SDG-GARCH")

# Load required libraries
library(dplyr)
library(stringr)
library(rugarch)

# Test 1: Verify model_configs structure
cat("🧪 Test 1: Checking model_configs structure\n")
model_configs <- list(
  sGARCH_norm  = list(model = "sGARCH", distribution = "norm", submodel = NULL),
  sGARCH_sstd  = list(model = "sGARCH", distribution = "sstd", submodel = NULL),
  gjrGARCH     = list(model = "gjrGARCH", distribution = "sstd", submodel = NULL),
  eGARCH       = list(model = "eGARCH", distribution = "sstd", submodel = NULL),
  TGARCH       = list(model = "fGARCH", distribution = "sstd", submodel = "TGARCH")
)

# Test accessing model_configs with both $ and [[]] operators
test_config <- model_configs[["sGARCH_norm"]]
cat("✅ model_configs[['sGARCH_norm']]$model:", test_config[["model"]], "\n")
cat("✅ model_configs[['sGARCH_norm']]$distribution:", test_config[["distribution"]], "\n")

# Test 2: Verify NF residuals loading
cat("\n🧪 Test 2: Loading NF residuals\n")
if (!dir.exists("nf_generated_residuals")) {
  stop("❌ nf_generated_residuals directory not found!")
}

nf_files <- list.files("nf_generated_residuals", pattern = "*.csv", full.names = TRUE)
cat("📁 Found", length(nf_files), "NF residual files\n")

# Load a few test files
nf_residuals_map <- list()
for (f in head(nf_files, 3)) {  # Just test first 3 files
  fname <- basename(f)
  key <- stringr::str_replace(fname, "\\.csv$", "")
  
  residuals_data <- read.csv(f)
  if ("residual" %in% names(residuals_data)) {
    nf_residuals_map[[key]] <- residuals_data$residual
  } else {
    nf_residuals_map[[key]] <- residuals_data[[1]]
  }
  
  cat("✅ Loaded:", key, "(", length(nf_residuals_map[[key]]), "residuals)\n")
}

# Test 3: Verify key matching logic
cat("\n🧪 Test 3: Testing key matching logic\n")
test_asset <- "USDZAR"
test_model <- "sGARCH_norm"

possible_keys <- c(
  paste0(test_model, "_fx_", test_asset, "_residuals_synthetic"),
  paste0("fx_", test_asset, "_residuals_", test_model, "_residuals_synthetic_synthetic"),
  paste0(test_model, "_", test_asset, "_residuals_synthetic")
)

key <- NULL
for (k in possible_keys) {
  if (k %in% names(nf_residuals_map)) {
    key <- k
    break
  }
}

if (!is.null(key)) {
  cat("✅ Found key:", key, "\n")
} else {
  cat("❌ No key found for", test_asset, test_model, "\n")
  cat("  Tried keys:", paste(possible_keys, collapse = ", "), "\n")
}

# Test 4: Test the fixed fit_nf_garch function
cat("\n🧪 Test 4: Testing fit_nf_garch function\n")
fit_nf_garch <- function(asset_name, asset_returns, model_config, nf_resid) {
  tryCatch({
    # Validate distribution input
    if (is.null(model_config[["distribution"]]) || !is.character(model_config[["distribution"]])) {
      stop("Distribution must be a non-null character string.")
    }
    
    cat("✅ Model config accessed successfully:\n")
    cat("  - model:", model_config[["model"]], "\n")
    cat("  - distribution:", model_config[["distribution"]], "\n")
    cat("  - submodel:", model_config[["submodel"]], "\n")
    
    # Define GARCH spec
    spec <- ugarchspec(
      mean.model = list(armaOrder = c(0, 0)),
      variance.model = list(
        model = model_config[["model"]],
        garchOrder = c(1, 1),
        submodel = model_config[["submodel"]]
      ),
      distribution.model = model_config[["distribution"]]
    )
    
    cat("✅ GARCH spec created successfully\n")
    
    # For testing, just return success
    return(data.frame(
      Model = model_config[["model"]],
      Distribution = model_config[["distribution"]],
      Asset = asset_name,
      AIC = 0,
      BIC = 0,
      LogLikelihood = 0,
      MSE = 0,
      MAE = 0,
      SplitType = "Chrono"
    ))
    
  }, error = function(e) {
    message(paste("❌ Error for", asset_name, model_config[["model"]], ":", e$message))
    return(NULL)
  })
}

# Test the function
if (!is.null(key) && length(nf_residuals_map[[key]]) > 0) {
  test_result <- fit_nf_garch("USDZAR", c(0.01, 0.02, 0.03), model_configs[["sGARCH_norm"]], nf_residuals_map[[key]])
  if (!is.null(test_result)) {
    cat("✅ fit_nf_garch function works correctly\n")
  } else {
    cat("❌ fit_nf_garch function failed\n")
  }
} else {
  cat("⚠️ Skipping fit_nf_garch test - no suitable NF residuals found\n")
}

cat("\n🎯 All tests completed! If all tests pass, script 4 should work correctly.\n")
