from datetime import datetime, timezone

from common.v1.providers.gcp import (
    GCP_PUBSUB_TOPIC_ASSET_V1,
    GCP_STORAGE_BUCKET_ASSET_V1,
)
from common.v1.schemas import CaizenAssetV1
from src.schemas import CaiRecord


class GCP_ASSET:
    def transform(cr) -> CaizenAssetV1:
        """
        Transform a CAI record into a CAIZEN asset.

        Args:
            cai_record: The CAI record to transform.

        Returns:
            The CAIZEN asset as a dictionary.
        """
        asset_version = cr.resource.version.lstrip("v")
        # Use the earliest time as the created time
        created = datetime.now(timezone.utc)
        if created > cr.update_time:
            created = cr.update_time
        # Remove projects/ from ancestors and format as full paths
        ancestors = [
            "cloudresourcemanager.googleapis.com/" + a
            for a in cr.ancestors
            if not a.startswith("projects/")
        ]

        cav1 = {
            "version": asset_version,
            "asset": {
                "name": cr.name,
                "type": cr.asset_type,
                "action": "upsert",
                "created": created,
                "updated": cr.update_time,
                "attrs": {
                    "ancestors": ancestors,
                    "parent": cr.resource.parent.lstrip("//"),
                    "location": cr.resource.location,
                },
            },
        }
        caizen_asset = CaizenAssetV1(**cav1)

        # Enrich the asset with custom attributes based on the asset type
        asset_model = globals().get(f"{cr.asset_type}_V{str(asset_version)}")
        if asset_model:
            caizen_asset = asset_model.enrich_attrs(caizen_asset, cr)

        return caizen_asset


class GCP_STORAGE_BUCKET_V1:
    def enrich_attrs(cav1: CaizenAssetV1, cr: CaiRecord) -> CaizenAssetV1:
        """
        Set the attributes for a GCP Storage Bucket asset.

        Args:
            cav: The CAIZEN asset.
            cr: The CAI record.

        Returns:
            The CAIZEN asset with attributes set.
        """
        cav1.asset.created = datetime.fromisoformat(cr.resource.data.get("timeCreated"))
        cav1.asset.attrs["storage_class"] = cr.resource.data.get(
            "storageClass", "STANDARD"
        )  # "STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"
        cav1.asset.attrs["iam"] = {
            "bucket_policy_only": cr.resource.data.get("iamConfiguration", {})
            .get("bucketPolicyOnly", {})
            .get("enabled", False),  # True, False
            "uniform_bucket_level_access": cr.resource.data.get("iamConfiguration", {})
            .get("uniformBucketLevelAccess", {})
            .get("enabled", False),  # True, False
            "block_public_access": cr.resource.data.get("iamConfiguration", {}).get(
                "publicAccessPrevention", "unspecified"
            ),  # "enforced", "unspecified"
        }
        cav1.asset.attrs["cors"] = cr.resource.data.get("cors", [])
        cav1.asset.attrs["labels"] = cr.resource.data.get("labels", {})
        cav1.asset.attrs["versioning"] = cr.resource.data.get("versioning", {}).get(
            "enabled", False
        )
        try:
            GCP_STORAGE_BUCKET_ASSET_V1(**cav1.asset.model_dump())
        except ValueError as e:
            raise ValueError(f"Error enriching GCP Storage Bucket asset: {e}")

        return cav1


class GCP_PUBSUB_TOPIC_V1:
    def enrich_attrs(cav1: CaizenAssetV1, cr: CaiRecord) -> CaizenAssetV1:
        """
        Set the attributes for a GCP PUBSUB TOPIC asset.

        Args:
            cav: The CAIZEN asset.
            cr: The CAI record.

        Returns:
            The CAIZEN asset with attributes set.
        """
        try:
            GCP_PUBSUB_TOPIC_ASSET_V1(**cav1.asset.model_dump())
        except ValueError as e:
            raise ValueError(f"Error enriching GCP Storage Bucket asset: {e}")

        return cav1
