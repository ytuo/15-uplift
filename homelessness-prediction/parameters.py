state_info = {
    "AL": ("Alabama", "01"),
    "AK": ("Alaska", "02"),
    "AZ": ("Arizona", "04"),
    "AR": ("Arkansas", "05"),
    "CA": ("California", "06"),
    "CO": ("Colorado", "08"),
    "CT": ("Connecticut", "09"),
    "DE": ("Delaware", "10"),
    "FL": ("Florida", "12"),
    "GA": ("Georgia", "13"),
    "HI": ("Hawaii", "15"),
    "ID": ("Idaho", "16"),
    "IL": ("Illinois", "17"),
    "IN": ("Indiana", "18"),
    "IA": ("Iowa", "19"),
    "KS": ("Kansas", "20"),
    "KY": ("Kentucky", "21"),
    "LA": ("Louisiana", "22"),
    "ME": ("Maine", "23"),
    "MD": ("Maryland", "24"),
    "MA": ("Massachusetts", "25"),
    "MI": ("Michigan", "26"),
    "MN": ("Minnesota", "27"),
    "MS": ("Mississippi", "28"),
    "MO": ("Missouri", "29"),
    "MT": ("Montana", "30"),
    "NE": ("Nebraska", "31"),
    "NV": ("Nevada", "32"),
    "NH": ("New Hampshire", "33"),
    "NJ": ("New Jersey", "34"),
    "NM": ("New Mexico", "35"),
    "NY": ("New York", "36"),
    "NC": ("North Carolina", "37"),
    "ND": ("North Dakota", "38"),
    "OH": ("Ohio", "39"),
    "OK": ("Oklahoma", "40"),
    "OR": ("Oregon", "41"),
    "PA": ("Pennsylvania", "42"),
    "RI": ("Rhode Island", "44"),
    "SC": ("South Carolina", "45"),
    "SD": ("South Dakota", "46"),
    "TN": ("Tennessee", "47"),
    "TX": ("Texas", "48"),
    "UT": ("Utah", "49"),
    "VT": ("Vermont", "50"),
    "VA": ("Virginia", "51"),
    "WA": ("Washington", "53"),
    "WV": ("West Virginia", "54"),
    "WI": ("Wisconsin", "55"),
    "WY": ("Wyoming", "56")
}

states = ["AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA", 
          "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", 
          "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", 
          "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", 
          "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"]

# census_features = {
#     "Total Population": "B01003_001E",
#     "Total Housing Units": "B25001_001E",
#     "Total Commuters": "B08303_001E",
#     "Bachelor's Degree": "B15003_022E",
#     "Total Education Population": "B15003_001E",
    
#     "Median Household Income": "B19013_001E",
#     "Per Capita Income": "B19301_001E",
#     "Median Gross Rent": "B25064_001E",
#     "Median Earnings": "B08121_001E",
#     "Unemployed": "B23025_005E",
#     "Labor Force": "B23025_002E",
    
#     "Median Home Value": "B25077_001E",
#     "Owner Occupied": "B25003_002E",
#     "Renter Occupied": "B25003_003E",
#     "Total Occupied Housing": "B25003_001E",
#     "Vacant Housing Units": "B25002_003E",
#     "Built 2000-2009": "B25034_010E",
#     "Total Housing Stock by Year": "B25034_001E"
# }

census_features = {
        "Total Population": "B01003_001E",
#     # TIER 1: CRITICAL PREDICTORS (Highest Impact)
    
#     # Housing & Economic Stability
#     "housing_tenure_owner_occupied": "B25003_002E",
#     "housing_tenure_renter_occupied": "B25003_003E", 
#     "housing_tenure_total": "B25003_001E",
    
    "median_household_income": "B19013_001E",
    
    # "gross_rent_30_to_35_percent_income": "B25070_007E",
    # "gross_rent_35_percent_or_more_income": "B25070_008E",
    "gross_rent_50_percent_or_more_income": "B25070_010E",
#     "gross_rent_not_computed": "B25070_009E",
    "gross_rent_total": "B25070_001E",
    
    "poverty_status_below_poverty": "B17001_002E",
    "poverty_status_total": "B17001_001E",
    
#     "vacancy_for_rent": "B25004_002E",
#     "vacancy_rented_not_occupied": "B25004_003E",
#     "vacancy_for_sale": "B25004_004E",
#     "vacancy_other": "B25004_008E",
    # "vacancy_total": "B25004_001E",
    
#     # TIER 2: STRONG PREDICTORS
    
#     # Employment & Income
    "employment_in_labor_force": "B23025_002E",
    # "employment_civilian_labor_force": "B23025_003E",
    # "employment_employed": "B23025_004E",
    # "employment_unemployed": "B23025_005E",
    "employment_not_in_labor_force": "B23025_007E",
    # "employment_total": "B23025_001E",
    
#     "earnings_male_with_earnings": "B20001_002E",
#     "earnings_female_with_earnings": "B20001_003E",
#     "earnings_total_with_earnings": "B20001_001E",
    
    "snap_received_in_past_12_months": "B22001_002E",
#     "snap_not_received_in_past_12_months": "B22001_003E",
    "snap_total_households": "B22001_001E",
    
#     # Demographics & Household Structure
#     "household_type_family": "B11001_002E",
#     "household_type_nonfamily": "B11001_007E",
#     "household_type_living_alone": "B11001_008E",
#     "household_type_total": "B11001_001E",
    
#     "age_under_18": "B01001_003E",  # Male under 5 + 5-9 + 10-14 + 15-17
#     "age_18_to_24_male": "B01001_007E",
#     "age_18_to_24_female": "B01001_031E", 
#     "age_25_to_34_male": "B01001_008E",
#     "age_25_to_34_female": "B01001_032E",
#     "age_55_to_64_male": "B01001_017E",
#     "age_55_to_64_female": "B01001_041E",
    "age_65_plus_male": "B01001_020E",
    "age_65_plus_female": "B01001_044E",
    # "age_total_population": "B01001_001E",
    
#     "tenure_household_size_1_person": "B25009_003E",
#     "tenure_household_size_2_person": "B25009_004E",
#     "tenure_household_size_7_plus_person": "B25009_010E",
#     "tenure_household_size_total": "B25009_001E",
    
#     # TIER 3: IMPORTANT CONTRIBUTING FACTORS
    
#     # Health & Disability
#     "disability_with_disability": "B18101_004E",
#     "disability_no_disability": "B18101_007E", 
#     "disability_total": "B18101_001E",
    
#     "health_insurance_with_coverage": "B27001_004E",
#     "health_insurance_no_coverage": "B27001_007E",
#     "health_insurance_total": "B27001_001E",
    
#     # Education & Human Capital
#     "education_less_than_high_school": "B15002_003E",  # Male less than 9th grade + 9th-12th no diploma
#     "education_high_school_grad": "B15002_011E",  # Male HS grad
#     "education_some_college": "B15002_012E",  # Male some college
    "education_bachelors_or_higher": "B15002_015E",  # Male bachelor's + graduate
#     "education_total_25_plus": "B15002_001E",
    
#     "employment_status_male_in_labor_force": "C23002_008E",
#     "employment_status_female_in_labor_force": "C23002_021E",
#     "employment_status_total_16_plus": "C23002_001E",
    
#     # Geographic Mobility  
    "geographic_mobility_same_house": "B07001_017E",
    "geographic_mobility_moved_within_state": "B07001_065E",
    "geographic_mobility_moved_different_state": "B07001_081E",
    "geographic_mobility_total": "B07001_001E",
    
#     "year_moved_2018_or_later": "B25038_003E",
#     "year_moved_2015_to_2017": "B25038_004E", 
#     "year_moved_before_2015": "B25038_008E",
#     "year_moved_total": "B25038_001E",
    
#     # TIER 4: CONTEXTUAL & RISK FACTORS
    
#     # Family Structure & Support
#     "family_type_married_with_children": "B11003_003E",
#     "family_type_single_parent_male": "B11003_016E",
#     "family_type_single_parent_female": "B11003_010E",
#     "family_type_total_families": "B11003_001E",
    
#     "marital_status_never_married": "B12001_003E",
#     "marital_status_divorced": "B12001_010E",
#     "marital_status_separated": "B12001_009E",
#     "marital_status_widowed": "B12001_011E",
#     "marital_status_total": "B12001_001E",
    
#     # Specialized Populations
    "veteran_status_veteran": "B21001_002E",
    # "veteran_status_nonveteran": "B21001_003E",
    "veteran_status_total": "B21001_001E",
    
#     "nativity_native_born": "B05001_002E",
    "nativity_foreign_born_naturalized": "B05001_005E",
    "nativity_foreign_born_not_citizen": "B05001_006E",
    "nativity_total": "B05001_001E",
    
#     "group_quarters_population": "B26001_001E",
    
#     # Additional Economic Indicators
    "social_security_income_households": "B19055_002E",
    "social_security_income_total_households": "B19055_001E",
    
    "ssi_income_households": "B19056_002E", 
    # "ssi_income_total_households": "B19056_001E",

    # "public_assistance_income_households": "B19057_001E",    
    # "public_assistance_income_households": "B19057_002E",
    # "public_assistance_income_total_households": "B19057_001E",
    
#     # Additional useful housing variables
    "median_gross_rent": "B25064_001E",
    "median_home_value": "B25077_001E",
    "housing_units_total": "B25001_001E",
#     "occupied_housing_units": "B25002_002E",
    "vacant_housing_units": "B25002_003E",
    
#     # Additional demographic variables
#     "total_population": "B01003_001E",
    "median_age": "B01002_001E",
    
#     # Race/ethnicity (important for understanding disparities)
    "race_white_alone": "B02001_002E",
    "race_black_alone": "B02001_003E", 
    "race_hispanic_latino": "B03003_003E"
    # "race_total_population": "B02001_001E"
}

# # census_features = {
# #     # TIER 1: CRITICAL PREDICTORS (Highest Impact)
# #     "Total Population": "B01003_001E",
# #     "Total Housing Units": "B25001_001E",
    
# #     # Housing & Economic Stability
# #     "housing_tenure_owner_occupied": "B25003_002E",
# #     "housing_tenure_renter_occupied": "B25003_003E", 
# #     "housing_tenure_total": "B25003_001E",
    
# #     "median_household_income": "B19013_001E",
    
# #     "gross_rent_30_to_35_percent_income": "B25070_007E",
# #     "gross_rent_35_percent_or_more_income": "B25070_008E",
# #     "gross_rent_not_computed": "B25070_009E",
# #     "gross_rent_total": "B25070_001E",
    
# #     "poverty_status_below_poverty": "B17001_002E",
# #     "poverty_status_total": "B17001_001E",
    
# #     "vacancy_for_rent": "B25004_002E",
# #     "vacancy_rented_not_occupied": "B25004_003E",
# #     "vacancy_for_sale": "B25004_004E",
# #     "vacancy_other": "B25004_008E",
# #     "vacancy_total": "B25004_001E",
    
# #     # TIER 2: STRONG PREDICTORS
    
# #     # Employment & Income
# #     "employment_in_labor_force": "B23025_002E",
# #     "employment_civilian_labor_force": "B23025_003E",
# #     "employment_employed": "B23025_004E",
# #     "employment_unemployed": "B23025_005E",
# #     "employment_not_in_labor_force": "B23025_007E",
# #     "employment_total": "B23025_001E",
    
# #     "earnings_male_with_earnings": "B20001_002E",
# #     "earnings_female_with_earnings": "B20001_003E",
# #     "earnings_total_with_earnings": "B20001_001E",
    
# #     "snap_received_in_past_12_months": "B22001_002E",
# #     "snap_not_received_in_past_12_months": "B22001_003E",
# #     "snap_total_households": "B22001_001E"
# # }