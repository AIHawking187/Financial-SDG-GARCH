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
# install.packages("ggplot2")

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
library(ggplot2)

#### Import the Equity data ####

# Main Tickers
  equity_tickers <- c("NVDA", "MSFT", "PG", "CAT", "WMT", "AMZN")
  fx_names <- c("EURUSD", "GBPUSD", "GBPCNY","USDZAR", "GBPZAR", "EURZAR")
  
# Pull the Equity data
  equity_data <- lapply(equity_tickers, function(ticker) 
      {
      quantmod::getSymbols(ticker, from = "2005-08-30", to = "2024-08-30", auto.assign = FALSE)[, 6]
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
  avg_volumes <- sapply(equity_data_check, function(x) mean(Vo(x), na.rm = TRUE)) %>% 
    as.numeric()
  sort(avg_volumes, decreasing = TRUE)


#### Import the FX data ####

FX_data <- read.csv(file = "./data/raw/fx_equity_prices.csv") %>% 
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


#### Consolidate and Export FX and EQ data into one CSV ####

# Step 1: Gather all dates
all_series <- c(equity_data, fx_data)
all_dates <- as.Date(Reduce(union, lapply(all_series, index)))

# Step 2: Reindex and rename equity data
equity_data_full <- lapply(seq_along(equity_data), function(i) {
  x <- equity_data[[i]]
  reindexed <- merge(xts(, all_dates), x)
  colnames(reindexed) <- equity_tickers[i]   # Assign ticker name directly
  reindexed
})

# Step 3: Reindex and rename FX data
fx_data_full <- lapply(seq_along(fx_data), function(i) {
  x <- fx_data[[i]]
  reindexed <- merge(xts(, all_dates), x)
  colnames(reindexed) <- fx_names[i]        # Assign FX pair name directly
  reindexed
})

# Step 4: Merge all series
combined_df <- do.call(merge, c(equity_data_full, fx_data_full))
combined_df <- na.omit(combined_df)

# Step 5: Split back 
equity_data_clean <- as.list(combined_df[, equity_tickers])
fx_data_clean     <- as.list(combined_df[, fx_names])


# Step 56: Export to Processed folder
write.csv(as.data.frame(combined_df), "./data/processed/raw (FX + EQ).csv")


