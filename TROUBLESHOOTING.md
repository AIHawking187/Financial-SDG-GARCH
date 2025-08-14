# Troubleshooting Guide for Financial-SDG-GARCH

This guide helps resolve common issues encountered when running the Financial-SDG-GARCH project.

## R Command Not Found Errors

### Problem
```
'Rscript' is not recognized as an internal or external command
```
or
```
R command not found
```

### Solutions

#### 1. Check R Installation (Windows)
Run the diagnostic script:
```cmd
scripts\utils\check_r_setup.bat
```

#### 2. Check R Installation (Linux/macOS)
Run the diagnostic script:
```bash
Rscript scripts/utils/setup_r_environment.R
```

#### 3. Manual R Installation

**Windows:**
1. Download R from: https://cran.r-project.org/bin/windows/base/
2. Install R (recommended: C:\Program Files\R\R-4.x.x\)
3. Add R bin directory to PATH:
   - Open System Properties → Advanced → Environment Variables
   - Add `C:\Program Files\R\R-4.x.x\bin\x64` to PATH
   - Restart command prompt

**Linux:**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install r-base r-base-dev

# CentOS/RHEL
sudo yum install R R-devel

# macOS
brew install r
```

#### 4. Alternative Execution Methods

If `Rscript` is not available, use these alternatives:

**Method 1: Direct R execution**
```bash
R --slave -e "source('scripts/eda/eda_summary_stats.R')"
```

**Method 2: Interactive R session**
```bash
R
> source('scripts/eda/eda_summary_stats.R')
> q()
```

**Method 3: RStudio**
Open scripts directly in RStudio and run them interactively.

## Package Installation Issues

### Problem
```
Error in library(package_name): there is no package called 'package_name'
```

### Solutions

#### 1. Install Required Packages
Run the setup script:
```r
source('scripts/utils/setup_r_environment.R')
```

#### 2. Manual Package Installation
```r
# Core packages
install.packages(c("rugarch", "xts", "dplyr", "tidyr", "ggplot2"))

# Financial packages
install.packages(c("quantmod", "tseries", "PerformanceAnalytics", "FinTS"))

# Utility packages
install.packages(c("openxlsx", "stringr", "forecast", "transport", "fmsb", "moments"))
```

#### 3. CRAN Mirror Issues
If packages fail to install, try different CRAN mirrors:
```r
chooseCRANmirror()
# Select a mirror close to your location
```

## File Path Issues

### Problem
```
cannot open file './data/raw/raw.csv': No such file or directory
```

### Solutions

#### 1. Check File Structure
Ensure the following files exist:
- `./data/raw/raw (FX).csv`
- `./data/raw/raw (EQ).csv`
- `./data/processed/raw (FX + EQ).csv`

#### 2. Update File Paths
All scripts have been updated to use correct file paths. If you encounter this error:
1. Check that data files are in the correct locations
2. Ensure file names match exactly (including spaces)
3. Run from the project root directory

## Memory Issues

### Problem
```
Error: cannot allocate vector of size X Mb
```

### Solutions

#### 1. Increase Memory Limit
```r
# Increase memory limit (Windows)
memory.limit(size = 8000)  # 8GB

# Check available memory
memory.size()
```

#### 2. Optimize Data Loading
- Use `data.table` for large datasets
- Load only required columns
- Process data in chunks

## Performance Issues

### Problem
Scripts run very slowly or hang

### Solutions

#### 1. Check System Resources
- Monitor CPU and memory usage
- Close unnecessary applications
- Ensure sufficient disk space

#### 2. Optimize Execution
- Run scripts individually instead of full pipeline
- Use parallel processing where available
- Reduce data size for testing

## Common Error Messages

### "Error in rugarch::qdist"
**Solution:** Use robust distribution functions from `scripts/utils/safety_functions.R`

### "Error in bind_rows"
**Solution:** Use `add_row_safe()` function for safe row binding

### "Model failed to converge"
**Solution:** 
- Check data quality
- Try different starting values
- Use simpler model specifications

## Getting Help

### 1. Run Diagnostics
```bash
# Windows
scripts\utils\check_r_setup.bat

# Linux/macOS
Rscript scripts/utils/setup_r_environment.R
```

### 2. Check Logs
- Review error messages carefully
- Check R session info: `environment/R_sessionInfo.txt`
- Check Python environment: `environment/pip_freeze.txt`

### 3. Common Commands
```bash
# Check R version
R --version

# Check Rscript availability
Rscript --version

# Check working directory
pwd

# List files in data directory
ls data/raw/
```

### 4. Environment Information
When reporting issues, include:
- Operating system and version
- R version (`R --version`)
- Python version (`python --version`)
- Error messages and stack traces
- Contents of `environment/R_sessionInfo.txt`

## Prevention

### 1. Regular Maintenance
- Keep R and packages updated
- Regularly clean temporary files
- Monitor disk space

### 2. Best Practices
- Always run from project root directory
- Use version control for code changes
- Test scripts with small datasets first
- Keep environment files updated

### 3. Documentation
- Update `ai.md` with new conventions
- Document any custom configurations
- Note any workarounds used
