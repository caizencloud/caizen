from pydantic import ValidationError
from common.v1.schemas import CaizenAssetFormatV1
from fastapi import APIRouter, HTTPException, status

from src.v1.providers import *

router = APIRouter()

# POST /v1/asset
@router.post("/asset", status_code=status.HTTP_201_CREATED)
def process_asset(asset_input: CaizenAssetFormatV1):
    try:
        asset_model = find_asset_processor(asset_input)
        if asset_model.action == "upsert":
            asset_model.upsert()
        elif asset_model.action == "delete":
            asset_model.delete()
        else:
            raise HTTPException(status_code=400, detail="Invalid action")
    except Exception as e:
        raise HTTPException(status_code=400, detail="Failed to process asset")
    
    return {"name": asset_model.name, "action": asset_model.action}


def find_asset_processor(asset_model):
    parsed_model = dict()
    asset_record = asset_model.model_dump()
    asset = asset_record.get('asset')
    asset_type = asset.get('type')
    asset_version = asset_record.get('version')

    try:
        global_model_name = globals().get(f"{asset_type}_ASSET_V{str(asset_version)}")
        if global_model_name is not None:
            parsed_model = global_model_name(**asset)
        else:
            default_model_name = lookup_default_asset_processor(asset_record)
            parsed_model = default_model_name(**asset)
    except TypeError as e:
        print(f"Type error: {e}")
        raise HTTPException(status_code=400, detail="Invalid type error")
    except ValidationError as e:
        print(f"Validation error: {e}")
        raise HTTPException(status_code=400, detail="Invalid asset")
    except Exception as e:
        print(f"Generic processing error: {e}")
        raise HTTPException(status_code=400, detail="Processing error")
    
    return parsed_model


def lookup_default_asset_processor(asset_record):
    asset_version = asset_record.get('version')

    subdirs = []
    for dir in os.listdir(os.path.dirname(os.path.realpath(__file__)) + "/providers"):
        if not dir.startswith("_"):
            subdirs.append(dir.upper())

    default_model_name = globals().get(f"{dir.upper()}_DEFAULT_ASSET_V{str(asset_version)}")
    if default_model_name is None:
        raise HTTPException(status_code=400, detail="Default asset processor not found")

    return default_model_name