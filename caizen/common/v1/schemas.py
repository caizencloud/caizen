from datetime import datetime
from typing import Literal, Optional

from pydantic import BaseModel, field_validator


class CaizenAssetFormatV1(BaseModel):
    """Model for all v1 'asset' payloads."""

    name: str
    type: str
    action: Literal["upsert", "delete"]
    created: datetime
    updated: datetime
    attrs: Optional[dict] = None

    def upsert(self):
        raise NotImplementedError

    def delete(self):
        raise NotImplementedError


class CaizenAssetV1(BaseModel):
    """Outermost model of the versioned asset format."""

    version: int
    asset: CaizenAssetFormatV1

    @field_validator("version")
    def ensure_version_is_1(cls, v):
        if v != 1:
            raise ValueError("version must be equal to 1")
        return v


class ProcessedAsset(BaseModel):
    """Model for the response of the /v1/asset endpoint."""

    name: str
    action: Literal["upsert", "delete"]


class HealthStatus(BaseModel):
    """Model for the response of the /status endpoint."""

    status: str = "error"
    msg: Optional[str] = None
