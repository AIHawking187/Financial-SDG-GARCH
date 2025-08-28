@echo off
REM Modular Pipeline Execution Script
REM Allows independent execution of pipeline components with checkpointing

echo ========================================
echo MODULAR NF-GARCH PIPELINE
echo ========================================

if "%1"=="" (
    echo Running full modular pipeline...
    Rscript scripts\modular_pipeline\run_modular_pipeline.R
) else if "%1"=="status" (
    echo Checking pipeline status...
    Rscript scripts\modular_pipeline\run_modular_pipeline.R status
) else if "%1"=="run" (
    if "%2"=="" (
        echo ERROR: Please specify a component to run
        echo Available components:
        echo   nf_residual_generation, data_prep, garch_fitting
        echo   residual_extraction, nf_training, nf_evaluation
        echo   nf_garch_manual, nf_garch_rugarch, legacy_nf_garch
        echo   forecasting, forecast_evaluation, var_backtesting
        echo   stress_testing, stylized_facts, final_summary
        echo   consolidation
    ) else (
        echo Running component: %2
        Rscript scripts\modular_pipeline\run_modular_pipeline.R run %2
    )
) else if "%1"=="reset" (
    if "%2"=="" (
        echo ERROR: Please specify a component to reset
        echo Available components:
        echo   nf_residual_generation, data_prep, garch_fitting
        echo   residual_extraction, nf_training, nf_evaluation
        echo   nf_garch_manual, nf_garch_rugarch, legacy_nf_garch
        echo   forecasting, forecast_evaluation, var_backtesting
        echo   stress_testing, stylized_facts, final_summary
        echo   consolidation
    ) else (
        echo Resetting component: %2
        Rscript scripts\modular_pipeline\run_modular_pipeline.R reset %2
    )
) else if "%1"=="help" (
    echo.
    echo USAGE:
    echo   run_modular.bat                    - Run full pipeline
    echo   run_modular.bat status             - Show pipeline status
    echo   run_modular.bat run <component>    - Run specific component
    echo   run_modular.bat reset <component>  - Reset component
    echo   run_modular.bat help               - Show this help
    echo.
    echo COMPONENTS:
    echo   nf_residual_generation - Generate missing NF residuals
    echo   data_prep           - Data loading and preprocessing
    echo   garch_fitting       - Standard GARCH model fitting
    echo   residual_extraction - Extract residuals for NF training
    echo   nf_training         - Python NF model training
    echo   nf_evaluation       - NF model evaluation
    echo   nf_garch_manual     - NF-GARCH with manual engine
    echo   nf_garch_rugarch    - NF-GARCH with rugarch engine
    echo   legacy_nf_garch     - Legacy NF-GARCH simulation
    echo   forecasting         - Forecasting evaluation
    echo   forecast_evaluation - Evaluate forecasts (Wilcoxon)
    echo   var_backtesting     - VaR backtesting
    echo   stress_testing      - Stress testing
    echo   stylized_facts      - Stylized facts analysis
    echo   final_summary       - Generate final summary
    echo   consolidation       - Final results consolidation
    echo.
    echo EXAMPLES:
    echo   run_modular.bat run nf_garch_manual
    echo   run_modular.bat reset nf_training
    echo   run_modular.bat status
    echo.
) else (
    echo ERROR: Unknown command '%1'
    echo Run 'run_modular.bat help' for usage information
)

echo.
pause
