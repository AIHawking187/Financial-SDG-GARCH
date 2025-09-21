#Reminder to Set your Working Directory

cat("Starting NFGARCH script...\n")
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

# Source utility functions
source("./scripts/utils/safety_functions.R")
library(ggplot2)
#### Import the FX + EQ price data ####

# Read CSV with Date in first column (row names)

raw_price_data <- read.csv("./data/processed/raw (FX + EQ).csv", row.names = 1)

# Convert row names into a Date column

raw_price_data$Date <- lubridate::ymd(rownames(raw_price_data))
rownames(raw_price_data) <- NULL

# Move Date to the front

raw_price_data <- raw_price_data %>% dplyr::select(Date, everything())


#### Clean the Price data####

# Extract date vector

date_index <- raw_price_data$Date

# Remove date column from data matrix

price_data_matrix <- raw_price_data[, !(names(raw_price_data) %in% "Date")]

# Define equity and FX tickers (ensure they match column names exactly)

equity_tickers <- c("NVDA", "MSFT", "PG", "CAT", "WMT", "AMZN")
fx_names <- c("EURUSD", "GBPUSD", "GBPCNY", "USDZAR", "GBPZAR", "EURZAR")

# Split into equity and FX price matrices

equity_xts <- lapply(equity_tickers, function(ticker)
{
  xts(price_data_matrix[[ticker]], order.by = date_index)
})

names(equity_xts) <- equity_tickers

fx_xts <- lapply(fx_names, function(ticker) 
{
  xts(price_data_matrix[[ticker]], order.by = date_index)
})

names(fx_xts) <- fx_names


#### Calculate Returns on FX and Equity data ####

# Calculate returns

equity_returns <- lapply(equity_xts, function(x) CalculateReturns(x)[-1, ])
fx_returns     <- lapply(fx_xts,     function(x) diff(log(x))[-1, ])

#### Plotting returns data ####

plot_returns_and_save <- function(returns_list, prefix) {
  dir_path <- file.path("results/plots/exhaustive", paste0("histograms_", prefix))
  dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
  
  for (name in names(returns_list)) {
    png(file.path(dir_path, paste0(name, "_histogram.png")), width = 800, height = 600)
    chart.Histogram(returns_list[[name]], method = c("add.density", "add.normal"),
                    main = paste(prefix, name), colorset = c("blue", "red", "black"))
    dev.off()
  }
}

plot_returns_and_save(equity_returns, "Real_Equity")
plot_returns_and_save(fx_returns, "Real_FX")


#### Model Generator ####

generate_spec <- function(model, dist = "sstd", submodel = NULL) 
{
  ugarchspec(
    mean.model = list(armaOrder = c(0,0)),
    variance.model = list(model = model, garchOrder = c(1,1), submodel = submodel),
    distribution.model = dist
  )
} # Change the order of the ARCH and GARCH parameters here

#### Automate Fitting for Any Set of Returns #### 

fit_models <- function(returns_list, model_type, dist_type = "sstd", submodel = NULL) 
{
  specs <- lapply(returns_list, function(x) generate_spec(model_type, dist_type, submodel))
  fits <- mapply(function(ret, spec) ugarchfit(data = ret, spec = spec, out.sample = 20),
                 returns_list, specs, SIMPLIFY = FALSE)
  return(fits)
}

#### Set the GARCH Model Configs ####

# List of Different model configurations
model_configs <- list(
  sGARCH_norm  = list(model = "sGARCH", distribution = "norm", submodel = NULL),
  sGARCH_sstd  = list(model = "sGARCH", distribution = "sstd", submodel = NULL),
  gjrGARCH     = list(model = "gjrGARCH", distribution = "sstd", submodel = NULL),
  eGARCH       = list(model = "eGARCH", distribution = "sstd", submodel = NULL),
  TGARCH       = list(model = "fGARCH", distribution = "sstd", submodel = "TGARCH")
)  # Change the distributional assumptions of the ARCH and GARCH parameters here


#### Data Splitting ####

## Chronological Data Split
# Helper to get cutoff index
get_split_index <- function(x, split_ratio = 0.65) 
{
  return(floor(nrow(x) * split_ratio))
}

# Split returns into train/test
fx_train_returns <- lapply(fx_returns, function(x) x[1:get_split_index(x)])
fx_test_returns  <- lapply(fx_returns, function(x) x[(get_split_index(x) + 1):nrow(x)])

equity_train_returns <- lapply(equity_returns, function(x) x[1:get_split_index(x)])
equity_test_returns  <- lapply(equity_returns, function(x) x[(get_split_index(x) + 1):nrow(x)])

## Time-series cross-validation - Sliding Window Time-Series Cross-Validation

# Helper to get cutoff index and train across sliding windows
ts_cross_validate <- function(returns, model_type, dist_type = "sstd", submodel = NULL,
                              nf_innovations = NULL,
                              window_size = 500, step_size = 50, forecast_horizon = 20) {
  n <- nrow(returns)
  results <- list()
  window_index <- 1
  innovation_index <- 1
  
  for (start_idx in seq(1, n - window_size - forecast_horizon, by = step_size)) {
    train_set <- returns[start_idx:(start_idx + window_size - 1)]
    test_set  <- returns[(start_idx + window_size):(start_idx + window_size + forecast_horizon - 1)]
    
    spec <- generate_spec(model_type, dist_type, submodel)
    
    fit <- tryCatch({
      ugarchfit(data = train_set, spec = spec)
    }, error = function(e) {
      message("❌ Fit error: ", conditionMessage(e))
      return(NULL)
    })
    
    if (!is.null(fit)) {
      if (!is.null(nf_innovations)) {
        # Pull the appropriate slice of synthetic residuals
        n_sim <- forecast_horizon
        if (innovation_index + n_sim - 1 > length(nf_innovations)) break
        resid_slice <- nf_innovations[innovation_index:(innovation_index + n_sim - 1)]
        innovation_index <- innovation_index + n_sim
        
        sim <- tryCatch({
          ugarchpath(spec,
                     n.sim = n_sim,
                     m.sim = 1,
                     presigma = tail(sigma(fit), 1),
                     preresiduals = tail(residuals(fit), 1),
                     prereturns = tail(fitted(fit), 1),
                     innovations = resid_slice,
                     pars = coef(fit))
        }, error = function(e) return(NULL))
        
        if (!is.null(sim)) {
          sim_returns <- fitted(sim)
          actual <- test_set[1:min(length(sim_returns), length(test_set))]
          sim_returns <- sim_returns[1:length(actual)]
          
          mse <- mean((actual - sim_returns)^2, na.rm = TRUE)
          mae <- mean(abs(actual - sim_returns), na.rm = TRUE)
          
          results[[length(results) + 1]] <- list(
            Window = window_index,
            MSE = mse,
            MAE = mae,
            SplitType = "CV_NF",
            residuals = resid_slice
          )
        }
      } else {
        forecast <- tryCatch({
          ugarchforecast(fit, n.ahead = forecast_horizon)
        }, error = function(e) return(NULL))
        
        if (!is.null(forecast)) {
          eval <- tryCatch({
            evaluate_model(fit, forecast, test_set)
          }, error = function(e) return(NULL))
          
          if (!is.null(eval)) {
            eval$WindowStart <- index(train_set[1])
            results[[length(results) + 1]] <- eval
          }
        }
      }
      window_index <- window_index + 1
    }
  }
  return(results)
}



# Helper function to extract the best fit from each CV using criteria like:
# Lowest AIC / BIC
# 
# Highest log-likelihood
# 
# Lowest forecast MSE / MAE (from evaluate_model)

extract_best_fit <- function(cv_result, metric = "MSE..Forecast.vs.Actual.", minimize = TRUE) 
{
  if (is.null(cv_result) || length(cv_result) == 0) return(NULL)
  
  metric_vals <- sapply(cv_result, function(x) {
    if (!is.null(x[[metric]])) return(x[[metric]])
    else return(NA)
  })
  
  if (all(is.na(metric_vals))) return(NULL)
  
  best_index <- if (minimize) which.min(metric_vals) else which.max(metric_vals)
  return(cv_result[[best_index]]$fit_object[[1]])
}

# Helper to evaluate results across each TS CV Window
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
  
  # Extract residuals
  resids <- tryCatch(as.numeric(residuals(fit, standardize = TRUE)), error = function(e) NA)
  
  return(list(
    metrics = data.frame(
      AIC = infocriteria(fit)[1],
      BIC = infocriteria(fit)[2],
      LogLikelihood = likelihood(fit),
      `MSE (Forecast vs Actual)` = mse,
      `MAE (Forecast vs Actual)` = mae,
      `Q-Stat (p>0.05)` = q_stat_p,
      `ARCH LM (p>0.05)` = arch_p
    ),
    residuals = resids,
    fit_object = list(fit)  # wrap in list to keep structure consistent
  ))
}


# Helper to evaluate results across the 65/35 chronological split

compare_results <- function(cv_result_list, model_name, is_cv = FALSE) {
  if (length(cv_result_list) == 0) return(NULL)
  
  all_rows <- list()
  
  for (asset_name in names(cv_result_list)) {
    asset_result <- cv_result_list[[asset_name]]
    
    for (window_eval in asset_result) {
      # Ensure it's a data frame
      if (!is.null(window_eval$metrics)) {
        eval_metrics <- window_eval$metrics
        eval_metrics$Asset <- asset_name
        eval_metrics$Model <- model_name
        eval_metrics$Type  <- ifelse(is_cv, "CV", "Chrono")
        all_rows[[length(all_rows) + 1]] <- eval_metrics
      }
    }
  }
  
  if (length(all_rows) == 0) return(NULL)
  
  # Before binding, make sure all have the same columns
  common_cols <- Reduce(intersect, lapply(all_rows, names))
  all_rows <- lapply(all_rows, function(df) df[, common_cols, drop = FALSE])
  
  return(bind_rows(all_rows))
}

#### Train the GARCH Models using Chrono split and TS CV Split ####

# Train model fits across 65/35 Chrono Split
Fitted_Chrono_Split_models <- list()

for (config_name in names(model_configs)) 
{
  cfg <- model_configs[[config_name]]
  
  equity_chrono_split_fit <- fit_models(equity_train_returns, model_type = cfg$model, dist_type = cfg$dist, submodel = cfg$submodel)
  fx_chrono_split_fit     <- fit_models(fx_train_returns, model_type = cfg$model, dist_type = cfg$dist, submodel = cfg$submodel)
  
  Fitted_Chrono_Split_models[[paste0("equity_", config_name)]] <- equity_chrono_split_fit
  Fitted_Chrono_Split_models[[paste0("fx_", config_name)]]     <- fx_chrono_split_fit
}

# Helper to run all CV models across window size of x and a forecast horizon of y

run_all_cv_models <- function(returns_list, model_configs, window_size = 500, forecast_horizon = 40) 
{
  cv_results_all <- list()
  
  for (model_name in names(model_configs)) {
    cfg <- model_configs[[model_name]]
    
    message("Running CV for: ", model_name)
    
    result <- lapply(returns_list, function(ret) {
      tryCatch({
        ts_cross_validate(ret, 
                          model_type = cfg$model, 
                          dist_type  = cfg$dist, 
                          submodel   = cfg$submodel,
                          window_size = window_size,
                          forecast_horizon = forecast_horizon)
      }, error = function(e) NULL)
    })
    
    # Keep non-null results only
    result <- result[!sapply(result, is.null)]
    
    cv_results_all[[model_name]] <- result
  }
  
  return(cv_results_all)
}

# Check and ensure sufficient size and variability across each window

valid_fx_returns <- fx_returns[sapply(fx_returns, function(x) nrow(x) > 520 && sd(x, na.rm = TRUE) > 0)]
valid_equity_returns <- equity_returns[sapply(equity_returns, function(x) nrow(x) > 520 && sd(x, na.rm = TRUE) > 0)]

# Run all CV models on all model configs across window size of 500 and a forecast horizon of 40

Fitted_FX_TS_CV_models     <- run_all_cv_models(valid_fx_returns, model_configs)
Fitted_EQ_TS_CV_models <- run_all_cv_models(valid_equity_returns, model_configs)

# Flatten all CV results into one data frame

Fitted_TS_CV_models <- data.frame()

for (model_name in names(Fitted_FX_TS_CV_models)) {
  fx_results <- tryCatch({
    compare_results(Fitted_FX_TS_CV_models[[model_name]], model_name, is_cv = TRUE)
      }, error = function(e) {
      message("⚠️ FX compare_results failed for: ", model_name, " - ", conditionMessage(e))
      return(NULL)
    })
  
  eq_results <- tryCatch({
    compare_results(Fitted_EQ_TS_CV_models[[model_name]], model_name, is_cv = TRUE)
      }, error = function(e) {
      message("⚠️ EQ compare_results failed for: ", model_name, " - ", conditionMessage(e))
      return(NULL)
    })
  
  # Use add_row_safe to prevent crashes when models return no rows
  Fitted_TS_CV_models <- add_row_safe(Fitted_TS_CV_models, fx_results)
  Fitted_TS_CV_models <- add_row_safe(Fitted_TS_CV_models, eq_results)
}


#### Load synthetic residuals ####

# Load all synthetic residual files from Python
nf_files <- list.files("nf_generated_residuals", pattern = "*.csv", full.names = TRUE)

# Parse model and asset from file names
nf_residuals_map <- list()
for (f in nf_files) {
  fname <- basename(f)
  # Remove .csv extension and extract the key
  key <- stringr::str_replace(fname, "\\.csv$", "")
  
  # Debug: Print the key being created
  cat("Loading NF residuals for key:", key, "\n")
  
  # Read the residuals
  residuals_data <- read.csv(f)
  
  # Check if 'residual' column exists, otherwise use first column
  if ("residual" %in% names(residuals_data)) {
    nf_residuals_map[[key]] <- residuals_data$residual
  } else {
    nf_residuals_map[[key]] <- residuals_data[[1]]  # Use first column
  }
  
  # Debug: Print the length of loaded residuals
  cat("  Loaded", length(nf_residuals_map[[key]]), "residuals\n")
}

# Debug: Print all available keys
cat("\nAvailable NF residual keys:\n")
for (key in names(nf_residuals_map)) {
  cat("  -", key, "(", length(nf_residuals_map[[key]]), "residuals)\n")
}


# Source the manual NF-GARCH simulator
source("scripts/utils/utils_nf_garch.R")

# Define an NF-GARCH Fitting Function

fit_nf_garch <- function(asset_name, asset_returns, model_config, nf_resid) {
  tryCatch({
    # Validate distribution input
    if (is.null(model_config[["distribution"]]) || !is.character(model_config[["distribution"]])) {
      stop("Distribution must be a non-null character string.")
    }
    
    # Define GARCH spec
    spec <- ugarchspec(
      mean.model = list(armaOrder = c(0, 0)),
      variance.model = list(
        model = model_config[["model"]],
        garchOrder = c(1, 1),
        submodel = model_config[["submodel"]]
      ),
      distribution.model = model_config[["distribution"]]
    )
    
    # Fit GARCH
    fit <- ugarchfit(spec = spec, data = asset_returns)
    
    # Create correctly ordered parameter vector
    ordered_pars <- coef(spec)  # defaults from spec
    fitted_pars <- coef(fit)    # estimated values
    ordered_pars[names(fitted_pars)] <- fitted_pars  # overwrite fitted
    
    # Ensure named numeric vector (not list)
    ordered_pars <- as.numeric(ordered_pars)
    names(ordered_pars) <- names(coef(spec))
    
    # Setup simulation
    n_sim <- floor(length(asset_returns) / 2)
    if (length(nf_resid) < n_sim) {
      warning(paste("⚠️ NF residuals too short for", asset_name, "-", model_config[["model"]]))
      return(NULL)
    }
    
    prereturns_val <- tail(fitted(fit), 1)
    if (is.na(prereturns_val)) prereturns_val <- mean(asset_returns, na.rm = TRUE)
    
    sim_returns <- NULL
    
    # Try ugarchpath first
    sim_returns <- tryCatch({
      sim <- ugarchpath(
        spec,
        n.sim = n_sim,
        m.sim = 1,
        presigma = tail(sigma(fit), 1),
        preresiduals = tail(residuals(fit), 1),
        prereturns = prereturns_val,
        innovations = head(nf_resid, n_sim),
        pars = ordered_pars
      )
      fitted(sim)
    }, error = function(e) {
      message("⚠️ ugarchpath failed, switching to manual NF simulation: ", conditionMessage(e))
      NULL
    })
    
    # Fallback: manual simulator
    if (is.null(sim_returns)) {
      manual <- simulate_nf_garch(
        fit,
        z_nf    = head(nf_resid, n_sim),
        horizon = n_sim,
        model   = model_config[["model"]],
        submodel = model_config[["submodel"]]
      )
      sim_returns <- manual$returns
    }
    
    fitted_values <- sim_returns
    mse <- mean((asset_returns - fitted_values)^2, na.rm = TRUE)
    mae <- mean(abs(asset_returns - fitted_values), na.rm = TRUE)
    
    return(data.frame(
      Model = model_config[["model"]],
      Distribution = model_config[["distribution"]],
      Asset = asset_name,
      AIC = infocriteria(fit)[1],
      BIC = infocriteria(fit)[2],
      LogLikelihood = likelihood(fit),
      MSE = mse,
      MAE = mae,
      SplitType = "Chrono"
    ))
  }, error = function(e) {
    message(paste("❌ Error for", asset_name, model_config[["model"]], ":", conditionMessage(e)))
    return(NULL)
  })
}


# Helper to plot_real_vs_nf_returns

plot_real_vs_nf_returns <- function(real_returns, synthetic_returns, asset_name, model_name) {
  df <- data.frame(
    Value = c(as.numeric(real_returns), as.numeric(synthetic_returns)),
    Type = rep(c("Real", "NF Simulated"), c(length(real_returns), length(synthetic_returns)))
  )
  p <- ggplot(df, aes(x = Value, fill = Type)) +
    geom_histogram(alpha = 0.6, bins = 60, position = "identity") +
    theme_minimal() +
    ggtitle(paste("Return Distribution:", asset_name, "-", model_name))
  
  dir.create("plots/return_distribution", showWarnings = FALSE, recursive = TRUE)
  ggsave(filename = paste0("plots/return_distribution/", asset_name, "_", model_name, "_returns.png"), plot = p)
}





# Loop Over All Assets & Model Configs

nf_results <- list()

for (config_name in names(model_configs)) {
  cfg <- model_configs[[config_name]]
  
  # FX
  for (asset in names(fx_returns)) {
    # Try different key patterns to match the actual file names
    possible_keys <- c(
      paste0(config_name, "_fx_", asset, "_residuals_synthetic"),
      paste0("fx_", asset, "_residuals_", config_name, "_residuals_synthetic_synthetic"),
      paste0(config_name, "_", asset, "_residuals_synthetic")
    )
    
    key <- NULL
    for (k in possible_keys) {
      if (k %in% names(nf_residuals_map)) {
        key <- k
        break
      }
    }
    
    if (is.null(key)) {
      message(paste("❌ Skipped:", asset, config_name, "- No synthetic residuals found."))
      message("  Tried keys:", paste(possible_keys, collapse = ", "))
      next
    }
    
    cat("NF-GARCH (FX):", asset, config_name, "using key:", key, "\n")
    r <- fit_nf_garch(asset, fx_returns[[asset]], cfg, nf_residuals_map[[key]])
    if (!is.null(r)) nf_results[[length(nf_results) + 1]] <- r
  }
  
  # Equity
  for (asset in names(equity_returns)) {
    # Try different key patterns to match the actual file names
    possible_keys <- c(
      paste0(config_name, "_equity_", asset, "_residuals_synthetic"),
      paste0("equity_", asset, "_residuals_", config_name, "_residuals_synthetic_synthetic"),
      paste0(config_name, "_", asset, "_residuals_synthetic")
    )
    
    key <- NULL
    for (k in possible_keys) {
      if (k %in% names(nf_residuals_map)) {
        key <- k
        break
      }
    }
    
    if (is.null(key)) {
      message(paste("❌ Skipped:", asset, config_name, "- No synthetic residuals found."))
      message("  Tried keys:", paste(possible_keys, collapse = ", "))
      next
    }
    
    cat("NF-GARCH (EQ):", asset, config_name, "using key:", key, "\n")
    r <- fit_nf_garch(asset, equity_returns[[asset]], cfg, nf_residuals_map[[key]])
    if (!is.null(r)) nf_results[[length(nf_results) + 1]] <- r
  }
}

nf_results_df <- do.call(rbind, nf_results)
nf_results_df$Source <- "NF"

# Remove the problematic plot call - these variables are not defined in this scope
# plot_real_vs_nf_returns(asset_returns, fitted_values, asset_name, model_config$model)




# === NF-GARCH TS CV Evaluation ===
nf_cv_results <- list()

for (config_name in names(model_configs)) {
  cfg <- model_configs[[config_name]]
  
  # FX
  for (asset in names(valid_fx_returns)) {
    # Try different key patterns to match the actual file names
    possible_keys <- c(
      paste0(config_name, "_fx_", asset, "_residuals_synthetic"),
      paste0("fx_", asset, "_residuals_", config_name, "_residuals_synthetic_synthetic"),
      paste0(config_name, "_", asset, "_residuals_synthetic")
    )
    
    key <- NULL
    for (k in possible_keys) {
      if (k %in% names(nf_residuals_map)) {
        key <- k
        break
      }
    }
    
    if (is.null(key)) {
      message(paste("⚠️ Missing NF residuals for", asset, config_name))
      message("  Tried keys:", paste(possible_keys, collapse = ", "))
      next
    }
    
    message("🔁 Running NF-GARCH CV (FX): ", asset, " [", config_name, "] using key:", key)
    
         r <- ts_cross_validate(valid_fx_returns[[asset]],
                            model_type = cfg[["model"]],
                            dist_type = cfg[["distribution"]],
                            submodel = cfg[["submodel"]],
                            nf_innovations = nf_residuals_map[[key]],
                            window_size = 500,
                            step_size = 50,
                            forecast_horizon = 40)
    
    if (!is.null(r)) {
      df <- do.call(rbind, lapply(r, as.data.frame))
      df$Model <- cfg[["model"]]
      df$Distribution <- cfg[["distribution"]]
      df$Asset <- asset
      df$Source <- "NF"
      df$SplitType <- "CV"
      nf_cv_results[[length(nf_cv_results) + 1]] <- df
    }
  }
  
  # Equity
  for (asset in names(valid_equity_returns)) {
    # Try different key patterns to match the actual file names
    possible_keys <- c(
      paste0(config_name, "_equity_", asset, "_residuals_synthetic"),
      paste0("equity_", asset, "_residuals_", config_name, "_residuals_synthetic_synthetic"),
      paste0(config_name, "_", asset, "_residuals_synthetic")
    )
    
    key <- NULL
    for (k in possible_keys) {
      if (k %in% names(nf_residuals_map)) {
        key <- k
        break
      }
    }
    
    if (is.null(key)) {
      message(paste("⚠️ Missing NF residuals for", asset, config_name))
      message("  Tried keys:", paste(possible_keys, collapse = ", "))
      next
    }
    
    message("🔁 Running NF-GARCH CV (EQ): ", asset, " [", config_name, "] using key:", key)
    
    r <- ts_cross_validate(valid_equity_returns[[asset]],
                           model_type = cfg[["model"]],
                           dist_type = cfg[["distribution"]],
                           submodel = cfg[["submodel"]],
                           nf_innovations = nf_residuals_map[[key]],
                           window_size = 500,
                           step_size = 50,
                           forecast_horizon = 40)
    
    if (!is.null(r)) {
      df <- do.call(rbind, lapply(r, as.data.frame))
      df$Model <- cfg[["model"]]
      df$Distribution <- cfg[["distribution"]]
      df$Asset <- asset
      df$Source <- "NF"
      df$SplitType <- "CV"
      nf_cv_results[[length(nf_cv_results) + 1]] <- df
    }
  }
}

nf_cv_results_df <- do.call(rbind, nf_cv_results)

# Combine & Rank All Models Including NF
# Merge Chrono and CV NF results
final_nf_results <- bind_rows(nf_results_df, nf_cv_results_df)

evaluate_win_rate <- function(standard_df, nf_df, metric = "MSE", split_type = "CV") {
  standard_df <- standard_df %>% filter(SplitType == split_type)
  nf_df <- nf_df %>% filter(SplitType == split_type)
  
  merged <- merge(
    standard_df, nf_df,
    by = c("Asset", "Model"),
    suffixes = c("_GARCH", "_NF")
  )
  
  merged$Win <- merged[[paste0(metric, "_GARCH")]] > merged[[paste0(metric, "_NF")]]
  
  win_rate <- merged %>%
    group_by(Model) %>%
    summarise(
      Wins = sum(Win, na.rm = TRUE),
      Total = n(),
      WinRate = Wins / Total,
      .groups = "drop"
    )
  return(win_rate)
}

library(forecast)

evaluate_dm_test <- function(standard_cv, nf_cv, metric = "MSE") {
  assets <- intersect(unique(standard_cv$Asset), unique(nf_cv$Asset))
  models <- intersect(unique(standard_cv$Model), unique(nf_cv$Model))
  
  results <- list()
  
  for (asset in assets) {
    for (model in models) {
      garch_vals <- standard_cv %>% filter(Asset == asset, Model == model) %>% pull(!!sym(metric))
      nf_vals <- nf_cv %>% filter(Asset == asset, Model == model) %>% pull(!!sym(metric))
      
      if (length(garch_vals) == length(nf_vals) && length(garch_vals) >= 5) {
        dm_result <- tryCatch({
          dm.test(garch_vals, nf_vals, alternative = "greater")  # GARCH worse than NF
        }, error = function(e) NULL)
        
        if (!is.null(dm_result)) {
          results[[length(results) + 1]] <- data.frame(
            Asset = asset,
            Model = model,
            DM_Statistic = dm_result$statistic,
            P_Value = dm_result$p.value,
            Mean_GARCH = mean(garch_vals, na.rm = TRUE),
            Mean_NF = mean(nf_vals, na.rm = TRUE)
          )
        }
      }
    }
  }
  return(bind_rows(results))
}

library(transport)  # for Wasserstein
library(stats)      # for ks.test

evaluate_residual_distance <- function(real_resids, nf_resids, asset, model) {
  ks_res <- tryCatch({
    ks.test(real_resids, nf_resids)
  }, error = function(e) list(statistic = NA, p.value = NA))
  
  wass_res <- tryCatch({
    wasserstein1d(real_resids, nf_resids)
  }, error = function(e) NA)
  
  return(data.frame(
    Asset = asset,
    Model = model,
    KS_Statistic = ks_res$statistic,
    KS_PValue = ks_res$p.value,
    Wasserstein_Distance = wass_res
  ))
}


evaluate_stat_tests <- function(standard_cv, nf_cv, metric = "MSE") {
  standard_cv <- standard_cv %>% filter(SplitType == "CV")
  nf_cv <- nf_cv %>% filter(SplitType == "CV")
  
  assets <- intersect(unique(standard_cv$Asset), unique(nf_cv$Asset))
  models <- intersect(unique(standard_cv$Model), unique(nf_cv$Model))
  
  results <- list()
  
  for (asset in assets) {
    for (model in models) {
      garch_vals <- standard_cv %>% filter(Asset == asset, Model == model) %>% pull(!!sym(metric))
      nf_vals <- nf_cv %>% filter(Asset == asset, Model == model) %>% pull(!!sym(metric))
      
      if (length(garch_vals) == length(nf_vals) && length(garch_vals) >= 5) {
        p <- tryCatch({
          wilcox.test(garch_vals, nf_vals, paired = TRUE, alternative = "greater")$p.value
        }, error = function(e) NA)
        
        results[[length(results) + 1]] <- data.frame(
          Asset = asset, Model = model, P_Value = p, Median_GARCH = median(garch_vals), Median_NF = median(nf_vals)
        )
      }
    }
  }
  
  return(bind_rows(results))
}


All_Results_Chrono_Split$Source <- "Standard"
combined_eval <- dplyr::bind_rows(All_Results_Chrono_Split, nf_results_df)

combined_ranking <- combined_eval %>%
  dplyr::group_by(Source, Model) %>%
  dplyr::summarise(
    Avg_MSE = mean(MSE..Forecast.vs.Actual., na.rm = TRUE),
    Avg_MAE = mean(MAE..Forecast.vs.Actual., na.rm = TRUE),
    Avg_LL  = mean(LogLikelihood, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::arrange(Source, Avg_MSE)


win_rate_table <- evaluate_win_rate(All_Results_Chrono_Split, nf_results_df, metric = "MSE", split_type = "Chrono")
stat_test_df <- evaluate_stat_tests(Fitted_TS_CV_models, nf_cv_results_df, metric = "MSE")
dm_test_df <- evaluate_dm_test(Fitted_TS_CV_models, nf_cv_results_df, metric = "MSE")

residual_eval <- list()

for (key in names(nf_residuals_map)) {
  parts <- strsplit(key, "_")[[1]]
  model_name <- parts[1]
  asset_type <- parts[2]
  asset <- parts[3]
  
  model_cfg <- model_configs[[model_name]]
  real_resids <- tryCatch({
    spec <- generate_spec(model_cfg$model, model_cfg$distribution, model_cfg$submodel)
    fit <- ugarchfit(spec = spec, data = price_data_matrix[[asset]])
    as.numeric(residuals(fit, standardize = TRUE))
  }, error = function(e) NULL)
  
  nf_resids <- nf_residuals_map[[key]]
  
  if (!is.null(real_resids)) {
    df <- evaluate_residual_distance(real_resids, nf_resids, asset, model_name)
    residual_eval[[length(residual_eval) + 1]] <- df
  }
}

residual_distance_df <- bind_rows(residual_eval)



# Plot Comparisons

library(ggplot2)

ggplot(combined_ranking, aes(x = Model, y = Avg_MSE, fill = Source)) +
  geom_bar(stat = "identity", position = "dodge") +
  labs(title = "Avg MSE Comparison: NF vs Normal/SSTD", y = "Avg MSE", x = "") +
  theme_minimal()

plot_nf_vs_garch_residuals <- function(real_resid, nf_resid, asset, model) {
  hist_data <- data.frame(
    Value = c(real_resid, nf_resid),
    Type = rep(c("GARCH", "NF"), c(length(real_resid), length(nf_resid)))
  )
  
  ggplot(hist_data, aes(x = Value, fill = Type)) +
    geom_histogram(alpha = 0.5, position = "identity", bins = 60) +
    ggtitle(paste("Residual Distribution:", asset, "-", model)) +
    theme_minimal()
}

plot_asset_comparison <- function(eval_df, metric = "MSE") {
  ggplot(eval_df, aes(x = Asset, y = .data[[metric]], fill = Source)) +
    geom_bar(stat = "identity", position = "dodge") +
    theme_minimal() +
    labs(title = paste("Asset-wise", metric, ": NF-GARCH vs GARCH"), y = metric, x = "Asset") +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
}

# Example:
plot_asset_comparison(bind_rows(nf_results_df, All_Results_Chrono_Split), metric = "MSE")


library(fmsb)
radar_data <- rbind(
  max_vals,
  min_vals,
  aggregate(MSE ~ Model, data = nf_results_df, mean),
  aggregate(MSE ~ Model, data = All_Results_Chrono_Split, mean)
)


top_model_summary <- final_nf_results %>%
  group_by(Asset, SplitType) %>%
  filter(MSE == min(MSE, na.rm = TRUE)) %>%
  select(Asset, SplitType, Model, MSE, Source)

composite_ranking <- final_nf_results %>%
  group_by(Model, Source) %>%
  summarise(
    CompositeScore = mean(scale(MSE) + scale(MAE) - scale(LogLikelihood), na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(CompositeScore)





#### Save Results ####

# Create a new workbook
wb <- createWorkbook()

# Add each sheet
addWorksheet(wb, "Chrono_Split_Eval")
writeData(wb, "Chrono_Split_Eval", All_Results_Chrono_Split)

addWorksheet(wb, "CV_Results")
writeData(wb, "CV_Results", Fitted_TS_CV_models)

addWorksheet(wb, "CV_Asset_Model_Summary")
writeData(wb, "CV_Asset_Model_Summary", cv_asset_model_summary)

addWorksheet(wb, "CV_Results_All")
writeData(wb, "CV_Results_All", Fitted_TS_CV_models)

addWorksheet(wb, "Model_Ranking_All")
writeData(wb, "Model_Ranking_All", ranking_combined)

addWorksheet(wb, "Synthetic_Chrono_Eval")
writeData(wb, "Synthetic_Chrono_Eval", synth_chrono_results)

addWorksheet(wb, "Synthetic_CV_Eval")
writeData(wb, "Synthetic_CV_Eval", synth_cv_results)

addWorksheet(wb, "All_Model_Ranking")
writeData(wb, "All_Model_Ranking", ranking_all_combined)

addWorksheet(wb, "Synthetic_Distribution_Eval")
writeData(wb, "Synthetic_Distribution_Eval", simulation_results)

addWorksheet(wb, "Synthetic_Distribution_Rank")
writeData(wb, "Synthetic_Distribution_Rank", simulation_ranking)

addWorksheet(wb, "Synth_CV_Asset_Summary")
writeData(wb, "Synth_CV_Asset_Summary", synth_cv_asset_summary)

addWorksheet(wb, "NF_GARCH_Eval")
writeData(wb, "NF_GARCH_Eval", nf_results_df)

addWorksheet(wb, "WinRate_MSE_Chrono")
writeData(wb, "WinRate_MSE_Chrono", win_rate_table)

addWorksheet(wb, "Wilcoxon_MSE_CV")
writeData(wb, "Wilcoxon_MSE_CV", stat_test_df)

addWorksheet(wb, "Residual_Dist_Stats")
writeData(wb, "Residual_Dist_Stats", residual_distance_df)

addWorksheet(wb, "DM_Test_MSE_CV")
writeData(wb, "DM_Test_MSE_CV", dm_test_df)

# Save in workbook
addWorksheet(wb, "NF_GARCH_CV_Eval")
writeData(wb, "NF_GARCH_CV_Eval", nf_cv_results_df)

addWorksheet(wb, "Top_Model_Per_Asset")
writeData(wb, "Top_Model_Per_Asset", top_model_summary)

addWorksheet(wb, "NF_GARCH_All_Eval")
writeData(wb, "NF_GARCH_All_Eval", final_nf_results)

saveWorkbook(wb, "GARCH_Model_Evaluation_Summary.xlsx", overwrite = TRUE)


