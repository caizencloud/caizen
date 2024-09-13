import base64
import json
from datetime import datetime
from typing import Optional

from pydantic import BaseModel, field_validator


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
    errors: Optional[dict] = None
