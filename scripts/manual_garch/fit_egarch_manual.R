# Manual eGARCH(1,1) Fitter
# Implements: log(σ_t^2) = ω + β log(σ_{t-1}^2) + α(|z_{t-1}| - E|z|) + γ z_{t-1}

source("scripts/manual_garch/manual_garch_core.R")

fit_egarch_manual <- function(returns, dist = c("norm", "std"), init = NULL) {
  dist <- match.arg(dist)
  n <- length(returns)
  
  # Initialize parameters if not provided
  if (is.null(init)) {
    sample_var <- var(returns, na.rm = TRUE)
    sample_mean <- mean(returns, na.rm = TRUE)
    
    if (dist == "norm") {
      # 5 parameters: μ, ω, α, γ, β
      init <- c(
        mu = sample_mean,
        omega = log(sample_var),  # no transform for log-variance
        alpha = 0.05,  # Very small positive value
        gamma = 0.02, # Very small value
        beta = 0.9    # High persistence
      )
    } else if (dist == "std") {
      # 6 parameters: μ, ω, α, γ, β, ν
      init <- c(
        mu = sample_mean,
        omega = log(sample_var),
        alpha = 0.05,  # Very small positive value
        gamma = 0.02, # Very small value
        beta = 0.9,   # High persistence
        nu = log(5)
      )
    }
  }
  
  # Negative log-likelihood function with better error handling
  neg_ll <- function(theta) {
    tryCatch({
      if (dist == "norm") {
        # Extract parameters directly (no transform for eGARCH)
        mu <- theta[1]
        omega <- theta[2]
        alpha <- theta[3]
        gamma <- theta[4]
        beta <- 1 / (1 + exp(-theta[5]))  # β ∈ (0,1)
        
        # Initialize variance recursion
        log_sigma2 <- rep(log(sample_var), n)
        residuals <- returns - mu
        
        # E|z| for normal distribution
        E_z <- sqrt(2/pi)
        
        # Variance recursion with burn-in and better numerical stability
        for (t in 2:n) {
          sigma_prev <- exp(log_sigma2[t-1]/2)
          if (sigma_prev < 1e-10) sigma_prev <- 1e-10  # Safety floor
          
          z_prev <- residuals[t-1] / sigma_prev
          log_sigma2[t] <- omega + beta * log_sigma2[t-1] + alpha * (abs(z_prev) - E_z) + gamma * z_prev
          
          # Ensure finite values with safety bounds
          if (!is.finite(log_sigma2[t])) {
            log_sigma2[t] <- log(sample_var)
          }
          if (log_sigma2[t] < -20) log_sigma2[t] <- -20  # Lower bound
          if (log_sigma2[t] > 20) log_sigma2[t] <- 20    # Upper bound
        }
        
        sigma <- exp(log_sigma2/2)
        
        # Compute log-likelihood with safety checks
        ll <- compute_ll_normal(returns, sigma, mu)
        if (!is.finite(ll)) {
          return(1e10)  # Return large value for non-finite likelihood
        }
        return(-ll)
        
      } else if (dist == "std") {
        # Extract parameters
        mu <- theta[1]
        omega <- theta[2]
        alpha <- theta[3]
        gamma <- theta[4]
        beta <- 1 / (1 + exp(-theta[5]))  # β ∈ (0,1)
        nu <- 2 + exp(theta[6])
        
        # Initialize variance recursion
        log_sigma2 <- rep(log(sample_var), n)
        residuals <- returns - mu
        
        # E|z| for Student-t distribution
        E_z <- E_abs_t(nu)
        
        # Variance recursion with burn-in and better numerical stability
        for (t in 2:n) {
          sigma_prev <- exp(log_sigma2[t-1]/2)
          if (sigma_prev < 1e-10) sigma_prev <- 1e-10  # Safety floor
          
          z_prev <- residuals[t-1] / sigma_prev
          log_sigma2[t] <- omega + beta * log_sigma2[t-1] + alpha * (abs(z_prev) - E_z) + gamma * z_prev
          
          # Ensure finite values with safety bounds
          if (!is.finite(log_sigma2[t])) {
            log_sigma2[t] <- log(sample_var)
          }
          if (log_sigma2[t] < -20) log_sigma2[t] <- -20  # Lower bound
          if (log_sigma2[t] > 20) log_sigma2[t] <- 20    # Upper bound
        }
        
        sigma <- exp(log_sigma2/2)
        
        # Compute log-likelihood with safety checks
        ll <- compute_ll_student_t(returns, sigma, mu, nu)
        if (!is.finite(ll)) {
          return(1e10)  # Return large value for non-finite likelihood
        }
        return(-ll)
      }
    }, error = function(e) {
      return(1e10)
    })
  }
  
  # Try multiple optimization methods with different starting points
  best_result <- NULL
  best_value <- Inf
  
  # Method 1: L-BFGS-B with original starting point
  tryCatch({
    opt_result <- optim(
      par = init,
      fn = neg_ll,
      method = "L-BFGS-B",
      control = list(maxit = 500, factr = 1e8)  # More relaxed tolerance
    )
    if (opt_result$value < best_value) {
      best_result <- opt_result
      best_value <- opt_result$value
    }
  }, error = function(e) {
    # Continue to next method
  })
  
  # Method 2: Nelder-Mead if L-BFGS-B failed
  if (is.null(best_result)) {
    tryCatch({
      opt_result <- optim(
        par = init,
        fn = neg_ll,
        method = "Nelder-Mead",
        control = list(maxit = 1000)
      )
      if (opt_result$value < best_value) {
        best_result <- opt_result
        best_value <- opt_result$value
      }
    }, error = function(e) {
      # Continue to next method
    })
  }
  
  # Method 3: Use simple starting point if all else fails
  if (is.null(best_result)) {
    simple_init <- c(
      mu = mean(returns),
      omega = log(var(returns)),
      alpha = 0.01,
      gamma = 0.01,
      beta = 0.95
    )
    if (dist == "std") {
      simple_init <- c(simple_init, nu = log(5))
    }
    
    tryCatch({
      opt_result <- optim(
        par = simple_init,
        fn = neg_ll,
        method = "Nelder-Mead",
        control = list(maxit = 500)
      )
      if (opt_result$value < best_value) {
        best_result <- opt_result
        best_value <- opt_result$value
      }
    }, error = function(e) {
      # If all methods fail, create a basic result
      best_result <- list(
        par = simple_init,
        value = 1e6,
        convergence = 1
      )
    })
  }
  
  # Check convergence
  if (best_result$convergence != 0) {
    warning("Optimization may not have converged. Convergence code: ", best_result$convergence)
  }
  
  # Extract final parameters and compute fitted values
  if (dist == "norm") {
    # Extract parameters directly
    mu <- best_result$par[1]
    omega <- best_result$par[2]
    alpha <- best_result$par[3]
    gamma <- best_result$par[4]
    beta <- 1 / (1 + exp(-best_result$par[5]))
    
    # Compute final sigma and residuals
    log_sigma2 <- rep(log(sample_var), n)
    residuals <- returns - mu
    E_z <- sqrt(2/pi)
    
    for (t in 2:n) {
      sigma_prev <- exp(log_sigma2[t-1]/2)
      if (sigma_prev < 1e-10) sigma_prev <- 1e-10
      
      z_prev <- residuals[t-1] / sigma_prev
      log_sigma2[t] <- omega + beta * log_sigma2[t-1] + alpha * (abs(z_prev) - E_z) + gamma * z_prev
      
      if (!is.finite(log_sigma2[t])) {
        log_sigma2[t] <- log(sample_var)
      }
    }
    
    sigma <- exp(log_sigma2/2)
    std_residuals <- residuals / sigma
    
    # Compute log-likelihood and information criteria
    ll <- -best_result$value
    ic <- aic_bic_from_ll(ll, 5, n)  # 5 parameters
    
    # Create return object
    result <- list(
      par_constrained = c(mu = mu, omega = omega, alpha = alpha, gamma = gamma, beta = beta),
      par_unconstrained = best_result$par,
      loglik = ll,
      aic = ic$aic,
      bic = ic$bic,
      convergence = best_result$convergence == 0,
      sigma = sigma,
      residuals = residuals,
      std_residuals = std_residuals,
      fitted = rep(mu, n),
      coef = c(mu = mu, omega = omega, alpha = alpha, gamma = gamma, beta = beta),
      model_type = "eGARCH",
      distribution = dist
    )
    
  } else if (dist == "std") {
    # Extract parameters
    mu <- best_result$par[1]
    omega <- best_result$par[2]
    alpha <- best_result$par[3]
    gamma <- best_result$par[4]
    beta <- 1 / (1 + exp(-best_result$par[5]))
    nu <- 2 + exp(best_result$par[6])
    
    # Compute final sigma and residuals
    log_sigma2 <- rep(log(sample_var), n)
    residuals <- returns - mu
    E_z <- E_abs_t(nu)
    
    for (t in 2:n) {
      sigma_prev <- exp(log_sigma2[t-1]/2)
      if (sigma_prev < 1e-10) sigma_prev <- 1e-10
      
      z_prev <- residuals[t-1] / sigma_prev
      log_sigma2[t] <- omega + beta * log_sigma2[t-1] + alpha * (abs(z_prev) - E_z) + gamma * z_prev
      
      if (!is.finite(log_sigma2[t])) {
        log_sigma2[t] <- log(sample_var)
      }
    }
    
    sigma <- exp(log_sigma2/2)
    std_residuals <- residuals / sigma
    
    # Compute log-likelihood and information criteria
    ll <- -best_result$value
    ic <- aic_bic_from_ll(ll, 6, n)  # 6 parameters
    
    # Create return object
    result <- list(
      par_constrained = c(mu = mu, omega = omega, alpha = alpha, gamma = gamma, beta = beta, nu = nu),
      par_unconstrained = best_result$par,
      loglik = ll,
      aic = ic$aic,
      bic = ic$bic,
      convergence = best_result$convergence == 0,
      sigma = sigma,
      residuals = residuals,
      std_residuals = std_residuals,
      fitted = rep(mu, n),
      coef = c(mu = mu, omega = omega, alpha = alpha, gamma = gamma, beta = beta, nu = nu),
      model_type = "eGARCH",
      distribution = dist
    )
  }
  
  # Add predict function
  result$predict <- function(h) {
    # h-step ahead forecast
    if (h <= 0) stop("h must be positive")
    
    last_sigma <- tail(result$sigma, 1)
    last_residual <- tail(result$residuals, 1)
    
    sigma_forecast <- numeric(h)
    sigma_forecast[1] <- forecast_one_step(result, last_sigma, last_residual, "eGARCH")
    
    for (i in 2:h) {
      sigma_forecast[i] <- forecast_one_step(result, sigma_forecast[i-1], 0, "eGARCH")
    }
    
    return(list(
      sigma = sigma_forecast,
      mean = rep(result$coef["mu"], h)
    ))
  }
  
  return(result)
}
