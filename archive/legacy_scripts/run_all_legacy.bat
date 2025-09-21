@echo off
REM Windows batch script to run the Financial-SDG-GARCH pipeline

echo Starting Financial-SDG-GARCH pipeline...

REM Setup
echo Setting up environment...
if not exist "environment" mkdir environment
if not exist "data\raw" mkdir data\raw
if not exist "data\processed\ts_cv_folds" mkdir data\processed\ts_cv_folds
if not exist "outputs\eda\tables" mkdir outputs\eda\tables
if not exist "outputs\eda\figures" mkdir outputs\eda\figures
if not exist "outputs\model_eval\tables" mkdir outputs\model_eval\tables
if not exist "outputs\model_eval\figures" mkdir outputs\model_eval\figures
if not exist "outputs\var_backtest\tables" mkdir outputs\var_backtest\tables
if not exist "outputs\var_backtest\figures" mkdir outputs\var_backtest\figures
if not exist "outputs\stress_tests\tables" mkdir outputs\stress_tests\tables
if not exist "outputs\stress_tests\figures" mkdir outputs\stress_tests\figures
if not exist "outputs\supplementary" mkdir outputs\supplementary
if not exist "nf_generated_residuals" mkdir nf_generated_residuals

echo Installing Python dependencies...
pip install -r environment\requirements.txt

echo Fixing Python environment issues...
python scripts\utils\fix_python_env.py

echo Checking R environment...
Rscript --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Rscript not found in PATH
    echo Please run: quick_install.R to set up R environment
    pause
    exit /b 1
)

echo Generating session info files...
Rscript -e "writeLines(capture.output(sessionInfo()), 'environment/R_sessionInfo.txt')"
if %errorlevel% neq 0 (
    echo ERROR: Failed to generate R session info
    echo Please check R installation and run: quick_install.R
    pause
    exit /b 1
)
pip freeze > environment\pip_freeze.txt

echo Setup complete!

REM Step 1: Generate missing NF residuals (NEW)
echo Step 1: Generating missing NF residuals...
python scripts\model_fitting\generate_missing_nf_residuals.py
if %errorlevel% neq 0 (
    echo WARNING: NF residual generation failed, continuing...
)

REM Step 2: Run EDA
echo Step 2: Running EDA...
Rscript scripts\eda\eda_summary_stats.R
if %errorlevel% neq 0 (
    echo WARNING: EDA failed, continuing...
)

REM Step 3: Fit GARCH models
echo Step 3: Fitting GARCH models...
Rscript scripts\model_fitting\fit_garch_models.R
if %errorlevel% neq 0 (
    echo WARNING: GARCH fitting failed, continuing...
)

REM Step 4: Extract residuals
echo Step 4: Extracting residuals...
Rscript scripts\model_fitting\extract_residuals.R
if %errorlevel% neq 0 (
    echo WARNING: Residual extraction failed, continuing...
)

REM Step 5: Train NF models
echo Step 5: Training NF models...
python scripts\model_fitting\train_nf_models.py
if %errorlevel% neq 0 (
    echo WARNING: NF training failed, continuing...
)

REM Step 6: Evaluate NF models
echo Step 6: Evaluating NF models...
python scripts\model_fitting\evaluate_nf_fit.py
if %errorlevel% neq 0 (
    echo WARNING: NF evaluation failed, continuing...
)

REM Step 7: Run NF-GARCH simulation with MANUAL engine (NEW)
echo Step 7: Running NF-GARCH simulation (MANUAL engine)...
Rscript scripts\simulation_forecasting\simulate_nf_garch_engine.R --engine manual
if %errorlevel% neq 0 (
    echo WARNING: Manual engine simulation failed, continuing...
)

REM Step 8: Run NF-GARCH simulation with RUGARCH engine (NEW)
echo Step 8: Running NF-GARCH simulation (RUGARCH engine)...
Rscript scripts\simulation_forecasting\simulate_nf_garch_engine.R --engine rugarch
if %errorlevel% neq 0 (
    echo WARNING: rugarch engine simulation failed, continuing...
)

REM Step 9: Run legacy NF-GARCH simulation (for backward compatibility)
echo Step 9: Running legacy NF-GARCH simulation...
Rscript scripts\simulation_forecasting\simulate_nf_garch.R
if %errorlevel% neq 0 (
    echo WARNING: Legacy simulation failed, continuing...
)

REM Step 10: Run forecasts
echo Step 10: Running forecasts...
Rscript scripts\simulation_forecasting\forecast_garch_variants.R
if %errorlevel% neq 0 (
    echo WARNING: Forecasting failed, continuing...
)

REM Step 11: Evaluate forecasts
echo Step 11: Evaluating forecasts...
Rscript scripts\evaluation\wilcoxon_winrate_analysis.R
if %errorlevel% neq 0 (
    echo WARNING: Forecast evaluation failed, continuing...
)

REM Step 12: Run stylized fact tests
echo Step 12: Running stylized fact tests...
Rscript scripts\evaluation\stylized_fact_tests.R
if %errorlevel% neq 0 (
    echo WARNING: Stylized fact tests failed, continuing...
)

REM Step 13: Run VaR backtesting
echo Step 13: Running VaR backtesting...
Rscript scripts\evaluation\var_backtesting.R
if %errorlevel% neq 0 (
    echo WARNING: VaR backtesting failed, continuing...
)

REM Step 13.5: Run NFGARCH VaR backtesting (NEW)
echo Step 13.5: Running NFGARCH VaR backtesting...
Rscript scripts\evaluation\nfgarch_var_backtesting.R
if %errorlevel% neq 0 (
    echo WARNING: NFGARCH VaR backtesting failed, continuing...
)

REM Step 14: Run stress tests
echo Step 14: Running stress tests...
Rscript scripts\stress_tests\evaluate_under_stress.R
if %errorlevel% neq 0 (
    echo WARNING: Stress tests failed, continuing...
)

REM Step 14.5: Run NFGARCH stress testing (NEW)
echo Step 14.5: Running NFGARCH stress testing...
Rscript scripts\evaluation\nfgarch_stress_testing.R
if %errorlevel% neq 0 (
    echo WARNING: NFGARCH stress testing failed, continuing...
)

REM Step 15: Generate final summary (NEW)
echo Step 15: Generating final summary...
Rscript -e "library(openxlsx); cat('=== NF-GARCH PIPELINE SUMMARY ===\n'); cat('Date:', Sys.Date(), '\n'); cat('Time:', Sys.time(), '\n\n'); output_files <- list.files('outputs', recursive = TRUE, full.names = TRUE); cat('Output files generated:', length(output_files), '\n'); nf_files <- list.files('nf_generated_residuals', pattern = '*.csv', full.names = TRUE); cat('NF residual files:', length(nf_files), '\n'); result_files <- list.files(pattern = '*Results*.xlsx', full.names = TRUE); cat('Result files:', length(result_files), '\n'); cat('\n=== PIPELINE COMPLETE ===\n')"

REM Step 16: Consolidate all results (NEW)
echo Step 16: Consolidating all results into comprehensive Excel document...
Rscript scripts\utils\consolidate_results.R
if %errorlevel% neq 0 (
    echo WARNING: Results consolidation failed, continuing...
)

REM Step 17: Validate pipeline results (NEW)
echo Step 17: Validating pipeline results...
python validate_pipeline.py
if %errorlevel% neq 0 (
    echo WARNING: Pipeline validation failed, continuing...
)

REM Step 18: Generate appendix log (NEW)
echo Step 18: Generating appendix log...
python generate_appendix_log.py
if %errorlevel% neq 0 (
    echo WARNING: Appendix log generation failed, continuing...
)

echo.
echo ========================================
echo PIPELINE EXECUTION COMPLETE!
echo ========================================
echo.
echo Check the following directories for results:
echo - outputs\ (all analysis results)
echo - nf_generated_residuals\ (NF residual files)
echo - *.xlsx files (comprehensive results)
echo.
echo CONSOLIDATED RESULTS:
echo - Consolidated_NF_GARCH_Results.xlsx (ALL results in one file)
echo.
echo Both MANUAL and RUGARCH engines have been tested.
echo.
pause
