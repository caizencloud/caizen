import os

from common.v1.schemas import CaizenAssetFormatAssetV1

# import all the files in the directory starting with GCP_
for file in os.listdir(os.path.dirname(os.path.realpath(__file__))):
    if file.endswith(".py") and file.startswith("GCP_"):
        exec(f"from src.v1.providers.gcp.{file[:-3]} import *")
