from typing import List

from common.v1.schemas import CaizenAssetFormatV1
from pydantic import BaseModel


class GCP_PUBSUB_TOPIC_ASSET_ATTRS_V1(BaseModel):
    ancestors: List[str]
    parent: str
    location: str


class GCP_PUBSUB_TOPIC_ASSET_V1(CaizenAssetFormatV1):
    attrs: GCP_PUBSUB_TOPIC_ASSET_ATTRS_V1
