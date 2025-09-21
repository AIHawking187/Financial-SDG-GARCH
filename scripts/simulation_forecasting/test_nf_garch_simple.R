#!/usr/bin/env Rscript
# Simple NF-GARCH Test Script
# Tests basic functionality without complex error handling

library(rugarch)
library(xts)
library(zoo)
library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)

# Set up error handling
options(warn = 1)

cat("=== SIMPLE NF-GARCH TEST ===\n")
set.seed(123)

# Load data
cat("Loading data...\n")
data <- read.csv("data/processed/raw (FX + EQ).csv", row.names = 1, stringsAsFactors = FALSE)
data$Date <- as.Date(rownames(data))
rownames(data) <- NULL

# Define assets
equity_tickers <- c("NVDA", "MSFT", "PG", "CAT", "WMT", "AMZN")
fx_names <- c("EURUSD", "GBPUSD", "GBPCNY", "USDZAR", "GBPZAR", "EURZAR")

# Calculate returns for one asset
test_asset <- "EURUSD"
if (test_asset %in% names(data)) {
  cat("Testing with asset:", test_asset, "\n")
  
  # Calculate returns
  returns <- c(NA, diff(log(data[[test_asset]])))
  returns <- returns[!is.na(returns)]
  
  cat("Returns calculated, length:", length(returns), "\n")
  cat("Mean return:", mean(returns), "\n")
  cat("SD return:", sd(returns), "\n")
  
  # Test simple GARCH fit
  cat("Testing simple GARCH fit...\n")
  
  tryCatch({
    # Create spec
    spec <- ugarchspec(
      mean.model = list(armaOrder = c(0, 0)),
      variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
      distribution.model = "norm"
    )
    
    # Fit model
    fit <- ugarchfit(spec = spec, data = returns)
    
    cat("✅ GARCH fit successful\n")
    cat("   AIC:", infocriteria(fit)[1], "\n")
    cat("   BIC:", infocriteria(fit)[2], "\n")
    cat("   LogLik:", fit@fit$LLH, "\n")
    
    # Test forecast
    cat("Testing forecast...\n")
    forecast <- ugarchforecast(fit, n.ahead = 10)
    cat("✅ Forecast successful\n")
    
  }, error = function(e) {
    cat("❌ GARCH fit failed:", e$message, "\n")
  })
  
} else {
  cat("❌ Test asset not found in data\n")
}

# Test NF residuals loading
cat("\nTesting NF residuals loading...\n")
nf_files <- list.files("nf_generated_residuals", pattern = "*.csv", full.names = TRUE)
cat("Found", length(nf_files), "NF residual files\n")

if (length(nf_files) > 0) {
  # Load first file
  tryCatch({
    nf_data <- read.csv(nf_files[1])
    cat("✅ NF residuals loaded successfully\n")
    cat("   File:", basename(nf_files[1]), "\n")
    cat("   Rows:", nrow(nf_data), "\n")
    cat("   Columns:", ncol(nf_data), "\n")
    
    if ("residual" %in% names(nf_data)) {
      cat("   Residual column found\n")
      cat("   Mean residual:", mean(nf_data$residual, na.rm = TRUE), "\n")
      cat("   SD residual:", sd(nf_data$residual, na.rm = TRUE), "\n")
    } else {
      cat("   Using first column as residuals\n")
      cat("   Mean residual:", mean(nf_data[[1]], na.rm = TRUE), "\n")
      cat("   SD residual:", sd(nf_data[[1]], na.rm = TRUE), "\n")
    }
    
  }, error = function(e) {
    cat("❌ Failed to load NF residuals:", e$message, "\n")
  })
} else {
  cat("❌ No NF residual files found\n")
}

cat("\n=== TEST COMPLETE ===\n")
