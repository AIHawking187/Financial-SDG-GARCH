# Manual Forecast and Path Simulation Functions
# For NF-GARCH simulation and forecasting

source("scripts/manual_garch/manual_garch_core.R")

manual_forecast <- function(fit, h) {
  # Given a fitted manual GARCH object, implement h-step ahead forecast
  if (h <= 0) stop("h must be positive")
  
  last_sigma <- tail(fit$sigma, 1)
  last_residual <- tail(fit$residuals, 1)
  
  sigma_forecast <- numeric(h)
  sigma_forecast[1] <- forecast_one_step(fit, last_sigma, last_residual, fit$model_type)
  
  for (i in 2:h) {
    sigma_forecast[i] <- forecast_one_step(fit, sigma_forecast[i-1], 0, fit$model_type)
  }
  
  # Find mu parameter (it has a prefix)
  mu_idx <- grep("mu", names(fit$coef))
  mu <- if (length(mu_idx) > 0) fit$coef[mu_idx[1]] else 0
  
  return(list(
    sigma = sigma_forecast,
    mean = rep(mu, h)
  ))
}

manual_path <- function(fit, z, h, model, submodel = NULL) {
  # Manual path simulation for NF-GARCH
  # fit: fitted manual GARCH object
  # z: innovations (NF residuals)
  # h: forecast horizon
  # model: model type (for compatibility)
  # submodel: submodel type (for compatibility)
  
  if (h <= 0) stop("h must be positive")
  if (length(z) < h) stop("Not enough innovations provided")
  
  # Use only the first h innovations
  z <- z[1:h]
  
  # Get last state
  last_sigma <- tail(fit$sigma, 1)
  last_residual <- tail(fit$residuals, 1)
  
  # Find mu parameter (it has a prefix)
  mu_idx <- grep("mu", names(fit$coef))
  mu <- if (length(mu_idx) > 0) fit$coef[mu_idx[1]] else 0
  
  # Initialize arrays
  sigma_path <- numeric(h)
  returns_path <- numeric(h)
  
  # First step
  sigma_path[1] <- forecast_one_step(fit, last_sigma, last_residual, fit$model_type)
  returns_path[1] <- mu + sigma_path[1] * z[1]
  
  # Subsequent steps
  for (i in 2:h) {
    sigma_path[i] <- forecast_one_step(fit, sigma_path[i-1], returns_path[i-1] - mu, fit$model_type)
    returns_path[i] <- mu + sigma_path[i] * z[i]
  }
  
  return(list(
    returns = returns_path,
    sigma = sigma_path,
    innovations = z
  ))
}

# Compatibility function to match rugarch interface
manual_simulate_nf_garch <- function(fit, z_nf, horizon = 40, model = NULL, submodel = NULL) {
  # Wrapper function to match the existing simulate_nf_garch interface
  # This allows seamless integration with the existing pipeline
  
  if (is.null(model)) {
    model <- fit$model_type
  }
  
  result <- manual_path(fit, z_nf, horizon, model, submodel)
  
  # Return in the same format as the original simulate_nf_garch
  return(list(
    returns = result$returns,
    sigma = result$sigma,
    innovations = result$innovations
  ))
}
