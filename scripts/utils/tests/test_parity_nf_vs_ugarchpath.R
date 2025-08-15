# scripts/utils/tests/test_parity_nf_vs_ugarchpath.R
# Goal: With Gaussian shocks, manual simulator ≈ ugarchpath outputs.

library(testthat)
library(rugarch)
source("../utils_nf_garch.R")

test_that("manual simulators match ugarchpath under Gaussian shocks", {
  set.seed(123)
  x <- rnorm(2000) * 0.01
  spec_s <- ugarchspec(mean.model = list(armaOrder=c(0,0)),
                       variance.model = list(model="sGARCH", garchOrder=c(1,1)),
                       distribution.model = "norm")
  fit_s <- ugarchfit(spec=spec_s, data=x)

  horizon <- 50

  # Generate the same innovations for both
  set.seed(456)
  innovations <- rnorm(horizon)

  # Reference path from ugarchpath
  set.seed(456)
  spec_fixed <- ugarchspec(mean.model = list(armaOrder=c(0,0)),
                           variance.model = list(model="sGARCH", garchOrder=c(1,1)),
                           distribution.model = "norm",
                           fixed.pars = as.list(coef(fit_s)))
  ref_sim <- ugarchpath(spec_fixed, n.sim=horizon, m.sim=1,
                        presigma=tail(sigma(fit_s),1),
                        preresiduals=tail(residuals(fit_s),1),
                        prereturns=tail(fitted(fit_s),1),
                        innovations = innovations)
  ref_ret <- as.numeric(fitted(ref_sim))

  # Manual path with gaussian_parity=TRUE
  set.seed(456)
  man <- simulate_nf_garch(fit_s, z_nf=innovations, horizon=horizon, model="sGARCH", gaussian_parity=FALSE)
  man_ret <- as.numeric(man$returns)

  # Tolerances can be adjusted if needed
  expect_equal(length(ref_ret), length(man_ret))
  expect_lt(mean(abs(ref_ret - man_ret)), 2e-3)  # reasonable tolerance for numerical differences
})

test_that("manual GJR-GARCH matches ugarchpath under Gaussian shocks", {
  set.seed(789)
  x <- rnorm(2000) * 0.01
  spec_gjr <- ugarchspec(mean.model = list(armaOrder=c(0,0)),
                         variance.model = list(model="gjrGARCH", garchOrder=c(1,1)),
                         distribution.model = "norm")
  fit_gjr <- ugarchfit(spec=spec_gjr, data=x)

  horizon <- 50

  # Generate the same innovations for both
  set.seed(789)
  innovations <- rnorm(horizon)

  # Reference path from ugarchpath
  set.seed(789)
  spec_fixed <- ugarchspec(mean.model = list(armaOrder=c(0,0)),
                           variance.model = list(model="gjrGARCH", garchOrder=c(1,1)),
                           distribution.model = "norm",
                           fixed.pars = as.list(coef(fit_gjr)))
  ref_sim <- ugarchpath(spec_fixed, n.sim=horizon, m.sim=1,
                        presigma=tail(sigma(fit_gjr),1),
                        preresiduals=tail(residuals(fit_gjr),1),
                        prereturns=tail(fitted(fit_gjr),1),
                        innovations = innovations)
  ref_ret <- as.numeric(fitted(ref_sim))

  # Manual path with gaussian_parity=TRUE
  set.seed(789)
  man <- simulate_nf_garch(fit_gjr, z_nf=innovations, horizon=horizon, model="gjrGARCH", gaussian_parity=FALSE)
  man_ret <- as.numeric(man$returns)

  expect_equal(length(ref_ret), length(man_ret))
  expect_lt(mean(abs(ref_ret - man_ret)), 2e-3)
})

test_that("manual eGARCH matches ugarchpath under Gaussian shocks", {
  set.seed(101)
  x <- rnorm(2000) * 0.01
  spec_e <- ugarchspec(mean.model = list(armaOrder=c(0,0)),
                       variance.model = list(model="eGARCH", garchOrder=c(1,1)),
                       distribution.model = "norm")
  fit_e <- ugarchfit(spec=spec_e, data=x)

  horizon <- 50

  # Generate the same innovations for both
  set.seed(101)
  innovations <- rnorm(horizon)

  # Reference path from ugarchpath
  set.seed(101)
  spec_fixed <- ugarchspec(mean.model = list(armaOrder=c(0,0)),
                           variance.model = list(model="eGARCH", garchOrder=c(1,1)),
                           distribution.model = "norm",
                           fixed.pars = as.list(coef(fit_e)))
  ref_sim <- ugarchpath(spec_fixed, n.sim=horizon, m.sim=1,
                        presigma=tail(sigma(fit_e),1),
                        preresiduals=tail(residuals(fit_e),1),
                        prereturns=tail(fitted(fit_e),1),
                        innovations = innovations)
  ref_ret <- as.numeric(fitted(ref_sim))

  # Manual path with gaussian_parity=TRUE
  set.seed(101)
  man <- simulate_nf_garch(fit_e, z_nf=innovations, horizon=horizon, model="eGARCH", gaussian_parity=FALSE)
  man_ret <- as.numeric(man$returns)

  expect_equal(length(ref_ret), length(man_ret))
  expect_lt(mean(abs(ref_ret - man_ret)), 2e-3)
})
