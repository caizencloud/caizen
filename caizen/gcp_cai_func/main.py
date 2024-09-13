import base64
import json
import logging
import os
from collections import defaultdict
from datetime import datetime
from typing import Optional

import functions_framework
import google.cloud.logging
from flask import Flask, abort
from flask.wrappers import Request, Response
from pydantic import BaseModel, ValidationError, field_validator

# Initialize Flask app
app = Flask(__name__)

if os.getenv("K_SERVICE"):
    client = google.cloud.logging.Client()
    client.setup_logging()

logger = logging.getLogger()
log_level = os.getenv("LOG_LEVEL", "INFO")
logger.setLevel(log_level)


class StorageAttributes(BaseModel):
    bucketId: str
    eventTime: datetime
    eventType: str
    notificationConfig: str
    objectGeneration: str
    objectId: str
    overwroteGeneration: Optional[str] = None
    payloadFormat: str


class StorageNotification(BaseModel):
    attributes: StorageAttributes
    data: str
    decoded_data: dict = None  # Holds the parsed JSON from the base64 data
    messageId: str
    message_id: str
    publishTime: str
    publish_time: str

    @field_validator("data")
    def decode_base64_and_load_json(cls, v):
        try:
            # Decode the base64 string
            decoded_bytes = base64.b64decode(v)
            # Load the JSON content
            decoded_json = json.loads(decoded_bytes.decode("utf-8"))
        except (ValueError, json.JSONDecodeError):
            raise ValueError("Invalid base64-encoded JSON data")

        return decoded_json


class PushNotification(BaseModel):
    message: StorageNotification
    subscription: str


class NotificationResponse(BaseModel):
    detail: str


def validate_request(request: Request):
    try:
        # Parse and validate the request body using Pydantic
        data = request.get_json()
        body = PushNotification(**data)
    except ValidationError as e:
        reformatted_message = defaultdict(list)
        for pydantic_error in e.errors():
            loc, msg = pydantic_error["loc"], pydantic_error["msg"]
            filtered_loc = loc[1:] if loc[0] in ("body", "query", "path") else loc
            field_string = ".".join(filtered_loc)  # nested fields with dot-notation
            reformatted_message[field_string].append(msg)
        msg = {
            "detail": "Invalid request",
            "errors": reformatted_message,
        }
        # Return validation errors if the body is invalid
        logging.error(msg)
        abort(Response(json.dumps(msg), status=422))

    bucket_id = body.message.attributes.bucketId
    object_id = body.message.attributes.objectId
    full_object_name = f"gs://{bucket_id}/{object_id}"
    event_type = body.message.attributes.eventType
    if event_type != "OBJECT_FINALIZE":
        msg = {
            "detail": f"Invalid event type {event_type}. Skipping {full_object_name}"
        }
        logging.error(msg)
        abort(Response(json.dumps(msg), status=400))

    file_size = int(body.message.data.get("size")) or 0
    if file_size == 0:
        msg = {"detail": f"Empty file. Skipping {full_object_name}"}
        logging.info(msg)
        abort(Response(json.dumps(msg), status=200))

    content_type = body.message.data.get("contentType")
    if content_type != "application/x-ndjson":
        msg = {
            "detail": f"Non-ndjson file. Skipping {full_object_name} of type {content_type}"
        }
        logging.info(msg)
        abort(Response(json.dumps(msg), status=200))

    return body


# Flask route that accepts POST requests
@functions_framework.http
def main(request: Request) -> Response:
    body = validate_request(request)

    # Extract the bucket ID and object ID from the validated data
    bucket_id = body.message.attributes.bucketId
    object_id = body.message.attributes.objectId

    # Return a response with the validated data
    resp = NotificationResponse(detail=f"gs://{bucket_id}/{object_id}")
    logging.info(resp.model_dump_json())

    return Response(resp.model_dump_json(), status=200, mimetype="application/json")
