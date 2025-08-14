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

# Source utility functions
source("./scripts/utils/safety_functions.R")

#### Import the Equity data ####

# Main Tickers
  # equity_tickers <- c("NVDA", "AAPL", "AMZN", "DJT", "PDCO", "MLGO")
  equity_tickers <- c("NVDA", "AAPL", "AMZN", "DJT", "MLGO")
  fx_names <- c("EURUSD", "GBPUSD", "GBPCNY","USDZAR", "GBPZAR", "EURZAR")
  
# Pull the Equity data
  equity_data <- lapply(equity_tickers, function(ticker) 
      {
      quantmod::getSymbols(ticker, from = "2000-01-04", to = "2024-08-30", auto.assign = FALSE)[, 6]
      }
    )
  
  names(equity_data) <- equity_tickers

#### Check on the quality of the Equity Data #### 

# Pull the Equity data for the check [Include all 6 Columns]
  equity_data_check <- lapply(equity_tickers, function(ticker) 
    {
    quantmod::getSymbols(ticker, from = "2000-01-04", to = "2024-08-30", auto.assign = FALSE)
    }
  )
  names(equity_data_check) <- equity_tickers
  
# Check the total observations, missing values and average daily trading volumes
  check_equity_quality <- function(data, ticker) 
    {
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
  
# Rank the equity data across the average trading volumes 
  avg_volumes <- sapply(equity_data_check, function(x) mean(Vo(x), na.rm = TRUE))
  sort(avg_volumes, decreasing = TRUE)


#### Import the FX data ####

FX_data <- read.csv(file = "./data/raw/raw (FX).csv") %>% 
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
ranking_combined <- add_row_safe(ranking_chrono, ranking_cv)


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

#### Generate Synthetic Financial Data ####

# Helper to simulate Synthetic Financial Data from respective GARCH model

  simulate_from_garch <- function(fit, n.sim = 1000, m.sim = 1) 
  {
    sim <- ugarchsim(fit, n.sim = n.sim, m.sim = m.sim)
    return(fitted(sim)[,1])
  }

# Generate Synthetic Financial Data from respective GARCH model trained under 65/35 Chrono Split 
  Synthetic_Returns_Chrono_Split <- list()
  
  for (model_key in names(Fitted_Chrono_Split_models)) 
  {
    model_list <- Fitted_Chrono_Split_models[[model_key]]
    for (asset in names(model_list)) {
      real_index <- if (asset %in% names(fx_returns)) {
        index(fx_returns[[asset]])
      } else {
        index(equity_returns[[asset]])
      }
      simulated  <- simulate_from_garch(model_list[[asset]], n.sim = length(real_index))
      Synthetic_Returns_Chrono_Split[[asset]] <- xts(simulated, order.by = real_index)
    }
  }

# Helper to Split Synthetic Financial Data to create a 65/35 Chrono Split to train a new model 
  
  split_Synthetic_Returns_Chrono_Split <- function(syn_returns_list, split_ratio = 0.65) 
  {
    chrono_split <- list()
    for (name in names(syn_returns_list)) {
      x <- syn_returns_list[[name]]
      idx <- get_split_index(x, split_ratio)
      chrono_split[[name]] <- list(
        train = x[1:idx],
        test  = x[(idx + 1):length(x)]
      )
    }
    return(chrono_split)
  }
  
# Split Synthetic Financial Data to create a 65/35 Chrono Split to train a new model   
  
  synthetic_chrono_split <- split_Synthetic_Returns_Chrono_Split(Synthetic_Returns_Chrono_Split)

# Helper to fit GARCH model on Synthetic Financial Data across a 65/35 Chrono Split 
  
  fit_synthetic_models <- function(split_list, model_configs) 
  {
    all_synth_fits <- list()
    
    for (model_name in names(model_configs)) {
      cfg <- model_configs[[model_name]]
      
      fits <- lapply(split_list, function(s) {
        tryCatch({
          spec <- generate_spec(cfg$model, cfg$dist, cfg$submodel)
          ugarchfit(data = s$train, spec = spec)
        }, error = function(e) NULL)
      })
      
      names(fits) <- names(split_list)
      all_synth_fits[[model_name]] <- fits
    }
    return(all_synth_fits)
  }
  
# Fit GARCH model on Synthetic Financial Data across a 65/35 Chrono Split   
  
  Fitted_Synth_Chrono_Split_Model <- fit_synthetic_models(synthetic_chrono_split, model_configs)

#### Evaluation of Synthetic Data ####

# Helper to evaluate the appropriateness of the Generated Synthetic Data
  
  evaluate_synthetic_data <- function(real, synthetic) {
    ks <- tryCatch(ks.test(synthetic, real)$statistic, error = function(e) NA)
    jb <- tryCatch(jarque.test(synthetic)$statistic, error = function(e) NA)
    
    return(data.frame(
      Mean = mean(synthetic, na.rm = TRUE),
      SD = sd(synthetic, na.rm = TRUE),
      Skewness = skewness(synthetic, na.rm = TRUE),
      Kurtosis = kurtosis(synthetic, na.rm = TRUE),
      KS_Distance = ks,
      Jarque_Bera = jb
    ))
  }

# Helper to evaluate the Synthetic data generated from the fitted Synthetic Chrono Split model using test data
  
  evaluate_simulated_chrono <- function(real_returns, sim_returns) 
  {
    test_idx <- get_split_index(real_returns, split_ratio = 0.65)
    evaluate_synthetic_data(real_returns[(test_idx + 1):length(real_returns)], sim_returns[(test_idx + 1):length(real_returns)])
  }

#  Helper to evaluate the Forecasted data generated from the fitted Synthetic Chrono Split model using test data

  evaluate_synth_chrono <- function(fit_list, split_list) 
    {
    results <- data.frame()
    
    for (model_name in names(fit_list)) {
      for (asset in names(fit_list[[model_name]])) {
        fit <- fit_list[[model_name]][[asset]]
        test <- split_list[[asset]]$test
        
        if (!is.null(fit)) {
          fcast <- ugarchforecast(fit, n.ahead = length(test))
          eval <- evaluate_model(fit, fcast, test)
          eval$Asset <- asset
          eval$Model <- model_name
          eval$Source <- "Synthetic_Chrono"
          results <- rbind(results, eval)
        }
      }
    }
    return(results)
  }

# Evaluate the Forecasted data generated from the fitted Synthetic Chrono Split model using test data  

  synth_chrono_results <- evaluate_synth_chrono(Fitted_Synth_Chrono_Split_Model, synthetic_chrono_split)

# Order the Synthetic data generated under the 65/35 Chrono Split

  Synthetic_Returns_Chrono_Split_xts <- lapply(Synthetic_Returns_Chrono_Split, function(x) xts(x, order.by = index(x)))

# Train more GARCH models under TS CV Data splitting using the Synthetic data generated under the 65/35 Chrono Split

  Fitted_TS_CV_Synth_Chrono_Split_Model <- run_all_cv_models(Synthetic_Returns_Chrono_Split_xts, model_configs)

# Evaluate the results of the GARCH models under TS CV Data splitting using the Synthetic data generated under the 65/35 Chrono Split
  synth_cv_results <- data.frame()
  
  for (model_name in names(Fitted_TS_CV_Synth_Chrono_Split_Model)) {
    res <- compare_results(Fitted_TS_CV_Synth_Chrono_Split_Model[[model_name]], model_name, is_cv = TRUE)
    res$Source <- "Synthetic_CV"
    synth_cv_results <- rbind(synth_cv_results, res)
  }

# Consolidate the results of evaluating the Synthetic data generated under the 65/35 Chrono Split and save the Synthetic returns

  simulation_results <- data.frame()
  
  for (model_key in names(Fitted_Chrono_Split_models)) 
  {
    model_list <- Fitted_Chrono_Split_models[[model_key]]
    asset_type <- ifelse(startsWith(model_key, "equity"), "equity", "fx")
    model_name <- gsub("^(equity|fx)_", "", model_key)
    return_list <- if (asset_type == "equity") equity_returns else fx_returns
    
    for (asset in names(model_list)) {
      fit <- model_list[[asset]]
      real <- as.numeric(return_list[[asset]])
      sim <- simulate_from_garch(fit, n.sim = length(real))
      
      # Save synthetic returns
      write.csv(data.frame(SimulatedReturns = sim),
                file = paste0("results/tables/synthetic/", asset_type, "_", model_name, "_", asset, "_sim.csv"),
                row.names = FALSE)
      
      # Evaluate
      stats <- evaluate_synthetic_data(real, sim)
      stats$Asset <- asset
      stats$Model <- model_name
      stats$Type <- asset_type
      
      simulation_results <- rbind(simulation_results, stats)
    }
  }

# Rank results of models in generating synthetic data

simulation_ranking <- simulation_results %>%
  group_by(Model) %>%
  summarise(
    Avg_KS   = mean(KS_Distance, na.rm = TRUE),
    Avg_JB   = mean(Jarque_Bera, na.rm = TRUE),
    Avg_Skew = mean(Skewness, na.rm = TRUE),
    Avg_Kurt = mean(Kurtosis, na.rm = TRUE)
  ) %>%
  arrange(Avg_KS)  # or arrange(Avg_JB) depending on what you prioritize

ranking_synth_chrono <- rank_models(synth_chrono_results, "Synthetic_Chrono")
ranking_synth_cv     <- rank_models(synth_cv_results, "Synthetic_CV")

ranking_all_combined <- Reduce(add_row_safe, list(ranking_chrono, ranking_cv, ranking_synth_chrono, ranking_synth_cv), init = data.frame())

synth_cv_asset_summary <- synth_cv_results %>%
  group_by(Model, Asset) %>%
  summarise(
    Avg_MSE = mean(`MSE..Forecast.vs.Actual.`, na.rm = TRUE),
    Avg_MAE = mean(`MAE..Forecast.vs.Actual.`, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(Model, Avg_MSE)

plot_and_save_real_vs_synthetic <- function(real_list, synthetic_list, model_name, asset_type) {
  dir_path <- file.path("results/plots/exhaustive", paste0("real_vs_synthetic_", model_name, "_", asset_type))
  dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
  
  for (asset in intersect(names(real_list), names(synthetic_list))) {
    real <- real_list[[asset]]
    synthetic <- synthetic_list[[asset]]
    
    png(file.path(dir_path, paste0(asset, "_real_vs_synthetic.png")), width = 800, height = 600)
    ts.plot(cbind(real, synthetic), col = c("black", "blue"), lty = c(1, 2),
            main = paste("Real vs Synthetic:", asset, "-", model_name),
            ylab = "Returns")
    legend("topright", legend = c("Real", "Synthetic"), col = c("black", "blue"), lty = c(1, 2))
    dev.off()
  }
}

for (key in names(Fitted_Chrono_Split_models)) {
  asset_type <- ifelse(startsWith(key, "equity"), "equity", "fx")
  model_name <- gsub("^(equity|fx)_", "", key)
  real_list  <- if (asset_type == "equity") equity_returns else fx_returns
  
  plot_and_save_real_vs_synthetic(real_list, Synthetic_Returns_Chrono_Split, model_name, asset_type)
}

plot_returns_and_save(Synthetic_Returns_Chrono_Split, "Synthetic")




# === Extract and Save Residuals for All FX and Equity Assets Across All Model Configs ===

# Ensure residuals directory exists
dir.create("residuals_by_model", recursive = TRUE, showWarnings = FALSE)

# Iterate through all model fits (equity_* and fx_*)
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
    # resid_num <- rep(NA, full_length)
    resid_num[1:n] <- as.numeric(resid_vec)[1:n]
    
    # Wrap in a data frame with column name
    resid_df <- data.frame(residual = resid_num)
    
    # Save
    write.csv(resid_df,
              file = file.path(model_dir, paste0(asset_type, "_", asset_name, "_residuals.csv")),
              row.names = FALSE)
  }
}


#### Load synthetic residuals ####

# Load all synthetic residual files from Python
nf_files <- list.files("nf_generated_residuals", pattern = "*.csv", full.names = TRUE)

# Parse model and asset from file names
nf_residuals_map <- list()
for (f in nf_files) {
  fname <- basename(f)
  key <- stringr::str_replace(fname, "\\.csv$", "") #e.g., fx_USDZAR_eGARCH_sstd_synthetic.csv → key = fx_USDZAR_eGARCH_sstd
  nf_residuals_map[[key]] <- read.csv(f)$residual
}



# Define an NF-GARCH Fitting Function

fit_nf_garch <- function(asset_name, asset_returns, model_config, nf_resid) {
  tryCatch({
    if (is.null(model_config$distribution) || !is.character(model_config$distribution)) {
      stop("Distribution must be a non-null character string.")
    }
    
    spec <- ugarchspec(
      mean.model     = list(armaOrder = c(0, 0)),
      variance.model = list(
        model = model_config$model,
        garchOrder = c(1, 1),
        submodel = model_config$submodel
      ),
      distribution.model = model_config$distribution
    )
    
    fit <- ugarchfit(spec = spec, data = asset_returns)
    fitted_pars <- coef(fit)
    spec_par_names <- names(ugarchfit(spec = spec, data = asset_returns, fit.control = list(scale = 1), solver = "hybrid")@fit$coef)
    
    # Ensure matching names and order
    if (!all(spec_par_names %in% names(fitted_pars))) {
      stop(paste("Mismatch in parameter names for", asset_name, model_config$model))
    }
    ordered_pars <- fitted_pars[spec_par_names]
    
    
    sim <- ugarchpath(
      spec,
      n.sim = length(asset_returns)/2,
      m.sim = 1,
      presigma = tail(sigma(fit), 1),
      preresiduals = tail(residuals(fit), 1),
      prereturns = tail(fitted(fit), 1),
      innovations = nf_resid[1:length(asset_returns)/2],
      pars = ordered_pars
    )
    
    fitted_values <- fitted(sim)
    mse <- mean((asset_returns - fitted_values)^2, na.rm = TRUE)
    mae <- mean(abs(asset_returns - fitted_values), na.rm = TRUE)
    
    return(data.frame(
      Model = model_config$model,
      Distribution = model_config$distribution,
      Asset = asset_name,
      AIC = infocriteria(fit)[1],
      BIC = infocriteria(fit)[2],
      LogLikelihood = likelihood(fit),
      MSE = mse,
      MAE = mae
    ))
  }, error = function(e) {
    message(paste("❌ Error for", asset_name, model_config$model, ":", e$message))
    return(NULL)
  })
}




# Loop Over All Assets & Model Configs

nf_results <- list()

for (config_name in names(model_configs)) {
  cfg <- model_configs[[config_name]]
  
  # FX
  for (asset in names(fx_returns)) {
    key <- paste0( config_name, "_", "fx_", asset, "_residuals_synthetic")
    if (!key %in% names(nf_residuals_map)) next
    cat("NF-GARCH (FX):", asset, config_name, "\n")
    r <- fit_nf_garch(asset, fx_returns[[asset]], cfg, nf_residuals_map[[key]])
    if (!is.null(r)) nf_results[[length(nf_results) + 1]] <- r
  }
  
  # Equity
  for (asset in names(equity_returns)) {
    key <- paste0( config_name, "_", "equity_", asset, "_residuals_synthetic")
    if (!key %in% names(nf_residuals_map)) next
    cat("NF-GARCH (EQ):", asset, config_name, "\n")
    r <- fit_nf_garch(asset, equity_returns[[asset]], cfg, nf_residuals_map[[key]])
    if (!is.null(r)) nf_results[[length(nf_results) + 1]] <- r
  }
}

nf_results_df <- do.call(rbind, nf_results)
nf_results_df$Source <- "NF"


# Combine & Rank All Models Including NF

All_Results_Chrono_Split$Source <- "Standard"
combined_eval <- add_row_safe(All_Results_Chrono_Split, nf_results_df)

combined_ranking <- combined_eval %>%
  dplyr::group_by(Source, Model) %>%
  dplyr::summarise(
    Avg_MSE = mean(MSE..Forecast.vs.Actual., na.rm = TRUE),
    Avg_MAE = mean(MAE..Forecast.vs.Actual., na.rm = TRUE),
    Avg_LL  = mean(LogLikelihood, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::arrange(Source, Avg_MSE)

# Plot Comparisons

library(ggplot2)

ggplot(combined_ranking, aes(x = Model, y = Avg_MSE, fill = Source)) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(title = "Avg MSE Comparison: NF vs Normal/SSTD", y = "Avg MSE", x = "") +
  theme_minimal()

plot_nf_vs_garch_residuals <- function(real_resid, nf_resid, asset, model) {
  hist_data <- data.frame(
    Value = c(real_resid, nf_resid),
    Type = rep(c("GARCH", "NF"), c(length(real_resid), length(nf_resid)))
  )
  
  ggplot(hist_data, aes(x = Value, fill = Type)) +
    geom_histogram(alpha = 0.5, position = "identity", bins = 60) +
    ggtitle(paste("Residual Distribution:", asset, "-", model)) +
    theme_minimal()
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

saveWorkbook(wb, "GARCH_Model_Evaluation_Summary.xlsx", overwrite = TRUE)


