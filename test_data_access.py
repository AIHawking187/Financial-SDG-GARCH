#!/usr/bin/env python3
"""
Simple test script to check data access and basic functionality.
"""
import pandas as pd
import os
from pathlib import Path

def test_data_access():
    """Test if we can access the data files."""
    print("Testing data access...")
    
    # Check if data files exist
    data_files = [
        "data/raw/fx_equity_prices.csv",
        "data/residuals_by_model/",
        "outputs/eda/figures/",
        "outputs/model_eval/figures/"
    ]
    
    for file_path in data_files:
        if os.path.exists(file_path):
            print(f"✅ {file_path} exists")
        else:
            print(f"❌ {file_path} missing")
    
    # Try to read the main data file
    try:
        data_path = "data/raw/fx_equity_prices.csv"
        if os.path.exists(data_path):
            df = pd.read_csv(data_path)
            print(f"✅ Successfully read data file: {len(df)} rows, {len(df.columns)} columns")
            print(f"   Columns: {list(df.columns)}")
        else:
            print("❌ Main data file not found")
    except Exception as e:
        print(f"❌ Error reading data: {e}")
    
    # Check residuals
    residuals_dir = Path("data/residuals_by_model")
    if residuals_dir.exists():
        residual_files = list(residuals_dir.glob("*.csv"))
        print(f"✅ Found {len(residual_files)} residual files")
        for file in residual_files[:5]:  # Show first 5
            print(f"   - {file.name}")
    else:
        print("❌ Residuals directory not found")

if __name__ == "__main__":
    test_data_access()
