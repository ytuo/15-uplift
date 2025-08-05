# Loading required libraries
library(readxl)
library(dplyr)
library(writexl)

# Set working directory
setwd("C:/Users/charl/Desktop/15-uplift")

# Reading the Excel files
ratios_sheets <- excel_sheets("homeless_data_ratios_2007_2035.xlsx")
summary_sheets <- excel_sheets("coc_summary_3.xlsx")

# Load summary data and add Year column
summary_data <- lapply(summary_sheets, function(sheet) {
  data <- read_excel("coc_summary_3.xlsx", sheet = sheet)
  data$Year <- as.numeric(sheet)  # Add Year column from sheet name
  data
})
summary_combined <- bind_rows(summary_data)

# Standardize CoC_Number in summary data
summary_combined$CoC_Number <- trimws(gsub("_", "-", as.character(summary_combined$CoC_Number)))
summary_combined$Year <- as.numeric(summary_combined$Year)

# Process each year separately to maintain sheet structure
output_data <- lapply(ratios_sheets, function(sheet) {
  # Read the year's data
  data <- read_excel("homeless_data_ratios_2007_2035.xlsx", sheet = sheet)
  year <- as.numeric(sheet)
  
  # Standardize CoC_Number and Year
  data$CoC_Number <- trimws(gsub("_", "-", as.character(data$CoC_Number)))
  data$Year <- as.numeric(data$Year)
  
  # Merge with Total Population from summary data
  data <- data %>%
    left_join(select(summary_combined, CoC_Number, Year, `Total Population`),
              by = c("CoC_Number", "Year"))
  
  # Split COUNTRY row
  country_row <- data %>% filter(CoC_Number == "COUNTRY")
  coc_data <- data %>% filter(CoC_Number != "COUNTRY")
  
  # Remove rows with any NA values from CoC data
  coc_data_clean <- coc_data %>% na.omit()
  
  # Create COUNTRY row if missing
  if (nrow(country_row) == 0) {
    country_row <- data[1, ]  # Create a template row
    country_row$CoC_Number <- "COUNTRY"
    country_row$Year <- year
    country_row[ , !names(country_row) %in% c("CoC_Number", "Year")] <- NA_real_
  }
  
  # Calculate weighted averages for dependent variables and sum for Total Population
  if (nrow(coc_data_clean) > 0 && sum(coc_data_clean$`Total Population`, na.rm = TRUE) > 0) {
    weighted_avgs <- coc_data_clean %>%
      summarise(across(where(is.numeric) & !c(Year, `Total Population`),
                       ~sum(. * `Total Population`, na.rm = TRUE) / sum(coc_data_clean$`Total Population`, na.rm = TRUE),
                       .names = "{.col}"))
    total_population_sum <- sum(coc_data_clean$`Total Population`, na.rm = TRUE)
  } else {
    # If no valid data (e.g., 2007–2011, 2024–2035), set weighted averages to NA
    weighted_avgs <- coc_data_clean %>%
      summarise(across(where(is.numeric) & !c(Year, `Total Population`),
                       ~NA_real_,
                       .names = "{.col}"))
    total_population_sum <- NA_real_
  }
  
  # Update COUNTRY row with weighted averages and Total Population sum
  country_row <- country_row %>%
    mutate(
      across(where(is.numeric) & !c(Year, `Total Population`),
             ~weighted_avgs[[cur_column()]]),
      `Total Population` = total_population_sum,
      CoC_Number = "COUNTRY",
      Year = year
    )
  
  # Combine COUNTRY (top) and clean CoC data
  final_data <- bind_rows(country_row, coc_data_clean)
  
  # Debugging: Check COUNTRY values
  message("Year ", sheet, ": COUNTRY Total_Homeless = ", country_row$Total_Homeless,
          ", Total Population = ", country_row$`Total Population`)
  
  # Return data with sheet name for writing
  list(sheet_name = sheet, data = final_data)
})

# Prepare output for Excel (list of data frames with sheet names)
output_list <- setNames(lapply(output_data, `[[`, "data"), lapply(output_data, `[[`, "sheet_name"))

# Debugging: Print summary of results
message("Processing ", length(ratios_sheets), " years: ", paste(ratios_sheets, collapse = ", "))
message("Unique CoC_Number in summary_combined: ", paste(unique(summary_combined$CoC_Number), collapse = ", "))
message("Years in summary_combined: ", paste(unique(summary_combined$Year), collapse = ", "))
for (sheet in ratios_sheets) {
  year_data <- output_list[[sheet]]
  country_row <- year_data %>% filter(CoC_Number == "COUNTRY")
  message("Year ", sheet, ": ", nrow(year_data), " rows (including COUNTRY at top), ",
          sum(!is.na(year_data$`Total Population`)), " with non-NA Total Population")
}

# Write to Excel with one sheet per year
write_xlsx(output_list, "homeless_data_ratios_with_population.xlsx")