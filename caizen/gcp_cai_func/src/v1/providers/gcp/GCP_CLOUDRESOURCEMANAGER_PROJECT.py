from datetime import datetime

from common.v1.providers.gcp.GCP_CLOUDRESOURCEMANAGER_PROJECT import (
    GCP_CLOUDRESOURCEMANAGER_PROJECT_ASSET_V1,
)
from common.v1.schemas import CaizenAssetV1
from src.schemas import CaiRecord


class GCP_CLOUDRESOURCEMANAGER_PROJECT_V1:
    def enrich_attrs(
        ca: GCP_CLOUDRESOURCEMANAGER_PROJECT_ASSET_V1, cr: CaiRecord
    ) -> CaizenAssetV1:
        """
        Set the attributes for a GCP CRM Project asset.

        Args:
            ca: The CAIZEN asset.
            cr: The CAI record.

        Returns:
            The CAIZEN asset with attributes set.
        """
        ca["created"] = datetime.fromisoformat(cr.resource.data.get("createTime"))
        ca["updated"] = cr.update_time
        ca["attrs"]["display_name"] = cr.resource.data.get("name")
        ca["attrs"]["lifecycle_state"] = cr.resource.data.get("lifecycleState").lower()
        ca["attrs"]["project_number"] = cr.resource.data.get("projectNumber")
        ca["attrs"]["project_id"] = cr.resource.data.get("projectId")

        try:
            GCP_CLOUDRESOURCEMANAGER_PROJECT_ASSET_V1(**ca)
        except ValueError as e:
            raise ValueError(f"Error enriching GCP CRM Project asset: {e}")

        return ca
