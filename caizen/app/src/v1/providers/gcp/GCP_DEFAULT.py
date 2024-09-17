from common.v1.schemas import CaizenAssetV1
from neo4j import AsyncGraphDatabase


class GCP_DEFAULT_ASSET_V1_LOADER:
    def __init__(self, asset_model: CaizenAssetV1, db: AsyncGraphDatabase) -> None:
        self.asset = asset_model
        self.db = db

    async def upsert(self) -> None:
        session = self.db.session()
        async with await session.begin_transaction() as tx:
            result = await tx.run("MATCH (n) RETURN count(n) as count")
            data = await result.single()
            count = data[0]
        print(f"{count} nodes")
        print(
            f"DEFAULT Upserting {self.asset.name} of type {self.asset.type}"
            f" with {self.asset.attrs}"
        )

    async def delete(self) -> None:
        print(f"DEFAULT Deleting {self.asset.name} of type {self.asset.type}")
