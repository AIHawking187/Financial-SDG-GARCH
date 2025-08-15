#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
EDA for Financial Time Series (FX & Equities)

- Loads prices, computes log/simple returns
- Summary stats: mean, variance, skew, kurtosis, Jarque-Bera
- Visuals: price series, returns, ACF/PACF, QQ, correlation heatmap
- Stylized facts: volatility clustering (ARCH-LM), non-normality, heavy tails (Hill)
- Stationarity: ADF (levels & returns), KPSS (levels & returns)
- Outputs CSV tables + PNG plots + Markdown report

Usage:
    python scripts/eda/eda_finance.py --config scripts/eda/configs/eda.yaml
"""

from __future__ import annotations
import argparse
import os
import sys
from dataclasses import dataclass
from typing import List, Optional, Tuple, Dict

import numpy as np
import pandas as pd
import yaml
from tqdm import tqdm

import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
from statsmodels.tsa.stattools import adfuller, kpss
from statsmodels.stats.diagnostic import acorr_ljungbox
from statsmodels.stats.diagnostic import het_arch

# Set style for better plots
try:
    plt.style.use('seaborn-v0_8')
except:
    plt.style.use('seaborn')  # Fallback for newer versions
sns.set_palette("husl")

@dataclass
class EDAConfig:
    """Configuration for EDA analysis"""
    input_csv: str
    date_column: str
    parse_dates: bool
    dropna: bool
    price_columns_include: List[str]
    price_columns_exclude: List[str]
    resample: Optional[str]
    return_type: str
    plots: Dict[str, bool]
    tests: Dict[str, float]
    tails: Dict[str, float]
    output_dirs: Dict[str, str]
    seed: int

def load_config(config_path: str) -> EDAConfig:
    """Load configuration from YAML file"""
    if not os.path.exists(config_path):
        raise FileNotFoundError(f"Configuration file not found: {config_path}")
    
    try:
        with open(config_path, 'r') as f:
            config_dict = yaml.safe_load(f)
        
        if config_dict is None:
            raise ValueError("Configuration file is empty or invalid")
        
        return EDAConfig(**config_dict)
    except yaml.YAMLError as e:
        raise ValueError(f"Invalid YAML in configuration file: {str(e)}")
    except Exception as e:
        raise ValueError(f"Failed to load configuration: {str(e)}")

def setup_output_dirs(config: EDAConfig) -> None:
    """Create output directories if they don't exist"""
    for dir_path in config.output_dirs.values():
        os.makedirs(dir_path, exist_ok=True)

def load_data(config: EDAConfig) -> pd.DataFrame:
    """Load and preprocess financial data"""
    print(f"📥 Loading data from {config.input_csv}")
    
    # Check if file exists
    if not os.path.exists(config.input_csv):
        raise FileNotFoundError(f"Data file not found: {config.input_csv}")
    
    # Load data
    try:
        df = pd.read_csv(config.input_csv)
    except Exception as e:
        raise ValueError(f"Failed to load data from {config.input_csv}: {str(e)}")
    
    # Handle date column
    if config.date_column and config.date_column in df.columns:
        df[config.date_column] = pd.to_datetime(df[config.date_column])
        df.set_index(config.date_column, inplace=True)
    elif config.parse_dates:
        # Try to find date column
        date_cols = [col for col in df.columns if 'date' in col.lower() or 'time' in col.lower()]
        if date_cols:
            df[date_cols[0]] = pd.to_datetime(df[date_cols[0]])
            df.set_index(date_cols[0], inplace=True)
        else:
            # Assume first column is date if it looks like dates
            first_col = df.columns[0]
            try:
                df[first_col] = pd.to_datetime(df[first_col])
                df.set_index(first_col, inplace=True)
            except:
                print("⚠️  Could not parse dates automatically. Using index as dates.")
    
    # Identify price columns
    if config.price_columns_include:
        price_cols = config.price_columns_include
    else:
        # Exclude date-like columns and use all numeric columns
        exclude_patterns = ['date', 'time', 'index', 'id']
        price_cols = [col for col in df.columns 
                     if not any(pattern in col.lower() for pattern in exclude_patterns)
                     and pd.api.types.is_numeric_dtype(df[col])]
    
    # Apply exclusions
    price_cols = [col for col in price_cols if col not in config.price_columns_exclude]
    
    if not price_cols:
        raise ValueError("No price columns found!")
    
    print(f"📊 Found {len(price_cols)} price columns: {price_cols}")
    
    # Select only price columns
    df = df[price_cols]
    
    # Check if dataframe is empty
    if df.empty:
        raise ValueError("No data found after selecting price columns")
    
    # Handle missing data
    if config.dropna:
        df = df.dropna()
        print(f"📈 Data shape after dropping NA: {df.shape}")
        
        if df.empty:
            raise ValueError("No data remaining after dropping NA values")
    
    # Resample if specified
    if config.resample:
        df = df.resample(config.resample).last().dropna()
        print(f"📈 Resampled to {config.resample} frequency: {df.shape}")
    
    return df

def compute_returns(prices: pd.DataFrame, return_type: str = "log") -> pd.DataFrame:
    """Compute returns from price series"""
    if return_type.lower() == "log":
        returns = np.log(prices / prices.shift(1))
    else:  # simple returns
        returns = (prices - prices.shift(1)) / prices.shift(1)
    
    return returns.dropna()

def summary_statistics(returns: pd.DataFrame) -> pd.DataFrame:
    """Compute summary statistics for return series"""
    print("📊 Computing summary statistics...")
    
    stats_list = []
    for col in returns.columns:
        series = returns[col].dropna()
        
        # Basic stats
        mean_val = series.mean()
        std_val = series.std()
        skew_val = series.skew()
        kurt_val = series.kurtosis()
        
        # Jarque-Bera test
        jb_stat, jb_pval = stats.jarque_bera(series)
        
        # Min/Max
        min_val = series.min()
        max_val = series.max()
        
        # Quantiles
        q25 = series.quantile(0.25)
        q75 = series.quantile(0.75)
        
        stats_list.append({
            'Series': col,
            'Mean': mean_val,
            'Std': std_val,
            'Skewness': skew_val,
            'Excess_Kurtosis': kurt_val,
            'JB_Statistic': jb_stat,
            'JB_p_value': jb_pval,
            'Min': min_val,
            'Max': max_val,
            'Q25': q25,
            'Q75': q75,
            'Observations': len(series)
        })
    
    return pd.DataFrame(stats_list)

def stationarity_tests(data: pd.DataFrame, alpha: float = 0.05) -> pd.DataFrame:
    """Perform stationarity tests (ADF and KPSS)"""
    print("🧪 Performing stationarity tests...")
    
    results = []
    for col in data.columns:
        series = data[col].dropna()
        
        # ADF test
        try:
            adf_stat, adf_pval, adf_crit = adfuller(series, regression='ct', autolag='AIC')[:3]
            adf_result = "Stationary" if adf_pval < alpha else "Non-stationary"
        except:
            adf_stat, adf_pval, adf_result = np.nan, np.nan, "Error"
        
        # KPSS test
        try:
            import warnings
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                kpss_stat, kpss_pval, kpss_crit = kpss(series, regression='ct')[:3]
            kpss_result = "Stationary" if kpss_pval > alpha else "Non-stationary"
        except:
            kpss_stat, kpss_pval, kpss_result = np.nan, np.nan, "Error"
        
        results.append({
            'Series': col,
            'ADF_Statistic': adf_stat,
            'ADF_p_value': adf_pval,
            'ADF_Result': adf_result,
            'KPSS_Statistic': kpss_stat,
            'KPSS_p_value': kpss_pval,
            'KPSS_Result': kpss_result
        })
    
    return pd.DataFrame(results)

def hill_tail_index(series: pd.Series, threshold_quantile: float = 0.95) -> float:
    """Compute Hill tail index for heavy-tailed distributions"""
    try:
        # Get upper tail
        threshold = series.quantile(threshold_quantile)
        tail_data = series[series > threshold]
        
        if len(tail_data) < 10:
            return np.nan
        
        # Log of exceedances
        log_exceedances = np.log(tail_data / threshold)
        
        # Hill estimator
        hill_index = 1 / log_exceedances.mean()
        
        return hill_index
    except:
        return np.nan

def stylized_facts(returns: pd.DataFrame, config: EDAConfig) -> pd.DataFrame:
    """Compute stylized facts of financial returns"""
    print("🎯 Computing stylized facts...")
    
    results = []
    for col in returns.columns:
        series = returns[col].dropna()
        
        # Ljung-Box test for serial correlation
        try:
            lb_stat, lb_pval = acorr_ljungbox(series, lags=config.tests['lb_lags'], return_df=False)
            lb_result = lb_stat[-1], lb_pval[-1]  # Use last lag
        except:
            lb_result = (np.nan, np.nan)
        
        # ARCH-LM test for volatility clustering
        try:
            arch_stat, arch_pval = het_arch(series, nlags=config.tests['arch_lm_lags'])
            arch_result = (arch_stat, arch_pval)
        except:
            arch_result = (np.nan, np.nan)
        
        # Hill tail index
        hill_idx = hill_tail_index(series, config.tails['hill_threshold_quantile'])
        
        # Excess kurtosis
        excess_kurt = series.kurtosis()
        
        results.append({
            'Series': col,
            'Ljung_Box_Stat': lb_result[0],
            'Ljung_Box_p_value': lb_result[1],
            'ARCH_LM_Stat': arch_result[0],
            'ARCH_LM_p_value': arch_result[1],
            'Hill_Tail_Index': hill_idx,
            'Excess_Kurtosis': excess_kurt
        })
    
    return pd.DataFrame(results)

def create_plots(prices: pd.DataFrame, returns: pd.DataFrame, config: EDAConfig) -> None:
    """Create various plots for EDA"""
    print("📈 Creating visualizations...")
    
    # Time series plots
    if config.plots['timeseries']:
        plt.figure(figsize=(15, 10))
        for i, col in enumerate(prices.columns, 1):
            plt.subplot(3, 3, i)
            plt.plot(prices.index, prices[col])
            plt.title(f'{col} - Price Series')
            plt.xticks(rotation=45)
            if i >= 9:  # Limit to 9 plots per figure
                break
        plt.tight_layout()
        plt.savefig(f"{config.output_dirs['reports']}/prices.png", dpi=300, bbox_inches='tight')
        plt.close()
    
    # Returns plots
    if config.plots['returns']:
        plt.figure(figsize=(15, 10))
        for i, col in enumerate(returns.columns, 1):
            plt.subplot(3, 3, i)
            plt.plot(returns.index, returns[col])
            plt.title(f'{col} - Returns')
            plt.xticks(rotation=45)
            if i >= 9:
                break
        plt.tight_layout()
        plt.savefig(f"{config.output_dirs['reports']}/returns.png", dpi=300, bbox_inches='tight')
        plt.close()
    
    # Correlation heatmap
    if config.plots['heatmap']:
        plt.figure(figsize=(12, 10))
        corr_matrix = returns.corr()
        sns.heatmap(corr_matrix, annot=True, cmap='coolwarm', center=0, 
                   square=True, fmt='.2f')
        plt.title('Return Correlation Matrix')
        plt.tight_layout()
        plt.savefig(f"{config.output_dirs['reports']}/corr_heatmap.png", dpi=300, bbox_inches='tight')
        plt.close()
    
    # ACF and PACF plots
    if config.plots['acf_pacf']:
        for col in returns.columns:
            fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(12, 8))
            
            # ACF
            pd.plotting.autocorrelation_plot(returns[col], ax=ax1)
            ax1.set_title(f'{col} - Autocorrelation Function')
            
            # PACF
            from statsmodels.graphics.tsaplots import plot_pacf
            plot_pacf(returns[col].dropna(), ax=ax2, lags=40)
            ax2.set_title(f'{col} - Partial Autocorrelation Function')
            
            plt.tight_layout()
            plt.savefig(f"{config.output_dirs['reports']}/acf_{col}.png", dpi=300, bbox_inches='tight')
            plt.close()
    
    # QQ plots
    if config.plots['qq']:
        for col in returns.columns:
            plt.figure(figsize=(8, 6))
            stats.probplot(returns[col].dropna(), dist="norm", plot=plt)
            plt.title(f'{col} - Q-Q Plot vs Normal Distribution')
            plt.tight_layout()
            plt.savefig(f"{config.output_dirs['reports']}/qq_{col}.png", dpi=300, bbox_inches='tight')
            plt.close()

def generate_report(config: EDAConfig, summary_stats: pd.DataFrame, 
                   stationarity: pd.DataFrame, stylized_facts: pd.DataFrame) -> None:
    """Generate comprehensive EDA report"""
    print("📝 Generating EDA report...")
    
    report_path = f"{config.output_dirs['reports']}/EDA_Report.md"
    
    try:
        with open(report_path, 'w', encoding='utf-8') as f:
            f.write("# Financial Time Series EDA Report\n\n")
            f.write(f"**Generated:** {pd.Timestamp.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
            f.write(f"**Data Source:** {config.input_csv}\n\n")
            f.write(f"**Analysis Period:** {len(summary_stats)} series analyzed\n\n")
            
            # Summary Statistics
            f.write("## Summary Statistics\n\n")
            f.write("| Series | Mean | Std | Skewness | Excess Kurtosis | JB p-value |\n")
            f.write("|--------|------|-----|----------|-----------------|------------|\n")
            for _, row in summary_stats.iterrows():
                mean_val = f"{row['Mean']:.6f}" if not pd.isna(row['Mean']) else "N/A"
                std_val = f"{row['Std']:.6f}" if not pd.isna(row['Std']) else "N/A"
                skew_val = f"{row['Skewness']:.3f}" if not pd.isna(row['Skewness']) else "N/A"
                kurt_val = f"{row['Excess_Kurtosis']:.3f}" if not pd.isna(row['Excess_Kurtosis']) else "N/A"
                jb_pval = f"{row['JB_p_value']:.3f}" if not pd.isna(row['JB_p_value']) else "N/A"
                f.write(f"| {row['Series']} | {mean_val} | {std_val} | {skew_val} | {kurt_val} | {jb_pval} |\n")
            f.write("\n")
            
            # Stationarity Results
            f.write("## Stationarity Tests\n\n")
            f.write("### ADF Test Results\n")
            f.write("| Series | ADF Statistic | p-value | Result |\n")
            f.write("|--------|---------------|---------|--------|\n")
            for _, row in stationarity.iterrows():
                adf_stat = f"{row['ADF_Statistic']:.3f}" if not pd.isna(row['ADF_Statistic']) and isinstance(row['ADF_Statistic'], (int, float)) else "N/A"
                adf_pval = f"{row['ADF_p_value']:.3f}" if not pd.isna(row['ADF_p_value']) and isinstance(row['ADF_p_value'], (int, float)) else "N/A"
                f.write(f"| {row['Series']} | {adf_stat} | {adf_pval} | {row['ADF_Result']} |\n")
            f.write("\n")
            
            f.write("### KPSS Test Results\n")
            f.write("| Series | KPSS Statistic | p-value | Result |\n")
            f.write("|--------|----------------|---------|--------|\n")
            for _, row in stationarity.iterrows():
                kpss_stat = f"{row['KPSS_Statistic']:.3f}" if not pd.isna(row['KPSS_Statistic']) and isinstance(row['KPSS_Statistic'], (int, float)) else "N/A"
                kpss_pval = f"{row['KPSS_p_value']:.3f}" if not pd.isna(row['KPSS_p_value']) and isinstance(row['KPSS_p_value'], (int, float)) else "N/A"
                f.write(f"| {row['Series']} | {kpss_stat} | {kpss_pval} | {row['KPSS_Result']} |\n")
            f.write("\n")
            
            # Stylized Facts
            f.write("## Stylized Facts\n\n")
            f.write("| Series | Ljung-Box p-value | ARCH-LM p-value | Hill Index | Excess Kurtosis |\n")
            f.write("|--------|-------------------|-----------------|------------|------------------|\n")
            for _, row in stylized_facts.iterrows():
                lb_pval = f"{row['Ljung_Box_p_value']:.3f}" if not pd.isna(row['Ljung_Box_p_value']) and isinstance(row['Ljung_Box_p_value'], (int, float)) else "N/A"
                arch_pval = f"{row['ARCH_LM_p_value']:.3f}" if not pd.isna(row['ARCH_LM_p_value']) and isinstance(row['ARCH_LM_p_value'], (int, float)) else "N/A"
                hill_idx = f"{row['Hill_Tail_Index']:.3f}" if not pd.isna(row['Hill_Tail_Index']) and isinstance(row['Hill_Tail_Index'], (int, float)) else "N/A"
                excess_kurt = f"{row['Excess_Kurtosis']:.3f}" if not pd.isna(row['Excess_Kurtosis']) and isinstance(row['Excess_Kurtosis'], (int, float)) else "N/A"
                f.write(f"| {row['Series']} | {lb_pval} | {arch_pval} | {hill_idx} | {excess_kurt} |\n")
            f.write("\n")
            
            # Interpretation
            f.write("## Interpretation Guide\n\n")
            f.write("### Summary Statistics\n")
            f.write("- **Skewness != 0:** Distribution is asymmetric\n")
            f.write("- **Excess Kurtosis > 0:** Heavier tails than normal\n")
            f.write("- **JB p-value < 0.05:** Reject normality\n\n")
            
            f.write("### Stationarity Tests\n")
            f.write("- **ADF p < 0.05:** Series is stationary (reject unit root)\n")
            f.write("- **KPSS p > 0.05:** Series is stationary (fail to reject stationarity)\n")
            f.write("- **Expected:** Price levels non-stationary, returns stationary\n\n")
            
            f.write("### Stylized Facts\n")
            f.write("- **Ljung-Box p < 0.05:** Evidence of serial correlation\n")
            f.write("- **ARCH-LM p < 0.05:** Evidence of volatility clustering (good for GARCH)\n")
            f.write("- **Hill Index > 3:** Heavy tails (Pareto-like distribution)\n\n")
            
            # Plots section
            f.write("## Generated Plots\n\n")
            f.write("The following plots have been generated:\n\n")
            f.write("- `prices.png` - Price series over time\n")
            f.write("- `returns.png` - Return series over time\n")
            f.write("- `corr_heatmap.png` - Correlation matrix heatmap\n")
            f.write("- `acf_[series].png` - Autocorrelation function for each series\n")
            f.write("- `qq_[series].png` - QQ plots for each series\n\n")
            
            f.write("## Files Generated\n\n")
            f.write("- `artifacts/eda/summary_stats.csv` - Summary statistics\n")
            f.write("- `artifacts/eda/stationarity.csv` - Stationarity test results\n")
            f.write("- `artifacts/eda/stylized_facts.csv` - Stylized facts analysis\n")
            f.write("- `reports/eda/*.png` - All generated plots\n\n")
    
    except Exception as e:
        print(f"❌ Error in report generation: {str(e)}")
        print(f"Error type: {type(e)}")
        import traceback
        traceback.print_exc()
        raise
    
    print(f"✅ Report saved to {report_path}")

def main():
    """Main EDA execution function"""
    parser = argparse.ArgumentParser(description='Financial Time Series EDA')
    parser.add_argument('--config', type=str, default='scripts/eda/configs/eda.yaml',
                       help='Path to configuration file')
    args = parser.parse_args()
    
    # Set random seed
    np.random.seed(123)
    
    # Suppress warnings for cleaner output
    import warnings
    warnings.filterwarnings('ignore', category=UserWarning)
    warnings.filterwarnings('ignore', category=FutureWarning)
    
    try:
        # Load configuration
        config = load_config(args.config)
        
        # Setup output directories
        setup_output_dirs(config)
        
        # Load data
        prices = load_data(config)
        
        # Compute returns
        returns = compute_returns(prices, config.return_type)
        
        # Perform analysis
        summary_stats = summary_statistics(returns)
        stationarity = stationarity_tests(returns, config.tests['adf_alpha'])
        stylized_facts_df = stylized_facts(returns, config)
        
        # Create plots
        create_plots(prices, returns, config)
        
        # Save results
        summary_stats.to_csv(f"{config.output_dirs['artifacts']}/summary_stats.csv", index=False)
        stationarity.to_csv(f"{config.output_dirs['artifacts']}/stationarity.csv", index=False)
        stylized_facts_df.to_csv(f"{config.output_dirs['artifacts']}/stylized_facts.csv", index=False)
        
        # Generate report
        generate_report(config, summary_stats, stationarity, stylized_facts_df)
        
        print("✅ EDA analysis completed successfully!")
        print(f"📁 Results saved to:")
        print(f"   - Artifacts: {config.output_dirs['artifacts']}")
        print(f"   - Reports: {config.output_dirs['reports']}")
        
    except Exception as e:
        print(f"❌ Error during EDA analysis: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
