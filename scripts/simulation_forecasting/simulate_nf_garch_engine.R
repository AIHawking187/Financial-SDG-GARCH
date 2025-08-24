# NF-GARCH Simulation with Engine Selector
# Supports both rugarch and manual engines via CLI switch

# Load CLI parser and engine selector
source("scripts/utils/cli_parser.R")
source("scripts/engines/engine_selector.R")

# Print current configuration
print_config()

# Get engine setting
engine <- get_engine()
cat("Using engine:", engine, "\n\n")

cat("Starting NFGARCH script with engine:", engine, "...\n")
set.seed(123)

# Libraries with conflict resolution
source("scripts/utils/conflict_resolution.R")
initialize_pipeline()

# Source utility functions
source("./scripts/utils/safety_functions.R")

#### Import and Process Data ####

# Read CSV with Date in first column (row names)
raw_price_data <- read.csv("./data/processed/raw (FX + EQ).csv", row.names = 1)
raw_price_data$Date <- lubridate::ymd(rownames(raw_price_data))
rownames(raw_price_data) <- NULL
raw_price_data <- raw_price_data %>% dplyr::select(Date, everything())

# Extract date vector and price matrix
date_index <- raw_price_data$Date
price_data_matrix <- raw_price_data[, !(names(raw_price_data) %in% "Date")]

# Define equity and FX tickers
equity_tickers <- c("NVDA", "MSFT", "PG", "CAT", "WMT", "AMZN")
fx_names <- c("EURUSD", "GBPUSD", "GBPCNY", "USDZAR", "GBPZAR", "EURZAR")

# Create XTS objects
equity_xts <- lapply(equity_tickers, function(ticker) {
  xts(price_data_matrix[[ticker]], order.by = date_index)
})
names(equity_xts) <- equity_tickers

fx_xts <- lapply(fx_names, function(ticker) {
  xts(price_data_matrix[[ticker]], order.by = date_index)
})
names(fx_xts) <- fx_names

# Calculate returns
equity_returns <- lapply(equity_xts, function(x) CalculateReturns(x)[-1, ])
fx_returns     <- lapply(fx_xts,     function(x) diff(log(x))[-1, ])

#### Model Configurations ####

model_configs <- list(
  sGARCH_norm  = list(model = "sGARCH", distribution = "norm", submodel = NULL),
  sGARCH_sstd  = list(model = "sGARCH", distribution = "sstd", submodel = NULL),
  gjrGARCH     = list(model = "gjrGARCH", distribution = "sstd", submodel = NULL),
  eGARCH       = list(model = "eGARCH", distribution = "sstd", submodel = NULL),
  TGARCH       = list(model = "fGARCH", distribution = "sstd", submodel = "TGARCH")
)

#### Data Splitting ####

get_split_index <- function(x, split_ratio = 0.65) {
  return(floor(nrow(x) * split_ratio))
}

# Split returns into train/test
fx_train_returns <- lapply(fx_returns, function(x) x[1:get_split_index(x)])
fx_test_returns  <- lapply(fx_returns, function(x) x[(get_split_index(x) + 1):nrow(x)])

equity_train_returns <- lapply(equity_returns, function(x) x[1:get_split_index(x)])
equity_test_returns  <- lapply(equity_returns, function(x) x[(get_split_index(x) + 1):nrow(x)])

#### Train GARCH Models ####

# Train model fits across 65/35 Chrono Split
Fitted_Chrono_Split_models <- list()

for (config_name in names(model_configs)) {
  cfg <- model_configs[[config_name]]
  
  cat("Fitting", config_name, "models...\n")
  
  # Use engine_fit for both rugarch and manual engines
  equity_chrono_split_fit <- lapply(equity_train_returns, function(ret) {
    engine_fit(model = cfg$model, returns = ret, dist = cfg$distribution, submodel = cfg$submodel, engine = engine)
  })
  
  fx_chrono_split_fit <- lapply(fx_train_returns, function(ret) {
    engine_fit(model = cfg$model, returns = ret, dist = cfg$distribution, submodel = cfg$submodel, engine = engine)
  })
  
  Fitted_Chrono_Split_models[[paste0("equity_", config_name)]] <- equity_chrono_split_fit
  Fitted_Chrono_Split_models[[paste0("fx_", config_name)]]     <- fx_chrono_split_fit
}

#### Load NF Residuals ####

# Load all synthetic residual files from Python
nf_files <- list.files("nf_generated_residuals", pattern = "*.csv", full.names = TRUE)

# Parse model and asset from file names
nf_residuals_map <- list()
for (f in nf_files) {
  fname <- basename(f)
  key <- stringr::str_replace(fname, "\\.csv$", "")
  
  residuals_data <- read.csv(f)
  
  if ("residual" %in% names(residuals_data)) {
    nf_residuals_map[[key]] <- residuals_data$residual
  } else {
    nf_residuals_map[[key]] <- residuals_data[[1]]
  }
}

cat("Loaded", length(nf_residuals_map), "NF residual files\n")

#### NF-GARCH Simulation ####

# Define NF-GARCH fitting function
fit_nf_garch <- function(asset_name, asset_returns, model_config, nf_resid) {
  tryCatch({
    # Use engine_fit
    fit <- engine_fit(
      model = model_config[["model"]], 
      returns = asset_returns, 
      dist = model_config[["distribution"]], 
      submodel = model_config[["submodel"]], 
      engine = engine
    )
    
    if (!engine_converged(fit)) {
      message(paste("❌ Fit failed for", asset_name, model_config[["model"]]))
      return(NULL)
    }
    
    # Setup simulation
    n_sim <- floor(length(asset_returns) / 2)
    if (length(nf_resid) < n_sim) {
      warning(paste("⚠️ NF residuals too short for", asset_name, "-", model_config[["model"]]))
      return(NULL)
    }
    
    # Use engine_path for simulation
    sim_result <- engine_path(
      fit, 
      head(nf_resid, n_sim), 
      n_sim, 
      model_config[["model"]], 
      model_config[["submodel"]], 
      engine
    )
    sim_returns <- sim_result$returns
    
    fitted_values <- sim_returns
    mse <- mean((asset_returns - fitted_values)^2, na.rm = TRUE)
    mae <- mean(abs(asset_returns - fitted_values), na.rm = TRUE)
    
    # Get model information
    ic <- engine_infocriteria(fit)
    
    return(data.frame(
      Model = model_config[["model"]],
      Distribution = model_config[["distribution"]],
      Asset = asset_name,
      AIC = ic["AIC"],
      BIC = ic["BIC"],
      LogLikelihood = ic["LogLikelihood"],
      MSE = mse,
      MAE = mae,
      SplitType = "Chrono"
    ))
  }, error = function(e) {
    message(paste("❌ Error for", asset_name, model_config[["model"]], ":", conditionMessage(e)))
    return(NULL)
  })
}

#### Run NF-GARCH Analysis ####

cat("=== CHRONOLOGICAL SPLIT NF-GARCH ANALYSIS ===\n")
nf_results_chrono <- list()

for (config_name in names(model_configs)) {
  cfg <- model_configs[[config_name]]
  
  cat("Processing", config_name, "(Chrono Split)...\n")
  
  # FX
  for (asset in names(fx_returns)) {
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
      next
    }
    
    cat("NF-GARCH (FX):", asset, config_name, "\n")
    r <- fit_nf_garch(asset, fx_returns[[asset]], cfg, nf_residuals_map[[key]])
    if (!is.null(r)) nf_results_chrono[[length(nf_results_chrono) + 1]] <- r
  }
  
  # Equity
  for (asset in names(equity_returns)) {
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
      next
    }
    
    cat("NF-GARCH (EQ):", asset, config_name, "\n")
    r <- fit_nf_garch(asset, equity_returns[[asset]], cfg, nf_residuals_map[[key]])
    if (!is.null(r)) nf_results_chrono[[length(nf_results_chrono) + 1]] <- r
  }
}

#### Time-Series Cross-Validation NF-GARCH Analysis ####

cat("\n=== TIME-SERIES CV NF-GARCH ANALYSIS ===\n")

# NF-GARCH Time-Series CV function
fit_nf_garch_cv <- function(asset_name, asset_returns, model_config, nf_resid, 
                           window_size = 500, step_size = 50, forecast_horizon = 20) {
  n <- nrow(asset_returns)
  results <- list()
  
  for (start_idx in seq(1, n - window_size - forecast_horizon, by = step_size)) {
    train_set <- asset_returns[start_idx:(start_idx + window_size - 1)]
    test_set  <- asset_returns[(start_idx + window_size):(start_idx + window_size + forecast_horizon - 1)]
    
    cat("📦 CV Window:", start_idx, "| Train size:", nrow(train_set), "| Test size:", nrow(test_set), "\n")
    
    tryCatch({
      # Use engine_fit
      fit <- engine_fit(
        model = model_config[["model"]], 
        returns = train_set, 
        dist = model_config[["distribution"]], 
        submodel = model_config[["submodel"]], 
        engine = engine
      )
      
      if (!engine_converged(fit)) {
        message(paste("❌ CV Fit failed for", asset_name, model_config[["model"]], "at window", start_idx))
        return(NULL)
      }
      
      # Setup simulation for this window
      n_sim <- forecast_horizon
      if (length(nf_resid) < start_idx + n_sim) {
        warning(paste("⚠️ NF residuals too short for CV window", start_idx))
        return(NULL)
      }
      
      # Use NF residuals for this window
      window_nf_resid <- nf_resid[start_idx:(start_idx + n_sim - 1)]
      
      # Use engine_path for simulation
      sim_result <- engine_path(
        fit, 
        window_nf_resid, 
        n_sim, 
        model_config[["model"]], 
        model_config[["submodel"]], 
        engine
      )
      sim_returns <- sim_result$returns
      
      # Evaluate against test set
      actual <- as.numeric(test_set)
      pred <- as.numeric(head(sim_returns, length(actual)))
      
      # Ensure same length
      min_len <- min(length(actual), length(pred))
      actual <- actual[1:min_len]
      pred <- pred[1:min_len]
      
      mse <- mean((actual - pred)^2, na.rm = TRUE)
      mae <- mean(abs(actual - pred), na.rm = TRUE)
      
      # Get model information
      ic <- engine_infocriteria(fit)
      
      result <- data.frame(
        Model = model_config[["model"]],
        Distribution = model_config[["distribution"]],
        Asset = asset_name,
        AIC = ic["AIC"],
        BIC = ic["BIC"],
        LogLikelihood = ic["LogLikelihood"],
        MSE = mse,
        MAE = mae,
        SplitType = "TimeSeriesCV",
        WindowStart = start_idx,
        WindowSize = window_size,
        ForecastHorizon = forecast_horizon
      )
      
      results[[length(results) + 1]] <- result
      
    }, error = function(e) {
      message(paste("❌ CV Error for", asset_name, model_config[["model"]], "at window", start_idx, ":", conditionMessage(e)))
    })
  }
  
  return(results)
}

# Run Time-Series CV for NF-GARCH
nf_results_cv <- list()

# Filter valid returns (sufficient length and variability)
valid_fx_returns <- fx_returns[sapply(fx_returns, function(x) nrow(x) > 570 && sd(x, na.rm = TRUE) > 0)]
valid_equity_returns <- equity_returns[sapply(equity_returns, function(x) nrow(x) > 570 && sd(x, na.rm = TRUE) > 0)]

cat("Valid FX assets for CV:", names(valid_fx_returns), "\n")
cat("Valid Equity assets for CV:", names(valid_equity_returns), "\n")

for (config_name in names(model_configs)) {
  cfg <- model_configs[[config_name]]
  
  cat("Processing TS CV for", config_name, "...\n")
  
  # FX CV
  for (asset in names(valid_fx_returns)) {
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
      message(paste("❌ CV Skipped:", asset, config_name, "- No synthetic residuals found."))
      next
    }
    
    cat("NF-GARCH CV (FX):", asset, config_name, "\n")
    cv_results <- fit_nf_garch_cv(asset, valid_fx_returns[[asset]], cfg, nf_residuals_map[[key]])
    if (length(cv_results) > 0) {
      nf_results_cv <- append(nf_results_cv, cv_results)
    }
  }
  
  # Equity CV
  for (asset in names(valid_equity_returns)) {
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
      message(paste("❌ CV Skipped:", asset, config_name, "- No synthetic residuals found."))
      next
    }
    
    cat("NF-GARCH CV (EQ):", asset, config_name, "\n")
    cv_results <- fit_nf_garch_cv(asset, valid_equity_returns[[asset]], cfg, nf_residuals_map[[key]])
    if (length(cv_results) > 0) {
      nf_results_cv <- append(nf_results_cv, cv_results)
    }
  }
}

# Combine all results
nf_results <- c(nf_results_chrono, nf_results_cv)

# Process results for saving
nf_chrono_df <- if (length(nf_results_chrono) > 0) do.call(rbind, nf_results_chrono) else data.frame()
nf_cv_df <- if (length(nf_results_cv) > 0) do.call(rbind, nf_results_cv) else data.frame()
nf_results_df <- if (length(nf_results) > 0) do.call(rbind, nf_results) else data.frame()

if (nrow(nf_results_df) > 0) {
  nf_results_df$Source <- "NF"
}

#### Save Results ####

# Create a new workbook
wb <- createWorkbook()

# Add sheets for different split types
if (nrow(nf_chrono_df) > 0) {
  addWorksheet(wb, "NF_GARCH_Chrono_Split")
  writeData(wb, "NF_GARCH_Chrono_Split", nf_chrono_df)
}

if (nrow(nf_cv_df) > 0) {
  addWorksheet(wb, "NF_GARCH_TS_CV")
  writeData(wb, "NF_GARCH_TS_CV", nf_cv_df)
}

# Combined results sheet
if (nrow(nf_results_df) > 0) {
  addWorksheet(wb, "NF_GARCH_Eval")
  writeData(wb, "NF_GARCH_Eval", nf_results_df)
}

# Engine info sheet
addWorksheet(wb, "Engine_Info")
engine_info <- data.frame(
  Engine = engine,
  Timestamp = Sys.time(),
  Model_Configs = paste(names(model_configs), collapse = ", "),
  Total_Models_Chrono = nrow(nf_chrono_df),
  Total_Models_CV = nrow(nf_cv_df),
  Total_Models_Combined = nrow(nf_results_df),
  CV_Windows_Processed = ifelse(nrow(nf_cv_df) > 0, max(nf_cv_df$WindowStart, na.rm = TRUE), 0)
)
writeData(wb, "Engine_Info", engine_info)

# Summary by split type
addWorksheet(wb, "Summary_by_Split")
summary_by_split <- data.frame(
  SplitType = c("Chronological", "TimeSeriesCV", "Combined"),
  Total_Records = c(nrow(nf_chrono_df), nrow(nf_cv_df), nrow(nf_results_df)),
  Avg_MSE = c(
    ifelse(nrow(nf_chrono_df) > 0, mean(nf_chrono_df$MSE, na.rm = TRUE), NA),
    ifelse(nrow(nf_cv_df) > 0, mean(nf_cv_df$MSE, na.rm = TRUE), NA),
    ifelse(nrow(nf_results_df) > 0, mean(nf_results_df$MSE, na.rm = TRUE), NA)
  ),
  Avg_MAE = c(
    ifelse(nrow(nf_chrono_df) > 0, mean(nf_chrono_df$MAE, na.rm = TRUE), NA),
    ifelse(nrow(nf_cv_df) > 0, mean(nf_cv_df$MAE, na.rm = TRUE), NA),
    ifelse(nrow(nf_results_df) > 0, mean(nf_results_df$MAE, na.rm = TRUE), NA)
  )
)
writeData(wb, "Summary_by_Split", summary_by_split)

saveWorkbook(wb, paste0("NF_GARCH_Results_", engine, ".xlsx"), overwrite = TRUE)

cat("=== NF-GARCH Simulation Complete ===\n")
cat("Engine used:", engine, "\n")
cat("Chronological split models:", nrow(nf_chrono_df), "\n")
cat("Time-series CV models:", nrow(nf_cv_df), "\n")
cat("Total models processed:", nrow(nf_results_df), "\n")
cat("Results saved to: NF_GARCH_Results_", engine, ".xlsx\n", sep = "")
