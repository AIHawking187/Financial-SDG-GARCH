#!/usr/bin/env python3
"""
Pipeline Validation Script
Validates all reporting requirements and checks for deterministic behavior
"""

import pandas as pd
import numpy as np
import os
import sys
from pathlib import Path
import warnings
warnings.filterwarnings('ignore')

# Set deterministic seeds
np.random.seed(123)
os.environ['PYTHONHASHSEED'] = '123'

# Required schemas
REQUIRED_SCHEMAS = {
    'Model_Performance_Summary': ['Model', 'Source', 'Avg_AIC', 'Avg_BIC', 'Avg_LogLik', 'Avg_MSE', 'Avg_MAE'],
    'VaR_Performance_Summary': ['Model', 'Asset', 'Confidence_Level', 'Total_Obs', 'Expected_Rate', 
                               'Violations', 'Violation_Rate', 'Kupiec_PValue', 'Christoffersen_PValue', 'DQ_PValue'],
    'Stress_Test_Summary': ['Model', 'Asset', 'Scenario_Type', 'Scenario_Name', 'Convergence_Rate', 
                           'Pass_LB_Test', 'Pass_ARCH_Test', 'Total_Tests', 'Robustness_Score'],
    'NF_Winners_By_Asset': ['Asset', 'Winning_Model', 'Split', 'Metric', 'Value'],
    'Distributional_Fit_Summary': ['Model', 'Asset', 'KS_Statistic', 'KS_PValue', 'Wasserstein_Distance', 'Notes']
}

# Required sheets
REQUIRED_SHEETS = [
    'Consolidated_Comparison', 'Model_Performance_Summary', 'VaR_Performance_Summary', 
    'NFGARCH_VaR_Summary', 'Stress_Test_Summary', 'NFGARCH_Stress_Summary', 
    'Stylized_Facts_Summary', 'model_ranking', 'NF_Winners_By_Asset', 'Distributional_Fit_Summary'
]

# Expected assets
EXPECTED_ASSETS = ['EURUSD', 'GBPUSD', 'GBPCNY', 'USDZAR', 'GBPZAR', 'EURZAR', 
                  'NVDA', 'MSFT', 'PG', 'CAT', 'WMT', 'AMZN']

# Expected models
EXPECTED_CLASSICAL_MODELS = ['sGARCH_norm', 'sGARCH_sstd', 'eGARCH', 'gjrGARCH', 'TGARCH']
EXPECTED_NF_MODELS = ['NF--sGARCH', 'NF--eGARCH', 'NF--gjrGARCH', 'NF--TGARCH']

def check_file_exists(filepath):
    """Check if file exists"""
    if os.path.exists(filepath):
        print(f"✓ File exists: {filepath}")
        return True
    else:
        print(f"✗ File missing: {filepath}")
        return False

def check_sheet_exists(excel_file, sheet_name):
    """Check if sheet exists in Excel file"""
    try:
        xl = pd.ExcelFile(excel_file)
        if sheet_name in xl.sheet_names:
            print(f"✓ Sheet exists: {sheet_name}")
            return True
        else:
            print(f"✗ Sheet missing: {sheet_name}")
            return False
    except Exception as e:
        print(f"✗ Error checking sheet {sheet_name}: {e}")
        return False

def check_schema_compliance(excel_file, sheet_name, expected_schema):
    """Check if sheet has correct schema"""
    try:
        df = pd.read_excel(excel_file, sheet_name=sheet_name)
        actual_columns = list(df.columns)
        
        missing_cols = set(expected_schema) - set(actual_columns)
        extra_cols = set(actual_columns) - set(expected_schema)
        
        if missing_cols:
            print(f"✗ Schema violation in {sheet_name}: missing columns {missing_cols}")
            return False
        elif extra_cols:
            print(f"⚠️ Schema warning in {sheet_name}: extra columns {extra_cols}")
            return True
        else:
            print(f"✓ Schema compliant: {sheet_name}")
            return True
    except Exception as e:
        print(f"✗ Error checking schema for {sheet_name}: {e}")
        return False

def check_missing_values(excel_file, sheet_name):
    """Check for missing values in sheet"""
    try:
        df = pd.read_excel(excel_file, sheet_name=sheet_name)
        
        # Check for NaN, NA, n/a, --- values
        missing_count = 0
        for col in df.columns:
            missing_count += df[col].isna().sum()
            missing_count += (df[col] == 'n/a').sum()
            missing_count += (df[col] == '---').sum()
            missing_count += (df[col] == 'NaN').sum()
            missing_count += (df[col] == 'NA').sum()
        
        if missing_count == 0:
            print(f"✓ No missing values: {sheet_name}")
            return True
        else:
            print(f"✗ Missing values found in {sheet_name}: {missing_count} cells")
            return False
    except Exception as e:
        print(f"✗ Error checking missing values for {sheet_name}: {e}")
        return False

def check_nf_winners_coverage(excel_file):
    """Check NF winners table covers all assets and includes NF models"""
    try:
        df = pd.read_excel(excel_file, sheet_name='NF_Winners_By_Asset')
        
        # Check asset coverage
        covered_assets = set(df['Asset'].unique())
        missing_assets = set(EXPECTED_ASSETS) - covered_assets
        
        if missing_assets:
            print(f"✗ NF winners missing assets: {missing_assets}")
            return False
        
        # Check NF model coverage
        winning_models = set(df['Winning_Model'].unique())
        nf_models_found = [m for m in winning_models if m.startswith('NF--')]
        
        if not nf_models_found:
            print(f"✗ NF winners table has no NF models")
            return False
        
        print(f"✓ NF winners coverage complete: {len(covered_assets)} assets, {len(nf_models_found)} NF models")
        return True
    except Exception as e:
        print(f"✗ Error checking NF winners coverage: {e}")
        return False

def check_var_95_coverage(excel_file):
    """Check VaR summaries include 95% rows with valid p-values"""
    try:
        # Check classical VaR
        df_classical = pd.read_excel(excel_file, sheet_name='VaR_Performance_Summary')
        var_95_classical = df_classical[df_classical['Confidence_Level'].isin([0.95, 95])]
        
        if len(var_95_classical) == 0:
            print(f"✗ No 95% VaR data in classical summary")
            return False
        
        # Check NF-GARCH VaR
        df_nf = pd.read_excel(excel_file, sheet_name='NFGARCH_VaR_Summary')
        var_95_nf = df_nf[df_nf['Confidence_Level'].isin([0.95, 95])]
        
        if len(var_95_nf) == 0:
            print(f"✗ No 95% VaR data in NF-GARCH summary")
            return False
        
        # Check p-values are valid
        pvalue_cols = ['Kupiec_PValue', 'Christoffersen_PValue', 'DQ_PValue']
        for col in pvalue_cols:
            if col in var_95_classical.columns:
                invalid_pvals = var_95_classical[col].isna().sum()
                if invalid_pvals > 0:
                    print(f"✗ Invalid p-values in classical VaR: {invalid_pvals}")
                    return False
        
        print(f"✓ VaR 95% coverage complete: {len(var_95_classical)} classical, {len(var_95_nf)} NF-GARCH")
        return True
    except Exception as e:
        print(f"✗ Error checking VaR coverage: {e}")
        return False

def check_model_coverage(excel_file):
    """Check model coverage across all sheets"""
    try:
        # Check Model_Performance_Summary
        df_perf = pd.read_excel(excel_file, sheet_name='Model_Performance_Summary')
        models_perf = set(df_perf['Model'].unique())
        
        # Check classical models
        classical_found = [m for m in EXPECTED_CLASSICAL_MODELS if m in models_perf]
        if len(classical_found) != len(EXPECTED_CLASSICAL_MODELS):
            missing_classical = set(EXPECTED_CLASSICAL_MODELS) - set(classical_found)
            print(f"✗ Missing classical models: {missing_classical}")
            return False
        
        # Check NF models
        nf_found = [m for m in EXPECTED_NF_MODELS if m in models_perf]
        if len(nf_found) == 0:
            print(f"✗ No NF models found in performance summary")
            return False
        
        print(f"✓ Model coverage: {len(classical_found)} classical, {len(nf_found)} NF models")
        return True
    except Exception as e:
        print(f"✗ Error checking model coverage: {e}")
        return False

def check_deterministic_behavior():
    """Check for deterministic seeds and configurations"""
    print("\n=== DETERMINISTIC BEHAVIOR CHECKS ===")
    
    # Check environment variables
    env_vars = {
        'PYTHONHASHSEED': '123',
        'CUDA_VISIBLE_DEVICES': '',
        'TORCH_CUDNN_V8_API_DISABLED': '1'
    }
    
    for var, expected_value in env_vars.items():
        actual_value = os.environ.get(var, '')
        if actual_value == expected_value:
            print(f"✓ Environment variable set: {var}={expected_value}")
        else:
            print(f"⚠️ Environment variable not set: {var} (expected: {expected_value})")
    
    # Check numpy seed
    np_seed = np.random.get_state()[1][0]
    if np_seed == 123:
        print(f"✓ NumPy seed set correctly: {np_seed}")
    else:
        print(f"⚠️ NumPy seed not set correctly: {np_seed} (expected: 123)")
    
    return True

def validate_excel_file(excel_file):
    """Validate a single Excel file"""
    print(f"\n=== VALIDATING {excel_file} ===")
    
    if not check_file_exists(excel_file):
        return False
    
    validation_results = []
    
    # Check all required sheets exist
    print("\n--- Sheet Existence Checks ---")
    for sheet_name in REQUIRED_SHEETS:
        sheet_exists = check_sheet_exists(excel_file, sheet_name)
        validation_results.append(('sheet_exists', sheet_name, sheet_exists))
    
    # Check schema compliance
    print("\n--- Schema Compliance Checks ---")
    for sheet_name, expected_schema in REQUIRED_SCHEMAS.items():
        schema_compliant = check_schema_compliance(excel_file, sheet_name, expected_schema)
        validation_results.append(('schema_compliant', sheet_name, schema_compliant))
    
    # Check missing values
    print("\n--- Missing Values Checks ---")
    for sheet_name in REQUIRED_SHEETS:
        no_missing = check_missing_values(excel_file, sheet_name)
        validation_results.append(('no_missing', sheet_name, no_missing))
    
    # Check specific requirements
    print("\n--- Specific Requirement Checks ---")
    
    nf_winners_ok = check_nf_winners_coverage(excel_file)
    validation_results.append(('nf_winners_coverage', 'NF_Winners_By_Asset', nf_winners_ok))
    
    var_coverage_ok = check_var_95_coverage(excel_file)
    validation_results.append(('var_95_coverage', 'VaR_Summaries', var_coverage_ok))
    
    model_coverage_ok = check_model_coverage(excel_file)
    validation_results.append(('model_coverage', 'Model_Performance_Summary', model_coverage_ok))
    
    # Summary
    print(f"\n--- Validation Summary for {excel_file} ---")
    passed = sum(1 for _, _, result in validation_results if result)
    total = len(validation_results)
    
    print(f"Passed: {passed}/{total} checks")
    
    if passed == total:
        print("✓ ALL VALIDATION CHECKS PASSED")
        return True
    else:
        print("✗ SOME VALIDATION CHECKS FAILED")
        failed_checks = [(check_type, name, result) for check_type, name, result in validation_results if not result]
        for check_type, name, result in failed_checks:
            print(f"  - Failed: {check_type} for {name}")
        return False

def main():
    """Main validation function"""
    print("=== NF-GARCH PIPELINE VALIDATION ===")
    print("Checking all reporting requirements and deterministic behavior...")
    
    # Check deterministic behavior
    check_deterministic_behavior()
    
    # Validate Excel files
    excel_files = [
        "Consolidated_NF_GARCH_Results.xlsx",
        "Dissertation_Consolidated_Results.xlsx"
    ]
    
    all_passed = True
    for excel_file in excel_files:
        if os.path.exists(excel_file):
            file_passed = validate_excel_file(excel_file)
            all_passed = all_passed and file_passed
        else:
            print(f"\n⚠️ File not found: {excel_file}")
            all_passed = False
    
    # Final summary
    print(f"\n=== FINAL VALIDATION SUMMARY ===")
    if all_passed:
        print("✓ ALL VALIDATION CHECKS PASSED")
        print("✓ Pipeline is ready for final rerun")
        return True
    else:
        print("✗ SOME VALIDATION CHECKS FAILED")
        print("✗ Pipeline needs fixes before final rerun")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)

