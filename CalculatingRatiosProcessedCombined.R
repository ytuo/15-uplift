# Loading required libraries
library(readxl)
library(dplyr)
library(writexl)

# Setting working directory
setwd("C:/Users/charl/Desktop/15-uplift/v2")

# Reading all sheets from the Excel file
file_path <- "processed_combined.xlsx"
sheets <- excel_sheets(file_path)

# Function to process each sheet
process_sheet <- function(sheet_name, file_path) {
  # Reading the sheet
  data <- read_excel(file_path, sheet = sheet_name)
  
  # Calculating the specified columns
  processed_data <- data %>%
    mutate(
      Year = sheet_name,  # Adding year column from sheet name
      Overall_Homeless = round(Overall_Homeless),
      Percent_Women = signif(Overall_Homeless_Woman / Overall_Homeless * 100, 3),
      Percent_Children = signif(Overall_Homeless_Under_18 / Overall_Homeless * 100, 3),
      median_household_income = round(median_household_income),
      Gross_Rent_Ratio = signif(gross_rent_50_percent_or_more_income / gross_rent_total, 3),
      Poverty_Ratio = signif(poverty_status_below_poverty / poverty_status_total, 3),
      Employment_Ratio = signif(employment_in_labor_force / (employment_in_labor_force + employment_not_in_labor_force), 3),
      SNAP_Ratio = signif(snap_received_in_past_12_months / snap_total_households, 3),
      Age_65_Plus_Ratio = signif((age_65_plus_male + age_65_plus_female) / `Total Population`, 3),
      Education_Bachelors_Ratio = signif(education_bachelors_or_higher / `Total Population`, 3),
      Mobility_Same_House_Ratio = signif(geographic_mobility_same_house / geographic_mobility_total, 3),
      Mobility_Within_State_Ratio = signif(geographic_mobility_moved_within_state / geographic_mobility_total, 3),
      Mobility_Different_State_Ratio = signif(geographic_mobility_moved_different_state / geographic_mobility_total, 3),
      Veteran_Ratio = signif(veteran_status_veteran / veteran_status_total, 3),
      Nativity_Naturalized_Ratio = signif(nativity_foreign_born_naturalized / nativity_total, 3),
      Nativity_Not_Citizen_Ratio = signif(nativity_foreign_born_not_citizen / nativity_total, 3),
      Social_Security_Ratio = signif(social_security_income_households / social_security_income_total_households, 3),
      SSI_Ratio = signif(ssi_income_households / social_security_income_total_households, 3),
      median_gross_rent = round(median_gross_rent),
      median_home_value = round(median_home_value),
      Vacant_Housing_Ratio = signif(vacant_housing_units / housing_units_total, 3),
      median_age = round(median_age),
      Race_White_Ratio = signif(race_white_alone / `Total Population`, 3),
      Race_Black_Ratio = signif(race_black_alone / `Total Population`, 3),
      Race_Hispanic_Ratio = signif(race_hispanic_latino / `Total Population`, 3)
    ) %>%
    select(
      CoC_Number, Year, Overall_Homeless, Percent_Women, Percent_Children,
      median_household_income, Gross_Rent_Ratio, Poverty_Ratio, Employment_Ratio,
      SNAP_Ratio, Age_65_Plus_Ratio, Education_Bachelors_Ratio,
      Mobility_Same_House_Ratio, Mobility_Within_State_Ratio, Mobility_Different_State_Ratio,
      Veteran_Ratio, Nativity_Naturalized_Ratio, Nativity_Not_Citizen_Ratio,
      Social_Security_Ratio, SSI_Ratio, median_gross_rent, median_home_value,
      Vacant_Housing_Ratio, median_age, Race_White_Ratio, Race_Black_Ratio, Race_Hispanic_Ratio
    )
  
  return(processed_data)
}

# Processing all sheets
all_data <- lapply(sheets, function(sheet) process_sheet(sheet, file_path))

# Naming the list elements with sheet names for output
names(all_data) <- sheets

# Writing the output to a new Excel file with separate sheets for each year
write_xlsx(all_data, "processed_output.xlsx")

# Printing a message to confirm completion
cat("Processing complete. Output saved to processed_output.xlsx with separate sheets for each year\n")