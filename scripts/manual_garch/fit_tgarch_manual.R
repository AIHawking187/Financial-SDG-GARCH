# Manual TGARCH(1,1) Fitter
# Implements: σ_t = ω + α |ε_{t-1}| + η I(ε_{t-1}<0)|ε_{t-1}| + β σ_{t-1}

source("scripts/manual_garch/manual_garch_core.R")

fit_tgarch_manual <- function(returns, dist = c("norm", "std"), init = NULL) {
  dist <- match.arg(dist)
  n <- length(returns)
  
  # Initialize parameters if not provided
  if (is.null(init)) {
    sample_var <- var(returns, na.rm = TRUE)
    sample_mean <- mean(returns, na.rm = TRUE)
    
    if (dist == "norm") {
      # 5 parameters: μ, ω, α, η, β
      init <- c(
        mu = sample_mean,
        omega = log(sample_var * 0.1),
        alpha = 0,
        eta = 0,  # asymmetry parameter
        beta = 0
      )
    } else if (dist == "std") {
      # 6 parameters: μ, ω, α, η, β, ν
      init <- c(
        mu = sample_mean,
        omega = log(sample_var * 0.1),
        alpha = 0,
        eta = 0,
        beta = 0,
        nu = log(5)
      )
    }
  }
  
  # Negative log-likelihood function
  neg_ll <- function(theta) {
    tryCatch({
      # Transform parameters
      if (dist == "norm") {
        params <- transform_params(theta, "TGARCH")
        mu <- params$mu
        omega <- params$omega
        alpha <- params$alpha
        eta <- params$eta
        beta <- params$beta
        
        # Initialize variance recursion
        sigma <- rep(sqrt(sample_var), n)
        residuals <- returns - mu
        
        # Variance recursion with burn-in
        for (t in 2:n) {
          indicator <- ifelse(residuals[t-1] < 0, 1, 0)
          sigma[t] <- omega + alpha * abs(residuals[t-1]) + eta * indicator * abs(residuals[t-1]) + beta * sigma[t-1]
          sigma[t] <- pmax(sigma[t], safe_sqrt(var_floor))
        }
        
        # Compute log-likelihood
        ll <- compute_ll_normal(returns, sigma, mu)
        return(-ll)
        
      } else if (dist == "std") {
        # Extract parameters
        mu <- theta[1]
        omega <- exp(theta[2])
        alpha <- 1 / (1 + exp(-theta[3]))
        eta <- theta[4]  # asymmetry parameter
        beta <- 1 / (1 + exp(-theta[5]))
        nu <- 2 + exp(theta[6])
        
        # Initialize variance recursion
        sigma <- rep(sqrt(sample_var), n)
        residuals <- returns - mu
        
        # Variance recursion with burn-in
        for (t in 2:n) {
          indicator <- ifelse(residuals[t-1] < 0, 1, 0)
          sigma[t] <- omega + alpha * abs(residuals[t-1]) + eta * indicator * abs(residuals[t-1]) + beta * sigma[t-1]
          sigma[t] <- pmax(sigma[t], safe_sqrt(var_floor))
        }
        
        # Compute log-likelihood
        ll <- compute_ll_student_t(returns, sigma, mu, nu)
        return(-ll)
      }
    }, error = function(e) {
      return(1e10)
    })
  }
  
  # Optimize
  opt_result <- optim(
    par = init,
    fn = neg_ll,
    method = "BFGS",  # Use BFGS for better stability
    control = list(maxit = 1000)
  )
  
  # Check convergence
  if (opt_result$convergence != 0) {
    warning("Optimization may not have converged. Convergence code: ", opt_result$convergence)
  }
  
  # Extract final parameters and compute fitted values
  if (dist == "norm") {
    params <- transform_params(opt_result$par, "TGARCH")
    mu <- params$mu
    omega <- params$omega
    alpha <- params$alpha
    eta <- params$eta
    beta <- params$beta
    
    # Compute final sigma and residuals
    sigma <- rep(sqrt(sample_var), n)
    residuals <- returns - mu
    
    for (t in 2:n) {
      indicator <- ifelse(residuals[t-1] < 0, 1, 0)
      sigma[t] <- omega + alpha * abs(residuals[t-1]) + eta * indicator * abs(residuals[t-1]) + beta * sigma[t-1]
      sigma[t] <- pmax(sigma[t], safe_sqrt(var_floor))
    }
    
    std_residuals <- residuals / sigma
    
    # Compute log-likelihood and information criteria
    ll <- -opt_result$value
    ic <- aic_bic_from_ll(ll, 5, n)  # 5 parameters
    
    # Create return object
    result <- list(
      par_constrained = params$par_constrained,
      par_unconstrained = opt_result$par,
      loglik = ll,
      aic = ic$aic,
      bic = ic$bic,
      convergence = opt_result$convergence == 0,
      sigma = sigma,
      residuals = residuals,
      std_residuals = std_residuals,
      fitted = rep(mu, n),
      coef = params$par_constrained,
      model_type = "TGARCH",
      distribution = dist
    )
    
  } else if (dist == "std") {
    # Extract parameters
    mu <- opt_result$par[1]
    omega <- exp(opt_result$par[2])
    alpha <- 1 / (1 + exp(-opt_result$par[3]))
    eta <- opt_result$par[4]
    beta <- 1 / (1 + exp(-opt_result$par[5]))
    nu <- 2 + exp(opt_result$par[6])
    
    # Compute final sigma and residuals
    sigma <- rep(sqrt(sample_var), n)
    residuals <- returns - mu
    
    for (t in 2:n) {
      indicator <- ifelse(residuals[t-1] < 0, 1, 0)
      sigma[t] <- omega + alpha * abs(residuals[t-1]) + eta * indicator * abs(residuals[t-1]) + beta * sigma[t-1]
      sigma[t] <- pmax(sigma[t], safe_sqrt(var_floor))
    }
    
    std_residuals <- residuals / sigma
    
    # Compute log-likelihood and information criteria
    ll <- -opt_result$value
    ic <- aic_bic_from_ll(ll, 6, n)  # 6 parameters
    
    # Create return object
    result <- list(
      par_constrained = c(mu = mu, omega = omega, alpha = alpha, eta = eta, beta = beta, nu = nu),
      par_unconstrained = opt_result$par,
      loglik = ll,
      aic = ic$aic,
      bic = ic$bic,
      convergence = opt_result$convergence == 0,
      sigma = sigma,
      residuals = residuals,
      std_residuals = std_residuals,
      fitted = rep(mu, n),
      coef = c(mu = mu, omega = omega, alpha = alpha, eta = eta, beta = beta, nu = nu),
      model_type = "TGARCH",
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
    sigma_forecast[1] <- forecast_one_step(result, last_sigma, last_residual, "TGARCH")
    
    for (i in 2:h) {
      sigma_forecast[i] <- forecast_one_step(result, sigma_forecast[i-1], 0, "TGARCH")
    }
    
    return(list(
      sigma = sigma_forecast,
      mean = rep(result$coef["mu"], h)
    ))
  }
  
  return(result)
}
