
#### Install Packages ####

# Remove Comments if installing packages for the first time

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
# install.packages("moments")
# devtools::install_github("tidyverse/tidyr")

# Libraries
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
library(FinTS)
library(moments)

#### Import the Equity data ####

equity_tickers <- c("NVDA", "AAPL", "AMZN", "DJT", "PDCO", "MLGO")
fx_names <- c("USDZAR", "GBPZAR", "EURZAR", "GBPCNY", "EURUSD", "GBPUSD")

equity_data <- lapply(equity_tickers, function(ticker) 
  {
  quantmod::getSymbols(ticker, from = "2000-01-04", to = "2024-08-30", auto.assign = FALSE)[, 6]
  })

names(equity_data) <- equity_tickers

#### Import FX data ####

FX_data <- read.csv(file = "./data/raw/fx_equity_prices.csv") %>% 
  dplyr::mutate(
    Date = stringr::str_replace_all(Date, "-", ""),  # Remove dashes from dates
    Date = lubridate::ymd(Date)  # Convert strings to Date objects
                ) 

# Ensure that the results folders are created before any plots or results are saved 
if (!dir.exists("results/tables")) dir.create("results/tables", recursive = TRUE)
if (!dir.exists("results/plots")) dir.create("results/plots", recursive = TRUE)


#### Clean FX_data ####
fx_data <- lapply(fx_names, function(name) 
  {
  xts(FX_data[[name]], order.by = FX_data$Date)
  })

names(fx_data) <- fx_names

# Confirm the number of datapoints for the Equity and FX data
sapply(equity_data, nrow)
sapply(fx_data, nrow)

#### Calculate Returns on Equity data ####
equity_returns <- lapply(equity_data, function(x) CalculateReturns(x)[-1, ])

#### Calculate Returns on FX data ####

# Convert FX series to xts objects
fx_returns <- lapply(fx_data, function(x) diff(log(x))[-1, ])

#### Plotting Helpers ####
plot_returns <- function(returns_list, title_prefix = "") {
  folder_path <- paste0("results/plots/", title_prefix)
  if (!dir.exists(folder_path)) dir.create(folder_path, recursive = TRUE)
  
  for (name in names(returns_list)) {
    file_name <- paste0(folder_path, "/", name, "_hist.png")
    png(file_name)
    chart.Histogram(returns_list[[name]],
                    method = c("add.density", "add.normal"),
                    main = paste0(title_prefix, name),
                    colorset = c("blue", "red", "black"))
    dev.off()
  }
}

plot_volatility_forecasts <- function(forecast_list, title_prefix = "") {
  folder_path <- paste0("results/plots/", title_prefix)
  if (!dir.exists(folder_path)) dir.create(folder_path, recursive = TRUE)
  
  for (name in names(forecast_list)) {
    file_name <- paste0(folder_path, "/", name, "_volatility.png")
    png(file_name)
    sigma_vals <- sigma(forecast_list[[name]])
    plot(sigma_vals, main = paste0(title_prefix, name), col = "blue", ylab = "Volatility")
    dev.off()
  }
}

plot_returns(equity_returns)
plot_returns(fx_returns)


#### Model Generator ####

generate_spec <- function(model, dist = "sstd", submodel = NULL) 
  {
  ugarchspec(
    mean.model = list(armaOrder = c(0,0)),
    variance.model = list(model = model, garchOrder = c(1,1), submodel = submodel),
    distribution.model = dist
            )
  }

#### Automate Fitting for Any Set of Returns #### 
fit_models <- function(returns_list, model_type, dist_type = "sstd", submodel = NULL) 
  {
  specs <- lapply(returns_list, function(x) generate_spec(model_type, dist_type, submodel))
  fits <- mapply(function(ret, spec) ugarchfit(data = ret, spec = spec, out.sample = 20),
                 returns_list, specs, SIMPLIFY = FALSE)
  return(fits)
  }

#### Fit Models ####
model_configs <- list(
                      sGARCH_norm  = list(model = "sGARCH", dist = "norm", submodel = NULL),
                      sGARCH_sstd  = list(model = "sGARCH", dist = "sstd", submodel = NULL),
                      gjrGARCH     = list(model = "gjrGARCH", dist = "sstd", submodel = NULL),
                      eGARCH       = list(model = "eGARCH", dist = "sstd", submodel = NULL),
                      TGARCH       = list(model = "fGARCH", dist = "sstd", submodel = "TGARCH")
                      )

all_model_fits <- list()

for (config_name in names(model_configs)) 
  {
  cfg <- model_configs[[config_name]]
  
  equity_fit <- fit_models(equity_returns, model_type = cfg$model, dist_type = cfg$dist, submodel = cfg$submodel)
  fx_fit     <- fit_models(fx_returns, model_type = cfg$model, dist_type = cfg$dist, submodel = cfg$submodel)
  
  all_model_fits[[paste0("equity_", config_name)]] <- equity_fit
  all_model_fits[[paste0("fx_", config_name)]]     <- fx_fit
  }


#### Forecast Financial Data ####
forecast_models <- function(fit_list, n.ahead = 40) {
  lapply(fit_list, function(fit) ugarchforecast(fitORspec = fit, n.ahead = n.ahead))
}

all_forecasts <- lapply(all_model_fits, forecast_models, n.ahead = 40)

for (key in names(all_forecasts)) {
  plot_volatility_forecasts(all_forecasts[[key]], title_prefix = key)
}

# Save forecasted Financial data (if ever required)

for (model_key in names(all_forecasts)) {
  forecast_list <- all_forecasts[[model_key]]
  asset_type <- ifelse(startsWith(model_key, "equity"), "equity", "fx")
  model_name <- gsub("^(equity|fx)_", "", model_key)
  
  for (asset in names(forecast_list)) {
    forecasted_returns <- as.numeric(fitted(forecast_list[[asset]]))
    forecast_df <- data.frame(ForecastedReturns = forecasted_returns)
    
    write.csv(forecast_df,
              file = paste0("results/tables/forecasts/", asset_type, "_", model_name, "_", asset, "_forecast.csv"),
              row.names = FALSE)
  }
}

#### Evaluation of Forecasted Financial Data ####

# Helpers
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

all_results <- data.frame()

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

# Rank results of forecasted financial data
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

# Plot results of forecasted financial data
plot_volatility_forecasts <- function(forecast_list, title_prefix = "") {
  par(mfrow = c(2, 3))
  for (name in names(forecast_list)) {
    sigma_vals <- sigma(forecast_list[[name]])
    plot(sigma_vals, main = paste0(title_prefix, name), col = "blue", ylab = "Volatility")
  }
}

for (key in names(all_forecasts)) {
  forecast_list <- all_forecasts[[key]]
  plot_volatility_forecasts(forecast_list, title_prefix = paste0(key, " - "))
}

#### Generate Synthetic Financial Data ####
# Helper
simulate_from_garch <- function(fit, n.sim = 1000, m.sim = 1) {
  sim <- ugarchsim(fit, n.sim = n.sim, m.sim = m.sim)
  return(fitted(sim)[,1])
}

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

simulation_results <- data.frame()

for (model_key in names(all_model_fits)) {
  model_list <- all_model_fits[[model_key]]
  asset_type <- ifelse(startsWith(model_key, "equity"), "equity", "fx")
  model_name <- gsub("^(equity|fx)_", "", model_key)
  return_list <- if (asset_type == "equity") equity_returns else fx_returns
  
  for (asset in names(model_list)) {
    fit <- model_list[[asset]]
    real <- as.numeric(return_list[[asset]])
    sim <- simulate_from_garch(fit, n.sim = length(real))  # match length
    
    # Save simulated series
    write.csv(data.frame(SimulatedReturns = sim),
              file = paste0("results/tables/synthetic/", asset_type, "_", model_name, "_", asset, "_sim.csv"),
              row.names = FALSE)
    
    # Evaluate and collect metrics
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


#### Save Results ####
# Save evaluation summary of forecasted financial data 
write.csv(all_results, "results/tables/garch_comparison.csv", row.names = FALSE)

# Save Model ranking from evaluation of forecasted financial data
write.csv(model_ranking, "results/tables/garch_model_ranking.csv", row.names = FALSE)

# Save evaluation summary of synthetic financial data 
write.csv(simulation_results, "results/tables/simulation_evaluation.csv", row.names = FALSE)

# Save Model ranking from evaluation of synthetic financial data
write.csv(simulation_ranking, "results/tables/simulation_model_ranking.csv", row.names = FALSE)


