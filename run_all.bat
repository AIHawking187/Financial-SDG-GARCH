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

echo Installing Python dependencies...
pip install -r environment\requirements.txt

echo Generating session info files...
Rscript -e "writeLines(capture.output(sessionInfo()), 'environment/R_sessionInfo.txt')"
pip freeze > environment\pip_freeze.txt

echo Setup complete!

REM Run pipeline stages
echo Running EDA...
Rscript scripts\eda\eda_summary_stats.R

echo Fitting GARCH models...
Rscript scripts\model_fitting\fit_garch_models.R

echo Extracting residuals...
Rscript scripts\model_fitting\extract_residuals.R

echo Training NF models...
python scripts\model_fitting\train_nf_models.py

echo Evaluating NF models...
python scripts\model_fitting\evaluate_nf_fit.py

echo Simulating NF-GARCH...
Rscript scripts\simulation_forecasting\simulate_nf_garch.R

echo Running forecasts...
Rscript scripts\simulation_forecasting\forecast_garch_variants.R

echo Evaluating forecasts...
Rscript scripts\evaluation\wilcoxon_winrate_analysis.R

echo Running stylized fact tests...
Rscript scripts\evaluation\stylized_fact_tests.R

echo Running VaR backtesting...
Rscript scripts\evaluation\var_backtesting.R

echo Running stress tests...
Rscript scripts\stress_tests\evaluate_under_stress.R

echo Pipeline complete!
pause
