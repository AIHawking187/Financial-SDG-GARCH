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
      nf_data <- read_excel(file, sheet = "NF_GARCH_Eval")
      nf_data$Engine <- engine_name
      nf_data$Model_Type <- "NF-GARCH"
      
      all_results[[paste0("nf_garch_", engine_name)]] <- nf_data
      cat("✓ Loaded NF-GARCH results for", engine_name, "engine\n")
    }, error = function(e) {
      cat("⚠️ Could not load NF-GARCH results from", file, ":", e$message, "\n")
    })
  }
  
  # 3. Load Forecasting Results
  cat("Loading forecasting results...\n")
  tryCatch({
    forecast_files <- list.files("outputs/model_eval/tables", pattern = ".*forecast.*\\.xlsx", full.names = TRUE)
    for (file in forecast_files) {
      forecast_data <- read_excel(file)
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
    var_files <- list.files("outputs/var_backtest/tables", pattern = ".*\\.xlsx", full.names = TRUE)
    for (file in var_files) {
      var_data <- read_excel(file)
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
    stress_files <- list.files("outputs/stress_tests/tables", pattern = ".*\\.xlsx", full.names = TRUE)
    for (file in stress_files) {
      stress_data <- read_excel(file)
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
    stylized_files <- list.files("outputs/model_eval/tables", pattern = ".*stylized.*\\.xlsx", full.names = TRUE)
    for (file in stylized_files) {
      stylized_data <- read_excel(file)
      file_name <- basename(file)
      all_results[[paste0("stylized_", file_name)]] <- stylized_data
    }
    cat("✓ Loaded stylized facts results\n")
  }, error = function(e) {
    cat("⚠️ Could not load stylized facts results:", e$message, "\n")
  })
  
  # 7. Create Summary Statistics
  cat("Creating summary statistics...\n")
  summary_stats$total_models <- length(all_results)
  summary_stats$total_assets <- 12  # 6 FX + 6 Equity
  summary_stats$total_garch_models <- 5  # sGARCH_norm, sGARCH_sstd, gjrGARCH, eGARCH, TGARCH
  
  # 8. Create Consolidated Comparison Sheet
  cat("Creating consolidated comparison...\n")
  consolidated_data <- data.frame()
  
  # Combine all results for comparison
  for (result_name in names(all_results)) {
    if (is.data.frame(all_results[[result_name]]) && nrow(all_results[[result_name]]) > 0) {
      df <- all_results[[result_name]]
      df$Source <- result_name
      consolidated_data <- bind_rows(consolidated_data, df)
    }
  }
  
  # 9. Create Model Performance Summary
  cat("Creating model performance summary...\n")
  if (nrow(consolidated_data) > 0) {
    performance_summary <- consolidated_data %>%
      group_by(Model, Source) %>%
      summarise(
        Avg_AIC = mean(AIC, na.rm = TRUE),
        Avg_BIC = mean(BIC, na.rm = TRUE),
        Avg_LogLik = mean(LogLikelihood, na.rm = TRUE),
        Avg_MSE = mean(MSE, na.rm = TRUE),
        Avg_MAE = mean(MAE, na.rm = TRUE),
        .groups = 'drop'
      ) %>%
      arrange(Avg_MSE)
  } else {
    performance_summary <- data.frame()
  }
  
  # 10. Add all sheets to workbook
  cat("Adding sheets to workbook...\n")
  
  # Add individual result sheets
  for (result_name in names(all_results)) {
    if (is.data.frame(all_results[[result_name]]) && nrow(all_results[[result_name]]) > 0) {
      sheet_name <- substr(result_name, 1, 31)  # Excel sheet name limit
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
  
  # Add pipeline summary
  addWorksheet(wb, "Pipeline_Summary")
  pipeline_summary <- data.frame(
    Metric = c("Total Models Evaluated", "Total Assets", "GARCH Model Types", "Engines Tested", "Data Splits", "Evaluation Metrics"),
    Value = c(
      summary_stats$total_models,
      summary_stats$total_assets,
      summary_stats$total_garch_models,
      "Manual, rugarch",
      "Chrono Split (65/35), Time-Series CV",
      "AIC, BIC, LogLik, MSE, MAE, VaR, Stress Tests, Stylized Facts"
    )
  )
  writeData(wb, "Pipeline_Summary", pipeline_summary)
  
  # Add execution info
  addWorksheet(wb, "Execution_Info")
  exec_info <- data.frame(
    Field = c("Execution Date", "Execution Time", "Total Results", "Engines", "Models", "Assets"),
    Value = c(
      as.character(Sys.Date()),
      as.character(Sys.time()),
      length(all_results),
      "Manual, rugarch",
      "sGARCH_norm, sGARCH_sstd, gjrGARCH, eGARCH, TGARCH",
      "EURUSD, GBPUSD, GBPCNY, USDZAR, GBPZAR, EURZAR, NVDA, MSFT, PG, CAT, WMT, AMZN"
    )
  )
  writeData(wb, "Execution_Info", exec_info)
  
  # 11. Save the consolidated workbook
  output_file <- "Consolidated_NF_GARCH_Results.xlsx"
  saveWorkbook(wb, output_file, overwrite = TRUE)
  
  cat("✓ Consolidated results saved to:", output_file, "\n")
  cat("Total sheets created:", length(names(wb)), "\n")
  cat("Total data records:", nrow(consolidated_data), "\n")
  
  return(output_file)
}

# Run the consolidation
if (!interactive()) {
  consolidate_all_results()
}
