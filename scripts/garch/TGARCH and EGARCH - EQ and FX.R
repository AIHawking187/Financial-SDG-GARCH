#Reminder to Set your Working Directory

#### Install Packages ####
# install.packages("tidyverse")
# install.packages("tidyr")
# install.packages("dplyr")
# install.packages("devtools")
# install.packages("magrittr")
# install.packages("quantmod")
# install.packages("tseries")
# install.packages("rugarch")
# install.packages("xts")
# install.packages("PerformanceAnalytics")
# install.packages("stringr")
# install.packages("FinTS")
# devtools::install_github("tidyverse/tidyr")
# install.packages(c("quantmod", "rvest", "dplyr", "xts", "stringr"))
# install.packages("openxlsx")


library(openxlsx)
library(tidyverse)
library(tidyr)
library(dplyr)
library(devtools)
library(magrittr)
library(quantmod)
library(tseries)
library(rugarch)
library(xts)
library(PerformanceAnalytics)
library(stringr)
library(rvest)
library(FinTS)  # For ArchTest

#### Import the Equity data ####

equity_tickers <- c("NVDA", "AAPL", "AMZN", "DJT", "PDCO", "MLGO")
fx_names <- c("EURUSD", "GBPUSD", "GBPCNY","USDZAR", "GBPZAR", "EURZAR")


equity_data <- lapply(equity_tickers, function(ticker) 
  {
  quantmod::getSymbols(ticker, from = "2000-01-04", to = "2024-08-30", auto.assign = FALSE)[, 6]
  })

names(equity_data) <- equity_tickers

#### Check on the quality of the Equity Data #### 

# Pull the Equity data for the check [Include all 6 Columns]
equity_data_check <- lapply(equity_tickers, function(ticker) {
  quantmod::getSymbols(ticker, from = "2000-01-04", to = "2024-08-30", auto.assign = FALSE)
})
names(equity_data_check) <- equity_tickers

# Check the total observations, missing values and average daily trading volumes
check_equity_quality <- function(data, ticker) {
  if (ncol(data) < 5) {
    cat("\nTicker:", ticker, "- Skipped (Insufficient columns)\n")
    return()
  }
  
  close_prices <- data[, 4]   # Close
  volume       <- data[, 5]   # Volume
  
  cat("\nTicker:", ticker)
  cat("\nDate Range:", index(first(data)), "to", index(last(data)))
  cat("\nTotal Observations:", nrow(data))
  cat("\nMissing Close Prices:", sum(is.na(close_prices)))
  cat("\nAverage Daily Volume:", round(mean(volume, na.rm = TRUE), 2), "\n")
}

for (i in seq_along(equity_data_check)) {
  check_equity_quality(equity_data_check[[i]], names(equity_data_check)[i])
}

# Visualize the volume and price history to assess liquidity visually
for (i in equity_tickers) {
  chartSeries(equity_data_check[[i]], theme = chartTheme("white"), TA = "addVo();addSMA(50)", name = i)
  Sys.sleep(0)  # Optional pause between charts
}

# Rank the equity data across the average trading volumes 
avg_volumes <- sapply(equity_data_check, function(x) mean(Vo(x), na.rm = TRUE))
sort(avg_volumes, decreasing = TRUE)


#### Import the FX data ####

FX_data <- read.csv(file = "../input/raw.csv") %>% 
  dplyr::mutate(
    Date = stringr::str_replace_all(Date, "-", ""),  # Remove dashes from dates
    Date = lubridate::ymd(Date)  # Convert strings to Date objects
                ) 

#### Clean Equity and FX data####

fx_data <- lapply(fx_names, function(name) 
  {
  xts(FX_data[[name]], order.by = FX_data$Date)
  })

names(fx_data) <- fx_names

#### Calculate Returns on Equity data ####

equity_returns <- lapply(equity_data, function(x) CalculateReturns(x)[-1, ])

#### Calculate Returns on FX data ####

# Convert FX series to xts objects

fx_returns <- lapply(fx_data, function(x) diff(log(x))[-1, ])

#### Plotting Helpers ####

plot_returns <- function(returns_list, title_prefix = "") 
  {
  for (name in names(returns_list)) 
    {
    chart.Histogram(returns_list[[name]], 
                    method = c("add.density", "add.normal"),
                    main = paste0(title_prefix, name),
                    colorset = c("blue", "red", "black"))
    }
  }

plot_returns(equity_returns)


#### Model Generator using Skewed Distribution - Automated across Normal and Student's T distribution ####

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

equity_gjr_models <- fit_models(equity_returns, "gjrGARCH", "sstd")
fx_egarch_models   <- fit_models(fx_returns, "eGARCH", "sstd")

#### Fit the GARCH Models ####
model_configs <- list(
                      sGARCH_norm  = list(model = "sGARCH", dist = "norm", submodel = NULL),
                      sGARCH_sstd  = list(model = "sGARCH", dist = "sstd", submodel = NULL),
                      gjrGARCH     = list(model = "gjrGARCH", dist = "sstd", submodel = NULL),
                      eGARCH       = list(model = "eGARCH", dist = "sstd", submodel = NULL),
                      TGARCH       = list(model = "fGARCH", dist = "sstd", submodel = "TGARCH")
                      )  # Change the distributional assumptions of the ARCH and GARCH parameters here

all_model_fits <- list()

for (config_name in names(model_configs)) 
  {
  cfg <- model_configs[[config_name]]
  
  equity_fit <- fit_models(equity_returns, model_type = cfg$model, dist_type = cfg$dist, submodel = cfg$submodel)
  fx_fit     <- fit_models(fx_returns, model_type = cfg$model, dist_type = cfg$dist, submodel = cfg$submodel)
  
  all_model_fits[[paste0("equity_", config_name)]] <- equity_fit
  all_model_fits[[paste0("fx_", config_name)]]     <- fx_fit
  }

#### Data Splitting ####
## Chronological Data Split
# Helper to get cutoff index
get_split_index <- function(x, split_ratio = 0.65) {
  return(floor(nrow(x) * split_ratio))
}

# Split returns into train/test
fx_train_returns <- lapply(fx_returns, function(x) x[1:get_split_index(x)])
fx_test_returns  <- lapply(fx_returns, function(x) x[(get_split_index(x) + 1):nrow(x)])

equity_train_returns <- lapply(equity_returns, function(x) x[1:get_split_index(x)])
equity_test_returns  <- lapply(equity_returns, function(x) x[(get_split_index(x) + 1):nrow(x)])

#Sliding Window Time-Series Cross-Validation
## Time-series cross-validation

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

ts_cross_validate <- function(returns, model_type, dist_type = "sstd", submodel = NULL, 
                              window_size = 500, step_size = 50, forecast_horizon = 20) {
  n <- nrow(returns)
  results <- list()
  
  for (start_idx in seq(1, n - window_size - forecast_horizon, by = step_size)) {
    train_set <- returns[start_idx:(start_idx + window_size - 1)]
    test_set  <- returns[(start_idx + window_size):(start_idx + window_size + forecast_horizon - 1)]
    
    spec <- generate_spec(model_type, dist_type, submodel)
    
    try({
      fit <- ugarchfit(data = train_set, spec = spec, solver = "hybrid")
      forecast <- ugarchforecast(fit, n.ahead = forecast_horizon)
      eval <- evaluate_model(fit, forecast, test_set)
      eval$WindowStart <- index(train_set[1])
      results[[length(results) + 1]] <- eval
    }, silent = TRUE)
  }
  
  if (length(results) == 0) return(NULL)
  do.call(rbind, results)
}

valid_fx_returns <- fx_returns[sapply(fx_returns, function(x) {
  nrow(x) > 520 && sd(x, na.rm = TRUE) > 0  # Ensure sufficient size and variability
})]

cv_fx_gjr <- lapply(valid_fx_returns, function(ret) 
  ts_cross_validate(ret, model_type = "gjrGARCH", dist_type = "sstd", window_size = 500, forecast_horizon = 20)
)


cv_equity_egarch <- lapply(equity_returns, function(ret) 
  ts_cross_validate(ret, model_type = "eGARCH", dist_type = "sstd", window_size = 500, forecast_horizon = 20)
)


cv_fx_gjr <- cv_fx_gjr[!sapply(cv_fx_gjr, is.null)]
cv_equity_egarch <- cv_equity_egarch[!sapply(cv_equity_egarch, is.null)]

#### Forecast Helper ####

forecast_models <- function(fit_list, n.ahead = 40) {
  lapply(fit_list, function(fit) ugarchforecast(fitORspec = fit, n.ahead = n.ahead))
}

equity_gjr_forecasts <- forecast_models(equity_gjr_models, n.ahead = 40)
fx_egarch_forecasts  <- forecast_models(fx_egarch_models, n.ahead = 40)

all_forecasts <- lapply(all_model_fits, forecast_models, n.ahead = 40)

#### Evaluation ####




compare_models <- function(model_list, forecast_list, returns_list, model_name) 
  {
  all_results <- data.frame()
  
  for (asset in names(model_list)) 
    {
    fit <- model_list[[asset]]
    fcast <- forecast_list[[asset]]
    returns <- returns_list[[asset]]
    
    metrics <- evaluate_model(fit, fcast, returns)
    metrics$Asset <- asset
    metrics$Model <- model_name
    all_results <- rbind(all_results, metrics)
    }
  
    return(all_results)
  }

# Aggregate cross-validation metrics for each asset and model
compare_cv_models <- function(cv_results_list, model_name) {
  all_results <- data.frame()
  
  for (asset in names(cv_results_list)) {
    results <- cv_results_list[[asset]]
    results$Asset <- asset
    results$Model <- model_name
    all_results <- rbind(all_results, results)
  }
  
  return(all_results)
}


results_equity_gjr <- compare_models(equity_gjr_models, equity_gjr_forecasts, equity_returns, "GJR-GARCH_sstd")
results_fx_egarch  <- compare_models(fx_egarch_models, fx_egarch_forecasts, fx_returns, "eGARCH_sstd")

all_results <- data.frame()

cv_fx_gjr_summary     <- compare_cv_models(cv_fx_gjr, "GJR-GARCH_sstd")
cv_equity_egarch_summary <- compare_cv_models(cv_equity_egarch, "eGARCH_sstd")

# Combine all CV results
cv_all_results <- rbind(cv_fx_gjr_summary, cv_equity_egarch_summary)



for (key in names(all_model_fits)) {
  model_set <- all_model_fits[[key]]
  forecast_set <- all_forecasts[[key]]
  
  asset_type <- ifelse(startsWith(key, "equity"), "equity", "fx")
  model_name <- gsub("^(equity|fx)_", "", key)
  return_list <- if (asset_type == "equity") equity_returns else fx_returns
  
  comparison <- compare_models(model_set, forecast_set, return_list, model_name)
  all_results <- rbind(all_results, comparison)
}

names(all_results)

model_ranking <- all_results %>%
  group_by(Model) %>%
  dplyr::summarise(
    Avg_AIC  = mean(AIC, na.rm = TRUE),
    Avg_BIC  = mean(BIC, na.rm = TRUE),
    Avg_LL   = mean(LogLikelihood, na.rm = TRUE),
    Avg_MSE  = mean(`MSE..Forecast.vs.Actual.`, na.rm = TRUE),
    Avg_MAE  = mean(`MAE..Forecast.vs.Actual.`, na.rm = TRUE),
    Mean_Q_Stat = mean(`Q.Stat..p.0.05.`, na.rm = TRUE),
    Mean_ARCH_LM = mean(`ARCH.LM..p.0.05.`, na.rm = TRUE)
  ) %>%
  arrange(Avg_MSE)

print(model_ranking)

model_ranking_cv <- cv_all_results %>%
  group_by(Model) %>%
  summarise(
    Avg_AIC        = mean(AIC, na.rm = TRUE),
    Avg_BIC        = mean(BIC, na.rm = TRUE),
    Avg_LL         = mean(LogLikelihood, na.rm = TRUE),
    Avg_MSE        = mean(`MSE..Forecast.vs.Actual.`, na.rm = TRUE),
    Avg_MAE        = mean(`MAE..Forecast.vs.Actual.`, na.rm = TRUE),
    Mean_Q_Stat    = mean(`Q.Stat..p.0.05.`, na.rm = TRUE),
    Mean_ARCH_LM   = mean(`ARCH.LM..p.0.05.`, na.rm = TRUE)
  ) %>%
  arrange(Avg_MSE)


cv_asset_model_summary <- cv_all_results %>%
  group_by(Model, Asset) %>%
  summarise(
    Avg_MSE = mean(`MSE..Forecast.vs.Actual.`, na.rm = TRUE),
    Avg_MAE = mean(`MAE..Forecast.vs.Actual.`, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(Model, Avg_MSE)


plot_volatility_forecasts <- function(forecast_list, title_prefix = "") {
  par(mfrow = c(2, 3))
  for (name in names(forecast_list)) {
    sigma_vals <- sigma(forecast_list[[name]])
    plot(sigma_vals, main = paste0(title_prefix, name), col = "blue", ylab = "Volatility")
  }
}

plot_volatility_forecasts(equity_gjr_forecasts, title_prefix = "GJR-GARCH - ")
plot_volatility_forecasts(fx_egarch_forecasts, title_prefix = "eGARCH - ")

#Export the Results
write.csv(all_results, "garch_comparison.csv", row.names = FALSE)
write.csv(cv_all_results, "garch_cv_results.csv", row.names = FALSE)
write.csv(model_ranking_cv, "garch_cv_model_ranking.csv", row.names = FALSE)
write.csv(model_ranking, "garch_test_model_ranking.csv", row.names = FALSE)

# Create a new workbook
wb <- createWorkbook()

# Add each sheet
addWorksheet(wb, "Chrono_Split_Eval")
writeData(wb, "Chrono_Split_Eval", all_results)

addWorksheet(wb, "CV_Results")
writeData(wb, "CV_Results", cv_all_results)

addWorksheet(wb, "CV_Model_Ranking")
writeData(wb, "CV_Model_Ranking", model_ranking_cv)

addWorksheet(wb, "Test_Model_Ranking")
writeData(wb, "Test_Model_Ranking", model_ranking)

addWorksheet(wb, "CV_Asset_Model_Summary")
writeData(wb, "CV_Asset_Model_Summary", cv_asset_model_summary)

# Save the workbook
saveWorkbook(wb, "GARCH_Model_Evaluation_Summary.xlsx", overwrite = TRUE)



#Export the equity data

# # Combine list of xts objects into a single xts with aligned dates
# equity_data_xts <- do.call(merge, equity_data_check)
# 
# # Convert xts to data.frame for CSV export
# equity_data_df <- data.frame(Date = index(equity_data_xts), coredata(equity_data_xts))
# 
# # Write to CSV
# write.csv(equity_data_df, "equity_data.csv", row.names = FALSE)

# Run all CV Models

run_all_cv_models <- function(returns_list, model_configs, window_size = 500, forecast_horizon = 20) {
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

# Optional: Clean returns beforehand
valid_fx_returns <- fx_returns[sapply(fx_returns, function(x) nrow(x) > 520 && sd(x, na.rm = TRUE) > 0)]
valid_equity_returns <- equity_returns[sapply(equity_returns, function(x) nrow(x) > 520 && sd(x, na.rm = TRUE) > 0)]

cv_fx_all_models     <- run_all_cv_models(valid_fx_returns, model_configs)
cv_equity_all_models <- run_all_cv_models(valid_equity_returns, model_configs)

compare_cv_models <- function(cv_results_list, model_name) {
  all_results <- data.frame()
  
  for (asset in names(cv_results_list)) {
    results <- cv_results_list[[asset]]
    if (!is.null(results)) {
      results$Asset <- asset
      results$Model <- model_name
      all_results <- rbind(all_results, results)
    }
  }
  
  return(all_results)
}

# Flatten all CV results into one data frame
cv_all_results <- data.frame()

for (model_name in names(cv_fx_all_models)) {
  fx_results <- compare_cv_models(cv_fx_all_models[[model_name]], model_name)
  eq_results <- compare_cv_models(cv_equity_all_models[[model_name]], model_name)
  
  cv_all_results <- rbind(cv_all_results, fx_results, eq_results)
}


write.csv(cv_all_results, "garch_cv_results_all_models.csv", row.names = FALSE)

cv_model_ranking_all <- cv_all_results %>%
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

write.csv(cv_model_ranking_all, "garch_cv_model_ranking_all.csv", row.names = FALSE)

addWorksheet(wb, "CV_Results_All")
writeData(wb, "CV_Results_All", cv_all_results)

addWorksheet(wb, "CV_Model_Ranking_All")
writeData(wb, "CV_Model_Ranking_All", cv_model_ranking_all)

saveWorkbook(wb, "GARCH_Model_Evaluation_Summary.xlsx", overwrite = TRUE)

