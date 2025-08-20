# Manual GARCH Core Utilities
# Shared utilities for manual GARCH implementation

# Parameter transforms (unconstrained -> constrained)
transform_params <- function(theta, model_type) {
  if (model_type == "sGARCH") {
    # sGARCH: μ, ω, α, β
    mu <- theta[1]
    omega <- exp(theta[2])  # ω > 0
    alpha <- 1 / (1 + exp(-theta[3]))  # α ∈ (0,1)
    beta_raw <- 1 / (1 + exp(-theta[4]))  # β_raw ∈ (0,1)
    beta <- (1 - 1e-4) * (1 - alpha) * beta_raw  # ensures α + β < 1
    
    return(list(
      mu = mu,
      omega = omega,
      alpha = alpha,
      beta = beta,
      par_constrained = c(mu = mu, omega = omega, alpha = alpha, beta = beta),
      par_unconstrained = theta
    ))
  } else if (model_type == "gjrGARCH") {
    # GJR-GARCH: μ, ω, α, γ, β
    mu <- theta[1]
    omega <- exp(theta[2])
    alpha <- 1 / (1 + exp(-theta[3]))
    gamma <- theta[4]  # asymmetry parameter (no transform)
    beta_raw <- 1 / (1 + exp(-theta[5]))
    beta <- (1 - 1e-4) * (1 - alpha) * beta_raw
    
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
    # eGARCH: μ, ω, α, γ, β
    mu <- theta[1]
    omega <- theta[2]  # no transform for log-variance
    alpha <- theta[3]
    gamma <- theta[4]
    beta <- 1 / (1 + exp(-theta[5]))  # β ∈ (0,1)
    
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
    # TGARCH: μ, ω, α, η, β
    mu <- theta[1]
    omega <- exp(theta[2])
    alpha <- 1 / (1 + exp(-theta[3]))
    eta <- theta[4]  # asymmetry parameter
    beta <- 1 / (1 + exp(-theta[5]))
    
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

# Distribution log-pdfs
dnorm_ll <- function(z) {
  # Standard normal log-pdf
  -0.5 * (log(2 * pi) + z^2)
}

dt_ll <- function(z, nu) {
  # Student-t log-pdf
  if (nu <= 2) stop("nu must be > 2")
  lgamma((nu + 1) / 2) - lgamma(nu / 2) - 0.5 * log(pi * nu) - 
    ((nu + 1) / 2) * log(1 + z^2 / nu)
}

# Vectorized negative log-likelihood helpers
compute_ll_normal <- function(returns, sigma, mu) {
  # Normal distribution log-likelihood
  residuals <- returns - mu
  z <- residuals / sigma
  sum(dnorm_ll(z) - log(sigma))
}

compute_ll_student_t <- function(returns, sigma, mu, nu) {
  # Student-t distribution log-likelihood
  residuals <- returns - mu
  z <- residuals / sigma
  sum(dt_ll(z, nu) - log(sigma))
}

# AIC/BIC from log-likelihood
aic_bic_from_ll <- function(ll, k, n) {
  aic <- -2 * ll + 2 * k
  bic <- -2 * ll + k * log(n)
  return(list(aic = aic, bic = bic))
}

# Safe variance floor
var_floor <- 1e-12

# Safe recursion helpers
safe_sqrt <- function(x) {
  sqrt(pmax(x, var_floor))
}

safe_log <- function(x) {
  log(pmax(x, var_floor))
}

# Common forecast functions
forecast_one_step <- function(fit, last_sigma, last_residual, model_type) {
  # One-step ahead forecast
  if (model_type == "sGARCH") {
    # Find parameters (they have prefixes)
    omega_idx <- grep("omega", names(fit$coef))
    alpha_idx <- grep("alpha", names(fit$coef))
    beta_idx <- grep("beta", names(fit$coef))
    
    omega <- fit$coef[omega_idx[1]]
    alpha <- fit$coef[alpha_idx[1]]
    beta <- fit$coef[beta_idx[1]]
    sigma2_next <- omega + alpha * last_residual^2 + beta * last_sigma^2
    return(safe_sqrt(sigma2_next))
  } else if (model_type == "gjrGARCH") {
    omega_idx <- grep("omega", names(fit$coef))
    alpha_idx <- grep("alpha", names(fit$coef))
    gamma_idx <- grep("gamma", names(fit$coef))
    beta_idx <- grep("beta", names(fit$coef))
    
    omega <- fit$coef[omega_idx[1]]
    alpha <- fit$coef[alpha_idx[1]]
    gamma <- fit$coef[gamma_idx[1]]
    beta <- fit$coef[beta_idx[1]]
    indicator <- ifelse(last_residual < 0, 1, 0)
    sigma2_next <- omega + alpha * last_residual^2 + gamma * indicator * last_residual^2 + beta * last_sigma^2
    return(safe_sqrt(sigma2_next))
  } else if (model_type == "eGARCH") {
    omega_idx <- grep("omega", names(fit$coef))
    alpha_idx <- grep("alpha", names(fit$coef))
    gamma_idx <- grep("gamma", names(fit$coef))
    beta_idx <- grep("beta", names(fit$coef))
    
    omega <- fit$coef[omega_idx[1]]
    alpha <- fit$coef[alpha_idx[1]]
    gamma <- fit$coef[gamma_idx[1]]
    beta <- fit$coef[beta_idx[1]]
    z_last <- last_residual / last_sigma
    E_z <- sqrt(2/pi)  # E|z| for normal
    log_sigma2_next <- omega + beta * log(last_sigma^2) + alpha * (abs(z_last) - E_z) + gamma * z_last
    return(safe_sqrt(exp(log_sigma2_next)))
  } else if (model_type == "TGARCH") {
    omega_idx <- grep("omega", names(fit$coef))
    alpha_idx <- grep("alpha", names(fit$coef))
    eta_idx <- grep("eta", names(fit$coef))
    beta_idx <- grep("beta", names(fit$coef))
    
    omega <- fit$coef[omega_idx[1]]
    alpha <- fit$coef[alpha_idx[1]]
    eta <- fit$coef[eta_idx[1]]
    beta <- fit$coef[beta_idx[1]]
    indicator <- ifelse(last_residual < 0, 1, 0)
    sigma_next <- omega + alpha * abs(last_residual) + eta * indicator * abs(last_residual) + beta * last_sigma
    return(pmax(sigma_next, safe_sqrt(var_floor)))
  }
}

# E|z| for Student-t distribution
E_abs_t <- function(nu) {
  if (nu <= 2) stop("nu must be > 2")
  sqrt(nu/pi) * gamma((nu-1)/2) / gamma(nu/2)
}
