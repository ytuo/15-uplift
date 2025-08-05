# Loading required libraries
library(readxl)
library(dplyr)
library(tidyr)
library(openxlsx)

# Function to standardize CoC Number
standardize_coc_number <- function(coc) {
  coc <- trimws(toupper(as.character(coc)))  # Uppercase and trim
  coc <- gsub("_", "-", coc)  # Replace underscore with hyphen
  return(coc)
}

# Function to read and process CoC summary data for a given year
read_coc_summary <- function(file_path, sheet_name) {
  data <- read_excel(file_path, sheet = sheet_name)
  data <- data %>%
    select(CoC_Number = `CoC Number`, everything()) %>%  # Keep all columns
    mutate(CoC_Number = standardize_coc_number(CoC_Number)) %>%  # Standardize CoC Number
    filter(!is.na(CoC_Number), !grepl("MO-604 COVERS TERRITORY|FILE DOES NOT CONTAIN", CoC_Number, ignore.case = TRUE)) %>%  # Remove non-data rows
    distinct(CoC_Number, .keep_all = TRUE)  # Ensure unique CoC Numbers
  cat("Read", nrow(data), "rows from CoC summary, year", sheet_name, "with", length(unique(data$CoC_Number)), "unique CoC Numbers\n")
  return(data)
}

# Function to read and process PIT counts data for a given year
read_pit_counts <- function(file_path, sheet_name) {
  data <- read_excel(file_path, sheet = sheet_name)
  data <- data %>%
    select(CoC_Number = `CoC Number`, 
           Overall_Homeless = `Overall Homeless`,
           Overall_Homeless_Woman = `Overall Homeless - Woman`,
           Overall_Homeless_Under_18 = `Overall Homeless - Under 18`) %>%
    mutate(CoC_Number = standardize_coc_number(CoC_Number)) %>%  # Standardize CoC Number
    filter(!is.na(CoC_Number), !grepl("MO-604 COVERS TERRITORY|FILE DOES NOT CONTAIN", CoC_Number, ignore.case = TRUE)) %>%  # Remove non-data rows
    distinct(CoC_Number, .keep_all = TRUE)  # Ensure unique CoC Numbers
  cat("Read", nrow(data), "rows from PIT counts, year", sheet_name, "with", length(unique(data$CoC_Number)), "unique CoC Numbers\n")
  return(data)
}

# File paths (adjust if files are not in working directory)
coc_file <- "coc_summary_3.xlsx"
pit_file <- "2007-2024-PIT-Counts-by-CoC.xlsx"

# Years to process
years <- as.character(2014:2023)

# Create a workbook for output
wb <- createWorkbook()

# Process each year and create a separate sheet
for (year in years) {
  cat("Processing year", year, "\n")
  
  # Read CoC summary data
  coc_data <- tryCatch({
    read_coc_summary(coc_file, year)
  }, error = function(e) {
    cat("Error reading CoC summary sheet", year, ":", e$message, "\n")
    return(NULL)
  })
  
  # Read PIT counts data
  pit_data <- tryCatch({
    read_pit_counts(pit_file, year)
  }, error = function(e) {
    cat("Error reading PIT counts sheet", year, ":", e$message, "\n")
    return(NULL)
  })
  
  # Skip if both datasets are missing
  if (is.null(coc_data) && is.null(pit_data)) {
    cat("Skipping year", year, "due to missing data in both datasets\n")
    next
  }
  
  # If one dataset is missing, create an empty one with CoC_Number to allow merge
  if (is.null(coc_data)) {
    coc_data <- data.frame(CoC_Number = pit_data$CoC_Number)
  }
  if (is.null(pit_data)) {
    pit_data <- data.frame(CoC_Number = coc_data$CoC_Number, 
                           Overall_Homeless = NA_real_, 
                           Overall_Homeless_Woman = NA_real_, 
                           Overall_Homeless_Under_18 = NA_real_)
  }
  
  # Merge datasets by CoC Number, keeping all rows
  merged_data <- full_join(coc_data, pit_data, by = "CoC_Number") %>%
    # Convert relevant columns to numeric
    mutate(across(where(is.numeric), as.numeric)) %>%
    # Ensure unique CoC Numbers, keeping first non-NA values for overlapping columns
    group_by(CoC_Number) %>%
    summarise(across(everything(), ~first(na.omit(.))), .groups = "drop") %>%
    # Reorder columns: all coc_summary columns first, then PIT columns
    select(CoC_Number, 
           any_of(c("Total Population", "median_household_income", "gross_rent_50_percent_or_more_income",
                    "gross_rent_total", "poverty_status_below_poverty", "poverty_status_total",
                    "employment_in_labor_force", "employment_not_in_labor_force", "snap_received_in_past_12_months",
                    "snap_total_households", "age_65_plus_male", "age_65_plus_female", "education_bachelors_or_higher",
                    "geographic_mobility_same_house", "geographic_mobility_moved_within_state",
                    "geographic_mobility_moved_different_state", "geographic_mobility_total",
                    "veteran_status_veteran", "veteran_status_total", "nativity_foreign_born_naturalized",
                    "nativity_foreign_born_not_citizen", "nativity_total", "social_security_income_households",
                    "social_security_income_total_households", "ssi_income_households", "median_gross_rent",
                    "median_home_value", "housing_units_total", "vacant_housing_units", "median_age",
                    "race_white_alone", "race_black_alone", "race_hispanic_latino")),
           Overall_Homeless, Overall_Homeless_Woman, Overall_Homeless_Under_18) %>%
    # Sort by CoC Number
    arrange(CoC_Number)
  
  cat("Merged", nrow(merged_data), "rows for year", year, "with", length(unique(merged_data$CoC_Number)), "unique CoC Numbers\n")
  cat("PIT columns present:", sum(!is.na(merged_data$Overall_Homeless)), "rows with Overall_Homeless\n")
  
  # Add sheet to workbook
  addWorksheet(wb, sheetName = year)
  writeData(wb, sheet = year, x = merged_data)
}

# Save the workbook
saveWorkbook(wb, "combined.xlsx", overwrite = TRUE)

# Print confirmation
cat("Combined dataset has been saved as 'combined.xlsx' with separate sheets for each year.\n")
cat("Years processed:", paste(years, collapse = ", "), "\n")
cat("Sheets created:", paste(names(wb), collapse = ", "), "\n")