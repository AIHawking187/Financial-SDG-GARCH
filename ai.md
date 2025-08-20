# Financial-SDG-GARCH Project

## Project Overview
This project implements a comprehensive financial synthetic data generation pipeline using GARCH (Generalized Autoregressive Conditional Heteroskedasticity) models combined with Normalizing Flows (NF). The goal is to generate realistic synthetic financial time series data that preserves the statistical properties of real financial markets.

## Architecture and Key Technologies

### Core Technologies
- **R**: Primary language for statistical modeling, GARCH implementations, and analysis
- **Python**: Used for Normalizing Flow implementation and deep learning components
- **R Packages**: `rugarch`, `quantmod`, `xts`, `PerformanceAnalytics`, `FinTS`, `tidyverse`, `dplyr`, `tidyr`, `stringr`, `ggplot2`, `openxlsx`, `moments`, `tseries`, `forecast`, `lmtest`
- **Python Packages**: `numpy`, `pandas`, `scikit-learn`, `matplotlib`, `seaborn`, `torch`, `torchvision`, `pyyaml`, `pathlib2`

### GARCH Models Implemented
The pipeline now supports **ALL 5 GARCH model variants** with **dual engine support**:
1. **sGARCH_norm**: Standard GARCH with normal distribution
2. **sGARCH_sstd**: Standard GARCH with skewed Student's t distribution
3. **eGARCH**: Exponential GARCH with asymmetric effects
4. **gjrGARCH**: Glosten-Jagannathan-Runkle GARCH with leverage effects
5. **TGARCH**: Threshold GARCH with regime-dependent behavior

**Engine Options:**
- **rugarch**: Standard implementation using the `rugarch` package (default)
- **manual**: Custom implementation from scratch with CLI switch support

### Asset Classes
- **FX (Foreign Exchange)**: EURUSD, GBPUSD, GBPCNY, USDZAR, GBPZAR, EURZAR
- **Equity**: NVDA, MSFT, PG, CAT, WMT, AMZN

## Directory Structure

```
Financial-SDG-GARCH/
├── data/
│   ├── processed/          # Cleaned price data
│   ├── raw/               # Raw price data
│   └── residuals_by_model/ # GARCH residuals organized by model
├── nf_generated_residuals/ # Synthetic residuals from NF training
├── outputs/               # Analysis results and visualizations
├── results/               # Model outputs and plots
├── scripts/
│   ├── eda/              # Exploratory data analysis
│   ├── evaluation/       # Model evaluation and testing
│   ├── model_fitting/    # GARCH model fitting and residual extraction
│   ├── simulation_forecasting/ # NF-GARCH simulation and forecasting
│   ├── stress_tests/     # Stress testing scenarios
│   ├── manual_garch/     # Manual GARCH implementation
│   ├── engines/          # Engine selector and compatibility layer
│   └── utils/            # Utility functions including CLI parser
└── environment/          # Environment configuration files
```

## Key Components and Their Relationships

### 1. Data Pipeline
- **Raw Data**: Historical price data for FX and equity assets
- **Data Cleaning**: Returns calculation and preprocessing
- **Data Splitting**: Chronological (65/35) and Time-Series Cross-Validation splits

### 2. GARCH Model Fitting
- **Model Specification**: 5 GARCH variants with different distributions
- **Parameter Estimation**: Maximum likelihood estimation using `rugarch`
- **Residual Extraction**: Standardized residuals for NF training

### 3. Normalizing Flow Training
- **Residual Processing**: Loading GARCH residuals for each model-asset combination
- **NF Model Training**: Training individual NF models on each residual set
- **Synthetic Generation**: Generating synthetic residuals from trained NFs

### 4. NF-GARCH Simulation
- **Dual Engine Support**: Both `rugarch` and manual implementations
- **Engine Selector**: Uniform API for seamless switching between engines
- **Manual Simulation**: Custom implementation replacing `ugarchpath`
- **Residual Injection**: Injecting synthetic residuals into GARCH models
- **Performance Evaluation**: MSE, MAE, AIC, BIC metrics

### 5. Comprehensive Evaluation
- **Forecasting**: Out-of-sample forecasting for all GARCH variants
- **Stylized Facts**: Testing for financial market characteristics
- **VaR Backtesting**: Value-at-Risk calculations and validation
- **Stress Testing**: Model performance under crisis scenarios

## Development Guidelines and Conventions

### Code Organization
- **R Scripts**: Use consistent naming with descriptive prefixes
- **Python Scripts**: Follow PEP 8 style guidelines
- **Configuration**: Use YAML files for experiment settings
- **Documentation**: Maintain comprehensive comments and docstrings

### Model Configuration Standard
All scripts use the standardized 5-model configuration:
```r
model_configs <- list(
  sGARCH_norm  = list(model = "sGARCH", distribution = "norm", submodel = NULL),
  sGARCH_sstd  = list(model = "sGARCH", distribution = "sstd", submodel = NULL),
  gjrGARCH     = list(model = "gjrGARCH", distribution = "sstd", submodel = NULL),
  eGARCH       = list(model = "eGARCH", distribution = "sstd", submodel = NULL),
  TGARCH       = list(model = "fGARCH", distribution = "sstd", submodel = "TGARCH")
)
```

### Engine Selection
The pipeline supports two engines with CLI switch:
```bash
# Use rugarch engine (default)
Rscript simulate_nf_garch_engine.R --engine rugarch

# Use manual engine
Rscript simulate_nf_garch_engine.R --engine manual

# Use config file
Rscript simulate_nf_garch_engine.R --config config.yaml
```

### File Naming Conventions
- **NF Residuals**: `{GARCH_TYPE}_{ASSET_TYPE}_{ASSET}_residuals_synthetic.csv`
- **Results**: Organized by model type and asset class
- **Plots**: Descriptive names with model and asset identifiers

## Environment Configuration

### R Environment
```r
# Required packages
install.packages(c("rugarch", "quantmod", "xts", "PerformanceAnalytics", 
                   "FinTS", "tidyverse", "dplyr", "tidyr", "stringr", 
                   "ggplot2", "openxlsx", "moments", "tseries", 
                   "forecast", "lmtest"))
```

### Python Environment
```bash
pip install -r environment/requirements.txt
# or
conda env create -f environment/environment.yml
```

## Error Handling Approach

### Robust Model Fitting
- **Convergence Checks**: Verify GARCH model convergence
- **Fallback Mechanisms**: Manual simulation when `ugarchpath` fails
- **Error Logging**: Comprehensive error messages and warnings
- **Graceful Degradation**: Continue processing when individual models fail

### Data Validation
- **Input Validation**: Check data quality and completeness
- **Missing Data Handling**: Appropriate treatment of NA values
- **Outlier Detection**: Identify and handle extreme values

## Security Considerations

### Data Privacy
- **No Sensitive Data**: Only use publicly available financial data
- **Local Processing**: All computations performed locally
- **Secure Storage**: No external data transmission

### Code Security
- **No Hardcoded Credentials**: Use environment variables if needed
- **Input Sanitization**: Validate all user inputs
- **Dependency Management**: Use specific package versions

## Testing Requirements

### Unit Testing
- **Model Fitting**: Test each GARCH variant independently
- **NF Training**: Validate Normalizing Flow implementations
- **Simulation**: Verify manual GARCH simulation accuracy

### Integration Testing
- **Pipeline Flow**: Test complete end-to-end pipeline
- **Cross-Platform**: Ensure compatibility across operating systems
- **Performance**: Monitor execution time and resource usage

### Validation Testing
- **Statistical Tests**: Verify synthetic data properties
- **Stylized Facts**: Ensure synthetic data preserves market characteristics
- **Backtesting**: Validate VaR and forecasting accuracy

## Global Instructions for Maintaining Code Consistency

### 1. Model Configuration Updates
When adding new GARCH models:
- Update `model_configs` in ALL relevant scripts
- Ensure consistent naming across the pipeline
- Update documentation and configuration files

### 2. Asset Coverage
When adding new assets:
- Update asset lists in data loading scripts
- Ensure NF residuals are generated for all combinations
- Update evaluation scripts to include new assets

### 3. Pipeline Integration
When modifying scripts:
- Maintain backward compatibility
- Update Makefile and batch scripts
- Test complete pipeline execution

### 4. Error Handling
Always implement:
- Try-catch blocks for model fitting
- Graceful handling of convergence failures
- Comprehensive error logging

### 5. Performance Optimization
- Use efficient data structures (XTS for time series)
- Implement parallel processing where appropriate
- Monitor memory usage for large datasets

## Current Status (Updated)

### ✅ Completed Components
- **Full 5-Model GARCH Pipeline**: All GARCH variants implemented and tested
- **Complete NF Residual Coverage**: All model-asset combinations have synthetic residuals
- **Comprehensive Evaluation**: Forecasting, stylized facts, VaR, and stress testing
- **Robust Error Handling**: Manual simulation fallbacks and convergence checks
- **Cross-Platform Support**: Windows batch scripts and Unix makefiles

### 🔧 Recent Fixes
- **Naming Convention Resolution**: Fixed missing eGARCH, gjrGARCH, and TGARCH residuals
- **Manual Simulation**: Replaced problematic `ugarchpath` with custom implementation
- **Quick Testing**: Added comprehensive testing framework for pipeline validation

### 📊 Pipeline Coverage
- **Models**: 5 GARCH variants (sGARCH_norm, sGARCH_sstd, eGARCH, gjrGARCH, TGARCH)
- **Assets**: 12 total (6 FX + 6 Equity)
- **Splits**: Chronological and Time-Series Cross-Validation
- **NF Residuals**: ~240 files covering all combinations
- **Evaluation**: 4 comprehensive analysis stages

### 🚀 Ready for Production
The pipeline is now fully functional and ready for:
- Complete synthetic data generation
- Comprehensive model comparison
- Robust statistical validation
- Production-scale analysis

## Quick Start Guide

1. **Setup Environment**:
   ```bash
   # Windows
   run_all.bat
   
   # Linux/Mac
   ./run_all.sh
   ```

2. **Run Quick Test**:
   ```bash
   Rscript scripts/simulation_forecasting/simulate_nf_garch_quick_test.R
   ```

3. **Full Pipeline**:
   ```bash
   # Windows
   run_all.bat
   
   # Linux/Mac
   make all
   ```

The pipeline will automatically process all 5 GARCH models across all assets, generate synthetic data, and provide comprehensive evaluation results.
