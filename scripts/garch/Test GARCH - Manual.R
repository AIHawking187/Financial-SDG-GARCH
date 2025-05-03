
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

#### Import the Equity data ####
TSLA <- quantmod::getSymbols("TSLA", from = "2000-01-04", to = "2024-08-30", auto.assign = FALSE)
AAPL <- quantmod::getSymbols("AAPL", from = "2000-01-04", to = "2024-08-30", auto.assign = FALSE)
NVDA <- quantmod::getSymbols("NVDA", from = "2000-01-04", to = "2024-08-30", auto.assign = FALSE)
JPM  <- quantmod::getSymbols("JPM",  from = "2000-01-04", to = "2024-08-30", auto.assign = FALSE)
JNJ  <- quantmod::getSymbols("JNJ",  from = "2000-01-04", to = "2024-08-30", auto.assign = FALSE)

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
ZAR_dates <- ZAR_data %>% 
  dplyr::select(Date)
USD_dates <- USD_data %>% 
  dplyr::select(date) 
  
USDZAR <- ZAR_data %>% dplyr::select(USDZAR)
GBPZAR <- ZAR_data %>% dplyr::select(GBPZAR)
EURZAR <- ZAR_data %>% dplyr::select(EURZAR)
AUDZAR <- ZAR_data %>% dplyr::select(AUDZAR)
CHYZAR <- ZAR_data %>% dplyr::select(CHYZAR)

USD_colnames <- names(USD_data)[-1]

#### Calculate Returns on Equity data ####
TSLA_return = (PerformanceAnalytics::CalculateReturns(TSLA$TSLA.Adjusted))
AAPL_return = (PerformanceAnalytics::CalculateReturns(AAPL$AAPL.Adjusted))
NVDA_return = (PerformanceAnalytics::CalculateReturns(NVDA$NVDA.Adjusted))
JPM_return = (PerformanceAnalytics::CalculateReturns(JPM$JPM.Adjusted))
JNJ_return = (PerformanceAnalytics::CalculateReturns(JNJ$JNJ.Adjusted))

TSLA_return = TSLA_return[-c(1),] #remove the first row as it doesn't contain a value
AAPL_return = AAPL_return[-c(1),]
NVDA_return = NVDA_return[-c(1),]
JPM_return = JPM_return[-c(1),]
JNJ_return = JNJ_return[-c(1),]

#### Calculate Returns on FX data ####

# Convert FX series to xts objects
USDZAR_xts <- xts(USDZAR, order.by = ZAR_data$Date)
GBPZAR_xts <- xts(GBPZAR, order.by = ZAR_data$Date)
EURZAR_xts <- xts(EURZAR, order.by = ZAR_data$Date)
AUDZAR_xts <- xts(AUDZAR, order.by = ZAR_data$Date)
CHYZAR_xts <- xts(CHYZAR, order.by = ZAR_data$Date)

# Calculate simple returns
USDZAR_returns_simple <- PerformanceAnalytics::CalculateReturns(USDZAR_xts)[-1, ]
GBPZAR_returns_simple <- PerformanceAnalytics::CalculateReturns(GBPZAR_xts)[-1, ]
EURZAR_returns_simple <- PerformanceAnalytics::CalculateReturns(EURZAR_xts)[-1, ]
AUDZAR_returns_simple <- PerformanceAnalytics::CalculateReturns(AUDZAR_xts)[-1, ]
CHYZAR_returns_simple <- PerformanceAnalytics::CalculateReturns(CHYZAR_xts)[-1, ]

# Calculate log returns (exclude first row which will be NA)
USDZAR_returns <- diff(log(USDZAR_xts))[-1, ]
GBPZAR_returns <- diff(log(GBPZAR_xts))[-1, ]
EURZAR_returns <- diff(log(EURZAR_xts))[-1, ]
AUDZAR_returns <- diff(log(AUDZAR_xts))[-1, ]
CHYZAR_returns <- diff(log(CHYZAR_xts))[-1, ]

#### Plot the Equity Data ####
#Plot the time series of the returns
chart_Series(TSLA_return)
chart_Series(AAPL_return)
chart_Series(NVDA_return)
chart_Series(JPM_return)
chart_Series(JNJ_return)

#Plot the histogram of the returns

chart.Histogram(TSLA_return,method = c('add.density', 'add.normal'), colorset = c('blue', 'red', 'black'))
chart.Histogram(AAPL_return,method = c('add.density', 'add.normal'), colorset = c('blue', 'red', 'black'))
chart.Histogram(NVDA_return,method = c('add.density', 'add.normal'), colorset = c('blue', 'red', 'black'))
chart.Histogram(JPM_return,method = c('add.density', 'add.normal'), colorset = c('blue', 'red', 'black'))
chart.Histogram(JNJ_return,method = c('add.density', 'add.normal'), colorset = c('blue', 'red', 'black'))

legend("topright", legend = c("return", "kernel", "normal dist"), fill = c('blue', 'red', 'black'))

#Calculate the annualized volatility and the rolling-window volatility of returns. 
#This can be done either at the daily, monthly, quarterly frequency, etc. 
#Here is the code for the monthly. width = 22 (252 for yearly frequency)

sqrt(252) * sd(TSLA_return["2020"])
sqrt(252) * sd(AAPL_return["2020"])
sqrt(252) * sd(NVDA_return["2020"])
sqrt(252) * sd(JPM_return["2020"])
sqrt(252) * sd(JNJ_return["2020"])

chart.RollingPerformance(R = TSLA_return["2010::2020"], width = 22, FUN = "sd.annualized", scale = 252, main = "Tesla, Inc.'s monthly volatility")
chart.RollingPerformance(R = AAPL_return["2010::2020"], width = 22, FUN = "sd.annualized", scale = 252, main = "Apple Inc.'s monthly volatility")
chart.RollingPerformance(R = NVDA_return["2010::2020"], width = 22, FUN = "sd.annualized", scale = 252, main = "NVIDIA Corporation's monthly volatility")
chart.RollingPerformance(R = JPM_return["2010::2020"], width = 22, FUN = "sd.annualized", scale = 252, main = "JPMorgan Chase & Co.'s monthly volatility")
chart.RollingPerformance(R = JNJ_return["2010::2020"], width = 22, FUN = "sd.annualized", scale = 252, main = "Johnson & Johnson's monthly volatility")

#### Plot the FX Data ####
#Plot the time series of the returns
plot(USDZAR_returns, which = 'all')
plot(GBPZAR_returns, which = 'all')
plot(EURZAR_returns, which = 'all')
plot(AUDZAR_returns, which = 'all')
plot(CHYZAR_returns, which = 'all')

#Plot the histogram of the returns

chart.Histogram(USDZAR_returns,method = c('add.density', 'add.normal'), colorset = c('blue', 'red', 'black'))
chart.Histogram(GBPZAR_returns,method = c('add.density', 'add.normal'), colorset = c('blue', 'red', 'black'))
chart.Histogram(EURZAR_returns,method = c('add.density', 'add.normal'), colorset = c('blue', 'red', 'black'))
chart.Histogram(AUDZAR_returns,method = c('add.density', 'add.normal'), colorset = c('blue', 'red', 'black'))
chart.Histogram(CHYZAR_returns,method = c('add.density', 'add.normal'), colorset = c('blue', 'red', 'black'))
legend("topright", legend = c("return", "kernel", "normal dist"), fill = c('blue', 'red', 'black'))


#Calculate the annualized volatility and the rolling-window volatility of returns. 
#This can be done either at the daily, monthly, quarterly frequency, etc. 
#Here is the code for the monthly. width = 22 (252 for yearly frequency)
sqrt(252) * sd(USDZAR_returns)
sqrt(252) * sd(GBPZAR_returns)
sqrt(252) * sd(EURZAR_returns)
sqrt(252) * sd(AUDZAR_returns)
sqrt(252) * sd(CHYZAR_returns)

chart.RollingPerformance(R = USDZAR_returns["2010::2020"], width = 22, FUN = "sd.annualized", scale = 252, main = "USDZAR's monthly volatility")
chart.RollingPerformance(R = GBPZAR_returns["2010::2020"], width = 22, FUN = "sd.annualized", scale = 252, main = "GBPZAR's monthly volatility")
chart.RollingPerformance(R = EURZAR_returns["2010::2020"], width = 22, FUN = "sd.annualized", scale = 252, main = "EURZAR's monthly volatility")
chart.RollingPerformance(R = AUDZAR_returns["2010::2020"], width = 22, FUN = "sd.annualized", scale = 252, main = "AUDZAR's monthly volatility")
chart.RollingPerformance(R = CHYZAR_returns["2010::2020"], width = 22, FUN = "sd.annualized", scale = 252, main = "CHYZAR's monthly volatility")

#### The Standard GARCH model ####
# Model Specification of a GARCH Constant model: meaning that the ARMA specification of the variance is (0,0)

#Equity data
TSLA_mod_specify_standard = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "norm")
AAPL_mod_specify_standard = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "norm")
NVDA_mod_specify_standard = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "norm")
JPM_mod_specify_standard = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "norm")
JNJ_mod_specify_standard = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "norm")

#FX data
USDZAR_mod_specify_standard = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "norm")
GBPZAR_mod_specify_standard = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "norm")
EURZAR_mod_specify_standard = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "norm")
AUDZAR_mod_specify_standard = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "norm")
CHYZAR_mod_specify_standard = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "norm")

# Model fitting code

#Equity data
TSLA_mod_fitting_standard = ugarchfit(data = TSLA_return, spec = TSLA_mod_specify_standard, out.sample = 40)
AAPL_mod_fitting_standard = ugarchfit(data = AAPL_return, spec = AAPL_mod_specify_standard, out.sample = 40)
NVDA_mod_fitting_standard = ugarchfit(data = NVDA_return, spec = NVDA_mod_specify_standard, out.sample = 40)
JPM_mod_fitting_standard = ugarchfit(data = JPM_return, spec = JPM_mod_specify_standard, out.sample = 40)
JNJ_mod_fitting_standard = ugarchfit(data = JNJ_return, spec = JNJ_mod_specify_standard, out.sample = 40)

#FX data
USDZAR_mod_fitting_standard = ugarchfit(data = USDZAR_returns, spec = USDZAR_mod_specify_standard, out.sample = 40)
GBPZAR_mod_fitting_standard = ugarchfit(data = GBPZAR_returns, spec = GBPZAR_mod_specify_standard, out.sample = 40)
EURZAR_mod_fitting_standard = ugarchfit(data = EURZAR_returns, spec = EURZAR_mod_specify_standard, out.sample = 40)
AUDZAR_mod_fitting_standard = ugarchfit(data = AUDZAR_returns, spec = AUDZAR_mod_specify_standard, out.sample = 40)
CHYZAR_mod_fitting_standard = ugarchfit(data = CHYZAR_returns, spec = CHYZAR_mod_specify_standard, out.sample = 40)

#### The GARCH model with Skewed student distribution ####
# Model Specification of a GARCH Constant model: meaning that the ARMA specification of the variance is (0,0)

#Equity data
TSLA_mod_specify_skewed = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
AAPL_mod_specify_skewed = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
NVDA_mod_specify_skewed = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
JPM_mod_specify_skewed = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
JNJ_mod_specify_skewed = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "sstd")

#FX data
USDZAR_mod_specify_skewed = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
GBPZAR_mod_specify_skewed = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
EURZAR_mod_specify_skewed = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
AUDZAR_mod_specify_skewed = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
CHYZAR_mod_specify_skewed = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "sGARCH", garchOrder = c(1,1)), distribution.model = "sstd")

# Model fitting code

#Equity data
TSLA_mod_fitting_skewed = ugarchfit(data = TSLA_return, spec = TSLA_mod_specify_skewed, out.sample = 40)
AAPL_mod_fitting_skewed = ugarchfit(data = AAPL_return, spec = AAPL_mod_specify_skewed, out.sample = 40)
NVDA_mod_fitting_skewed = ugarchfit(data = NVDA_return, spec = NVDA_mod_specify_skewed, out.sample = 40)
JPM_mod_fitting_skewed = ugarchfit(data = JPM_return, spec = JPM_mod_specify_skewed, out.sample = 40)
JNJ_mod_fitting_skewed = ugarchfit(data = JNJ_return, spec = JNJ_mod_specify_skewed, out.sample = 40)

#FX data
USDZAR_mod_fitting_skewed = ugarchfit(data = USDZAR_returns, spec = USDZAR_mod_specify_skewed, out.sample = 40)
GBPZAR_mod_fitting_skewed = ugarchfit(data = GBPZAR_returns, spec = GBPZAR_mod_specify_skewed, out.sample = 40)
EURZAR_mod_fitting_skewed = ugarchfit(data = EURZAR_returns, spec = EURZAR_mod_specify_skewed, out.sample = 40)
AUDZAR_mod_fitting_skewed = ugarchfit(data = AUDZAR_returns, spec = AUDZAR_mod_specify_skewed, out.sample = 40)
CHYZAR_mod_fitting_skewed = ugarchfit(data = CHYZAR_returns, spec = CHYZAR_mod_specify_skewed, out.sample = 40)


#### The GJR-GARCH model estimation ####
# Model Specification of a GARCH Constant model: meaning that the ARMA specification of the variance is (0,0)

#Equity data
TSLA_mod_specify_GJR_GARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "gjrGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
AAPL_mod_specify_GJR_GARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "gjrGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
NVDA_mod_specify_GJR_GARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "gjrGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
JPM_mod_specify_GJR_GARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "gjrGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
JNJ_mod_specify_GJR_GARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "gjrGARCH", garchOrder = c(1,1)), distribution.model = "sstd")

#FX data
USDZAR_mod_specify_GJR_GARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "gjrGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
GBPZAR_mod_specify_GJR_GARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "gjrGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
EURZAR_mod_specify_GJR_GARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "gjrGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
AUDZAR_mod_specify_GJR_GARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "gjrGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
CHYZAR_mod_specify_GJR_GARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "gjrGARCH", garchOrder = c(1,1)), distribution.model = "sstd")

# Model fitting code

#Equity data
TSLA_mod_fitting_GJR_GARCH = ugarchfit(data = TSLA_return, spec = TSLA_mod_specify_GJR_GARCH, out.sample = 40)
AAPL_mod_fitting_GJR_GARCH = ugarchfit(data = AAPL_return, spec = AAPL_mod_specify_GJR_GARCH, out.sample = 40)
NVDA_mod_fitting_GJR_GARCH = ugarchfit(data = NVDA_return, spec = NVDA_mod_specify_GJR_GARCH, out.sample = 40)
JPM_mod_fitting_GJR_GARCH = ugarchfit(data = JPM_return, spec = JPM_mod_specify_GJR_GARCH, out.sample = 40)
JNJ_mod_fitting_GJR_GARCH = ugarchfit(data = JNJ_return, spec = JNJ_mod_specify_GJR_GARCH, out.sample = 40)

#FX data
USDZAR_mod_fitting_GJR_GARCH = ugarchfit(data = USDZAR_returns, spec = USDZAR_mod_specify_GJR_GARCH, out.sample = 40)
GBPZAR_mod_fitting_GJR_GARCH = ugarchfit(data = GBPZAR_returns, spec = GBPZAR_mod_specify_GJR_GARCH, out.sample = 40)
EURZAR_mod_fitting_GJR_GARCH = ugarchfit(data = EURZAR_returns, spec = EURZAR_mod_specify_GJR_GARCH, out.sample = 40)
AUDZAR_mod_fitting_GJR_GARCH = ugarchfit(data = AUDZAR_returns, spec = AUDZAR_mod_specify_GJR_GARCH, out.sample = 40)
CHYZAR_mod_fitting_GJR_GARCH = ugarchfit(data = CHYZAR_returns, spec = CHYZAR_mod_specify_GJR_GARCH, out.sample = 40)


#Plot the different useful graph for the model estimation

plot(TSLA_mod_fitting, which = 'all')

#### The Exponential GARCH model with Skewed student distribution ####
# Model Specification of a GARCH Constant model: meaning that the ARMA specification of the variance is (0,0)
# Assumes returns are already stationary (common for daily returns).
# (1,1) captures volatility clustering well without overfitting.
# EGARCH Accounts for asymmetry/leverage effects in volatility (e.g., negative shocks impacting volatility more than positive).
# EGARCH handles log-volatility, avoiding non-negativity constraints.
# Skewed Student-t distribution: Accounts for heavy tails and skewness in returns

#Equity data
TSLA_mod_specify_EGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "eGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
AAPL_mod_specify_EGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "eGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
NVDA_mod_specify_EGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "eGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
JPM_mod_specify_EGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "eGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
JNJ_mod_specify_EGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "eGARCH", garchOrder = c(1,1)), distribution.model = "sstd")

#FX data
USDZAR_mod_specify_EGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "eGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
GBPZAR_mod_specify_EGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "eGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
EURZAR_mod_specify_EGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "eGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
AUDZAR_mod_specify_EGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "eGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
CHYZAR_mod_specify_EGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "eGARCH", garchOrder = c(1,1)), distribution.model = "sstd")

# Model fitting code

#Equity data
TSLA_mod_fitting_EGARCH = ugarchfit(data = TSLA_return, spec = TSLA_mod_specify_EGARCH, out.sample = 40)
AAPL_mod_fitting_EGARCH = ugarchfit(data = AAPL_return, spec = AAPL_mod_specify_EGARCH, out.sample = 40)
NVDA_mod_fitting_EGARCH = ugarchfit(data = NVDA_return, spec = NVDA_mod_specify_EGARCH, out.sample = 40)
JPM_mod_fitting_EGARCH = ugarchfit(data = JPM_return, spec = JPM_mod_specify_EGARCH, out.sample = 40)
JNJ_mod_fitting_EGARCH = ugarchfit(data = JNJ_return, spec = JNJ_mod_specify_EGARCH, out.sample = 40)

#FX data
USDZAR_mod_fitting_EGARCH = ugarchfit(data = USDZAR_returns, spec = USDZAR_mod_specify_EGARCH, out.sample = 40)
GBPZAR_mod_fitting_EGARCH = ugarchfit(data = GBPZAR_returns, spec = GBPZAR_mod_specify_EGARCH, out.sample = 40)
EURZAR_mod_fitting_EGARCH = ugarchfit(data = EURZAR_returns, spec = EURZAR_mod_specify_EGARCH, out.sample = 40)
AUDZAR_mod_fitting_EGARCH = ugarchfit(data = AUDZAR_returns, spec = AUDZAR_mod_specify_EGARCH, out.sample = 40)
CHYZAR_mod_fitting_EGARCH = ugarchfit(data = CHYZAR_returns, spec = CHYZAR_mod_specify_EGARCH, out.sample = 40)

#### The Threshold GARCH model with Skewed student distribution ####
# Model Specification of a GARCH Constant model: meaning that the ARMA specification of the variance is (0,0)
# Assumes returns are already stationary (common for daily returns).
# (1,1) captures volatility clustering well without over fitting.
# Also captures asymmetry (as in the EGARCH model), but in a threshold-based way — good for FX series often impacted by macroeconomic shocks.
# Skewed Student-t distribution: Accounts for heavy tails and skewness in returns

#Equity data
TSLA_mod_specify_TGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "fGARCH", submodel = "TGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
AAPL_mod_specify_TGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "fGARCH", submodel = "TGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
NVDA_mod_specify_TGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "fGARCH", submodel = "TGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
JPM_mod_specify_TGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "fGARCH", submodel = "TGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
JNJ_mod_specify_TGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "fGARCH", submodel = "TGARCH", garchOrder = c(1,1)), distribution.model = "sstd")

#FX data
USDZAR_mod_specify_TGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "fGARCH", submodel = "TGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
GBPZAR_mod_specify_TGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "fGARCH", submodel = "TGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
EURZAR_mod_specify_TGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "fGARCH", submodel = "TGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
AUDZAR_mod_specify_TGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "fGARCH", submodel = "TGARCH", garchOrder = c(1,1)), distribution.model = "sstd")
CHYZAR_mod_specify_TGARCH = ugarchspec(mean.model = list(armaOrder = c(0,0)), variance.model = list(model = "fGARCH", submodel = "TGARCH", garchOrder = c(1,1)), distribution.model = "sstd")

# Model fitting code

#Equity data
TSLA_mod_fitting_TGARCH = ugarchfit(data = TSLA_return, spec = TSLA_mod_specify_TGARCH, out.sample = 40)
AAPL_mod_fitting_TGARCH = ugarchfit(data = AAPL_return, spec = AAPL_mod_specify_TGARCH, out.sample = 40)
NVDA_mod_fitting_TGARCH = ugarchfit(data = NVDA_return, spec = NVDA_mod_specify_TGARCH, out.sample = 40)
JPM_mod_fitting_TGARCH = ugarchfit(data = JPM_return, spec = JPM_mod_specify_TGARCH, out.sample = 40)
JNJ_mod_fitting_TGARCH = ugarchfit(data = JNJ_return, spec = JNJ_mod_specify_TGARCH, out.sample = 40)

#FX data
USDZAR_mod_fitting_TGARCH = ugarchfit(data = USDZAR_returns, spec = USDZAR_mod_specify_TGARCH, out.sample = 40)
GBPZAR_mod_fitting_TGARCH = ugarchfit(data = GBPZAR_returns, spec = GBPZAR_mod_specify_TGARCH, out.sample = 40)
EURZAR_mod_fitting_TGARCH = ugarchfit(data = EURZAR_returns, spec = EURZAR_mod_specify_TGARCH, out.sample = 40)
AUDZAR_mod_fitting_TGARCH = ugarchfit(data = AUDZAR_returns, spec = AUDZAR_mod_specify_TGARCH, out.sample = 40)
CHYZAR_mod_fitting_TGARCH = ugarchfit(data = CHYZAR_returns, spec = CHYZAR_mod_specify_TGARCH, out.sample = 40)

#### Forecast ####

TSLA_forc =  ugarchforecast(fitORspec = TSLA_mod_fitting, n.ahead = 40)

plot(fitted(TSLA_forc))

plot(sigma(TSLA_forc))
