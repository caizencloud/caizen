import logging
from collections import defaultdict

from flask import Request, Response, abort
from pydantic import ValidationError
from src.schemas import NotificationResponse, PushNotification


def validate_request(request: Request):
    """
    Validates the request body using Pydantic.

    Args:
        request: The Flask request object.

    Returns:
        The validated request body.
    """
    # Validate the request body using Pydantic
    try:
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
        resp = NotificationResponse(**msg).model_dump_json(exclude_none=True)
        logging.error(resp)
        abort(Response(resp, status=422))

    # Validate the event type, size, and file content
    bucket_id, object_id = extract_bucket_and_object_id(body)
    full_object_name = f"gs://{bucket_id}/{object_id}"
    event_type = body.message.attributes.eventType
    if event_type != "OBJECT_FINALIZE":
        msg = {
            "detail": f"Invalid event type {event_type}. Skipping {full_object_name}"
        }
        resp = NotificationResponse(**msg).model_dump_json(exclude_none=True)
        logging.error(resp)
        abort(Response(resp, status=400))

    file_size = int(body.message.data.get("size")) or 0
    if file_size == 0:
        msg = {"detail": f"Empty file. Skipping {full_object_name}"}
        resp = NotificationResponse(**msg).model_dump_json(exclude_none=True)
        logging.info(resp)
        abort(Response(resp, status=200))

    content_type = body.message.data.get("contentType")
    if content_type != "application/x-ndjson":
        msg = {
            "detail": f"Non-ndjson file. Skipping {full_object_name} of type {content_type}"
        }
        resp = NotificationResponse(**msg).model_dump_json(exclude_none=True)
        logging.info(resp)
        abort(Response(resp, status=200))

    return body


def extract_bucket_and_object_id(body):
    """
    Extracts the bucket ID and object ID from the validated data.

    Args:
        body: The validated data containing the message attributes.

    Returns:
        A tuple containing the bucket ID and object ID.
    """
    bucket_id = body.message.attributes.bucketId
    object_id = body.message.attributes.objectId
    return bucket_id, object_id
