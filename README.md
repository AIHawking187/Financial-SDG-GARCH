## Financial Synthetic Data Generation (GARCH + GAN)

A practical implementation of Synthetic Financial Data Generation for FX and EQ datasets using ARCH and GARCH.

This repo contains scripts and data used to generate synthetic FX and equity return data using GARCH-family models and (coming soon) GANs.

### Structure
- `data/`: Input datasets
- `scripts/`: Code for models (GARCH in R; GAN in future)
- `results/`: Forecast plots and model evaluations
- `reports/`: Notes and writeups for publication

### To Run
Open `Test Garch and GAN - Automatic.R` and run from top. Ensure the `rugarch`, `quantmod`, `PerformanceAnalytics`, etc., packages are installed.

### Output
- GARCH evaluation metrics are saved in `results/tables/garch_comparison.csv`
- Forecast volatility plots are generated into `results/plots/`
