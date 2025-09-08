# Makefile for Financial-SDG-GARCH Research Project

.PHONY: setup eda fit-garch extract-residuals train-nf eval-nf simulate-nf-garch forecast eval-forecasts stylized var stress all clean

setup:
	@echo "Setting up environment..."
	@mkdir -p data/raw data/processed/ts_cv_folds outputs/eda/{tables,figures} outputs/model_eval/{tables,figures} outputs/var_backtest/{tables,figures} outputs/stress_tests/{tables,figures} outputs/supplementary
	@echo "Installing Python dependencies..."
	@pip install -r environment/requirements.txt
	@echo "Checking R environment..."
	@which Rscript >/dev/null 2>&1 || (echo "WARNING: Rscript not found in PATH. Please run 'scripts/utils/check_r_setup.bat' (Windows) or ensure R is installed and in PATH." && exit 1)
	@echo "Generating session info files..."
	@Rscript -e "writeLines(capture.output(sessionInfo()), 'environment/R_sessionInfo.txt')" || (echo "ERROR: Failed to generate R session info. Check R installation." && exit 1)
	@pip freeze > environment/pip_freeze.txt
	@echo "Setup complete!"

eda:
	@echo "Running EDA scripts..."
	@Rscript scripts/eda/eda_summary_stats.R
	@echo "EDA complete!"

fit-garch:
	@echo "Fitting GARCH models..."
	@Rscript scripts/model_fitting/fit_garch_models.R
	@echo "GARCH fitting complete!"

extract-residuals:
	@echo "Extracting residuals..."
	@Rscript scripts/model_fitting/extract_residuals.R
	@echo "Residual extraction complete!"

train-nf:
	@echo "Training Normalizing Flow models..."
	@python scripts/model_fitting/train_nf_models.py
	@echo "NF training complete!"

eval-nf:
	@echo "Evaluating NF models..."
	@python scripts/model_fitting/evaluate_nf_fit.py
	@echo "NF evaluation complete!"

simulate-nf-garch:
	@echo "Simulating NF-GARCH models..."
	@Rscript scripts/simulation_forecasting/simulate_nf_garch.R
	@echo "NF-GARCH simulation complete!"

forecast:
	@echo "Running forecasts..."
	@Rscript scripts/simulation_forecasting/forecast_garch_variants.R
	@echo "Forecasting complete!"

eval-forecasts:
	@echo "Evaluating forecasts..."
	@Rscript scripts/evaluation/wilcoxon_winrate_analysis.R
	@echo "Forecast evaluation complete!"

stylized:
	@echo "Running stylized fact tests..."
	@Rscript scripts/evaluation/stylized_fact_tests.R
	@echo "Stylized fact tests complete!"

var:
	@echo "Running VaR backtesting..."
	@Rscript scripts/evaluation/var_backtesting.R
	@echo "VaR backtesting complete!"

stress:
	@echo "Running stress tests..."
	@Rscript scripts/stress_tests/evaluate_under_stress.R
	@echo "Stress tests complete!"

all: setup eda fit-garch extract-residuals train-nf eval-nf simulate-nf-garch forecast eval-forecasts stylized var stress
	@echo "Full pipeline complete!"

clean:
	@echo "Cleaning generated outputs..."
	@rm -rf outputs/eda/figures/* outputs/eda/tables/* outputs/model_eval/figures/* outputs/model_eval/tables/* outputs/var_backtest/figures/* outputs/var_backtest/tables/* outputs/stress_tests/figures/* outputs/stress_tests/tables/*
	@echo "Clean complete!"
