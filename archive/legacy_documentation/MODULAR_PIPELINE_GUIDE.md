# Modular NF-GARCH Pipeline Guide

## Overview

The modular pipeline system allows you to run the NF-GARCH research pipeline in independent components with checkpointing. This means you can:

- **Run components independently** - no need to restart from scratch
- **Resume from where you left off** - checkpoint-based execution
- **Parallel processing** - run different components simultaneously
- **Better error isolation** - one component failing doesn't break everything

## Quick Start

### Basic Commands

```bash
# Check pipeline status
.\run_modular.bat status

# Run full pipeline
.\run_modular.bat

# Run specific component
.\run_modular.bat run nf_garch_manual

# Reset a component (to re-run it)
.\run_modular.bat reset nf_training

# Show help
.\run_modular.bat help
```

### Direct R Script Usage

```bash
# Check status
Rscript scripts\modular_pipeline\run_modular_pipeline.R status

# Run specific component
Rscript scripts\modular_pipeline\run_modular_pipeline.R run nf_garch_manual

# Reset component
Rscript scripts\modular_pipeline\run_modular_pipeline.R reset nf_training
```

## Pipeline Components

### 1. Data Preparation (`data_prep`)
- **Purpose**: Loads and processes raw financial data
- **Dependencies**: None
- **Output**: Processed FX and equity returns data
- **Files**: `modular_results/processed_data.rds`

### 2. GARCH Model Fitting (`garch_fitting`)
- **Purpose**: Fits standard GARCH models (sGARCH, GJR-GARCH, eGARCH, TGARCH)
- **Dependencies**: `data_prep`
- **Output**: Fitted GARCH models for both chronological and TS CV splits
- **Files**: `outputs/GARCH_Fitting_Results.xlsx`

### 3. Residual Extraction (`residual_extraction`)
- **Purpose**: Extracts residuals from fitted GARCH models for NF training
- **Dependencies**: `garch_fitting`
- **Output**: Residual CSV files for each asset-model combination
- **Files**: `residuals/*.csv`

### 4. NF Model Training (`nf_training`)
- **Purpose**: Trains Normalizing Flow models on extracted residuals
- **Dependencies**: `residual_extraction`
- **Output**: Trained NF models and generated innovations
- **Files**: `nf_generated_residuals/*.csv`

### 5. NF Model Evaluation (`nf_evaluation`)
- **Purpose**: Evaluates trained NF models
- **Dependencies**: `nf_training`
- **Output**: NF model evaluation metrics
- **Files**: `outputs/NF_Evaluation_Results.xlsx`

### 6. NF-GARCH Manual Engine (`nf_garch_manual`)
- **Purpose**: Runs NF-GARCH simulation using manual GARCH engine
- **Dependencies**: `nf_evaluation`, `garch_fitting`
- **Output**: NF-GARCH results with manual engine
- **Files**: `NF_GARCH_Results_manual.xlsx`

### 7. NF-GARCH Rugarch Engine (`nf_garch_rugarch`)
- **Purpose**: Runs NF-GARCH simulation using rugarch engine
- **Dependencies**: `nf_evaluation`, `garch_fitting`
- **Output**: NF-GARCH results with rugarch engine
- **Files**: `NF_GARCH_Results_rugarch.xlsx`

### 8. Forecasting Evaluation (`forecasting`)
- **Purpose**: Evaluates forecasting performance
- **Dependencies**: `garch_fitting`
- **Output**: Forecasting evaluation results
- **Files**: `outputs/Forecasting_Results.xlsx`

### 9. VaR Backtesting (`var_backtesting`)
- **Purpose**: Performs VaR backtesting
- **Dependencies**: `garch_fitting`, `nf_garch_manual`, `nf_garch_rugarch`
- **Output**: VaR backtesting results
- **Files**: `outputs/VaR_Backtesting_Results.xlsx`

### 10. Stress Testing (`stress_testing`)
- **Purpose**: Performs stress testing
- **Dependencies**: `garch_fitting`, `nf_garch_manual`, `nf_garch_rugarch`
- **Output**: Stress testing results
- **Files**: `outputs/Stress_Testing_Results.xlsx`

### 11. Stylized Facts Analysis (`stylized_facts`)
- **Purpose**: Analyzes stylized facts
- **Dependencies**: `garch_fitting`, `nf_garch_manual`, `nf_garch_rugarch`
- **Output**: Stylized facts analysis results
- **Files**: `outputs/Stylized_Facts_Results.xlsx`

### 12. Results Consolidation (`consolidation`)
- **Purpose**: Consolidates all results into a single Excel file
- **Dependencies**: `var_backtesting`, `stress_testing`, `stylized_facts`
- **Output**: Consolidated results file
- **Files**: `Consolidated_NF_GARCH_Results.xlsx`

## Checkpoint System

### How It Works

The pipeline uses a JSON-based checkpoint system stored in `checkpoints/pipeline_status.json`. Each component's status is tracked with:

- **Status**: `completed`, `failed`, or `not started`
- **Timestamp**: When the component was last run
- **Error**: Error message if the component failed

### Checkpoint Management

```bash
# View all checkpoints
.\run_modular.bat status

# Reset a specific component
.\run_modular.bat reset nf_training

# Reset multiple components
.\run_modular.bat reset nf_training
.\run_modular.bat reset nf_evaluation
```

## Common Workflows

### 1. Full Pipeline Run
```bash
.\run_modular.bat
```

### 2. Manual Engine Only
```bash
# Ensure dependencies are met
.\run_modular.bat run data_prep
.\run_modular.bat run garch_fitting
.\run_modular.bat run residual_extraction
.\run_modular.bat run nf_training
.\run_modular.bat run nf_evaluation

# Run manual engine
.\run_modular.bat run nf_garch_manual
```

### 3. Rugarch Engine Only
```bash
# Ensure dependencies are met (same as above)
.\run_modular.bat run nf_garch_rugarch
```

### 4. Evaluation Only (if models already fitted)
```bash
.\run_modular.bat run forecasting
.\run_modular.bat run var_backtesting
.\run_modular.bat run stress_testing
.\run_modular.bat run stylized_facts
.\run_modular.bat run consolidation
```

### 5. Resume After Failure
```bash
# Check what failed
.\run_modular.bat status

# Reset the failed component
.\run_modular.bat reset failed_component

# Continue from where you left off
.\run_modular.bat
```

## Error Handling

### Common Issues

1. **Missing Dependencies**: If a component fails due to missing dependencies, check the status and run the required components first.

2. **Python Environment Issues**: If NF training/evaluation fails, ensure Python environment is properly set up:
   ```bash
   python scripts\utils\fix_python_env.py
   ```

3. **R Package Issues**: If R components fail, ensure all required packages are installed:
   ```r
   install.packages(c("openxlsx", "dplyr", "tidyr", "stringr", "readxl", "jsonlite"))
   ```

### Debugging

1. **Check Component Logs**: Each component creates detailed logs in the console output.

2. **Reset and Retry**: If a component fails, reset it and try again:
   ```bash
   .\run_modular.bat reset component_name
   .\run_modular.bat run component_name
   ```

3. **Manual Execution**: You can run components manually by sourcing the individual scripts:
   ```r
   source("scripts/modular_pipeline/components/data_preparation.R")
   ```

## File Structure

```
scripts/modular_pipeline/
├── run_modular_pipeline.R          # Main orchestrator
├── components/
│   ├── data_preparation.R          # Data loading
│   ├── garch_fitting.R             # GARCH model fitting
│   ├── residual_extraction.R       # Residual extraction
│   ├── nf_training.py              # NF training (Python)
│   ├── nf_evaluation.py            # NF evaluation (Python)
│   ├── forecasting_evaluation.R    # Forecasting evaluation
│   ├── var_backtesting.R           # VaR backtesting
│   ├── stress_testing.R            # Stress testing
│   └── stylized_facts.R            # Stylized facts analysis
├── checkpoints/
│   └── pipeline_status.json        # Checkpoint file
└── modular_results/
    └── processed_data.rds          # Cached processed data
```

## Performance Tips

1. **Parallel Execution**: You can run independent components in parallel (e.g., `nf_garch_manual` and `nf_garch_rugarch`).

2. **Caching**: The pipeline caches processed data to avoid re-processing.

3. **Selective Execution**: Only run the components you need for your current analysis.

4. **Resource Management**: Monitor system resources during heavy computations (NF training, GARCH fitting).

## Troubleshooting

### Component Fails to Start
- Check if dependencies are met: `.\run_modular.bat status`
- Ensure required files exist
- Check R/Python environment

### Component Fails During Execution
- Check console output for error messages
- Reset the component and try again
- Verify input data quality

### Pipeline Hangs
- Check system resources (CPU, memory)
- Kill the process and restart
- Consider running components individually

## Advanced Usage

### Custom Component Execution
You can modify the component scripts in `scripts/modular_pipeline/components/` to customize behavior.

### Adding New Components
1. Add the component to `PIPELINE_CONFIG$components`
2. Define dependencies in `PIPELINE_CONFIG$dependencies`
3. Create the component script
4. Add execution function to the main orchestrator

### Batch Processing
Create batch files for common workflows:
```batch
@echo off
REM Run manual engine workflow
.\run_modular.bat run data_prep
.\run_modular.bat run garch_fitting
.\run_modular.bat run residual_extraction
.\run_modular.bat run nf_training
.\run_modular.bat run nf_evaluation
.\run_modular.bat run nf_garch_manual
```

## Support

For issues or questions:
1. Check the console output for error messages
2. Verify the checkpoint status
3. Ensure all dependencies are properly installed
4. Check file permissions and paths
