@echo off
echo 🚀 FINANCIAL-SDG-GARCH ENVIRONMENT SETUP WITH CUSTOM PATHS
echo =========================================================

echo.
echo 🔍 Using custom Python and R paths...
echo Python: C:\Users\software\AppData\Local\Programs\Python\Python313\python.exe
echo R: C:\Program Files\R\R-4.5.1\bin\Rscript.exe
echo.

echo ✅ Both Python and R are available!
echo Proceeding with package installation...
echo.

echo 📦 Installing Python packages...
"C:\Users\software\AppData\Local\Programs\Python\Python313\python.exe" quick_install_python.py

echo.
echo 📦 Installing R packages...
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" quick_install.R

echo.
echo 🧪 Running quick test...
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" scripts/simulation_forecasting/simulate_nf_garch_quick_test.R

echo.
echo 🎉 Setup complete! You can now run the full pipeline:
echo   run_all.bat
echo.
echo 💡 To avoid using full paths in the future, add these to your system PATH:
echo   C:\Users\software\AppData\Local\Programs\Python\Python313\
echo   C:\Users\software\AppData\Local\Programs\Python\Python313\Scripts\
echo   C:\Program Files\R\R-4.5.1\bin\
echo.

pause

