# Loading required libraries
library(readxl)
library(writexl)
library(dplyr)

# Setting working directory
setwd("C:/Users/charl/Desktop/15-uplift/v2")

# Reading all sheets from the combined Excel file
sheet_names <- excel_sheets("combined.xlsx")
all_data <- lapply(sheet_names, function(sheet) {
  data <- read_excel("combined.xlsx", sheet = sheet)
  
  # Ensuring CoC_Number and specified columns exist
  required_cols <- c("CoC_Number", "Overall_Homeless", "Overall_Homeless_Woman", "Overall_Homeless_Under_18")
  if (all(required_cols %in% colnames(data))) {
    # Reordering columns: CoC_Number, Overall_Homeless, Overall_Homeless_Woman, Overall_Homeless_Under_18, then others
    other_cols <- setdiff(colnames(data), required_cols)
    data <- data %>% select(CoC_Number, Overall_Homeless, Overall_Homeless_Woman, Overall_Homeless_Under_18, all_of(other_cols))
    
    # Removing rows with any missing data
    data <- data[complete.cases(data), ]
    
    # Rounding all numeric columns to the nearest integer
    numeric_cols <- sapply(data, is.numeric)
    data[numeric_cols] <- lapply(data[numeric_cols], round)
    
    # Creating a 'Country' row with summed values for numeric columns
    country_row <- data %>%
      summarise(across(where(is.numeric), sum, .names = "{.col}")) %>%
      mutate(CoC_Number = "Country")
    
    # Ensuring the country row has all columns in the correct order
    country_row <- country_row %>% select(CoC_Number, Overall_Homeless, Overall_Homeless_Woman, Overall_Homeless_Under_18, all_of(other_cols))
    
    # Combining the country row with the cleaned data
    final_data <- bind_rows(country_row, data)
    
    return(final_data)
  } else {
    warning(paste("Sheet", sheet, "is missing one or more required columns. Skipping."))
    return(NULL)
  }
})

# Filtering out any NULL results (sheets with missing required columns)
all_data <- all_data[!sapply(all_data, is.null)]

# Naming the sheets (using original sheet names)
names(all_data) <- sheet_names

# Writing the result to a new Excel file with separate sheets for each year
write_xlsx(all_data, "processed_combined.xlsx")

cat("Processing complete. Output saved to processed_combined.xlsx with separate sheets for each year.\n")