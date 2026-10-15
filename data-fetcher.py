import os
import logging
import requests
import pandas as pd
from dotenv import load_dotenv
import duckdb
import time

load_dotenv()

API_KEY = os.getenv("RAPIDAPI_KEY")
URL = "https://private-zillow.p.rapidapi.com/search/bycoordinates"
HEADERS = {
    "X-RapidAPI-Key": API_KEY,
    "X-RapidAPI-Host": "private-zillow.p.rapidapi.com"
}
cities = {"New York": {"lat": "40.7128", "lon": "-74.0060"},
    "Los Angeles": {"lat": "34.0522", "lon": "-118.2437"},
    "Chicago": {"lat": "41.8781", "lon": "-87.6298"},
    "Houston": {"lat": "29.7604", "lon": "-95.3698"},
    "Phoenix": {"lat": "33.4484", "lon": "-112.0740"},
    "Philadelphia": {"lat": "39.9526", "lon": "-75.1652"},
    "San Antonio": {"lat": "29.4241", "lon": "-98.4936"},
    "San Diego": {"lat": "32.7157", "lon": "-117.1611"},
    "Dallas": {"lat": "32.7767", "lon": "-96.7970"},
    "San Jose": {"lat": "37.3382", "lon": "-121.8863"
    }}

def api_fetcher(lat: str, lon: str, page: int = 1, radius=50, status_type="ForSale", sort="DaysOnZillow"):
    query_parameters = {
        "latitude": lat,
        "longitude": lon,
        "page": str(page),
        "radius": radius,
        "status_type": status_type,
        "sort": sort

    }
    try:
        response = requests.get(URL, headers=HEADERS, params=query_parameters)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.HTTPError as err:
        logging.error(f"HTTP Error for coords ({lat}, {lon}): {err}")
    except Exception as e:
        logging.error(f"Unexpected error: {e}")
    return None

def transform_to_df(city_name,raw_data):
    if not raw_data or 'searchResults' not in raw_data:
        logging.warning(f"No 'searchResults' key in API response for {city_name}.")
        return None

    data = raw_data['searchResults']
    properties_data = [item['property'] for item in data if 'property' in item]
    if not properties_data:
        logging.warning(f"No properties found for {city_name}.")
        return None
    df = pd.json_normalize(properties_data)
    df['searched_city'] = city_name
    df['extracted_at'] = pd.Timestamp.now(tz='UTC')
    return df

def run_pipeline(max_pages_per_city: int = 2):
    all_city_dfs = []

    for city, coords in cities.items():
        logging.info(f"Fetching data for: {city}")
        for page in range(1, max_pages_per_city + 1):
            logging.info(f"Fetching data for page number: {page}")
            data = api_fetcher(coords['lat'],coords['lon'],page=page)
            if data is None:
                logging.warning(f"Skipping {city} and page{page} due to fetch error.")
                continue
            new_df = transform_to_df(city,data)
            if new_df is None or new_df.empty:
                logging.info(f"No results for {city} on page: {page}. Fetching new city...")
                break
            all_city_dfs.append(new_df)
            time.sleep(1)

    if not all_city_dfs:
        logging.error("No data fetched for any city.")
        return pd.DataFrame()

    final_df = pd.concat(all_city_dfs, ignore_index=True)
    logging.info(f"Successfully extracted {len(final_df)} rows for {len(all_city_dfs)} cities.")

    if 'zpid' in final_df.columns:
        initial_count = len(final_df)
        final_df = final_df.drop_duplicates(subset=['zpid'])
        logging.info(f"Deleted {initial_count - len(final_df)} duplicates based on column 'zpid'.")

    logging.info(f"Fetched {len(final_df)} unique records")
    return final_df

def load_to_duckdb(df: pd.DataFrame, db_path: str = "zillow_dw.duckdb", table_name: str = "raw_zillow_listings") -> None:
    if df is None or df.empty:
        logging.warning("No data to save (DataFrame is empty)")
        return

    try:
        with duckdb.connect(db_path) as con:
            con.execute(f"CREATE OR REPLACE TABLE {table_name} AS SELECT * FROM df")
            logging.info(f"Rows loaded to the table: {len(df)}'{table_name}' to databae: '{db_path}'.")
    except Exception as e:
        logging.error(f"Error why loading the data to DuckDB, error: {e}")
        raise

if __name__ == "__main__":
    df = run_pipeline()
    load_to_duckdb(df)