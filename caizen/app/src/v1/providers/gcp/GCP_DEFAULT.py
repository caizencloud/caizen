from neo4j import AsyncGraphDatabase
from common.v1.schemas import CaizenAssetFormatV1


class GCP_DEFAULT_ASSET_V1(CaizenAssetFormatV1):

    async def upsert(self, db: AsyncGraphDatabase) -> None:
        print(
            f"GCP_DEFAULT: Upserting {self.name} of type {self.type}"
            f" with {self.attrs}"
        )

    async def delete(self, db: AsyncGraphDatabase) -> None:
        print(f"GCP_DEFAULT: Deleting {self.name} of type {self.type}")
