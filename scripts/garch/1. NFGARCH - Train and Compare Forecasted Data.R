#Reminder to Set your Working Directory

#### Install Packages ####
# Uncomment below if running for the first time
# install.packages(c("tidyverse", "rugarch", "quantmod", "xts", "PerformanceAnalytics", "FinTS", "openxlsx"))
# install.packages("tidyr")
# install.packages("dplyr")
# install.packages("quantmod")
# install.packages("tseries")
# install.packages("rugarch")
# install.packages("xts")
# install.packages("PerformanceAnalytics")
# install.packages("stringr")
# install.packages("FinTS")
# install.packages("openxlsx")

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

#### Import the Equity data ####

# Main Tickers
  equity_tickers <- c("NVDA", "AAPL", "AMZN", "DJT", "TSLA", "MLGO")
  fx_names <- c("EURUSD", "GBPUSD", "GBPCNY","USDZAR", "GBPZAR", "EURZAR")
  
# Pull the Equity data
  equity_data <- lapply(equity_tickers, function(ticker) 
      {
      quantmod::getSymbols(ticker, from = "2000-01-04", to = "2024-08-30", auto.assign = FALSE)[, 6]
      }
    )
  
  names(equity_data) <- equity_tickers


#### Import the FX data ####

FX_data <- read.csv(file = "./data/raw/raw.csv") %>% 
  dplyr::mutate(
    Date = stringr::str_replace_all(Date, "-", ""),  # Remove dashes from dates
    Date = lubridate::ymd(Date)  # Convert strings to Date objects
                ) 

#### Clean the FX data####

fx_data <- lapply(fx_names, function(name) 
    {
    xts(FX_data[[name]], order.by = FX_data$Date)
    }
  )

names(fx_data) <- fx_names

#### Calculate Returns on Equity data ####

equity_returns <- lapply(equity_data, function(x) CalculateReturns(x)[-1, ])

#### Calculate Returns on FX data ####

# Convert FX series to xts objects

fx_returns <- lapply(fx_data, function(x) diff(log(x))[-1, ])

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
    fx_results <- compare_results(Fitted_FX_TS_CV_models[[model_name]], model_name, is_cv = TRUE)
    eq_results <- compare_results(Fitted_EQ_TS_CV_models[[model_name]], model_name, is_cv = TRUE)
    Fitted_TS_CV_models <- rbind(Fitted_TS_CV_models, fx_results, eq_results)
  }

#### Forecast Financial Data ####
  
# Helper to forecast financial returns data across each GARCH model for 40 days into the future

  forecast_models <- function(fit_list, n.ahead = 40) {
    lapply(fit_list, function(fit) ugarchforecast(fitORspec = fit, n.ahead = n.ahead))
  }

# Forecast financial data for models trained on 65/35 Chrono Split
  Forecasts_Chrono_Split <- lapply(Fitted_Chrono_Split_models, forecast_models, n.ahead = 40)

####  Helpers for the Evaluation of Forecasted Financial Data ####

# Helper to evaluate results across the 65/35 chronological split
  
  compare_results <- function(results_list, model_name, is_cv = FALSE) 
  {
    All_Results_Chrono_Split <- data.frame()
    
    for (asset in names(results_list)) {
      result <- results_list[[asset]]
      if (!is.null(result)) {
        result$Asset <- asset
        result$Model <- model_name
        
        if (is_cv && !"WindowStart" %in% names(result)) {
          result$WindowStart <- NA  # pad if needed for uniformity
        }
        
        All_Results_Chrono_Split <- rbind(All_Results_Chrono_Split, result)
      }
    }
    
    return(All_Results_Chrono_Split)
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
    model_set <- Fitted_Chrono_Split_models[[key]]
    forecast_set <- Forecasts_Chrono_Split[[key]]
    
    asset_type <- ifelse(startsWith(key, "equity"), "equity", "fx")
    model_name <- gsub("^(equity|fx)_", "", key)
    return_list <- if (asset_type == "equity") equity_returns else fx_returns
    
    comparison <- compare_results(
      setNames(Map(function(fit, forecast, ret) evaluate_model(fit, forecast, ret), 
                   model_set, forecast_set, return_list), 
               names(model_set)),
      model_name,
      is_cv = FALSE
    )
    
    All_Results_Chrono_Split <- rbind(All_Results_Chrono_Split, comparison)
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

addWorksheet(wb, "Synthetic_Chrono_Eval")
writeData(wb, "Synthetic_Chrono_Eval", synth_chrono_results)

addWorksheet(wb, "Synthetic_CV_Eval")
writeData(wb, "Synthetic_CV_Eval", synth_cv_results)

addWorksheet(wb, "All_Model_Ranking")
writeData(wb, "All_Model_Ranking", ranking_all_combined)

addWorksheet(wb, "Synthetic_Distribution_Eval")
writeData(wb, "Synthetic_Distribution_Eval", simulation_results)

addWorksheet(wb, "Synthetic_Distribution_Rank")
writeData(wb, "Synthetic_Distribution_Rank", simulation_ranking)

addWorksheet(wb, "Synth_CV_Asset_Summary")
writeData(wb, "Synth_CV_Asset_Summary", synth_cv_asset_summary)

addWorksheet(wb, "NF_GARCH_Eval")
writeData(wb, "NF_GARCH_Eval", nf_results_df)

saveWorkbook(wb, "1. NFGARCH - Train and Compare Forecasted Data.xlsx", overwrite = TRUE)


