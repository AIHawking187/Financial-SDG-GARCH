#!/usr/bin/env Rscript
# Consolidated Results Generator
# Combines all NF-GARCH pipeline results into a single comprehensive Excel document

library(openxlsx)
library(dplyr)
library(tidyr)
library(stringr)
library(readxl)

consolidate_all_results <- function() {
  cat("=== CONSOLIDATING ALL PIPELINE RESULTS ===\n")
  
  # Create a new workbook
  wb <- createWorkbook()
  
  # Initialize results tracking
  all_results <- list()
  summary_stats <- list()
  
  # 1. Load GARCH Model Fitting Results
  cat("Loading GARCH model fitting results...\n")
  tryCatch({
    if (file.exists("Initial_GARCH_Model_Fitting.xlsx")) {
      chrono_results <- read_excel("Initial_GARCH_Model_Fitting.xlsx", sheet = "Chrono_Split_Eval")
      cv_results <- read_excel("Initial_GARCH_Model_Fitting.xlsx", sheet = "CV_Results")
      model_ranking <- read_excel("Initial_GARCH_Model_Fitting.xlsx", sheet = "Model_Ranking_All")
      
      all_results$chrono_split <- chrono_results
      all_results$cv_split <- cv_results
      all_results$model_ranking <- model_ranking
      
      cat("✓ Loaded GARCH fitting results\n")
    }
  }, error = function(e) {
    cat("⚠️ Could not load GARCH fitting results:", e$message, "\n")
  })
  
  # 2. Load NF-GARCH Results (both engines)
  cat("Loading NF-GARCH results...\n")
  nf_files <- list.files(pattern = "NF_GARCH_Results_.*\\.xlsx", full.names = TRUE)
  
  for (file in nf_files) {
    engine_name <- str_extract(file, "(?<=NF_GARCH_Results_)[^.]+")
    tryCatch({
      # Load all sheets from NF-GARCH results
      sheets <- excel_sheets(file)
      for (sheet in sheets) {
        nf_data <- read_excel(file, sheet = sheet)
        nf_data$Engine <- engine_name
        nf_data$Model_Type <- "NF-GARCH"
        nf_data$Sheet_Name <- sheet
        
        all_results[[paste0("nf_garch_", engine_name, "_", sheet)]] <- nf_data
      }
      cat("✓ Loaded NF-GARCH results for", engine_name, "engine (", length(sheets), "sheets)\n")
    }, error = function(e) {
      cat("⚠️ Could not load NF-GARCH results from", file, ":", e$message, "\n")
    })
  }
  
  # 3. Load Forecasting Results
  cat("Loading forecasting results...\n")
  tryCatch({
    forecast_files <- list.files("outputs/model_eval/tables", pattern = ".*forecast.*\\.csv", full.names = TRUE)
    for (file in forecast_files) {
      forecast_data <- read.csv(file)
      file_name <- basename(file)
      all_results[[paste0("forecast_", file_name)]] <- forecast_data
    }
    cat("✓ Loaded forecasting results\n")
  }, error = function(e) {
    cat("⚠️ Could not load forecasting results:", e$message, "\n")
  })
  
  # 4. Load VaR Backtesting Results
  cat("Loading VaR backtesting results...\n")
  tryCatch({
    var_files <- list.files("outputs/var_backtest/tables", pattern = ".*\\.csv", full.names = TRUE)
    for (file in var_files) {
      var_data <- read.csv(file)
      file_name <- basename(file)
      all_results[[paste0("var_", file_name)]] <- var_data
    }
    cat("✓ Loaded VaR backtesting results\n")
  }, error = function(e) {
    cat("⚠️ Could not load VaR backtesting results:", e$message, "\n")
  })
  
  # 5. Load Stress Testing Results
  cat("Loading stress testing results...\n")
  tryCatch({
    stress_files <- list.files("outputs/stress_tests/tables", pattern = ".*\\.csv", full.names = TRUE)
    for (file in stress_files) {
      stress_data <- read.csv(file)
      file_name <- basename(file)
      all_results[[paste0("stress_", file_name)]] <- stress_data
    }
    cat("✓ Loaded stress testing results\n")
  }, error = function(e) {
    cat("⚠️ Could not load stress testing results:", e$message, "\n")
  })
  
  # 6. Load Stylized Facts Results
  cat("Loading stylized facts results...\n")
  tryCatch({
    stylized_files <- list.files("outputs/model_eval/tables", pattern = ".*stylized.*\\.csv", full.names = TRUE)
    for (file in stylized_files) {
      stylized_data <- read.csv(file)
      file_name <- basename(file)
      all_results[[paste0("stylized_", file_name)]] <- stylized_data
    }
    cat("✓ Loaded stylized facts results\n")
  }, error = function(e) {
    cat("⚠️ Could not load stylized facts results:", e$message, "\n")
  })
  
  # 7. Load Model Evaluation Results
  cat("Loading model evaluation results...\n")
  tryCatch({
    eval_files <- list.files("outputs/model_eval/tables", pattern = ".*\\.csv", full.names = TRUE)
    for (file in eval_files) {
      eval_data <- read.csv(file)
      file_name <- basename(file)
      all_results[[paste0("eval_", file_name)]] <- eval_data
    }
    cat("✓ Loaded model evaluation results\n")
  }, error = function(e) {
    cat("⚠️ Could not load model evaluation results:", e$message, "\n")
  })
  
  # 8. Load Supplementary Results
  cat("Loading supplementary results...\n")
  tryCatch({
    if (file.exists("outputs/supplementary/all_per_asset_metrics.xlsx")) {
      supp_sheets <- excel_sheets("outputs/supplementary/all_per_asset_metrics.xlsx")
      for (sheet in supp_sheets) {
        supp_data <- read_excel("outputs/supplementary/all_per_asset_metrics.xlsx", sheet = sheet)
        all_results[[paste0("supplementary_", sheet)]] <- supp_data
      }
      cat("✓ Loaded supplementary results (", length(supp_sheets), "sheets)\n")
    }
  }, error = function(e) {
    cat("⚠️ Could not load supplementary results:", e$message, "\n")
  })
  
  # 9. Load EDA Results
  cat("Loading EDA results...\n")
  tryCatch({
    eda_files <- list.files("outputs/eda/tables", pattern = ".*\\.csv", full.names = TRUE, recursive = TRUE)
    for (file in eda_files) {
      eda_data <- read.csv(file)
      file_name <- basename(file)
      all_results[[paste0("eda_", file_name)]] <- eda_data
    }
    cat("✓ Loaded EDA results\n")
  }, error = function(e) {
    cat("⚠️ Could not load EDA results:", e$message, "\n")
  })
  
  # 10. Create Summary Statistics
  cat("Creating summary statistics...\n")
  summary_stats$total_models <- length(all_results)
  summary_stats$total_assets <- 12  # 6 FX + 6 Equity
  summary_stats$total_garch_models <- 5  # sGARCH_norm, sGARCH_sstd, gjrGARCH, eGARCH, TGARCH
  
  # 11. Create Consolidated Comparison Sheet
  cat("Creating consolidated comparison...\n")
  consolidated_data <- data.frame()
  
  # Combine all results for comparison with proper data type handling
  for (result_name in names(all_results)) {
    if (is.data.frame(all_results[[result_name]]) && nrow(all_results[[result_name]]) > 0) {
      df <- all_results[[result_name]]
      df$Source <- result_name
      
      # Convert all columns to character to avoid data type conflicts
      df <- df %>% mutate(across(everything(), as.character))
      
      # If this is the first dataframe, use it as the base
      if (nrow(consolidated_data) == 0) {
        consolidated_data <- df
      } else {
        # For subsequent dataframes, ensure column compatibility
        common_cols <- intersect(names(consolidated_data), names(df))
        if (length(common_cols) > 0) {
          # Only bind rows for common columns
          consolidated_data <- bind_rows(
            consolidated_data %>% select(all_of(common_cols)),
            df %>% select(all_of(common_cols))
          )
        }
      }
    }
  }
  
  # 12. Create Model Performance Summary
  cat("Creating model performance summary...\n")
  if (nrow(consolidated_data) > 0) {
    # Create a separate performance summary from individual sheets
    performance_summary <- data.frame()
    
    # Extract performance metrics from individual result sheets
    for (result_name in names(all_results)) {
      if (is.data.frame(all_results[[result_name]]) && nrow(all_results[[result_name]]) > 0) {
        df <- all_results[[result_name]]
        
        # Check if performance columns exist
        if (all(c("Model", "AIC", "BIC", "LogLikelihood", "MSE", "MAE") %in% names(df))) {
          summary_row <- df %>%
            summarise(
              Model = first(Model),
              Source = result_name,
              Avg_AIC = mean(as.numeric(AIC), na.rm = TRUE),
              Avg_BIC = mean(as.numeric(BIC), na.rm = TRUE),
              Avg_LogLik = mean(as.numeric(LogLikelihood), na.rm = TRUE),
              Avg_MSE = mean(as.numeric(MSE), na.rm = TRUE),
              Avg_MAE = mean(as.numeric(MAE), na.rm = TRUE)
            )
          performance_summary <- bind_rows(performance_summary, summary_row)
        }
      }
    }
    
    # Sort by MSE if available
    if (nrow(performance_summary) > 0 && "Avg_MSE" %in% names(performance_summary)) {
      performance_summary <- performance_summary %>% arrange(Avg_MSE)
    }
  } else {
    performance_summary <- data.frame()
  }
  
  # 13. Create VaR Performance Summary
  cat("Creating VaR performance summary...\n")
  var_summary <- data.frame()
  tryCatch({
    var_results <- all_results[grepl("var_", names(all_results))]
    for (result_name in names(var_results)) {
      df <- var_results[[result_name]]
      if (nrow(df) > 0 && any(grepl("VaR", names(df)))) {
        var_summary <- bind_rows(var_summary, df)
      }
    }
  }, error = function(e) {
    cat("⚠️ Could not create VaR summary:", e$message, "\n")
  })
  
  # 14. Create Stress Test Summary
  cat("Creating stress test summary...\n")
  stress_summary <- data.frame()
  tryCatch({
    stress_results <- all_results[grepl("stress_", names(all_results))]
    for (result_name in names(stress_results)) {
      df <- stress_results[[result_name]]
      if (nrow(df) > 0) {
        stress_summary <- bind_rows(stress_summary, df)
      }
    }
  }, error = function(e) {
    cat("⚠️ Could not create stress test summary:", e$message, "\n")
  })
  
  # 15. Create Stylized Facts Summary
  cat("Creating stylized facts summary...\n")
  stylized_summary <- data.frame()
  tryCatch({
    stylized_results <- all_results[grepl("stylized_", names(all_results))]
    for (result_name in names(stylized_results)) {
      df <- stylized_results[[result_name]]
      if (nrow(df) > 0) {
        stylized_summary <- bind_rows(stylized_summary, df)
      }
    }
  }, error = function(e) {
    cat("⚠️ Could not create stylized facts summary:", e$message, "\n")
  })
  
  # 16. Add all sheets to workbook
  cat("Adding sheets to workbook...\n")
  
  # Add individual result sheets
  used_sheet_names <- c()
  for (result_name in names(all_results)) {
    if (is.data.frame(all_results[[result_name]]) && nrow(all_results[[result_name]]) > 0) {
      # Create unique sheet name
      base_name <- substr(result_name, 1, 25)  # Shorter base name
      sheet_name <- base_name
      counter <- 1
      
      # Ensure unique sheet name
      while (sheet_name %in% used_sheet_names) {
        sheet_name <- paste0(base_name, "_", counter)
        counter <- counter + 1
      }
      
      used_sheet_names <- c(used_sheet_names, sheet_name)
      addWorksheet(wb, sheet_name)
      writeData(wb, sheet_name, all_results[[result_name]])
    }
  }
  
  # Add consolidated comparison
  if (nrow(consolidated_data) > 0) {
    addWorksheet(wb, "Consolidated_Comparison")
    writeData(wb, "Consolidated_Comparison", consolidated_data)
  }
  
  # Add performance summary
  if (nrow(performance_summary) > 0) {
    addWorksheet(wb, "Model_Performance_Summary")
    writeData(wb, "Model_Performance_Summary", performance_summary)
  }
  
  # Add VaR summary
  if (nrow(var_summary) > 0) {
    addWorksheet(wb, "VaR_Performance_Summary")
    writeData(wb, "VaR_Performance_Summary", var_summary)
  }
  
  # Add stress test summary
  if (nrow(stress_summary) > 0) {
    addWorksheet(wb, "Stress_Test_Summary")
    writeData(wb, "Stress_Test_Summary", stress_summary)
  }
  
  # Add stylized facts summary
  if (nrow(stylized_summary) > 0) {
    addWorksheet(wb, "Stylized_Facts_Summary")
    writeData(wb, "Stylized_Facts_Summary", stylized_summary)
  }
  
  # Add pipeline summary
  addWorksheet(wb, "Pipeline_Summary")
  pipeline_summary <- data.frame(
    Metric = c(
      "Total Models Evaluated", 
      "Total Assets", 
      "GARCH Model Types", 
      "Engines Tested", 
      "Data Splits", 
      "Evaluation Metrics",
      "VaR Backtesting",
      "Stress Testing",
      "Stylized Facts",
      "Forecasting Analysis"
    ),
    Value = c(
      summary_stats$total_models,
      summary_stats$total_assets,
      summary_stats$total_garch_models,
      "Manual, rugarch",
      "Chrono Split (65/35), Time-Series CV",
      "AIC, BIC, LogLik, MSE, MAE",
      "Kupiec, Christoffersen, DQ Tests",
      "Extreme Scenarios, Robustness Analysis",
      "Volatility Clustering, Leverage Effects",
      "Multi-step Forecasting, Accuracy Metrics"
    )
  )
  writeData(wb, "Pipeline_Summary", pipeline_summary)
  
  # Add execution info
  addWorksheet(wb, "Execution_Info")
  exec_info <- data.frame(
    Field = c(
      "Execution Date", 
      "Execution Time", 
      "Total Results", 
      "Engines", 
      "Models", 
      "Assets",
      "VaR Tests",
      "Stress Scenarios",
      "Stylized Facts",
      "Forecast Horizons"
    ),
    Value = c(
      as.character(Sys.Date()),
      as.character(Sys.time()),
      length(all_results),
      "Manual, rugarch",
      "sGARCH_norm, sGARCH_sstd, gjrGARCH, eGARCH, TGARCH",
      "EURUSD, GBPUSD, GBPCNY, USDZAR, GBPZAR, EURZAR, NVDA, MSFT, PG, CAT, WMT, AMZN",
      "Kupiec, Christoffersen, Dynamic Quantile",
      "Market Crashes, Volatility Shocks, Correlation Breakdowns",
      "Volatility Clustering, Leverage Effects, Heavy Tails",
      "1-step, 5-step, 10-step, 20-step ahead"
    )
  )
  writeData(wb, "Execution_Info", exec_info)
  
  # Add results overview
  addWorksheet(wb, "Results_Overview")
  results_overview <- data.frame(
    Category = c(
      "GARCH Model Fitting",
      "NF-GARCH Simulation",
      "Forecasting Analysis",
      "VaR Backtesting",
      "Stress Testing",
      "Stylized Facts",
      "Model Evaluation",
      "Supplementary Analysis",
      "EDA Results"
    ),
    Description = c(
      "Standard GARCH models (sGARCH, eGARCH, GJR-GARCH, TGARCH) with Normal and Student-t distributions",
      "NF-GARCH models using both manual and rugarch engines with Normalizing Flow innovations",
      "Multi-step forecasting with accuracy metrics and comparison analysis",
      "Value-at-Risk validation using Kupiec, Christoffersen, and Dynamic Quantile tests",
      "Model robustness under extreme market scenarios and stress conditions",
      "Stylized facts validation including volatility clustering and leverage effects",
      "Comprehensive model comparison and ranking across multiple metrics",
      "Additional per-asset metrics and detailed performance analysis",
      "Exploratory data analysis results and summary statistics"
    ),
    Files = c(
      "Initial_GARCH_Model_Fitting.xlsx",
      "NF_GARCH_Results_manual.xlsx, NF_GARCH_Results_rugarch.xlsx",
      "forecast_accuracy_summary.csv",
      "var_backtest_summary.csv, model_performance_summary.csv",
      "stress_test_summary.csv, model_robustness_scores.csv",
      "stylized_facts_summary.csv",
      "model_ranking.csv, best_models_per_asset.csv",
      "all_per_asset_metrics.xlsx",
      "Various EDA tables and figures"
    )
  )
  writeData(wb, "Results_Overview", results_overview)
  
  # 17. Save the consolidated workbook
  output_file <- "Consolidated_NF_GARCH_Results.xlsx"
  saveWorkbook(wb, output_file, overwrite = TRUE)
  
  cat("✓ Consolidated results saved to:", output_file, "\n")
  cat("Total sheets created:", length(names(wb)), "\n")
  cat("Total data records:", nrow(consolidated_data), "\n")
  cat("Categories included:\n")
  cat("  - GARCH Model Fitting\n")
  cat("  - NF-GARCH Simulation (Manual & rugarch engines)\n")
  cat("  - Forecasting Analysis\n")
  cat("  - VaR Backtesting\n")
  cat("  - Stress Testing\n")
  cat("  - Stylized Facts\n")
  cat("  - Model Evaluation\n")
  cat("  - Supplementary Analysis\n")
  cat("  - EDA Results\n")
  
  return(output_file)
}

# Run the consolidation
if (!interactive()) {
  consolidate_all_results()
}
