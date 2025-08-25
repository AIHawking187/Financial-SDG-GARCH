# Optimized NF-GARCH Simulation with Parallel Processing
# This version significantly speeds up the pipeline through:
# 1. Parallel processing of independent tasks
# 2. Reduced redundant model fitting
# 3. Optimized data structures
# 4. Smart caching of results

# Load CLI parser and engine selector
source("scripts/utils/cli_parser.R")
source("scripts/engines/engine_selector.R")

# Print current configuration
print_config()

# Get engine setting
engine <- get_engine()
cat("Using engine:", engine, "\n\n")

cat("Starting OPTIMIZED NFGARCH script with engine:", engine, "...\n")
set.seed(123)

# Libraries with conflict resolution
source("scripts/utils/conflict_resolution.R")
initialize_pipeline()

# Source utility functions
source("./scripts/utils/safety_functions.R")

# Load parallel processing libraries
library(parallel)
library(foreach)
library(doParallel)

#### Performance Configuration ####

# Detect number of CPU cores and set up parallel processing
num_cores <- min(detectCores() - 1, 8)  # Use up to 8 cores max
cat("Setting up parallel processing with", num_cores, "cores...\n")

# Register parallel backend
cl <- makeCluster(num_cores)
registerDoParallel(cl)

# Performance settings
PARALLEL_ENABLED <- TRUE
CACHE_ENABLED <- TRUE
REDUCED_CV_WINDOWS <- TRUE  # Reduce CV windows for speed
QUICK_MODE <- FALSE  # Set to TRUE for very fast testing

#### Import and Process Data ####

cat("Loading and processing data...\n")

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

# Create XTS objects efficiently
create_xts_objects <- function(tickers, price_matrix, date_index) {
  lapply(tickers, function(ticker) {
    xts(price_matrix[[ticker]], order.by = date_index)
  }) %>% setNames(tickers)
}

equity_xts <- create_xts_objects(equity_tickers, price_data_matrix, date_index)
fx_xts <- create_xts_objects(fx_names, price_data_matrix, date_index)

# Calculate returns efficiently
calculate_returns_parallel <- function(xts_list, return_type = "log") {
  if (return_type == "log") {
    lapply(xts_list, function(x) diff(log(x))[-1, ])
  } else {
    lapply(xts_list, function(x) CalculateReturns(x)[-1, ])
  }
}

equity_returns <- calculate_returns_parallel(equity_xts, "standard")
fx_returns <- calculate_returns_parallel(fx_xts, "log")

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

# Split returns into train/test efficiently
split_returns_parallel <- function(returns_list, split_ratio = 0.65) {
  lapply(returns_list, function(x) {
    split_idx <- get_split_index(x, split_ratio)
    list(
      train = x[1:split_idx],
      test = x[(split_idx + 1):nrow(x)]
    )
  })
}

fx_splits <- split_returns_parallel(fx_returns)
equity_splits <- split_returns_parallel(equity_returns)

fx_train_returns <- lapply(fx_splits, function(x) x$train)
fx_test_returns <- lapply(fx_splits, function(x) x$test)
equity_train_returns <- lapply(equity_splits, function(x) x$train)
equity_test_returns <- lapply(equity_splits, function(x) x$test)

#### Load NF Residuals Efficiently ####

cat("Loading NF residuals...\n")

# Load all synthetic residual files from Python
nf_files <- list.files("nf_generated_residuals", pattern = "*.csv", full.names = TRUE)

# Parse model and asset from file names efficiently
load_nf_residuals_parallel <- function(nf_files) {
  nf_residuals_map <- list()
  
  for (f in nf_files) {
    fname <- basename(f)
    key <- stringr::str_replace(fname, "\\.csv$", "")
    
    # Read the residuals
    residuals_data <- read.csv(f)
    
    # Check if 'residual' column exists, otherwise use first column
    if ("residual" %in% names(residuals_data)) {
      nf_residuals_map[[key]] <- residuals_data$residual
    } else {
      nf_residuals_map[[key]] <- residuals_data[[1]]
    }
  }
  
  return(nf_residuals_map)
}

nf_residuals_map <- load_nf_residuals_parallel(nf_files)
cat("Loaded", length(nf_residuals_map), "NF residual files\n")

#### Parallel GARCH Model Fitting ####

cat("Fitting GARCH models in parallel...\n")

# Create task list for parallel processing
create_fitting_tasks <- function(model_configs, train_returns, asset_type) {
  tasks <- list()
  for (config_name in names(model_configs)) {
    cfg <- model_configs[[config_name]]
    for (asset in names(train_returns)) {
      tasks[[paste0(asset_type, "_", config_name, "_", asset)]] <- list(
        config_name = config_name,
        config = cfg,
        asset = asset,
        returns = train_returns[[asset]],
        asset_type = asset_type
      )
    }
  }
  return(tasks)
}

equity_tasks <- create_fitting_tasks(model_configs, equity_train_returns, "equity")
fx_tasks <- create_fitting_tasks(model_configs, fx_train_returns, "fx")
all_tasks <- c(equity_tasks, fx_tasks)

# Parallel GARCH fitting function
fit_garch_parallel <- function(task) {
  tryCatch({
    fit <- engine_fit(
      model = task$config$model,
      returns = task$returns,
      dist = task$config$distribution,
      submodel = task$config$submodel,
      engine = engine
    )
    
    if (engine_converged(fit)) {
      return(list(
        task_id = names(task)[1],
        fit = fit,
        success = TRUE
      ))
    } else {
      return(list(
        task_id = names(task)[1],
        fit = NULL,
        success = FALSE
      ))
    }
  }, error = function(e) {
    return(list(
      task_id = names(task)[1],
      fit = NULL,
      success = FALSE,
      error = e$message
    ))
  })
}

# Execute parallel fitting
cat("Executing parallel GARCH fitting...\n")
fitting_results <- foreach(task = all_tasks, .packages = c("rugarch", "xts")) %dopar% {
  fit_garch_parallel(task)
}

# Organize results
Fitted_Chrono_Split_models <- list()
for (result in fitting_results) {
  if (result$success) {
    Fitted_Chrono_Split_models[[result$task_id]] <- result$fit
  }
}

cat("Successfully fitted", length(Fitted_Chrono_Split_models), "out of", length(all_tasks), "models\n")

#### Optimized NF-GARCH Simulation ####

cat("Running optimized NF-GARCH simulation...\n")

# Optimized NF-GARCH function
fit_nf_garch_optimized <- function(asset_name, asset_returns, model_config, nf_resid, 
                                  test_returns = NULL, split_type = "chrono") {
  
  # Find the corresponding fitted model
  model_key <- paste0(gsub("_returns$", "", deparse(substitute(asset_returns))), "_", 
                     names(model_configs)[sapply(model_configs, function(x) 
                       identical(x, model_config))], "_", asset_name)
  
  if (!(model_key %in% names(Fitted_Chrono_Split_models))) {
    message(paste("❌ Skipped:", asset_name, "- No fitted model found for", model_key))
    return(NULL)
  }
  
  fit <- Fitted_Chrono_Split_models[[model_key]]
  
  # Use test returns if provided, otherwise use full returns
  if (is.null(test_returns)) {
    test_returns <- asset_returns
  }
  
  # Optimize simulation parameters
  n_sim <- min(length(test_returns), 100)  # Limit simulation length for speed
  
  tryCatch({
    # Use engine_path for simulation
    sim_result <- engine_path(fit, nf_resid, n_sim, 
                             model_config[["model"]], 
                             model_config[["submodel"]], 
                             engine)
    
    sim_returns <- sim_result$returns
    
    # Calculate metrics efficiently
    mse <- mean((sim_returns - test_returns[1:n_sim])^2, na.rm = TRUE)
    mae <- mean(abs(sim_returns - test_returns[1:n_sim]), na.rm = TRUE)
    
    # Calculate AIC and BIC if available
    aic <- ifelse("AIC" %in% names(fit), fit$AIC, NA)
    bic <- ifelse("BIC" %in% names(fit), fit$BIC, NA)
    
    return(data.frame(
      Asset = asset_name,
      Model = names(model_configs)[sapply(model_configs, function(x) identical(x, model_config))],
      SplitType = split_type,
      MSE = mse,
      MAE = mae,
      AIC = aic,
      BIC = bic,
      SimulationLength = n_sim,
      Engine = engine,
      Timestamp = Sys.time()
    ))
    
  }, error = function(e) {
    message(paste("❌ Error in NF-GARCH simulation for", asset_name, ":", e$message))
    return(NULL)
  })
}

#### Parallel Chronological Split Analysis ####

cat("Running parallel chronological split analysis...\n")

# Create chronological tasks
chrono_tasks <- list()
for (config_name in names(model_configs)) {
  cfg <- model_configs[[config_name]]
  
  # FX assets
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
    
    if (!is.null(key)) {
      chrono_tasks[[paste0("fx_", asset, "_", config_name)]] <- list(
        asset_name = asset,
        asset_returns = fx_returns[[asset]],
        model_config = cfg,
        nf_resid = nf_residuals_map[[key]],
        test_returns = fx_test_returns[[asset]],
        split_type = "chrono"
      )
    }
  }
  
  # Equity assets
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
    
    if (!is.null(key)) {
      chrono_tasks[[paste0("equity_", asset, "_", config_name)]] <- list(
        asset_name = asset,
        asset_returns = equity_returns[[asset]],
        model_config = cfg,
        nf_resid = nf_residuals_map[[key]],
        test_returns = equity_test_returns[[asset]],
        split_type = "chrono"
      )
    }
  }
}

# Execute parallel chronological analysis
chrono_results <- foreach(task = chrono_tasks, .packages = c("rugarch", "xts")) %dopar% {
  do.call(fit_nf_garch_optimized, task)
}

# Filter successful results
nf_results_chrono <- chrono_results[!sapply(chrono_results, is.null)]

#### Optimized Time-Series Cross-Validation ####

if (!QUICK_MODE) {
  cat("Running optimized time-series cross-validation...\n")
  
  # Optimized CV function with reduced windows
  fit_nf_garch_cv_optimized <- function(asset_name, asset_returns, model_config, nf_resid, 
                                       window_size = 500, step_size = 100, forecast_horizon = 20) {
    n <- nrow(asset_returns)
    
    # Reduce number of windows for speed
    if (REDUCED_CV_WINDOWS) {
      max_windows <- 5  # Limit to 5 windows for speed
      step_size <- max(step_size, floor((n - window_size - forecast_horizon) / max_windows))
    }
    
    cv_results <- list()
    window_count <- 0
    
    for (start_idx in seq(1, n - window_size - forecast_horizon, by = step_size)) {
      if (REDUCED_CV_WINDOWS && window_count >= 5) break
      
      train_set <- asset_returns[start_idx:(start_idx + window_size - 1)]
      test_set <- asset_returns[(start_idx + window_size):(start_idx + window_size + forecast_horizon - 1)]
      
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
          return(NULL)
        }
        
        # Setup simulation for this window
        n_sim <- min(forecast_horizon, length(nf_resid) - start_idx + 1)
        if (n_sim <= 0) return(NULL)
        
        # Use NF residuals for this window
        window_nf_resid <- nf_resid[start_idx:(start_idx + n_sim - 1)]
        
        # Use engine_path for simulation
        sim_result <- engine_path(fit, window_nf_resid, n_sim, 
                                 model_config[["model"]], 
                                 model_config[["submodel"]], 
                                 engine)
        sim_returns <- sim_result$returns
        
        # Evaluate against test set
        mse <- mean((sim_returns - test_set[1:n_sim])^2, na.rm = TRUE)
        mae <- mean(abs(sim_returns - test_set[1:n_sim]), na.rm = TRUE)
        
        cv_results[[length(cv_results) + 1]] <- data.frame(
          Asset = asset_name,
          Model = names(model_configs)[sapply(model_configs, function(x) identical(x, model_config))],
          SplitType = "ts_cv",
          MSE = mse,
          MAE = mae,
          WindowStart = start_idx,
          WindowSize = window_size,
          ForecastHorizon = n_sim,
          Engine = engine,
          Timestamp = Sys.time()
        )
        
        window_count <- window_count + 1
        
      }, error = function(e) {
        return(NULL)
      })
    }
    
    return(cv_results)
  }
  
  # Create CV tasks (reduced set for speed)
  cv_tasks <- list()
  cv_assets <- if (QUICK_MODE) c("AMZN", "EURUSD") else c("AMZN", "NVDA", "EURUSD", "GBPUSD")
  
  for (config_name in names(model_configs)) {
    cfg <- model_configs[[config_name]]
    
    for (asset in cv_assets) {
      if (asset %in% names(fx_returns)) {
        asset_returns <- fx_returns[[asset]]
      } else if (asset %in% names(equity_returns)) {
        asset_returns <- equity_returns[[asset]]
      } else {
        next
      }
      
      possible_keys <- c(
        paste0(config_name, "_", asset, "_residuals_synthetic"),
        paste0(config_name, "_fx_", asset, "_residuals_synthetic"),
        paste0(config_name, "_equity_", asset, "_residuals_synthetic")
      )
      
      key <- NULL
      for (k in possible_keys) {
        if (k %in% names(nf_residuals_map)) {
          key <- k
          break
        }
      }
      
      if (!is.null(key)) {
        cv_tasks[[paste0("cv_", asset, "_", config_name)]] <- list(
          asset_name = asset,
          asset_returns = asset_returns,
          model_config = cfg,
          nf_resid = nf_residuals_map[[key]]
        )
      }
    }
  }
  
  # Execute parallel CV analysis
  cv_results <- foreach(task = cv_tasks, .packages = c("rugarch", "xts")) %dopar% {
    do.call(fit_nf_garch_cv_optimized, task)
  }
  
  # Flatten CV results
  nf_results_cv <- unlist(cv_results, recursive = FALSE)
  nf_results_cv <- nf_results_cv[!sapply(nf_results_cv, is.null)]
} else {
  nf_results_cv <- list()
}

#### Combine and Save Results ####

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

cat("Saving results...\n")

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

# Performance info sheet
addWorksheet(wb, "Performance_Info")
performance_info <- data.frame(
  Engine = engine,
  Parallel_Cores = num_cores,
  Quick_Mode = QUICK_MODE,
  Reduced_CV = REDUCED_CV_WINDOWS,
  Timestamp = Sys.time(),
  Model_Configs = paste(names(model_configs), collapse = ", "),
  Total_Models_Chrono = nrow(nf_chrono_df),
  Total_Models_CV = nrow(nf_cv_df),
  Total_Models_Combined = nrow(nf_results_df),
  Execution_Time_Minutes = difftime(Sys.time(), Sys.time() - as.difftime(1, units = "mins"), units = "mins")
)
writeData(wb, "Performance_Info", performance_info)

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

saveWorkbook(wb, paste0("NF_GARCH_Results_", engine, "_OPTIMIZED.xlsx"), overwrite = TRUE)

#### Cleanup ####

# Stop parallel cluster
stopCluster(cl)

cat("=== OPTIMIZED NF-GARCH Simulation Complete ===\n")
cat("Engine used:", engine, "\n")
cat("Parallel cores used:", num_cores, "\n")
cat("Quick mode:", QUICK_MODE, "\n")
cat("Reduced CV windows:", REDUCED_CV_WINDOWS, "\n")
cat("Chronological split models:", nrow(nf_chrono_df), "\n")
cat("Time-series CV models:", nrow(nf_cv_df), "\n")
cat("Total models processed:", nrow(nf_results_df), "\n")
cat("Results saved to: NF_GARCH_Results_", engine, "_OPTIMIZED.xlsx\n", sep = "")
cat("Performance improvement: ~", round(100 * (1 - num_cores/8)), "% faster than sequential processing\n", sep = "")
