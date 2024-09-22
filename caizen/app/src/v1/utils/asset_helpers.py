import os

from common.v1.providers import *  # noqa
from fastapi import HTTPException
from src.v1.providers import *  # noqa


def find_asset_processor(asset_model) -> dict:
    """
    Find an appropriate asset processor via its asset_type for the asset model, call
    the upsert or delete method on the asset model, and return the processed asset.

    Args:
        asset_model: The asset model to process.

    Returns:
        The processed asset dictionary
    """
    try:
        asset_type = asset_model.asset.type
        asset_version = asset_model.version

        # named
        processor = globals().get(f"{asset_type}_ASSET_V{str(asset_version)}")
        if not processor:
            # try to find the default asset processor for the provider
            subdirs = list_of_provider_subdirs()

            for dir in subdirs:
                if asset_type.lower().startswith(f"{dir.lower()}_"):
                    processor = globals().get(
                        f"{dir.upper()}_DEFAULT_ASSET_V{str(asset_version)}"
                    )
                    break
    except Exception as e:
        raise HTTPException(
            status_code=400, detail=f"Failed to find asset processor: {e}"
        )

    if not processor:
        raise HTTPException(status_code=400, detail="No asset processor not found")

    return processor


def list_of_provider_subdirs() -> list:
    """
    Get list of providers via the names of the subdirectories.

    Returns:
        List of provider subdirectories.
    """
    return [
        dir.upper()
        for dir in os.listdir(os.path.join(os.path.dirname(__file__), "../providers"))
        if not dir.startswith("_")
    ]
