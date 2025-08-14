# Safety Functions for GARCH Model Analysis
# This file contains utility functions to prevent crashes and handle edge cases

#' Safe row addition function for summary tables
#' 
#' This function provides a safety net to prevent summary tables from crashing 
#' when a model returns no rows. It checks if the dataframe is NULL or empty
#' before attempting to bind rows.
#' 
#' @param acc The accumulator dataframe (existing results)
#' @param df The new dataframe to add
#' @return The combined dataframe, or the accumulator if df is NULL/empty
#' 
#' @examples
#' # Usage with reduce:
#' # reduce(add_row_safe, init = data.frame(), list_of_dataframes)
add_row_safe <- function(acc, df) {
  if (is.null(df) || nrow(df) == 0) {
    return(acc)
  }
  rbind(acc, df)
}

#' Robust distribution function wrapper for rugarch
#' 
#' These functions provide a robust interface to rugarch distribution functions,
#' ensuring consistent parameter handling and error management.
#' 
#' @param p Probability for quantile function
#' @param x Value for density function
#' @param q Quantile for CDF function
#' @param n Number of samples for RNG function
#' @param mu Location parameter
#' @param sigma Scale parameter
#' @param skew Skewness parameter
#' @param shape Shape parameter
#' @return The computed distribution value(s)
#' 
#' @examples
#' # Quantile function
#' qsstd_robust(0.95, mu = 0, sigma = 1, skew = 1.2, shape = 5)
#' 
#' # Density function
#' dsstd_robust(0, mu = 0, sigma = 1, skew = 1.2, shape = 5)
#' 
#' # CDF function
#' psstd_robust(0, mu = 0, sigma = 1, skew = 1.2, shape = 5)
#' 
#' # Random number generation
#' rsstd_robust(100, mu = 0, sigma = 1, skew = 1.2, shape = 5)

#' Robust quantile function for skewed-t distribution
qsstd_robust <- function(p, mu = 0, sigma = 1, skew = 1, shape = 5) {
  tryCatch({
    rugarch::qdist("sstd", p, mu = mu, sigma = sigma, skew = skew, shape = shape)
  }, error = function(e) {
    warning("qsstd_robust failed, falling back to normal: ", e$message)
    qnorm(p, mean = mu, sd = sigma)
  })
}

#' Robust density function for skewed-t distribution
dsstd_robust <- function(x, mu = 0, sigma = 1, skew = 1, shape = 5) {
  tryCatch({
    rugarch::ddist("sstd", x, mu = mu, sigma = sigma, skew = skew, shape = shape)
  }, error = function(e) {
    warning("dsstd_robust failed, falling back to normal: ", e$message)
    dnorm(x, mean = mu, sd = sigma)
  })
}

#' Robust CDF function for skewed-t distribution
psstd_robust <- function(q, mu = 0, sigma = 1, skew = 1, shape = 5) {
  tryCatch({
    rugarch::pdist("sstd", q, mu = mu, sigma = sigma, skew = skew, shape = shape)
  }, error = function(e) {
    warning("psstd_robust failed, falling back to normal: ", e$message)
    pnorm(q, mean = mu, sd = sigma)
  })
}

#' Robust random number generation for skewed-t distribution
rsstd_robust <- function(n, mu = 0, sigma = 1, skew = 1, shape = 5) {
  tryCatch({
    rugarch::rdist("sstd", n, mu = mu, sigma = sigma, skew = skew, shape = shape)
  }, error = function(e) {
    warning("rsstd_robust failed, falling back to normal: ", e$message)
    rnorm(n, mean = mu, sd = sigma)
  })
}
