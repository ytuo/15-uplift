import requests
import time
import zipfile
import glob
import os
import pandas as pd
from parameters import *
from urllib.request import urlretrieve
from urllib.parse import urlparse
import geopandas as gpd
from pathlib import Path
import numpy as np
from functools import reduce
import matplotlib.pyplot as plt

def download_file_with_progress(url, local_filename=None, download_dir="data/coc-shapefiles"):
    """
    Download a file with progress tracking
    """
    # Create download directory
    os.makedirs(download_dir, exist_ok=True)
    
    # Extract filename from URL if not provided
    if local_filename is None:
        parsed_url = urlparse(url)
        local_filename = os.path.basename(parsed_url.path)
    
    # Full path for the file
    file_path = os.path.join(download_dir, local_filename)
    
    print(f"Downloading: {url}")
    print(f"Saving to: {file_path}")
    print("-" * 50)
    
    try:
        # Start the download
        response = requests.get(url, stream=True, timeout=30, verify=False)
        response.raise_for_status()  # Raise an exception for bad status codes
        
        # Get file size if available
        total_size = int(response.headers.get('content-length', 0))
        
        # Download the file
        downloaded_size = 0
        start_time = time.time()
        
        with open(file_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    downloaded_size += len(chunk)
                    
                    # Show progress
                    if total_size > 0:
                        percent = (downloaded_size / total_size) * 100
                        speed = downloaded_size / (time.time() - start_time) / 1024 / 1024  # MB/s
                        print(f"\rProgress: {percent:.1f}% ({downloaded_size/(1024*1024):.1f}/{total_size/(1024*1024):.1f} MB) - Speed: {speed:.1f} MB/s", end='')
                    else:
                        print(f"\rDownloaded: {downloaded_size/(1024*1024):.1f} MB", end='')
        
        # Final stats
        total_time = time.time() - start_time
        final_size = downloaded_size / (1024 * 1024)  # Convert to MB
        avg_speed = final_size / total_time if total_time > 0 else 0
        
        print(f"\n✅ Download complete!")
        print(f"File size: {final_size:.1f} MB")
        print(f"Time taken: {total_time:.1f} seconds")
        print(f"Average speed: {avg_speed:.1f} MB/s")
        print(f"Saved to: {os.path.abspath(file_path)}")
        
        return file_path
        
    except requests.exceptions.RequestException as e:
        print(f"\n❌ Download failed: {str(e)}")
        return None
    except Exception as e:
        print(f"\n❌ Error: {str(e)}")
        return None

def download_coc_state_file(state_code, year, download_dir="data/coc-shapefiles"):
    """
    Download CoC state shapefile using the pattern from URL
    """
    url = f"https://files.hudexchange.info/reports/published/CoC_GIS_State_Shapefile_{state_code}_{year}.zip"
    filename = f"CoC_GIS_State_Shapefile_{state_code}.zip"
    
    return download_file_with_progress(url, filename, download_dir + "/" + str(year))

def download_tract_file(state_code, year, download_dir="data/tract-shapefiles"):
    """
    Download census tract shapefile using the pattern from URL
    """
    state_fips_code = state_info[state_code]
    url = f"https://www2.census.gov/geo/tiger/TIGER{year}/TRACT/tl_{year}_{state_fips_code[1]}_tract.zip"
    # Handle different URL pattern exceptions:
    # Year = 2010:
    if year == 2010:
        url = f"https://www2.census.gov/geo/tiger/TIGER2010/TRACT/2010/tl_2010_{state_fips_code[1]}_tract10.zip"

    filename = f"Tract_GIS_ShapeFile_{state_code}.zip"

    return download_file_with_progress(url, filename, download_dir + "/" + str(year))

def unzip_all(folder_path):
    """
    Unzip all .zip files in a folder
    """
    zip_files = glob.glob(os.path.join(folder_path, "*.zip"))
    
    for zip_file in zip_files:
        # Create folder name without .zip extension
        extract_to = os.path.splitext(zip_file)[0]
        
        try:
            with zipfile.ZipFile(zip_file, 'r') as zip_ref:
                zip_ref.extractall(extract_to)
            print(f"✅ Extracted: {os.path.basename(zip_file)}")
        except Exception as e:
            print(f"❌ Failed: {os.path.basename(zip_file)} - {e}")

def get_tract_data(fips_code, api_key, year):
    """
    Get economic, housing, and demographic data for a census tract
    
    Args:
        fips_code: Full 11-digit FIPS code (e.g., '25025000100')
        api_key: Your Census API key
        year: Year of ACS data (default 2020)
    
    Returns:
        pandas DataFrame with tract data
    """

    # Parse FIPS code
    state_fips = fips_code[:2]
    county_fips = fips_code[2:5]
    tract_fips = fips_code[5:]

    # Build API request
    base_url = f"https://api.census.gov/data/{year}/acs/acs5"
    
    # Create variable list for API call
    query_string = ",".join(["NAME"] + list(census_features.keys()))

    query_params = {
        "get": query_string,
        "for": f"tract:{tract_fips}",
        "in": f"state:{state_fips} county:{county_fips}",
        "key": api_key
    }

    try:
        response = requests.get(base_url, params=query_params)
        response.raise_for_status()
        
        data = response.json()
        
        if len(data) < 2:
            print("❌ No data returned - check your FIPS code")
            return None
        
        # Parse response
        headers = data[0]
        values = data[1]
        
        # Create results dictionary
        results = {}
        location_name = values[0]  # NAME field
        
        # print(f"✅ Found: {location_name}")
        # print("-" * 40)
        
        # Extract variable values
        for i, feature in enumerate(["NAME"] + list(census_features.keys())):
            if feature == "NAME":
                continue
            
            value = values[i]
            var_name = census_features[feature]
            
            # Handle null values
            if value in [None, -666666666, -888888888, -999999999]:
                value = "N/A"
            else:
                try:
                    value = int(value)
                except:
                    value = "N/A"
            
            results[var_name] = value
        
        df = pd.DataFrame([
            {"Category": "Demographics", "Metric": "Location", "Value": location_name},
            {"Category": "Demographics", "Metric": "total_population", "Value": results["total_population"]},
            # {"Category": "Demographics", "Metric": "Bachelor's Degree Rate (%)", "Value": results.get("Bachelor's Degree Rate (%)", "N/A")},
            
            {"Category": "Economics", "Metric": "Median Household Income ($)", "Value": results["Median Household Income"]},
            {"Category": "Economics", "Metric": "Per Capita Income ($)", "Value": results["Per Capita Income"]},
            # {"Category": "Economics", "Metric": "Unemployment Rate (%)", "Value": results.get("Unemployment Rate (%)", "N/A")},
            
            {"Category": "Housing", "Metric": "Median Home Value ($)", "Value": results["Median Home Value"]},
            {"Category": "Housing", "Metric": "Median Gross Rent ($)", "Value": results["Median Gross Rent"]},
            {"Category": "Housing", "Metric": "Total Housing Units", "Value": results["Total Housing Units"]},
            # {"Category": "Housing", "Metric": "Homeownership Rate (%)", "Value": results.get("Homeownership Rate (%)", "N/A")},
            # {"Category": "Housing", "Metric": "Vacancy Rate (%)", "Value": results.get("Vacancy Rate (%)", "N/A")},
        ])

        df = pd.DataFrame(
            [
                {
                    "FIPS": fips_code,
                    "Location": location_name,
                    "Total_Population": results["total_population"],
                    "Total_Housing_Units": results["Total Housing Units"],
                    "Bachelor_Degree_Count": results["Bachelor's Degree"],
                    "Total_Education_Population": results["Total Education Population"],
                    # "Bachelor_Degree_Rate_Pct": results.get("Bachelor's Degree Rate (%)", None),
                    "Median_Household_Income": results["Median Household Income"],
                    "Per_Capita_Income": results["Per Capita Income"],
                    "Total_Workers": results["Total Workers"],
                    "Unemployed": results["Unemployed"],
                    "Labor_Force": results["Labor Force"],
                    # "Unemployment_Rate_Pct": results.get("Unemployment Rate (%)", None),
                    "Median_Home_Value": results["Median Home Value"],
                    "Median_Gross_Rent": results["Median Gross Rent"],
                    "Owner_Occupied": results["Owner Occupied"],
                    "Renter_Occupied": results["Renter Occupied"],
                    "Total_Occupied_Housing": results["Total Occupied Housing"],
                    "Vacant_Housing_Units": results["Vacant Housing Units"],
                    # "Homeownership_Rate_Pct": results.get("Homeownership Rate (%)", None),
                    # "Vacancy_Rate_Pct": results.get("Vacancy Rate (%)", None),
                    "Built_2000_2009": results["Built 2000-2009"],
                    "Total_Housing_Stock_by_Year": results["Total Housing Stock by Year"]
                }
            ]
        )
        
        return df

    except requests.exceptions.RequestException as e:
        print(f"❌ API Error: {e}")
        return None

    except Exception as e:
        print(f"❌ Error: {e}")
        return None

def get_multiple_tracts(fips_codes, api_key, year=2020):
    """
    Get data for multiple tracts and return combined DataFrame
    """
    all_data = []
    
    for fips in fips_codes:
        # print(f"\nProcessing {fips}...")
        df = get_tract_data(fips, api_key, year)
        if df is not None:
            all_data.append(df)
    
    if all_data:
        combined_df = pd.concat(all_data, ignore_index=True)
        return combined_df
    else:
        return None
    
def get_state_tracts(state, year, api_key):
    """
    Get data for all tracts in a given state for a given year
    """
    
    # Build API request
    # Access the American Community Survey
    base_url = f"https://api.census.gov/data"
    
    # Create variable list for API call
    # The Census API limits the number of variables per request (max ~50). So, split census_features into chunks of 50.
    def chunk_list(lst, n):
        for i in range(0, len(lst), n):
            yield lst[i:i + n]

    feature_keys = list(census_features.keys())
    feature_chunks = list(chunk_list(feature_keys, 40))
    # print(len(feature_chunks[0]))

    dfs = []
    for chunk in feature_chunks:
        query_string = ",".join(["NAME"] + [census_features[k] for k in chunk])
        # print(query_string)
        geography_string = f"for=tract:*&in=state:{state_info[state][1]}&in=county:*"
        query_url = f"{base_url}/{year}/acs/acs5?get={query_string}&{geography_string}&key={api_key}"
        resp = requests.get(url=query_url)
        resp.raise_for_status()
        df_chunk = pd.DataFrame(resp.json())
        reverse_census_features = {v: k for k, v in census_features.items()}
        df_chunk.columns = [reverse_census_features.get(col, col) for col in df_chunk.iloc[0]]
        df_chunk = df_chunk[1:]
        dfs.append(df_chunk)

    # Merge all chunks on common columns (NAME, state, county, tract)
    df = reduce(lambda left, right: pd.merge(left, right, on=['NAME', 'state', 'county', 'tract'], how='outer'), dfs)

    # query_string = ",".join(["NAME"] + list(census_features.values()))

    # # Get data for all tracts in the state
    # geography_string = f"for=tract:*&in=state:{state_info[state][1]}&in=county:*"

    # query_url = f"{base_url}/{year}/acs/acs5?get={query_string}&{geography_string}&key={api_key}"

    # # print(query_url)

    # resp = requests.get(url=query_url)
    # resp.raise_for_status()
    # df = pd.DataFrame(resp.json())
    # # Map columns: if column name is in census_features.values(), replace with its key; else keep as is
    # reverse_census_features = {v: k for k, v in census_features.items()}
    # df.columns = [reverse_census_features.get(col, col) for col in df.iloc[0]]
    # df = df[1:]
    df['GEOID'] = df['state'].astype(str) + df['county'].astype(str) + df['tract'].astype(str)
    # print(df.head())
    return df

def create_cocs_graphs(year, states = states):
    directory = Path.cwd()
    coc_gpd = []
    for state in states:
        if state in ["AK", "HI"]:
            continue
        # print(state)
        coc_path = directory / 'data' / 'coc-shapefiles' / str(year) / f'CoC_GIS_State_Shapefile_{state}' / str.replace(state_info[state][0], " ", "_")
        cocs = [coc for coc in os.listdir(coc_path) if coc.startswith(state + '_')]
        for coc in cocs:
            coc_file = coc_path / coc / str(coc + '.shp')
            if coc_file.is_file():
                coc_gpd.append(gpd.read_file(coc_file))
    
    return gpd.GeoDataFrame(pd.concat(coc_gpd))


def create_cocs_tract_crosswalk(state = 'MA', year = 2024):
    
    directory = Path.cwd()
    coc_path = directory / 'data' / 'coc-shapefiles' / str(year) / f'CoC_GIS_State_Shapefile_{state}' / str.replace(state_info[state][0], " ", "_")
    if year == 2010:
        tract_file = f'tl_2010_{state_info[state][1]}_tract10.shp'
    else:
        tract_file = f'tl_{year}_{state_info[state][1]}_tract.shp'
    tracts_path = directory / 'data' / 'tract-shapefiles' / str(year) / f'Tract_GIS_ShapeFile_{state}' / tract_file
    cocs = [coc for coc in os.listdir(coc_path) if coc.startswith(state + '_')]

    # We must represent each CoC as a combination of Census tracts
    cocs_tract_crosswalk = {}
    tracts = gpd.read_file(tracts_path)

    for coc in cocs:
        # print(coc)
        coc_tract_crosswalk = {}
        coc_file = coc_path / coc / str(coc + '.shp')
        if coc_file.is_file():
            coc_gpd = gpd.read_file(coc_file)
            overlapping_tracts = gpd.sjoin(tracts.to_crs(coc_gpd.crs), coc_gpd, how="inner", predicate="intersects")
            # FOR DEBUGGING: Plot the overlapping tracts
            # fig, axes = plt.subplots(ncols = 2)
            # coc_gpd.plot(
            #     ax=axes[0]
            # )
            # overlapping_tracts.plot(
            #     ax=axes[1]
            # )
            
            # For those tracts that overlap, we estimate how much of each tract is contained in the CoC
            # First, project the CoC and tracts into an area-preserving coordinate system
            coc_projected = coc_gpd.to_crs(epsg=6933)
            tracts_projected = overlapping_tracts.to_crs(epsg=6933)
            for tract in tracts_projected.itertuples():
                intersection_area = tract.geometry.intersection(coc_projected.geometry).area
                tract_area = tract.geometry.area
                overlap = (intersection_area.iat[0]/tract_area)
            
                # Only keep tracts for which at least 1% of the tract is in CoC
                if overlap > 0.01: coc_tract_crosswalk[tract.GEOID] = round(overlap, 4)
        
        cocs_tract_crosswalk[coc] = coc_tract_crosswalk
    
    return cocs_tract_crosswalk

def create_coc_summary(year, api_key, states = states):
    """
    Summarize CoC data for the given year
    """
    print(f'Processing {year}')
    coc_data = pd.DataFrame()

    for state in states:
        # Get the data for the census tracts in this state for this year
        state_tracts = get_state_tracts(state, year, api_key)
        
        # Construct the mapping between CoCs and census tract in this state for this year
        state_coc_tract_crosswalk = create_cocs_tract_crosswalk(state, year)

        for coc in state_coc_tract_crosswalk:
            # print(coc)
            # Find the relevant tract in state_tracts and extract 
            subset_df = state_tracts[state_tracts['GEOID'].isin(state_coc_tract_crosswalk[coc].keys())]
            weights = [state_coc_tract_crosswalk[coc][geoid] for geoid in subset_df['GEOID']]
            # coc_population = subset_df['total_population']
            # total_population = np.dot(weights, subset_df['total_population'].astype(float))
            
            weighted_results = {}
            for feature, col in census_features.items():
                # Convert to float
                # # Ignore rows with negative values and re-compute weights
                # values = pd.to_numeric(subset_df[feature], errors='coerce')
                # valid_mask = values >= 0
                # if valid_mask.sum() == 0:
                #     weighted_results[feature] = np.nan
                #     continue
                # valid_values = values[valid_mask]
                # valid_weights = np.array(weights)[valid_mask]
                # valid_weights = valid_weights / valid_weights.sum()
                # weighted_results[feature] = np.dot(valid_weights, valid_values)

                values = pd.to_numeric(subset_df[feature], errors='coerce').fillna(0)
                weighted_results[feature] = np.dot(weights, values)
                
                # For median/mean/per capita features, use population-weighted average, omitting negatives/missing
                total_population = np.dot(weights, subset_df['total_population'].astype(float))
                # pop_weights = pd.to_numeric(subset_df['total_population'], errors='coerce').fillna(0) / total_population
                pop_weights = pd.to_numeric(subset_df['total_population'], errors='coerce').fillna(0)*weights / total_population
                if any(x in feature.lower() for x in ['median', 'mean', 'per capita']):
                    valid_mask = (values > 0) & values.notnull()
                    if valid_mask.sum() > 0:
                        valid_values = values[valid_mask]
                        valid_pop_weights = pop_weights[valid_mask]
                        valid_pop_weights = valid_pop_weights / valid_pop_weights.sum()
                        weighted_results[feature] = np.dot(valid_pop_weights, valid_values)
                    else:
                        weighted_results[feature] = np.nan

            weighted_df = pd.DataFrame([weighted_results], index = [coc])
            coc_data = pd.concat([coc_data, weighted_df], axis=0)
    
    return coc_data

def post_process_census_data(df):
    d = pd.DataFrame()
    d.index = df.index
    d['Total Population'] = df['total_population']
    d['Percent_Women'] = df['population_female']/df['total_population']
    d['Percent_Children'] = (df['age_0_5_female'] + df['age_5_9_female'] + df['age_10_14_female'] + df['age_15_17_female'] 
                             + df['age_0_5_male'] + df['age_5_9_male'] + df['age_10_14_male'] + df['age_15_17_male'])/df['total_population']
    d['median_household_income'] = df['median_household_income']
    d['Gross_Rent_Ratio'] = df['gross_rent_50_percent_or_more_income']/df['gross_rent_total']
    d['Poverty_Ratio'] = df['poverty_status_below_poverty']/(df['poverty_status_below_poverty'] + df['poverty_status_at_or_above_poverty'])
    d['Employment_Ratio'] = df['employment_in_civilian_labor_force_employed']/(df['employment_in_civilian_labor_force_employed'] + df['employment_in_civilian_labor_force_unemployed'])
    d['SNAP_Ratio'] = df['snap_received_in_past_12_months']/df['snap_total_households']
    d['Age_65_Plus_Ratio'] = (df['age_65_66_female'] + df['age_67_69_female'] + df['age_70_74_female'] + df['age_75_79_female'] + df['age_80_84_female'] + df['age_85_plus_female'] 
                             + df['age_65_66_male'] + df['age_67_69_male'] + df['age_70_74_male'] + df['age_75_79_male'] + df['age_80_84_male'] + df['age_85_plus_male'])/df['total_population']
    d['Education_Bachelors_Ratio'] = (df['education_male_bachelors'] + df['education_male_masters'] + df['education_male_professional_degree'] + df['education_male_doctorate']
                                      + df['education_female_bachelors'] + df['education_female_masters'] + df['education_female_professional_degree'] + df['education_female_doctorate']
                                      )/df['education_total']
    d['Mobility_Same_House_Ratio'] = df['geographic_mobility_same_house']/df['geographic_mobility_total']
    d['Mobility_Within_State_Ratio'] = df['geographic_mobility_moved_within_state']/df['geographic_mobility_total']
    d['Mobility_Different_State_Ratio'] = df['geographic_mobility_moved_different_state']/df['geographic_mobility_total']
    d['Veteran_Ratio'] = df['veteran_status_veteran']/(df['veteran_status_veteran'] + df['veteran_status_nonveteran'])
    d['Nativity_Naturalized_Ratio'] = df['nativity_foreign_born_naturalized']/df['nativity_total']
    d['Nativity_Not_Citizen_Ratio'] = df['nativity_foreign_born_not_citizen']/df['nativity_total']
    d['Social_Security_Ratio'] = df['social_security_income_households']/df['social_security_income_total_households']
    d['SSI_Ratio'] = df['ssi_income_households']/df['social_security_income_total_households']
    d['median_gross_rent'] = df['median_gross_rent']
    d['median_home_value'] = df['median_home_value']
    d['Vacant_Housing_Ratio'] = df['vacant_housing_units']/df['housing_units_total']
    d['median_age'] = df['median_age']
    d['Race_White_Ratio'] = df['race_white_alone']/df['race_total_population']
    d['Race_Black_Ratio'] = df['race_black_alone']/df['race_total_population']
    d['Race_Hispanic_Ratio'] = df['race_hispanic_latino']/df['race_total_population']

    return d