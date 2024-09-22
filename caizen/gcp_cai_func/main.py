import logging
import os

import functions_framework
import google.cloud.logging
from flask import Flask
from flask.wrappers import Request, Response
from src.message import extract_bucket_and_object_id, validate_request
from src.processing import process_gcs_file  # noqa
from src.schemas import NotificationResponse

app = Flask(__name__)

# If on GCP
if os.getenv("K_SERVICE"):
    client = google.cloud.logging.Client()
    client.setup_logging()

logger = logging.getLogger()
log_level = os.getenv("LOG_LEVEL", "INFO")
logger.setLevel(log_level)


# Function Entrypoint: main
@functions_framework.http
def main(request: Request) -> Response:
    body = validate_request(request)
    bucket_id, object_id = extract_bucket_and_object_id(body)

    try:
        process_gcs_file(bucket_id, object_id)
    except Exception as e:
        logging.error(f"Error processing GCS file: gs://{bucket_id}/{object_id}: {e}")
        resp = NotificationResponse(
            detail=f"Error processing GCS file: gs://{bucket_id}/{object_id}: {e}"
        ).model_dump_json(exclude_none=True)
        return Response(resp, status=500)

    # Log the file processed and respond 200 to the pubsub http trigger
    detail = f"gs://{bucket_id}/{object_id}"
    resp = NotificationResponse(detail=detail).model_dump_json(exclude_none=True)
    logging.info(resp)

    return Response(resp, status=200)
