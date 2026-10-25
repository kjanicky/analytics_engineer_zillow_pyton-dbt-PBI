import os
import logging
import requests
import pandas as pd
from dotenv import load_dotenv
import duckdb
import time

load_dotenv()

API_KEY = os.getenv("RAPIDAPI_KEY")
API_HOST = os.getenv("RAPIDAPI_HOST")
URL = os.getenv("RAPIDAPI_URL")
HEADERS = {
    "X-RapidAPI-Key": API_KEY,
    "X-RapidAPI-Host": API_HOST
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

def transform_to_df(city_name,raw_data,extraction_time=None):
    if not isinstance(raw_data, dict):
        logging.warning(f"downloaded data is not a dictionary or is empty")
        return None
    if 'searchResults' not in raw_data or not raw_data['searchResults']:
        logging.warning(f"No 'searchResults' key in API response for {city_name}.")
        return None
    if not isinstance(raw_data['searchResults'], list):
        logging.warning(f" 'searchResults' key is not a list")
        return None
    data = raw_data['searchResults']
    properties_data = [
        item['property'] for item in data
        if isinstance(item, dict) and isinstance(item.get('property'), dict)]
    if len(properties_data) == 0:
        logging.warning(f"No properties found for {city_name}.")
        return None
    df = pd.json_normalize(properties_data)
    df['batch_row_id'] = range(len(df))
    df['searched_city'] = city_name
    df['extracted_at'] = extraction_time if extraction_time is not None else pd.Timestamp.now(tz='UTC')
    return df

def run_pipeline(max_pages_per_city: int = 2):
    all_city_dfs = []
    pipeline_execution_time = pd.Timestamp.now(tz='UTC')

    for city, coords in cities.items():
        logging.info(f"Fetching data for: {city}")
        for page in range(1, max_pages_per_city + 1):
            logging.info(f"Fetching data for page number: {page}")
            data = api_fetcher(coords['lat'],coords['lon'],page=page)
            if data is None:
                logging.warning(f"Skipping {city} and page{page} due to fetch error.")
                continue
            new_df = transform_to_df(city,data,pipeline_execution_time)
            if new_df is None or new_df.empty:
                logging.info(f"No results for {city} on page: {page}. Fetching new city...")
                break
            all_city_dfs.append(new_df)
            time.sleep(1)

    if not all_city_dfs:
        logging.error("No data fetched for any city.")
        return pd.DataFrame()

    final_df = pd.concat(all_city_dfs, ignore_index=True)

    return final_df

def load_to_duckdb(df: pd.DataFrame, db_path: str = "zillow_dw.duckdb", table_name: str = "raw_zillow_listings") -> None:
    if df is None or df.empty:
        logging.warning("No data to save (DataFrame is empty)")
        return
    try:
        with duckdb.connect(db_path) as con:
            table_check = con.execute(f"SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'main' AND table_name = '{table_name}')").fetchone()[0]
            if  table_check:
                con.execute(f"INSERT INTO {table_name} BY NAME SELECT * EXCLUDE (batch_row_id) FROM df "
                            f"WHERE NOT EXISTS(SELECT 1 FROM {table_name} t WHERE t.zpid = df.zpid AND t.extracted_at = df.extracted_at) "
                            f" QUALIFY ROW_NUMBER() OVER (PARTITION BY zpid, extracted_at ORDER BY batch_row_id DESC) = 1")
            else:
                con.execute(f"CREATE TABLE {table_name} AS SELECT * EXCLUDE (batch_row_id) FROM df "
                            f"QUALIFY ROW_NUMBER() OVER (PARTITION BY zpid, extracted_at ORDER BY batch_row_id DESC) = 1")

            logging.info(f"Rows loaded to the table: {len(df)}'{table_name}' to data warehouse: '{db_path}'.")
    except Exception as e:
        logging.error(f"Error while loading the data to DuckDB, error: {e}")
        raise

if __name__ == "__main__":
    df = run_pipeline()
    load_to_duckdb(df)