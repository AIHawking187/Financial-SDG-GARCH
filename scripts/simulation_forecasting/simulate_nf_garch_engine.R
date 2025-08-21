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

nf_results <- list()

for (config_name in names(model_configs)) {
  cfg <- model_configs[[config_name]]
  
  cat("Processing", config_name, "...\n")
  
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
    if (!is.null(r)) nf_results[[length(nf_results) + 1]] <- r
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
    if (!is.null(r)) nf_results[[length(nf_results) + 1]] <- r
  }
}

nf_results_df <- do.call(rbind, nf_results)
nf_results_df$Source <- "NF"

#### Save Results ####

# Create a new workbook
wb <- createWorkbook()

# Add sheets
addWorksheet(wb, "NF_GARCH_Eval")
writeData(wb, "NF_GARCH_Eval", nf_results_df)

addWorksheet(wb, "Engine_Info")
engine_info <- data.frame(
  Engine = engine,
  Timestamp = Sys.time(),
  Model_Configs = paste(names(model_configs), collapse = ", "),
  Total_Models = nrow(nf_results_df)
)
writeData(wb, "Engine_Info", engine_info)

saveWorkbook(wb, paste0("NF_GARCH_Results_", engine, ".xlsx"), overwrite = TRUE)

cat("=== NF-GARCH Simulation Complete ===\n")
cat("Engine used:", engine, "\n")
cat("Total models processed:", nrow(nf_results_df), "\n")
cat("Results saved to: NF_GARCH_Results_", engine, ".xlsx\n", sep = "")
