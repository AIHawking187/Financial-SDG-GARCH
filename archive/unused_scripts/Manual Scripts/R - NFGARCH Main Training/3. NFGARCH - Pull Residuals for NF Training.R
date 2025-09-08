#Reminder to Set your Working Directory

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

# Source utility functions
source("./scripts/utils/safety_functions.R")
library(ggplot2)
#### Import the FX + EQ price data ####

# Read CSV with Date in first column (row names)

raw_price_data <- read.csv("./data/processed/raw (FX + EQ).csv", row.names = 1)

# Convert row names into a Date column

raw_price_data$Date <- lubridate::ymd(rownames(raw_price_data))
rownames(raw_price_data) <- NULL

# Move Date to the front

raw_price_data <- raw_price_data %>% dplyr::select(Date, everything())


#### Clean the Price data####

# Extract date vector

date_index <- raw_price_data$Date

# Remove date column from data matrix

price_data_matrix <- raw_price_data[, !(names(raw_price_data) %in% "Date")]

# Define equity and FX tickers (ensure they match column names exactly)

equity_tickers <- c("NVDA", "MSFT", "PG", "CAT", "WMT", "AMZN")
fx_names <- c("EURUSD", "GBPUSD", "GBPCNY", "USDZAR", "GBPZAR", "EURZAR")

# Split into equity and FX price matrices

equity_xts <- lapply(equity_tickers, function(ticker)
{
  xts(price_data_matrix[[ticker]], order.by = date_index)
})

names(equity_xts) <- equity_tickers

fx_xts <- lapply(fx_names, function(ticker) 
{
  xts(price_data_matrix[[ticker]], order.by = date_index)
})

names(fx_xts) <- fx_names


#### Calculate Returns on FX and Equity data ####

# Calculate returns

equity_returns <- lapply(equity_xts, function(x) CalculateReturns(x)[-1, ])
fx_returns     <- lapply(fx_xts,     function(x) diff(log(x))[-1, ])

#### Plotting returns data ####

plot_returns_and_save <- function(returns_list, prefix) {
  dir_path <- file.path("results/plots/exhaustive", paste0("histograms_", prefix))
  dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
  
  for (name in names(returns_list)) {
    png(file.path(dir_path, paste0(name, "_histogram.png")), width = 800, height = 600)
    chart.Histogram(returns_list[[name]], method = c("add.density", "add.normal"),
                    main = paste(prefix, name), colorset = c("blue", "red", "black"))
    dev.off()
  }
}

plot_returns_and_save(equity_returns, "Real_Equity")
plot_returns_and_save(fx_returns, "Real_FX")


#### Model Generator ####

generate_spec <- function(model, dist = "sstd", submodel = NULL) 
{
  ugarchspec(
    mean.model = list(armaOrder = c(0,0)),
    variance.model = list(model = model, garchOrder = c(1,1), submodel = submodel),
    distribution.model = dist
  )
} # Change the order of the ARCH and GARCH parameters here

#### Automate Fitting for Any Set of Returns #### 

fit_models <- function(returns_list, model_type, dist_type = "sstd", submodel = NULL) 
{
  specs <- lapply(returns_list, function(x) generate_spec(model_type, dist_type, submodel))
  fits <- mapply(function(ret, spec) ugarchfit(data = ret, spec = spec, out.sample = 20),
                 returns_list, specs, SIMPLIFY = FALSE)
  return(fits)
}

#### Set the GARCH Model Configs ####

# List of Different model configurations
model_configs <- list(
  sGARCH_norm  = list(model = "sGARCH", distribution = "norm", submodel = NULL),
  sGARCH_sstd  = list(model = "sGARCH", distribution = "sstd", submodel = NULL),
  gjrGARCH     = list(model = "gjrGARCH", distribution = "sstd", submodel = NULL),
  eGARCH       = list(model = "eGARCH", distribution = "sstd", submodel = NULL),
  TGARCH       = list(model = "fGARCH", distribution = "sstd", submodel = "TGARCH")
)  # Change the distributional assumptions of the ARCH and GARCH parameters here


#### Data Splitting ####

## Chronological Data Split
# Helper to get cutoff index
get_split_index <- function(x, split_ratio = 0.65) 
{
  return(floor(nrow(x) * split_ratio))
}

# Split returns into train/test
fx_train_returns <- lapply(fx_returns, function(x) x[1:get_split_index(x)])
fx_test_returns  <- lapply(fx_returns, function(x) x[(get_split_index(x) + 1):nrow(x)])

equity_train_returns <- lapply(equity_returns, function(x) x[1:get_split_index(x)])
equity_test_returns  <- lapply(equity_returns, function(x) x[(get_split_index(x) + 1):nrow(x)])

## Time-series cross-validation - Sliding Window Time-Series Cross-Validation

# Helper to get cutoff index and train across sliding windows
ts_cross_validate <- function(returns, model_type, dist_type = "sstd", submodel = NULL, 
                              window_size = 500, step_size = 50, forecast_horizon = 20) 
{
  n <- nrow(returns)
  results <- list()
  
  for (start_idx in seq(1, n - window_size - forecast_horizon, by = step_size)) {
    train_set <- returns[start_idx:(start_idx + window_size - 1)]
    test_set  <- returns[(start_idx + window_size):(start_idx + window_size + forecast_horizon - 1)]
    
    # 🔍 Print diagnostics before fitting
    message("📦 Start index: ", start_idx, 
            " | Train size: ", nrow(train_set), 
            " | Test size: ", nrow(test_set),
            " | Train SD: ", round(sd(train_set, na.rm = TRUE), 6))
    
    spec <- generate_spec(model_type, dist_type, submodel)
    
    # 🔒 Try fitting GARCH model
    fit <- tryCatch({
      ugarchfit(data = train_set, spec = spec, solver = "hybrid")
    }, error = function(e) {
      message("❌ Fit error at index ", start_idx, ": ", e$message)
      return(NULL)
    })
    
    if (!is.null(fit)) {
      forecast <- tryCatch({
        ugarchforecast(fit, n.ahead = forecast_horizon)
      }, error = function(e) {
        message("❌ Forecast error at index ", start_idx, ": ", e$message)
        return(NULL)
      })
      
      if (!is.null(forecast)) {
        eval <- tryCatch({
          evaluate_model(fit, forecast, test_set)
        }, error = function(e) {
          message("❌ Evaluation error at index ", start_idx, ": ", e$message)
          return(NULL)
        })
        
        if (!is.null(eval)) {
          eval$WindowStart <- index(train_set[1])
          results[[length(results) + 1]] <- eval
        }
      }
    }
  }
  
  if (length(results) == 0) {
    message("⚠️ No successful CV results for this series.")
    return(NULL)
  }
  
  return(results)
}

# Helper function to extract the best fit from each CV using criteria like:
# Lowest AIC / BIC
# 
# Highest log-likelihood
# 
# Lowest forecast MSE / MAE (from evaluate_model)

extract_best_fit <- function(cv_result, metric = "MSE..Forecast.vs.Actual.", minimize = TRUE) 
{
  if (is.null(cv_result) || length(cv_result) == 0) return(NULL)
  
  metric_vals <- sapply(cv_result, function(x) {
    if (!is.null(x[[metric]])) return(x[[metric]])
    else return(NA)
  })
  
  if (all(is.na(metric_vals))) return(NULL)
  
  best_index <- if (minimize) which.min(metric_vals) else which.max(metric_vals)
  return(cv_result[[best_index]]$fit_object[[1]])
}

# Helper to evaluate results across each TS CV Window
evaluate_model <- function(fit, forecast, actual_returns) 
{
  actual <- tail(actual_returns, 40)
  pred   <- fitted(forecast)
  
  # Ensure same length
  actual <- actual[1:min(nrow(actual), nrow(pred))]
  pred   <- pred[1:min(nrow(actual), nrow(pred))]
  
  mse <- mean((actual - pred)^2, na.rm = TRUE)
  mae <- mean(abs(actual - pred), na.rm = TRUE)
  
  q_stat_p <- tryCatch(Box.test(residuals(fit), lag = 10, type = "Ljung-Box")$p.value, error = function(e) NA)
  arch_p   <- tryCatch(ArchTest(residuals(fit), lags = 10)$p.value, error = function(e) NA)
  
  # Extract residuals
  resids <- tryCatch(as.numeric(residuals(fit, standardize = TRUE)), error = function(e) NA)
  
  return(list(
    metrics = data.frame(
      AIC = infocriteria(fit)[1],
      BIC = infocriteria(fit)[2],
      LogLikelihood = likelihood(fit),
      `MSE (Forecast vs Actual)` = mse,
      `MAE (Forecast vs Actual)` = mae,
      `Q-Stat (p>0.05)` = q_stat_p,
      `ARCH LM (p>0.05)` = arch_p
    ),
    residuals = resids,
    fit_object = list(fit)  # wrap in list to keep structure consistent
  ))
}


# Helper to evaluate results across the 65/35 chronological split

compare_results <- function(cv_result_list, model_name, is_cv = FALSE) {
  if (length(cv_result_list) == 0) return(NULL)
  
  all_rows <- list()
  
  for (asset_name in names(cv_result_list)) {
    asset_result <- cv_result_list[[asset_name]]
    
    for (window_eval in asset_result) {
      # Ensure it's a data frame
      if (!is.null(window_eval$metrics)) {
        eval_metrics <- window_eval$metrics
        eval_metrics$Asset <- asset_name
        eval_metrics$Model <- model_name
        eval_metrics$Type  <- ifelse(is_cv, "CV", "Chrono")
        all_rows[[length(all_rows) + 1]] <- eval_metrics
      }
    }
  }
  
  if (length(all_rows) == 0) return(NULL)
  
  # Before binding, make sure all have the same columns
  common_cols <- Reduce(intersect, lapply(all_rows, names))
  all_rows <- lapply(all_rows, function(df) df[, common_cols, drop = FALSE])
  
  return(bind_rows(all_rows))
}

#### Train the GARCH Models using Chrono split and TS CV Split ####

# Train model fits across 65/35 Chrono Split
Fitted_Chrono_Split_models <- list()

for (config_name in names(model_configs)) 
{
  cfg <- model_configs[[config_name]]
  
  equity_chrono_split_fit <- fit_models(equity_train_returns, model_type = cfg$model, dist_type = cfg$dist, submodel = cfg$submodel)
  fx_chrono_split_fit     <- fit_models(fx_train_returns, model_type = cfg$model, dist_type = cfg$dist, submodel = cfg$submodel)
  
  Fitted_Chrono_Split_models[[paste0("equity_", config_name)]] <- equity_chrono_split_fit
  Fitted_Chrono_Split_models[[paste0("fx_", config_name)]]     <- fx_chrono_split_fit
}

# Helper to run all CV models across window size of x and a forecast horizon of y

run_all_cv_models <- function(returns_list, model_configs, window_size = 500, forecast_horizon = 40) 
{
  cv_results_all <- list()
  
  for (model_name in names(model_configs)) {
    cfg <- model_configs[[model_name]]
    
    message("Running CV for: ", model_name)
    
    result <- lapply(returns_list, function(ret) {
      tryCatch({
        ts_cross_validate(ret, 
                          model_type = cfg$model, 
                          dist_type  = cfg$dist, 
                          submodel   = cfg$submodel,
                          window_size = window_size,
                          forecast_horizon = forecast_horizon)
      }, error = function(e) NULL)
    })
    
    # Keep non-null results only
    result <- result[!sapply(result, is.null)]
    
    cv_results_all[[model_name]] <- result
  }
  
  return(cv_results_all)
}

# Check and ensure sufficient size and variability across each window

valid_fx_returns <- fx_returns[sapply(fx_returns, function(x) nrow(x) > 520 && sd(x, na.rm = TRUE) > 0)]
valid_equity_returns <- equity_returns[sapply(equity_returns, function(x) nrow(x) > 520 && sd(x, na.rm = TRUE) > 0)]

# Run all CV models on all model configs across window size of 500 and a forecast horizon of 40

Fitted_FX_TS_CV_models     <- run_all_cv_models(valid_fx_returns, model_configs)
Fitted_EQ_TS_CV_models <- run_all_cv_models(valid_equity_returns, model_configs)

# Flatten all CV results into one data frame

Fitted_TS_CV_models <- data.frame()

for (model_name in names(Fitted_FX_TS_CV_models)) {
  fx_results <- tryCatch({
    compare_results(Fitted_FX_TS_CV_models[[model_name]], model_name, is_cv = TRUE)
  }, error = function(e) {
    message("⚠️ FX compare_results failed for: ", model_name, " - ", e$message)
    return(NULL)
  })
  
  eq_results <- tryCatch({
    compare_results(Fitted_EQ_TS_CV_models[[model_name]], model_name, is_cv = TRUE)
  }, error = function(e) {
    message("⚠️ EQ compare_results failed for: ", model_name, " - ", e$message)
    return(NULL)
  })
  
  # Use add_row_safe to prevent crashes when models return no rows
  Fitted_TS_CV_models <- add_row_safe(Fitted_TS_CV_models, fx_results)
  Fitted_TS_CV_models <- add_row_safe(Fitted_TS_CV_models, eq_results)
}


#### Extract and Save Residuals for All FX and Equity Assets Across All Model Configs ####

# Ensure residuals directory exists
dir.create("residuals_by_model", recursive = TRUE, showWarnings = FALSE)

# Iterate through all model fits (equity_* and fx_*) for Chrono Split models
for (model_key in names(Fitted_Chrono_Split_models)) {
  model_fits <- Fitted_Chrono_Split_models[[model_key]]
  
  # Extract model name and asset type
  asset_type <- ifelse(startsWith(model_key, "equity"), "equity", "fx")
  model_name <- gsub("^(equity|fx)_", "", model_key)
  
  # Create subdirectory for this model
  model_dir <- file.path("residuals_by_model", model_name)
  dir.create(model_dir, showWarnings = FALSE)
  
  return_list <- if (asset_type == "fx") fx_returns else equity_returns
  
  for (asset_name in names(model_fits)) {
    fit <- model_fits[[asset_name]]
    
    if (is.null(fit) || inherits(fit, "try-error")) next
    
    resid_vec <- residuals(fit, standardize = TRUE)
    
    # Align length with original returns
    full_length <- length(return_list[[asset_name]])
    n <- min(length(resid_vec), full_length)
     resid_num <- rep(NA, full_length)
    resid_num[1:n] <- as.numeric(resid_vec)[1:n]
    
    # Wrap in a data frame with column name
    resid_df <- data.frame(residual = resid_num)
    
    # Save
    write.csv(resid_df,
              file = file.path(model_dir, paste0(asset_type, "_", asset_name, "_Chrono_Split_residuals.csv")),
              row.names = FALSE)
  }
}

# Iterate through all model fits (equity_* and fx_*) for TS CV Models
  # Iterate over both FX and Equity TS CV model fits
  for (model_key in names(Fitted_FX_TS_CV_models)) {
    model_fits_list <- list(
      fx = Fitted_FX_TS_CV_models[[model_key]],
      equity = Fitted_EQ_TS_CV_models[[model_key]]
    )
    
    for (asset_type in names(model_fits_list)) {
      model_fits <- model_fits_list[[asset_type]]
      
      model_dir <- file.path("residuals_by_model", model_key)
      dir.create(model_dir, showWarnings = FALSE)
      
      return_list <- if (asset_type == "fx") fx_returns else equity_returns
      
      for (asset_name in names(model_fits)) {
        # Each TS CV fit for one asset is a list of windows
        fit_windows <- model_fits[[asset_name]]
        if (length(fit_windows) == 0) next
        
        # Combine all standardized residuals across CV windows
        all_resid <- unlist(lapply(fit_windows, function(fit_eval) {
          # fit_eval should contain residuals from evaluation object
          if (!is.null(fit_eval$residuals)) return(fit_eval$residuals)
          return(NULL)
        }))
        
        if (length(all_resid) == 0) next
        
        resid_df <- data.frame(residual = all_resid)
        write.csv(resid_df,
                  file = file.path(model_dir, paste0(asset_type, "_", asset_name, "_TS_CV_residuals.csv")),
                  row.names = FALSE)
      }
    }
  }
  
