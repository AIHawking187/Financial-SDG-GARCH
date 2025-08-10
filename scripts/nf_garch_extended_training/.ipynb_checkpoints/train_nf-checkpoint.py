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
    import random
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)

def main(config_path="nf_garch_config.yaml"):
    # === Load Config ===
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)

    # === Set Random Seed ===
    set_seed(config.get("random_seed", 123))

    # === Create Output Directory ===
    experiment_path = Path(config["save_dir"]) / config["experiment_name"]
    experiment_path.mkdir(parents=True, exist_ok=True)

    # === Load Residuals & Features ===
    residual_data = load_residuals("residuals_by_model/", standardize=config["residual_training"]["standardize_residuals"])
    
    if config["residual_training"].get("input_features"):
        cond_features = create_conditioning_features(
            residual_data, config["residual_training"]["input_features"]
        )
    else:
        cond_features = None

    # === Train Normalizing Flow Model ===
    nf_model = train_nf_model(
        residuals=residual_data,
        cond_features=cond_features,
        model_cfg=config["nf_model"],
        window_cfg=config["residual_training"].get("windowed_training", None),
        save_path=experiment_path
    )

    # === Generate Synthetic Residuals ===
    synthetic_resid = generate_residuals(nf_model, n=len(residual_data))

    # === Inject into GARCH & Simulate ===
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

    # === Evaluate & Save ===
    evaluation_metrics = evaluate_synthetic_quality(
        real_residuals=residual_data,
        synthetic_residuals=synthetic_resid,
        metric_list=config["evaluation"]["metrics"],
        include_diebold=config["evaluation"].get("use_diebold_mariano", False),
        include_wilcoxon=config["evaluation"].get("use_wilcoxon", False)
    )

    save_results_and_plots(
        results=all_results,
        evaluation=evaluation_metrics,
        output_dir=experiment_path,
        config=config
    )

    # Save synthetic evaluation results for use in main.py (TS-CV equivalent of nf_cv_results.csv)
    pd.DataFrame(all_results).to_csv("results/nf_cv_results.csv", index=False)
    
    # Optional: Save TS-CV baseline results here if available, else skip
    # pd.DataFrame(fitted_cv_results).to_csv("results/Fitted_TS_CV_models.csv", index=False)

    
    print(f"✅ Experiment complete. Results saved to {experiment_path}")

if __name__ == "__main__":
    main()
