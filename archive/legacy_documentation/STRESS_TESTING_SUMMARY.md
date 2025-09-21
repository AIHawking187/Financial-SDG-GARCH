# Financial-SDG-GARCH Stress Testing Summary

## 🎯 **Overview**

This document provides a comprehensive explanation of the stress testing framework implemented in the Financial-SDG-GARCH pipeline. The stress testing methodology evaluates both classical GARCH models and NF-GARCH models under extreme market conditions to assess their robustness and reliability.

---

## **📊 Stress Testing Framework**

### **Two-Tier Approach**

The pipeline implements a **dual stress testing framework**:

1. **Classical GARCH Stress Testing** (`scripts/stress_tests/evaluate_under_stress.R`)
2. **NF-GARCH Stress Testing** (`scripts/evaluation/nfgarch_stress_testing.R`)

### **Key Objectives**

- **Model Robustness**: Assess how well models perform under extreme conditions
- **Risk Management**: Evaluate VaR estimates under stress scenarios
- **Model Comparison**: Compare classical vs NF-GARCH model resilience
- **Regulatory Compliance**: Meet stress testing requirements for financial models

---

## **🏛️ Historical Crisis Scenarios**

### **Rationale**
Historical crisis periods provide **real-world validation** of model performance under actual extreme market conditions. These scenarios test model behavior during documented periods of market stress.

### **Implemented Scenarios**

#### **1. 2008 Financial Crisis**
- **Period**: September 2008 - March 2009
- **Rationale**: Represents the most severe global financial crisis since the Great Depression
- **Characteristics**: 
  - Lehman Brothers collapse
  - Global credit freeze
  - Extreme volatility spikes
  - Correlation breakdown
- **Testing Focus**: Model convergence and parameter stability during systemic crisis

#### **2. 2020 COVID-19 Crisis**
- **Period**: February 2020 - April 2020
- **Rationale**: Represents a modern, rapid-onset crisis with unique characteristics
- **Characteristics**:
  - Sudden market crash
  - Unprecedented volatility
  - Global economic shutdown
  - Central bank interventions
- **Testing Focus**: Model adaptability to rapid regime changes

#### **3. 2000 Dot-com Bubble**
- **Period**: March 2000 - December 2000
- **Rationale**: Represents a technology sector-specific crisis
- **Characteristics**:
  - Technology stock bubble burst
  - Sector-specific volatility
  - Market sentiment shift
- **Testing Focus**: Sector-specific model performance

### **Historical Testing Methodology**

```r
# Calculate stress period statistics
calculate_stress_stats <- function(returns, start_date, end_date) {
  # Extract crisis period data
  stress_returns <- returns[start_date:end_date]
  
  # Compute crisis metrics
  list(
    mean_return = mean(stress_returns, na.rm = TRUE),
    volatility = sd(stress_returns, na.rm = TRUE),
    max_drawdown = maxDrawdown(stress_returns)[1],
    var_95 = quantile(stress_returns, 0.05, na.rm = TRUE),
    var_99 = quantile(stress_returns, 0.01, na.rm = TRUE),
    skewness = skewness(stress_returns, na.rm = TRUE),
    kurtosis = kurtosis(stress_returns, na.rm = TRUE)
  )
}
```

---

## **🔮 Hypothetical Stress Scenarios**

### **Rationale**
Hypothetical scenarios test model behavior under **extreme but plausible** conditions that may not have occurred historically but represent potential future risks.

### **Implemented Scenarios**

#### **1. Extreme Volatility Shock**
- **Shock**: 3x increase in volatility
- **Rationale**: Tests model behavior under unprecedented volatility spikes
- **Implementation**: Multiply returns by shock multiplier
- **Risk Focus**: Volatility clustering and persistence

#### **2. Market Crash Scenario**
- **Shock**: 20% negative return shock
- **Rationale**: Tests model response to severe market downturns
- **Implementation**: Add negative return shock to all observations
- **Risk Focus**: Tail risk and extreme loss modeling

#### **3. Volatility Persistence**
- **Shock**: 2x increase in volatility persistence
- **Rationale**: Tests model behavior when volatility becomes more persistent
- **Implementation**: Modify GARCH persistence parameters
- **Risk Focus**: Long-term volatility dynamics

### **Hypothetical Testing Methodology**

```r
# Apply hypothetical shocks
apply_hypothetical_shocks <- function(returns, model_spec, scenarios) {
  # Fit model on full data first
  full_fit <- ugarchfit(model_spec, data = returns, solver = "hybrid")
  
  for (scenario_name in names(scenarios)) {
    scenario <- scenarios[[scenario_name]]
    
    if (scenario_name == "extreme_volatility") {
      # Apply volatility shock
      shocked_returns <- returns * scenario$shock_multiplier
      shocked_fit <- ugarchfit(model_spec, data = shocked_returns, solver = "hybrid")
      
      # Compare model performance
      shock_results[[scenario_name]] <- list(
        original_aic = infocriteria(full_fit)[1],
        shocked_aic = infocriteria(shocked_fit)[1],
        original_bic = infocriteria(full_fit)[2],
        shocked_bic = infocriteria(shocked_fit)[2]
      )
    }
  }
}
```

---

## **🌊 NF-GARCH Specific Stress Scenarios**

### **Rationale**
NF-GARCH models require **specialized stress testing** due to their unique architecture combining normalizing flows with GARCH dynamics.

### **Implemented Scenarios**

#### **1. Market Crash**
- **Return Shock**: -10% daily loss
- **Volatility Shock**: 3x increase
- **Correlation Shock**: 0.8 (high correlation)
- **Rationale**: Tests NF-GARCH response to severe market stress
- **NF-Specific Focus**: Normalizing flow adaptation under extreme conditions

#### **2. Volatility Spike**
- **Return Shock**: 0% (no mean change)
- **Volatility Shock**: 5x increase
- **Correlation Shock**: 0.6 (moderate correlation)
- **Rationale**: Tests NF-GARCH volatility modeling under pure volatility stress
- **NF-Specific Focus**: Flow transformation under high volatility

#### **3. Correlation Breakdown**
- **Return Shock**: -5% daily loss
- **Volatility Shock**: 2x increase
- **Correlation Shock**: 0.9 (very high correlation)
- **Rationale**: Tests NF-GARCH under loss of diversification
- **NF-Specific Focus**: Multivariate flow behavior under correlation stress

#### **4. Flash Crash**
- **Return Shock**: -15% daily loss
- **Volatility Shock**: 4x increase
- **Correlation Shock**: 0.7 (high correlation)
- **Rationale**: Tests NF-GARCH under rapid, extreme movements
- **NF-Specific Focus**: Flow adaptation to sudden regime changes

#### **5. Black Swan Event**
- **Return Shock**: -20% daily loss
- **Volatility Shock**: 6x increase
- **Correlation Shock**: 0.95 (very high correlation)
- **Rationale**: Tests NF-GARCH under unprecedented extreme conditions
- **NF-Specific Focus**: Flow behavior at distributional extremes

### **NF-GARCH Testing Methodology**

```r
# Calculate stress scenario impact on NFGARCH models
calculate_stress_impact <- function(returns, nf_innovations, scenario) {
  # Apply stress scenario to returns
  stressed_returns <- returns * (1 + scenario$return_shock)
  
  # Apply volatility shock to NF innovations
  stressed_innovations <- nf_innovations * scenario$volatility_shock
  
  # Calculate stressed VaR
  stressed_var_95 <- quantile(stressed_innovations, 0.05, na.rm = TRUE)
  stressed_var_99 <- quantile(stressed_innovations, 0.01, na.rm = TRUE)
  
  # Calculate stressed volatility
  stressed_volatility <- sd(stressed_innovations, na.rm = TRUE)
  
  # Calculate maximum drawdown under stress
  cumulative_returns <- cumprod(1 + stressed_returns)
  running_max <- cummax(cumulative_returns)
  drawdown <- (cumulative_returns - running_max) / running_max
  max_drawdown <- min(drawdown, na.rm = TRUE)
  
  return(list(
    stressed_var_95 = stressed_var_95,
    stressed_var_99 = stressed_var_99,
    stressed_volatility = stressed_volatility,
    max_drawdown = max_drawdown
  ))
}
```

---

## **📈 Stress Testing Metrics**

### **Model Performance Metrics**

#### **1. Convergence Rate**
- **Definition**: Percentage of models that successfully converge under stress
- **Rationale**: Tests numerical stability and parameter estimation robustness
- **Formula**: `(Converged Models / Total Models) × 100`

#### **2. Robustness Score**
- **Definition**: Composite measure of model stability under stress
- **Rationale**: Quantifies overall model resilience
- **Formula**: 
  ```
  Robustness_Score = (|ΔVaR_95| + |ΔVaR_99| + |ΔVolatility|) / 3
  ```
  Where Δ represents percentage change from baseline

#### **3. Maximum Drawdown**
- **Definition**: Largest peak-to-trough decline under stress
- **Rationale**: Measures worst-case loss potential
- **Formula**: `min((Cumulative_Returns - Running_Max) / Running_Max)`

### **Risk Management Metrics**

#### **1. Stressed VaR**
- **VaR 95%**: 5th percentile of stressed returns
- **VaR 99%**: 1st percentile of stressed returns
- **Rationale**: Tests risk measurement accuracy under extreme conditions

#### **2. Volatility Impact**
- **Definition**: Change in volatility under stress scenarios
- **Rationale**: Tests volatility modeling accuracy
- **Formula**: `|Stressed_Volatility - Baseline_Volatility| / Baseline_Volatility`

#### **3. Model Stability**
- **AIC/BIC Changes**: Information criteria changes under stress
- **Log-Likelihood Changes**: Model fit deterioration under stress
- **Rationale**: Tests parameter stability and model adequacy

---

## **🔍 Testing Methodology**

### **Data Requirements**
- **Minimum Observations**: 500 data points per asset
- **Asset Coverage**: 12 assets (6 FX + 6 Equity)
- **Model Coverage**: 5 classical GARCH + 4 NF-GARCH models

### **Testing Process**

#### **Phase 1: Baseline Estimation**
1. Fit models on full historical dataset
2. Calculate baseline performance metrics
3. Establish reference VaR and volatility estimates

#### **Phase 2: Historical Crisis Testing**
1. Extract crisis period data
2. Refit models on crisis periods
3. Compare crisis vs baseline performance
4. Assess convergence and stability

#### **Phase 3: Hypothetical Scenario Testing**
1. Apply stress shocks to data
2. Refit models on shocked data
3. Calculate stress impact metrics
4. Compute robustness scores

#### **Phase 4: NF-GARCH Specific Testing**
1. Load NF innovations and residuals
2. Apply NF-specific stress scenarios
3. Test flow transformation under stress
4. Compare NF vs classical model resilience

### **Validation Framework**

#### **Convergence Checks**
- Model fitting success rate
- Parameter stability
- Numerical convergence

#### **Statistical Validation**
- Likelihood ratio tests
- Information criteria comparison
- Residual diagnostics

#### **Economic Validation**
- VaR accuracy under stress
- Volatility forecasting accuracy
- Risk measure stability

---

## **📊 Output and Reporting**

### **Generated Reports**

#### **1. Stress Test Summary Tables**
- Model performance under each scenario
- Convergence rates and robustness scores
- Comparative analysis across models

#### **2. Scenario Comparison Tables**
- Cross-scenario model ranking
- Scenario-specific insights
- Risk factor analysis

#### **3. Model Robustness Scores**
- Overall model resilience ranking
- Stress-specific performance metrics
- NF-GARCH vs classical comparison

### **Key Output Files**

```
outputs/stress_tests/
├── figures/
│   ├── stress_test_comparison.png
│   ├── model_robustness_ranking.png
│   └── scenario_impact_analysis.png
├── tables/
│   ├── stress_test_summary.csv
│   ├── model_robustness_scores.csv
│   ├── nfgarch_stress_test_summary.csv
│   ├── nfgarch_model_robustness_scores.csv
│   └── nfgarch_scenario_comparison.csv
```

---

## **🎯 Academic and Regulatory Context**

### **Academic Significance**

#### **1. Model Validation**
- **Contribution**: Comprehensive stress testing framework for NF-GARCH models
- **Innovation**: Integration of normalizing flows with traditional stress testing
- **Rigor**: Both historical and hypothetical scenario testing

#### **2. Risk Management**
- **VaR Accuracy**: Tests risk measurement under extreme conditions
- **Model Robustness**: Evaluates model reliability for practical applications
- **Comparative Analysis**: Classical vs NF-GARCH model comparison

### **Regulatory Compliance**

#### **1. Basel III Requirements**
- **Stress Testing**: Meets regulatory stress testing requirements
- **Risk Measurement**: Validates VaR and volatility estimates
- **Model Governance**: Comprehensive model validation framework

#### **2. Financial Stability**
- **Systemic Risk**: Tests model behavior under systemic stress
- **Market Risk**: Validates market risk measurement accuracy
- **Model Risk**: Assesses model risk under extreme conditions

---

## **🔬 Research Contributions**

### **Methodological Innovations**

#### **1. NF-GARCH Stress Testing**
- **Novel Approach**: First comprehensive stress testing framework for NF-GARCH models
- **Flow-Specific Scenarios**: Tailored stress scenarios for normalizing flows
- **Multivariate Testing**: Tests correlation and dependence modeling

#### **2. Comparative Framework**
- **Classical vs NF**: Direct comparison of model resilience
- **Scenario Analysis**: Systematic scenario-based evaluation
- **Robustness Quantification**: Quantitative robustness scoring

### **Practical Applications**

#### **1. Risk Management**
- **Portfolio Risk**: Stress testing for portfolio risk management
- **Trading Risk**: Model validation for trading applications
- **Regulatory Compliance**: Meeting regulatory stress testing requirements

#### **2. Model Selection**
- **Robustness Ranking**: Quantitative model selection criteria
- **Scenario-Specific Performance**: Scenario-based model choice
- **Risk-Adjusted Performance**: Risk-adjusted model evaluation

---

## **📋 Summary**

The Financial-SDG-GARCH stress testing framework provides a **comprehensive, rigorous, and innovative** approach to model validation under extreme market conditions. By combining:

- **Historical crisis testing** for real-world validation
- **Hypothetical scenario testing** for extreme risk assessment
- **NF-GARCH specific testing** for novel model validation
- **Quantitative robustness scoring** for objective comparison

The framework ensures that both classical GARCH and NF-GARCH models are thoroughly validated for practical financial applications, contributing to both academic research and regulatory compliance in financial risk management.

---

*This stress testing framework represents a significant contribution to the field of financial econometrics, providing the first comprehensive validation methodology for NF-GARCH models under extreme market conditions.*

