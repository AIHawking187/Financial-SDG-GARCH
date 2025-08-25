@echo off
echo 🚀 FINANCIAL-SDG-GARCH ENVIRONMENT SETUP FOR WINDOWS
echo ===================================================

echo.
echo 🔍 Checking Python installation...
python --version >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Python found
    set PYTHON_AVAILABLE=1
) else (
    echo ❌ Python not found
    set PYTHON_AVAILABLE=0
)

echo.
echo 🔍 Checking R installation...
Rscript --version >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ R found
    set R_AVAILABLE=1
) else (
    echo ❌ R not found
    set R_AVAILABLE=0
)

echo.
if %PYTHON_AVAILABLE% equ 1 if %R_AVAILABLE% equ 1 (
    echo ✅ Both Python and R are available!
    echo Proceeding with package installation...
    echo.
    
    echo 📦 Installing Python packages...
    python quick_install_python.py
    
    echo.
    echo 📦 Installing R packages...
    Rscript quick_install.R
    
    echo.
    echo 🧪 Running quick test...
    Rscript scripts/simulation_forecasting/simulate_nf_garch_quick_test.R
    
    echo.
    echo 🎉 Setup complete! You can now run the full pipeline:
    echo   run_all.bat
) else (
    echo ❌ Missing required software:
    if %PYTHON_AVAILABLE% equ 0 (
        echo   - Python is not installed or not in PATH
    )
    if %R_AVAILABLE% equ 0 (
        echo   - R is not installed or not in PATH
    )
    
    echo.
    echo 📋 INSTALLATION INSTRUCTIONS FOR WINDOWS
    echo ========================================
    echo.
    echo 🔧 Installing Python:
    echo 1. Go to https://www.python.org/downloads/
    echo 2. Download the latest Python version
    echo 3. Run the installer
    echo 4. ⚠️  IMPORTANT: Check 'Add Python to PATH' during installation
    echo 5. Complete the installation
    echo.
    echo 🔧 Installing R:
    echo 1. Go to https://cran.r-project.org/bin/windows/base/
    echo 2. Download the latest R version for Windows
    echo 3. Run the installer
    echo 4. ⚠️  IMPORTANT: Add R to your system PATH
    echo    - Find your R installation (usually C:\Program Files\R\R-4.x.x\bin)
    echo    - Add this path to your system environment variables
    echo.
    echo 🔧 Installing RStudio (Optional but Recommended):
    echo 1. Go to https://posit.co/download/rstudio-desktop/
    echo 2. Download RStudio for Windows
    echo 3. Install and launch
    echo.
    echo 🔄 After installation:
    echo 1. Close and reopen your command prompt
    echo 2. Run this script again to verify installation
    echo 3. The script will automatically install required packages
    echo.
    echo 🌐 Would you like to open the download pages?
    echo 1. Python: https://www.python.org/downloads/
    echo 2. R: https://cran.r-project.org/
    echo 3. RStudio: https://posit.co/download/rstudio-desktop/
    echo.
    set /p choice="Enter choice (1-3) or press Enter to skip: "
    if "%choice%"=="1" start https://www.python.org/downloads/
    if "%choice%"=="2" start https://cran.r-project.org/
    if "%choice%"=="3" start https://posit.co/download/rstudio-desktop/
)

echo.
pause

