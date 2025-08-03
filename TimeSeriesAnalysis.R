# Milestone 1: Set working directory and load required libraries
setwd("C:/Users/charl/Desktop/Uplift/2025-Modeling")
install.packages("openxlsx")
library(readxl)
library(dplyr)
library(tidyr)
library(openxlsx) # For Excel output

# Milestone 2: Define file path, historical years, and initialize Excel workbook
file_path <- "2007-2024-PIT-Counts-by-CoC.xlsx"
years <- 2007:2024
model_years <- c(2018, 2019, 2020, 2022, 2023, 2024) # Years for modeling: 2018-2024 excluding 2021
wb <- createWorkbook() # Initialize Excel workbook at the top

# Milestone 3: Read and process data from each yearly sheet in the Excel file
data_list <- lapply(years, function(year) {
  df <- read_excel(file_path, sheet = as.character(year), col_types = "text")
  homeless_col <- grep("^Overall Homeless$", names(df))
  women_col <- grep("^Overall Homeless - Woman$", names(df))
  under18_col <- grep("^Overall Homeless - Under 18$", names(df))
  if (length(homeless_col) == 0) stop("No Overall Homeless column")
  
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
    mutate(Year = year) %>%
    filter(grepl("^[A-Z]{2}-\\d{3}$", CoC_Number))
  df
})
all_data <- bind_rows(data_list)

# Milestone 4: Filter CoCs with complete data in model_years for total, women, under18 (no NA)
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

# Milestone 5: Prepare prediction years (only future years)
future_years <- data.frame(Year = 2025:2035)

# Milestone 6: Perform linear predictions for total, women, under18 using model_years, with 2024 as baseline
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

# Milestone 7: Calculate national observed totals for all years and summed predictions
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

# Milestone 8: Create national dataframe with observed and predicted values
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

# Milestone 9: Output simple table for historical homeless counts (2007-2024)
cat("\nHistorical National Homeless Counts (2007-2024):\n")
print(nat_df %>% filter(Year <= 2024) %>% select(Year, Observed_Total) %>% rename(Homeless = Observed_Total))

# Milestone 10: Output dataframe table for predicted values (2025-2035)
cat("\nPredicted National Homeless Counts (2025-2035):\n")
print(nat_df %>% filter(Year >= 2025) %>% select(Year, Predicted_Total) %>% rename(Homeless = Predicted_Total))

# Milestone 11: Prepare combined data for all years (2007-2035)
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

# Milestone 13: Pivot to wide format for single CSV
df_wide <- df_combined %>%
  pivot_wider(names_from = Year, 
              values_from = c(Total_Homeless, Percent_Women, Percent_Children),
              names_glue = "{.value}_{Year}") %>%
  arrange(CoC_Number)

# Milestone 14: Write single CSV file
write.csv(df_wide, "homeless_data_2007_2035.csv", row.names = FALSE)

# Milestone 15: Populate Excel file with one worksheet per year
for (year in 2007:2035) {
  sheet_data <- df_combined %>%
    filter(Year == year) %>%
    select(CoC_Number, Total_Homeless, Percent_Women, Percent_Children)
  addWorksheet(wb, sheetName = as.character(year))
  writeData(wb, sheet = as.character(year), x = sheet_data)
}
saveWorkbook(wb, "homeless_data_by_year_2007_2035.xlsx", overwrite = TRUE)

cat("\nCSV file 'homeless_data_2007_2035.csv' and Excel file 'homeless_data_by_year_2007_2035.xlsx' have been saved in the working directory.\n")