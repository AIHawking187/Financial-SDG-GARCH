# === utils/data_utils.py ===
import pandas as pd
import numpy as np
import os

def load_residuals(residual_dir, standardize=True):
    residuals = []
    files = [f for f in os.listdir(residual_dir) if f.endswith('.csv')]
    for file in files:
        df = pd.read_csv(os.path.join(residual_dir, file))
        res = df.iloc[:, 0].values
        if standardize:
            res = (res - np.mean(res)) / np.std(res)
        residuals.extend(res)
    return np.array(residuals)

def create_conditioning_features(residuals, method="rolling_stats"):
    if method == "rolling_stats":
        window = 10
        means = pd.Series(residuals).rolling(window).mean().fillna(0).values
        stds  = pd.Series(residuals).rolling(window).std().fillna(1).values
        return np.stack([means, stds], axis=1)
    return None

