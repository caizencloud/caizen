import json
import logging
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Generator

import requests
from google.cloud import storage
from pydantic import ValidationError
from src.schemas import CaiRecord
from src.transform import GCP_ASSET


def stream_gcs_file(bucket_id: str, object_id: str) -> Generator[str, None, None]:
    """
    Stream the contents of a file from GCS line by line (asset by asset).

    Args:
        bucket_id: The GCS bucket ID.
        object_id: The GCS object ID.

    Yields:
        Each line of the file as a string.
    """
    client = storage.Client()
    bucket = client.bucket(bucket_id)
    blob = bucket.blob(object_id)
    try:
        with blob.open("r") as file:
            for line in file:
                yield line.strip()
    except Exception as e:
        logging.error(f"Error fetching GCS file: {e}")
        raise Exception(f"Error fetching GCS file: {e}")


def decode_json_line(line: str):
    try:
        return json.loads(line)
    except json.JSONDecodeError as e:
        logging.error(f"Error decoding JSON: {e}")
        raise Exception(f"Error decoding JSON: {e}")


def validate_cai_record(data: dict):
    try:
        return CaiRecord(**data)
    except ValidationError as e:
        logging.error(f"Error validating CAI record: {e}")
        raise Exception(f"Error validating CAI record: {e}")


def transform_cai_record(cai_record):
    try:
        asset = GCP_ASSET.transform(cai_record)
        return asset
    except ValueError as e:
        logging.error(f"Error transforming CAI record: {e}")
        raise Exception(f"Error transforming CAI record: {e}")


def send_to_caizen_api(api_url: str, headers: dict, caizen_asset_json: dict):
    try:
        # import random
        # import time

        # time.sleep(random.randint(1, 5))
        response = requests.post(api_url, headers=headers, json=caizen_asset_json)
        response.raise_for_status()
    except requests.RequestException as e:
        logging.error(
            f"Error sending request to CAIZEN API: {api_url} {caizen_asset_json} {e}"
        )
        raise Exception(
            f"Error sending request to CAIZEN API: {api_url} {caizen_asset_json} {e}"
        )


def process_asset_line(line: str, api_url: str, headers: dict) -> None:
    """
    Process a single line and send it to the CAIZEN API as an "upsert" request.

    Args:
        line: The line to process.
        api_url: The CAIZEN API URL.
        headers: The headers for the API request.

    Returns:
        None
    """
    try:
        data = decode_json_line(line)
        cai_record = validate_cai_record(data)
        caizen_asset = transform_cai_record(cai_record)
        caizen_asset_json = json.loads(caizen_asset.model_dump_json(exclude_none=True))
        send_to_caizen_api(api_url, headers, caizen_asset_json)
    except Exception as e:
        logging.error(f"Error processing asset line: {e}")
        raise Exception(f"Error processing asset line: {e}")


def process_gcs_file(bucket_id: str, object_id: str) -> None:
    """
    Stream the ndjson file from GCS and process chunks of each
    line at a time and send to the CAIZEN API as "upsert" requests.

    Args:
        bucket_id: The GCS bucket ID.
        object_id: The GCS object ID.

    Returns:
        None
    """
    api_url = "http://localhost:8000/v1/asset"
    headers = {"Content-Type": "application/json"}

    with ThreadPoolExecutor(max_workers=10) as executor:
        futures = []
        for line in stream_gcs_file(bucket_id, object_id):
            futures.append(executor.submit(process_asset_line, line, api_url, headers))

        for future in as_completed(futures):
            try:
                future.result()
            except Exception as e:
                logging.error(f"Error processing asset: {e}")
                raise Exception(f"Error processing asset: {e}")
