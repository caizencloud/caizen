from common.v1.providers.gcp.GCP_PUBSUB_TOPIC import GCP_PUBSUB_TOPIC_ASSET_V1
from common.v1.schemas import CaizenAssetV1
from src.schemas import CaiRecord


class GCP_PUBSUB_TOPIC_V1:
    def enrich_attrs(ca: GCP_PUBSUB_TOPIC_ASSET_V1, cr: CaiRecord) -> CaizenAssetV1:
        """
        Set the attributes for a GCP PUBSUB TOPIC asset.

        Args:
            cav: The CAIZEN asset.
            cr: The CAI record.

        Returns:
            The CAIZEN asset with attributes set.
        """
        ca["attrs"]["display_name"] = cr.name.split("/")[-1]

        try:
            GCP_PUBSUB_TOPIC_ASSET_V1(**ca)
        except ValueError as e:
            raise ValueError(f"Error enriching GCP_PUBSUB_TOPIC asset: {e}")

        return ca
