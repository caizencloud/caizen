import os

# Import all the provider modules
for folder in os.listdir(os.path.dirname(os.path.realpath(__file__))):
    if not folder.startswith("__"):
        exec(f"from common.v1.providers.{folder} import *")
