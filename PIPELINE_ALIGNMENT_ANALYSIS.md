# 🔍 **PIPELINE ALIGNMENT ANALYSIS: run_all vs Modular Pipeline**

## 🎯 **Overview**

This analysis examines the alignment between the `run_all.bat` pipeline and the modular pipeline, and identifies missing NFGARCH-specific VaR and stress testing scripts in the execution files.

## 📊 **PIPELINE COMPONENT COMPARISON**

### **run_all.bat Pipeline Components**
1. **Step 1**: Generate missing NF residuals (`generate_missing_nf_residuals.py`)
2. **Step 2**: Run EDA (`eda_summary_stats.R`)
3. **Step 3**: Fit GARCH models (`fit_garch_models.R`)
4. **Step 4**: Extract residuals (`extract_residuals.R`)
5. **Step 5**: Train NF models (`train_nf_models.py`)
6. **Step 6**: Evaluate NF models (`evaluate_nf_fit.py`)
7. **Step 7**: NF-GARCH simulation MANUAL engine (`simulate_nf_garch_engine.R --engine manual`)
8. **Step 8**: NF-GARCH simulation RUGARCH engine (`simulate_nf_garch_engine.R --engine rugarch`)
9. **Step 9**: Legacy NF-GARCH simulation (`simulate_nf_garch.R`)
10. **Step 10**: Run forecasts (`forecast_garch_variants.R`)
11. **Step 11**: Evaluate forecasts (`wilcoxon_winrate_analysis.R`)
12. **Step 12**: Run stylized fact tests (`stylized_fact_tests.R`)
13. **Step 13**: Run VaR backtesting (`var_backtesting.R`)
14. **Step 14**: Run stress tests (`evaluate_under_stress.R`)
15. **Step 15**: Generate final summary
16. **Step 16**: Consolidate all results (`consolidate_results.R`)

### **Modular Pipeline Components**
1. **data_prep** - Data loading and preprocessing
2. **garch_fitting** - Standard GARCH model fitting
3. **residual_extraction** - Extract residuals for NF training
4. **nf_training** - Python NF model training
5. **nf_evaluation** - NF model evaluation
6. **nf_garch_manual** - NF-GARCH with manual engine
7. **nf_garch_rugarch** - NF-GARCH with rugarch engine
8. **forecasting** - Forecasting evaluation
9. **var_backtesting** - VaR backtesting
10. **stress_testing** - Stress testing
11. **stylized_facts** - Stylized facts analysis
12. **consolidation** - Final results consolidation

## ⚠️ **ALIGNMENT ISSUES IDENTIFIED**

### **1. Missing Components in Modular Pipeline**
❌ **Missing in Modular Pipeline**:
- **Step 1**: Generate missing NF residuals (`generate_missing_nf_residuals.py`)
- **Step 9**: Legacy NF-GARCH simulation (`simulate_nf_garch.R`)
- **Step 11**: Evaluate forecasts (`wilcoxon_winrate_analysis.R`)
- **Step 15**: Generate final summary

### **2. Different Script References**
⚠️ **Different Scripts Used**:
- **run_all.bat**: Uses `scripts/stress_tests/evaluate_under_stress.R`
- **Modular Pipeline**: Uses `scripts/evaluation/stylized_fact_tests.R` for stress testing

### **3. Missing NFGARCH-Specific Scripts**
❌ **Missing NFGARCH VaR and Stress Testing**:
- **NFGARCH VaR Backtesting**: `scripts/evaluation/nfgarch_var_backtesting.R` (EXISTS but NOT CALLED)
- **NFGARCH Stress Testing**: `scripts/evaluation/nfgarch_stress_testing.R` (EXISTS but NOT CALLED)

## 🚨 **CRITICAL FINDINGS**

### **NFGARCH Scripts Exist But Not Called**

#### **1. NFGARCH VaR Backtesting Script**
- **File**: `scripts/evaluation/nfgarch_var_backtesting.R` ✅ **EXISTS**
- **Purpose**: Performs VaR backtesting specifically on NF-GARCH models
- **Status**: ❌ **NOT CALLED** in either pipeline

#### **2. NFGARCH Stress Testing Script**
- **File**: `scripts/evaluation/nfgarch_stress_testing.R` ✅ **EXISTS**
- **Purpose**: Performs stress testing specifically on NF-GARCH models
- **Status**: ❌ **NOT CALLED** in either pipeline

### **Current VaR and Stress Testing Coverage**

#### **run_all.bat Pipeline**
- **Step 13**: `scripts/evaluation/var_backtesting.R` - Standard GARCH VaR only
- **Step 14**: `scripts/stress_tests/evaluate_under_stress.R` - Standard GARCH stress testing only

#### **Modular Pipeline**
- **var_backtesting**: `scripts/evaluation/var_backtesting.R` - Standard GARCH VaR only
- **stress_testing**: `scripts/evaluation/stylized_fact_tests.R` - Wrong script (should be stress testing)

## 🔧 **RECOMMENDED FIXES**

### **1. Update run_all.bat to Include NFGARCH Scripts**

Add these steps after the existing VaR and stress testing:

```batch
REM Step 13.5: Run NFGARCH VaR backtesting (NEW)
echo Step 13.5: Running NFGARCH VaR backtesting...
Rscript scripts\evaluation\nfgarch_var_backtesting.R
if %errorlevel% neq 0 (
    echo WARNING: NFGARCH VaR backtesting failed, continuing...
)

REM Step 14.5: Run NFGARCH stress testing (NEW)
echo Step 14.5: Running NFGARCH stress testing...
Rscript scripts\evaluation\nfgarch_stress_testing.R
if %errorlevel% neq 0 (
    echo WARNING: NFGARCH stress testing failed, continuing...
)
```

### **2. Update Modular Pipeline Components**

#### **Fix var_backtesting.R Component**
```r
# Current (incomplete)
source("scripts/evaluation/var_backtesting.R")

# Should be (complete)
source("scripts/evaluation/var_backtesting.R")
source("scripts/evaluation/nfgarch_var_backtesting.R")
```

#### **Fix stress_testing.R Component**
```r
# Current (wrong script)
source("scripts/evaluation/stylized_fact_tests.R")

# Should be (correct)
source("scripts/stress_tests/evaluate_under_stress.R")
source("scripts/evaluation/nfgarch_stress_testing.R")
```

### **3. Add Missing Components to Modular Pipeline**

Add these components to the modular pipeline:
- **nf_residual_generation** - Generate missing NF residuals
- **forecast_evaluation** - Wilcoxon winrate analysis
- **final_summary** - Generate final summary

## 📋 **DETAILED COMPONENT MAPPING**

### **✅ Properly Aligned Components**

| run_all.bat | Modular Pipeline | Status |
|-------------|------------------|---------|
| Step 2 (EDA) | data_prep | ✅ Aligned |
| Step 3 (GARCH) | garch_fitting | ✅ Aligned |
| Step 4 (Residuals) | residual_extraction | ✅ Aligned |
| Step 5 (NF Training) | nf_training | ✅ Aligned |
| Step 6 (NF Eval) | nf_evaluation | ✅ Aligned |
| Step 7 (NF-GARCH Manual) | nf_garch_manual | ✅ Aligned |
| Step 8 (NF-GARCH rugarch) | nf_garch_rugarch | ✅ Aligned |
| Step 10 (Forecasting) | forecasting | ✅ Aligned |
| Step 12 (Stylized Facts) | stylized_facts | ✅ Aligned |
| Step 16 (Consolidation) | consolidation | ✅ Aligned |

### **❌ Missing or Misaligned Components**

| run_all.bat | Modular Pipeline | Issue |
|-------------|------------------|-------|
| Step 1 (NF Residuals) | ❌ Missing | Not in modular |
| Step 9 (Legacy NF-GARCH) | ❌ Missing | Not in modular |
| Step 11 (Forecast Eval) | ❌ Missing | Not in modular |
| Step 13 (VaR) | var_backtesting | ❌ Missing NFGARCH |
| Step 14 (Stress) | stress_testing | ❌ Wrong script + Missing NFGARCH |
| Step 15 (Summary) | ❌ Missing | Not in modular |

## 🎯 **IMMEDIATE ACTION REQUIRED**

### **Priority 1: Add NFGARCH Scripts to run_all.bat**
1. Add NFGARCH VaR backtesting after Step 13
2. Add NFGARCH stress testing after Step 14

### **Priority 2: Fix Modular Pipeline Components**
1. Update `var_backtesting.R` to include NFGARCH VaR
2. Update `stress_testing.R` to use correct script and include NFGARCH stress testing

### **Priority 3: Align Missing Components**
1. Add missing components to modular pipeline
2. Ensure both pipelines produce identical results

## 📊 **IMPACT ANALYSIS**

### **Current Coverage**
- **Standard GARCH**: ✅ Fully covered (VaR + Stress Testing)
- **NF-GARCH**: ❌ **Partially covered** (Missing VaR + Stress Testing)

### **Missing Analysis**
- **NFGARCH VaR Backtesting**: Kupiec, Christoffersen, Dynamic Quantile tests
- **NFGARCH Stress Testing**: Market crash, volatility spike, correlation breakdown scenarios
- **NFGARCH Robustness Scores**: Model performance under extreme conditions

### **Dissertation Impact**
- **Current**: Only standard GARCH VaR and stress testing results
- **Missing**: NFGARCH-specific risk assessment and stress testing
- **Gap**: Cannot fully compare NF-GARCH vs standard GARCH risk performance

## ✅ **CONCLUSION**

### **Alignment Status**: ⚠️ **PARTIALLY ALIGNED**

**Issues Found**:
1. ❌ NFGARCH VaR and stress testing scripts exist but are NOT called
2. ❌ Modular pipeline uses wrong script for stress testing
3. ❌ Several components missing from modular pipeline
4. ❌ Incomplete risk assessment coverage for NF-GARCH models

**Immediate Fixes Needed**:
1. Add NFGARCH scripts to `run_all.bat`
2. Fix modular pipeline component scripts
3. Ensure both pipelines produce identical comprehensive results

**Impact**: Currently missing critical NFGARCH risk assessment results needed for dissertation comparison.
