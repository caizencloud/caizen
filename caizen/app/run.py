import os
import sys
# Add the parent directory to the sys.path
sys.path.append(os.path.dirname(os.path.dirname(os.path.realpath(__file__))))

from fastapi import FastAPI

from src.v1 import routes as v1_routes

app = FastAPI()

# /v1 routes
app.include_router(v1_routes.router, prefix="/v1")