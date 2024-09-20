from common.v1.schemas import CaizenAssetV1
from neo4j import GraphDatabase
from src.v1.providers.gcp.GCP_DEFAULT import GCP_DEFAULT_ASSET_V1_MANAGER


class GCP_STORAGE_BUCKET_ASSET_V1_MANAGER(GCP_DEFAULT_ASSET_V1_MANAGER):
    def __init__(self, asset_model: CaizenAssetV1, db: GraphDatabase) -> None:
        super().__init__(asset_model, db)

    # def upsert(self) -> None:
    #     self._upsert()

    def delete(self) -> None:
        print(f"BUCKET Deleting {self.asset.name} of type {self.asset.type}")
