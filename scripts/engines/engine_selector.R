# Engine Selector - Uniform API for rugarch and manual engines
# Provides compatibility layer between different GARCH engines

# Load manual GARCH functions
source("scripts/manual_garch/fit_sgarch_manual.R")
source("scripts/manual_garch/fit_gjr_manual.R")
source("scripts/manual_garch/fit_egarch_manual.R")
source("scripts/manual_garch/fit_tgarch_manual.R")
source("scripts/manual_garch/forecast_manual.R")

engine_fit <- function(model, returns, dist, submodel = NULL, engine = "rugarch") {
  # Uniform fitting function that works with both rugarch and manual engines
  # Returns a standardized fit object with consistent fields
  
  if (engine == "rugarch") {
    # Use rugarch engine
    library(rugarch)
    
    # Create spec
    spec <- ugarchspec(
      mean.model = list(armaOrder = c(0, 0)),
      variance.model = list(
        model = model,
        garchOrder = c(1, 1),
        submodel = submodel
      ),
      distribution.model = dist
    )
    
    # Fit model
    fit <- ugarchfit(spec = spec, data = returns)
    
    # Extract standardized fields
    result <- list(
      engine = "rugarch",
      model_type = model,
      distribution = dist,
      submodel = submodel,
      convergence = fit@fit$convergence == 0,
      loglik = fit@fit$LLH,
      aic = fit@fit$ics[1],
      bic = fit@fit$ics[2],
      coef = fit@fit$coef,
      sigma = as.numeric(sigma(fit)),
      residuals = as.numeric(residuals(fit)),
      std_residuals = as.numeric(residuals(fit, standardize = TRUE)),
      fitted = as.numeric(fitted(fit)),
      rugarch_fit = fit  # Keep original for compatibility
    )
    
  } else if (engine == "manual") {
    # Use manual engine
    # Map sstd to std for manual engine (skewed-t not implemented yet)
    manual_dist <- if (dist == "sstd") "std" else dist
    
    if (model == "sGARCH") {
      fit <- fit_sgarch_manual(returns, dist = manual_dist)
    } else if (model == "gjrGARCH") {
      fit <- fit_gjr_manual(returns, dist = manual_dist)
    } else if (model == "eGARCH") {
      fit <- fit_egarch_manual(returns, dist = manual_dist)
    } else if (model == "fGARCH" && submodel == "TGARCH") {
      fit <- fit_tgarch_manual(returns, dist = manual_dist)
    } else {
      stop("Manual engine does not support model: ", model, " with submodel: ", submodel)
    }
    
    # Standardize fields to match rugarch output
    result <- list(
      engine = "manual",
      model_type = fit$model_type,
      distribution = fit$distribution,
      submodel = submodel,
      convergence = fit$convergence,
      loglik = fit$loglik,
      aic = fit$aic,
      bic = fit$bic,
      coef = fit$coef,
      sigma = fit$sigma,
      residuals = fit$residuals,
      std_residuals = fit$std_residuals,
      fitted = fit$fitted,
      manual_fit = fit  # Keep original for compatibility
    )
    
  } else {
    stop("Unknown engine: ", engine, ". Use 'rugarch' or 'manual'")
  }
  
  return(result)
}

engine_forecast <- function(fit, h, engine = NULL) {
  # Uniform forecasting function
  if (is.null(engine)) {
    engine <- fit$engine
  }
  
  if (engine == "rugarch") {
    # Use rugarch forecast
    library(rugarch)
    forecast <- ugarchforecast(fit$rugarch_fit, n.ahead = h)
    
    return(list(
      sigma = as.numeric(sigma(forecast)),
      mean = as.numeric(fitted(forecast))
    ))
    
  } else if (engine == "manual") {
    # Use manual forecast
    return(manual_forecast(fit$manual_fit, h))
    
  } else {
    stop("Unknown engine: ", engine)
  }
}

engine_path <- function(fit, z, h, model, submodel = NULL, engine = NULL) {
  # Uniform path simulation function for NF-GARCH
  if (is.null(engine)) {
    engine <- fit$engine
  }
  
  if (engine == "rugarch") {
    # Use rugarch path (if available) or manual simulation
    library(rugarch)
    
    # Try ugarchpath first
    tryCatch({
      spec <- ugarchspec(
        mean.model = list(armaOrder = c(0, 0)),
        variance.model = list(
          model = model,
          garchOrder = c(1, 1),
          submodel = submodel
        ),
        distribution.model = fit$distribution
      )
      
      # Standardize parameter names for rugarch
      coef_standardized <- fit$coef
      names(coef_standardized) <- standardize_rugarch_params(names(coef_standardized), model, fit$distribution)
      
      sim <- ugarchpath(
        spec,
        n.sim = h,
        m.sim = 1,
        presigma = tail(fit$sigma, 1),
        preresiduals = tail(fit$residuals, 1),
        prereturns = tail(fit$fitted, 1),
        innovations = z[1:h],
        pars = coef_standardized
      )
      
      return(list(
        returns = as.numeric(fitted(sim)),
        sigma = as.numeric(sigma(sim)),
        innovations = z[1:h]
      ))
      
    }, error = function(e) {
      # Fallback to manual simulation for rugarch
      warning("ugarchpath failed, using manual simulation: ", conditionMessage(e))
      return(manual_path(fit$manual_fit, z, h, model, submodel))
    })
    
  } else if (engine == "manual") {
    # Use manual path - this should work without errors
    result <- manual_path(fit$manual_fit, z, h, model, submodel)
    
    # Ensure we return the correct length
    if (length(result$returns) != h) {
      warning("Manual path returned incorrect length. Expected: ", h, ", Got: ", length(result$returns))
    }
    
    return(result)
    
  } else {
    stop("Unknown engine: ", engine)
  }
}

# Helper function to standardize parameter names for rugarch
standardize_rugarch_params <- function(param_names, model, distribution) {
  # Map parameter names to rugarch expected format
  standardized <- param_names
  
  # Standard GARCH parameter mappings
  if (model == "sGARCH") {
    if (distribution == "norm") {
      # Expected: mu, omega, alpha1, beta1
      standardized[param_names == "mu"] <- "mu"
      standardized[param_names == "omega"] <- "omega"
      standardized[param_names == "alpha"] <- "alpha1"
      standardized[param_names == "beta"] <- "beta1"
    } else if (distribution == "std" || distribution == "sstd") {
      # Expected: mu, omega, alpha1, beta1, shape (and skew for sstd)
      standardized[param_names == "mu"] <- "mu"
      standardized[param_names == "omega"] <- "omega"
      standardized[param_names == "alpha"] <- "alpha1"
      standardized[param_names == "beta"] <- "beta1"
      standardized[param_names == "nu"] <- "shape"
      standardized[param_names == "skew"] <- "skew"
    }
  } else if (model == "gjrGARCH") {
    if (distribution == "norm") {
      # Expected: mu, omega, alpha1, beta1, gamma1
      standardized[param_names == "mu"] <- "mu"
      standardized[param_names == "omega"] <- "omega"
      standardized[param_names == "alpha"] <- "alpha1"
      standardized[param_names == "beta"] <- "beta1"
      standardized[param_names == "gamma"] <- "gamma1"
    } else if (distribution == "std" || distribution == "sstd") {
      # Expected: mu, omega, alpha1, beta1, gamma1, shape (and skew for sstd)
      standardized[param_names == "mu"] <- "mu"
      standardized[param_names == "omega"] <- "omega"
      standardized[param_names == "alpha"] <- "alpha1"
      standardized[param_names == "beta"] <- "beta1"
      standardized[param_names == "gamma"] <- "gamma1"
      standardized[param_names == "nu"] <- "shape"
      standardized[param_names == "skew"] <- "skew"
    }
  } else if (model == "eGARCH") {
    if (distribution == "norm") {
      # Expected: mu, omega, alpha1, beta1, gamma1
      standardized[param_names == "mu"] <- "mu"
      standardized[param_names == "omega"] <- "omega"
      standardized[param_names == "alpha"] <- "alpha1"
      standardized[param_names == "beta"] <- "beta1"
      standardized[param_names == "gamma"] <- "gamma1"
    } else if (distribution == "std" || distribution == "sstd") {
      # Expected: mu, omega, alpha1, beta1, gamma1, shape (and skew for sstd)
      standardized[param_names == "mu"] <- "mu"
      standardized[param_names == "omega"] <- "omega"
      standardized[param_names == "alpha"] <- "alpha1"
      standardized[param_names == "beta"] <- "beta1"
      standardized[param_names == "gamma"] <- "gamma1"
      standardized[param_names == "nu"] <- "shape"
      standardized[param_names == "skew"] <- "skew"
    }
  } else if (model == "fGARCH" && submodel == "TGARCH") {
    if (distribution == "norm") {
      # Expected: mu, omega, alpha1, beta1, eta11
      standardized[param_names == "mu"] <- "mu"
      standardized[param_names == "omega"] <- "omega"
      standardized[param_names == "alpha"] <- "alpha1"
      standardized[param_names == "beta"] <- "beta1"
      standardized[param_names == "eta"] <- "eta11"
    } else if (distribution == "std" || distribution == "sstd") {
      # Expected: mu, omega, alpha1, beta1, eta11, shape (and skew for sstd)
      standardized[param_names == "mu"] <- "mu"
      standardized[param_names == "omega"] <- "omega"
      standardized[param_names == "alpha"] <- "alpha1"
      standardized[param_names == "beta"] <- "beta1"
      standardized[param_names == "eta"] <- "eta11"
      standardized[param_names == "nu"] <- "shape"
      standardized[param_names == "skew"] <- "skew"
    }
  }
  
  return(standardized)
}

# Helper function to get standardized residuals for NF training
engine_residuals <- function(fit, standardize = TRUE) {
  # Get residuals in standardized format for NF training
  if (fit$engine == "rugarch") {
    if (standardize) {
      return(fit$std_residuals)
    } else {
      return(fit$residuals)
    }
  } else if (fit$engine == "manual") {
    if (standardize) {
      return(fit$std_residuals)
    } else {
      return(fit$residuals)
    }
  } else {
    stop("Unknown engine: ", fit$engine)
  }
}

# Helper function to get model information criteria
engine_infocriteria <- function(fit) {
  # Get information criteria in standardized format
  return(c(AIC = fit$aic, BIC = fit$bic, LogLikelihood = fit$loglik))
}

# Helper function to check if fit was successful
engine_converged <- function(fit) {
  return(fit$convergence)
}
