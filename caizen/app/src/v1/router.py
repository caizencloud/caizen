import os

from common.v1.providers import *  # noqa
from common.v1.schemas import CaizenAssetV1, ProcessedAsset
from fastapi import APIRouter, HTTPException, Request, status
from src.v1.providers import *  # noqa

v1_router = APIRouter()


# POST /v1/asset
@v1_router.post(
    "/asset",
    status_code=status.HTTP_201_CREATED,
    response_model=ProcessedAsset,
)
async def process_asset(req: Request, input: CaizenAssetV1) -> ProcessedAsset:
    """
    Find an asset processor and call the upsert or delete method on the asset
    model to upsert or delete the asset in the database.
    """
    db = req.app.db
    try:
        asset_model = await find_asset_processor(input)
        # create instance of class f"{type(asset_model).__name__}_LOADER"
        # and call action (upsert or delete) method
        loader = globals().get(f"{type(asset_model).__name__}_LOADER")(
            db=db, asset_model=asset_model
        )
        await getattr(loader, asset_model.action)()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to process asset: {e}")

    return ProcessedAsset(name=asset_model.name, action=asset_model.action)


async def find_asset_processor(asset_model) -> dict:
    """
    Find an appropriate asset processor via its asset_type for the asset model.
    """
    parsed_model = dict()
    asset_record = asset_model.model_dump()
    asset = asset_record.get("asset")
    asset_type = asset.get("type")
    asset_version = asset_record.get("version")

    # Match a provider's named processor by asset_type and asset_version
    # If no exact match is found, try the default asset processor
    try:
        model_name = await lookup_named_asset_processor(asset_type, asset_version)
        if model_name is not None:
            parsed_model = model_name(**asset)
        else:
            default_model_name = await lookup_default_asset_processor(asset_record)
            # No default model matches the asset_type
            if default_model_name is None:
                raise HTTPException(
                    status_code=400, detail="Default asset processor not found"
                )
            parsed_model = default_model_name(**asset)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Processing error: {e}")

    return parsed_model


async def lookup_named_asset_processor(asset_type, asset_version) -> dict | None:
    """Helper function to find a named asset processor."""
    model = globals().get(f"{asset_type}_ASSET_V{str(asset_version)}")

    return model


async def lookup_default_asset_processor(asset_record) -> dict | None:
    """
    Find the default asset processor for the asset model or throw an error.
    """
    asset_version = asset_record.get("version")
    asset_type = asset_record.get("asset").get("type")

    subdirs = await list_of_provider_subdirs()

    # See if the asset_type matches any provider subdir
    # and set the default model name to its default asset processor
    default_model_name = None
    for dir in subdirs:
        if asset_type.lower().startswith(f"{dir.lower()}_"):
            default_model_name = globals().get(
                f"{dir.upper()}_DEFAULT_ASSET_V{str(asset_version)}"
            )
            break

    return default_model_name


async def list_of_provider_subdirs():
    """Get list of providers via the names of the subdirectories."""
    return [
        dir.upper()
        for dir in os.listdir(os.path.join(os.path.dirname(__file__), "providers"))
        if not dir.startswith("_")
    ]
