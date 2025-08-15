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

# Plot returns histograms to results folder under exhaustive plots  

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
          evaluate_model(fit, forecast, test_set, forecast_horizon)
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

# Helper to evaluate results across each TS CV Window
evaluate_model <- function(fit, forecast, actual_returns, forecast_horizon = 40) 
{
  actual <- head(actual_returns, forecast_horizon)
  pred   <- fitted(forecast)
  
  # Ensure same length
  actual <- actual[1:min(NROW(actual), NROW(pred))]
  pred   <- pred[1:min(NROW(actual), NROW(pred))]
  
  mse <- mean((actual - pred)^2, na.rm = TRUE)
  mae <- mean(abs(actual - pred), na.rm = TRUE)
  
  q_stat_p <- tryCatch(Box.test(residuals(fit), lag = 10, type = "Ljung-Box")$p.value, error = function(e) NA)
  arch_p   <- tryCatch(ArchTest(residuals(fit), lags = 10)$p.value, error = function(e) NA)
  
  return(data.frame
         (
           AIC = infocriteria(fit)[1],
           BIC = infocriteria(fit)[2],
           LogLikelihood = likelihood(fit),
           `MSE (Forecast vs Actual)` = mse,
           `MAE (Forecast vs Actual)` = mae,
           `Q-Stat (p>0.05)` = q_stat_p,
           `ARCH LM (p>0.05)` = arch_p
         ))
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

run_all_cv_models <- function(returns_list, model_configs, window_size = 500, forecast_horizon = 40) {
  cv_results_all <- list()
  
  for (model_name in names(model_configs)) {
    cfg <- model_configs[[model_name]]
    message("⚙️ Running CV for model: ", model_name)
    
    result <- lapply(returns_list, function(ret) {
      ts_cross_validate(ret, 
                        model_type = cfg$model, 
                        dist_type  = cfg$dist, 
                        submodel   = cfg$submodel,
                        window_size = window_size,
                        forecast_horizon = forecast_horizon)
    })
    
    # Label by asset names
    names(result) <- names(returns_list)
    
    # Remove nulls
    result <- result[!sapply(result, is.null)]
    
    message("✅ CV fits found for assets: ", paste(names(result), collapse = ", "))
    
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

# Helper to evaluate results across the 65/35 chronological split

compare_results <- function(cv_result_list, model_name, is_cv = FALSE) {
  if (length(cv_result_list) == 0) return(NULL)
  
  all_rows <- list()
  
  for (asset_name in names(cv_result_list)) {
    asset_result <- cv_result_list[[asset_name]]
    
    for (window_eval in asset_result) {
      # Ensure it's a data frame
      if (!is.null(window_eval) && is.data.frame(window_eval)) {
        # Add metadata
        window_eval$Asset <- asset_name
        window_eval$Model <- model_name
        window_eval$Type  <- ifelse(is_cv, "CV", "Chrono")
        
        all_rows[[length(all_rows) + 1]] <- window_eval
      }
    }
  }
  
  if (length(all_rows) == 0) return(NULL)
  
  # Before binding, make sure all have the same columns
  common_cols <- Reduce(intersect, lapply(all_rows, names))
  all_rows <- lapply(all_rows, function(df) df[, common_cols, drop = FALSE])
  
  return(bind_rows(all_rows))
}


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


#### Forecast Financial Data ####

# Helper to forecast financial returns data across each GARCH model for 40 days into the future

forecast_models <- function(fit_list, n.ahead = 40) {
  lapply(fit_list, function(fit) ugarchforecast(fitORspec = fit, n.ahead = n.ahead))
}

# Forecast financial data for models trained on 65/35 Chrono Split
Forecasts_Chrono_Split <- lapply(Fitted_Chrono_Split_models, forecast_models, n.ahead = 40)

####  Helpers for the Evaluation of Forecasted Financial Data ####

# Helper to rank results of forecasted financial data

rank_models <- function(results_df, label = NULL) 
{
  results_df %>%
    group_by(Model) %>%
    summarise(
      Avg_AIC      = mean(AIC, na.rm = TRUE),
      Avg_BIC      = mean(BIC, na.rm = TRUE),
      Avg_LL       = mean(LogLikelihood, na.rm = TRUE),
      Avg_MSE      = mean(`MSE..Forecast.vs.Actual.`, na.rm = TRUE),
      Avg_MAE      = mean(`MAE..Forecast.vs.Actual.`, na.rm = TRUE),
      Mean_Q_Stat  = mean(`Q.Stat..p.0.05.`, na.rm = TRUE),
      Mean_ARCH_LM = mean(`ARCH.LM..p.0.05.`, na.rm = TRUE),
      .groups = 'drop'
    ) %>%
    arrange(Avg_MSE) %>%
    mutate(Source = label)
}  

####  Evaluate the Forecasted Financial Data ####  

# Compare results for 65/35 forecast
All_Results_Chrono_Split <- data.frame()

for (key in names(Fitted_Chrono_Split_models)) 
{
  model_set    <- Fitted_Chrono_Split_models[[key]]
  forecast_set <- Forecasts_Chrono_Split[[key]]
  
  asset_type <- ifelse(startsWith(key, "equity"), "equity", "fx")
  model_name <- gsub("^(equity|fx)_", "", key)
  return_list <- if (asset_type == "equity") equity_returns else fx_returns
  
  comparison <- setNames(
    Map(function(fit, forecast, ret) evaluate_model(fit, forecast, ret), 
        model_set, forecast_set, return_list), 
    names(model_set)
  )
  
  # Inject model name and type into each comparison entry
  comparison_df <- bind_rows(lapply(names(comparison), function(asset_name) {
    df <- comparison[[asset_name]]
    if (!is.null(df)) {
      df$Asset <- asset_name
      df$Model <- model_name
      df$Type  <- "Chrono"
      return(df)
    }
    return(NULL)
  }))
  
  # ✅ If comparison exists, inject model and type info
  if (!is.null(comparison)) {
    comparison$Model <- model_name
    comparison$Type  <- "Chrono"
    # Append to final results
    All_Results_Chrono_Split <- bind_rows(All_Results_Chrono_Split, comparison_df)
  }
}

names(All_Results_Chrono_Split)

# Compare and rank the results from all CV models across window size of x and a forecast horizon of y
cv_asset_model_summary <- Fitted_TS_CV_models %>%
  group_by(Model) %>%
  summarise(
    Avg_AIC  = mean(AIC, na.rm = TRUE),
    Avg_BIC  = mean(BIC, na.rm = TRUE),
    Avg_LL   = mean(LogLikelihood, na.rm = TRUE),
    Avg_MSE  = mean(`MSE..Forecast.vs.Actual.`, na.rm = TRUE),
    Avg_MAE  = mean(`MAE..Forecast.vs.Actual.`, na.rm = TRUE),
    Mean_Q_Stat = mean(`Q.Stat..p.0.05.`, na.rm = TRUE),
    Mean_ARCH_LM = mean(`ARCH.LM..p.0.05.`, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(Avg_MSE)

# Consolidate and compare the results of the Chrono split and TS CV split 
ranking_chrono <- rank_models(All_Results_Chrono_Split, "Chrono_Split")
ranking_cv     <- rank_models(Fitted_TS_CV_models, "TS_CV")
ranking_combined <- bind_rows(ranking_chrono, ranking_cv)


# Plot results of forecasted financial data
plot_and_save_volatility_forecasts <- function(forecast_list, model_name, asset_type) 
{
  dir_path <- file.path("results/plots/exhaustive", paste0("volatility_", model_name, "_", asset_type))
  dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
  
  for (asset in names(forecast_list)) {
    sigma_vals <- sigma(forecast_list[[asset]])
    
    png(file.path(dir_path, paste0(asset, "_volatility.png")), width = 800, height = 600)
    plot(sigma_vals, main = paste("Volatility Forecast:", asset, "-", model_name), col = "blue", ylab = "Volatility")
    dev.off()
  }
}

for (key in names(Forecasts_Chrono_Split)) {
  asset_type <- ifelse(startsWith(key, "equity"), "equity", "fx")
  model_name <- gsub("^(equity|fx)_", "", key)
  plot_and_save_volatility_forecasts(Forecasts_Chrono_Split[[key]], model_name, asset_type)
}


#### Save Results ####

# Create a new workbook
wb <- createWorkbook()

# Add each sheet
addWorksheet(wb, "Chrono_Split_Eval")
writeData(wb, "Chrono_Split_Eval", All_Results_Chrono_Split)

addWorksheet(wb, "CV_Results")
writeData(wb, "CV_Results", Fitted_TS_CV_models)

addWorksheet(wb, "CV_Asset_Model_Summary")
writeData(wb, "CV_Asset_Model_Summary", cv_asset_model_summary)

addWorksheet(wb, "CV_Results_All")
writeData(wb, "CV_Results_All", Fitted_TS_CV_models)

addWorksheet(wb, "Model_Ranking_All")
writeData(wb, "Model_Ranking_All", ranking_combined)


saveWorkbook(wb, "1. NFGARCH - Train and Compare Forecasted Data.xlsx", overwrite = TRUE)


