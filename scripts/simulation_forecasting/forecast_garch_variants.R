# GARCH Variants Forecasting and Evaluation Script
# This script performs out-of-sample forecasting for different GARCH models
# and evaluates their forecasting performance

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
library(ggplot2)
library(forecast)

cat("Starting GARCH Variants Forecasting Analysis...\n")

#### Import and Prepare Data ####

# Read price data
raw_price_data <- read.csv("./data/processed/raw (FX + EQ).csv", row.names = 1)
raw_price_data$Date <- lubridate::ymd(rownames(raw_price_data))
rownames(raw_price_data) <- NULL
raw_price_data <- raw_price_data %>% dplyr::select(Date, everything())

# Extract date vector and price matrix
date_index <- raw_price_data$Date
price_data_matrix <- raw_price_data[, !(names(raw_price_data) %in% "Date")]

# Define asset tickers
equity_tickers <- c("NVDA", "MSFT", "PG", "CAT", "WMT", "AMZN")
fx_names <- c("EURUSD", "GBPUSD", "GBPCNY", "USDZAR", "GBPZAR", "EURZAR")

# Create XTS objects
equity_xts <- lapply(equity_tickers, function(ticker) {
  xts(price_data_matrix[[ticker]], order.by = date_index)
})
names(equity_xts) <- equity_tickers

fx_xts <- lapply(fx_names, function(ticker) {
  xts(price_data_matrix[[ticker]], order.by = date_index)
})
names(fx_xts) <- fx_names

# Calculate returns
equity_returns <- lapply(equity_xts, function(x) CalculateReturns(x)[-1, ])
fx_returns <- lapply(fx_xts, function(x) diff(log(x))[-1, ])

#### Model Specifications ####

generate_spec <- function(model, dist = "sstd", submodel = NULL) {
  ugarchspec(
    mean.model = list(armaOrder = c(0,0)),
    variance.model = list(model = model, garchOrder = c(1,1), submodel = submodel),
    distribution.model = dist
  )
}

# Define models to test
models <- list(
  sGARCH_norm = list(model = "sGARCH", dist = "norm"),
  sGARCH_sstd = list(model = "sGARCH", dist = "sstd"),
  eGARCH = list(model = "eGARCH", dist = "sstd"),
  gjrGARCH = list(model = "gjrGARCH", dist = "sstd"),
  TGARCH = list(model = "fGARCH", dist = "sstd", submodel = "TGARCH")
)

#### Forecasting Function ####

perform_forecasting <- function(returns_data, asset_name, asset_type) {
  cat("Processing", asset_name, "(", asset_type, ")\n")
  
  # Remove any NA values
  clean_returns <- na.omit(returns_data)
  
  # Split data: 80% for training, 20% for testing
  n <- length(clean_returns)
  train_size <- floor(0.8 * n)
  train_data <- clean_returns[1:train_size]
  test_data <- clean_returns[(train_size + 1):n]
  
  forecast_results <- list()
  
  for (model_name in names(models)) {
    tryCatch({
      cat("  Fitting", model_name, "...\n")
      
      # Generate specification
      spec <- do.call(generate_spec, models[[model_name]])
      
      # Fit model
      fit <- ugarchfit(spec, data = train_data, solver = "hybrid")
      
      # Perform rolling forecast
      n_ahead <- 1
      n_roll <- length(test_data)
      
      # Try simple forecast first (more reliable)
      tryCatch({
        roll_forecast <- ugarchforecast(fit, n.ahead = length(test_data))
      }, error = function(e) {
        # Fallback: use fitted volatility as forecast
        cat("  Warning: Forecast failed, using fitted volatility\n")
        roll_forecast <- list(
          forecast = list(
            sigmaFor = matrix(sigma(fit)[length(sigma(fit))], nrow = length(test_data), ncol = 1)
          )
        )
      })
      
      # Extract forecasted volatility
      forecasted_vol <- as.numeric(roll_forecast@forecast$sigmaFor)
      actual_vol <- abs(test_data)
      
      # Calculate forecast accuracy metrics
      mse <- mean((forecasted_vol - actual_vol)^2)
      mae <- mean(abs(forecasted_vol - actual_vol))
      mape <- mean(abs((forecasted_vol - actual_vol) / actual_vol)) * 100
      
      # Store results
      forecast_results[[model_name]] <- list(
        forecasted_vol = forecasted_vol,
        actual_vol = actual_vol,
        mse = mse,
        mae = mae,
        mape = mape,
        model_fit = fit
      )
      
    }, error = function(e) {
      cat("  Error fitting", model_name, ":", e$message, "\n")
      forecast_results[[model_name]] <<- NULL
    })
  }
  
  return(forecast_results)
}

#### Perform Forecasting Analysis ####

# Create output directories
output_dir <- "outputs/model_eval/figures"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Process equity assets
equity_forecasts <- list()
for (ticker in names(equity_returns)) {
  equity_forecasts[[ticker]] <- perform_forecasting(equity_returns[[ticker]], ticker, "Equity")
}

# Process FX assets
fx_forecasts <- list()
for (fx in names(fx_returns)) {
  fx_forecasts[[fx]] <- perform_forecasting(fx_returns[[fx]], fx, "FX")
}

#### Create Forecast Comparison Plots ####

plot_forecast_comparison <- function(forecast_results, asset_name, asset_type) {
  if (length(forecast_results) == 0) return()
  
  # Prepare data for plotting
  plot_data <- data.frame()
  
  for (model_name in names(forecast_results)) {
    if (!is.null(forecast_results[[model_name]])) {
      temp_data <- data.frame(
        Date = 1:length(forecast_results[[model_name]]$forecasted_vol),
        Forecasted = forecast_results[[model_name]]$forecasted_vol,
        Actual = forecast_results[[model_name]]$actual_vol,
        Model = model_name
      )
      plot_data <- rbind(plot_data, temp_data)
    }
  }
  
  if (nrow(plot_data) == 0) return()
  
  # Create plot
  p <- ggplot(plot_data, aes(x = Date)) +
    geom_line(aes(y = Actual, color = "Actual"), size = 0.8) +
    geom_line(aes(y = Forecasted, color = Model), alpha = 0.7) +
    labs(title = paste(asset_name, "(", asset_type, ") - Volatility Forecasts"),
         x = "Time", y = "Volatility", color = "Series") +
    theme_minimal() +
    theme(legend.position = "bottom")
  
  # Save plot
  filename <- paste0(output_dir, "/", asset_name, "_forecast_comparison.png")
  ggsave(filename, p, width = 10, height = 6, dpi = 300)
  
  cat("Saved forecast plot:", filename, "\n")
}

# Generate plots for all assets
for (ticker in names(equity_forecasts)) {
  plot_forecast_comparison(equity_forecasts[[ticker]], ticker, "Equity")
}

for (fx in names(fx_forecasts)) {
  plot_forecast_comparison(fx_forecasts[[fx]], fx, "FX")
}

#### Calculate Summary Statistics ####

calculate_summary_stats <- function(forecast_results, asset_name) {
  summary_data <- data.frame()
  
  for (model_name in names(forecast_results)) {
    if (!is.null(forecast_results[[model_name]])) {
      summary_data <- rbind(summary_data, data.frame(
        Asset = asset_name,
        Model = model_name,
        MSE = forecast_results[[model_name]]$mse,
        MAE = forecast_results[[model_name]]$mae,
        MAPE = forecast_results[[model_name]]$mape
      ))
    }
  }
  
  return(summary_data)
}

# Combine all summary statistics
all_summary <- data.frame()

for (ticker in names(equity_forecasts)) {
  all_summary <- rbind(all_summary, calculate_summary_stats(equity_forecasts[[ticker]], ticker))
}

for (fx in names(fx_forecasts)) {
  all_summary <- rbind(all_summary, calculate_summary_stats(fx_forecasts[[fx]], fx))
}

# Save summary statistics
output_table_dir <- "outputs/model_eval/tables"
dir.create(output_table_dir, recursive = TRUE, showWarnings = FALSE)

write.csv(all_summary, paste0(output_table_dir, "/forecast_accuracy_summary.csv"), row.names = FALSE)

#### Model Ranking Analysis ####

# Calculate average performance across all assets
model_ranking <- all_summary %>%
  group_by(Model) %>%
  summarise(
    Avg_MSE = mean(MSE, na.rm = TRUE),
    Avg_MAE = mean(MAE, na.rm = TRUE),
    Avg_MAPE = mean(MAPE, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(Avg_MSE)

# Save model ranking
write.csv(model_ranking, paste0(output_table_dir, "/model_ranking.csv"), row.names = FALSE)

#### Asset-Specific Analysis ####

# Calculate best model per asset
best_models_per_asset <- all_summary %>%
  group_by(Asset) %>%
  slice_min(order_by = MSE, n = 1) %>%
  select(Asset, Best_Model = Model, Best_MSE = MSE)

write.csv(best_models_per_asset, paste0(output_table_dir, "/best_models_per_asset.csv"), row.names = FALSE)

#### Print Summary ####

cat("\n=== FORECASTING ANALYSIS SUMMARY ===\n")
cat("Total assets processed:", length(equity_forecasts) + length(fx_forecasts), "\n")
cat("Models tested:", length(models), "\n")
cat("Output files saved to:", output_dir, "\n")
cat("Summary tables saved to:", output_table_dir, "\n")

cat("\n=== MODEL RANKING (by Average MSE) ===\n")
print(model_ranking)

cat("\n=== BEST MODEL PER ASSET ===\n")
print(best_models_per_asset)

cat("\nForecasting analysis complete!\n")

