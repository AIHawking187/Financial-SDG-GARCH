#!/usr/bin/env python3
"""
LaTeX Table Generator for NF-GARCH Results
Generates publication-ready LaTeX tables from Excel sheets
"""

import pandas as pd
import numpy as np
import os
import sys
from pathlib import Path

# Set deterministic seeds
np.random.seed(123)
os.environ['PYTHONHASHSEED'] = '123'

def clean_numeric(value):
    """Clean numeric values, replacing NaN/NA with 0"""
    if pd.isna(value) or value in ['n/a', '---', 'NaN', 'NA']:
        return 0
    try:
        return float(value)
    except (ValueError, TypeError):
        return 0

def format_number(value, decimal_places=4):
    """Format number for LaTeX with specified decimal places"""
    if pd.isna(value) or value == 0:
        return "0.0000"
    try:
        return f"{float(value):.{decimal_places}f}"
    except (ValueError, TypeError):
        return "0.0000"

def format_pvalue(value):
    """Format p-value for LaTeX"""
    if pd.isna(value) or value == 0:
        return "1.0000"
    try:
        pval = float(value)
        if pval < 0.0001:
            return "$<0.0001$"
        elif pval < 0.001:
            return f"${pval:.4f}$"
        else:
            return f"${pval:.4f}$"
    except (ValueError, TypeError):
        return "1.0000"

def generate_model_performance_table(excel_file):
    """Generate LaTeX table for model performance summary"""
    try:
        df = pd.read_excel(excel_file, sheet_name='Model_Performance_Summary')
        
        # Clean and format data
        df['Avg_AIC'] = df['Avg_AIC'].apply(clean_numeric)
        df['Avg_BIC'] = df['Avg_BIC'].apply(clean_numeric)
        df['Avg_LogLik'] = df['Avg_LogLik'].apply(clean_numeric)
        df['Avg_MSE'] = df['Avg_MSE'].apply(clean_numeric)
        df['Avg_MAE'] = df['Avg_MAE'].apply(clean_numeric)
        
        # Sort by MSE
        df = df.sort_values('Avg_MSE')
        
        latex = []
        latex.append("\\begin{table}[htbp]")
        latex.append("\\centering")
        latex.append("\\caption{Model Performance Summary}")
        latex.append("\\label{tab:model_performance}")
        latex.append("\\begin{tabular}{lccccc}")
        latex.append("\\hline")
        latex.append("Model & Source & AIC & BIC & Log-Lik & MSE & MAE \\\\")
        latex.append("\\hline")
        
        for _, row in df.iterrows():
            model = row['Model'].replace('_', '\\_')
            source = row['Source']
            aic = format_number(row['Avg_AIC'], 2)
            bic = format_number(row['Avg_BIC'], 2)
            loglik = format_number(row['Avg_LogLik'], 2)
            mse = format_number(row['Avg_MSE'], 6)
            mae = format_number(row['Avg_MAE'], 4)
            
            latex.append(f"{model} & {source} & {aic} & {bic} & {loglik} & {mse} & {mae} \\\\")
        
        latex.append("\\hline")
        latex.append("\\end{tabular}")
        latex.append("\\end{table}")
        
        return "\n".join(latex)
        
    except Exception as e:
        return f"% Error generating model performance table: {e}"

def generate_var_performance_table(excel_file):
    """Generate LaTeX table for VaR performance summary"""
    try:
        df = pd.read_excel(excel_file, sheet_name='VaR_Performance_Summary')
        
        # Filter for 95% confidence level
        df = df[df['Confidence_Level'].isin([0.95, 95])]
        
        # Clean and format data
        df['Violation_Rate'] = df['Violation_Rate'].apply(clean_numeric)
        df['Kupiec_PValue'] = df['Kupiec_PValue'].apply(clean_numeric)
        df['Christoffersen_PValue'] = df['Christoffersen_PValue'].apply(clean_numeric)
        df['DQ_PValue'] = df['DQ_PValue'].apply(clean_numeric)
        
        # Group by model and calculate averages
        summary = df.groupby('Model').agg({
            'Violation_Rate': 'mean',
            'Kupiec_PValue': 'mean',
            'Christoffersen_PValue': 'mean',
            'DQ_PValue': 'mean'
        }).reset_index()
        
        latex = []
        latex.append("\\begin{table}[htbp]")
        latex.append("\\centering")
        latex.append("\\caption{VaR Performance Summary (95\\% Confidence Level)}")
        latex.append("\\label{tab:var_performance}")
        latex.append("\\begin{tabular}{lcccc}")
        latex.append("\\hline")
        latex.append("Model & Violation Rate & Kupiec p-value & Christoffersen p-value & DQ p-value \\\\")
        latex.append("\\hline")
        
        for _, row in summary.iterrows():
            model = row['Model'].replace('_', '\\_')
            violation_rate = format_number(row['Violation_Rate'], 4)
            kupiec_pval = format_pvalue(row['Kupiec_PValue'])
            christoffersen_pval = format_pvalue(row['Christoffersen_PValue'])
            dq_pval = format_pvalue(row['DQ_PValue'])
            
            latex.append(f"{model} & {violation_rate} & {kupiec_pval} & {christoffersen_pval} & {dq_pval} \\\\")
        
        latex.append("\\hline")
        latex.append("\\end{tabular}")
        latex.append("\\end{table}")
        
        return "\n".join(latex)
        
    except Exception as e:
        return f"% Error generating VaR performance table: {e}"

def generate_nfgarch_var_table(excel_file):
    """Generate LaTeX table for NF-GARCH VaR summary"""
    try:
        df = pd.read_excel(excel_file, sheet_name='NFGARCH_VaR_Summary')
        
        # Clean and format data
        df['Violation_Rate'] = df['Violation_Rate'].apply(clean_numeric)
        df['Kupiec_PValue'] = df['Kupiec_PValue'].apply(clean_numeric)
        df['Christoffersen_PValue'] = df['Christoffersen_PValue'].apply(clean_numeric)
        df['DQ_PValue'] = df['DQ_PValue'].apply(clean_numeric)
        
        # Group by model and calculate averages
        summary = df.groupby('Model').agg({
            'Violation_Rate': 'mean',
            'Kupiec_PValue': 'mean',
            'Christoffersen_PValue': 'mean',
            'DQ_PValue': 'mean'
        }).reset_index()
        
        latex = []
        latex.append("\\begin{table}[htbp]")
        latex.append("\\centering")
        latex.append("\\caption{NF-GARCH VaR Performance Summary (95\\% Confidence Level)}")
        latex.append("\\label{tab:nfgarch_var}")
        latex.append("\\begin{tabular}{lcccc}")
        latex.append("\\hline")
        latex.append("Model & Violation Rate & Kupiec p-value & Christoffersen p-value & DQ p-value \\\\")
        latex.append("\\hline")
        
        for _, row in summary.iterrows():
            model = row['Model'].replace('--', '\\textendash{}')
            violation_rate = format_number(row['Violation_Rate'], 4)
            kupiec_pval = format_pvalue(row['Kupiec_PValue'])
            christoffersen_pval = format_pvalue(row['Christoffersen_PValue'])
            dq_pval = format_pvalue(row['DQ_PValue'])
            
            latex.append(f"{model} & {violation_rate} & {kupiec_pval} & {christoffersen_pval} & {dq_pval} \\\\")
        
        latex.append("\\hline")
        latex.append("\\end{tabular}")
        latex.append("\\end{table}")
        
        return "\n".join(latex)
        
    except Exception as e:
        return f"% Error generating NF-GARCH VaR table: {e}"

def generate_stress_test_table(excel_file):
    """Generate LaTeX table for stress test summary"""
    try:
        df = pd.read_excel(excel_file, sheet_name='Stress_Test_Summary')
        
        # Clean and format data
        df['Convergence_Rate'] = df['Convergence_Rate'].apply(clean_numeric)
        df['Robustness_Score'] = df['Robustness_Score'].apply(clean_numeric)
        
        # Group by model and calculate averages
        summary = df.groupby('Model').agg({
            'Convergence_Rate': 'mean',
            'Pass_LB_Test': 'sum',
            'Pass_ARCH_Test': 'sum',
            'Total_Tests': 'sum',
            'Robustness_Score': 'mean'
        }).reset_index()
        
        latex = []
        latex.append("\\begin{table}[htbp]")
        latex.append("\\centering")
        latex.append("\\caption{Stress Test Summary}")
        latex.append("\\label{tab:stress_test}")
        latex.append("\\begin{tabular}{lccccc}")
        latex.append("\\hline")
        latex.append("Model & Conv. Rate & LB Tests & ARCH Tests & Total Tests & Robustness \\\\")
        latex.append("\\hline")
        
        for _, row in summary.iterrows():
            model = row['Model'].replace('_', '\\_')
            conv_rate = format_number(row['Convergence_Rate'], 3)
            lb_tests = int(row['Pass_LB_Test'])
            arch_tests = int(row['Pass_ARCH_Test'])
            total_tests = int(row['Total_Tests'])
            robustness = format_number(row['Robustness_Score'], 3)
            
            latex.append(f"{model} & {conv_rate} & {lb_tests} & {arch_tests} & {total_tests} & {robustness} \\\\")
        
        latex.append("\\hline")
        latex.append("\\end{tabular}")
        latex.append("\\end{table}")
        
        return "\n".join(latex)
        
    except Exception as e:
        return f"% Error generating stress test table: {e}"

def generate_nfgarch_stress_table(excel_file):
    """Generate LaTeX table for NF-GARCH stress summary"""
    try:
        df = pd.read_excel(excel_file, sheet_name='NFGARCH_Stress_Summary')
        
        # Clean and format data
        df['Convergence_Rate'] = df['Convergence_Rate'].apply(clean_numeric)
        df['Robustness_Score'] = df['Robustness_Score'].apply(clean_numeric)
        
        # Group by model and calculate averages
        summary = df.groupby('Model').agg({
            'Convergence_Rate': 'mean',
            'Pass_LB_Test': 'sum',
            'Pass_ARCH_Test': 'sum',
            'Total_Tests': 'sum',
            'Robustness_Score': 'mean'
        }).reset_index()
        
        latex = []
        latex.append("\\begin{table}[htbp]")
        latex.append("\\centering")
        latex.append("\\caption{NF-GARCH Stress Test Summary}")
        latex.append("\\label{tab:nfgarch_stress}")
        latex.append("\\begin{tabular}{lccccc}")
        latex.append("\\hline")
        latex.append("Model & Conv. Rate & LB Tests & ARCH Tests & Total Tests & Robustness \\\\")
        latex.append("\\hline")
        
        for _, row in summary.iterrows():
            model = row['Model'].replace('--', '\\textendash{}')
            conv_rate = format_number(row['Convergence_Rate'], 3)
            lb_tests = int(row['Pass_LB_Test'])
            arch_tests = int(row['Pass_ARCH_Test'])
            total_tests = int(row['Total_Tests'])
            robustness = format_number(row['Robustness_Score'], 3)
            
            latex.append(f"{model} & {conv_rate} & {lb_tests} & {arch_tests} & {total_tests} & {robustness} \\\\")
        
        latex.append("\\hline")
        latex.append("\\end{tabular}")
        latex.append("\\end{table}")
        
        return "\n".join(latex)
        
    except Exception as e:
        return f"% Error generating NF-GARCH stress table: {e}"

def generate_nf_winners_table(excel_file):
    """Generate LaTeX table for NF winners by asset"""
    try:
        df = pd.read_excel(excel_file, sheet_name='NF_Winners_By_Asset')
        
        # Clean and format data
        df['Value'] = df['Value'].apply(clean_numeric)
        
        latex = []
        latex.append("\\begin{table}[htbp]")
        latex.append("\\centering")
        latex.append("\\caption{NF-GARCH Winners by Asset}")
        latex.append("\\label{tab:nf_winners}")
        latex.append("\\begin{tabular}{lcc}")
        latex.append("\\hline")
        latex.append("Asset & Winning Model & MSE \\\\")
        latex.append("\\hline")
        
        for _, row in df.iterrows():
            asset = row['Asset']
            winning_model = row['Winning_Model'].replace('--', '\\textendash{}')
            mse = format_number(row['Value'], 6)
            
            latex.append(f"{asset} & {winning_model} & {mse} \\\\")
        
        latex.append("\\hline")
        latex.append("\\end{tabular}")
        latex.append("\\end{table}")
        
        return "\n".join(latex)
        
    except Exception as e:
        return f"% Error generating NF winners table: {e}"

def generate_model_ranking_table(excel_file):
    """Generate LaTeX table for model ranking"""
    try:
        df = pd.read_excel(excel_file, sheet_name='model_ranking')
        
        # Clean and format data
        df['Avg_MSE'] = df['Avg_MSE'].apply(clean_numeric)
        df['Avg_MAE'] = df['Avg_MAE'].apply(clean_numeric)
        df['Avg_AIC'] = df['Avg_AIC'].apply(clean_numeric)
        
        # Sort by MSE
        df = df.sort_values('Avg_MSE')
        
        latex = []
        latex.append("\\begin{table}[htbp]")
        latex.append("\\centering")
        latex.append("\\caption{Model Ranking by Performance}")
        latex.append("\\label{tab:model_ranking}")
        latex.append("\\begin{tabular}{lccccc}")
        latex.append("\\hline")
        latex.append("Rank & Model & Source & MSE & MAE & AIC \\\\")
        latex.append("\\hline")
        
        for i, (_, row) in enumerate(df.iterrows(), 1):
            model = row['Model'].replace('_', '\\_').replace('--', '\\textendash{}')
            source = row['Source']
            mse = format_number(row['Avg_MSE'], 6)
            mae = format_number(row['Avg_MAE'], 4)
            aic = format_number(row['Avg_AIC'], 2)
            
            latex.append(f"{i} & {model} & {source} & {mse} & {mae} & {aic} \\\\")
        
        latex.append("\\hline")
        latex.append("\\end{tabular}")
        latex.append("\\end{table}")
        
        return "\n".join(latex)
        
    except Exception as e:
        return f"% Error generating model ranking table: {e}"

def generate_all_tables(excel_file):
    """Generate all LaTeX tables"""
    print("Generating LaTeX tables from:", excel_file)
    
    tables = {
        'model_performance': generate_model_performance_table(excel_file),
        'var_performance': generate_var_performance_table(excel_file),
        'nfgarch_var': generate_nfgarch_var_table(excel_file),
        'stress_test': generate_stress_test_table(excel_file),
        'nfgarch_stress': generate_nfgarch_stress_table(excel_file),
        'nf_winners': generate_nf_winners_table(excel_file),
        'model_ranking': generate_model_ranking_table(excel_file)
    }
    
    # Write individual table files
    for table_name, latex_content in tables.items():
        filename = f"table_{table_name}.tex"
        with open(filename, 'w') as f:
            f.write(latex_content)
        print(f"✓ Generated: {filename}")
    
    # Write combined file
    combined_content = []
    combined_content.append("% LaTeX Tables for NF-GARCH Results")
    combined_content.append("% Generated automatically from Excel sheets")
    combined_content.append("%")
    
    for table_name, latex_content in tables.items():
        combined_content.append(f"% {table_name.upper().replace('_', ' ')} TABLE")
        combined_content.append(latex_content)
        combined_content.append("")
    
    with open("all_tables.tex", 'w') as f:
        f.write("\n".join(combined_content))
    
    print("✓ Generated: all_tables.tex")
    print("✓ All tables generated successfully!")

def main():
    """Main function"""
    excel_files = [
        "Consolidated_NF_GARCH_Results.xlsx",
        "Dissertation_Consolidated_Results.xlsx"
    ]
    
    for excel_file in excel_files:
        if os.path.exists(excel_file):
            print(f"\nProcessing: {excel_file}")
            generate_all_tables(excel_file)
        else:
            print(f"Warning: {excel_file} not found")

if __name__ == "__main__":
    main()
