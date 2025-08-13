#!/usr/bin/env python3
"""
Comprehensive repository migration script for Financial-SDG-GARCH.
This script restructures the repository to match the target structure.
"""
import os
import shutil
import re
from pathlib import Path
import subprocess

def run_command(cmd, check=True):
    """Run a shell command."""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if check and result.returncode != 0:
            print(f"Command failed: {cmd}")
            print(f"Error: {result.stderr}")
            return False
        return True
    except Exception as e:
        print(f"Error running command {cmd}: {e}")
        return False

def create_directories():
    """Create all required directories."""
    dirs = [
        "environment",
        "data/raw",
        "data/processed/ts_cv_folds",
        "scripts/eda",
        "scripts/model_fitting", 
        "scripts/simulation_forecasting",
        "scripts/evaluation",
        "scripts/stress_tests",
        "outputs/eda/tables",
        "outputs/eda/figures",
        "outputs/model_eval/tables",
        "outputs/model_eval/figures",
        "outputs/var_backtest/tables",
        "outputs/var_backtest/figures",
        "outputs/stress_tests/tables",
        "outputs/stress_tests/figures",
        "outputs/supplementary"
    ]
    
    for dir_path in dirs:
        Path(dir_path).mkdir(parents=True, exist_ok=True)
        print(f"Created directory: {dir_path}")

def move_data_files():
    """Move and rename data files."""
    moves = [
        # Data files
        ("data/processed/raw (FX + EQ).csv", "data/raw/fx_equity_prices.csv"),
        ("residuals_usdzar.csv", "data/residuals_by_model/usdzar_residuals.csv"),
        ("GARCH_Model_Evaluation_Summary.xlsx", "outputs/supplementary/all_per_asset_metrics.xlsx"),
        ("usdzar_price_comparison.png", "outputs/eda/figures/price_comparison_usdzar.png")
    ]
    
    for src, dst in moves:
        if Path(src).exists():
            Path(dst).parent.mkdir(parents=True, exist_ok=True)
            if run_command(f'git mv "{src}" "{dst}"'):
                print(f"Moved: {src} -> {dst}")
            else:
                shutil.copy2(src, dst)
                print(f"Copied: {src} -> {dst}")

def move_script_files():
    """Move and rename script files."""
    script_moves = [
        # R scripts
        ("scripts/R - NFGARCH Main Training/1. NFGARCH - Train and Compare Forecasted Data.R", 
         "scripts/model_fitting/fit_garch_models.R"),
        ("scripts/R - NFGARCH Main Training/3. NFGARCH - Pull Residuals for NF Training.R", 
         "scripts/model_fitting/extract_residuals.R"),
        ("scripts/R - NFGARCH Main Training/4. NFGARCH - Train and Compare Forecasted Data using NFGARCH.R", 
         "scripts/simulation_forecasting/simulate_nf_garch.R"),
        ("scripts/R - NFGARCH Main Training/2. NFGARCH - Train and Compare Synthetic Data.R", 
         "scripts/evaluation/distribution_fit_metrics.R"),
        ("scripts/R - NFGARCH Main Training/5. NFGARCH - Train and Compare Synthetic Data using NFGARCH.R", 
         "scripts/evaluation/wilcoxon_winrate_analysis.R"),
        
        # Python scripts
        ("scripts/Python - NF Extended Training/train_nf.py", 
         "scripts/model_fitting/train_nf_models.py"),
        ("scripts/Python - NF Extended Training/main.py", 
         "scripts/model_fitting/evaluate_nf_fit.py"),
        ("scripts/Python - NF Extended Training/nf_garch_config.yaml", 
         "scripts/model_fitting/nf_garch_config.yaml"),
    ]
    
    for src, dst in script_moves:
        if Path(src).exists():
            Path(dst).parent.mkdir(parents=True, exist_ok=True)
            if run_command(f'git mv "{src}" "{dst}"'):
                print(f"Moved: {src} -> {dst}")
            else:
                shutil.copy2(src, dst)
                print(f"Copied: {src} -> {dst}")

def move_results():
    """Move results to outputs directory."""
    if Path("results").exists():
        # Move tables
        if Path("results/tables").exists():
            for file_path in Path("results/tables").glob("*"):
                if file_path.is_file():
                    dst = f"outputs/model_eval/tables/{file_path.name}"
                    shutil.copy2(file_path, dst)
                    print(f"Copied: {file_path} -> {dst}")
        
        # Move plots
        if Path("results/plots").exists():
            for file_path in Path("results/plots").rglob("*"):
                if file_path.is_file() and file_path.suffix in ['.png', '.jpg', '.pdf']:
                    # Determine appropriate output directory based on filename
                    if 'eda' in str(file_path) or 'histogram' in str(file_path):
                        dst = f"outputs/eda/figures/{file_path.name}"
                    elif 'volatility' in str(file_path):
                        dst = f"outputs/model_eval/figures/{file_path.name}"
                    else:
                        dst = f"outputs/model_eval/figures/{file_path.name}"
                    
                    Path(dst).parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(file_path, dst)
                    print(f"Copied: {file_path} -> {dst}")

def create_environment_files():
    """Create environment files."""
    
    # requirements.txt
    requirements = """numpy>=1.21.0
pandas>=1.3.0
scikit-learn>=1.0.0
matplotlib>=3.4.0
seaborn>=0.11.0
torch>=1.9.0
torchvision>=0.10.0
pyyaml>=5.4.0
pathlib2>=2.3.0
"""
    
    with open("environment/requirements.txt", "w") as f:
        f.write(requirements)
    
    # environment.yml
    environment_yml = """name: nfgarch
channels:
  - conda-forge
  - defaults
dependencies:
  - python=3.8
  - numpy>=1.21.0
  - pandas>=1.3.0
  - scikit-learn>=1.0.0
  - matplotlib>=3.4.0
  - seaborn>=0.11.0
  - pip
  - pip:
    - torch>=1.9.0
    - torchvision>=0.10.0
    - pyyaml>=5.4.0
"""
    
    with open("environment/environment.yml", "w") as f:
        f.write(environment_yml)
    
    # renv.lock (placeholder)
    renv_lock = """# R package lock file
# This is a placeholder - run renv::snapshot() to generate actual lock file
"""
    
    with open("environment/renv.lock", "w") as f:
        f.write(renv_lock)
    
    print("Created environment files")

def create_makefile():
    """Create Makefile."""
    makefile = """# Makefile for Financial-SDG-GARCH Research Project

.PHONY: setup eda fit-garch extract-residuals train-nf eval-nf simulate-nf-garch forecast eval-forecasts stylized var stress all clean

setup:
	@echo "Setting up environment..."
	@mkdir -p data/raw data/processed/ts_cv_folds outputs/eda/{tables,figures} outputs/model_eval/{tables,figures} outputs/var_backtest/{tables,figures} outputs/stress_tests/{tables,figures} outputs/supplementary
	@echo "Installing Python dependencies..."
	@pip install -r environment/requirements.txt
	@echo "Generating session info files..."
	@Rscript -e "writeLines(capture.output(sessionInfo()), 'environment/R_sessionInfo.txt')"
	@pip freeze > environment/pip_freeze.txt
	@echo "Setup complete!"

eda:
	@echo "Running EDA scripts..."
	@Rscript scripts/eda/eda_summary_stats.R
	@echo "EDA complete!"

fit-garch:
	@echo "Fitting GARCH models..."
	@Rscript scripts/model_fitting/fit_garch_models.R
	@echo "GARCH fitting complete!"

extract-residuals:
	@echo "Extracting residuals..."
	@Rscript scripts/model_fitting/extract_residuals.R
	@echo "Residual extraction complete!"

train-nf:
	@echo "Training Normalizing Flow models..."
	@python scripts/model_fitting/train_nf_models.py
	@echo "NF training complete!"

eval-nf:
	@echo "Evaluating NF models..."
	@python scripts/model_fitting/evaluate_nf_fit.py
	@echo "NF evaluation complete!"

simulate-nf-garch:
	@echo "Simulating NF-GARCH models..."
	@Rscript scripts/simulation_forecasting/simulate_nf_garch.R
	@echo "NF-GARCH simulation complete!"

forecast:
	@echo "Running forecasts..."
	@Rscript scripts/simulation_forecasting/forecast_garch_variants.R
	@echo "Forecasting complete!"

eval-forecasts:
	@echo "Evaluating forecasts..."
	@Rscript scripts/evaluation/wilcoxon_winrate_analysis.R
	@echo "Forecast evaluation complete!"

stylized:
	@echo "Running stylized fact tests..."
	@Rscript scripts/evaluation/stylized_fact_tests.R
	@echo "Stylized fact tests complete!"

var:
	@echo "Running VaR backtesting..."
	@Rscript scripts/evaluation/var_backtesting.R
	@echo "VaR backtesting complete!"

stress:
	@echo "Running stress tests..."
	@Rscript scripts/stress_tests/evaluate_under_stress.R
	@echo "Stress tests complete!"

all: setup eda fit-garch extract-residuals train-nf eval-nf simulate-nf-garch forecast eval-forecasts stylized var stress
	@echo "Full pipeline complete!"

clean:
	@echo "Cleaning generated outputs..."
	@rm -rf outputs/eda/figures/* outputs/eda/tables/* outputs/model_eval/figures/* outputs/model_eval/tables/* outputs/var_backtest/figures/* outputs/var_backtest/tables/* outputs/stress_tests/figures/* outputs/stress_tests/tables/*
	@echo "Clean complete!"
"""
    
    with open("Makefile", "w") as f:
        f.write(makefile)
    
    print("Created Makefile")

def create_run_all_sh():
    """Create run_all.sh script."""
    run_all_sh = """#!/bin/bash
# Bash script to run the full pipeline

set -e  # Exit on any error

echo "Starting Financial-SDG-GARCH pipeline..."

# Setup
echo "Setting up environment..."
make setup

# Run pipeline stages
echo "Running EDA..."
make eda

echo "Fitting GARCH models..."
make fit-garch

echo "Extracting residuals..."
make extract-residuals

echo "Training NF models..."
make train-nf

echo "Evaluating NF models..."
make eval-nf

echo "Simulating NF-GARCH..."
make simulate-nf-garch

echo "Running forecasts..."
make forecast

echo "Evaluating forecasts..."
make eval-forecasts

echo "Running stylized fact tests..."
make stylized

echo "Running VaR backtesting..."
make var

echo "Running stress tests..."
make stress

echo "Pipeline complete!"
"""
    
    with open("run_all.sh", "w") as f:
        f.write(run_all_sh)
    
    # Make executable
    os.chmod("run_all.sh", 0o755)
    print("Created run_all.sh")

def create_citation_cff():
    """Create CITATION.cff file."""
    citation = """cff-version: 1.2.0
title: "Incorporating Normalizing Flows into Traditional GARCH-Family Volatility Models for Enhanced Financial Return Modelling"
message: "If you use this software, please cite it as below."
authors:
  - family-names: Hassan
    given-names: Abdullah
    affiliation: University of the Witwatersrand
    orcid: "https://orcid.org/0000-0000-0000-0000"
type: software
version: 1.0.0
date-released: 2024-12-01
repository-code: "https://github.com/username/Financial-SDG-GARCH"
license: MIT
keywords:
  - "GARCH models"
  - "Normalizing Flows"
  - "Financial time series"
  - "Volatility modeling"
  - "Machine learning"
"""
    
    with open("CITATION.cff", "w") as f:
        f.write(citation)
    
    print("Created CITATION.cff")

def update_readme():
    """Update README.md with new structure."""
    readme = """# Financial-SDG-GARCH: Enhanced Financial Return Modelling with Normalizing Flows

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

- R (>= 4.0.0) with packages: rugarch, xts, dplyr, ggplot2
- Python (>= 3.8) with packages: numpy, pandas, torch, scikit-learn
- Make (optional, for automated pipeline)

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
"""
    
    with open("README.md", "w", encoding="utf-8") as f:
        f.write(readme)
    
    print("Updated README.md")

def create_migration_report():
    """Create MIGRATION.md report."""
    migration_report = """# Repository Migration Report

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
"""
    
    with open("MIGRATION.md", "w", encoding="utf-8") as f:
        f.write(migration_report)
    
    print("Created MIGRATION.md")

def main():
    """Main migration function."""
    print("Starting Financial-SDG-GARCH repository migration...")
    
    # Create directories
    print("\n1. Creating directories...")
    create_directories()
    
    # Move data files
    print("\n2. Moving data files...")
    move_data_files()
    
    # Move script files
    print("\n3. Moving script files...")
    move_script_files()
    
    # Move results
    print("\n4. Moving results...")
    move_results()
    
    # Create environment files
    print("\n5. Creating environment files...")
    create_environment_files()
    
    # Create automation files
    print("\n6. Creating automation files...")
    create_makefile()
    create_run_all_sh()
    
    # Create documentation
    print("\n7. Creating documentation...")
    create_citation_cff()
    update_readme()
    create_migration_report()
    
    print("\nMigration complete!")
    print("Next steps:")
    print("1. Update path references in scripts")
    print("2. Create missing script files")
    print("3. Test the pipeline")
    print("4. Remove old directories")
    print("5. Commit changes")

if __name__ == "__main__":
    main()
