from common.v1.providers import *  # noqa
from common.v1.schemas import CaizenAssetV1, ProcessedAsset
from fastapi import APIRouter, HTTPException, Request, status
from src.v1.providers import *  # noqa
from src.v1.utils.asset_helpers import find_asset_processor

v1_router = APIRouter()


# POST /v1/asset
@v1_router.post(
    "/asset",
    status_code=status.HTTP_201_CREATED,
    response_model=ProcessedAsset,
)
def process_asset_upsert(req: Request, input: CaizenAssetV1) -> ProcessedAsset:
    """
    Find an asset processor and call the upsert method on the asset
    model to upsert the asset into the database.

    Args:
        input: The asset model to process.

    Returns:
        The processed asset JSON response.
    """
    try:
        # Find the asset processor to use
        asset_processor = find_asset_processor(input)
        # Process the asset into a pydantic model
        asset_model = asset_processor(**input.asset.model_dump())
        # Get the db manager class for the asset model
        loader_cls = globals().get(f"{type(asset_model).__name__}_MANAGER")
        # and call upsert()
        loader_cls(db=req.app.db, asset_model=asset_model).upsert()
    except Exception as e:
        print(f"Failed to upsert asset: {e}")
        raise HTTPException(status_code=400, detail=f"Failed to upsert asset: {e}")

    return ProcessedAsset(name=asset_model.name, action=asset_model.action)


# DELETE /v1/asset
@v1_router.delete(
    "/asset",
    status_code=status.HTTP_200_OK,
    response_model=ProcessedAsset,
)
def process_asset_delete(req: Request, input: CaizenAssetV1) -> ProcessedAsset:
    """
    Find an asset processor and call the delete method on the asset
    model to delete the asset from the database.

    Args:
        input: The asset model to process.

    Returns:
        The processed asset JSON response.
    """
    try:
        # Find the asset processor to use
        asset_processor = find_asset_processor(input)
        # Process the asset into a pydantic model
        asset_model = asset_processor(**input.asset.model_dump())
        # Get the db manager class for the asset model
        loader_cls = globals().get(f"{type(asset_model).__name__}_MANAGER")
        # and call delete()
        loader_cls(db=req.app.db, asset_model=asset_model).delete()
    except Exception as e:
        print(f"Failed to delete asset: {e}")
        raise HTTPException(status_code=400, detail=f"Failed to delete asset: {e}")

    return ProcessedAsset(name=asset_model.name, action=asset_model.action)
