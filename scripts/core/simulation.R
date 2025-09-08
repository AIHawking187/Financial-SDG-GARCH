#!/usr/bin/env Rscript
# Consolidated NF-GARCH Simulation Module
# This file combines all simulation functionality into a single, unified module
# Replaces: simulate_nf_garch.R, simulate_nf_garch_engine.R, forecast_garch_variants.R

# Load required libraries
library(rugarch)
library(xts)
library(zoo)
library(dplyr)
library(tidyr)
library(stringr)
library(lubridate)
library(openxlsx)

# Load configuration
source("scripts/core/config.R")

# =============================================================================
# CORE SIMULATION FUNCTIONS
# =============================================================================

# Unified NF-GARCH simulation function
simulate_nf_garch <- function(
  engine = c("rugarch", "manual"),
  models = NULL,
  assets = NULL,
  n_simulations = 1000,
  forecast_horizon = 10,
  confidence_levels = c(0.95, 0.99),
  seed = 12345,
  output_format = c("dataframe", "list", "files")
) {
  # Unified simulation function that handles all NF-GARCH variants
  
  # Set defaults from config if not provided
  if (is.null(models)) {
    models <- get_nf_models()
  }
  if (is.null(assets)) {
    assets <- ALL_ASSETS
  }
  
  # Set seed for reproducibility
  set.seed(seed)
  
  # Load data
  data <- load_simulation_data()
  
  # Initialize results storage
  results <- list()
  
  # Run simulations for each model and asset
  for (model in models) {
    results[[model]] <- list()
    
    for (asset in assets) {
      if (asset %in% names(data)) {
        cat("Simulating", model, "for", asset, "with", engine, "engine...\n")
        
        # Get asset returns
        returns <- data[[asset]]
        
        # Run simulation based on engine
        if (engine == "rugarch") {
          sim_result <- simulate_nf_garch_rugarch(
            returns, model, n_simulations, forecast_horizon, confidence_levels
          )
        } else if (engine == "manual") {
          sim_result <- simulate_nf_garch_manual(
            returns, model, n_simulations, forecast_horizon, confidence_levels
          )
        }
        
        results[[model]][[asset]] <- sim_result
      }
    }
  }
  
  # Format output
  output_format <- match.arg(output_format)
  if (output_format == "dataframe") {
    return(format_simulation_results_dataframe(results))
  } else if (output_format == "files") {
    save_simulation_results_files(results)
    return(TRUE)
  } else {
    return(results)
  }
}

# Rugarch engine simulation
simulate_nf_garch_rugarch <- function(returns, model, n_sim, horizon, conf_levels) {
  # NF-GARCH simulation using rugarch engine
  
  # Load NF residuals
  nf_residuals <- load_nf_residuals(model, returns)
  
  # Fit base GARCH model
  base_model <- extract_base_model_name(model)
  garch_spec <- create_garch_spec(base_model)
  garch_fit <- ugarchfit(garch_spec, returns, solver = "hybrid")
  
  # Generate synthetic data using NF residuals
  synthetic_data <- generate_synthetic_data(nf_residuals, n_sim)
  
  # Fit GARCH to synthetic data
  synthetic_fits <- lapply(synthetic_data, function(data) {
    tryCatch({
      ugarchfit(garch_spec, data, solver = "hybrid")
    }, error = function(e) {
      NULL
    })
  })
  
  # Remove failed fits
  synthetic_fits <- synthetic_fits[!sapply(synthetic_fits, is.null)]
  
  # Generate forecasts
  forecasts <- lapply(synthetic_fits, function(fit) {
    tryCatch({
      ugarchforecast(fit, n.ahead = horizon)
    }, error = function(e) {
      NULL
    })
  })
  
  # Compute VaR forecasts
  var_forecasts <- compute_var_forecasts(forecasts, conf_levels)
  
  return(list(
    model = model,
    engine = "rugarch",
    n_simulations = length(synthetic_fits),
    forecasts = forecasts,
    var_forecasts = var_forecasts,
    synthetic_data = synthetic_data
  ))
}

# Manual engine simulation
simulate_nf_garch_manual <- function(returns, model, n_sim, horizon, conf_levels) {
  # NF-GARCH simulation using manual engine
  
  # Load manual GARCH functions
  source("scripts/models/garch_manual.R")
  manual_garch <- source("scripts/models/garch_manual.R")$value
  
  # Load NF residuals
  nf_residuals <- load_nf_residuals(model, returns)
  
  # Extract base model
  base_model <- extract_base_model_name(model)
  
  # Generate synthetic data
  synthetic_data <- generate_synthetic_data(nf_residuals, n_sim)
  
  # Fit manual GARCH models
  manual_fits <- lapply(synthetic_data, function(data) {
    tryCatch({
      manual_garch$fit(data, model = base_model)
    }, error = function(e) {
      NULL
    })
  })
  
  # Remove failed fits
  manual_fits <- manual_fits[!sapply(manual_fits, is.null)]
  
  # Generate forecasts
  forecasts <- lapply(manual_fits, function(fit) {
    tryCatch({
      manual_garch$forecast(fit, n_ahead = horizon, n_sim = 1000)
    }, error = function(e) {
      NULL
    })
  })
  
  # Compute VaR forecasts
  var_forecasts <- compute_manual_var_forecasts(forecasts, conf_levels)
  
  return(list(
    model = model,
    engine = "manual",
    n_simulations = length(manual_fits),
    forecasts = forecasts,
    var_forecasts = var_forecasts,
    synthetic_data = synthetic_data
  ))
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Load simulation data
load_simulation_data <- function() {
  # Load and preprocess data for simulation
  
  if (!file.exists("./data/processed/raw (FX + EQ).csv")) {
    stop("Data file not found: ./data/processed/raw (FX + EQ).csv")
  }
  
  raw_price_data <- read.csv("./data/processed/raw (FX + EQ).csv", row.names = 1, stringsAsFactors = FALSE)
  raw_price_data$Date <- as.Date(rownames(raw_price_data))
  rownames(raw_price_data) <- NULL
  raw_price_data <- raw_price_data %>% dplyr::select(Date, everything())
  
  # Convert to returns
  returns_data <- list()
  for (col in names(raw_price_data)[-1]) {
    prices <- raw_price_data[[col]]
    returns <- diff(log(prices))
    returns_data[[col]] <- returns[!is.na(returns)]
  }
  
  return(returns_data)
}

# Load NF residuals
load_nf_residuals <- function(model, returns) {
  # Load NF residuals for given model and asset
  
  # Determine asset type and name
  asset_name <- extract_asset_name_from_returns(returns)
  asset_type <- ifelse(asset_name %in% ASSETS$fx, "fx", "equity")
  
  # Construct filename
  filename <- paste0(model, "_", asset_type, "_", asset_name, "_residuals_synthetic.csv")
  filepath <- file.path("nf_generated_residuals", filename)
  
  if (!file.exists(filepath)) {
    stop("NF residual file not found: ", filepath)
  }
  
  residuals <- read.csv(filepath)
  return(residuals)
}

# Extract base model name from NF model
extract_base_model_name <- function(nf_model) {
  # Extract base GARCH model from NF model name
  # e.g., "NF--sGARCH" -> "sGARCH"
  
  if (grepl("^NF--", nf_model)) {
    return(sub("^NF--", "", nf_model))
  } else {
    return(nf_model)
  }
}

# Create GARCH specification
create_garch_spec <- function(model_type) {
  # Create rugarch specification for given model type
  
  if (model_type == "sGARCH") {
    spec <- ugarchspec(
      variance.model = list(model = "sGARCH", garchOrder = c(1, 1)),
      mean.model = list(armaOrder = c(0, 0)),
      distribution.model = "norm"
    )
  } else if (model_type == "eGARCH") {
    spec <- ugarchspec(
      variance.model = list(model = "eGARCH", garchOrder = c(1, 1)),
      mean.model = list(armaOrder = c(0, 0)),
      distribution.model = "norm"
    )
  } else if (model_type == "gjrGARCH") {
    spec <- ugarchspec(
      variance.model = list(model = "gjrGARCH", garchOrder = c(1, 1)),
      mean.model = list(armaOrder = c(0, 0)),
      distribution.model = "norm"
    )
  } else if (model_type == "TGARCH") {
    spec <- ugarchspec(
      variance.model = list(model = "TGARCH", garchOrder = c(1, 1)),
      mean.model = list(armaOrder = c(0, 0)),
      distribution.model = "norm"
    )
  } else {
    stop("Unknown model type: ", model_type)
  }
  
  return(spec)
}

# Generate synthetic data
generate_synthetic_data <- function(nf_residuals, n_simulations) {
  # Generate synthetic data using NF residuals
  
  # Sample from NF residuals
  n_residuals <- nrow(nf_residuals)
  synthetic_data <- list()
  
  for (i in 1:n_simulations) {
    # Sample random indices
    indices <- sample(1:n_residuals, size = n_residuals, replace = TRUE)
    synthetic_data[[i]] <- nf_residuals$residuals[indices]
  }
  
  return(synthetic_data)
}

# Compute VaR forecasts (rugarch)
compute_var_forecasts <- function(forecasts, confidence_levels) {
  # Compute VaR forecasts from rugarch forecast objects
  
  var_results <- list()
  
  for (conf_level in confidence_levels) {
    var_values <- sapply(forecasts, function(fcst) {
      if (!is.null(fcst)) {
        tryCatch({
          quantile(fcst@forecast$seriesFor, 1 - conf_level)
        }, error = function(e) {
          NA
        })
      } else {
        NA
      }
    })
    
    var_results[[as.character(conf_level)]] <- var_values
  }
  
  return(var_results)
}

# Compute VaR forecasts (manual)
compute_manual_var_forecasts <- function(forecasts, confidence_levels) {
  # Compute VaR forecasts from manual forecast objects
  
  var_results <- list()
  
  for (conf_level in confidence_levels) {
    var_values <- sapply(forecasts, function(fcst) {
      if (!is.null(fcst)) {
        tryCatch({
          quantile(fcst$return_forecast[, 1], 1 - conf_level)
        }, error = function(e) {
          NA
        })
      } else {
        NA
      }
    })
    
    var_results[[as.character(conf_level)]] <- var_values
  }
  
  return(var_results)
}

# Extract asset name from returns
extract_asset_name_from_returns <- function(returns) {
  # Extract asset name from returns vector (placeholder)
  # This would need to be implemented based on how returns are identified
  
  # For now, return a default
  return("UNKNOWN")
}

# Format simulation results as dataframe
format_simulation_results_dataframe <- function(results) {
  # Convert simulation results to dataframe format
  
  df_list <- list()
  
  for (model in names(results)) {
    for (asset in names(results[[model]])) {
      result <- results[[model]][[asset]]
      
      # Extract VaR forecasts
      for (conf_level in names(result$var_forecasts)) {
        var_values <- result$var_forecasts[[conf_level]]
        
        df_list[[length(df_list) + 1]] <- data.frame(
          Model = model,
          Asset = asset,
          Engine = result$engine,
          Confidence_Level = as.numeric(conf_level),
          VaR_Value = var_values,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  
  if (length(df_list) > 0) {
    return(do.call(rbind, df_list))
  } else {
    return(data.frame())
  }
}

# Save simulation results to files
save_simulation_results_files <- function(results) {
  # Save simulation results to output files
  
  # Create output directory
  output_dir <- "outputs/nf_garch_simulation"
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Save detailed results
  saveRDS(results, file.path(output_dir, "nf_garch_simulation_results.rds"))
  
  # Save summary dataframe
  summary_df <- format_simulation_results_dataframe(results)
  write.csv(summary_df, file.path(output_dir, "nf_garch_simulation_summary.csv"), row.names = FALSE)
  
  # Save to Excel
  wb <- createWorkbook()
  addWorksheet(wb, "Simulation_Summary")
  writeData(wb, "Simulation_Summary", summary_df)
  saveWorkbook(wb, file.path(output_dir, "nf_garch_simulation_results.xlsx"), overwrite = TRUE)
  
  cat("Simulation results saved to:", output_dir, "\n")
}

# =============================================================================
# LEGACY COMPATIBILITY FUNCTIONS
# =============================================================================

# Legacy simulation function for backward compatibility
simulate_nf_garch_legacy <- function(engine = "rugarch", ...) {
  # Legacy simulation function that maintains backward compatibility
  
  cat("Running legacy NF-GARCH simulation with engine:", engine, "\n")
  
  # Set default parameters
  args <- list(
    engine = engine,
    models = get_nf_models(),
    assets = ALL_ASSETS,
    n_simulations = SIMULATION_PARAMS$n_simulations,
    forecast_horizon = SIMULATION_PARAMS$forecast_horizon,
    confidence_levels = SIMULATION_PARAMS$confidence_levels,
    seed = SIMULATION_PARAMS$seed,
    output_format = "files"
  )
  
  # Override with provided arguments
  args <- modifyList(args, list(...))
  
  # Run simulation
  result <- do.call(simulate_nf_garch, args)
  
  return(result)
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

# Main execution function
main <- function() {
  # Parse command line arguments
  args <- commandArgs(trailingOnly = TRUE)
  
  # Default engine
  engine <- "rugarch"
  
  # Parse engine argument
  if (length(args) > 0) {
    if (args[1] == "--engine" && length(args) > 1) {
      engine <- args[2]
    }
  }
  
  # Validate engine
  if (!engine %in% c("rugarch", "manual")) {
    stop("Invalid engine. Use 'rugarch' or 'manual'")
  }
  
  cat("Starting NF-GARCH simulation with engine:", engine, "\n")
  
  # Run simulation
  tryCatch({
    result <- simulate_nf_garch_legacy(engine = engine)
    cat("Simulation completed successfully\n")
  }, error = function(e) {
    cat("ERROR: Simulation failed:", e$message, "\n")
    quit(status = 1)
  })
}

# Run main function if script is executed directly
if (!interactive() && length(commandArgs(trailingOnly = TRUE)) > 0) {
  main()
}
