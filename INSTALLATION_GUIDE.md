# Quick Installation Guide for Financial-SDG-GARCH

## 🚀 **Super Quick Install (5 minutes)**

### **Step 1: Install R and Python**

#### **Windows:**
1. **R**: Download from https://cran.r-project.org/bin/windows/base/
2. **RStudio**: Download from https://posit.co/download/rstudio-desktop/
3. **Python**: Download from https://www.python.org/downloads/ (check "Add to PATH")

#### **Linux/Mac:**
```bash
# Ubuntu/Debian
sudo apt-get install r-base r-base-dev python3 python3-pip

# macOS
brew install r python3
```

### **Step 2: Run Installation Scripts**

Open a terminal/command prompt in your project directory and run:

```bash
# Install Python packages
python quick_install_python.py

# Install R packages
Rscript quick_install.R
```

### **Step 3: Test Installation**

```bash
# Quick test to verify everything works
Rscript scripts/simulation_forecasting/simulate_nf_garch_quick_test.R
```

### **Step 4: Run Full Pipeline**

```bash
# Windows
run_all.bat

# Linux/Mac
./run_all.sh
```

## 📋 **Detailed Installation Steps**

### **Prerequisites**

#### **System Requirements:**
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 2GB free space
- **OS**: Windows 10+, macOS 10.14+, or Linux
- **Internet**: Required for package downloads

#### **Software Requirements:**
- **R**: Version 4.0.0 or higher
- **Python**: Version 3.7 or higher
- **RStudio**: Recommended (but not required)

### **Step-by-Step Installation**

#### **1. Install R**

**Windows:**
1. Go to https://cran.r-project.org/bin/windows/base/
2. Download the latest R version for Windows
3. Run the installer
4. **Important**: Add R to your system PATH
   - Find your R installation (usually `C:\Program Files\R\R-4.x.x\bin`)
   - Add this path to your system environment variables

**Linux:**
```bash
sudo apt-get update
sudo apt-get install r-base r-base-dev
```

**macOS:**
```bash
brew install r
```

#### **2. Install RStudio (Optional but Recommended)**

1. Go to https://posit.co/download/rstudio-desktop/
2. Download for your operating system
3. Install and launch

#### **3. Install Python**

**Windows:**
1. Go to https://www.python.org/downloads/
2. Download the latest Python version
3. **Important**: Check "Add Python to PATH" during installation

**Linux:**
```bash
sudo apt-get install python3 python3-pip
```

**macOS:**
```bash
brew install python3
```

#### **4. Verify Installations**

Open a terminal/command prompt and run:

```bash
# Check R
Rscript --version

# Check Python
python --version

# Check pip
pip --version
```

### **Package Installation**

#### **Method 1: Automated Scripts (Recommended)**

```bash
# Install Python packages
python quick_install_python.py

# Install R packages
Rscript quick_install.R
```

#### **Method 2: Manual Installation**

**Python Packages:**
```bash
pip install numpy pandas scikit-learn matplotlib seaborn torch torchvision pyyaml pathlib2
```

**R Packages:**
Open R or RStudio and run:
```r
install.packages(c(
  "rugarch", "quantmod", "xts", "PerformanceAnalytics", "FinTS",
  "tidyverse", "dplyr", "tidyr", "stringr", "ggplot2", "openxlsx",
  "moments", "tseries", "forecast", "lmtest"
))
```

### **Verification**

#### **1. Environment Check**

Run the verification script:
```bash
Rscript scripts/utils/verify_pipeline_consistency.R
```

#### **2. Quick Test**

Test that everything works:
```bash
Rscript scripts/simulation_forecasting/simulate_nf_garch_quick_test.R
```

Expected output:
```
=== QUICK TEST RESULTS ===
Assets tested: 4
Models tested: 5
Total tests: 20
```

## 🔧 **Troubleshooting**

### **Common Issues**

#### **"Rscript not found"**
- **Solution**: Add R to your system PATH
- **Windows**: Add `C:\Program Files\R\R-4.x.x\bin` to PATH
- **Linux/Mac**: Ensure R is installed via package manager

#### **"Python not found"**
- **Solution**: Add Python to your system PATH
- **Windows**: Reinstall Python with "Add to PATH" checked
- **Linux/Mac**: Use `python3` instead of `python`

#### **Package Installation Failures**
- **Solution**: Update pip and setuptools
```bash
python -m pip install --upgrade pip setuptools
```

#### **R Package Installation Errors**
- **Solution**: Install system dependencies first
```bash
# Ubuntu/Debian
sudo apt-get install libcurl4-openssl-dev libssl-dev libxml2-dev

# macOS
brew install openssl libxml2
```

### **Performance Issues**

#### **Slow Package Installation**
- **Solution**: Use faster mirrors
```bash
# Python
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple package_name

# R
options(repos = c(CRAN = "https://cran.rstudio.com/"))
```

#### **Memory Issues**
- **Solution**: Close other applications and increase R memory limit
```r
memory.limit(size = 8000)  # 8GB limit
```

## ✅ **Installation Checklist**

- [ ] R installed and in PATH
- [ ] Python installed and in PATH
- [ ] RStudio installed (optional)
- [ ] Python packages installed
- [ ] R packages installed
- [ ] Quick test passes
- [ ] Pipeline verification passes

## 🎯 **Next Steps After Installation**

1. **Run Quick Test**: Verify everything works
2. **Explore Data**: Check your financial data files
3. **Run Full Pipeline**: Execute complete analysis
4. **Review Results**: Check outputs in `outputs/` directory

## 📞 **Getting Help**

If you encounter issues:

1. **Check the troubleshooting section above**
2. **Run verification scripts** to identify problems
3. **Check system requirements** and dependencies
4. **Ensure all paths are correctly set**

## 🚀 **Ready to Go!**

Once installation is complete, you can run:

```bash
# Quick test
Rscript scripts/simulation_forecasting/simulate_nf_garch_quick_test.R

# Full pipeline
run_all.bat  # Windows
./run_all.sh  # Linux/Mac
```

Your NF-GARCH pipeline with all 5 models is ready to use! 🎉
