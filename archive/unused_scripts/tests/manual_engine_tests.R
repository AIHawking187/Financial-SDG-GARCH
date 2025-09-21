# Manual Engine Tests
# Comprehensive tests for the manual GARCH engine

# Load required libraries and functions
source("scripts/manual_garch/manual_garch_core.R")
source("scripts/manual_garch/fit_sgarch_manual.R")
source("scripts/manual_garch/fit_gjr_manual.R")
source("scripts/manual_garch/fit_egarch_manual.R")
source("scripts/manual_garch/fit_tgarch_manual.R")
source("scripts/manual_garch/forecast_manual.R")
source("scripts/engines/engine_selector.R")

cat("=== Manual GARCH Engine Tests ===\n\n")

# Test 1: Smoke tests for each model on synthetic data
cat("Test 1: Smoke tests for each model...\n")

# Generate synthetic data
set.seed(123)
n <- 1000
synthetic_returns <- rnorm(n, mean = 0.001, sd = 0.02)

# Test sGARCH
cat("  Testing sGARCH (normal)...\n")
sgarch_norm_fit <- fit_sgarch_manual(synthetic_returns, dist = "norm")
if (sgarch_norm_fit$convergence) {
  cat("    ✅ sGARCH (normal) converged\n")
  cat("    AIC:", sgarch_norm_fit$aic, "BIC:", sgarch_norm_fit$bic, "LogLik:", sgarch_norm_fit$loglik, "\n")
} else {
  cat("    ❌ sGARCH (normal) failed to converge\n")
}

cat("  Testing sGARCH (Student-t)...\n")
sgarch_std_fit <- fit_sgarch_manual(synthetic_returns, dist = "std")
if (sgarch_std_fit$convergence) {
  cat("    ✅ sGARCH (Student-t) converged\n")
  cat("    AIC:", sgarch_std_fit$aic, "BIC:", sgarch_std_fit$bic, "LogLik:", sgarch_std_fit$loglik, "\n")
} else {
  cat("    ❌ sGARCH (Student-t) failed to converge\n")
}

# Test GJR-GARCH
cat("  Testing GJR-GARCH (normal)...\n")
gjr_norm_fit <- fit_gjr_manual(synthetic_returns, dist = "norm")
if (gjr_norm_fit$convergence) {
  cat("    ✅ GJR-GARCH (normal) converged\n")
  cat("    AIC:", gjr_norm_fit$aic, "BIC:", gjr_norm_fit$bic, "LogLik:", gjr_norm_fit$loglik, "\n")
} else {
  cat("    ❌ GJR-GARCH (normal) failed to converge\n")
}

# Test eGARCH
cat("  Testing eGARCH (normal)...\n")
egarch_norm_fit <- fit_egarch_manual(synthetic_returns, dist = "norm")
if (egarch_norm_fit$convergence) {
  cat("    ✅ eGARCH (normal) converged\n")
  cat("    AIC:", egarch_norm_fit$aic, "BIC:", egarch_norm_fit$bic, "LogLik:", egarch_norm_fit$loglik, "\n")
} else {
  cat("    ❌ eGARCH (normal) failed to converge\n")
}

# Test TGARCH
cat("  Testing TGARCH (normal)...\n")
tgarch_norm_fit <- fit_tgarch_manual(synthetic_returns, dist = "norm")
if (tgarch_norm_fit$convergence) {
  cat("    ✅ TGARCH (normal) converged\n")
  cat("    AIC:", tgarch_norm_fit$aic, "BIC:", tgarch_norm_fit$bic, "LogLik:", tgarch_norm_fit$loglik, "\n")
} else {
  cat("    ❌ TGARCH (normal) failed to converge\n")
}

# Test 2: Parameter sanity checks
cat("\nTest 2: Parameter sanity checks...\n")

# Check sGARCH parameters
if (sgarch_norm_fit$convergence) {
  # Find alpha and beta parameters (they have prefixes)
  alpha_idx <- grep("alpha", names(sgarch_norm_fit$coef))
  beta_idx <- grep("beta", names(sgarch_norm_fit$coef))
  
  if (length(alpha_idx) > 0 && length(beta_idx) > 0) {
    alpha <- sgarch_norm_fit$coef[alpha_idx[1]]
    beta <- sgarch_norm_fit$coef[beta_idx[1]]
    cat("  sGARCH: alpha =", alpha, "beta =", beta, "alpha + beta =", alpha + beta, "\n")
    if (alpha + beta < 1) {
      cat("    ✅ sGARCH stationarity condition satisfied\n")
    } else {
      cat("    ❌ sGARCH stationarity condition violated\n")
    }
  } else {
    cat("    ⚠️  Could not find alpha/beta parameters\n")
  }
}

# Check GJR-GARCH parameters
if (gjr_norm_fit$convergence) {
  # Find parameters (they have prefixes)
  alpha_idx <- grep("alpha", names(gjr_norm_fit$coef))
  gamma_idx <- grep("gamma", names(gjr_norm_fit$coef))
  beta_idx <- grep("beta", names(gjr_norm_fit$coef))
  
  if (length(alpha_idx) > 0 && length(gamma_idx) > 0 && length(beta_idx) > 0) {
    alpha <- gjr_norm_fit$coef[alpha_idx[1]]
    gamma <- gjr_norm_fit$coef[gamma_idx[1]]
    beta <- gjr_norm_fit$coef[beta_idx[1]]
    cat("  GJR-GARCH: alpha =", alpha, "gamma =", gamma, "beta =", beta, "alpha + gamma/2 + beta =", alpha + gamma/2 + beta, "\n")
    if (alpha + gamma/2 + beta < 1) {
      cat("    ✅ GJR-GARCH stationarity condition satisfied\n")
    } else {
      cat("    ❌ GJR-GARCH stationarity condition violated\n")
    }
  } else {
    cat("    ⚠️  Could not find alpha/gamma/beta parameters\n")
  }
}

# Test 3: Forecast sanity
cat("\nTest 3: Forecast sanity...\n")

if (sgarch_norm_fit$convergence) {
  forecast <- sgarch_norm_fit$predict(10)
  cat("  sGARCH 10-step forecast:\n")
  cat("    Mean:", mean(forecast$mean), "\n")
  cat("    Sigma range:", range(forecast$sigma), "\n")
  if (all(forecast$sigma > 0)) {
    cat("    ✅ All forecasted volatilities are positive\n")
  } else {
    cat("    ❌ Some forecasted volatilities are non-positive\n")
  }
}

# Test 4: NF-GARCH path simulation
cat("\nTest 4: NF-GARCH path simulation...\n")

# Generate synthetic NF innovations
nf_innovations <- rnorm(20, mean = 0, sd = 1)

if (sgarch_norm_fit$convergence) {
  path_result <- manual_path(sgarch_norm_fit, nf_innovations, 20, "sGARCH")
  cat("  sGARCH NF path simulation:\n")
  cat("    Returns range:", range(path_result$returns), "\n")
  cat("    Sigma range:", range(path_result$sigma), "\n")
  if (all(path_result$sigma > 0)) {
    cat("    ✅ All simulated volatilities are positive\n")
  } else {
    cat("    ❌ Some simulated volatilities are non-positive\n")
  }
}

# Test 5: Engine selector compatibility
cat("\nTest 5: Engine selector compatibility...\n")

# Test manual engine
manual_fit <- engine_fit("sGARCH", synthetic_returns, "norm", engine = "manual")
if (engine_converged(manual_fit)) {
  cat("  ✅ Manual engine fit successful\n")
  cat("    AIC:", manual_fit$aic, "BIC:", manual_fit$bic, "LogLik:", manual_fit$loglik, "\n")
} else {
  cat("  ❌ Manual engine fit failed\n")
}

# Test manual forecast
manual_forecast_result <- engine_forecast(manual_fit, 10, "manual")
cat("  Manual engine forecast:\n")
cat("    Mean:", mean(manual_forecast_result$mean), "\n")
cat("    Sigma range:", range(manual_forecast_result$sigma), "\n")

# Test manual path
manual_path_result <- engine_path(manual_fit, nf_innovations, 20, "sGARCH", engine = "manual")
cat("  Manual engine path simulation:\n")
cat("    Returns range:", range(manual_path_result$returns), "\n")
cat("    Sigma range:", range(manual_path_result$sigma), "\n")

# Test 6: Equality of interfaces (if rugarch is available)
cat("\nTest 6: Interface compatibility...\n")

if (requireNamespace("rugarch", quietly = TRUE)) {
  cat("  rugarch package available, testing interface compatibility...\n")
  
  # Test rugarch engine
  rugarch_fit <- engine_fit("sGARCH", synthetic_returns, "norm", engine = "rugarch")
  if (engine_converged(rugarch_fit)) {
    cat("  ✅ rugarch engine fit successful\n")
    cat("    AIC:", rugarch_fit$aic, "BIC:", rugarch_fit$bic, "LogLik:", rugarch_fit$loglik, "\n")
    
    # Compare log-likelihoods (allow tolerance)
    ll_diff <- abs(manual_fit$loglik - rugarch_fit$loglik)
    if (ll_diff < 1.0) {
      cat("    ✅ Log-likelihoods are comparable (difference:", ll_diff, ")\n")
    } else {
      cat("    ⚠️  Log-likelihoods differ significantly (difference:", ll_diff, ")\n")
    }
  } else {
    cat("  ❌ rugarch engine fit failed\n")
  }
} else {
  cat("  rugarch package not available, skipping interface comparison\n")
}

# Test 7: Error handling
cat("\nTest 7: Error handling...\n")

# Test with invalid data
invalid_data <- c(NA, NaN, Inf, -Inf, 1, 2, 3)
cat("  Testing with invalid data...\n")
tryCatch({
  invalid_fit <- fit_sgarch_manual(invalid_data, dist = "norm")
  cat("    ⚠️  Invalid data fit succeeded (unexpected)\n")
}, error = function(e) {
  cat("    ✅ Invalid data properly rejected:", conditionMessage(e), "\n")
})

# Test with very short data
short_data <- rnorm(10)
cat("  Testing with short data...\n")
short_fit <- fit_sgarch_manual(short_data, dist = "norm")
if (short_fit$convergence) {
  cat("    ✅ Short data fit succeeded\n")
} else {
  cat("    ⚠️  Short data fit failed to converge\n")
}

# Summary
cat("\n=== Test Summary ===\n")
cat("Manual GARCH engine tests completed.\n")
cat("Check the output above for any ❌ failures.\n")
cat("All ✅ indicate successful tests.\n")
