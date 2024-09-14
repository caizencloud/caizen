from datetime import datetime, timezone

from common.v1.schemas import CaizenAssetV1
from src.schemas import CaiRecord


def format_asset_type(input_string: str) -> str:
    """
    Format the asset type to match the CAIZEN schema.
    Ex: pubsub.googleapis.com/Topic -> GCP_PUBSUB_TOPIC

    Args:
        asset_type: The asset type to format.

    Returns:
        The formatted asset type.
    """
    try:
        parts = input_string.split("/")
        if len(parts) != 2:
            raise ValueError(f"Invalid asset_type format {input_string}")

        service = parts[0].split(".")[0].upper()  # "pubsub.googleapis.com" -> "PUBSUB"
        resource = parts[1].upper()  # "Topic" -> "TOPIC"

        return f"GCP_{service}_{resource}"

    except (IndexError, AttributeError) as e:
        # Handle errors related to string splitting or accessing elements
        raise AttributeError(f"Error: Malformed input '{input_string}' - {str(e)}")

    except ValueError as ve:
        # Handle custom validation errors
        raise ValueError(f"Error: {str(ve)}")


def format_asset_name(input_string: str) -> str:
    """
    Format the asset name to match the CAIZEN schema.
    Ex: //pubsub.googleapis.com/projects/caizen-export/topics/gcp-cai-caizen-topic
    -> pubsub.googleapis.com/projects/caizen-export/topics/gcp-cai-caizen-topic

    Args:
        asset_name: The asset name to format.

    Returns:
        The formatted asset name.
    """
    return input_string.lstrip("//")


def transform_cai_data(cai_record: CaiRecord) -> dict:
    """
    Transform a CAI record into a CAIZEN asset.

    Args:
        cai_record: The CAI record to transform.

    Returns:
        The CAIZEN asset as a dictionary.
    """

    cr = cai_record.model_dump()
    name = format_asset_name(cr["name"])
    asset_type = format_asset_type(cr["asset_type"])
    cav1 = {
        "version": 1,
        "asset": {
            "name": name,
            "type": asset_type,
            "action": "upsert",
            "created": datetime.now(timezone.utc),
            "updated": cr["update_time"],
            "attrs": {
                "location": cr["resource"]["location"],
            },
        },
    }
    caizen_asset = CaizenAssetV1(**cav1)

    return caizen_asset
