#!/usr/bin/env Rscript
# Comprehensive Dissertation Results Consolidation
# Includes ALL results needed for the NF-GARCH dissertation

library(openxlsx)
library(dplyr)
library(tidyr)
library(stringr)
library(readxl)

consolidate_dissertation_results <- function() {
  cat("=== CONSOLIDATING ALL DISSERTATION RESULTS ===\n")
  
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
  
  # 2. Load NF-GARCH Results (both engines) - INCLUDING NFEGARCH
  cat("Loading NF-GARCH results (including NFEGARCH)...\n")
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
        
        # Extract NFEGARCH results specifically
        if (any(grepl("eGARCH", nf_data$Model, ignore.case = TRUE))) {
          nfegarch_data <- nf_data[grepl("eGARCH", nf_data$Model, ignore.case = TRUE), ]
          if (nrow(nfegarch_data) > 0) {
            all_results[[paste0("nfegarch_", engine_name, "_", sheet)]] <- nfegarch_data
          }
        }
        
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
  
  # 4. Load VaR Backtesting Results (INCLUDING NFGARCH)
  cat("Loading VaR backtesting results (including NFGARCH)...\n")
  tryCatch({
    var_files <- list.files("outputs/var_backtest/tables", pattern = ".*\\.csv", full.names = TRUE)
    for (file in var_files) {
      var_data <- read.csv(file)
      file_name <- basename(file)
      
      # Check if this contains NFGARCH results
      if (any(grepl("NF", var_data$Model, ignore.case = TRUE))) {
        nf_var_data <- var_data[grepl("NF", var_data$Model, ignore.case = TRUE), ]
        if (nrow(nf_var_data) > 0) {
          all_results[[paste0("nf_var_", file_name)]] <- nf_var_data
        }
      }
      
      # Specifically load NFGARCH VaR files
      if (grepl("nfgarch", file_name, ignore.case = TRUE)) {
        all_results[[paste0("nfgarch_var_", file_name)]] <- var_data
      }
      
      all_results[[paste0("var_", file_name)]] <- var_data
    }
    cat("✓ Loaded VaR backtesting results\n")
  }, error = function(e) {
    cat("⚠️ Could not load VaR backtesting results:", e$message, "\n")
  })
  
  # 5. Load Stress Testing Results (INCLUDING NFGARCH)
  cat("Loading stress testing results (including NFGARCH)...\n")
  tryCatch({
    stress_files <- list.files("outputs/stress_tests/tables", pattern = ".*\\.csv", full.names = TRUE)
    for (file in stress_files) {
      stress_data <- read.csv(file)
      file_name <- basename(file)
      
      # Check if this contains NFGARCH results
      if (any(grepl("NF", stress_data$Model, ignore.case = TRUE))) {
        nf_stress_data <- stress_data[grepl("NF", stress_data$Model, ignore.case = TRUE), ]
        if (nrow(nf_stress_data) > 0) {
          all_results[[paste0("nf_stress_", file_name)]] <- nf_stress_data
        }
      }
      
      # Specifically load NFGARCH stress files
      if (grepl("nfgarch", file_name, ignore.case = TRUE)) {
        all_results[[paste0("nfgarch_stress_", file_name)]] <- stress_data
      }
      
      all_results[[paste0("stress_", file_name)]] <- stress_data
    }
    cat("✓ Loaded stress testing results\n")
  }, error = function(e) {
    cat("⚠️ Could not load stress testing results:", e$message, "\n")
  })
  
  # 6. Load Stylized Facts Results (INCLUDING WASSERSTEIN METRICS)
  cat("Loading stylized facts results (including Wasserstein metrics)...\n")
  tryCatch({
    stylized_files <- list.files("outputs/model_eval/tables", pattern = ".*stylized.*\\.csv", full.names = TRUE)
    for (file in stylized_files) {
      stylized_data <- read.csv(file)
      file_name <- basename(file)
      
      # Check for Wasserstein metrics
      if (any(grepl("wasserstein|wasser|w1", names(stylized_data), ignore.case = TRUE))) {
        wasserstein_data <- stylized_data
        all_results[[paste0("wasserstein_", file_name)]] <- wasserstein_data
      }
      
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
      
      # Check for Wasserstein metrics in evaluation files
      if (any(grepl("wasserstein|wasser|w1", names(eval_data), ignore.case = TRUE))) {
        wasserstein_eval <- eval_data
        all_results[[paste0("wasserstein_eval_", file_name)]] <- wasserstein_eval
      }
      
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
        
        # Check for NFEGARCH results in supplementary data
        if (any(grepl("eGARCH", supp_data$Model, ignore.case = TRUE))) {
          nfegarch_supp <- supp_data[grepl("eGARCH", supp_data$Model, ignore.case = TRUE), ]
          if (nrow(nfegarch_supp) > 0) {
            all_results[[paste0("nfegarch_supplementary_", sheet)]] <- nfegarch_supp
          }
        }
        
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
  
  # 13. Create NFEGARCH Performance Summary
  cat("Creating NFEGARCH performance summary...\n")
  nfegarch_summary <- data.frame()
  tryCatch({
    nfegarch_results <- all_results[grepl("nfegarch", names(all_results))]
    for (result_name in names(nfegarch_results)) {
      df <- nfegarch_results[[result_name]]
      if (nrow(df) > 0) {
        nfegarch_summary <- bind_rows(nfegarch_summary, df)
      }
    }
  }, error = function(e) {
    cat("⚠️ Could not create NFEGARCH summary:", e$message, "\n")
  })
  
  # 14. Create VaR Performance Summary (INCLUDING NFGARCH)
  cat("Creating VaR performance summary (including NFGARCH)...\n")
  var_summary <- data.frame()
  nf_var_summary <- data.frame()
  tryCatch({
    var_results <- all_results[grepl("var_", names(all_results))]
    for (result_name in names(var_results)) {
      df <- var_results[[result_name]]
      if (nrow(df) > 0 && any(grepl("VaR", names(df)))) {
        var_summary <- bind_rows(var_summary, df)
      }
      
      # Separate NFGARCH VaR results
      if (grepl("nf_var", result_name) && nrow(df) > 0) {
        nf_var_summary <- bind_rows(nf_var_summary, df)
      }
    }
  }, error = function(e) {
    cat("⚠️ Could not create VaR summary:", e$message, "\n")
  })
  
  # 15. Create Stress Test Summary (INCLUDING NFGARCH)
  cat("Creating stress test summary (including NFGARCH)...\n")
  stress_summary <- data.frame()
  nf_stress_summary <- data.frame()
  tryCatch({
    stress_results <- all_results[grepl("stress_", names(all_results))]
    for (result_name in names(stress_results)) {
      df <- stress_results[[result_name]]
      if (nrow(df) > 0) {
        stress_summary <- bind_rows(stress_summary, df)
      }
      
      # Separate NFGARCH stress results
      if (grepl("nf_stress", result_name) && nrow(df) > 0) {
        nf_stress_summary <- bind_rows(nf_stress_summary, df)
      }
    }
  }, error = function(e) {
    cat("⚠️ Could not create stress test summary:", e$message, "\n")
  })
  
  # 16. Create Stylized Facts Summary (INCLUDING WASSERSTEIN)
  cat("Creating stylized facts summary (including Wasserstein metrics)...\n")
  stylized_summary <- data.frame()
  wasserstein_summary <- data.frame()
  tryCatch({
    stylized_results <- all_results[grepl("stylized_", names(all_results))]
    for (result_name in names(stylized_results)) {
      df <- stylized_results[[result_name]]
      if (nrow(df) > 0) {
        stylized_summary <- bind_rows(stylized_summary, df)
      }
    }
    
    # Extract Wasserstein metrics specifically
    wasserstein_results <- all_results[grepl("wasserstein", names(all_results))]
    for (result_name in names(wasserstein_results)) {
      df <- wasserstein_results[[result_name]]
      if (nrow(df) > 0) {
        wasserstein_summary <- bind_rows(wasserstein_summary, df)
      }
    }
  }, error = function(e) {
    cat("⚠️ Could not create stylized facts summary:", e$message, "\n")
  })
  
  # 17. Add all sheets to workbook
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
  
  # Add NFEGARCH summary
  if (nrow(nfegarch_summary) > 0) {
    addWorksheet(wb, "NFEGARCH_Performance_Summary")
    writeData(wb, "NFEGARCH_Performance_Summary", nfegarch_summary)
  }
  
  # Add VaR summary (including NFGARCH)
  if (nrow(var_summary) > 0) {
    addWorksheet(wb, "VaR_Performance_Summary")
    writeData(wb, "VaR_Performance_Summary", var_summary)
  }
  
  if (nrow(nf_var_summary) > 0) {
    addWorksheet(wb, "NFGARCH_VaR_Summary")
    writeData(wb, "NFGARCH_VaR_Summary", nf_var_summary)
  }
  
  # Add stress test summary (including NFGARCH)
  if (nrow(stress_summary) > 0) {
    addWorksheet(wb, "Stress_Test_Summary")
    writeData(wb, "Stress_Test_Summary", stress_summary)
  }
  
  if (nrow(nf_stress_summary) > 0) {
    addWorksheet(wb, "NFGARCH_Stress_Summary")
    writeData(wb, "NFGARCH_Stress_Summary", nf_stress_summary)
  }
  
  # Add stylized facts summary (including Wasserstein)
  if (nrow(stylized_summary) > 0) {
    addWorksheet(wb, "Stylized_Facts_Summary")
    writeData(wb, "Stylized_Facts_Summary", stylized_summary)
  }
  
  if (nrow(wasserstein_summary) > 0) {
    addWorksheet(wb, "Wasserstein_Metrics_Summary")
    writeData(wb, "Wasserstein_Metrics_Summary", wasserstein_summary)
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
      "Forecasting Analysis",
      "NFEGARCH Results",
      "Wasserstein Metrics",
      "NFGARCH VaR",
      "NFGARCH Stress Tests"
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
      "Multi-step Forecasting, Accuracy Metrics",
      "NF-EGARCH Performance Analysis",
      "Wasserstein Distance Metrics",
      "NF-GARCH VaR Validation",
      "NF-GARCH Stress Testing Results"
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
      "Forecast Horizons",
      "NFEGARCH Analysis",
      "Wasserstein Metrics",
      "NFGARCH VaR",
      "NFGARCH Stress"
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
      "1-step, 5-step, 10-step, 20-step ahead",
      "NF-EGARCH Performance and Analysis",
      "Wasserstein Distance Calculations",
      "NF-GARCH VaR Backtesting Results",
      "NF-GARCH Stress Testing Analysis"
    )
  )
  writeData(wb, "Execution_Info", exec_info)
  
  # Add results overview
  addWorksheet(wb, "Results_Overview")
  results_overview <- data.frame(
    Category = c(
      "GARCH Model Fitting",
      "NF-GARCH Simulation",
      "NFEGARCH Analysis",
      "Forecasting Analysis",
      "VaR Backtesting",
      "NFGARCH VaR Backtesting",
      "Stress Testing",
      "NFGARCH Stress Testing",
      "Stylized Facts",
      "Wasserstein Metrics",
      "Model Evaluation",
      "Supplementary Analysis",
      "EDA Results"
    ),
    Description = c(
      "Standard GARCH models (sGARCH, eGARCH, GJR-GARCH, TGARCH) with Normal and Student-t distributions",
      "NF-GARCH models using both manual and rugarch engines with Normalizing Flow innovations",
      "Specific analysis of NF-EGARCH performance and results",
      "Multi-step forecasting with accuracy metrics and comparison analysis",
      "Value-at-Risk validation using Kupiec, Christoffersen, and Dynamic Quantile tests",
      "NF-GARCH specific VaR backtesting and validation results",
      "Model robustness under extreme market scenarios and stress conditions",
      "NF-GARCH specific stress testing and robustness analysis",
      "Stylized facts validation including volatility clustering and leverage effects",
      "Wasserstein distance metrics for distributional comparison",
      "Comprehensive model comparison and ranking across multiple metrics",
      "Additional per-asset metrics and detailed performance analysis",
      "Exploratory data analysis results and summary statistics"
    ),
    Files = c(
      "Initial_GARCH_Model_Fitting.xlsx",
      "NF_GARCH_Results_manual.xlsx, NF_GARCH_Results_rugarch.xlsx",
      "NFEGARCH specific results from NF-GARCH files",
      "forecast_accuracy_summary.csv",
      "var_backtest_summary.csv, model_performance_summary.csv",
      "NF-GARCH VaR results from var_backtest_summary.csv",
      "stress_test_summary.csv, model_robustness_scores.csv",
      "NF-GARCH stress results from stress_test_summary.csv",
      "stylized_facts_summary.csv",
      "Wasserstein metrics from stylized_facts_summary.csv",
      "model_ranking.csv, best_models_per_asset.csv",
      "all_per_asset_metrics.xlsx",
      "Various EDA tables and figures"
    )
  )
  writeData(wb, "Results_Overview", results_overview)
  
  # 18. Save the consolidated workbook
  output_file <- "Dissertation_Consolidated_Results.xlsx"
  saveWorkbook(wb, output_file, overwrite = TRUE)
  
  cat("✓ Dissertation results saved to:", output_file, "\n")
  cat("Total sheets created:", length(names(wb)), "\n")
  cat("Total data records:", nrow(consolidated_data), "\n")
  cat("Categories included:\n")
  cat("  - GARCH Model Fitting\n")
  cat("  - NF-GARCH Simulation (Manual & rugarch engines)\n")
  cat("  - NFEGARCH Analysis\n")
  cat("  - Forecasting Analysis\n")
  cat("  - VaR Backtesting (including NFGARCH)\n")
  cat("  - Stress Testing (including NFGARCH)\n")
  cat("  - Stylized Facts\n")
  cat("  - Wasserstein Metrics\n")
  cat("  - Model Evaluation\n")
  cat("  - Supplementary Analysis\n")
  cat("  - EDA Results\n")
  
  return(output_file)
}

# Run the consolidation
if (!interactive()) {
  consolidate_dissertation_results()
}
