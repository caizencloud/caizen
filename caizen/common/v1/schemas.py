from typing import Optional, Any
from datetime import datetime
from pydantic import BaseModel, ValidationError, field_validator

class CaizenAssetFormatAssetV1(BaseModel):
    name: str
    type: str
    action: str
    created: datetime
    updated: datetime
    attrs: Optional[Any] = None

    def upsert(self):
        print(f"Upserting {self.name} of type {self.type} with {self.attrs}")

    def delete(self):
        print(f"Deleting {self.name} of type {self.type}")

class CaizenAssetFormatV1(BaseModel):
    version: int
    asset: CaizenAssetFormatAssetV1

    @field_validator('version')
    def ensure_version_is_1(cls, v):
        if v != 1:
            raise ValueError('version must be equal to 1')
        return v