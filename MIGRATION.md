# Repository Migration Report

## Overview

This document details the migration of the Financial-SDG-GARCH repository from its original structure to a clean, auditable, and fully reproducible research package.

## Migration Summary

### Before Migration
```
Financial-SDG-GARCH/
├── scripts/
│   ├── R - NFGARCH Main Training/
│   ├── Python - NF Main Training/
│   └── Python - NF Extended Training/
├── data/
│   └── processed/
├── results/
├── residuals_by_model/
├── nf_generated_residuals/
└── [various loose files]
```

### After Migration
```
Financial-SDG-GARCH/
├── data/
│   ├── raw/
│   ├── processed/
│   └── residuals_by_model/
├── scripts/
│   ├── eda/
│   ├── model_fitting/
│   ├── simulation_forecasting/
│   ├── evaluation/
│   └── stress_tests/
├── outputs/
│   ├── eda/
│   ├── model_eval/
│   ├── var_backtest/
│   ├── stress_tests/
│   └── supplementary/
├── environment/
├── Makefile
└── run_all.sh
```

## File Mappings

### Data Files
| Original | New Location | Notes |
|----------|--------------|-------|
| `data/processed/raw (FX + EQ).csv` | `data/raw/fx_equity_prices.csv` | Renamed for clarity |
| `residuals_usdzar.csv` | `data/residuals_by_model/usdzar_residuals.csv` | Moved to residuals directory |
| `GARCH_Model_Evaluation_Summary.xlsx` | `outputs/supplementary/all_per_asset_metrics.xlsx` | Moved to outputs |

### Script Files
| Original | New Location | Purpose |
|----------|--------------|---------|
| `1. NFGARCH - Train and Compare Forecasted Data.R` | `scripts/model_fitting/fit_garch_models.R` | GARCH model fitting |
| `3. NFGARCH - Pull Residuals for NF Training.R` | `scripts/model_fitting/extract_residuals.R` | Residual extraction |
| `4. NFGARCH - Train and Compare Forecasted Data using NFGARCH.R` | `scripts/simulation_forecasting/simulate_nf_garch.R` | NF-GARCH simulation |
| `2. NFGARCH - Train and Compare Synthetic Data.R` | `scripts/evaluation/distribution_fit_metrics.R` | Distribution evaluation |
| `5. NFGARCH - Train and Compare Synthetic Data using NFGARCH.R` | `scripts/evaluation/wilcoxon_winrate_analysis.R` | Statistical tests |
| `train_nf.py` | `scripts/model_fitting/train_nf_models.py` | NF model training |
| `main.py` | `scripts/model_fitting/evaluate_nf_fit.py` | NF evaluation |

### Residual Files
All NF residual files from `nf_generated_residuals/` were moved to `data/residuals_by_model/` with standardized naming:
- Pattern: `{config}_{asset_type}_{asset}_residuals_synthetic.csv`
- Config names standardized to lowercase (e.g., `sgarch`, `egarch`, `gjrgarch`, `tgarch`)
- Asset names kept in uppercase (e.g., `USDZAR`, `NVDA`)

## Path Updates Required

### R Scripts
The following path references need to be updated in R scripts:
- `./data/processed/raw (FX + EQ).csv` → `here::here("data", "raw", "fx_equity_prices.csv")`
- `results/plots/` → `here::here("outputs", "eda", "figures")` or `here::here("outputs", "model_eval", "figures")`
- `nf_generated_residuals/` → `here::here("data", "residuals_by_model")`

### Python Scripts
The following path references need to be updated in Python scripts:
- `results/` → `Path(__file__).resolve().parents[1] / "outputs"`
- Relative paths should use `Path(__file__).resolve().parents[1]` for project root

## New Files Created

### Environment Files
- `environment/requirements.txt`: Python dependencies
- `environment/environment.yml`: Conda environment
- `environment/renv.lock`: R package lock file (placeholder)
- `environment/R_sessionInfo.txt`: R session information
- `environment/pip_freeze.txt`: Python package versions

### Automation Files
- `Makefile`: Automated pipeline with targets for each stage
- `run_all.sh`: Bash script for running the full pipeline

### Documentation
- `CITATION.cff`: Citation information for the research
- Updated `README.md`: Comprehensive project documentation

## Manual TODOs

1. **Path Updates**: Update all hardcoded paths in R and Python scripts to use the new structure
2. **Missing Scripts**: Create missing scripts for:
   - `scripts/eda/eda_stylized_facts.R`
   - `scripts/eda/plot_correlation_heatmap.R`
   - `scripts/simulation_forecasting/forecast_garch_variants.R`
   - `scripts/simulation_forecasting/evaluate_forecasts.R`
   - `scripts/evaluation/stylized_fact_tests.R`
   - `scripts/evaluation/var_backtesting.R`
   - `scripts/stress_tests/define_historical_scenarios.R`
   - `scripts/stress_tests/inject_hypothetical_shocks.R`
   - `scripts/stress_tests/evaluate_under_stress.R`
   - `scripts/stress_tests/plot_stress_responses.R`

3. **Environment Setup**: 
   - Generate actual `renv.lock` file using `renv::snapshot()`
   - Verify all Python dependencies are correctly specified

4. **Testing**: 
   - Test `make setup` and `make eda` to ensure pipeline works
   - Verify all scripts can find their required data files

## Git History Preservation

All file moves were performed using `git mv` where possible to preserve git history. For files that couldn't be moved with git mv, copies were made and the originals should be removed after verification.

## Next Steps

1. Update all path references in scripts
2. Create missing script files
3. Test the pipeline end-to-end
4. Remove old directories and files
5. Commit the restructured repository
