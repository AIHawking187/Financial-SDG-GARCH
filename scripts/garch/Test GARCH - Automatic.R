
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
library(FinTS)  # For ArchTest

#### Import the data ####

equity_tickers <- c("TSLA", "AAPL", "NVDA", "JPM", "JNJ")
fx_names <- c("USDZAR", "GBPZAR", "EURZAR", "AUDZAR", "CHYZAR")


equity_data <- lapply(equity_tickers, function(ticker) 
  {
  quantmod::getSymbols(ticker, from = "2000-01-04", to = "2024-08-30", auto.assign = FALSE)[, 6]
  })

names(equity_data) <- equity_tickers

#### Import ZAR_data and USD_data ####
ZAR_data <- read.csv(file = "../input/raw.csv") %>% 
  dplyr::mutate(
    Date = stringr::str_replace_all(Date, "-", ""),  # Remove dashes from dates
    Date = lubridate::ymd(Date)  # Convert strings to Date objects
                ) 

USD_data <- read.csv(file = "../input/exchange_rate_to_usd.csv") %>% 
  dplyr::mutate(
    date = stringr::str_replace_all(date, "-", ""),  # Remove dashes from dates
    date = lubridate::ymd(date)  # Convert strings to Date objects
                ) %>% 
                dplyr::filter(date <= lubridate::ymd("2024-08-30") & date >= lubridate::ymd("2000-01-04"))


#### Clean ZAR_data and USD_data####
fx_data <- lapply(fx_names, function(name) 
  {
  xts(ZAR_data[[name]], order.by = ZAR_data$Date)
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

equity_gjr_models <- fit_models(equity_returns, "gjrGARCH", "sstd")
fx_egarch_models   <- fit_models(fx_returns, "eGARCH", "sstd")

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



#### Forecast Helper ####
forecast_models <- function(fit_list, n.ahead = 40) {
  lapply(fit_list, function(fit) ugarchforecast(fitORspec = fit, n.ahead = n.ahead))
}

equity_gjr_forecasts <- forecast_models(equity_gjr_models, n.ahead = 40)
fx_egarch_forecasts  <- forecast_models(fx_egarch_models, n.ahead = 40)

all_forecasts <- lapply(all_model_fits, forecast_models, n.ahead = 40)

#### Evaluation ####

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

results_equity_gjr <- compare_models(equity_gjr_models, equity_gjr_forecasts, equity_returns, "GJR-GARCH_sstd")
results_fx_egarch  <- compare_models(fx_egarch_models, fx_egarch_forecasts, fx_returns, "eGARCH_sstd")

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


plot_volatility_forecasts <- function(forecast_list, title_prefix = "") {
  par(mfrow = c(2, 3))
  for (name in names(forecast_list)) {
    sigma_vals <- sigma(forecast_list[[name]])
    plot(sigma_vals, main = paste0(title_prefix, name), col = "blue", ylab = "Volatility")
  }
}

plot_volatility_forecasts(equity_gjr_forecasts, title_prefix = "GJR-GARCH - ")
plot_volatility_forecasts(fx_egarch_forecasts, title_prefix = "eGARCH - ")


write.csv(all_results, "garch_comparison.csv", row.names = FALSE)

