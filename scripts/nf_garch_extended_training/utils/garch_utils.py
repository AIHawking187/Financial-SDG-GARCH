# === utils/garch_utils.py ===
import pandas as pd
import numpy as np
from rugarch import ugarchspec, ugarchfit, ugarchpath

def inject_residuals_into_garch(asset_returns_path, synthetic_residuals,
                                model="sGARCH", distribution="sstd",
                                injection_method="replace",
                                hybrid_alpha=0.7,
                                enforce_zero_mean=True,
                                enforce_unit_variance=True,
                                split_type="chrono",
                                forecast_horizon=40,
                                cv_window=500,
                                cv_step=50):
    # Stub placeholder
    return []  # to be filled with results from injected simulation


def simulate_returns():
    pass  # Placeholder


# === utils/evaluation.py ===
from scipy.stats import ks_2samp, wasserstein_distance, wilcoxon
import pandas as pd

def evaluate_synthetic_quality(real_residuals, synthetic_residuals, metric_list,
                                include_diebold=False, include_wilcoxon=False):
    results = {}
    if "KS" in metric_list:
        results["KS"] = ks_2samp(real_residuals, synthetic_residuals).statistic
    if "Wasserstein" in metric_list:
        results["Wasserstein"] = wasserstein_distance(real_residuals, synthetic_residuals)
    if include_wilcoxon:
        stat, p = wilcoxon(real_residuals[:len(synthetic_residuals)], synthetic_residuals)
        results["Wilcoxon"] = p
    if include_diebold:
        results["Diebold-Mariano"] = None  # Requires time-series forecast error arrays
    return results

def save_results_and_plots(results, evaluation, output_dir, config):
    pd.DataFrame(results).to_csv(f"{output_dir}/garch_sim_results.csv", index=False)
    pd.DataFrame([evaluation]).to_csv(f"{output_dir}/evaluation_metrics.csv", index=False)
    with open(f"{output_dir}/config_used.yaml", "w") as f:
        import yaml; yaml.dump(config, f)
