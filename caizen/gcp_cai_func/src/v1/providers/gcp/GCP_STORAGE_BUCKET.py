from datetime import datetime

from common.v1.providers.gcp.GCP_STORAGE_BUCKET import GCP_STORAGE_BUCKET_ASSET_V1
from common.v1.schemas import CaizenAssetV1
from src.schemas import CaiRecord


class GCP_STORAGE_BUCKET_V1:
    def enrich_attrs(ca: GCP_STORAGE_BUCKET_ASSET_V1, cr: CaiRecord) -> CaizenAssetV1:
        """
        Set the attributes for a GCP Storage Bucket asset.

        Args:
            ca: The CAIZEN asset.
            cr: The CAI record.

        Returns:
            The CAIZEN asset with attributes set.
        """
        ca["created"] = datetime.fromisoformat(cr.resource.data.get("timeCreated"))
        ca["attrs"]["storage_class"] = cr.resource.data.get(
            "storageClass", "STANDARD"
        )  # "STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"
        ca["attrs"]["iam"] = {
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
        ca["attrs"]["cors"] = cr.resource.data.get("cors", [])
        ca["attrs"]["labels"] = cr.resource.data.get("labels", {})
        ca["attrs"]["versioning"] = cr.resource.data.get("versioning", {}).get(
            "enabled", False
        )

        try:
            GCP_STORAGE_BUCKET_ASSET_V1(**ca)
        except ValueError as e:
            raise ValueError(f"Error enriching GCP Storage Bucket asset: {e}")

        return ca
