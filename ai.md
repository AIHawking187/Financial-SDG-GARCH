# Financial Synthetic Data Generation (GARCH + GAN) Project

## Project Overview

This repository implements a comprehensive framework for generating synthetic financial data using GARCH-family models and comparing their performance across different asset classes (equity and foreign exchange). The project aims to create realistic synthetic financial time series that preserve the statistical properties of real market data.

## Purpose and Goals

- **Synthetic Data Generation**: Create realistic synthetic financial time series using GARCH models
- **Model Comparison**: Evaluate different GARCH variants (sGARCH, eGARCH, gjrGARCH, TGARCH) across multiple assets
- **Cross-Asset Analysis**: Compare model performance between equity and FX markets
- **Forecasting Evaluation**: Assess model forecasting accuracy and volatility prediction capabilities
- **Future GAN Integration**: Framework designed to incorporate GAN-based synthetic data generation

## Architecture and Key Technologies

### Core Technologies
- **R**: Primary programming language for statistical modeling
- **Python**: Advanced NF implementation and deep learning
- **rugarch**: GARCH model implementation and estimation
- **quantmod**: Financial data retrieval and manipulation
- **xts**: Time series data handling
- **PerformanceAnalytics**: Financial performance metrics
- **ggplot2**: Data visualization
- **PyTorch/TensorFlow**: Deep learning frameworks for NF models
- **RealNVP/NSF**: Normalizing Flow architectures

### GARCH Models Implemented
1. **sGARCH** (Standard GARCH): Basic GARCH(1,1) with normal and skewed-t distributions
2. **eGARCH** (Exponential GARCH): Captures asymmetric volatility effects
3. **gjrGARCH** (Glosten-Jagannathan-Runkle GARCH): Models leverage effects
4. **TGARCH** (Threshold GARCH): Captures regime-dependent volatility

### Asset Classes
- **Equity**: NVDA, MSFT, PG, CAT, WMT, AMZN, AAPL, DJT, MLGO, PDCO
- **FX**: EURUSD, GBPUSD, GBPCNY, USDZAR, GBPZAR, EURZAR

## Directory Structure

```
Financial-SDG-GARCH/
├── data/
│   └── processed/
│       └── raw (FX + EQ).csv          # Consolidated price data (2005-2024)
├── scripts/
│   ├── garch/                         # Original GARCH implementation
│   │   ├── 0. NFGARCH - Source EQ data and perform checks.R
│   │   ├── 1. NFGARCH - Train and Compare Forecasted Data.R
│   │   ├── 2. NFGARCH - Train and Compare Synthetic Data.R
│   │   └── GARCH Comparison Scripts/
│   │       ├── Exhaustive GARCH Comparison.R
│   │       └── Simplified GARCH Comparison.R
│   ├── R - NFGARCH Main Training/     # Enhanced R implementation
│   │   ├── 0-5. NFGARCH scripts (enhanced versions)
│   │   └── GARCH Comparison Scripts/
│   ├── Python - NF Main Training/     # Python NF implementation
│   │   └── NFGARCH - Train all Residuals.ipynb
│   └── Python - NF Extended Training/ # Advanced Python NF framework
│       ├── main.py                    # Main execution script
│       ├── train_nf.py                # NF training utilities
│       ├── nf_garch_config.yaml       # Configuration file
│       └── utils/
│           ├── data_utils.py          # Data loading utilities
│           ├── flow_utils.py          # NF model utilities
│           └── garch_utils.py         # GARCH integration utilities
├── results/
│   ├── plots/                         # Generated visualizations
│   │   ├── exhaustive/                # Comprehensive analysis plots
│   │   ├── equity_[model]/            # Equity-specific results
│   │   └── fx_[model]/                # FX-specific results
│   └── tables/
│       └── garch_comparison.csv       # Model performance metrics
├── residuals_by_model/                # Model residuals by GARCH variant
│   ├── sGARCH_norm/                   # Standard GARCH with normal distribution
│   ├── sGARCH_sstd/                   # Standard GARCH with skewed-t distribution
│   ├── eGARCH/                        # Exponential GARCH residuals
│   ├── gjrGARCH/                      # GJR-GARCH residuals
│   └── TGARCH/                        # Threshold GARCH residuals
├── nf_generated_residuals/            # Synthetic residuals and data
├── residuals_usdzar.csv               # USDZAR specific residuals
├── usdzar_price_comparison.png        # Price comparison visualization
├── GARCH_Model_Evaluation_Summary.xlsx # Excel summary of results
├── Masters - NFGARCH.Rproj            # RStudio project file
├── LICENSE                            # MIT License
└── .gitignore                         # Git ignore patterns
```

## Key Components and Their Relationships

### 1. Data Pipeline
- **Data Sourcing**: Automated retrieval of equity data via quantmod
- **Data Cleaning**: Standardization of FX and equity price series
- **Quality Checks**: Volume analysis, missing data detection, date range validation
- **Consolidation**: Unified CSV format for both asset classes

### 2. Model Training Framework
- **Specification Generator**: Dynamic GARCH model specification creation
- **Multi-Asset Training**: Parallel processing across all assets and models
- **Distribution Handling**: Support for normal and skewed-t distributions
- **Cross-Validation**: Time series cross-validation for robust evaluation

### 3. Evaluation Metrics
- **Information Criteria**: AIC, BIC for model selection
- **Forecast Accuracy**: MSE, MAE for volatility predictions
- **Diagnostic Tests**: Q-statistic, ARCH-LM for residual analysis
- **Likelihood Comparison**: Log-likelihood for model fit assessment

### 4. Synthetic Data Generation
- **Residual Simulation**: Generation of synthetic residuals from fitted models
- **Volatility Reconstruction**: Back-transformation to price series
- **Statistical Validation**: Comparison of real vs synthetic data properties

### 5. Normalizing Flow Integration
- **NF Model Training**: RealNVP, NSF, and other flow architectures
- **Residual Learning**: NF models trained on GARCH residuals
- **Hybrid Generation**: Combination of GARCH and NF approaches
- **Advanced Evaluation**: Distribution distance metrics and statistical tests

## Development Guidelines and Conventions

### Code Organization
- **Sequential Scripts**: Numbered execution order (0, 1, 2)
- **Modular Functions**: Reusable components for model generation and evaluation
- **Consistent Naming**: Asset-model-distribution naming convention
- **Error Handling**: Graceful handling of model convergence issues

### Data Management
- **Structured Outputs**: Organized results by model type and asset class
- **Reproducible Seeds**: Fixed random seeds for consistent results
- **Version Control**: Comprehensive tracking of all generated outputs

### Performance Optimization
- **Parallel Processing**: Efficient handling of multiple assets and models
- **Memory Management**: Streamlined data structures for large datasets
- **Caching**: Intermediate results storage to avoid recomputation

## Environment Configuration

### Required R Packages
```r
# Core statistical packages
rugarch, quantmod, xts, PerformanceAnalytics, FinTS

# Data manipulation
tidyverse, dplyr, tidyr, stringr

# Visualization
ggplot2

# File handling
openxlsx
```

### Required Python Packages
```python
# Deep learning frameworks
torch, tensorflow, numpy

# Normalizing flows
nflows, normflows, pytorch-flows

# Data manipulation
pandas, numpy, scipy

# Visualization
matplotlib, seaborn, plotly

# Configuration
pyyaml, argparse
```

### Data Requirements
- **Equity Data**: Yahoo Finance via quantmod (2005-2024)
- **FX Data**: CSV format with daily exchange rates
- **Minimum Observations**: Sufficient data for GARCH estimation (~1000+ observations)

## Error Handling Approach

### Model Convergence
- **Fallback Strategies**: Alternative specifications for failed models
- **Diagnostic Logging**: Detailed error reporting for debugging
- **Graceful Degradation**: Continue processing other assets/models

### Data Quality Issues
- **Missing Data Handling**: Interpolation or exclusion strategies
- **Outlier Detection**: Statistical methods for identifying anomalies
- **Volume Validation**: Trading volume checks for data quality

## Security Considerations

### Data Privacy
- **Public Data Only**: All financial data from public sources
- **No Sensitive Information**: No proprietary or confidential data
- **Reproducible Research**: All data sources documented and accessible

### Code Security
- **No Hardcoded Credentials**: API keys or credentials not stored in code
- **Input Validation**: Robust handling of user inputs and data files
- **Error Message Sanitization**: No sensitive information in error outputs

## Testing Requirements

### Model Validation
- **Residual Analysis**: Q-statistic and ARCH-LM tests
- **Forecast Evaluation**: Out-of-sample testing procedures
- **Cross-Validation**: Time series CV for robust performance assessment

### Data Quality Tests
- **Completeness Checks**: Missing data detection and reporting
- **Consistency Validation**: Cross-reference between data sources
- **Statistical Tests**: Normality, stationarity, and autocorrelation tests

## Global Instructions for Maintaining Code Consistency

### Code Style
- **Consistent Indentation**: 2-space indentation throughout
- **Function Documentation**: Clear parameter descriptions and return values
- **Variable Naming**: Descriptive names following R conventions
- **Comment Standards**: Inline comments for complex logic

### File Path Conventions
- **FX Data File**: Always use `"./data/raw/raw (FX).csv"` (with space and parentheses)
- **Consolidated Data**: Use `"./data/processed/raw (FX + EQ).csv"` for combined datasets
- **Path Validation**: Verify file paths exist before running scripts to avoid "No such file or directory" errors

### Robust Distribution Functions
- **Use `rugarch::qdist("sstd", ...)` instead of `qsstd(...)`**: Ensures consistent parameter handling
- **Use `rugarch::ddist("sstd", ...)` for density functions**: Robust density calculation
- **Use `rugarch::pdist("sstd", ...)` for CDF functions**: Reliable cumulative distribution
- **Use `rugarch::rdist("sstd", ...)` for random generation**: Safe random number generation
- **Fallback to normal distribution**: If sstd functions fail, automatically fall back to normal

### Safety Functions
- **`add_row_safe()`**: Prevents summary tables from crashing when models return no rows
- **Usage**: `reduce(add_row_safe, init = data.frame(), list_of_dataframes)`
- **Location**: `./scripts/utils/safety_functions.R`
- **Source in scripts**: Add `source("./scripts/utils/safety_functions.R")` to library imports

### R Installation and Path Configuration
- **R Installation**: Ensure R (>= 4.0.0) is installed and accessible from command line
- **Rscript Path**: Verify `Rscript` command is available in system PATH
- **Windows**: Add R installation directory to PATH environment variable
- **Linux/macOS**: Ensure R is installed via package manager or official installer
- **Package Dependencies**: Install required R packages before running scripts:
  ```r
  install.packages(c("rugarch", "xts", "dplyr", "tidyr", "ggplot2", "quantmod", 
                     "tseries", "PerformanceAnalytics", "FinTS", "openxlsx", 
                     "stringr", "forecast", "transport", "fmsb", "moments"))
  ```
- **Troubleshooting**: If `Rscript` not found, check R installation and PATH configuration
- **Alternative**: Use `R --slave -e "source('script.R')"` instead of `Rscript script.R`

### Version Control
- **Atomic Commits**: Logical grouping of related changes
- **Descriptive Messages**: Clear commit messages explaining changes
- **Branch Strategy**: Feature branches for major developments

### Documentation Updates
- **README Maintenance**: Keep project overview current
- **Code Comments**: Update inline documentation with changes
- **Result Tracking**: Document new findings and model improvements

### Performance Monitoring
- **Execution Time Tracking**: Monitor script performance
- **Memory Usage**: Track resource consumption
- **Scalability Testing**: Validate with larger datasets

## Future Development Roadmap

### Phase 1: GAN Integration
- **GAN Architecture**: Design for financial time series
- **Training Pipeline**: Integration with existing GARCH framework
- **Comparison Framework**: GAN vs GARCH performance evaluation

### Phase 2: Advanced Features
- **Multi-Variate Models**: DCC-GARCH and copula approaches
- **Real-Time Processing**: Streaming data capabilities
- **API Development**: RESTful interface for model access

### Phase 3: Production Deployment
- **Containerization**: Docker deployment for reproducibility
- **Cloud Integration**: AWS/Azure deployment options
- **Monitoring Dashboard**: Real-time model performance tracking
