# Milestone 1: Set working directory and load required libraries
setwd("C:/Users/charl/Desktop/Uplift/2025-Modeling")
library(readxl)
library(dplyr)
library(tidyr)

# Milestone 2: Define file path and historical years
file_path <- "2007-2024-PIT-Counts-by-CoC.xlsx"
years <- 2007:2024
model_years <- c(2018, 2019, 2020, 2022, 2023, 2024)  # Years for modeling: 2018-2024 excluding 2021

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
national_obs <- all_data %>% group_by(Year) %>% summarise(Observed_Total = sum(Overall_Homeless, na.rm = TRUE),
                                                          Observed_Women = sum(Women, na.rm = TRUE),
                                                          Observed_Under18 = sum(Under18, na.rm = TRUE))
nat_pred_total <- all_preds_total %>% group_by(Year) %>% summarise(Predicted_Total = sum(Predicted_Total, na.rm = TRUE))
nat_pred_women <- all_preds_women %>% group_by(Year) %>% summarise(Predicted_Women = sum(Predicted_Women, na.rm = TRUE))
nat_pred_under18 <- all_preds_under18 %>% group_by(Year) %>% summarise(Predicted_Under18 = sum(Predicted_Under18, na.rm = TRUE))

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

# Milestone 11: Prepare full data for total counts, apply ceiling
df_full_total <- expand.grid(CoC_Number = unique_cocs, Year = 2007:2035) %>%
  left_join(all_data %>% select(CoC_Number, Year, Historical_Total = Overall_Homeless), by = c("CoC_Number", "Year")) %>%
  left_join(all_preds_total, by = c("CoC_Number", "Year")) %>%
  mutate(Homeless = if_else(Year <= 2024, Historical_Total, Predicted_Total),
         Homeless = ceiling(Homeless)) %>%
  select(CoC_Number, Year, Homeless)

# Milestone 12: Pivot to wide format for total
coc_wide_total <- df_full_total %>%
  pivot_wider(names_from = Year, values_from = Homeless) %>%
  arrange(CoC_Number)

nat_wide_total <- nat_df %>%
  select(Year, Total) %>%
  mutate(Total = ceiling(Total)) %>%
  pivot_wider(names_from = Year, values_from = Total) %>%
  mutate(CoC_Number = "COUNTRY") %>%
  select(CoC_Number, everything())

full_wide_total <- bind_rows(nat_wide_total, coc_wide_total)

write.csv(full_wide_total, "homeless_counts_2007_2035.csv", row.names = FALSE)

# Milestone 13: Prepare full data for women percents
df_full_women <- expand.grid(CoC_Number = unique_cocs, Year = 2007:2035) %>%
  left_join(all_data %>% select(CoC_Number, Year, Historical_Women = Women, Historical_Total = Overall_Homeless), by = c("CoC_Number", "Year")) %>%
  left_join(all_preds_women, by = c("CoC_Number", "Year")) %>%
  left_join(all_preds_total, by = c("CoC_Number", "Year")) %>%
  mutate(Women_Count = if_else(Year <= 2024, Historical_Women, Predicted_Women),
         Total_Count = if_else(Year <= 2024, Historical_Total, Predicted_Total),
         Women_Percent = round((Women_Count / Total_Count) * 100)) %>%
  select(CoC_Number, Year, Women_Percent)

# Milestone 14: Pivot to wide format for women percent
coc_wide_women <- df_full_women %>%
  pivot_wider(names_from = Year, values_from = Women_Percent) %>%
  arrange(CoC_Number)

nat_wide_women <- nat_df %>%
  select(Year, Women_Percent) %>%
  pivot_wider(names_from = Year, values_from = Women_Percent) %>%
  mutate(CoC_Number = "COUNTRY") %>%
  select(CoC_Number, everything())

full_wide_women <- bind_rows(nat_wide_women, coc_wide_women)

write.csv(full_wide_women, "women_percent_2007_2035.csv", row.names = FALSE)

# Milestone 15: Prepare full data for children percents
df_full_under18 <- expand.grid(CoC_Number = unique_cocs, Year = 2007:2035) %>%
  left_join(all_data %>% select(CoC_Number, Year, Historical_Under18 = Under18, Historical_Total = Overall_Homeless), by = c("CoC_Number", "Year")) %>%
  left_join(all_preds_under18, by = c("CoC_Number", "Year")) %>%
  left_join(all_preds_total, by = c("CoC_Number", "Year")) %>%
  mutate(Under18_Count = if_else(Year <= 2024, Historical_Under18, Predicted_Under18),
         Total_Count = if_else(Year <= 2024, Historical_Total, Predicted_Total),
         Under18_Percent = round((Under18_Count / Total_Count) * 100)) %>%
  select(CoC_Number, Year, Under18_Percent)

# Milestone 16: Pivot to wide format for under18 percent
coc_wide_under18 <- df_full_under18 %>%
  pivot_wider(names_from = Year, values_from = Under18_Percent) %>%
  arrange(CoC_Number)

nat_wide_under18 <- nat_df %>%
  select(Year, Under18_Percent) %>%
  pivot_wider(names_from = Year, values_from = Under18_Percent) %>%
  mutate(CoC_Number = "COUNTRY") %>%
  select(CoC_Number, everything())

full_wide_under18 <- bind_rows(nat_wide_under18, coc_wide_under18)

write.csv(full_wide_under18, "children_percent_2007_2035.csv", row.names = FALSE)

cat("\nCSV files have been saved in the working directory.\n")