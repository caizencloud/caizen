import random
import time

from common.v1.schemas import CaizenAssetV1
from neo4j import GraphDatabase


class GCP_DEFAULT_ASSET_V1_LOADER:
    def __init__(self, asset_model: CaizenAssetV1, db: GraphDatabase) -> None:
        self.asset = asset_model
        self.db = db

    def upsert(self) -> None:
        raise NotImplementedError

    def _upsert(self) -> None:
        max_retries = 50
        initial_wait_time = 0.200
        backoff_factor = 1.1
        jitter = 0.1
        asset = self.asset
        with self.db.session(database="") as session:
            for attempt in range(max_retries):
                try:
                    session.execute_write(self._upsert_node, asset)
                    break
                except Exception as e:
                    if e.__context__.code.startswith("Memgraph.TransientError"):
                        jitter = random.uniform(0, jitter) * initial_wait_time
                        wait_time = (
                            initial_wait_time * (backoff_factor**attempt) + jitter
                        )
                        print(
                            f"Commit failed on attempt {attempt + 1}. Retrying in {wait_time} seconds..."
                        )
                        time.sleep(wait_time)
                    else:
                        print(f"Failed to execute transaction: {e}")
                        session.close()
                        raise e

    def delete(self) -> None:
        print(f"DEFAULT Deleting {self.asset.name} of type {self.asset.type}")

    def _upsert_node(self, tx, asset) -> None:
        try:
            parent = None
            parent_query = ""
            if "parent" in asset.attrs.__fields_set__:
                parent = asset.attrs.parent

                parent_label = None
                if parent.startswith("cloudresourcemanager.googleapis.com/projects/"):
                    parent_label = "GCP_CLOUDRESOURCEMANAGER_PROJECT"
                elif parent.startswith(
                    "cloudresourcemanager.googleapis.com/organizations/"
                ):
                    parent_label = "GCP_CLOUDRESOURCEMANAGER_ORGANIZATION"
                elif parent.startswith("cloudresourcemanager.googleapis.com/folders/"):
                    parent_label = "GCP_CLOUDRESOURCEMANAGER_FOLDER"
                else:
                    raise Exception(f"Unknown parent type {parent}")

                parent_query = f"""
                MERGE (p:{parent_label} {{ name: $parent_name }})
                MERGE (p)-[:HAS_CHILD]->(n)
                """

            display_name = None
            if "display_name" in asset.attrs.__fields_set__:
                display_name = asset.attrs.display_name

            node_label = str(asset.type)
            q = f"""
            MERGE (n:{node_label} {{ name: $node_name }})
            ON CREATE SET
             n.created_ts = $created,
             n.created = $created_display,
             n.updated_ts = $updated,
             n.updated = $updated_display,
             n.display_name = $display_name,
             n.attrs = $node_attrs
            ON MATCH SET
             n.updated_ts = $updated,
             n.updated = $updated_display,
             n.display_name = $display_name,
             n.attrs = $node_attrs
            {parent_query}
            RETURN n
            """
            node_attrs = asset.attrs.dict()
            node_attrs.pop("parent", None)
            node_attrs.pop("display_name", None)
            result = tx.run(
                q,
                node_name=str(asset.name),
                created=asset.created.timestamp(),
                created_display=self._format_3339(asset.created),
                updated=asset.updated.timestamp(),
                updated_display=self._format_3339(asset.updated),
                node_attrs=node_attrs,
                display_name=display_name,
                parent_name=parent,
            )
            result.data()
            print(f"Node {asset.name} of type {asset.type} upserted")

        except Exception as e:
            print(f"Node {asset.name}/{asset.type} failed upserting: {e}")
            raise Exception(f"Node {asset.name}/{asset.type} failed upserting: {e}")

    def _format_3339(self, dt) -> str:
        return dt.replace(microsecond=0).isoformat() + "Z"
