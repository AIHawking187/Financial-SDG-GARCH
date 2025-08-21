# Conflict Resolution Utilities
# This script resolves common package conflicts in the NF-GARCH pipeline

# Resolve dplyr lag function conflict with xts
resolve_lag_conflict <- function() {
  # Suppress the dplyr lag conflict warning
  options(xts.warn_dplyr_breaks_lag = FALSE)
  
  # Create explicit lag functions to avoid conflicts
  if (requireNamespace("dplyr", quietly = TRUE)) {
    # Use stats::lag explicitly for xts objects
    assign("xts_lag", function(x, k = 1, ...) {
      if (inherits(x, "xts")) {
        stats::lag(x, k = k, ...)
      } else {
        dplyr::lag(x, n = k, ...)
      }
    }, envir = .GlobalEnv)
  }
  
  cat("✓ Lag function conflicts resolved\n")
}

# Suppress package version warnings
suppress_version_warnings <- function() {
  # Suppress package version warnings
  options(warn = 1)  # Only show warnings once
  
  # Suppress specific package warnings
  suppressWarnings({
    library(openxlsx, quietly = TRUE)
    library(quantmod, quietly = TRUE)
    library(xts, quietly = TRUE)
    library(zoo, quietly = TRUE)
    library(TTR, quietly = TRUE)
    library(tseries, quietly = TRUE)
    library(rugarch, quietly = TRUE)
    library(PerformanceAnalytics, quietly = TRUE)
    library(FinTS, quietly = TRUE)
    library(dplyr, quietly = TRUE)
    library(stringr, quietly = TRUE)
  })
  
  cat("✓ Package version warnings suppressed\n")
}

# Initialize conflict resolution
initialize_pipeline <- function() {
  cat("Initializing pipeline with conflict resolution...\n")
  resolve_lag_conflict()
  suppress_version_warnings()
  cat("✓ Pipeline initialization complete\n")
}

# Export functions
if (!exists("PIPELINE_INITIALIZED")) {
  PIPELINE_INITIALIZED <- TRUE
  cat("Conflict resolution utilities loaded\n")
}
