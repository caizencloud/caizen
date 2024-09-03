from common.v1.schemas import CaizenAssetFormatAssetV1

from typing import Optional
from pydantic import BaseModel

class GCP_STORAGE_BUCKET_ASSET_ATTRS_V1(BaseModel):
    location: str
    replication: Optional[bool] = False

class GCP_STORAGE_BUCKET_ASSET_V1(CaizenAssetFormatAssetV1):
    attrs: GCP_STORAGE_BUCKET_ASSET_ATTRS_V1

    def upsert(self):
        print(f"BUCKET Upserting {self.name} of type {self.type} with {self.attrs}")

    def delete(self):
        print(f"BUCKET Deleting {self.name} of type {self.type}")