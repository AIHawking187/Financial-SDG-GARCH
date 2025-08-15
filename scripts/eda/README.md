# EDA for Financial Time Series

This directory contains comprehensive Exploratory Data Analysis (EDA) tools for financial time series data, specifically designed for FX and equity markets.

## Quick Start

### Python Version (Recommended)

1. **Install dependencies:**
   ```bash
   pip install -r scripts/eda/requirements.txt
   ```

2. **Run the analysis:**
   ```bash
   python scripts/eda/eda_finance.py --config scripts/eda/configs/eda.yaml
   ```

## What the EDA Covers

### 📊 Summary Statistics
- **Mean, Variance, Skewness, Excess Kurtosis**
- **Jarque-Bera test** for normality
- **Per-series analysis** for all assets

### 🧪 Statistical Tests
- **Stationarity Tests:**
  - ADF (Augmented Dickey-Fuller) on levels and returns
  - KPSS (Kwiatkowski-Phillips-Schmidt-Shin) on levels and returns
- **Stylized Facts:**
  - Ljung-Box test for serial correlation
  - ARCH-LM test for volatility clustering
  - Hill tail index for heavy tails

### 📈 Visualizations
- **Time Series Plots:** Price levels and returns over time
- **Correlation Heatmap:** Return correlations between assets
- **ACF/PACF Plots:** Autocorrelation and partial autocorrelation functions
- **QQ Plots:** Quantile-quantile plots vs normal distribution

### 📋 Outputs

#### CSV Tables (`artifacts/eda/`)
- `summary_stats.csv` - Basic statistics for each series
- `stationarity.csv` - ADF and KPSS test results
- `stylized_facts.csv` - Ljung-Box, ARCH-LM, and tail index results

#### Plots (`reports/eda/`)
- `prices.png` - Price series over time
- `returns.png` - Return series over time
- `corr_heatmap.png` - Correlation matrix heatmap
- `acf_[series].png` - Autocorrelation function for each series
- `pacf_[series].png` - Partial autocorrelation function for each series
- `qq_[series].png` - QQ plots for each series

#### Reports
- `EDA_Report.md` - Comprehensive Markdown report

## Configuration

Edit `scripts/eda/configs/eda.yaml` to customize the analysis:

```yaml
input_csv: "../../data/processed/raw (FX + EQ).csv"
return_type: "log"  # "log" or "simple"
plots:
  timeseries: true
  returns: true
  acf_pacf: true
  qq: true
  heatmap: true
tests:
  lb_lags: 20
  arch_lm_lags: 12
tails:
  hill_threshold_quantile: 0.95
```

## Interpretation Guide

### Summary Statistics
- **Skewness ≠ 0:** Distribution is asymmetric
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

## Example Results

For typical financial data, you should expect:
- **Returns:** Stationary, non-normal, with volatility clustering
- **FX pairs:** Lower correlations than equities
- **Equities:** Higher correlations, especially within sectors
- **All series:** Heavy tails and ARCH effects

## Troubleshooting

### Common Issues

1. **"No such file or directory"**
   - Ensure data file exists at specified path
   - Check file permissions

2. **"Package not found"**
   - Install missing packages: `pip install package_name`

3. **Memory issues with large datasets**
   - Reduce number of series in config
   - Use resampling (e.g., weekly instead of daily)

### Performance Tips

- **Large datasets:** Consider resampling to weekly/monthly
- **Many series:** Process in batches
- **Memory:** Close other applications during analysis

## Integration with GARCH Models

The EDA results help validate GARCH model assumptions:

1. **Stationarity:** Returns should be stationary (ADF p < 0.05)
2. **ARCH Effects:** Should be present (ARCH-LM p < 0.05)
3. **Non-normality:** Expected for financial returns
4. **Heavy Tails:** Consider skewed-t or other heavy-tailed distributions

## Testing

Run unit tests for the Hill estimator:

```bash
python scripts/eda/tests/test_tails.py
```

## Contributing

To extend the EDA framework:

1. Add new statistical tests to the appropriate function
2. Update the configuration schema
3. Add corresponding visualization functions
4. Update the report generation
5. Add unit tests for new functionality

## References

- **ADF Test:** Dickey, D.A. & Fuller, W.A. (1979)
- **KPSS Test:** Kwiatkowski, D. et al. (1992)
- **ARCH-LM Test:** Engle, R.F. (1982)
- **Hill Estimator:** Hill, B.M. (1975)
- **Ljung-Box Test:** Ljung, G.M. & Box, G.E.P. (1978)
