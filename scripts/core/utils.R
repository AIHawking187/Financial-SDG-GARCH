#!/usr/bin/env Rscript
# Consolidated Utilities Module
# This file combines utility functions from multiple files into a single, unified module
# Replaces: conflict_resolution.R, cli_parser.R, safety_functions.R, enhanced_plotting.R

# Load required libraries
library(dplyr)
library(tidyr)
library(stringr)
library(ggplot2)
library(scales)
library(viridis)
library(gridExtra)

# Load configuration
source("scripts/core/config.R")

# =============================================================================
# CONFLICT RESOLUTION
# =============================================================================

# Resolve package conflicts
resolve_conflicts <- function() {
  # Resolve dplyr/xts lag function conflicts
  if (exists("lag", envir = asNamespace("dplyr"))) {
    # Use stats::lag for xts objects
    assign("lag", stats::lag, envir = asNamespace("xts"))
  }
  
  # Suppress warnings for known conflicts
  options(xts.warn_dplyr_breaks_lag = FALSE)
  
  cat("✓ Package conflicts resolved\n")
}

# Initialize pipeline with conflict resolution
initialize_pipeline <- function() {
  cat("Initializing pipeline with conflict resolution...\n")
  resolve_conflicts()
  cat("✓ Pipeline initialization complete\n")
}

# =============================================================================
# CLI PARSING
# =============================================================================

# Parse command line arguments
parse_cli_args <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  
  # Default values
  config <- list(
    engine = "rugarch",
    verbose = FALSE,
    debug = FALSE
  )
  
  # Parse arguments
  i <- 1
  while (i <= length(args)) {
    if (args[i] == "--engine" && i + 1 <= length(args)) {
      config$engine <- args[i + 1]
      i <- i + 2
    } else if (args[i] == "--verbose") {
      config$verbose <- TRUE
      i <- i + 1
    } else if (args[i] == "--debug") {
      config$debug <- TRUE
      i <- i + 1
    } else {
      i <- i + 1
    }
  }
  
  return(config)
}

# Get engine from CLI or default
get_engine <- function() {
  config <- parse_cli_args()
  return(config$engine)
}

# Print current configuration
print_config <- function() {
  config <- parse_cli_args()
  cat("=== CURRENT CONFIGURATION ===\n")
  cat("Engine:", config$engine, "\n")
  cat("Verbose:", config$verbose, "\n")
  cat("Debug:", config$debug, "\n")
  cat("============================\n")
}

# =============================================================================
# SAFETY FUNCTIONS
# =============================================================================

# Safe file operations
safe_read_csv <- function(file_path, ...) {
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path)
  }
  
  tryCatch({
    read.csv(file_path, ...)
  }, error = function(e) {
    stop("Error reading file ", file_path, ": ", e$message)
  })
}

safe_write_csv <- function(data, file_path, ...) {
  tryCatch({
    # Create directory if it doesn't exist
    dir_path <- dirname(file_path)
    if (!dir.exists(dir_path)) {
      dir.create(dir_path, recursive = TRUE)
    }
    
    write.csv(data, file_path, ...)
    cat("✓ File written successfully:", file_path, "\n")
  }, error = function(e) {
    stop("Error writing file ", file_path, ": ", e$message)
  })
}

# Safe directory operations
ensure_directory <- function(dir_path) {
  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE)
    cat("✓ Directory created:", dir_path, "\n")
  }
  return(dir_path)
}

# Safe data validation
validate_data <- function(data, required_cols = NULL, min_rows = 1) {
  # Check if data is not null
  if (is.null(data)) {
    stop("Data is NULL")
  }
  
  # Check if data has required columns
  if (!is.null(required_cols)) {
    missing_cols <- setdiff(required_cols, colnames(data))
    if (length(missing_cols) > 0) {
      stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
    }
  }
  
  # Check minimum rows
  if (nrow(data) < min_rows) {
    stop("Data has fewer than ", min_rows, " rows")
  }
  
  return(TRUE)
}

# Safe numeric operations
safe_numeric <- function(x, default = 0) {
  if (is.null(x) || is.na(x) || is.nan(x)) {
    return(default)
  }
  
  if (is.numeric(x)) {
    return(x)
  } else {
    # Try to convert to numeric
    result <- suppressWarnings(as.numeric(x))
    if (is.na(result)) {
      return(default)
    }
    return(result)
  }
}

# Clean numeric values
clean_numeric <- function(x) {
  if (is.numeric(x)) {
    # Replace infinite values with NA
    x[is.infinite(x)] <- NA
    return(x)
  } else {
    # Try to convert to numeric
    result <- suppressWarnings(as.numeric(x))
    result[is.infinite(result)] <- NA
    return(result)
  }
}

# =============================================================================
# ENHANCED PLOTTING
# =============================================================================

# Professional theme for plots
professional_theme <- function() {
  theme_minimal() +
    theme(
      # Text elements
      text = element_text(family = "serif", size = 12),
      axis.title = element_text(size = 14, face = "bold"),
      axis.text = element_text(size = 11),
      plot.title = element_text(size = 16, face = "bold", hjust = 0.5),
      plot.subtitle = element_text(size = 12, hjust = 0.5),
      legend.title = element_text(size = 12, face = "bold"),
      legend.text = element_text(size = 11),
      
      # Panel elements
      panel.grid.major = element_line(color = "gray90", size = 0.3),
      panel.grid.minor = element_line(color = "gray95", size = 0.2),
      panel.background = element_rect(fill = "white", color = NA),
      
      # Legend
      legend.position = "bottom",
      legend.box = "horizontal",
      legend.key = element_rect(fill = "white", color = "gray50"),
      
      # Margins
      plot.margin = margin(1, 1, 1, 1, "cm")
    )
}

# Enhanced histogram
create_enhanced_histogram <- function(data, x_var, title = NULL, subtitle = NULL, 
                                     bins = 30, fill_color = "steelblue", 
                                     alpha = 0.7, add_density = TRUE) {
  
  p <- ggplot(data, aes_string(x = x_var)) +
    geom_histogram(aes(y = ..density..), bins = bins, 
                   fill = fill_color, alpha = alpha, color = "white", size = 0.3) +
    labs(
      title = title,
      subtitle = subtitle,
      x = x_var,
      y = "Density"
    ) +
    professional_theme()
  
  if (add_density) {
    p <- p + geom_density(color = "red", size = 1, alpha = 0.8)
  }
  
  return(p)
}

# Enhanced time series plot
create_enhanced_timeseries <- function(data, x_var, y_var, title = NULL, 
                                      subtitle = NULL, color_var = NULL,
                                      line_size = 0.8, point_size = 1) {
  
  p <- ggplot(data, aes_string(x = x_var, y = y_var))
  
  if (!is.null(color_var)) {
    p <- p + aes_string(color = color_var) +
      geom_line(size = line_size) +
      geom_point(size = point_size, alpha = 0.7) +
      scale_color_viridis_d(name = color_var)
  } else {
    p <- p + geom_line(size = line_size, color = "steelblue") +
      geom_point(size = point_size, alpha = 0.7, color = "steelblue")
  }
  
  p <- p + labs(
    title = title,
    subtitle = subtitle,
    x = x_var,
    y = y_var
  ) +
    professional_theme() +
    scale_x_date(date_labels = "%Y-%m", date_breaks = "6 months") +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  return(p)
}

# Enhanced correlation heatmap
create_correlation_heatmap <- function(data, title = NULL, subtitle = NULL,
                                      method = "pearson", show_values = TRUE,
                                      color_palette = "viridis") {
  
  # Calculate correlation matrix
  cor_matrix <- cor(data, method = method, use = "complete.obs")
  
  # Convert to long format
  cor_data <- as.data.frame(cor_matrix) %>%
    rownames_to_column("Var1") %>%
    gather(key = "Var2", value = "Correlation", -Var1) %>%
    mutate(
      Var1 = factor(Var1, levels = rownames(cor_matrix)),
      Var2 = factor(Var2, levels = colnames(cor_matrix))
    )
  
  # Create plot
  p <- ggplot(cor_data, aes(Var1, Var2, fill = Correlation)) +
    geom_tile() +
    labs(
      title = title,
      subtitle = subtitle,
      x = NULL,
      y = NULL
    ) +
    professional_theme() +
    theme(
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "right"
    )
  
  # Add color scale
  if (color_palette == "viridis") {
    p <- p + scale_fill_viridis_c(limits = c(-1, 1))
  } else {
    p <- p + scale_fill_gradient2(low = "red", mid = "white", high = "blue", 
                                 limits = c(-1, 1))
  }
  
  # Add correlation values
  if (show_values) {
    p <- p + geom_text(aes(label = sprintf("%.2f", Correlation)), 
                       size = 3, color = "black")
  }
  
  return(p)
}

# Save plot with enhanced formatting
save_enhanced_plot <- function(plot, filename, width = 10, height = 8, 
                              dpi = 300, format = "png") {
  
  # Ensure output directory exists
  output_dir <- dirname(filename)
  ensure_directory(output_dir)
  
  # Save plot
  ggsave(
    filename = filename,
    plot = plot,
    width = width,
    height = height,
    dpi = dpi,
    format = format
  )
  
  cat("✓ Plot saved:", filename, "\n")
}

# =============================================================================
# DATA PROCESSING UTILITIES
# =============================================================================

# Convert price data to returns
price_to_returns <- function(prices, method = "log") {
  if (method == "log") {
    returns <- diff(log(prices))
  } else if (method == "simple") {
    returns <- diff(prices) / prices[-length(prices)]
  } else {
    stop("Unknown method. Use 'log' or 'simple'")
  }
  
  return(returns[!is.na(returns)])
}

# Calculate rolling statistics
rolling_stats <- function(data, window = 252, fun = "mean") {
  if (fun == "mean") {
    rollapply(data, width = window, FUN = mean, na.rm = TRUE, align = "right")
  } else if (fun == "sd") {
    rollapply(data, width = window, FUN = sd, na.rm = TRUE, align = "right")
  } else if (fun == "var") {
    rollapply(data, width = window, FUN = var, na.rm = TRUE, align = "right")
  } else {
    stop("Unknown function. Use 'mean', 'sd', or 'var'")
  }
}

# Calculate VaR
calculate_var <- function(returns, confidence_level = 0.95, method = "historical") {
  if (method == "historical") {
    quantile(returns, 1 - confidence_level, na.rm = TRUE)
  } else if (method == "parametric") {
    mean(returns, na.rm = TRUE) + qnorm(1 - confidence_level) * sd(returns, na.rm = TRUE)
  } else {
    stop("Unknown method. Use 'historical' or 'parametric'")
  }
}

# Calculate Expected Shortfall (CVaR)
calculate_es <- function(returns, confidence_level = 0.95) {
  var_level <- calculate_var(returns, confidence_level)
  mean(returns[returns <= var_level], na.rm = TRUE)
}

# =============================================================================
# MODEL EVALUATION UTILITIES
# =============================================================================

# Calculate model performance metrics
calculate_performance_metrics <- function(actual, predicted) {
  # Mean Squared Error
  mse <- mean((actual - predicted)^2, na.rm = TRUE)
  
  # Mean Absolute Error
  mae <- mean(abs(actual - predicted), na.rm = TRUE)
  
  # Root Mean Squared Error
  rmse <- sqrt(mse)
  
  # Mean Absolute Percentage Error
  mape <- mean(abs((actual - predicted) / actual), na.rm = TRUE) * 100
  
  # R-squared
  ss_res <- sum((actual - predicted)^2, na.rm = TRUE)
  ss_tot <- sum((actual - mean(actual, na.rm = TRUE))^2, na.rm = TRUE)
  r_squared <- 1 - (ss_res / ss_tot)
  
  return(list(
    MSE = mse,
    MAE = mae,
    RMSE = rmse,
    MAPE = mape,
    R_squared = r_squared
  ))
}

# Calculate information criteria
calculate_information_criteria <- function(loglik, n_params, n_obs) {
  # Akaike Information Criterion
  aic <- 2 * n_params - 2 * loglik
  
  # Bayesian Information Criterion
  bic <- log(n_obs) * n_params - 2 * loglik
  
  # Hannan-Quinn Information Criterion
  hqic <- 2 * log(log(n_obs)) * n_params - 2 * loglik
  
  return(list(
    AIC = aic,
    BIC = bic,
    HQIC = hqic
  ))
}

# =============================================================================
# EXPORT UTILITIES
# =============================================================================

# Export results to Excel with multiple sheets
export_to_excel <- function(data_list, filename, sheet_names = NULL) {
  library(openxlsx)
  
  # Create workbook
  wb <- createWorkbook()
  
  # Add sheets
  for (i in seq_along(data_list)) {
    sheet_name <- ifelse(is.null(sheet_names), 
                        paste("Sheet", i), 
                        sheet_names[i])
    
    addWorksheet(wb, sheet_name)
    writeData(wb, sheet_name, data_list[[i]])
  }
  
  # Save workbook
  saveWorkbook(wb, filename, overwrite = TRUE)
  cat("✓ Excel file saved:", filename, "\n")
}

# Export results to LaTeX table
export_to_latex <- function(data, filename, caption = NULL, label = NULL) {
  library(xtable)
  
  # Create LaTeX table
  latex_table <- xtable(data, caption = caption, label = label)
  
  # Save to file
  print(latex_table, file = filename, include.rownames = FALSE)
  cat("✓ LaTeX table saved:", filename, "\n")
}

# =============================================================================
# MAIN UTILITY INTERFACE
# =============================================================================

# Main utility interface
utils <- list(
  # Conflict resolution
  resolve_conflicts = resolve_conflicts,
  initialize_pipeline = initialize_pipeline,
  
  # CLI parsing
  parse_cli_args = parse_cli_args,
  get_engine = get_engine,
  print_config = print_config,
  
  # Safety functions
  safe_read_csv = safe_read_csv,
  safe_write_csv = safe_write_csv,
  ensure_directory = ensure_directory,
  validate_data = validate_data,
  safe_numeric = safe_numeric,
  clean_numeric = clean_numeric,
  
  # Enhanced plotting
  professional_theme = professional_theme,
  create_enhanced_histogram = create_enhanced_histogram,
  create_enhanced_timeseries = create_enhanced_timeseries,
  create_correlation_heatmap = create_correlation_heatmap,
  save_enhanced_plot = save_enhanced_plot,
  
  # Data processing
  price_to_returns = price_to_returns,
  rolling_stats = rolling_stats,
  calculate_var = calculate_var,
  calculate_es = calculate_es,
  
  # Model evaluation
  calculate_performance_metrics = calculate_performance_metrics,
  calculate_information_criteria = calculate_information_criteria,
  
  # Export utilities
  export_to_excel = export_to_excel,
  export_to_latex = export_to_latex
)

# Export the utility interface
return(utils)

