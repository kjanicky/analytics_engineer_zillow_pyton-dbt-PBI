import os
import logging
import requests
import pandas as pd
from dotenv import load_dotenv
import duckdb
import time
import json
import uuid

load_dotenv()
API_KEY = os.getenv("RAPIDAPI_KEY")
API_HOST = os.getenv("RAPIDAPI_HOST")
URL = os.getenv("RAPIDAPI_URL")
for var in ("RAPIDAPI_KEY", "RAPIDAPI_HOST", "RAPIDAPI_URL"):
    if not os.getenv(var):
        raise EnvironmentError(f"Missing env var: {var}")
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
        response = requests.get(URL, headers=HEADERS, params=query_parameters, timeout=30)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.HTTPError as err:
        logging.error(f"HTTP Error for coords ({lat}, {lon}): {err}")
    except Exception as e:
        logging.error(f"Unexpected error: {e}")
    return None

def transform_to_df(city_name: str, raw_data: dict, page: int, run_id: str, extraction_time=None):
    if not isinstance(raw_data, dict) or 'searchResults' not in raw_data:
        logging.warning(f"Downloaded data is not a valid dictionary for {city_name}")
        return None

    search_results = raw_data.get('searchResults')

    if not isinstance(search_results, list) or not search_results:
        logging.warning(f"No 'searchResults' list for {city_name} on page {page}.")
        return None
    extracted_at = extraction_time if extraction_time is not None else pd.Timestamp.now(tz='UTC')
    records = []
    for item in search_results:
        prop = item.get('property') if isinstance(item, dict) else None
        if not isinstance(prop, dict) or prop.get('zpid') is None:
            continue

        records.append({
            "zpid": int(prop["zpid"]),
            "extracted_at": extracted_at,
            "run_id": run_id,
            "searched_city": city_name,
            "page": page,
            "payload": json.dumps(prop)
        })

    if not records:
        return None

    return pd.DataFrame(records)
def run_pipeline(max_pages_per_city: int = 2):
    all_city_dfs = []
    pipeline_execution_time = pd.Timestamp.now(tz='UTC')
    run_id = str(uuid.uuid4())

    for city, coords in cities.items():
        logging.info(f"Fetching data for: {city}")
        for page in range(1, max_pages_per_city + 1):
            logging.info(f"Fetching data for page number: {page}")
            data = api_fetcher(coords['lat'],coords['lon'],page=page)
            if data is None:
                logging.warning(f"Skipping {city} and page{page} due to fetch error.")
                continue
            new_df = transform_to_df(city,data,page,run_id,pipeline_execution_time)
            if new_df is None or new_df.empty:
                logging.info(f"No results for {city} on page: {page}. Fetching new city...")
                break
            all_city_dfs.append(new_df)
            time.sleep(1)

    if not all_city_dfs:
        logging.error("No data fetched for any city.")
        return pd.DataFrame()

    return pd.concat(all_city_dfs, ignore_index=True)


def load_to_duckdb(df: pd.DataFrame,db_path: str = "zillow_dw.duckdb") -> None:
    if df is None or df.empty:
        logging.warning("No data to save (DataFrame is empty)")
        return
    try:
        with duckdb.connect(db_path) as con:
            con.execute("""
                            CREATE TABLE IF NOT EXISTS raw.zillow_listings (
                                zpid BIGINT NOT NULL,
                                extracted_at TIMESTAMPTZ NOT NULL,
                                run_id VARCHAR NOT NULL,
                                searched_city VARCHAR NOT NULL,
                                page INTEGER,
                                payload JSON NOT NULL,
                                PRIMARY KEY (zpid, extracted_at)
                            );
                        """)
            con.register("incoming_df", df)

            before_count = con.execute("SELECT COUNT(*) FROM raw.zillow_listings").fetchone()[0]
            con.execute("""
                            INSERT OR IGNORE INTO raw.zillow_listings (zpid, extracted_at, run_id, searched_city, page, payload)
                            SELECT zpid, extracted_at, run_id, searched_city, page, payload::JSON
                            FROM incoming_df
                        """)

            after_count = con.execute("SELECT COUNT(*) FROM raw.zillow_listings").fetchone()[0]
            inserted = after_count - before_count
            logging.info(
                f"Successfully loaded {inserted} new records into 'raw.zillow_listings' in '{db_path}'. Total records: {after_count}")



    except Exception as e:
        logging.error(f"Error while loading data to DuckDB: {e}")
        raise


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    df = run_pipeline()
    load_to_duckdb(df)