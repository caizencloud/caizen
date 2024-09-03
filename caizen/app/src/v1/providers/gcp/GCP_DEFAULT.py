from common.v1.schemas import CaizenAssetFormatAssetV1

class GCP_DEFAULT_ASSET_V1(CaizenAssetFormatAssetV1):
   
    def upsert(self):
        print(f"GCP_DEFAULT: Upserting {self.name} of type {self.type} with {self.attrs}")

    def delete(self):
        print(f"GCP_DEFAULT: Deleting {self.name} of type {self.type}") 