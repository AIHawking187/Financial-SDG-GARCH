#!/usr/bin/env Rscript
# EDA Summary Statistics Script
# Performs exploratory data analysis on the financial data

library(dplyr)
library(ggplot2)
library(readr)
library(tidyr)
library(scales)
library(viridis)

# Source utilities
source("scripts/utils/conflict_resolution.R")
source("scripts/utils/enhanced_plotting.R")

# Initialize pipeline
initialize_pipeline()

cat("=== RUNNING EXPLORATORY DATA ANALYSIS ===\n")

# Load data
cat("Loading data...\n")
data_file <- "data/processed/raw (FX + EQ).csv"

if (!file.exists(data_file)) {
  stop("Data file not found: ", data_file)
}

data <- read.csv(data_file, row.names = 1)
data$Date <- as.Date(rownames(data))

cat("Data loaded successfully\n")
cat("  Rows:", nrow(data), "\n")
cat("  Columns:", ncol(data), "\n")

# Separate FX and Equity data
fx_cols <- c("EURUSD", "GBPUSD", "GBPCNY", "USDZAR", "GBPZAR", "EURZAR")
equity_cols <- c("NVDA", "MSFT", "PG", "CAT", "WMT", "AMZN")

fx_data <- data[, fx_cols, drop = FALSE]
equity_data <- data[, equity_cols, drop = FALSE]

# Calculate returns
fx_returns <- fx_data %>%
  mutate_all(~c(NA, diff(log(.)))) %>%
  filter(!is.na(.[,1]))

equity_returns <- equity_data %>%
  mutate_all(~c(NA, diff(log(.)))) %>%
  filter(!is.na(.[,1]))

# Create output directories
dir.create("outputs/eda/figures", showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/eda/tables", showWarnings = FALSE, recursive = TRUE)

# Generate summary statistics
cat("Generating summary statistics...\n")

# FX Summary
fx_summary <- fx_returns %>%
  summarise_all(list(
    mean = ~mean(., na.rm = TRUE),
    sd = ~sd(., na.rm = TRUE),
    min = ~min(., na.rm = TRUE),
    max = ~max(., na.rm = TRUE),
    skewness = ~skewness(., na.rm = TRUE),
    kurtosis = ~kurtosis(., na.rm = TRUE)
  )) %>%
  gather(key = "stat", value = "value") %>%
  separate(stat, into = c("asset", "statistic"), sep = "_") %>%
  spread(statistic, value)

# Equity Summary
equity_summary <- equity_returns %>%
  summarise_all(list(
    mean = ~mean(., na.rm = TRUE),
    sd = ~sd(., na.rm = TRUE),
    min = ~min(., na.rm = TRUE),
    max = ~max(., na.rm = TRUE),
    skewness = ~skewness(., na.rm = TRUE),
    kurtosis = ~kurtosis(., na.rm = TRUE)
  )) %>%
  gather(key = "stat", value = "value") %>%
  separate(stat, into = c("asset", "statistic"), sep = "_") %>%
  spread(statistic, value)

# Save summary tables
write.csv(fx_summary, "outputs/eda/tables/fx_summary_stats.csv", row.names = FALSE)
write.csv(equity_summary, "outputs/eda/tables/equity_summary_stats.csv", row.names = FALSE)

# Generate histograms
cat("Generating histograms...\n")

# FX Histograms
for (asset in fx_cols) {
  p <- create_enhanced_histogram(
    fx_returns[[asset]], 
    title = paste("Return Distribution -", asset),
    xlab = "Returns",
    ylab = "Density"
  )
  ggsave(paste0("outputs/eda/figures/", asset, "_histogram.png"), p, width = 10, height = 6, dpi = 300)
}

# Equity Histograms
for (asset in equity_cols) {
  p <- create_enhanced_histogram(
    equity_returns[[asset]], 
    title = paste("Return Distribution -", asset),
    xlab = "Returns",
    ylab = "Density"
  )
  ggsave(paste0("outputs/eda/figures/", asset, "_histogram.png"), p, width = 10, height = 6, dpi = 300)
}

# Generate time series plots
cat("Generating time series plots...\n")

# FX Time Series
fx_returns_long <- fx_returns %>%
  mutate(Date = data$Date[-1]) %>%
  gather(key = "Asset", value = "Returns", -Date)

p <- create_enhanced_time_series(
  fx_returns_long,
  x_var = "Date",
  y_var = "Returns",
  group_var = "Asset",
  title = "FX Returns Time Series",
  xlab = "Date",
  ylab = "Returns"
)
ggsave("outputs/eda/figures/fx_returns_timeseries.png", p, width = 12, height = 8, dpi = 300)

# Equity Time Series
equity_returns_long <- equity_returns %>%
  mutate(Date = data$Date[-1]) %>%
  gather(key = "Asset", value = "Returns", -Date)

p <- create_enhanced_time_series(
  equity_returns_long,
  x_var = "Date",
  y_var = "Returns",
  group_var = "Asset",
  title = "Equity Returns Time Series",
  xlab = "Date",
  ylab = "Returns"
)
ggsave("outputs/eda/figures/equity_returns_timeseries.png", p, width = 12, height = 8, dpi = 300)

# Generate correlation heatmaps
cat("Generating correlation heatmaps...\n")

# FX Correlation
fx_corr <- cor(fx_returns, use = "complete.obs")
p <- create_enhanced_correlation_heatmap(
  fx_corr,
  title = "FX Returns Correlation Matrix"
)
ggsave("outputs/eda/figures/fx_correlation_heatmap.png", p, width = 10, height = 8, dpi = 300)

# Equity Correlation
equity_corr <- cor(equity_returns, use = "complete.obs")
p <- create_enhanced_correlation_heatmap(
  equity_corr,
  title = "Equity Returns Correlation Matrix"
)
ggsave("outputs/eda/figures/equity_correlation_heatmap.png", p, width = 10, height = 8, dpi = 300)

# Generate volatility clustering plots
cat("Generating volatility clustering plots...\n")

# FX Volatility Clustering
fx_vol <- fx_returns %>%
  mutate_all(~abs(.)) %>%
  mutate(Date = data$Date[-1]) %>%
  gather(key = "Asset", value = "Absolute_Returns", -Date)

p <- create_enhanced_time_series(
  fx_vol,
  x_var = "Date",
  y_var = "Absolute_Returns",
  group_var = "Asset",
  title = "FX Volatility Clustering",
  xlab = "Date",
  ylab = "Absolute Returns"
)
ggsave("outputs/eda/figures/fx_volatility_clustering.png", p, width = 12, height = 8, dpi = 300)

# Equity Volatility Clustering
equity_vol <- equity_returns %>%
  mutate_all(~abs(.)) %>%
  mutate(Date = data$Date[-1]) %>%
  gather(key = "Asset", value = "Absolute_Returns", -Date)

p <- create_enhanced_time_series(
  equity_vol,
  x_var = "Date",
  y_var = "Absolute_Returns",
  group_var = "Asset",
  title = "Equity Volatility Clustering",
  xlab = "Date",
  ylab = "Absolute Returns"
)
ggsave("outputs/eda/figures/equity_volatility_clustering.png", p, width = 12, height = 8, dpi = 300)

# Generate comparative analysis
cat("Generating comparative analysis...\n")

# Combine summary statistics
all_summary <- bind_rows(
  fx_summary %>% mutate(Asset_Type = "FX"),
  equity_summary %>% mutate(Asset_Type = "Equity")
)

# Comparative boxplots
all_returns_long <- bind_rows(
  fx_returns_long %>% mutate(Asset_Type = "FX"),
  equity_returns_long %>% mutate(Asset_Type = "Equity")
)

p <- create_enhanced_boxplot(
  all_returns_long,
  x_var = "Asset_Type",
  y_var = "Returns",
  fill_var = "Asset_Type",
  title = "Return Distribution Comparison: FX vs Equity",
  xlab = "Asset Type",
  ylab = "Returns"
)
ggsave("outputs/eda/figures/fx_vs_equity_comparison.png", p, width = 10, height = 6, dpi = 300)

# Save comprehensive summary
write.csv(all_summary, "outputs/eda/tables/comprehensive_summary_stats.csv", row.names = FALSE)

cat("=== EDA ANALYSIS COMPLETE ===\n")
cat("Generated files:\n")
cat("  Tables: outputs/eda/tables/\n")
cat("  Figures: outputs/eda/figures/\n")
cat("  Total files:", length(list.files("outputs/eda", recursive = TRUE)), "\n")
