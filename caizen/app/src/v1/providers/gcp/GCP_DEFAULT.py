import random
import time

from common.v1.schemas import CaizenAssetV1
from neo4j import GraphDatabase
from neo4j.exceptions import TransientError


class GCP_DEFAULT_ASSET_V1_MANAGER:
    def __init__(self, asset_model: CaizenAssetV1, db: GraphDatabase) -> None:
        self.asset = asset_model
        self.db = db

    def upsert(self) -> None:
        self._write_with_retries(self._upsert_node, asset=self.asset)

    def delete(self) -> None:
        print(f"DEFAULT Deleting {self.asset.name} of type {self.asset.type}")

    def _write_with_retries(self, db_action_func, **kwargs) -> None:
        max_retries = 50
        initial_wait_time = 0.200
        backoff_factor = 1.1
        jitter = 0.1
        with self.db.session(database="") as session:
            for attempt in range(max_retries):
                try:
                    # session.execute_write(action, **kwargs)
                    with session.begin_transaction() as tx:
                        db_action_func(tx, **kwargs)
                        tx.commit()
                        break
                except TransientError:
                    jitter = random.uniform(0, jitter) * initial_wait_time
                    wait_time = initial_wait_time * (backoff_factor**attempt) + jitter
                    print(
                        f"Commit failed on attempt {attempt + 1}. Retrying in {wait_time} seconds..."
                    )
                    time.sleep(wait_time)
                except Exception as e:
                    print(f"Failed to execute transaction: {e}")
                    raise e

    def _upsert_node(self, tx, asset) -> None:
        parent, parent_rel = self._get_parent_details(asset)
        display_name = self._get_display_name(asset)
        node_label = str(asset.type)
        node_attrs = self._get_tidy_attrs(asset)

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
        {parent_rel}
        RETURN n
        """
        tx.run(
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
        print(f"Node {asset.name} of type {asset.type} upserted")

    def _format_3339(self, dt) -> str:
        return dt.replace(microsecond=0).isoformat() + "Z"

    def _get_parent_label(self, parent):
        parent_label = None
        if parent.startswith("cloudresourcemanager.googleapis.com/projects/"):
            parent_label = "GCP_CLOUDRESOURCEMANAGER_PROJECT"
        elif parent.startswith("cloudresourcemanager.googleapis.com/organizations/"):
            parent_label = "GCP_CLOUDRESOURCEMANAGER_ORGANIZATION"
        elif parent.startswith("cloudresourcemanager.googleapis.com/folders/"):
            parent_label = "GCP_CLOUDRESOURCEMANAGER_FOLDER"
        else:
            parent_label = "GCP_CLOUDRESOURCEMANAGER_UNKNOWN"

        return parent_label

    def _get_parent_details(self, asset):
        """
        Get the parent details of the asset

        Args:
            asset (CaizenAssetV1): Asset object

        Returns:
            str: parent name
            str: parent relationship query
        """
        parent = None
        parent_rel = ""
        if "parent" in asset.attrs.__fields_set__:
            parent = asset.attrs.parent
            parent_label = self._get_parent_label(parent)
            parent_rel = f"""
            MERGE (p:{parent_label} {{ name: $parent_name }})
            MERGE (p)-[:HAS_CHILD]->(n)
            """

        return parent, parent_rel

    def _get_display_name(self, asset):
        """
        Get the display name of the asset

        Args:
            asset (CaizenAssetV1): Asset object

        Returns:
            str: friendly display name of the asset
        """
        display_name = asset.name
        if "display_name" in asset.attrs.__fields_set__:
            display_name = asset.attrs.display_name
        if "name" in asset.attrs.__fields_set__:
            display_name = asset.attrs.name

        return display_name

    def _get_tidy_attrs(self, asset):
        """
        Remove parent, display_name and name from the attrs dict

        Args:
            asset (CaizenAssetV1): Asset object

        Returns:
            dict: with several keys removed
        """
        node_attrs = asset.attrs.dict()
        node_attrs.pop("parent", None)
        node_attrs.pop("display_name", None)
        node_attrs.pop("name", None)

        return node_attrs
