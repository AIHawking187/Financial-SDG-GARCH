# Stylized Fact Tests for Financial Time Series
# This script tests for common financial market stylized facts
# including volatility clustering, fat tails, leverage effects, and autocorrelation

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
library(moments)
library(lmtest)
library(forecast)

cat("Starting Stylized Fact Tests Analysis...\n")

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

#### Stylized Fact Test Functions ####

# 1. Test for Fat Tails (Excess Kurtosis)
test_fat_tails <- function(returns) {
  kurtosis_val <- kurtosis(returns, na.rm = TRUE)
  excess_kurtosis <- kurtosis_val - 3  # Normal distribution has kurtosis = 3
  
  # Jarque-Bera test for normality
  jb_test <- jarque.bera.test(na.omit(returns))
  
  return(list(
    kurtosis = kurtosis_val,
    excess_kurtosis = excess_kurtosis,
    jarque_bera_stat = jb_test$statistic,
    jarque_bera_pvalue = jb_test$p.value,
    is_fat_tailed = excess_kurtosis > 0
  ))
}

# 2. Test for Volatility Clustering (ARCH effects)
test_volatility_clustering <- function(returns) {
  # ARCH-LM test
  arch_test <- ArchTest(na.omit(returns), lags = 12)
  
  # Ljung-Box test on squared returns
  lb_test <- Box.test(na.omit(returns)^2, lag = 12, type = "Ljung-Box")
  
  return(list(
    arch_stat = arch_test$statistic,
    arch_pvalue = arch_test$p.value,
    lb_stat = lb_test$statistic,
    lb_pvalue = lb_test$p.value,
    has_clustering = arch_test$p.value < 0.05
  ))
}

# 3. Test for Leverage Effects (Asymmetric volatility)
test_leverage_effects <- function(returns) {
  # Engle-Ng test for leverage effects
  # Create dummy variable for negative returns
  neg_returns <- ifelse(returns < 0, 1, 0)
  
  # Regress squared returns on lagged squared returns and leverage dummy
  squared_returns <- returns^2
  lagged_squared <- lag(squared_returns, 1)
  
  # Remove NA values
  valid_data <- data.frame(
    squared = squared_returns,
    lagged = lagged_squared,
    leverage = neg_returns
  )
  valid_data <- na.omit(valid_data)
  
  if (nrow(valid_data) > 10) {
    model <- lm(squared ~ lagged + leverage, data = valid_data)
    leverage_coef <- coef(model)["leverage"]
    leverage_pvalue <- summary(model)$coefficients["leverage", "Pr(>|t|)"]
  } else {
    leverage_coef <- NA
    leverage_pvalue <- NA
  }
  
  return(list(
    leverage_coefficient = leverage_coef,
    leverage_pvalue = leverage_pvalue,
    has_leverage = !is.na(leverage_pvalue) && leverage_pvalue < 0.05
  ))
}

# 4. Test for Autocorrelation in Returns
test_return_autocorrelation <- function(returns) {
  # Ljung-Box test on returns
  lb_test <- Box.test(na.omit(returns), lag = 12, type = "Ljung-Box")
  
  # First-order autocorrelation
  acf1 <- acf(na.omit(returns), lag.max = 1, plot = FALSE)$acf[2]
  
  return(list(
    lb_stat = lb_test$statistic,
    lb_pvalue = lb_test$p.value,
    acf1 = acf1,
    has_autocorr = lb_test$p.value < 0.05
  ))
}

# 5. Test for Long Memory in Volatility
test_long_memory <- function(returns) {
  # Calculate absolute returns as proxy for volatility
  abs_returns <- abs(returns)
  
  # Hurst exponent estimation (simplified)
  n <- length(abs_returns)
  if (n < 50) return(list(hurst = NA, has_long_memory = NA))
  
  # R/S analysis for Hurst exponent
  rs_values <- numeric()
  k_values <- floor(n/10):floor(n/2)
  
  for (k in k_values) {
    if (k < 10) next
    segments <- floor(n/k)
    rs_segment <- numeric(segments)
    
    for (i in 1:segments) {
      start_idx <- (i-1) * k + 1
      end_idx <- min(i * k, n)
      segment_data <- abs_returns[start_idx:end_idx]
      
      if (length(segment_data) >= 10) {
        mean_seg <- mean(segment_data, na.rm = TRUE)
        cumsum_seg <- cumsum(segment_data - mean_seg)
        R <- max(cumsum_seg) - min(cumsum_seg)
        S <- sd(segment_data, na.rm = TRUE)
        if (S > 0) rs_segment[i] <- R/S
      }
    }
    
    if (sum(rs_segment > 0, na.rm = TRUE) > 0) {
      rs_values <- c(rs_values, mean(rs_segment, na.rm = TRUE))
    }
  }
  
  if (length(rs_values) > 1) {
    # Estimate Hurst exponent
    log_k <- log(k_values[1:length(rs_values)])
    log_rs <- log(rs_values)
    hurst_model <- lm(log_rs ~ log_k)
    hurst <- coef(hurst_model)[2]
  } else {
    hurst <- NA
  }
  
  return(list(
    hurst = hurst,
    has_long_memory = !is.na(hurst) && hurst > 0.5
  ))
}

# 6. Test for Heavy Tails (Tail Index)
test_heavy_tails <- function(returns) {
  # Remove NA values
  clean_returns <- na.omit(returns)
  
  # Calculate tail index using Hill estimator
  sorted_returns <- sort(abs(clean_returns), decreasing = TRUE)
  k <- min(floor(length(sorted_returns) * 0.1), 100)  # Use top 10% or 100 observations
  
  if (k < 10) return(list(tail_index = NA, is_heavy_tailed = NA))
  
  # Hill estimator
  log_returns <- log(sorted_returns[1:k])
  tail_index <- 1 / mean(log_returns - log(sorted_returns[k]))
  
  return(list(
    tail_index = tail_index,
    is_heavy_tailed = tail_index < 4  # Less than 4 indicates heavy tails
  ))
}

#### Perform Stylized Fact Tests ####

perform_stylized_tests <- function(returns_data, asset_name, asset_type) {
  cat("Testing stylized facts for", asset_name, "(", asset_type, ")\n")
  
  # Remove any NA values
  clean_returns <- na.omit(returns_data)
  
  if (length(clean_returns) < 100) {
    cat("  Insufficient data for", asset_name, "\n")
    return(NULL)
  }
  
  # Perform all tests
  fat_tails_test <- test_fat_tails(clean_returns)
  clustering_test <- test_volatility_clustering(clean_returns)
  leverage_test <- test_leverage_effects(clean_returns)
  autocorr_test <- test_return_autocorrelation(clean_returns)
  long_memory_test <- test_long_memory(clean_returns)
  heavy_tails_test <- test_heavy_tails(clean_returns)
  
  # Compile results
  results <- list(
    asset = asset_name,
    asset_type = asset_type,
    n_observations = length(clean_returns),
    fat_tails = fat_tails_test,
    volatility_clustering = clustering_test,
    leverage_effects = leverage_test,
    autocorrelation = autocorr_test,
    long_memory = long_memory_test,
    heavy_tails = heavy_tails_test
  )
  
  return(results)
}

# Create output directories
output_dir <- "outputs/model_eval/figures"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# Process all assets
all_results <- list()

# Process equity assets
for (ticker in names(equity_returns)) {
  all_results[[ticker]] <- perform_stylized_tests(equity_returns[[ticker]], ticker, "Equity")
}

# Process FX assets
for (fx in names(fx_returns)) {
  all_results[[fx]] <- perform_stylized_tests(fx_returns[[fx]], fx, "FX")
}

#### Create Summary Tables ####

create_summary_table <- function(results_list) {
  summary_data <- data.frame()
  
  for (asset_name in names(results_list)) {
    if (is.null(results_list[[asset_name]])) next
    
    result <- results_list[[asset_name]]
    
    summary_data <- rbind(summary_data, data.frame(
      Asset = asset_name,
      Asset_Type = result$asset_type,
      N_Observations = result$n_observations,
      
      # Fat tails
      Kurtosis = result$fat_tails$kurtosis,
      Excess_Kurtosis = result$fat_tails$excess_kurtosis,
      JB_Statistic = result$fat_tails$jarque_bera_stat,
      JB_PValue = result$fat_tails$jarque_bera_pvalue,
      Fat_Tailed = result$fat_tails$is_fat_tailed,
      
      # Volatility clustering
      ARCH_Statistic = result$volatility_clustering$arch_stat,
      ARCH_PValue = result$volatility_clustering$arch_pvalue,
      LB_Statistic = result$volatility_clustering$lb_stat,
      LB_PValue = result$volatility_clustering$lb_pvalue,
      Has_Clustering = result$volatility_clustering$has_clustering,
      
      # Leverage effects
      Leverage_Coefficient = result$leverage_effects$leverage_coefficient,
      Leverage_PValue = result$leverage_effects$leverage_pvalue,
      Has_Leverage = result$leverage_effects$has_leverage,
      
      # Autocorrelation
      ACF1 = result$autocorrelation$acf1,
      Return_LB_PValue = result$autocorrelation$lb_pvalue,
      Has_Autocorr = result$autocorrelation$has_autocorr,
      
      # Long memory
      Hurst_Exponent = result$long_memory$hurst,
      Has_Long_Memory = result$long_memory$has_long_memory,
      
      # Heavy tails
      Tail_Index = result$heavy_tails$tail_index,
      Is_Heavy_Tailed = result$heavy_tails$is_heavy_tailed
    ))
  }
  
  return(summary_data)
}

# Create summary table
summary_table <- create_summary_table(all_results)

# Save results
output_table_dir <- "outputs/model_eval/tables"
dir.create(output_table_dir, recursive = TRUE, showWarnings = FALSE)

write.csv(summary_table, paste0(output_table_dir, "/stylized_facts_summary.csv"), row.names = FALSE)

#### Create Visualization Plots ####

# 1. Fat Tails Comparison
create_fat_tails_plot <- function(results_list) {
  fat_tails_data <- data.frame()
  
  for (asset_name in names(results_list)) {
    if (is.null(results_list[[asset_name]])) next
    
    result <- results_list[[asset_name]]
    fat_tails_data <- rbind(fat_tails_data, data.frame(
      Asset = asset_name,
      Asset_Type = result$asset_type,
      Excess_Kurtosis = result$fat_tails$excess_kurtosis
    ))
  }
  
  p <- ggplot(fat_tails_data, aes(x = Asset, y = Excess_Kurtosis, fill = Asset_Type)) +
    geom_bar(stat = "identity") +
    geom_hline(yintercept = 0, linetype = "dashed", color = "red") +
    labs(title = "Excess Kurtosis by Asset",
         x = "Asset", y = "Excess Kurtosis", fill = "Asset Type") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggsave(paste0(output_dir, "/excess_kurtosis_comparison.png"), p, width = 10, height = 6, dpi = 300)
}

# 2. Volatility Clustering Heatmap
create_clustering_heatmap <- function(results_list) {
  clustering_data <- data.frame()
  
  for (asset_name in names(results_list)) {
    if (is.null(results_list[[asset_name]])) next
    
    result <- results_list[[asset_name]]
    clustering_data <- rbind(clustering_data, data.frame(
      Asset = asset_name,
      Asset_Type = result$asset_type,
      ARCH_PValue = result$volatility_clustering$arch_pvalue,
      LB_PValue = result$volatility_clustering$lb_pvalue
    ))
  }
  
  # Create heatmap
  p <- ggplot(clustering_data, aes(x = Asset, y = "ARCH Test", fill = ARCH_PValue)) +
    geom_tile() +
    scale_fill_gradient2(low = "red", mid = "yellow", high = "green", 
                        midpoint = 0.05, limits = c(0, 0.1)) +
    labs(title = "Volatility Clustering Tests (p-values)",
         x = "Asset", y = "Test Type", fill = "P-Value") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  ggsave(paste0(output_dir, "/volatility_clustering_heatmap.png"), p, width = 10, height = 6, dpi = 300)
}

# Generate plots
create_fat_tails_plot(all_results)
create_clustering_heatmap(all_results)

#### Asset Type Comparison ####

# Compare stylized facts between equity and FX
asset_type_comparison <- summary_table %>%
  group_by(Asset_Type) %>%
  summarise(
    Avg_Excess_Kurtosis = mean(Excess_Kurtosis, na.rm = TRUE),
    Avg_Hurst = mean(Hurst_Exponent, na.rm = TRUE),
    Avg_Tail_Index = mean(Tail_Index, na.rm = TRUE),
    Pct_Fat_Tailed = mean(Fat_Tailed, na.rm = TRUE) * 100,
    Pct_Has_Clustering = mean(Has_Clustering, na.rm = TRUE) * 100,
    Pct_Has_Leverage = mean(Has_Leverage, na.rm = TRUE) * 100,
    .groups = 'drop'
  )

write.csv(asset_type_comparison, paste0(output_table_dir, "/asset_type_comparison.csv"), row.names = FALSE)

#### Print Summary ####

cat("\n=== STYLIZED FACTS ANALYSIS SUMMARY ===\n")
cat("Total assets tested:", length(all_results), "\n")
cat("Equity assets:", sum(sapply(all_results, function(x) !is.null(x) && x$asset_type == "Equity")), "\n")
cat("FX assets:", sum(sapply(all_results, function(x) !is.null(x) && x$asset_type == "FX")), "\n")

cat("\n=== ASSET TYPE COMPARISON ===\n")
print(asset_type_comparison)

cat("\n=== STYLIZED FACTS SUMMARY ===\n")
cat("Assets with fat tails:", sum(summary_table$Fat_Tailed, na.rm = TRUE), "/", nrow(summary_table), "\n")
cat("Assets with volatility clustering:", sum(summary_table$Has_Clustering, na.rm = TRUE), "/", nrow(summary_table), "\n")
cat("Assets with leverage effects:", sum(summary_table$Has_Leverage, na.rm = TRUE), "/", nrow(summary_table), "\n")
cat("Assets with long memory:", sum(summary_table$Has_Long_Memory, na.rm = TRUE), "/", nrow(summary_table), "\n")

cat("\nOutput files saved to:", output_dir, "\n")
cat("Summary tables saved to:", output_table_dir, "\n")

cat("\nStylized fact tests complete!\n")

