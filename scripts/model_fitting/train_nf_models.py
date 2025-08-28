"""
Normalizing Flow Training for GARCH Model Enhancement

This script implements the training pipeline for Normalizing Flow models
that enhance traditional GARCH models by learning the true innovation distribution
from empirical residuals. The trained NF models generate synthetic innovations
that preserve the statistical properties of the original residuals while
enabling more accurate volatility forecasting.
"""

import os
import yaml
import torch
import numpy as np
import pandas as pd
from pathlib import Path

from utils.flow_utils import train_nf_model, generate_residuals
from utils.data_utils import load_residuals, create_conditioning_features
from utils.garch_utils import inject_residuals_into_garch, simulate_returns
from utils.evaluation import evaluate_synthetic_quality, save_results_and_plots

os.makedirs("results", exist_ok=True)


def set_seed(seed):
    """Set random seeds for reproducibility across all random number generators."""
    import random
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)


def main(config_path="nf_garch_config.yaml"):
    """
    Main training pipeline for Normalizing Flow-enhanced GARCH models.
    
    This function orchestrates the complete NF training process:
    1. Loads GARCH residuals and configuration
    2. Trains Normalizing Flow models on the residuals
    3. Generates synthetic innovations
    4. Injects innovations into GARCH models for simulation
    5. Evaluates the quality of synthetic data and model performance
    """
    
    # Load configuration parameters
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)

    # Ensure reproducibility across runs
    set_seed(config.get("random_seed", 123))

    # Create experiment directory for results
    experiment_path = Path(config["save_dir"]) / config["experiment_name"]
    experiment_path.mkdir(parents=True, exist_ok=True)

    # Load GARCH residuals and create conditioning features
    residual_data = load_residuals("residuals_by_model/", 
                                  standardize=config["residual_training"]["standardize_residuals"])
    
    # Create conditioning features if specified in configuration
    if config["residual_training"].get("input_features"):
        cond_features = create_conditioning_features(
            residual_data, config["residual_training"]["input_features"]
        )
    else:
        cond_features = None

    # Train Normalizing Flow model on GARCH residuals
    nf_model = train_nf_model(
        residuals=residual_data,
        cond_features=cond_features,
        model_cfg=config["nf_model"],
        window_cfg=config["residual_training"].get("windowed_training", None),
        save_path=experiment_path
    )

    # Generate synthetic residuals using the trained NF model
    synthetic_resid = generate_residuals(nf_model, n=len(residual_data))

    # Inject synthetic innovations into GARCH models and simulate returns
    all_results = []
    for model_name in config["garch_spec"]["models"]:
        result = inject_residuals_into_garch(
            asset_returns_path="raw (FX + EQ).csv",
            synthetic_residuals=synthetic_resid,
            model=model_name,
            distribution=config["garch_spec"]["distribution"],
            injection_method=config["residual_injection"]["method"],
            hybrid_alpha=config["residual_injection"].get("hybrid_mix_alpha", 0.7),
            enforce_zero_mean=config["residual_injection"].get("enforce_zero_mean", True),
            enforce_unit_variance=config["residual_injection"].get("enforce_unit_variance", True),
            split_type=config["evaluation"]["split_type"],
            forecast_horizon=config["evaluation"]["forecast_horizon"],
            cv_window=config["evaluation"]["cv_window_size"],
            cv_step=config["evaluation"]["cv_step_size"]
        )
        all_results.extend(result)

    # Evaluate synthetic data quality and model performance
    evaluation_metrics = evaluate_synthetic_quality(
        real_residuals=residual_data,
        synthetic_residuals=synthetic_resid,
        metric_list=config["evaluation"]["metrics"],
        include_diebold=config["evaluation"].get("use_diebold_mariano", False),
        include_wilcoxon=config["evaluation"].get("use_wilcoxon", False)
    )

    # Save results and generate visualization plots
    save_results_and_plots(
        results=all_results,
        evaluation=evaluation_metrics,
        output_dir=experiment_path,
        config=config
    )

    # Save cross-validation results for downstream analysis
    pd.DataFrame(all_results).to_csv("results/nf_cv_results.csv", index=False)
    
    print(f"Experiment complete. Results saved to {experiment_path}")

if __name__ == "__main__":
    main()
