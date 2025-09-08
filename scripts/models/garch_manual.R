#!/usr/bin/env Rscript
# Consolidated Manual GARCH Implementation
# This file combines all manual GARCH implementations into a single, unified module
# Replaces: manual_garch_core.R, fit_sgarch_manual.R, fit_egarch_manual.R, 
#           fit_gjr_manual.R, fit_tgarch_manual.R, forecast_manual.R

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

# Parameter Transformation Functions
# Transform unconstrained parameters to constrained parameter space for numerical optimization

transform_params <- function(theta, model_type) {
  if (model_type == "sGARCH") {
    # Standard GARCH(1,1) parameter transformation
    # Parameters: μ (mean), ω (constant), α (ARCH), β (GARCH)
    mu <- theta[1]                                    # Mean parameter (unconstrained)
    omega <- exp(theta[2])                            # Constant term (ω > 0)
    alpha <- 1 / (1 + exp(-theta[3]))                 # ARCH parameter (α ∈ (0,1))
    beta_raw <- 1 / (1 + exp(-theta[4]))              # Raw GARCH parameter (β_raw ∈ (0,1))
    beta <- (1 - 1e-4) * (1 - alpha) * beta_raw      # Constrained β ensuring α + β < 1
    
    return(list(
      mu = mu,
      omega = omega,
      alpha = alpha,
      beta = beta,
      par_constrained = c(mu = mu, omega = omega, alpha = alpha, beta = beta),
      par_unconstrained = theta
    ))
  } else if (model_type == "gjrGARCH") {
    # GJR-GARCH parameter transformation for leverage effects
    # Parameters: μ (mean), ω (constant), α (ARCH), γ (leverage), β (GARCH)
    mu <- theta[1]                                    # Mean parameter
    omega <- exp(theta[2])                            # Constant term (ω > 0)
    alpha <- 1 / (1 + exp(-theta[3]))                 # ARCH parameter (α ∈ (0,1))
    gamma <- theta[4]                                 # Leverage parameter (unconstrained)
    beta_raw <- 1 / (1 + exp(-theta[5]))              # Raw GARCH parameter
    beta <- (1 - 1e-4) * (1 - alpha) * beta_raw      # Constrained β ensuring stationarity
    
    return(list(
      mu = mu,
      omega = omega,
      alpha = alpha,
      gamma = gamma,
      beta = beta,
      par_constrained = c(mu = mu, omega = omega, alpha = alpha, gamma = gamma, beta = beta),
      par_unconstrained = theta
    ))
  } else if (model_type == "eGARCH") {
    # Exponential GARCH parameter transformation
    # Parameters: μ (mean), ω (constant), α (ARCH), γ (leverage), β (GARCH)
    mu <- theta[1]                                    # Mean parameter
    omega <- theta[2]                                 # Constant term (log-variance, unconstrained)
    alpha <- theta[3]                                 # ARCH parameter (unconstrained)
    gamma <- theta[4]                                 # Leverage parameter (unconstrained)
    beta <- 1 / (1 + exp(-theta[5]))                 # GARCH parameter (β ∈ (0,1))
    
    return(list(
      mu = mu,
      omega = omega,
      alpha = alpha,
      gamma = gamma,
      beta = beta,
      par_constrained = c(mu = mu, omega = omega, alpha = alpha, gamma = gamma, beta = beta),
      par_unconstrained = theta
    ))
  } else if (model_type == "TGARCH") {
    # Threshold GARCH parameter transformation
    # Parameters: μ (mean), ω (constant), α (ARCH), η (threshold), β (GARCH)
    mu <- theta[1]                                    # Mean parameter
    omega <- exp(theta[2])                            # Constant term (ω > 0)
    alpha <- 1 / (1 + exp(-theta[3]))                 # ARCH parameter (α ∈ (0,1))
    eta <- theta[4]                                   # Threshold parameter (unconstrained)
    beta <- 1 / (1 + exp(-theta[5]))                 # GARCH parameter (β ∈ (0,1))
    
    return(list(
      mu = mu,
      omega = omega,
      alpha = alpha,
      eta = eta,
      beta = beta,
      par_constrained = c(mu = mu, omega = omega, alpha = alpha, eta = eta, beta = beta),
      par_unconstrained = theta
    ))
  }
}

# Distribution Log-Likelihood Functions
# Compute log-likelihood contributions for different error distributions

dnorm_ll <- function(z) {
  # Standard normal distribution log-likelihood
  # Returns the log-density of a standard normal random variable
  -0.5 * (log(2 * pi) + z^2)
}

dt_ll <- function(z, nu) {
  # Student-t distribution log-likelihood
  # Computes the log-density of a Student-t random variable with degrees of freedom nu
  if (nu <= 2) stop("Degrees of freedom must be greater than 2 for finite variance")
  lgamma((nu + 1) / 2) - lgamma(nu / 2) - 0.5 * log(pi * nu) - 
    ((nu + 1) / 2) * log(1 + z^2 / nu)
}

# =============================================================================
# GARCH MODEL IMPLEMENTATIONS
# =============================================================================

# Standard GARCH(1,1) Implementation
fit_sgarch_manual <- function(returns, distribution = "norm", ...) {
  # Standard GARCH(1,1) model implementation
  # Returns: fitted GARCH model with parameters and diagnostics
  
  n <- length(returns)
  
  # Initial parameter values (unconstrained)
  if (distribution == "norm") {
    theta_init <- c(mean(returns), log(var(returns)), 0, 0)
    n_params <- 4
  } else if (distribution == "std") {
    theta_init <- c(mean(returns), log(var(returns)), 0, 0, 5)
    n_params <- 5
  }
  
  # Log-likelihood function for sGARCH
  sgarch_ll <- function(theta) {
    par <- transform_params(theta, "sGARCH")
    mu <- par$mu
    omega <- par$omega
    alpha <- par$alpha
    beta <- par$beta
    
    # Initialize variance
    h <- rep(var(returns), n)
    z <- rep(0, n)
    
    # GARCH recursion
    for (t in 2:n) {
      z[t-1] <- (returns[t-1] - mu) / sqrt(h[t-1])
      h[t] <- omega + alpha * (returns[t-1] - mu)^2 + beta * h[t-1]
    }
    z[n] <- (returns[n] - mu) / sqrt(h[n])
    
    # Compute log-likelihood
    if (distribution == "norm") {
      ll <- sum(dnorm_ll(z))
    } else if (distribution == "std") {
      nu <- exp(theta[5]) + 2  # Ensure nu > 2
      ll <- sum(dt_ll(z, nu))
    }
    
    return(-ll)  # Return negative for minimization
  }
  
  # Optimize parameters
  opt_result <- optim(theta_init, sgarch_ll, method = "BFGS", hessian = TRUE)
  
  # Extract fitted parameters
  par_fitted <- transform_params(opt_result$par, "sGARCH")
  
  # Compute fitted values
  h_fitted <- rep(var(returns), n)
  z_fitted <- rep(0, n)
  
  for (t in 2:n) {
    z_fitted[t-1] <- (returns[t-1] - par_fitted$mu) / sqrt(h_fitted[t-1])
    h_fitted[t] <- par_fitted$omega + par_fitted$alpha * (returns[t-1] - par_fitted$mu)^2 + 
                   par_fitted$beta * h_fitted[t-1]
  }
  z_fitted[n] <- (returns[n] - par_fitted$mu) / sqrt(h_fitted[n])
  
  # Return fitted model
  list(
    model = "sGARCH",
    distribution = distribution,
    parameters = par_fitted$par_constrained,
    loglik = -opt_result$value,
    convergence = opt_result$convergence,
    hessian = opt_result$hessian,
    fitted_values = list(
      conditional_variance = h_fitted,
      standardized_residuals = z_fitted
    ),
    data = returns
  )
}

# GJR-GARCH Implementation
fit_gjr_manual <- function(returns, distribution = "norm", ...) {
  # GJR-GARCH model implementation with leverage effects
  # Returns: fitted GJR-GARCH model with parameters and diagnostics
  
  n <- length(returns)
  
  # Initial parameter values (unconstrained)
  if (distribution == "norm") {
    theta_init <- c(mean(returns), log(var(returns)), 0, 0, 0)
    n_params <- 5
  } else if (distribution == "std") {
    theta_init <- c(mean(returns), log(var(returns)), 0, 0, 0, 5)
    n_params <- 6
  }
  
  # Log-likelihood function for GJR-GARCH
  gjr_ll <- function(theta) {
    par <- transform_params(theta, "gjrGARCH")
    mu <- par$mu
    omega <- par$omega
    alpha <- par$alpha
    gamma <- par$gamma
    beta <- par$beta
    
    # Initialize variance
    h <- rep(var(returns), n)
    z <- rep(0, n)
    
    # GJR-GARCH recursion
    for (t in 2:n) {
      z[t-1] <- (returns[t-1] - mu) / sqrt(h[t-1])
      leverage <- ifelse(returns[t-1] - mu < 0, 1, 0)
      h[t] <- omega + alpha * (returns[t-1] - mu)^2 + 
              gamma * leverage * (returns[t-1] - mu)^2 + beta * h[t-1]
    }
    z[n] <- (returns[n] - mu) / sqrt(h[n])
    
    # Compute log-likelihood
    if (distribution == "norm") {
      ll <- sum(dnorm_ll(z))
    } else if (distribution == "std") {
      nu <- exp(theta[6]) + 2  # Ensure nu > 2
      ll <- sum(dt_ll(z, nu))
    }
    
    return(-ll)  # Return negative for minimization
  }
  
  # Optimize parameters
  opt_result <- optim(theta_init, gjr_ll, method = "BFGS", hessian = TRUE)
  
  # Extract fitted parameters
  par_fitted <- transform_params(opt_result$par, "gjrGARCH")
  
  # Compute fitted values
  h_fitted <- rep(var(returns), n)
  z_fitted <- rep(0, n)
  
  for (t in 2:n) {
    z_fitted[t-1] <- (returns[t-1] - par_fitted$mu) / sqrt(h_fitted[t-1])
    leverage <- ifelse(returns[t-1] - par_fitted$mu < 0, 1, 0)
    h_fitted[t] <- par_fitted$omega + par_fitted$alpha * (returns[t-1] - par_fitted$mu)^2 + 
                   par_fitted$gamma * leverage * (returns[t-1] - par_fitted$mu)^2 + 
                   par_fitted$beta * h_fitted[t-1]
  }
  z_fitted[n] <- (returns[n] - par_fitted$mu) / sqrt(h_fitted[n])
  
  # Return fitted model
  list(
    model = "gjrGARCH",
    distribution = distribution,
    parameters = par_fitted$par_constrained,
    loglik = -opt_result$value,
    convergence = opt_result$convergence,
    hessian = opt_result$hessian,
    fitted_values = list(
      conditional_variance = h_fitted,
      standardized_residuals = z_fitted
    ),
    data = returns
  )
}

# Exponential GARCH Implementation
fit_egarch_manual <- function(returns, distribution = "norm", ...) {
  # Exponential GARCH model implementation
  # Returns: fitted EGARCH model with parameters and diagnostics
  
  n <- length(returns)
  
  # Initial parameter values (unconstrained)
  if (distribution == "norm") {
    theta_init <- c(mean(returns), log(var(returns)), 0, 0, 0)
    n_params <- 5
  } else if (distribution == "std") {
    theta_init <- c(mean(returns), log(var(returns)), 0, 0, 0, 5)
    n_params <- 6
  }
  
  # Log-likelihood function for EGARCH
  egarch_ll <- function(theta) {
    par <- transform_params(theta, "eGARCH")
    mu <- par$mu
    omega <- par$omega
    alpha <- par$alpha
    gamma <- par$gamma
    beta <- par$beta
    
    # Initialize log-variance
    log_h <- rep(log(var(returns)), n)
    z <- rep(0, n)
    
    # EGARCH recursion
    for (t in 2:n) {
      z[t-1] <- (returns[t-1] - mu) / sqrt(exp(log_h[t-1]))
      abs_z <- abs(z[t-1])
      sign_z <- sign(z[t-1])
      log_h[t] <- omega + alpha * abs_z + gamma * sign_z + beta * log_h[t-1]
    }
    z[n] <- (returns[n] - mu) / sqrt(exp(log_h[n]))
    
    # Compute log-likelihood
    if (distribution == "norm") {
      ll <- sum(dnorm_ll(z))
    } else if (distribution == "std") {
      nu <- exp(theta[6]) + 2  # Ensure nu > 2
      ll <- sum(dt_ll(z, nu))
    }
    
    return(-ll)  # Return negative for minimization
  }
  
  # Optimize parameters
  opt_result <- optim(theta_init, egarch_ll, method = "BFGS", hessian = TRUE)
  
  # Extract fitted parameters
  par_fitted <- transform_params(opt_result$par, "eGARCH")
  
  # Compute fitted values
  log_h_fitted <- rep(log(var(returns)), n)
  z_fitted <- rep(0, n)
  
  for (t in 2:n) {
    z_fitted[t-1] <- (returns[t-1] - par_fitted$mu) / sqrt(exp(log_h_fitted[t-1]))
    abs_z <- abs(z_fitted[t-1])
    sign_z <- sign(z_fitted[t-1])
    log_h_fitted[t] <- par_fitted$omega + par_fitted$alpha * abs_z + 
                       par_fitted$gamma * sign_z + par_fitted$beta * log_h_fitted[t-1]
  }
  z_fitted[n] <- (returns[n] - par_fitted$mu) / sqrt(exp(log_h_fitted[n]))
  
  # Return fitted model
  list(
    model = "eGARCH",
    distribution = distribution,
    parameters = par_fitted$par_constrained,
    loglik = -opt_result$value,
    convergence = opt_result$convergence,
    hessian = opt_result$hessian,
    fitted_values = list(
      conditional_variance = exp(log_h_fitted),
      standardized_residuals = z_fitted
    ),
    data = returns
  )
}

# Threshold GARCH Implementation
fit_tgarch_manual <- function(returns, distribution = "norm", ...) {
  # Threshold GARCH model implementation
  # Returns: fitted TGARCH model with parameters and diagnostics
  
  n <- length(returns)
  
  # Initial parameter values (unconstrained)
  if (distribution == "norm") {
    theta_init <- c(mean(returns), log(var(returns)), 0, 0, 0)
    n_params <- 5
  } else if (distribution == "std") {
    theta_init <- c(mean(returns), log(var(returns)), 0, 0, 0, 5)
    n_params <- 6
  }
  
  # Log-likelihood function for TGARCH
  tgarch_ll <- function(theta) {
    par <- transform_params(theta, "TGARCH")
    mu <- par$mu
    omega <- par$omega
    alpha <- par$alpha
    eta <- par$eta
    beta <- par$beta
    
    # Initialize variance
    h <- rep(var(returns), n)
    z <- rep(0, n)
    
    # TGARCH recursion
    for (t in 2:n) {
      z[t-1] <- (returns[t-1] - mu) / sqrt(h[t-1])
      threshold_effect <- ifelse(returns[t-1] - mu > eta, 1, 0)
      h[t] <- omega + alpha * (returns[t-1] - mu)^2 + 
              threshold_effect * (returns[t-1] - mu)^2 + beta * h[t-1]
    }
    z[n] <- (returns[n] - mu) / sqrt(h[n])
    
    # Compute log-likelihood
    if (distribution == "norm") {
      ll <- sum(dnorm_ll(z))
    } else if (distribution == "std") {
      nu <- exp(theta[6]) + 2  # Ensure nu > 2
      ll <- sum(dt_ll(z, nu))
    }
    
    return(-ll)  # Return negative for minimization
  }
  
  # Optimize parameters
  opt_result <- optim(theta_init, tgarch_ll, method = "BFGS", hessian = TRUE)
  
  # Extract fitted parameters
  par_fitted <- transform_params(opt_result$par, "TGARCH")
  
  # Compute fitted values
  h_fitted <- rep(var(returns), n)
  z_fitted <- rep(0, n)
  
  for (t in 2:n) {
    z_fitted[t-1] <- (returns[t-1] - par_fitted$mu) / sqrt(h_fitted[t-1])
    threshold_effect <- ifelse(returns[t-1] - par_fitted$mu > par_fitted$eta, 1, 0)
    h_fitted[t] <- par_fitted$omega + par_fitted$alpha * (returns[t-1] - par_fitted$mu)^2 + 
                   threshold_effect * (returns[t-1] - par_fitted$mu)^2 + 
                   par_fitted$beta * h_fitted[t-1]
  }
  z_fitted[n] <- (returns[n] - par_fitted$mu) / sqrt(h_fitted[n])
  
  # Return fitted model
  list(
    model = "TGARCH",
    distribution = distribution,
    parameters = par_fitted$par_constrained,
    loglik = -opt_result$value,
    convergence = opt_result$convergence,
    hessian = opt_result$hessian,
    fitted_values = list(
      conditional_variance = h_fitted,
      standardized_residuals = z_fitted
    ),
    data = returns
  )
}

# =============================================================================
# FORECASTING FUNCTIONS
# =============================================================================

# Manual GARCH forecasting
forecast_manual <- function(fitted_model, n_ahead = 10, n_sim = 1000) {
  # Generate forecasts from manually fitted GARCH models
  # Returns: forecasted conditional variances and returns
  
  model_type <- fitted_model$model
  params <- fitted_model$parameters
  last_variance <- tail(fitted_model$fitted_values$conditional_variance, 1)
  last_return <- tail(fitted_model$data, 1)
  
  # Initialize forecast arrays
  variance_forecast <- numeric(n_ahead)
  return_forecast <- matrix(0, n_sim, n_ahead)
  
  # Generate forecasts based on model type
  if (model_type == "sGARCH") {
    mu <- params["mu"]
    omega <- params["omega"]
    alpha <- params["alpha"]
    beta <- params["beta"]
    
    # Variance forecast
    for (h in 1:n_ahead) {
      if (h == 1) {
        variance_forecast[h] <- omega + alpha * (last_return - mu)^2 + beta * last_variance
      } else {
        variance_forecast[h] <- omega + (alpha + beta) * variance_forecast[h-1]
      }
    }
    
    # Return forecast (simulation)
    for (sim in 1:n_sim) {
      for (h in 1:n_ahead) {
        return_forecast[sim, h] <- rnorm(1, mu, sqrt(variance_forecast[h]))
      }
    }
    
  } else if (model_type == "gjrGARCH") {
    mu <- params["mu"]
    omega <- params["omega"]
    alpha <- params["alpha"]
    gamma <- params["gamma"]
    beta <- params["beta"]
    
    # Variance forecast (assuming positive shock for simplicity)
    for (h in 1:n_ahead) {
      if (h == 1) {
        leverage <- ifelse(last_return - mu < 0, 1, 0)
        variance_forecast[h] <- omega + alpha * (last_return - mu)^2 + 
                               gamma * leverage * (last_return - mu)^2 + beta * last_variance
      } else {
        variance_forecast[h] <- omega + (alpha + 0.5 * gamma + beta) * variance_forecast[h-1]
      }
    }
    
    # Return forecast (simulation)
    for (sim in 1:n_sim) {
      for (h in 1:n_ahead) {
        return_forecast[sim, h] <- rnorm(1, mu, sqrt(variance_forecast[h]))
      }
    }
    
  } else if (model_type == "eGARCH") {
    mu <- params["mu"]
    omega <- params["omega"]
    alpha <- params["alpha"]
    gamma <- params["gamma"]
    beta <- params["beta"]
    
    # Log-variance forecast
    log_variance_forecast <- numeric(n_ahead)
    for (h in 1:n_ahead) {
      if (h == 1) {
        z_last <- (last_return - mu) / sqrt(last_variance)
        abs_z <- abs(z_last)
        sign_z <- sign(z_last)
        log_variance_forecast[h] <- omega + alpha * abs_z + gamma * sign_z + beta * log(last_variance)
      } else {
        log_variance_forecast[h] <- omega + beta * log_variance_forecast[h-1]
      }
      variance_forecast[h] <- exp(log_variance_forecast[h])
    }
    
    # Return forecast (simulation)
    for (sim in 1:n_sim) {
      for (h in 1:n_ahead) {
        return_forecast[sim, h] <- rnorm(1, mu, sqrt(variance_forecast[h]))
      }
    }
    
  } else if (model_type == "TGARCH") {
    mu <- params["mu"]
    omega <- params["omega"]
    alpha <- params["alpha"]
    eta <- params["eta"]
    beta <- params["beta"]
    
    # Variance forecast (assuming above threshold for simplicity)
    for (h in 1:n_ahead) {
      if (h == 1) {
        threshold_effect <- ifelse(last_return - mu > eta, 1, 0)
        variance_forecast[h] <- omega + alpha * (last_return - mu)^2 + 
                               threshold_effect * (last_return - mu)^2 + beta * last_variance
      } else {
        variance_forecast[h] <- omega + (alpha + 0.5 + beta) * variance_forecast[h-1]
      }
    }
    
    # Return forecast (simulation)
    for (sim in 1:n_sim) {
      for (h in 1:n_ahead) {
        return_forecast[sim, h] <- rnorm(1, mu, sqrt(variance_forecast[h]))
      }
    }
  }
  
  # Return forecast results
  list(
    model = model_type,
    n_ahead = n_ahead,
    n_sim = n_sim,
    variance_forecast = variance_forecast,
    return_forecast = return_forecast,
    forecast_summary = list(
      mean_variance = mean(variance_forecast),
      mean_return = colMeans(return_forecast),
      var_95 = apply(return_forecast, 2, quantile, 0.05),
      var_99 = apply(return_forecast, 2, quantile, 0.01)
    )
  )
}

# =============================================================================
# UNIFIED INTERFACE
# =============================================================================

# Main manual GARCH interface
manual_garch <- list(
  # Fit functions
  fit_sgarch = fit_sgarch_manual,
  fit_gjr = fit_gjr_manual,
  fit_egarch = fit_egarch_manual,
  fit_tgarch = fit_tgarch_manual,
  
  # Forecast function
  forecast = forecast_manual,
  
  # Utility functions
  transform_params = transform_params,
  dnorm_ll = dnorm_ll,
  dt_ll = dt_ll,
  
  # Unified fit function
  fit = function(returns, model = "sGARCH", distribution = "norm", ...) {
    switch(model,
           "sGARCH" = fit_sgarch_manual(returns, distribution, ...),
           "gjrGARCH" = fit_gjr_manual(returns, distribution, ...),
           "eGARCH" = fit_egarch_manual(returns, distribution, ...),
           "TGARCH" = fit_tgarch_manual(returns, distribution, ...),
           stop("Unknown model type: ", model))
  }
)

# Export the unified interface
return(manual_garch)

