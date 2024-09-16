from typing import List

from common.v1.schemas import CaizenAssetFormatV1
from neo4j import AsyncGraphDatabase
from pydantic import BaseModel


class GCP_STORAGE_BUCKET_ASSET_ATTRS_IAM_V1(BaseModel):
    bucket_policy_only: bool
    uniform_bucket_level_access: bool
    block_public_access: str


class GCP_STORAGE_BUCKET_ASSET_ATTRS_V1(BaseModel):
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

    async def upsert(self, db: AsyncGraphDatabase) -> None:
        session = db.session()
        async with await session.begin_transaction() as tx:
            result = await tx.run("MATCH (n) RETURN count(n) as count")
            data = await result.single()
            count = data[0]
        print(f"{count} nodes")
        print(f"BUCKET Upserting {self.name} of type {self.type}" f" with {self.attrs}")

    async def delete(self, db: AsyncGraphDatabase) -> None:
        print(f"BUCKET Deleting {self.name} of type {self.type}")
