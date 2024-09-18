from typing import Optional

from common.v1.schemas import CaizenAssetFormatV1
from pydantic import BaseModel


class GCP_CLOUDRESOURCEMANAGER_ORGANIZATION_ASSET_ATTRS_V1(BaseModel):
    location: Optional[str] = "global"
    display_name: str
    lifecycle_state: str


class GCP_CLOUDRESOURCEMANAGER_ORGANIZATION_ASSET_V1(CaizenAssetFormatV1):
    attrs: GCP_CLOUDRESOURCEMANAGER_ORGANIZATION_ASSET_ATTRS_V1
