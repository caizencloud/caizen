from typing import List, Optional

from common.v1.schemas import CaizenAssetFormatV1
from pydantic import BaseModel


class GCP_CLOUDRESOURCEMANAGER_PROJECT_ASSET_ATTRS_V1(BaseModel):
    ancestors: List[str]
    parent: str
    location: Optional[str] = "global"
    display_name: str
    lifecycle_state: str
    project_number: int
    project_id: str


class GCP_CLOUDRESOURCEMANAGER_PROJECT_ASSET_V1(CaizenAssetFormatV1):
    attrs: GCP_CLOUDRESOURCEMANAGER_PROJECT_ASSET_ATTRS_V1
