from datetime import datetime, timezone

from common.v1.schemas import CaizenAssetV1
from src.v1.providers import *  # noqa


def parse_ancestors(asset_name, ancestors_list):
    """
    Transform the ancestors list by prepending 'cloudresourcemanager.googleapis.com/'

    Args:
        ancestors_list: List of ancestor strings.

    Returns:
        List of transformed ancestor strings.
    """
    ancestors = ["cloudresourcemanager.googleapis.com/" + a for a in ancestors_list]

    # Remove self from the ancestors list
    if asset_name in ancestors:
        ancestors.remove(asset_name)

    return ancestors


class GCP_ASSET:
    def transform(cr) -> CaizenAssetV1:
        """
        Transform a CAI record into a CAIZEN asset.

        Args:
            cai_record: The CAI record to transform.

        Returns:
            The CAIZEN asset as a dictionary.
        """
        # Use the earliest time as the created time
        created = datetime.now(timezone.utc)
        if created > cr.update_time:
            created = cr.update_time

        ancestors = parse_ancestors(cr.name, cr.ancestors)

        # Create the asset dictionary
        ca = {
            "name": cr.name,
            "type": cr.asset_type,
            "action": "upsert",
            "created": created,
            "updated": cr.update_time,
            "attrs": {
                "ancestors": ancestors,
                "parent": str(cr.resource.parent).lstrip("//"),
                "location": cr.resource.location,
            },
        }

        # Enrich the asset with custom attributes based on the asset type
        asset_model = globals().get(f"{cr.asset_type}_V1")
        if asset_model:
            ca = asset_model.enrich_attrs(ca, cr)

        # Wrap into a CaizenAssetV1 object
        cav = {"version": 1, "asset": ca}
        caizen_asset = CaizenAssetV1(**cav)

        return caizen_asset
