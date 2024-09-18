from typing import List, Optional

from common.v1.schemas import CaizenAssetFormatV1
from pydantic import BaseModel


class GCP_STORAGE_BUCKET_ASSET_ATTRS_IAM_V1(BaseModel):
    bucket_policy_only: bool
    uniform_bucket_level_access: bool
    block_public_access: str


class GCP_STORAGE_BUCKET_ASSET_ATTRS_V1(BaseModel):
    display_name: Optional[str] = None
    ancestors: List[str]
    parent: str
    location: str
    storage_class: str
    cors: List
    labels: dict
    versioning: bool
    iam: GCP_STORAGE_BUCKET_ASSET_ATTRS_IAM_V1


class GCP_STORAGE_BUCKET_ASSET_V1(CaizenAssetFormatV1):
    attrs: GCP_STORAGE_BUCKET_ASSET_ATTRS_V1
