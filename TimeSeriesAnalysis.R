# Milestone 1: Set working directory and load required libraries
setwd("C:/Users/charl/Desktop/15-uplift")
library(readxl)
library(dplyr)
library(tidyr)
library(openxlsx)

# Milestone 2: Define file paths, historical years, and initialize Excel workbooks
file_path <- "2007-2024-PIT-Counts-by-CoC.xlsx"
coc_metrics_path <- "C:/Users/charl/Desktop/15-uplift/coc_summary_3.xlsx" # Path to CoC metrics Excel
years <- 2007:2024
model_years <- c(2018, 2019, 2020, 2022, 2023, 2024) # Years for modeling: 2018-2024 excluding 2021
wb <- createWorkbook() # Initialize workbook for homeless data by year
wb_ratios <- createWorkbook() # Initialize workbook for ratio calculations

# Milestone 3: Read and validate CoC metrics Excel file
cat("\nReading CoC metrics Excel file: ", coc_metrics_path, "\n")
coc_metrics_data <- NULL
if (!file.exists(coc_metrics_path)) {
  cat("Warning: CoC metrics Excel file not found at ", coc_metrics_path, ". Proceeding without metrics data.\n")
} else {
  metric_sheets <- excel_sheets(coc_metrics_path)
  cat("Available sheets in ", coc_metrics_path, ": ", paste(metric_sheets, collapse = ", "), "\n")
  expected_years <- as.character(2012:2023)
  missing_years <- setdiff(expected_years, metric_sheets)
  if (length(missing_years) > 0) {
    cat("Warning: Missing sheets for years ", paste(missing_years, collapse = ", "), "\n")
  }
  
  coc_metrics_list <- lapply(expected_years, function(year) {
    if (year %in% metric_sheets) {
      df <- tryCatch({
        read_excel(coc_metrics_path, sheet = year, col_types = "text", col_names = TRUE)
      }, error = function(e) {
        cat("Error reading sheet ", year, ": ", e$message, "\n")
        return(NULL)
      })
      if (!is.null(df)) {
        cat("Columns in sheet ", year, ": ", paste(colnames(df), collapse = ", "), "\n")
        # Handle unnamed first column
        if (colnames(df)[1] == "" || is.na(colnames(df)[1]) || grepl("^\\.\\.\\.", colnames(df)[1])) {
          cat("Note: First column in sheet ", year, " has no header. Assuming it is CoC_Number.\n")
          colnames(df)[1] <- "CoC_Number"
        }
        # Rename Total Population if space is used
        if ("Total Population" %in% colnames(df)) {
          cat("Note: Renaming 'Total Population' to 'Total_Population' in sheet ", year, "\n")
          colnames(df)[colnames(df) == "Total Population"] <- "Total_Population"
        }
        if (!"CoC_Number" %in% colnames(df)) {
          cat("Warning: Sheet ", year, " missing CoC_Number column after checking first column\n")
          return(NULL)
        }
        # Standardize CoC_Number: remove spaces, standardize dashes, uppercase
        df <- df %>%
          mutate(CoC_Number = toupper(trimws(gsub("[ _]", "-", CoC_Number))))
        # Validate CoC_Number values
        valid_cocs <- df %>%
          filter(grepl("^[A-Z]{2}-\\d{3}$", CoC_Number)) %>%
          nrow()
        if (valid_cocs == 0) {
          cat("Warning: Sheet ", year, " has no valid CoC_Number values (format: XX-###)\n")
          return(NULL)
        }
        df <- df %>%
          mutate(Year = as.numeric(year)) %>%
          select(CoC_Number, Year, everything())
        cat("Successfully read sheet for year ", year, " with ", nrow(df), " rows\n")
        cat("Sample CoC_Number values: ", paste(head(df$CoC_Number, 5), collapse = ", "), "\n")
        return(df)
      } else {
        cat("Warning: Sheet ", year, " is empty or invalid\n")
        return(NULL)
      }
    } else {
      cat("Warning: No sheet for year ", year, "\n")
      return(NULL)
    }
  })
  coc_metrics_data <- bind_rows(coc_metrics_list[!sapply(coc_metrics_list, is.null)])
  if (nrow(coc_metrics_data) == 0) {
    cat("Warning: No valid data read from CoC metrics Excel file. Proceeding without metrics data.\n")
  } else {
    cat("Successfully combined ", nrow(coc_metrics_data), " rows of CoC metrics data\n")
    cat("Sample CoC_Number values: ", paste(head(unique(coc_metrics_data$CoC_Number), 5), collapse = ", "), "\n")
  }
}

# Milestone 4: Read and process PIT count data from each yearly sheet
cat("\nReading PIT count data from ", file_path, "\n")
data_list <- lapply(years, function(year) {
  df <- tryCatch({
    read_excel(file_path, sheet = as.character(year), col_types = "text")
  }, error = function(e) {
    cat("Error reading PIT sheet ", year, ": ", e$message, "\n")
    return(NULL)
  })
  if (is.null(df)) return(NULL)
  
  homeless_col <- grep("^Overall Homeless$", names(df))
  women_col <- grep("^Overall Homeless - Woman$", names(df))
  under18_col <- grep("^Overall Homeless - Under 18$", names(df))
  if (length(homeless_col) == 0) {
    cat("Error: No Overall Homeless column in sheet ", year, "\n")
    return(NULL)
  }
  
  df_total <- df %>%
    select(CoC_Number = `CoC Number`, Overall_Homeless = all_of(homeless_col[1])) %>%
    mutate(Overall_Homeless = as.numeric(gsub(",", "", Overall_Homeless))) %>%
    distinct(CoC_Number, .keep_all = TRUE)
  
  df_women <- if (length(women_col) > 0) {
    df %>%
      select(CoC_Number = `CoC Number`, Women = all_of(women_col[1])) %>%
      mutate(Women = as.numeric(gsub(",", "", Women))) %>%
      distinct(CoC_Number, .keep_all = TRUE)
  } else {
    df %>%
      select(CoC_Number = `CoC Number`) %>%
      distinct() %>%
      mutate(Women = NA)
  }
  
  df_under18 <- if (length(under18_col) > 0) {
    df %>%
      select(CoC_Number = `CoC Number`, Under18 = all_of(under18_col[1])) %>%
      mutate(Under18 = as.numeric(gsub(",", "", Under18))) %>%
      distinct(CoC_Number, .keep_all = TRUE)
  } else {
    df %>%
      select(CoC_Number = `CoC Number`) %>%
      distinct() %>%
      mutate(Under18 = NA)
  }
  
  df <- df_total %>%
    left_join(df_women, by = "CoC_Number") %>%
    left_join(df_under18, by = "CoC_Number") %>%
    mutate(Year = year,
           CoC_Number = toupper(trimws(gsub("[ _]", "-", CoC_Number)))) %>% # Standardize CoC_Number
    filter(grepl("^[A-Z]{2}-\\d{3}$", CoC_Number))
  cat("Processed PIT data for year ", year, " with ", nrow(df), " rows\n")
  df
})
all_data <- bind_rows(data_list[!sapply(data_list, is.null)])
if (nrow(all_data) == 0) {
  stop("Error: No valid PIT count data processed")
}

# Check CoC_Number mismatches
if (!is.null(coc_metrics_data)) {
  pit_cocs <- unique(all_data$CoC_Number)
  metrics_cocs <- unique(coc_metrics_data$CoC_Number)
  unmatched_pit <- setdiff(pit_cocs, metrics_cocs)
  unmatched_metrics <- setdiff(metrics_cocs, pit_cocs)
  if (length(unmatched_pit) > 0) {
    cat("Warning: ", length(unmatched_pit), " CoC_Numbers in PIT data not found in metrics data: ",
        paste(head(unmatched_pit, 5), collapse = ", "), "\n")
  }
  if (length(unmatched_metrics) > 0) {
    cat("Warning: ", length(unmatched_metrics), " CoC_Numbers in metrics data not found in PIT data: ",
        paste(head(unmatched_metrics, 5), collapse = ", "), "\n")
  }
}

# Milestone 5: Filter CoCs with complete data in model_years for total, women, under18
complete_cocs <- all_data %>%
  filter(Year %in% model_years) %>%
  group_by(CoC_Number) %>%
  summarise(has_complete_total = sum(!is.na(Overall_Homeless)) == length(model_years),
            has_complete_women = sum(!is.na(Women)) == length(model_years),
            has_complete_under18 = sum(!is.na(Under18)) == length(model_years),
            has_complete = has_complete_total & has_complete_women & has_complete_under18) %>%
  filter(has_complete) %>%
  pull(CoC_Number)
all_data <- all_data %>% filter(CoC_Number %in% complete_cocs)
unique_cocs <- unique(all_data$CoC_Number)
cat("Found ", length(unique_cocs), " CoCs with complete data for model years\n")

# Milestone 6: Prepare prediction years
future_years <- data.frame(Year = 2025:2035)

# Milestone 7: Perform linear predictions for total, women, under18 using model_years
pred_total_list <- list()
pred_women_list <- list()
pred_under18_list <- list()
for (coc in unique_cocs) {
  df_coc <- all_data %>% filter(CoC_Number == coc)
  valid <- df_coc %>% filter(Year %in% model_years)
  
  # For total
  model_total <- lm(Overall_Homeless ~ Year, data = valid)
  slope_total <- coef(model_total)["Year"]
  observed_2024_total <- valid %>% filter(Year == 2024) %>% pull(Overall_Homeless)
  pred_total <- observed_2024_total + slope_total * (future_years$Year - 2024)
  pred_total_list[[coc]] <- data.frame(Year = future_years$Year, Predicted_Total = pred_total, CoC_Number = coc)
  
  # For women
  model_women <- lm(Women ~ Year, data = valid)
  slope_women <- coef(model_women)["Year"]
  observed_2024_women <- valid %>% filter(Year == 2024) %>% pull(Women)
  pred_women <- observed_2024_women + slope_women * (future_years$Year - 2024)
  pred_women_list[[coc]] <- data.frame(Year = future_years$Year, Predicted_Women = pred_women, CoC_Number = coc)
  
  # For under18
  model_under18 <- lm(Under18 ~ Year, data = valid)
  slope_under18 <- coef(model_under18)["Year"]
  observed_2024_under18 <- valid %>% filter(Year == 2024) %>% pull(Under18)
  pred_under18 <- observed_2024_under18 + slope_under18 * (future_years$Year - 2024)
  pred_under18_list[[coc]] <- data.frame(Year = future_years$Year, Predicted_Under18 = pred_under18, CoC_Number = coc)
}
all_preds_total <- bind_rows(pred_total_list)
all_preds_women <- bind_rows(pred_women_list)
all_preds_under18 <- bind_rows(pred_under18_list)

# Milestone 8: Calculate national observed totals and predictions
national_obs <- all_data %>%
  group_by(Year) %>%
  summarise(Observed_Total = sum(Overall_Homeless, na.rm = TRUE),
            Observed_Women = sum(Women, na.rm = TRUE),
            Observed_Under18 = sum(Under18, na.rm = TRUE))
nat_pred_total <- all_preds_total %>%
  group_by(Year) %>%
  summarise(Predicted_Total = sum(Predicted_Total, na.rm = TRUE))
nat_pred_women <- all_preds_women %>%
  group_by(Year) %>%
  summarise(Predicted_Women = sum(Predicted_Women, na.rm = TRUE))
nat_pred_under18 <- all_preds_under18 %>%
  group_by(Year) %>%
  summarise(Predicted_Under18 = sum(Predicted_Under18, na.rm = TRUE))

# Milestone 9: Create national dataframe with observed and predicted values
nat_df <- data.frame(Year = 2007:2035) %>%
  left_join(national_obs, by = "Year") %>%
  left_join(nat_pred_total, by = "Year") %>%
  left_join(nat_pred_women, by = "Year") %>%
  left_join(nat_pred_under18, by = "Year") %>%
  mutate(Total = if_else(Year <= 2024, Observed_Total, Predicted_Total),
         Women_Count = if_else(Year <= 2024, Observed_Women, Predicted_Women),
         Under18_Count = if_else(Year <= 2024, Observed_Under18, Predicted_Under18),
         Women_Percent = round((Women_Count / Total) * 100),
         Under18_Percent = round((Under18_Count / Total) * 100))

# Milestone 10: Output simple table for historical and predicted homeless counts
cat("\nHistorical National Homeless Counts (2007-2024):\n")
print(nat_df %>% filter(Year <= 2024) %>% select(Year, Observed_Total) %>% rename(Homeless = Observed_Total))
cat("\nPredicted National Homeless Counts (2025-2035):\n")
print(nat_df %>% filter(Year >= 2025) %>% select(Year, Predicted_Total) %>% rename(Homeless = Predicted_Total))

# Milestone 11: Prepare combined data for all years
df_combined <- expand.grid(CoC_Number = unique_cocs, Year = 2007:2035) %>%
  left_join(all_data %>% select(CoC_Number, Year, Historical_Total = Overall_Homeless, Historical_Women = Women, Historical_Under18 = Under18), by = c("CoC_Number", "Year")) %>%
  left_join(all_preds_total, by = c("CoC_Number", "Year")) %>%
  left_join(all_preds_women, by = c("CoC_Number", "Year")) %>%
  left_join(all_preds_under18, by = c("CoC_Number", "Year")) %>%
  mutate(Total_Homeless = ceiling(if_else(Year <= 2024, Historical_Total, Predicted_Total)),
         Women_Count = if_else(Year <= 2024, Historical_Women, Predicted_Women),
         Under18_Count = if_else(Year <= 2024, Historical_Under18, Predicted_Under18),
         Percent_Women = round((Women_Count / Total_Homeless) * 100),
         Percent_Children = round((Under18_Count / Total_Homeless) * 100)) %>%
  select(CoC_Number, Year, Total_Homeless, Percent_Women, Percent_Children)

# Milestone 12: Add national data to combined dataframe
nat_combined <- nat_df %>%
  select(Year, Total_Homeless = Total, Percent_Women = Women_Percent, Percent_Children = Under18_Percent) %>%
  mutate(CoC_Number = "COUNTRY", Total_Homeless = ceiling(Total_Homeless)) %>%
  select(CoC_Number, Year, Total_Homeless, Percent_Women, Percent_Children)
df_combined <- bind_rows(nat_combined, df_combined)

# Milestone 13: Append CoC metrics to combined data for 2012-2023 if available
if (!is.null(coc_metrics_data)) {
  df_combined <- df_combined %>%
    left_join(coc_metrics_data, by = c("CoC_Number", "Year"))
  cat("\nMerged CoC metrics with PIT data. Rows with metrics: ", sum(!is.na(df_combined$Total_Population)), "\n")
  
  # Check for missing metrics only if Total_Population exists
  if ("Total_Population" %in% colnames(df_combined)) {
    missing_metrics <- df_combined %>%
      filter(Year %in% 2012:2023 & is.na(Total_Population)) %>%
      select(CoC_Number, Year)
    if (nrow(missing_metrics) > 0) {
      cat("Warning: Missing CoC metrics for ", nrow(missing_metrics), " CoC-year combinations\n")
      print(head(missing_metrics, 10))
    }
  } else {
    cat("Warning: Total_Population column not found in merged data. Check column names in coc_summary_3.xlsx.\n")
  }
}

# Milestone 14: Pivot to wide format for single CSV
df_wide <- df_combined %>%
  pivot_wider(names_from = Year, 
              values_from = c(Total_Homeless, Percent_Women, Percent_Children),
              names_glue = "{.value}_{Year}") %>%
  arrange(CoC_Number)
write.csv(df_wide, "homeless_data_2007_2035.csv", row.names = FALSE)
cat("\nWrote CSV file 'homeless_data_2007_2035.csv'\n")

# Milestone 15: Populate Excel file with yearly worksheets and CoC metrics, with rounding
for (year in 2007:2035) {
  sheet_data <- df_combined %>%
    filter(Year == year) %>%
    select(CoC_Number, Year, Total_Homeless, Percent_Women, Percent_Children,
           any_of(c("Total_Population", "median_household_income", "gross_rent_50_percent_or_more_income",
                    "gross_rent_total", "poverty_status_below_poverty", "poverty_status_total",
                    "employment_in_labor_force", "employment_not_in_labor_force",
                    "snap_received_in_past_12_months", "snap_total_households",
                    "age_65_plus_male", "age_65_plus_female", "education_bachelors_or_higher",
                    "geographic_mobility_same_house", "geographic_mobility_moved_within_state",
                    "geographic_mobility_moved_different_state", "geographic_mobility_total",
                    "veteran_status_veteran", "veteran_status_total", "nativity_foreign_born_naturalized",
                    "nativity_foreign_born_not_citizen", "nativity_total",
                    "social_security_income_households", "social_security_income_total_households",
                    "ssi_income_households", "median_gross_rent", "median_home_value",
                    "housing_units_total", "vacant_housing_units", "median_age",
                    "race_white_alone", "race_black_alone", "race_hispanic_latino")))
  if (nrow(sheet_data) == 0) {
    cat("Warning: No data for year ", year, ". Skipping worksheet creation.\n")
    next
  }
  sheet_data <- sheet_data %>%
    mutate(across(.cols = -c(CoC_Number, Year), # Exclude CoC_Number and Year from conversion and rounding
                  .fns = as.numeric)) %>%
    mutate(across(.cols = where(is.numeric), # Apply rounding to all numeric columns
                  .fns = ~if_else(. >= 1, round(., 0), signif(., 3))))
  addWorksheet(wb, sheetName = as.character(year))
  writeData(wb, sheet = as.character(year), x = sheet_data)
  cat("Wrote worksheet for year ", year, " with ", nrow(sheet_data), " rows\n")
}
saveWorkbook(wb, "homeless_data_by_year_2007_2035.xlsx", overwrite = TRUE)
cat("\nSaved Excel file 'homeless_data_by_year_2007_2035.xlsx'\n")

# Milestone 16: Calculate ratios and create new Excel with calculated columns
df_ratios <- df_combined %>%
  mutate(across(.cols = any_of(c("Total_Population", "median_household_income", "gross_rent_50_percent_or_more_income",
                                 "gross_rent_total", "poverty_status_below_poverty", "poverty_status_total",
                                 "employment_in_labor_force", "employment_not_in_labor_force",
                                 "snap_received_in_past_12_months", "snap_total_households",
                                 "age_65_plus_male", "age_65_plus_female", "education_bachelors_or_higher",
                                 "geographic_mobility_same_house", "geographic_mobility_moved_within_state",
                                 "geographic_mobility_moved_different_state", "geographic_mobility_total",
                                 "veteran_status_veteran", "veteran_status_total", "nativity_foreign_born_naturalized",
                                 "nativity_foreign_born_not_citizen", "nativity_total",
                                 "social_security_income_households", "social_security_income_total_households",
                                 "ssi_income_households", "median_gross_rent", "median_home_value",
                                 "housing_units_total", "vacant_housing_units", "median_age",
                                 "race_white_alone", "race_black_alone", "race_hispanic_latino")),
                .fns = as.numeric)) %>%
  mutate(
    Gross_Rent_50_Percent_Ratio = if_else(gross_rent_total > 0, gross_rent_50_percent_or_more_income / gross_rent_total, NA_real_),
    Poverty_Ratio = if_else(poverty_status_total > 0, poverty_status_below_poverty / poverty_status_total, NA_real_),
    Employment_Labor_Force_Ratio = if_else((employment_in_labor_force + employment_not_in_labor_force) > 0,
                                           employment_in_labor_force / (employment_in_labor_force + employment_not_in_labor_force), NA_real_),
    SNAP_Ratio = if_else(snap_total_households > 0, snap_received_in_past_12_months / snap_total_households, NA_real_),
    Age_65_Plus_Ratio = if_else(Total_Population > 0, (age_65_plus_male + age_65_plus_female) / Total_Population, NA_real_),
    Education_Bachelors_Ratio = if_else(Total_Population > 0, education_bachelors_or_higher / Total_Population, NA_real_),
    Geo_Mobility_Same_House_Ratio = if_else(geographic_mobility_total > 0, geographic_mobility_same_house / geographic_mobility_total, NA_real_),
    Geo_Mobility_Within_State_Ratio = if_else(geographic_mobility_total > 0, geographic_mobility_moved_within_state / geographic_mobility_total, NA_real_),
    Geo_Mobility_Different_State_Ratio = if_else(geographic_mobility_total > 0, geographic_mobility_moved_different_state / geographic_mobility_total, NA_real_),
    Veteran_Ratio = if_else(veteran_status_total > 0, veteran_status_veteran / veteran_status_total, NA_real_),
    Nativity_Naturalized_Ratio = if_else(nativity_total > 0, nativity_foreign_born_naturalized / nativity_total, NA_real_),
    Nativity_Not_Citizen_Ratio = if_else(nativity_total > 0, nativity_foreign_born_not_citizen / nativity_total, NA_real_),
    Social_Security_Ratio = if_else(social_security_income_total_households > 0, social_security_income_households / social_security_income_total_households, NA_real_),
    SSI_Ratio = if_else(social_security_income_total_households > 0, ssi_income_households / social_security_income_total_households, NA_real_),
    Vacant_Housing_Ratio = if_else(housing_units_total > 0, vacant_housing_units / housing_units_total, NA_real_),
    Race_White_Ratio = if_else(Total_Population > 0, race_white_alone / Total_Population, NA_real_),
    Race_Black_Ratio = if_else(Total_Population > 0, race_black_alone / Total_Population, NA_real_),
    Race_Hispanic_Ratio = if_else(Total_Population > 0, race_hispanic_latino / Total_Population, NA_real_)
  ) %>%
  select(CoC_Number, Year, Total_Homeless, Percent_Women, Percent_Children,
         median_household_income, Gross_Rent_50_Percent_Ratio, Poverty_Ratio,
         Employment_Labor_Force_Ratio, SNAP_Ratio, Age_65_Plus_Ratio,
         Education_Bachelors_Ratio, Geo_Mobility_Same_House_Ratio,
         Geo_Mobility_Within_State_Ratio, Geo_Mobility_Different_State_Ratio,
         Veteran_Ratio, Nativity_Naturalized_Ratio, Nativity_Not_Citizen_Ratio,
         Social_Security_Ratio, SSI_Ratio, median_gross_rent, median_home_value,
         Vacant_Housing_Ratio, median_age, Race_White_Ratio, Race_Black_Ratio,
         Race_Hispanic_Ratio)

# Milestone 17: Populate ratios Excel file with yearly worksheets, with rounding
for (year in 2007:2035) {
  sheet_data <- df_ratios %>%
    filter(Year == year) %>%
    select(CoC_Number, Year, Total_Homeless, Percent_Women, Percent_Children,
           median_household_income, Gross_Rent_50_Percent_Ratio, Poverty_Ratio,
           Employment_Labor_Force_Ratio, SNAP_Ratio, Age_65_Plus_Ratio,
           Education_Bachelors_Ratio, Geo_Mobility_Same_House_Ratio,
           Geo_Mobility_Within_State_Ratio, Geo_Mobility_Different_State_Ratio,
           Veteran_Ratio, Nativity_Naturalized_Ratio, Nativity_Not_Citizen_Ratio,
           Social_Security_Ratio, SSI_Ratio, median_gross_rent, median_home_value,
           Vacant_Housing_Ratio, median_age, Race_White_Ratio, Race_Black_Ratio,
           Race_Hispanic_Ratio)
  if (nrow(sheet_data) == 0) {
    cat("Warning: No data for year ", year, ". Skipping worksheet creation.\n")
    next
  }
  sheet_data <- sheet_data %>%
    mutate(across(.cols = -c(CoC_Number, Year), # Exclude CoC_Number and Year from rounding
                  .fns = ~if_else(. >= 1, round(., 0), signif(., 3))))
  addWorksheet(wb_ratios, sheetName = as.character(year))
  writeData(wb_ratios, sheet = as.character(year), x = sheet_data)
  cat("Wrote ratios worksheet for year ", year, " with ", nrow(sheet_data), " rows\n")
}
saveWorkbook(wb_ratios, "homeless_data_ratios_2007_2035.xlsx", overwrite = TRUE)
cat("\nSaved Excel file 'homeless_data_ratios_2007_2035.xlsx'\n")

cat("\nProcessing complete. Check output files and review warnings for potential issues.\n")