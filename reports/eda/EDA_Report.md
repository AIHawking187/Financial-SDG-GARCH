# Financial Time Series EDA Report

**Generated:** 2025-08-14 21:13:22

**Data Source:** ./data/processed/raw (FX + EQ).csv

**Analysis Period:** 12 series analyzed

## Summary Statistics

| Series | Mean | Std | Skewness | Excess Kurtosis | JB p-value |
|--------|------|-----|----------|-----------------|------------|
| NVDA | 0.001382 | 0.031575 | -0.287 | 8.649 | 0.000 |
| MSFT | 0.000681 | 0.017770 | -0.070 | 8.778 | 0.000 |
| PG | 0.000367 | 0.011772 | -0.124 | 9.653 | 0.000 |
| CAT | 0.000524 | 0.020673 | -0.250 | 5.248 | 0.000 |
| WMT | 0.000447 | 0.013118 | -0.038 | 12.290 | 0.000 |
| AMZN | 0.000973 | 0.024435 | 0.395 | 12.284 | 0.000 |
| EURUSD | -0.000021 | 0.005863 | -0.093 | 4.268 | 0.000 |
| GBPUSD | -0.000067 | 0.006369 | -0.966 | 12.584 | 0.000 |
| GBPCNY | -0.000097 | 0.006175 | -0.548 | 9.945 | 0.000 |
| USDZAR | 0.000223 | 0.010845 | 0.555 | 4.132 | 0.000 |
| GBPZAR | 0.000155 | 0.009897 | 0.611 | 4.250 | 0.000 |
| EURZAR | 0.000201 | 0.009659 | 0.708 | 4.297 | 0.000 |

## Stationarity Tests

### ADF Test Results
| Series | ADF Statistic | p-value | Result |
|--------|---------------|---------|--------|
| NVDA | -22.003 | 0.000 | Stationary |
| MSFT | -23.891 | 0.000 | Stationary |
| PG | -18.109 | 0.000 | Stationary |
| CAT | -66.412 | 0.000 | Stationary |
| WMT | -16.697 | 0.000 | Stationary |
| AMZN | -49.718 | 0.000 | Stationary |
| EURUSD | -67.477 | 0.000 | Stationary |
| GBPUSD | -14.908 | 0.000 | Stationary |
| GBPCNY | -15.301 | 0.000 | Stationary |
| USDZAR | -18.511 | 0.000 | Stationary |
| GBPZAR | -24.758 | 0.000 | Stationary |
| EURZAR | -68.030 | 0.000 | Stationary |

### KPSS Test Results
| Series | KPSS Statistic | p-value | Result |
|--------|----------------|---------|--------|
| NVDA | 0.052 | 0.100 | Stationary |
| MSFT | 0.051 | 0.100 | Stationary |
| PG | 0.020 | 0.100 | Stationary |
| CAT | 0.028 | 0.100 | Stationary |
| WMT | 0.028 | 0.100 | Stationary |
| AMZN | 0.043 | 0.100 | Stationary |
| EURUSD | 0.051 | 0.100 | Stationary |
| GBPUSD | 0.041 | 0.100 | Stationary |
| GBPCNY | 0.029 | 0.100 | Stationary |
| USDZAR | 0.031 | 0.100 | Stationary |
| GBPZAR | 0.035 | 0.100 | Stationary |
| EURZAR | 0.028 | 0.100 | Stationary |

## Stylized Facts

| Series | Ljung-Box p-value | ARCH-LM p-value | Hill Index | Excess Kurtosis |
|--------|-------------------|-----------------|------------|------------------|
| NVDA | N/A | N/A | 3.108 | 8.649 |
| MSFT | N/A | N/A | 2.736 | 8.778 |
| PG | N/A | N/A | 2.499 | 9.653 |
| CAT | N/A | N/A | 2.779 | 5.248 |
| WMT | N/A | N/A | 2.480 | 12.290 |
| AMZN | N/A | N/A | 2.602 | 12.284 |
| EURUSD | N/A | N/A | 3.062 | 4.268 |
| GBPUSD | N/A | N/A | 3.077 | 12.584 |
| GBPCNY | N/A | N/A | 3.081 | 9.945 |
| USDZAR | N/A | N/A | 2.976 | 4.132 |
| GBPZAR | N/A | N/A | 3.248 | 4.250 |
| EURZAR | N/A | N/A | 2.743 | 4.297 |

## Interpretation Guide

### Summary Statistics
- **Skewness != 0:** Distribution is asymmetric
- **Excess Kurtosis > 0:** Heavier tails than normal
- **JB p-value < 0.05:** Reject normality

### Stationarity Tests
- **ADF p < 0.05:** Series is stationary (reject unit root)
- **KPSS p > 0.05:** Series is stationary (fail to reject stationarity)
- **Expected:** Price levels non-stationary, returns stationary

### Stylized Facts
- **Ljung-Box p < 0.05:** Evidence of serial correlation
- **ARCH-LM p < 0.05:** Evidence of volatility clustering (good for GARCH)
- **Hill Index > 3:** Heavy tails (Pareto-like distribution)

## Generated Plots

The following plots have been generated:

- `prices.png` - Price series over time
- `returns.png` - Return series over time
- `corr_heatmap.png` - Correlation matrix heatmap
- `acf_[series].png` - Autocorrelation function for each series
- `qq_[series].png` - QQ plots for each series

## Files Generated

- `artifacts/eda/summary_stats.csv` - Summary statistics
- `artifacts/eda/stationarity.csv` - Stationarity test results
- `artifacts/eda/stylized_facts.csv` - Stylized facts analysis
- `reports/eda/*.png` - All generated plots

