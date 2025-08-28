@echo off
echo ========================================
echo    Financial-SDG-GARCH Setup Guide
echo ========================================
echo.

echo This guide will help you set up and run the NF-GARCH pipeline.
echo.

echo Step 1: Check if R is installed...
Rscript --version >nul 2>&1
if %errorlevel% equ 0 (
    echo ✓ R is installed and working
) else (
    echo ✗ R is not found. Please install R from: https://cran.r-project.org/
    echo   After installation, run: quick_install.R
    pause
    exit /b 1
)

echo.
echo Step 2: Check if Python is installed...
python --version >nul 2>&1
if %errorlevel% equ 0 (
    echo ✓ Python is installed and working
) else (
    echo ✗ Python is not found. Please install Python from: https://python.org/
    echo   After installation, run: quick_install_python.py
    pause
    exit /b 1
)

echo.
echo Step 3: Install required packages...
echo Installing R packages...
Rscript quick_install.R
if %errorlevel% neq 0 (
    echo WARNING: R package installation had issues
)

echo Installing Python packages...
python quick_install_python.py
if %errorlevel% neq 0 (
    echo WARNING: Python package installation had issues
)

echo.
echo ========================================
echo    Setup Complete! 
echo ========================================
echo.
echo Next steps:
echo.
echo 1. Run the full pipeline:
echo    run_all.bat
echo.
echo 2. Or use the modular pipeline:
echo    run_modular.bat
echo.
echo 3. Check results in:
echo    Consolidated_NF_GARCH_Results.xlsx
echo.
echo For detailed instructions, see README.md
echo.
pause
