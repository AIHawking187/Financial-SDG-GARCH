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

# equity_tickers <- c("NVDA", "AAPL", "AMZN", "DJT", "PDCO", "MLGO")
equity_tickers <- c("NVDA", "AAPL", "AMZN", "DJT", "MLGO")
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

FX_data <- read.csv(file = "./data/raw/fx_equity_prices.csv") %>% 
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


#### Forecast Financial Data ####

forecast_models <- function(fit_list, n.ahead = 40) {
  lapply(fit_list, function(fit) ugarchforecast(fitORspec = fit, n.ahead = n.ahead))
}

all_forecasts <- lapply(all_model_fits, forecast_models, n.ahead = 40)

#### Evaluation of Forecasted Financial Data ####

# Helpers

# Evaluate for 65/35 test set forecasts
evaluate_chrono_split <- function(fit_list, test_returns, model_name) {
  results <- data.frame()
  for (asset in names(fit_list)) {
    fit <- fit_list[[asset]]
    fcast <- ugarchforecast(fit, n.ahead = length(test_returns[[asset]]))
    eval <- evaluate_model(fit, fcast, test_returns[[asset]])
    eval$Asset <- asset
    eval$Model <- model_name
    results <- rbind(results, eval)
  }
  return(results)
}

chrono_split_results <- data.frame()
for (model_key in names(all_model_fits)) {
  model_list <- all_model_fits[[model_key]]
  asset_type <- ifelse(startsWith(model_key, "equity"), "equity", "fx")
  test_data  <- if (asset_type == "equity") equity_test_returns else fx_test_returns
  model_name <- gsub("^(equity|fx)_", "", model_key)
  chrono_split_results <- rbind(chrono_split_results, evaluate_chrono_split(model_list, test_data, model_name))
}


# Aggregate cross-validation metrics for each asset and model

compare_results <- function(results_list, model_name, is_cv = FALSE) {
  all_results <- data.frame()
  
  for (asset in names(results_list)) {
    result <- results_list[[asset]]
    if (!is.null(result)) {
      result$Asset <- asset
      result$Model <- model_name
      
      if (is_cv && !"WindowStart" %in% names(result)) {
        result$WindowStart <- NA  # pad if needed for uniformity
      }
      
      all_results <- rbind(all_results, result)
    }
  }
  
  return(all_results)
}

# Compare results for 65/35 forecast
all_results <- data.frame()

for (key in names(all_model_fits)) {
  model_set <- all_model_fits[[key]]
  forecast_set <- all_forecasts[[key]]
  
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
  
  all_results <- rbind(all_results, comparison)
}

names(all_results)


# Rank results of forecasted financial data

rank_models <- function(results_df, label = NULL) {
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


# model_ranking_cv <- cv_all_results %>%
#   group_by(Model) %>%
#   summarise(
#     Avg_AIC        = mean(AIC, na.rm = TRUE),
#     Avg_BIC        = mean(BIC, na.rm = TRUE),
#     Avg_LL         = mean(LogLikelihood, na.rm = TRUE),
#     Avg_MSE        = mean(`MSE..Forecast.vs.Actual.`, na.rm = TRUE),
#     Avg_MAE        = mean(`MAE..Forecast.vs.Actual.`, na.rm = TRUE),
#     Mean_Q_Stat    = mean(`Q.Stat..p.0.05.`, na.rm = TRUE),
#     Mean_ARCH_LM   = mean(`ARCH.LM..p.0.05.`, na.rm = TRUE)
#   ) %>%
#   arrange(Avg_MSE)



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

valid_fx_returns <- fx_returns[sapply(fx_returns, function(x) nrow(x) > 520 && sd(x, na.rm = TRUE) > 0)]
valid_equity_returns <- equity_returns[sapply(equity_returns, function(x) nrow(x) > 520 && sd(x, na.rm = TRUE) > 0)]

cv_fx_all_models     <- run_all_cv_models(valid_fx_returns, model_configs)
cv_equity_all_models <- run_all_cv_models(valid_equity_returns, model_configs)


# Flatten all CV results into one data frame
cv_all_results <- data.frame()

for (model_name in names(cv_fx_all_models)) {
  fx_results <- compare_results(cv_fx_all_models[[model_name]], model_name, is_cv = TRUE)
  eq_results <- compare_results(cv_equity_all_models[[model_name]], model_name, is_cv = TRUE)
  cv_all_results <- rbind(cv_all_results, fx_results, eq_results)
}


# Compare results for rolling CV
# cv_model_ranking_all <- cv_all_results %>%
#   group_by(Model) %>%
#   summarise(
#     Avg_AIC  = mean(AIC, na.rm = TRUE),
#     Avg_BIC  = mean(BIC, na.rm = TRUE),
#     Avg_LL   = mean(LogLikelihood, na.rm = TRUE),
#     Avg_MSE  = mean(`MSE..Forecast.vs.Actual.`, na.rm = TRUE),
#     Avg_MAE  = mean(`MAE..Forecast.vs.Actual.`, na.rm = TRUE),
#     Mean_Q_Stat = mean(`Q.Stat..p.0.05.`, na.rm = TRUE),
#     Mean_ARCH_LM = mean(`ARCH.LM..p.0.05.`, na.rm = TRUE),
#     .groups = 'drop'
#   ) %>%
#   arrange(Avg_MSE)

ranking_chrono <- rank_models(all_results, "Chrono_Split")
ranking_cv     <- rank_models(cv_all_results, "TS_CV")
ranking_combined <- bind_rows(ranking_chrono, ranking_cv)

cv_asset_model_summary <- cv_all_results %>%
  group_by(Model, Asset) %>%
  summarise(
    Avg_MSE = mean(`MSE..Forecast.vs.Actual.`, na.rm = TRUE),
    Avg_MAE = mean(`MAE..Forecast.vs.Actual.`, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(Model, Avg_MSE)

# Plot results of forecasted financial data
plot_and_save_volatility_forecasts <- function(forecast_list, model_name, asset_type) {
  dir_path <- file.path("results/plots/exhaustive", paste0("volatility_", model_name, "_", asset_type))
  dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
  
  for (asset in names(forecast_list)) {
    sigma_vals <- sigma(forecast_list[[asset]])
    
    png(file.path(dir_path, paste0(asset, "_volatility.png")), width = 800, height = 600)
    plot(sigma_vals, main = paste("Volatility Forecast:", asset, "-", model_name), col = "blue", ylab = "Volatility")
    dev.off()
  }
}

for (key in names(all_forecasts)) {
  asset_type <- ifelse(startsWith(key, "equity"), "equity", "fx")
  model_name <- gsub("^(equity|fx)_", "", key)
  plot_and_save_volatility_forecasts(all_forecasts[[key]], model_name, asset_type)
}


#### Generate Synthetic Financial Data ####
# Helper
simulate_from_garch <- function(fit, n.sim = 1000, m.sim = 1) {
  sim <- ugarchsim(fit, n.sim = n.sim, m.sim = m.sim)
  return(fitted(sim)[,1])
}

synthetic_returns <- list()

for (model_key in names(all_model_fits)) {
  model_list <- all_model_fits[[model_key]]
  for (asset in names(model_list)) {
    real_index <- if (asset %in% names(fx_returns)) {
      index(fx_returns[[asset]])
    } else {
      index(equity_returns[[asset]])
    }
    simulated  <- simulate_from_garch(model_list[[asset]], n.sim = length(real_index))
    synthetic_returns[[asset]] <- xts(simulated, order.by = real_index)
  }
}



split_synthetic_returns <- function(syn_returns_list, split_ratio = 0.65) {
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

synthetic_chrono_split <- split_synthetic_returns(synthetic_returns)


fit_synthetic_models <- function(split_list, model_configs) {
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

synth_model_fits <- fit_synthetic_models(synthetic_chrono_split, model_configs)


#### Evaluation of Synthetic Data ####

# Helper
evaluate_simulation <- function(real, synthetic) {
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

evaluate_simulated_chrono <- function(real_returns, sim_returns) {
  test_idx <- get_split_index(real_returns, split_ratio = 0.65)
  evaluate_simulation(real_returns[(test_idx + 1):length(real_returns)], sim_returns[(test_idx + 1):length(real_returns)])
}

evaluate_synth_chrono <- function(fit_list, split_list) {
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

synth_chrono_results <- evaluate_synth_chrono(synth_model_fits, synthetic_chrono_split)

synthetic_returns_xts <- lapply(synthetic_returns, function(x) xts(x, order.by = index(x)))

synth_cv_models <- run_all_cv_models(synthetic_returns_xts, model_configs)

synth_cv_results <- data.frame()
for (model_name in names(synth_cv_models)) {
  res <- compare_results(synth_cv_models[[model_name]], model_name, is_cv = TRUE)
  res$Source <- "Synthetic_CV"
  synth_cv_results <- rbind(synth_cv_results, res)
}



simulation_results <- data.frame()

for (model_key in names(all_model_fits)) {
  model_list <- all_model_fits[[model_key]]
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
    stats <- evaluate_simulation(real, sim)
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

ranking_all_combined <- bind_rows(ranking_chrono, ranking_cv, ranking_synth_chrono, ranking_synth_cv)

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

for (key in names(all_model_fits)) {
  asset_type <- ifelse(startsWith(key, "equity"), "equity", "fx")
  model_name <- gsub("^(equity|fx)_", "", key)
  real_list  <- if (asset_type == "equity") equity_returns else fx_returns
  
  plot_and_save_real_vs_synthetic(real_list, synthetic_returns, model_name, asset_type)
}

plot_returns_and_save(synthetic_returns, "Synthetic")


#### To enable training of a Normalizing Flow (NF) on GARCH residuals ####
fx_egarch_models <- fit_models(fx_returns, "eGARCH", "sstd")


# === Extract and Save Residuals for USDZAR ===
usdzar_fit <- fx_egarch_models$USDZAR
usdzar_resid <- residuals(usdzar_fit, standardize = TRUE)

write.csv(as.numeric(usdzar_resid), "residuals_usdzar.csv", row.names = FALSE)

# # If you want to save residuals for all FX assets under fx_egarch_models
# dir.create("residuals", showWarnings = FALSE)
# 
# for (asset in names(fx_egarch_models)) {
#   res <- residuals(fx_egarch_models[[asset]], standardize = TRUE)
#   write.csv(as.numeric(res), file = paste0("residuals/", asset, "_resid.csv"), row.names = FALSE)
# }
# 



#### Save Results ####

# Create a new workbook
wb <- createWorkbook()

# Add each sheet
addWorksheet(wb, "Chrono_Split_Eval")
writeData(wb, "Chrono_Split_Eval", all_results)

addWorksheet(wb, "CV_Results")
writeData(wb, "CV_Results", cv_all_results)

addWorksheet(wb, "CV_Asset_Model_Summary")
writeData(wb, "CV_Asset_Model_Summary", cv_asset_model_summary)

addWorksheet(wb, "CV_Results_All")
writeData(wb, "CV_Results_All", cv_all_results)

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


saveWorkbook(wb, "GARCH_Model_Evaluation_Summary.xlsx", overwrite = TRUE)


