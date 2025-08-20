# Manual sGARCH(1,1) Fitter
# Implements: r_t = μ + ε_t, ε_t = σ_t z_t
#            σ_t^2 = ω + α ε_{t-1}^2 + β σ_{t-1}^2

source("scripts/manual_garch/manual_garch_core.R")

fit_sgarch_manual <- function(returns, dist = c("norm", "std"), init = NULL) {
  dist <- match.arg(dist)
  n <- length(returns)
  
  # Initialize parameters if not provided
  if (is.null(init)) {
    sample_var <- var(returns, na.rm = TRUE)
    sample_mean <- mean(returns, na.rm = TRUE)
    
    if (dist == "norm") {
      # 4 parameters: μ, ω, α, β
      init <- c(
        mu = sample_mean,
        omega = log(sample_var * 0.1),  # ω ≈ var * (1-α-β)
        alpha = 0,  # logit(0) = -Inf, so use 0
        beta = 0    # logit(0) = -Inf, so use 0
      )
    } else if (dist == "std") {
      # 5 parameters: μ, ω, α, β, ν
      init <- c(
        mu = sample_mean,
        omega = log(sample_var * 0.1),
        alpha = 0,
        beta = 0,
        nu = log(5)  # ν = 2 + exp(log(5)) = 7
      )
    }
  }
  
  # Negative log-likelihood function
  neg_ll <- function(theta) {
    tryCatch({
      # Transform parameters
      if (dist == "norm") {
        params <- transform_params(theta, "sGARCH")
        mu <- params$mu
        omega <- params$omega
        alpha <- params$alpha
        beta <- params$beta
        
        # Initialize variance recursion
        sigma2 <- rep(sample_var, n)
        residuals <- returns - mu
        
        # Variance recursion with burn-in
        for (t in 2:n) {
          sigma2[t] <- omega + alpha * residuals[t-1]^2 + beta * sigma2[t-1]
          sigma2[t] <- pmax(sigma2[t], var_floor)
        }
        
        sigma <- sqrt(sigma2)
        
        # Compute log-likelihood
        ll <- compute_ll_normal(returns, sigma, mu)
        return(-ll)
        
      } else if (dist == "std") {
        # Extract parameters
        mu <- theta[1]
        omega <- exp(theta[2])
        alpha <- 1 / (1 + exp(-theta[3]))
        beta_raw <- 1 / (1 + exp(-theta[4]))
        beta <- (1 - 1e-4) * (1 - alpha) * beta_raw
        nu <- 2 + exp(theta[5])  # ν > 2
        
        # Initialize variance recursion
        sigma2 <- rep(sample_var, n)
        residuals <- returns - mu
        
        # Variance recursion with burn-in
        for (t in 2:n) {
          sigma2[t] <- omega + alpha * residuals[t-1]^2 + beta * sigma2[t-1]
          sigma2[t] <- pmax(sigma2[t], var_floor)
        }
        
        sigma <- sqrt(sigma2)
        
        # Compute log-likelihood
        ll <- compute_ll_student_t(returns, sigma, mu, nu)
        return(-ll)
      }
    }, error = function(e) {
      return(1e10)  # Return large value for failed optimization
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
    params <- transform_params(opt_result$par, "sGARCH")
    mu <- params$mu
    omega <- params$omega
    alpha <- params$alpha
    beta <- params$beta
    
    # Compute final sigma and residuals
    sigma2 <- rep(sample_var, n)
    residuals <- returns - mu
    
    for (t in 2:n) {
      sigma2[t] <- omega + alpha * residuals[t-1]^2 + beta * sigma2[t-1]
      sigma2[t] <- pmax(sigma2[t], var_floor)
    }
    
    sigma <- sqrt(sigma2)
    std_residuals <- residuals / sigma
    
    # Compute log-likelihood and information criteria
    ll <- -opt_result$value
    ic <- aic_bic_from_ll(ll, 4, n)  # 4 parameters
    
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
      model_type = "sGARCH",
      distribution = dist
    )
    
  } else if (dist == "std") {
    # Extract parameters
    mu <- opt_result$par[1]
    omega <- exp(opt_result$par[2])
    alpha <- 1 / (1 + exp(-opt_result$par[3]))
    beta_raw <- 1 / (1 + exp(-opt_result$par[4]))
    beta <- (1 - 1e-4) * (1 - alpha) * beta_raw
    nu <- 2 + exp(opt_result$par[5])
    
    # Compute final sigma and residuals
    sigma2 <- rep(sample_var, n)
    residuals <- returns - mu
    
    for (t in 2:n) {
      sigma2[t] <- omega + alpha * residuals[t-1]^2 + beta * sigma2[t-1]
      sigma2[t] <- pmax(sigma2[t], var_floor)
    }
    
    sigma <- sqrt(sigma2)
    std_residuals <- residuals / sigma
    
    # Compute log-likelihood and information criteria
    ll <- -opt_result$value
    ic <- aic_bic_from_ll(ll, 5, n)  # 5 parameters
    
    # Create return object
    result <- list(
      par_constrained = c(mu = mu, omega = omega, alpha = alpha, beta = beta, nu = nu),
      par_unconstrained = opt_result$par,
      loglik = ll,
      aic = ic$aic,
      bic = ic$bic,
      convergence = opt_result$convergence == 0,
      sigma = sigma,
      residuals = residuals,
      std_residuals = std_residuals,
      fitted = rep(mu, n),
      coef = c(mu = mu, omega = omega, alpha = alpha, beta = beta, nu = nu),
      model_type = "sGARCH",
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
    sigma_forecast[1] <- forecast_one_step(result, last_sigma, last_residual, "sGARCH")
    
    for (i in 2:h) {
      sigma_forecast[i] <- forecast_one_step(result, sigma_forecast[i-1], 0, "sGARCH")
    }
    
    return(list(
      sigma = sigma_forecast,
      mean = rep(result$coef["mu"], h)
    ))
  }
  
  return(result)
}
