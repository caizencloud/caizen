from datetime import datetime, timezone

from common.v1.schemas import CaizenAssetV1
from src.v1.providers import *  # noqa


class GCP_ASSET:
    def transform(self, cr) -> CaizenAssetV1:
        """
        Transform a CAI record into a CAIZEN asset.

        Args:
            cai_record: The CAI record to transform.

        Returns:
            The CAIZEN asset as a dictionary.
        """

        created = self._get_created_time(cr)
        ancestors = self._parse_ancestors(cr.name, cr.ancestors)

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

    def _parse_ancestors(self, asset_name, ancestors_list):
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

    def _get_created_time(self, cr):
        """
        Get the created time of the asset. If not found, return the epoch datetime.

        Args:
            cr: The CAI record.

        Returns:
            created: datetime object of the created time.

        """
        created = datetime.fromtimestamp(0, tz=timezone.utc)
        ct = cr.resource.data.get("createTime") or cr.resource.data.get("creationTime")
        if ct:
            created = datetime.fromisoformat(ct)

        return created
