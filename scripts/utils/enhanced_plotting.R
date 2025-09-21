#!/usr/bin/env Rscript
# Enhanced Plotting Utilities for NF-GARCH Pipeline
# Provides professional plotting functions with consistent themes and formatting

library(ggplot2)
library(scales)
library(viridis)
library(dplyr)
library(tidyr)
library(gridExtra)

# Professional theme for all plots
professional_theme <- function(base_size = 12, base_family = "") {
  theme_minimal(base_size = base_size, base_family = base_family) +
    theme(
      # Title and subtitle
      plot.title = element_text(hjust = 0.5, size = base_size + 2, face = "bold", 
                               margin = margin(b = 15)),
      plot.subtitle = element_text(hjust = 0.5, size = base_size, color = "gray40", 
                                  margin = margin(b = 10)),
      plot.caption = element_text(size = base_size - 2, color = "gray50", hjust = 0),
      
      # Axes
      axis.title = element_text(size = base_size, face = "bold"),
      axis.text = element_text(size = base_size - 1),
      axis.text.x = element_text(angle = 45, hjust = 1),
      axis.line = element_line(color = "gray50"),
      
      # Legend
      legend.title = element_text(size = base_size - 1, face = "bold"),
      legend.text = element_text(size = base_size - 2),
      legend.position = "bottom",
      legend.box.spacing = unit(0.5, "cm"),
      
      # Grid
      panel.grid.major = element_line(color = "gray90", linewidth = 0.5),
      panel.grid.minor = element_line(color = "gray95", linewidth = 0.3),
      
      # Facets
      strip.text = element_text(size = base_size - 1, face = "bold"),
      strip.background = element_rect(fill = "gray95", color = "gray80"),
      
      # Margins
      plot.margin = margin(20, 20, 20, 20),
      
      # Panel
      panel.border = element_rect(color = "gray80", fill = NA, linewidth = 0.5)
    )
}

# Color schemes for different asset types and models
get_color_scheme <- function(type = "asset") {
  switch(type,
    "asset" = c("FX" = "#1f77b4", "Equity" = "#2ca02c"),
    "model" = c("sGARCH_norm" = "#1f77b4", "sGARCH_sstd" = "#ff7f0e", 
                "eGARCH" = "#2ca02c", "gjrGARCH" = "#d62728", 
                "TGARCH" = "#9467bd", "NF--sGARCH" = "#8c564b",
                "NF--eGARCH" = "#e377c2", "NF--gjrGARCH" = "#7f7f7f",
                "NF--TGARCH" = "#bcbd22"),
    "performance" = c("Good" = "#2ca02c", "Average" = "#ff7f0e", "Poor" = "#d62728"),
    "correlation" = c("Positive" = "#1e88e5", "Negative" = "#d73027", "Neutral" = "gray50")
  )
}

# Enhanced histogram with density overlay
create_enhanced_histogram <- function(data, x_var, title = NULL, subtitle = NULL, 
                                     color = "#1f77b4", bins = 50, 
                                     show_stats = TRUE, show_density = TRUE) {
  
  # Calculate statistics
  mean_val <- mean(data[[x_var]], na.rm = TRUE)
  sd_val <- sd(data[[x_var]], na.rm = TRUE)
  skewness_val <- moments::skewness(data[[x_var]], na.rm = TRUE)
  kurtosis_val <- moments::kurtosis(data[[x_var]], na.rm = TRUE)
  
  p <- ggplot(data, aes_string(x = x_var)) +
    geom_histogram(aes(y = ..density..), bins = bins, fill = color, 
                   alpha = 0.7, color = "white", linewidth = 0.3)
  
  if (show_density) {
    p <- p + geom_density(color = "red", linewidth = 1.2)
  }
  
  p <- p + geom_vline(xintercept = mean_val, color = "red", linewidth = 1, linetype = "dashed") +
    labs(
      title = title,
      subtitle = if (is.null(subtitle)) {
        paste("Mean:", round(mean_val, 4), "| SD:", round(sd_val, 4),
              "| Skew:", round(skewness_val, 2), "| Kurt:", round(kurtosis_val, 2))
      } else subtitle,
      x = "Value", 
      y = "Density",
      caption = paste("Data points:", sum(!is.na(data[[x_var]])))
    ) +
    scale_x_continuous(labels = scales::comma_format()) +
    scale_y_continuous(labels = scales::comma_format()) +
    professional_theme()
  
  if (show_stats) {
    p <- p + annotate(
      "text", x = Inf, y = Inf, 
      label = paste("Mean:", round(mean_val, 4), "\nSD:", round(sd_val, 4)),
      hjust = 1.1, vjust = 1.1, size = 3.5, color = "gray30", fontface = "bold"
    )
  }
  
  return(p)
}

# Enhanced time series plot
create_enhanced_timeseries <- function(data, x_var, y_var, title = NULL, subtitle = NULL,
                                      color = "#1f77b4", show_rolling = TRUE, 
                                      rolling_window = 30, show_zero_line = TRUE) {
  
  plot_data <- data %>%
    select(!!x_var, !!y_var) %>%
    filter(!is.na(!!sym(y_var)))
  
  if (show_rolling && nrow(plot_data) >= rolling_window) {
    plot_data$Rolling_Mean <- zoo::rollmean(plot_data[[y_var]], k = rolling_window, fill = NA)
    plot_data$Rolling_Vol <- zoo::rollapply(plot_data[[y_var]], width = rolling_window, 
                                           FUN = sd, fill = NA)
  }
  
  p <- ggplot(plot_data, aes_string(x = x_var, y = y_var)) +
    geom_line(color = color, alpha = 0.6, linewidth = 0.5)
  
  if (show_rolling && "Rolling_Mean" %in% names(plot_data)) {
    p <- p + geom_line(aes(y = Rolling_Mean), color = "red", linewidth = 1, linetype = "dashed")
  }
  
  if (show_zero_line) {
    p <- p + geom_hline(yintercept = 0, color = "gray50", linewidth = 0.5, linetype = "solid")
  }
  
  p <- p + labs(
    title = title,
    subtitle = subtitle,
    x = "Date", 
    y = "Value",
    caption = paste("Data points:", nrow(plot_data))
  ) +
    scale_x_date(date_labels = "%Y", date_breaks = "1 year") +
    scale_y_continuous(labels = scales::comma_format()) +
    professional_theme()
  
  return(p)
}

# Enhanced correlation heatmap
create_enhanced_correlation_heatmap <- function(correlation_matrix, title = NULL, 
                                               subtitle = NULL, show_values = TRUE,
                                               value_size = 2.5) {
  
  correlation_long <- as.data.frame(correlation_matrix) %>%
    rownames_to_column("Var1") %>%
    gather(key = "Var2", value = "Correlation", -Var1)
  
  p <- ggplot(correlation_long, aes(x = Var1, y = Var2, fill = Correlation)) +
    geom_tile(color = "white", linewidth = 0.5) +
    scale_fill_gradient2(
      low = "#d73027", mid = "white", high = "#1e88e5",
      midpoint = 0, limit = c(-1, 1), 
      name = "Correlation\nCoefficient",
      labels = c("-1.0", "-0.5", "0.0", "0.5", "1.0")
    ) +
    labs(
      title = title,
      subtitle = subtitle,
      x = "Variable 1", 
      y = "Variable 2",
      caption = "Blue: Positive correlation | Red: Negative correlation | White: No correlation"
    ) +
    professional_theme() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1, size = 9),
      axis.text.y = element_text(size = 9),
      plot.caption = element_text(size = 9, color = "gray50", hjust = 0)
    )
  
  if (show_values) {
    p <- p + geom_text(aes(label = sprintf("%.2f", Correlation)), 
                       size = value_size, color = "black", fontface = "bold")
  }
  
  return(p)
}

# Enhanced boxplot
create_enhanced_boxplot <- function(data, x_var, y_var, fill_var = NULL, 
                                   title = NULL, subtitle = NULL, 
                                   color_scheme = NULL) {
  
  p <- ggplot(data, aes_string(x = x_var, y = y_var))
  
  if (!is.null(fill_var)) {
    p <- p + aes_string(fill = fill_var)
    if (!is.null(color_scheme)) {
      p <- p + scale_fill_manual(values = color_scheme)
    }
  }
  
  p <- p + geom_boxplot(alpha = 0.7, outlier.alpha = 0.5) +
    labs(
      title = title,
      subtitle = subtitle,
      x = x_var, 
      y = y_var,
      caption = "Box: IQR | Whiskers: 1.5*IQR | Points: Outliers"
    ) +
    scale_y_continuous(labels = scales::comma_format()) +
    professional_theme() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  return(p)
}

# Enhanced scatter plot
create_enhanced_scatter <- function(data, x_var, y_var, color_var = NULL, 
                                   title = NULL, subtitle = NULL,
                                   color_scheme = NULL, show_trend = TRUE) {
  
  p <- ggplot(data, aes_string(x = x_var, y = y_var))
  
  if (!is.null(color_var)) {
    p <- p + aes_string(color = color_var)
    if (!is.null(color_scheme)) {
      p <- p + scale_color_manual(values = color_scheme)
    }
  }
  
  p <- p + geom_point(alpha = 0.6, size = 2)
  
  if (show_trend) {
    p <- p + geom_smooth(method = "lm", se = TRUE, alpha = 0.2, color = "red")
  }
  
  p <- p + labs(
    title = title,
    subtitle = subtitle,
    x = x_var, 
    y = y_var
  ) +
    scale_x_continuous(labels = scales::comma_format()) +
    scale_y_continuous(labels = scales::comma_format()) +
    professional_theme()
  
  return(p)
}

# Enhanced bar plot
create_enhanced_barplot <- function(data, x_var, y_var, fill_var = NULL,
                                   title = NULL, subtitle = NULL,
                                   color_scheme = NULL, horizontal = FALSE) {
  
  p <- ggplot(data, aes_string(x = x_var, y = y_var))
  
  if (!is.null(fill_var)) {
    p <- p + aes_string(fill = fill_var)
    if (!is.null(color_scheme)) {
      p <- p + scale_fill_manual(values = color_scheme)
    }
  }
  
  p <- p + geom_col(alpha = 0.8)
  
  if (horizontal) {
    p <- p + coord_flip()
  }
  
  p <- p + labs(
    title = title,
    subtitle = subtitle,
    x = x_var, 
    y = y_var
  ) +
    scale_y_continuous(labels = scales::comma_format()) +
    professional_theme() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  return(p)
}

# Enhanced performance comparison plot
create_performance_comparison <- function(data, model_var, metric_var, 
                                         title = "Model Performance Comparison",
                                         subtitle = NULL, 
                                         better_is_lower = FALSE) {
  
  # Order by performance
  if (better_is_lower) {
    data <- data %>% arrange(!!sym(metric_var))
  } else {
    data <- data %>% arrange(desc(!!sym(metric_var)))
  }
  
  # Determine color based on performance
  data$Performance <- if (better_is_lower) {
    ifelse(rank(data[[metric_var]]) <= nrow(data) * 0.33, "Good",
           ifelse(rank(data[[metric_var]]) <= nrow(data) * 0.67, "Average", "Poor"))
  } else {
    ifelse(rank(-data[[metric_var]]) <= nrow(data) * 0.33, "Good",
           ifelse(rank(-data[[metric_var]]) <= nrow(data) * 0.67, "Average", "Poor"))
  }
  
  color_scheme <- get_color_scheme("performance")
  
  p <- ggplot(data, aes_string(x = paste0("reorder(", model_var, ", ", metric_var, ")"), 
                               y = metric_var, fill = "Performance")) +
    geom_col(alpha = 0.8) +
    scale_fill_manual(values = color_scheme, name = "Performance") +
    labs(
      title = title,
      subtitle = subtitle,
      x = "Model", 
      y = metric_var,
      caption = "Performance ranking: Good (top 33%) | Average (middle 34%) | Poor (bottom 33%)"
    ) +
    scale_y_continuous(labels = scales::comma_format()) +
    professional_theme() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  return(p)
}

# Save plot with consistent settings
save_enhanced_plot <- function(plot, filename, width = 10, height = 7, dpi = 300) {
  ggsave(filename, plot = plot, width = width, height = height, dpi = dpi, bg = "white")
  cat("✓ Saved enhanced plot:", filename, "\n")
}

# Create multi-panel plot
create_multi_panel_plot <- function(plot_list, ncol = 2, title = NULL, subtitle = NULL) {
  if (!is.null(title) || !is.null(subtitle)) {
    # Add title and subtitle to the first plot
    plot_list[[1]] <- plot_list[[1]] + 
      labs(title = title, subtitle = subtitle) +
      theme(plot.title = element_text(hjust = 0.5, size = 16, face = "bold"),
            plot.subtitle = element_text(hjust = 0.5, size = 14, color = "gray40"))
  }
  
  do.call(grid.arrange, c(plot_list, ncol = ncol))
}

# Print plot summary statistics
print_plot_summary <- function(data, var, title = "Summary Statistics") {
  cat("\n", "=", title, "=", "\n")
  cat("Variable:", var, "\n")
  cat("Mean:", round(mean(data[[var]], na.rm = TRUE), 4), "\n")
  cat("Median:", round(median(data[[var]], na.rm = TRUE), 4), "\n")
  cat("SD:", round(sd(data[[var]], na.rm = TRUE), 4), "\n")
  cat("Min:", round(min(data[[var]], na.rm = TRUE), 4), "\n")
  cat("Max:", round(max(data[[var]], na.rm = TRUE), 4), "\n")
  cat("Skewness:", round(moments::skewness(data[[var]], na.rm = TRUE), 2), "\n")
  cat("Kurtosis:", round(moments::kurtosis(data[[var]], na.rm = TRUE), 2), "\n")
  cat("N:", sum(!is.na(data[[var]])), "\n")
  cat("=", strrep("=", nchar(title)), "=", "\n\n")
}

