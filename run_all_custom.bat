@echo off
echo Starting Financial-SDG-GARCH pipeline with custom paths...
echo.

echo Setting up environment...
echo Python: C:\Users\software\AppData\Local\Programs\Python\Python313\python.exe
echo R: C:\Program Files\R\R-4.5.1\bin\Rscript.exe
echo.

echo Installing Python dependencies...
"C:\Users\software\AppData\Local\Programs\Python\Python313\python.exe" -m pip install --upgrade pip
"C:\Users\software\AppData\Local\Programs\Python\Python313\python.exe" quick_install_python.py

echo.
echo Checking R environment...
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" --version

echo.
echo Running full NF-GARCH pipeline...

echo Step 1: Model Fitting...
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" scripts/model_fitting/fit_garch_models.R

echo Step 2: NF-GARCH Simulation...
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" scripts/simulation_forecasting/simulate_nf_garch.R

echo Step 3: Evaluation...
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" scripts/evaluation/evaluate_forecasts.R

echo Step 4: Stress Testing...
"C:\Program Files\R\R-4.5.1\bin\Rscript.exe" scripts/stress_tests/stress_test_models.R

echo.
echo Pipeline complete! Check outputs/ directory for results.
pause

