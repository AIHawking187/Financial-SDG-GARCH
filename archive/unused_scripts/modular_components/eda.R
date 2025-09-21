#!/usr/bin/env Rscript
# EDA Component for Modular Pipeline
# Matches the main pipeline's EDA functionality with enhanced plot quality

library(openxlsx)
library(dplyr)
library(tidyr)
library(stringr)
library(readxl)
library(ggplot2)
library(scales)
library(viridis)

# Set deterministic seeds
set.seed(123)

# Enhanced theme for professional plots
professional_theme <- function() {
  theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, size = 14, face = "bold", margin = margin(b = 20)),
      plot.subtitle = element_text(hjust = 0.5, size = 12, color = "gray40", margin = margin(b = 15)),
      axis.title = element_text(size = 12, face = "bold"),
      axis.text = element_text(size = 10),
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.title = element_text(size = 11, face = "bold"),
      legend.text = element_text(size = 10),
      legend.position = "bottom",
      panel.grid.major = element_line(color = "gray90"),
      panel.grid.minor = element_line(color = "gray95"),
      plot.margin = margin(20, 20, 20, 20),
      strip.text = element_text(size = 11, face = "bold")
    )
}

# Load data
cat("Loading data for EDA...\n")
data_file <- "data/processed/raw (FX + EQ).csv"

if (!file.exists(data_file)) {
  stop("Data file not found: ", data_file)
}

# Read data
data <- read.csv(data_file, stringsAsFactors = FALSE)
data$Date <- as.Date(data$Date)

# Separate FX and Equity data
fx_cols <- grep("^[A-Z]{6}$", names(data), value = TRUE)  # 6-letter currency pairs
equity_cols <- grep("^[A-Z]{1,5}$", names(data), value = TRUE)  # 1-5 letter stock symbols

fx_data <- data[, c("Date", fx_cols)]
equity_data <- data[, c("Date", equity_cols)]

# Calculate returns
calculate_returns <- function(price_data, date_col = "Date") {
  returns <- price_data
  price_cols <- setdiff(names(price_data), date_col)
  
  for (col in price_cols) {
    returns[[col]] <- c(NA, diff(log(price_data[[col]])))
  }
  
  return(returns)
}

fx_returns <- calculate_returns(fx_data)
equity_returns <- calculate_returns(equity_data)

# Create output directories
dir.create("outputs/eda/tables", showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/eda/figures", showWarnings = FALSE, recursive = TRUE)

# Generate summary statistics
cat("Generating summary statistics...\n")

# FX Summary
fx_summary <- data.frame(
  Asset = fx_cols,
  Type = "FX",
  Mean = sapply(fx_cols, function(x) mean(fx_returns[[x]], na.rm = TRUE)),
  SD = sapply(fx_cols, function(x) sd(fx_returns[[x]], na.rm = TRUE)),
  Min = sapply(fx_cols, function(x) min(fx_returns[[x]], na.rm = TRUE)),
  Max = sapply(fx_cols, function(x) max(fx_returns[[x]], na.rm = TRUE)),
  Skewness = sapply(fx_cols, function(x) moments::skewness(fx_returns[[x]], na.rm = TRUE)),
  Kurtosis = sapply(fx_cols, function(x) moments::kurtosis(fx_returns[[x]], na.rm = TRUE)),
  Observations = sapply(fx_cols, function(x) sum(!is.na(fx_returns[[x]])))
)

# Equity Summary
equity_summary <- data.frame(
  Asset = equity_cols,
  Type = "Equity",
  Mean = sapply(equity_cols, function(x) mean(equity_returns[[x]], na.rm = TRUE)),
  SD = sapply(equity_cols, function(x) sd(equity_returns[[x]], na.rm = TRUE)),
  Min = sapply(equity_cols, function(x) min(equity_returns[[x]], na.rm = TRUE)),
  Max = sapply(equity_cols, function(x) max(equity_returns[[x]], na.rm = TRUE)),
  Skewness = sapply(equity_cols, function(x) moments::skewness(equity_returns[[x]], na.rm = TRUE)),
  Kurtosis = sapply(equity_cols, function(x) moments::kurtosis(equity_returns[[x]], na.rm = TRUE)),
  Observations = sapply(equity_cols, function(x) sum(!is.na(equity_returns[[x]])))
)

# Combine summaries
all_summary <- rbind(fx_summary, equity_summary)

# Save summary statistics
write.csv(all_summary, "outputs/eda/tables/summary_statistics.csv", row.names = FALSE)

# Generate enhanced histograms
cat("Generating enhanced histograms...\n")

# Function to create enhanced histogram
create_enhanced_histogram <- function(returns_data, asset_name, output_dir) {
  # Calculate statistics for annotation
  mean_val <- mean(returns_data[[asset_name]], na.rm = TRUE)
  sd_val <- sd(returns_data[[asset_name]], na.rm = TRUE)
  skewness_val <- moments::skewness(returns_data[[asset_name]], na.rm = TRUE)
  kurtosis_val <- moments::kurtosis(returns_data[[asset_name]], na.rm = TRUE)
  
  # Determine asset type for color
  asset_type <- if(asset_name %in% fx_cols) "FX" else "Equity"
  color_scheme <- if(asset_type == "FX") c("#1f77b4", "#ff7f0e") else c("#2ca02c", "#d62728")
  
  # Create histogram with density overlay
  p <- ggplot(returns_data, aes_string(x = asset_name)) +
    geom_histogram(aes(y = ..density..), bins = 50, fill = color_scheme[1], 
                   alpha = 0.7, color = "white", linewidth = 0.3) +
    geom_density(color = color_scheme[2], linewidth = 1.2) +
    geom_vline(xintercept = mean_val, color = "red", linewidth = 1, linetype = "dashed") +
    labs(
      title = paste("Return Distribution:", asset_name),
      subtitle = paste("Asset Type:", asset_type, "| Mean:", round(mean_val, 4), 
                      "| SD:", round(sd_val, 4), "| Skew:", round(skewness_val, 2),
                      "| Kurt:", round(kurtosis_val, 2)),
      x = "Log Returns", 
      y = "Density",
      caption = paste("Data range:", format(min(returns_data$Date), "%Y-%m-%d"), 
                     "to", format(max(returns_data$Date), "%Y-%m-%d"))
    ) +
    scale_x_continuous(labels = scales::percent_format(accuracy = 0.1)) +
    scale_y_continuous(labels = scales::comma_format()) +
    professional_theme() +
    theme(
      legend.position = "none",
      plot.caption = element_text(size = 9, color = "gray50", hjust = 0)
    )
  
  # Add statistics annotation
  p <- p + annotate(
    "text", x = Inf, y = Inf, 
    label = paste("Mean:", round(mean_val, 4), "\nSD:", round(sd_val, 4)),
    hjust = 1.1, vjust = 1.1, size = 3.5, color = "gray30",
    fontface = "bold"
  )
  
  ggsave(file.path(output_dir, paste0(asset_name, "_histogram_enhanced.png")), 
         plot = p, width = 10, height = 7, dpi = 300, bg = "white")
}

# Create enhanced histograms for all assets
for (asset in c(fx_cols, equity_cols)) {
  if (asset %in% fx_cols) {
    create_enhanced_histogram(fx_returns, asset, "outputs/eda/figures")
  } else {
    create_enhanced_histogram(equity_returns, asset, "outputs/eda/figures")
  }
}

# Generate enhanced correlation matrix
cat("Generating enhanced correlation matrix...\n")

# Combine all returns
all_returns <- cbind(fx_returns[, fx_cols], equity_returns[, equity_cols])
correlation_matrix <- cor(all_returns, use = "complete.obs")

# Save correlation matrix
write.csv(correlation_matrix, "outputs/eda/tables/correlation_matrix.csv")

# Create enhanced correlation heatmap
correlation_long <- as.data.frame(correlation_matrix) %>%
  rownames_to_column("Asset1") %>%
  gather(key = "Asset2", value = "Correlation", -Asset1) %>%
  mutate(
    Asset1_Type = ifelse(Asset1 %in% fx_cols, "FX", "Equity"),
    Asset2_Type = ifelse(Asset2 %in% fx_cols, "FX", "Equity"),
    Type_Combination = paste(Asset1_Type, Asset2_Type, sep = "-")
  )

p_corr <- ggplot(correlation_long, aes(x = Asset1, y = Asset2, fill = Correlation)) +
  geom_tile(color = "white", linewidth = 0.5) +
  scale_fill_gradient2(
    low = "#d73027", mid = "white", high = "#1e88e5",
    midpoint = 0, limit = c(-1, 1), 
    name = "Correlation\nCoefficient",
    labels = c("-1.0", "-0.5", "0.0", "0.5", "1.0")
  ) +
  labs(
    title = "Asset Return Correlation Matrix",
    subtitle = paste("Period:", format(min(data$Date), "%Y-%m-%d"), 
                    "to", format(max(data$Date), "%Y-%m-%d")),
    x = "Asset 1", 
    y = "Asset 2",
    caption = "Blue: Positive correlation | Red: Negative correlation | White: No correlation"
  ) +
  professional_theme() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 9),
    axis.text.y = element_text(size = 9),
    plot.caption = element_text(size = 9, color = "gray50", hjust = 0)
  ) +
  # Add correlation values on tiles
  geom_text(aes(label = sprintf("%.2f", Correlation)), 
            size = 2.5, color = "black", fontface = "bold")

ggsave("outputs/eda/figures/correlation_heatmap_enhanced.png", 
       plot = p_corr, width = 12, height = 10, dpi = 300, bg = "white")

# Generate enhanced time series plots
cat("Generating enhanced time series plots...\n")

# Function to create enhanced time series plot
create_enhanced_time_series <- function(returns_data, asset_name, output_dir) {
  plot_data <- data.frame(
    Date = returns_data$Date,
    Returns = returns_data[[asset_name]]
  ) %>%
    filter(!is.na(Returns))
  
  # Calculate rolling statistics
  plot_data$Rolling_Mean <- zoo::rollmean(plot_data$Returns, k = 30, fill = NA)
  plot_data$Rolling_Vol <- zoo::rollapply(plot_data$Returns, width = 30, FUN = sd, fill = NA)
  
  # Determine asset type for color
  asset_type <- if(asset_name %in% fx_cols) "FX" else "Equity"
  color_scheme <- if(asset_type == "FX") "#1f77b4" else "#2ca02c"
  
  p <- ggplot(plot_data, aes(x = Date, y = Returns)) +
    geom_line(color = color_scheme, alpha = 0.6, linewidth = 0.5) +
    geom_line(aes(y = Rolling_Mean), color = "red", linewidth = 1, linetype = "dashed") +
    geom_hline(yintercept = 0, color = "gray50", linewidth = 0.5, linetype = "solid") +
    labs(
      title = paste("Return Time Series:", asset_name),
      subtitle = paste("Asset Type:", asset_type, "| Mean:", round(mean(plot_data$Returns), 4),
                      "| Volatility:", round(sd(plot_data$Returns), 4)),
      x = "Date", 
      y = "Log Returns",
      caption = paste("Red dashed line: 30-day rolling mean | Data points:", nrow(plot_data))
    ) +
    scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
    scale_y_continuous(labels = scales::percent_format(accuracy = 0.1)) +
    professional_theme() +
    theme(
      legend.position = "none",
      plot.caption = element_text(size = 9, color = "gray50", hjust = 0)
    )
  
  ggsave(file.path(output_dir, paste0(asset_name, "_timeseries_enhanced.png")), 
         plot = p, width = 12, height = 6, dpi = 300, bg = "white")
}

# Create enhanced time series plots for all assets
for (asset in c(fx_cols, equity_cols)) {
  if (asset %in% fx_cols) {
    create_enhanced_time_series(fx_returns, asset, "outputs/eda/figures")
  } else {
    create_enhanced_time_series(equity_returns, asset, "outputs/eda/figures")
  }
}

# Generate comparative analysis plots
cat("Generating comparative analysis plots...\n")

# 1. Volatility comparison by asset type
volatility_comparison <- all_summary %>%
  mutate(Asset_Type = Type) %>%
  ggplot(aes(x = reorder(Asset, SD), y = SD, fill = Asset_Type)) +
  geom_col(alpha = 0.8) +
  scale_fill_manual(values = c("FX" = "#1f77b4", "Equity" = "#2ca02c"),
                    name = "Asset Type") +
  labs(
    title = "Volatility Comparison Across Assets",
    subtitle = "Standard deviation of log returns",
    x = "Asset", 
    y = "Volatility (Standard Deviation)",
    caption = "Higher values indicate greater price variability"
  ) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 0.01)) +
  professional_theme() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("outputs/eda/figures/volatility_comparison.png", 
       plot = volatility_comparison, width = 12, height = 8, dpi = 300, bg = "white")

# 2. Skewness and Kurtosis comparison
skew_kurt_comparison <- all_summary %>%
  select(Asset, Type, Skewness, Kurtosis) %>%
  gather(key = "Statistic", value = "Value", Skewness, Kurtosis) %>%
  ggplot(aes(x = reorder(Asset, Value), y = Value, fill = Type)) +
  geom_col(alpha = 0.8) +
  facet_wrap(~Statistic, scales = "free_y", ncol = 2) +
  scale_fill_manual(values = c("FX" = "#1f77b4", "Equity" = "#2ca02c"),
                    name = "Asset Type") +
  labs(
    title = "Distribution Shape Comparison",
    subtitle = "Skewness and Kurtosis by Asset",
    x = "Asset", 
    y = "Value",
    caption = "Skewness: Asymmetry | Kurtosis: Tail heaviness"
  ) +
  professional_theme() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("outputs/eda/figures/skew_kurt_comparison.png", 
       plot = skew_kurt_comparison, width = 14, height = 8, dpi = 300, bg = "white")

# 3. Return distribution comparison (boxplot)
return_distribution_comparison <- bind_rows(
  fx_returns %>% select(-Date) %>% gather(key = "Asset", value = "Returns") %>% mutate(Type = "FX"),
  equity_returns %>% select(-Date) %>% gather(key = "Asset", value = "Returns") %>% mutate(Type = "Equity")
) %>%
  filter(!is.na(Returns)) %>%
  ggplot(aes(x = reorder(Asset, Returns, FUN = median), y = Returns, fill = Type)) +
  geom_boxplot(alpha = 0.7, outlier.alpha = 0.5) +
  scale_fill_manual(values = c("FX" = "#1f77b4", "Equity" = "#2ca02c"),
                    name = "Asset Type") +
  labs(
    title = "Return Distribution Comparison",
    subtitle = "Box plots showing median, quartiles, and outliers",
    x = "Asset", 
    y = "Log Returns",
    caption = "Box: IQR | Whiskers: 1.5*IQR | Points: Outliers"
  ) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 0.1)) +
  professional_theme() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave("outputs/eda/figures/return_distribution_comparison.png", 
       plot = return_distribution_comparison, width = 14, height = 8, dpi = 300, bg = "white")

# Generate EDA summary report
cat("Generating EDA summary report...\n")

eda_summary <- data.frame(
  Metric = c("Total Assets", "FX Assets", "Equity Assets", "Total Observations", 
             "Date Range Start", "Date Range End", "Files Generated",
             "Average FX Volatility", "Average Equity Volatility",
             "Average FX Skewness", "Average Equity Skewness",
             "Average FX Kurtosis", "Average Equity Kurtosis"),
  Value = c(
    length(c(fx_cols, equity_cols)),
    length(fx_cols),
    length(equity_cols),
    nrow(data),
    as.character(min(data$Date)),
    as.character(max(data$Date)),
    length(list.files("outputs/eda", recursive = TRUE)),
    round(mean(fx_summary$SD), 4),
    round(mean(equity_summary$SD), 4),
    round(mean(fx_summary$Skewness), 2),
    round(mean(equity_summary$Skewness), 2),
    round(mean(fx_summary$Kurtosis), 2),
    round(mean(equity_summary$Kurtosis), 2)
  )
)

write.csv(eda_summary, "outputs/eda/tables/eda_summary.csv", row.names = FALSE)

cat("✓ Enhanced EDA analysis completed successfully!\n")
cat("Generated files:\n")
cat("- Summary statistics: outputs/eda/tables/summary_statistics.csv\n")
cat("- Correlation matrix: outputs/eda/tables/correlation_matrix.csv\n")
cat("- Enhanced EDA summary: outputs/eda/tables/eda_summary.csv\n")
cat("- Enhanced figures: outputs/eda/figures/\n")
cat("  * Enhanced histograms with density overlays\n")
cat("  * Enhanced correlation heatmap with values\n")
cat("  * Enhanced time series with rolling statistics\n")
cat("  * Volatility comparison across assets\n")
cat("  * Skewness and kurtosis comparison\n")
cat("  * Return distribution boxplots\n")
