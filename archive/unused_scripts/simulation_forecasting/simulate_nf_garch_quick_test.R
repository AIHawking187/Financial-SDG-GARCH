# Quick Test Version of NFGARCH Simulation Script
# This is a reduced version for testing if everything works

cat("Starting NFGARCH Quick Test...\n")
set.seed(123)

# Libraries
library(openxlsx)
library(quantmod)
library(tseries)
library(rugarch)
library(xts)
library(PerformanceAnalytics)
library(FinTS)
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)

#### Import the FX + EQ price data ####

# Read CSV with Date in first column (row names)
raw_price_data <- read.csv("./data/processed/raw (FX + EQ).csv", row.names = 1)

# Convert row names into a Date column
raw_price_data$Date <- lubridate::ymd(rownames(raw_price_data))
rownames(raw_price_data) <- NULL

# Move Date to the front
raw_price_data <- raw_price_data %>% dplyr::select(Date, everything())

#### Clean the Price data ####

# Extract date vector
date_index <- raw_price_data$Date

# Remove date column from data matrix
price_data_matrix <- raw_price_data[, !(names(raw_price_data) %in% "Date")]

# QUICK TEST: Use only 2 assets for testing
equity_tickers <- c("NVDA", "AMZN")  # Reduced from 6 to 2
fx_names <- c("EURUSD", "USDZAR")    # Reduced from 6 to 2

# Split into equity and FX price matrices
equity_xts <- lapply(equity_tickers, function(ticker) {
  xts(price_data_matrix[[ticker]], order.by = date_index)
})
names(equity_xts) <- equity_tickers

fx_xts <- lapply(fx_names, function(ticker) {
  xts(price_data_matrix[[ticker]], order.by = date_index)
})
names(fx_xts) <- fx_names

#### Calculate Returns on FX and Equity data ####

# Calculate returns
equity_returns <- lapply(equity_xts, function(x) CalculateReturns(x)[-1, ])
fx_returns <- lapply(fx_xts, function(x) diff(log(x))[-1, ])

#### Model Generator ####

generate_spec <- function(model, dist = "sstd", submodel = NULL) {
  ugarchspec(
    mean.model = list(armaOrder = c(0,0)),
    variance.model = list(model = model, garchOrder = c(1,1), submodel = submodel),
    distribution.model = dist
  )
}

# QUICK TEST: Use ALL 5 model configurations
model_configs <- list(
  sGARCH_norm = list(model = "sGARCH", distribution = "norm", submodel = NULL),
  sGARCH_sstd = list(model = "sGARCH", distribution = "sstd", submodel = NULL),
  gjrGARCH = list(model = "gjrGARCH", distribution = "sstd", submodel = NULL),
  eGARCH = list(model = "eGARCH", distribution = "sstd", submodel = NULL),
  TGARCH = list(model = "fGARCH", distribution = "sstd", submodel = "TGARCH")
)

#### Load synthetic residuals ####

# Load all synthetic residual files from Python
nf_files <- list.files("nf_generated_residuals", pattern = "*.csv", full.names = TRUE)

# Parse model and asset from file names
nf_residuals_map <- list()
for (f in nf_files) {
  fname <- basename(f)
  # Remove .csv extension and extract the key
  key <- stringr::str_replace(fname, "\\.csv$", "")
  
  # Debug: Print the key being created
  cat("Loading NF residuals for key:", key, "\n")
  
  # Read the residuals
  residuals_data <- read.csv(f)
  
  # Check if 'residual' column exists, otherwise use first column
  if ("residual" %in% names(residuals_data)) {
    nf_residuals_map[[key]] <- residuals_data$residual
  } else {
    nf_residuals_map[[key]] <- residuals_data[[1]]  # Use first column
  }
  
  # Debug: Print the length of loaded residuals
  cat("  Loaded", length(nf_residuals_map[[key]]), "residuals\n")
}

# Debug: Print all available keys
cat("\nAvailable NF residual keys:\n")
for (key in names(nf_residuals_map)) {
  cat("  -", key, "(", length(nf_residuals_map[[key]]), "residuals)\n")
}

#### Source the manual NF-GARCH simulator ####

source("scripts/utils/utils_nf_garch.R")

#### Define an NF-GARCH Fitting Function ####

fit_nf_garch <- function(asset_name, asset_returns, model_config, nf_resid) {
  tryCatch({
    # Debug: Check what type of object model_config is
    cat("DEBUG: model_config class:", class(model_config), "\n")
    cat("DEBUG: model_config type:", typeof(model_config), "\n")
    
    # Ensure model_config is a list
    if (!is.list(model_config)) {
      stop("model_config must be a list")
    }
    
    # Validate distribution input
    if (is.null(model_config[["distribution"]]) || !is.character(model_config[["distribution"]])) {
      stop("Distribution must be a non-null character string.")
    }
    
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
    
    # Fit GARCH
    fit <- ugarchfit(spec = spec, data = asset_returns)
    
    # Setup simulation - QUICK TEST: Use smaller simulation size
    n_sim <- min(50, floor(length(asset_returns) / 8))  # Very small for testing
    if (length(nf_resid) < n_sim) {
      warning(paste("⚠️ NF residuals too short for", asset_name, "-", model_config[["model"]]))
      return(NULL)
    }
    
    # Use manual simulator directly
    manual <- simulate_nf_garch(
      fit,
      z_nf    = head(nf_resid, n_sim),
      horizon = n_sim,
      model   = model_config[["model"]],
      submodel = model_config[["submodel"]]
    )
    sim_returns <- manual$returns
    
    fitted_values <- sim_returns
    mse <- mean((asset_returns - fitted_values)^2, na.rm = TRUE)
    mae <- mean(abs(asset_returns - fitted_values), na.rm = TRUE)
    
    return(data.frame(
      Model = model_config[["model"]],
      Distribution = model_config[["distribution"]],
      Asset = asset_name,
      AIC = infocriteria(fit)[1],
      BIC = infocriteria(fit)[2],
      LogLikelihood = likelihood(fit),
      MSE = mse,
      MAE = mae,
      SplitType = "Chrono"
    ))
  }, error = function(e) {
    message(paste("❌ Error for", asset_name, ":", conditionMessage(e)))
    return(NULL)
  })
}

#### Run Quick Tests ####

cat("\n=== RUNNING QUICK NF-GARCH TESTS ===\n")

nf_results <- list()

for (config_name in names(model_configs)) {
  cfg <- model_configs[[config_name]]
  
  # Debug: Check the config
  cat("DEBUG: Testing config:", config_name, "\n")
  cat("DEBUG: cfg class:", class(cfg), "\n")
  cat("DEBUG: cfg type:", typeof(cfg), "\n")
  
  # FX
  for (asset in names(fx_returns)) {
    # Try different key patterns to match the actual file names
    possible_keys <- c(
      paste0(config_name, "_fx_", asset, "_residuals_synthetic"),
      paste0("fx_", asset, "_residuals_", config_name, "_residuals_synthetic_synthetic"),
      paste0(config_name, "_", asset, "_residuals_synthetic")
    )
    
    key <- NULL
    for (k in possible_keys) {
      if (k %in% names(nf_residuals_map)) {
        key <- k
        break
      }
    }
    
    if (is.null(key)) {
      message(paste("❌ Skipped:", asset, config_name, "- No synthetic residuals found."))
      message("  Tried keys:", paste(possible_keys, collapse = ", "))
      next
    }
    
    cat("NF-GARCH (FX):", asset, config_name, "using key:", key, "\n")
    r <- fit_nf_garch(asset, fx_returns[[asset]], cfg, nf_residuals_map[[key]])
    if (!is.null(r)) nf_results[[length(nf_results) + 1]] <- r
  }
  
  # Equity
  for (asset in names(equity_returns)) {
    # Try different key patterns to match the actual file names
    possible_keys <- c(
      paste0(config_name, "_equity_", asset, "_residuals_synthetic"),
      paste0("equity_", asset, "_residuals_", config_name, "_residuals_synthetic_synthetic"),
      paste0(config_name, "_", asset, "_residuals_synthetic")
    )
    
    key <- NULL
    for (k in possible_keys) {
      if (k %in% names(nf_residuals_map)) {
        key <- k
        break
      }
    }
    
    if (is.null(key)) {
      message(paste("❌ Skipped:", asset, config_name, "- No synthetic residuals found."))
      message("  Tried keys:", paste(possible_keys, collapse = ", "))
      next
    }
    
    cat("NF-GARCH (EQ):", asset, config_name, "using key:", key, "\n")
    r <- fit_nf_garch(asset, equity_returns[[asset]], cfg, nf_residuals_map[[key]])
    if (!is.null(r)) nf_results[[length(nf_results) + 1]] <- r
  }
}

#### Compile Results ####

if (length(nf_results) > 0) {
  nf_results_df <- do.call(rbind, nf_results)
  nf_results_df$Source <- "NF"
  
  cat("\n=== QUICK TEST RESULTS ===\n")
  cat("Assets tested:", length(c(equity_tickers, fx_names)), "\n")
  cat("Models tested:", length(model_configs), "\n")
  cat("Total tests:", nrow(nf_results_df), "\n")
  
  cat("\n=== MODEL PERFORMANCE ===\n")
  print(nf_results_df[, c("Asset", "Model", "AIC", "BIC", "MSE", "MAE")])
  
  #### Save Quick Test Results ####
  
  # Create output directory
  dir.create("outputs/quick_test", recursive = TRUE, showWarnings = FALSE)
  
  # Save results
  write.csv(nf_results_df, "outputs/quick_test/quick_nf_test_results.csv", row.names = FALSE)
  
  # Create a simple Excel file
  wb <- createWorkbook()
  addWorksheet(wb, "Quick_NF_Test_Results")
  writeData(wb, "Quick_NF_Test_Results", nf_results_df)
  saveWorkbook(wb, "outputs/quick_test/quick_nf_test_summary.xlsx", overwrite = TRUE)
  
  cat("\n=== QUICK TEST COMPLETE ===\n")
  cat("Results saved to: outputs/quick_test/\n")
  cat("Files created:\n")
  cat("  - quick_nf_test_results.csv\n")
  cat("  - quick_nf_test_summary.xlsx\n")
  
  cat("\nIf this test runs successfully, the full script should work!\n")
  
} else {
  cat("\n❌ No successful tests completed. Check error messages above.\n")
}
