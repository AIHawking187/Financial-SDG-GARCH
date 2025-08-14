# Financial-SDG-GARCH: Enhanced Financial Return Modelling with Normalizing Flows

## Overview

This repository contains the implementation and evaluation of incorporating Normalizing Flows into traditional GARCH-family volatility models for enhanced financial return modelling, particularly for FX and equity time series.

## Research Question

Can incorporating Normalizing Flows into traditional GARCH-family volatility models significantly improve the realism, flexibility, and empirical fidelity of financial return modelling, particularly for FX and equity time series?

## Repository Structure

```
Financial-SDG-GARCH/
├── data/
│   ├── raw/                    # Raw price data
│   ├── processed/              # Processed returns and splits
│   └── residuals_by_model/     # GARCH residuals by model type
├── scripts/
│   ├── eda/                    # Exploratory data analysis
│   ├── model_fitting/          # GARCH and NF model fitting
│   ├── simulation_forecasting/ # NF-GARCH simulation and forecasting
│   ├── evaluation/             # Model evaluation and comparison
│   └── stress_tests/           # Stress testing scenarios
├── outputs/
│   ├── eda/                    # EDA tables and figures
│   ├── model_eval/             # Model evaluation results
│   ├── var_backtest/           # VaR backtesting results
│   ├── stress_tests/           # Stress test results
│   └── supplementary/          # Additional results and summaries
└── environment/                # Environment configuration files
```

## Quick Start

### Prerequisites

- R (>= 4.0.0) with packages: rugarch, xts, dplyr, ggplot2, quantmod, tseries, PerformanceAnalytics, FinTS, openxlsx, stringr, forecast, transport, fmsb, moments
- Python (>= 3.8) with packages: numpy, pandas, torch, scikit-learn
- Make (optional, for automated pipeline)

### Troubleshooting

If you encounter "R command not found" errors:

**Windows:**
```cmd
scripts\utils\check_r_setup.bat
```

**Linux/macOS:**
```bash
Rscript scripts/utils/setup_r_environment.R
```

For detailed troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/username/Financial-SDG-GARCH.git
   cd Financial-SDG-GARCH
   ```

2. Set up the environment:
   ```bash
   make setup
   ```

### Running the Pipeline

#### Full Pipeline
```bash
make all
```

#### Individual Stages
```bash
make eda              # Exploratory data analysis
make fit-garch        # Fit GARCH models
make extract-residuals # Extract residuals
make train-nf         # Train Normalizing Flow models
make eval-nf          # Evaluate NF models
make simulate-nf-garch # Simulate NF-GARCH models
make forecast         # Generate forecasts
make eval-forecasts   # Evaluate forecasts
make stylized         # Stylized fact tests
make var              # VaR backtesting
make stress           # Stress tests
```

#### Alternative: Bash Script
```bash
./run_all.sh
```

## Data

### Raw Data
- `data/raw/fx_equity_prices.csv`: Historical price data for FX and equity assets

### Processed Data
- `data/processed/returns.csv`: Calculated returns
- `data/processed/chrono_split_train.csv`: Training data (chronological split)
- `data/processed/chrono_split_test.csv`: Test data (chronological split)
- `data/processed/ts_cv_folds/`: Time series cross-validation folds

### Residuals
- `data/residuals_by_model/`: GARCH residuals organized by model type and asset

## Models

### GARCH Models
- sGARCH (Standard GARCH)
- eGARCH (Exponential GARCH)
- gjrGARCH (Glosten-Jagannathan-Runkle GARCH)
- TGARCH (Threshold GARCH)

### Normalizing Flows
- RealNVP (Real-valued Non-Volume Preserving)
- MAF (Masked Autoregressive Flow)

## Results

### Key Findings
- NF-GARCH models show improved forecast accuracy
- Enhanced tail behavior modeling
- Better stylized fact replication

### Output Files
- `outputs/supplementary/all_per_asset_metrics.xlsx`: Comprehensive model comparison
- `outputs/supplementary/all_rolling_cv_results.xlsx`: Cross-validation results

## Citation

If you use this software in your research, please cite:

```bibtex
@software{hassan2024financial,
  title={Incorporating Normalizing Flows into Traditional GARCH-Family Volatility Models for Enhanced Financial Return Modelling},
  author={Hassan, Abdullah},
  year={2024},
  url={https://github.com/username/Financial-SDG-GARCH}
}
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact

- Author: Abdullah Hassan
- Institution: University of the Witwatersrand
- Email: [your-email@example.com]

## Acknowledgments

This research was conducted as part of an MSc in Mathematical Statistics at the University of the Witwatersrand.
