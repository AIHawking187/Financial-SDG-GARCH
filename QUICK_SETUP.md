# 🚀 Quick Setup Guide for Financial-SDG-GARCH

## ⚡ Super Quick Start (5 minutes)

### **Option 1: Automated Setup (Recommended)**

#### **Windows:**
```bash
# Run the automated setup script
setup_environment.bat
```

#### **Linux/Mac:**
```bash
# Run the automated setup script
python3 setup_environment.py
```

### **Option 2: Manual Setup**

If the automated scripts don't work, follow these steps:

#### **Step 1: Install Required Software**

**Python:**
- **Windows**: Download from [python.org](https://www.python.org/downloads/) (check "Add to PATH")
- **Linux**: `sudo apt-get install python3 python3-pip`
- **macOS**: `brew install python3`

**R:**
- **Windows**: Download from [CRAN](https://cran.r-project.org/bin/windows/base/)
- **Linux**: `sudo apt-get install r-base r-base-dev`
- **macOS**: `brew install r`

#### **Step 2: Install Packages**

```bash
# Install Python packages
python quick_install_python.py

# Install R packages
Rscript quick_install.R
```

#### **Step 3: Test Installation**

```bash
# Run quick test
Rscript scripts/simulation_forecasting/simulate_nf_garch_quick_test.R
```

#### **Step 4: Run Full Pipeline**

```bash
# Windows
run_all.bat

# Linux/Mac
./run_all.sh
```

## 📋 What This Project Does

The Financial-SDG-GARCH project implements a comprehensive financial synthetic data generation pipeline using:

- **5 GARCH Models**: sGARCH_norm, sGARCH_sstd, eGARCH, gjrGARCH, TGARCH
- **12 Assets**: 6 FX pairs + 6 Equity stocks
- **Normalizing Flows**: For synthetic data generation
- **Comprehensive Evaluation**: Forecasting, VaR, stress testing

## 🔧 System Requirements

- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 2GB free space
- **OS**: Windows 10+, macOS 10.14+, or Linux
- **Internet**: Required for package downloads

## 📦 Required Software

### **Python (3.7+)**
- numpy, pandas, scikit-learn
- matplotlib, seaborn
- torch, torchvision
- pyyaml, pathlib2

### **R (4.0+)**
- rugarch, quantmod, xts
- PerformanceAnalytics, FinTS
- tidyverse, dplyr, tidyr
- ggplot2, openxlsx
- moments, tseries, forecast, lmtest

## 🚨 Troubleshooting

### **Common Issues**

#### **"Python not found"**
- **Solution**: Install Python and add to PATH
- **Windows**: Check "Add Python to PATH" during installation
- **Linux/Mac**: Use `python3` instead of `python`

#### **"Rscript not found"**
- **Solution**: Install R and add to PATH
- **Windows**: Add R bin directory to system PATH
- **Linux/Mac**: Install via package manager

#### **Package Installation Failures**
- **Solution**: Update pip and setuptools
```bash
python -m pip install --upgrade pip setuptools
```

#### **R Package Errors**
- **Solution**: Install system dependencies
```bash
# Ubuntu/Debian
sudo apt-get install libcurl4-openssl-dev libssl-dev libxml2-dev

# macOS
brew install openssl libxml2
```

### **Performance Issues**

#### **Slow Installation**
- Use faster mirrors:
```bash
# Python
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple package_name

# R
options(repos = c(CRAN = "https://cran.rstudio.com/"))
```

#### **Memory Issues**
- Close other applications
- Increase R memory limit:
```r
memory.limit(size = 8000)  # 8GB limit
```

## ✅ Installation Checklist

- [ ] Python installed and in PATH
- [ ] R installed and in PATH
- [ ] Python packages installed
- [ ] R packages installed
- [ ] Quick test passes
- [ ] Pipeline verification passes

## 🎯 What Happens After Setup

1. **Data Processing**: Historical financial data is loaded and cleaned
2. **GARCH Modeling**: 5 GARCH variants are fitted to each asset
3. **NF Training**: Normalizing Flows learn residual distributions
4. **Synthetic Generation**: Realistic synthetic data is generated
5. **Evaluation**: Comprehensive statistical validation
6. **Results**: Outputs saved to `outputs/` directory

## 📊 Expected Outputs

After running the pipeline, you'll find:

- **Synthetic Data**: `nf_generated_residuals/`
- **Model Results**: `results/`
- **Analysis Plots**: `outputs/`
- **Performance Metrics**: Various CSV and RDS files

## 🔄 Quick Commands

```bash
# Check environment
python setup_environment.py

# Quick test
Rscript scripts/simulation_forecasting/simulate_nf_garch_quick_test.R

# Full pipeline
run_all.bat  # Windows
./run_all.sh  # Linux/Mac

# Individual components
Rscript scripts/model_fitting/fit_garch_models.R
Rscript scripts/simulation_forecasting/simulate_nf_garch.R
Rscript scripts/evaluation/evaluate_forecasts.R
```

## 📞 Getting Help

If you encounter issues:

1. **Check troubleshooting section above**
2. **Run verification scripts** to identify problems
3. **Check system requirements** and dependencies
4. **Ensure all paths are correctly set**

## 🎉 Ready to Go!

Once setup is complete, you can:

- Generate synthetic financial data
- Compare 5 different GARCH models
- Perform comprehensive statistical analysis
- Run stress tests and backtesting
- Create publication-ready visualizations

Your NF-GARCH pipeline with all 5 models is ready to use! 🚀

