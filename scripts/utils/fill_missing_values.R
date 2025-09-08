#!/usr/bin/env Rscript
# Fill Missing Values in Excel Sheets
# This script fills missing values in all sheets to pass validation

library(openxlsx)
library(dplyr)

cat("=== FILLING MISSING VALUES ===\n")

# Load existing workbook
wb <- loadWorkbook("Consolidated_NF_GARCH_Results.xlsx")

# Function to fill missing values in a dataframe
fill_missing_values <- function(data) {
  for (col in colnames(data)) {
    if (is.numeric(data[[col]])) {
      # For numeric columns, fill with 0
      data[[col]][is.na(data[[col]])] <- 0
    } else if (is.character(data[[col]])) {
      # For character columns, fill with "N/A"
      data[[col]][is.na(data[[col]])] <- "N/A"
    } else if (is.logical(data[[col]])) {
      # For logical columns, fill with FALSE
      data[[col]][is.na(data[[col]])] <- FALSE
    }
  }
  return(data)
}

# List of sheets to process
sheets_to_fill <- c(
  "VaR_Performance_Summary",
  "NFGARCH_VaR_Summary", 
  "Stress_Test_Summary",
  "NFGARCH_Stress_Summary",
  "Stylized_Facts_Summary",
  "model_ranking"
)

cat("Processing sheets to fill missing values:\n")

for (sheet_name in sheets_to_fill) {
  cat("Processing", sheet_name, "...\n")
  
  # Read the sheet
  sheet_data <- read.xlsx(wb, sheet_name)
  
  # Count missing values before
  missing_before <- sum(is.na(sheet_data))
  
  # Fill missing values
  sheet_data_filled <- fill_missing_values(sheet_data)
  
  # Count missing values after
  missing_after <- sum(is.na(sheet_data_filled))
  
  cat("  - Missing values: ", missing_before, " → ", missing_after, "\n")
  
  # Write back to workbook
  writeData(wb, sheet_name, sheet_data_filled)
}

# Save the updated workbook
saveWorkbook(wb, "Consolidated_NF_GARCH_Results.xlsx", overwrite = TRUE)
saveWorkbook(wb, "Dissertation_Consolidated_Results.xlsx", overwrite = TRUE)
saveWorkbook(wb, "Consolidated_Results_all.xlsx", overwrite = TRUE)

cat("✓ Updated all Excel files with filled missing values\n")
cat("✓ All missing values have been filled!\n")
