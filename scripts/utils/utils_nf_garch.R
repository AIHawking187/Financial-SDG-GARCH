# scripts/utils/utils_nf_garch.R
# Manual NF-GARCH simulator with safety floors and robust variance handling

.standardize_nf <- function(z) {
  z <- as.numeric(z)
  z <- z - mean(z, na.rm = TRUE)
  sdv <- sd(z, na.rm = TRUE)
  if (!is.finite(sdv) || sdv == 0) stop("NF shocks have zero/invalid variance after centering.")
  z / sdv
}

# ---- Model recursions with safety floors ----

.sim_sGARCH <- function(par, sigma0, eps0, z, mu=0, var_floor=1e-12) {
  omega <- par["omega"]; alpha <- par["alpha1"]; beta <- par["beta1"]
  n <- length(z); h <- numeric(n); eps <- numeric(n); r <- numeric(n)
  h_prev <- max(as.numeric(sigma0)^2, var_floor); eps_prev <- as.numeric(eps0)
  for (t in 1:n) {
    h_t <- max(omega + alpha * (eps_prev^2) + beta * h_prev, var_floor)
    eps_t <- sqrt(h_t) * z[t]
    r[t]  <- mu + eps_t
    h_prev <- h_t; eps_prev <- eps_t
    h[t] <- h_t; eps[t] <- eps_t
  }
  list(returns = r, sigma = sqrt(h), eps = eps)
}

.sim_gjrGARCH <- function(par, sigma0, eps0, z, mu=0, var_floor=1e-12) {
  omega <- par["omega"]; alpha <- par["alpha1"]; beta <- par["beta1"]; gamma <- par["gamma1"]
  n <- length(z); h <- numeric(n); eps <- numeric(n); r <- numeric(n)
  h_prev <- max(as.numeric(sigma0)^2, var_floor); eps_prev <- as.numeric(eps0)
  for (t in 1:n) {
    Ineg <- as.numeric(eps_prev < 0)
    h_t <- max(omega + (alpha + gamma * Ineg) * (eps_prev^2) + beta * h_prev, var_floor)
    eps_t <- sqrt(h_t) * z[t]
    r[t]  <- mu + eps_t
    h_prev <- h_t; eps_prev <- eps_t
    h[t] <- h_t; eps[t] <- eps_t
  }
  list(returns = r, sigma = sqrt(h), eps = eps)
}

.sim_eGARCH <- function(par, sigma0, eps0, z, mu=0, Ezabs=NULL, var_floor=1e-12) {
  # log(h_t) = omega + beta*log(h_{t-1}) + alpha*(|z_{t-1}| - E|z|) + gamma*z_{t-1}
  omega <- par["omega"]; alpha <- par["alpha1"]; beta <- par["beta1"]; gamma <- par["gamma1"]
  n <- length(z); h <- numeric(n); eps <- numeric(n); r <- numeric(n)
  h_prev <- max(as.numeric(sigma0)^2, var_floor); z_prev <- as.numeric(eps0) / sqrt(h_prev)
  if (is.null(Ezabs)) Ezabs <- mean(abs(z), na.rm = TRUE)
  for (t in 1:n) {
    logh_t <- omega + beta * log(h_prev) + alpha * (abs(z_prev) - Ezabs) + gamma * z_prev
    h_t <- max(exp(logh_t), var_floor)
    eps_t <- sqrt(h_t) * z[t]
    r[t]  <- mu + eps_t
    z_prev <- eps_t / sqrt(h_t)
    h_prev <- h_t
    h[t] <- h_t; eps[t] <- eps_t
  }
  list(returns = r, sigma = sqrt(h), eps = eps)
}



# ---- Manual NF-GARCH simulator ----------------------------------------------
# Works for: sGARCH, gjrGARCH, eGARCH, fGARCH(submodel="TGARCH")
# Assumes z_nf are pre-standardized innovations: mean ≈ 0, var ≈ 1
simulate_nf_garch <- function(fit,
                              z_nf,
                              horizon = 40,
                              model = c("sGARCH","gjrGARCH","eGARCH","fGARCH"),
                              submodel = NULL,
                              var_floor = 1e-12) {
  stopifnot(horizon > 0)
  model <- match.arg(model)

  # Use proper S4 access methods for rugarch objects
  cf <- tryCatch({
    if (isS4(fit)) {
      fit@fit$coef
    } else {
      coef(fit)
    }
  }, error = function(e) NULL)
  
  if (is.null(cf)) stop("No coefficients found in fit.")

  # Pull last state from the fitted object using S4 methods
  sig_last <- tryCatch({
    if (isS4(fit)) {
      tail(fit@fit$sigma, 1)
    } else {
      tail(sigma(fit), 1)
    }
  }, error = function(e) NA)
  
  eps_last <- tryCatch({
    if (isS4(fit)) {
      tail(fit@fit$residuals, 1)
    } else {
      tail(residuals(fit), 1)
    }
  }, error = function(e) NA)
  
  mu_last  <- if ("mu" %in% names(cf)) cf["mu"] else 0

  if (!is.finite(sig_last) || sig_last <= 0) {
    fitted_vals <- tryCatch({
      if (isS4(fit)) {
        fit@fit$fitted.values
      } else {
        fitted(fit)
      }
    }, error = function(e) NULL)
    sig_last <- if (!is.null(fitted_vals)) sd(fitted_vals, na.rm = TRUE) else 0.01
  }
  if (!is.finite(sig_last) || sig_last <= 0) sig_last <- 0.01
  if (!is.finite(eps_last)) eps_last <- 0

  # Storage
  r   <- numeric(horizon)
  eps <- numeric(horizon)
  sig <- numeric(horizon)

  # eGARCH needs E|z| term; estimate from supplied NF draws
  Ez_abs <- mean(abs(z_nf), na.rm = TRUE)
  if (!is.finite(Ez_abs) || Ez_abs <= 0) Ez_abs <- sqrt(2/pi) # N(0,1) fallback

  # Coeff helpers (presence differs by spec)
  get <- function(nm, default = 0) if (nm %in% names(cf)) as.numeric(cf[nm]) else default

  omega  <- get("omega")
  alpha1 <- get("alpha1")
  beta1  <- get("beta1")
  gamma1 <- get("gamma1")
  eta11  <- get("eta11") # TGARCH asymmetry name in rugarch

  # Initialize t=0 state
  sigma2_tm1 <- sig_last^2
  eps_tm1    <- eps_last
  z_tm1      <- if (sig_last > 0) eps_last / sig_last else 0
  logvar_tm1 <- log(max(sigma2_tm1, var_floor))

  # Ensure enough z's
  if (length(z_nf) < horizon) {
    warning("z_nf shorter than horizon; recycling.")
    z_nf <- rep_len(z_nf, horizon)
  }

  for (t in seq_len(horizon)) {
    z_t <- z_nf[t]

    if (model == "sGARCH") {
      # sigma^2_t = omega + alpha * eps_{t-1}^2 + beta * sigma^2_{t-1}
      sigma2_t <- omega + alpha1 * (eps_tm1^2) + beta1 * sigma2_tm1
      sigma2_t <- ifelse(is.finite(sigma2_t), pmax(sigma2_t, var_floor), var_floor)
      sigma_t  <- sqrt(sigma2_t)
      eps_t    <- sigma_t * z_t

      r[t]   <- mu_last + eps_t
      eps[t] <- eps_t
      sig[t] <- sigma_t

      # roll
      sigma2_tm1 <- sigma2_t
      eps_tm1    <- eps_t
      z_tm1      <- z_t

    } else if (model == "gjrGARCH") {
      # sigma^2_t = omega + alpha * eps_{t-1}^2 + gamma * I(eps_{t-1}<0)*eps_{t-1}^2 + beta * sigma^2_{t-1}
      Ineg      <- as.numeric(eps_tm1 < 0)
      sigma2_t  <- omega + alpha1*(eps_tm1^2) + gamma1*Ineg*(eps_tm1^2) + beta1*sigma2_tm1
      sigma2_t  <- ifelse(is.finite(sigma2_t), pmax(sigma2_t, var_floor), var_floor)
      sigma_t   <- sqrt(sigma2_t)
      eps_t     <- sigma_t * z_t

      r[t]   <- mu_last + eps_t
      eps[t] <- eps_t
      sig[t] <- sigma_t

      sigma2_tm1 <- sigma2_t
      eps_tm1    <- eps_t
      z_tm1      <- z_t

    } else if (model == "eGARCH") {
      # log(sigma^2_t) = omega + alpha*(|z_{t-1}| - E|z|) + gamma*z_{t-1} + beta*log(sigma^2_{t-1})
      logvar_t <- omega + alpha1 * (abs(z_tm1) - Ez_abs) + gamma1 * z_tm1 + beta1 * logvar_tm1
      logvar_t <- ifelse(is.finite(logvar_t), logvar_t, log(var_floor))
      sigma2_t <- exp(logvar_t)
      sigma_t  <- sqrt(pmax(sigma2_t, var_floor))
      eps_t    <- sigma_t * z_t

      r[t]   <- mu_last + eps_t
      eps[t] <- eps_t
      sig[t] <- sigma_t

      logvar_tm1 <- logvar_t
      sigma2_tm1 <- sigma2_t
      eps_tm1    <- eps_t
      z_tm1      <- z_t

    } else if (model == "fGARCH" && identical(submodel, "TGARCH")) {
      # rugarch TGARCH parameterization (absolute residual form):
      # sigma_t = omega + alpha*|eps_{t-1}| + eta11*I(eps_{t-1}<0)*|eps_{t-1}| + beta*sigma_{t-1}
      sigma_t <- omega + alpha1*abs(eps_tm1) + eta11*as.numeric(eps_tm1 < 0)*abs(eps_tm1) + beta1*sqrt(pmax(sigma2_tm1, var_floor))
      sigma_t <- ifelse(is.finite(sigma_t), pmax(sigma_t, sqrt(var_floor)), sqrt(var_floor))
      eps_t   <- sigma_t * z_t

      r[t]   <- mu_last + eps_t
      eps[t] <- eps_t
      sig[t] <- sigma_t

      sigma2_tm1 <- sigma_t^2
      eps_tm1    <- eps_t
      z_tm1      <- z_t

    } else {
      stop("Unsupported model/submodel combination.")
    }
  }

  list(returns = r, sigma = sig, eps = eps)
}
