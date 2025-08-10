import os
import pandas as pd
from data_utils import load_residuals_from_csv, split_residuals_by_model
from flow_utils import build_flow_model, train_nf_model, sample_from_nf
from evaluation import evaluate_distribution_distance, evaluate_forecast_accuracy
from garch_utils import run_nf_garch_simulation

import argparse
import pandas as pd
import os
from evaluation import evaluate_dm_test, evaluate_stat_tests
from training import run_training_pipeline
from synthetic_eval import run_synthetic_evaluation

# Argument parser setup
parser = argparse.ArgumentParser(description="Run NF-GARCH Experiments")
parser.add_argument('--run-tests', action='store_true', help='Run statistical tests after evaluation')
parser.add_argument('--train-models', action='store_true', help='Run model training pipeline')
parser.add_argument('--eval-synthetic', action='store_true', help='Run synthetic residual evaluation pipeline')
parser.add_argument('--window-size', type=int, default=500, help='Sliding window size for time-series cross-validation')
parser.add_argument('--forecast-horizon', type=int, default=40, help='Forecast horizon for out-of-sample evaluation')
parser.add_argument('--model-type', type=str, default='sGARCH', help='GARCH model type to use (e.g. sGARCH, eGARCH, gjrGARCH, TGARCH)')
parser.add_argument('--asset-subset', type=str, nargs='+', default=None, help='List of asset tickers to run (e.g. USDZAR NVDA)')
parser.add_argument('--asset-group', type=str, choices=['FX', 'EQ'], help='Predefined asset groups: FX or EQ')
args = parser.parse_args()

# Define default asset groups
FX_TICKERS = ['USDZAR', 'GBPZAR', 'EURZAR', 'EURUSD', 'GBPUSD', 'GBPCNY']
EQ_TICKERS = ['NVDA', 'MSFT', 'PG', 'CAT', 'WMT', 'AMZN']

# Override asset subset if asset group is selected
if args.asset_group and not args.asset_subset:
    if args.asset_group == 'FX':
        args.asset_subset = FX_TICKERS
    elif args.asset_group == 'EQ':
        args.asset_subset = EQ_TICKERS

# === Run Model Training Pipeline ===
if args.train_models:
    print("🚀 Running model training pipeline...")
    run_training_pipeline(
        window_size=args.window_size,
        forecast_horizon=args.forecast_horizon,
        model_type=args.model_type,
        asset_subset=args.asset_subset
    )
    print("✅ Model training complete.")
else:
    print("⚠️ Skipping model training. Use --train-models to enable.")

# === Run Synthetic Evaluation Pipeline ===
if args.eval_synthetic:
    print("🔍 Running synthetic evaluation pipeline...")
    run_synthetic_evaluation(
        window_size=args.window_size,
        forecast_horizon=args.forecast_horizon,
        model_type=args.model_type,
        asset_subset=args.asset_subset
    )
    print("✅ Synthetic evaluation complete.")
else:
    print("⚠️ Skipping synthetic evaluation. Use --eval-synthetic to enable.")

# === CONFIG ===
CONFIG = {
    "residual_dir": "residuals_by_model",
    "output_dir": "nf_models",
    "flow_config": {
        "num_layers": 5,
        "hidden_features": 64,
        "epochs": 1000,
        "batch_size": 128,
        "lr": 1e-3,
        "save_model": True
    },
    "sample_size": 1000,
    "forecast_horizon": 40,
    "assets": ["USDZAR", "EURUSD", "GBPZAR"],
    "models": ["sGARCH", "eGARCH", "gjrGARCH", "TGARCH"]
}


def main():
    # === Load residual files ===
    print("📥 Loading residuals...")
    residual_map = split_residuals_by_model(CONFIG["residual_dir"])

    nf_results = {}

    # === Train NF on each model's residuals ===
    for model_key, residuals in residual_map.items():
        print(f"🚀 Training NF for {model_key}...")

        flow = build_flow_model(
            num_layers=CONFIG["flow_config"]["num_layers"],
            hidden_features=CONFIG["flow_config"]["hidden_features"]
        )

        train_nf_model(
            flow, residuals,
            epochs=CONFIG["flow_config"]["epochs"],
            batch_size=CONFIG["flow_config"]["batch_size"],
            lr=CONFIG["flow_config"]["lr"],
            save_path=os.path.join(CONFIG["output_dir"], model_key + ".pt")
        )

        samples = sample_from_nf(flow, CONFIG["sample_size"])
        nf_results[model_key] = samples

        # === Distribution evaluation ===
        ks, wass = evaluate_distribution_distance(real_residuals=residuals, synthetic_residuals=samples)
        print(f"\tKS: {ks:.4f}, Wasserstein: {wass:.4f}")

    # === Run NF-GARCH simulations ===
    print("📊 Running NF-GARCH simulations...")
    all_results = []

    for model_key, innovations in nf_results.items():
        for asset in CONFIG["assets"]:
            print(f"🔁 Simulating {model_key} on {asset}")

            sim_result = run_nf_garch_simulation(
                asset_name=asset,
                model_key=model_key,
                synthetic_residuals=innovations,
                forecast_horizon=CONFIG["forecast_horizon"]
            )

            if sim_result is not None:
                all_results.append(sim_result)

    df_results = pd.DataFrame(all_results)
    df_results.to_csv("results/nf_garch_forecast_results.csv", index=False)
    print("✅ Done. Results saved to results/nf_garch_forecast_results.csv")




# === Statistical Comparison Tests ===
from scipy.stats import wilcoxon
from statsmodels.stats.diagnostic import acorr_ljungbox
from statsmodels.stats.stattools import durbin_watson

print("Running statistical tests...")

dm_results = evaluate_dm_test(Fitted_TS_CV_models_df, nf_cv_results_df, metric="MSE")
dm_results.to_csv("results/stat_tests/diebold_mariano_results.csv", index=False)

wilcoxon_results = evaluate_stat_tests(Fitted_TS_CV_models_df, nf_cv_results_df, metric="MSE")
wilcoxon_results.to_csv("results/stat_tests/wilcoxon_results.csv", index=False)

with pd.ExcelWriter("GARCH_Model_Evaluation_Summary.xlsx", engine="openpyxl", mode="a", if_sheet_exists="replace") as writer:
    dm_results.to_excel(writer, sheet_name="DM_Test_MSE_CV", index=False)
    wilcoxon_results.to_excel(writer, sheet_name="Wilcoxon_MSE_CV", index=False)

print("✅ All statistical tests complete.")


# === Statistical Comparison Tests ===
if args.run_tests:
    print("📊 Running statistical tests...")

    dm_results = evaluate_dm_test(Fitted_TS_CV_models_df, nf_cv_results_df, metric="MSE")
    dm_results.to_csv("results/stat_tests/diebold_mariano_results.csv", index=False)

    wilcoxon_results = evaluate_stat_tests(Fitted_TS_CV_models_df, nf_cv_results_df, metric="MSE")
    wilcoxon_results.to_csv("results/stat_tests/wilcoxon_results.csv", index=False)

    with pd.ExcelWriter("GARCH_Model_Evaluation_Summary.xlsx", engine="openpyxl", mode="a", if_sheet_exists="replace") as writer:
        dm_results.to_excel(writer, sheet_name="DM_Test_MSE_CV", index=False)
        wilcoxon_results.to_excel(writer, sheet_name="Wilcoxon_MSE_CV", index=False)

    print("✅ All statistical tests complete.")
else:
    print("⚠️ Skipping statistical tests. Use --run-tests to enable.")




if __name__ == "__main__":
    os.makedirs("results", exist_ok=True)
    os.makedirs(CONFIG["output_dir"], exist_ok=True)
    main()
