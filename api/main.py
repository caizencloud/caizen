from fastapi import FastAPI, HTTPException
from fastapi.encoders import jsonable_encoder

from models import CypherQuery
from db.graph_db import Database

db = Database("bolt://localhost:7687", "", "")

api = FastAPI()

@api.get("/")
def root():
    return {"status": "ok"}

@api.get("/resources")
def get_resources():
    try:
        result = db.get_all()
        return {"resources": result}
    except Exception as e:
        raise HTTPException(status_code=404, detail="No resources found")

@api.delete("/resources")
def delete_resources():
    try:
        db.delete_all()
        return {}
    except Exception as e:
        raise HTTPException(status_code=404, detail="Failed to delete all resources")

@api.post("/q")
def graph_query(cq: CypherQuery):
    try:
        return {"result": db.execute_query(cq.query, raw=True)}
    except Exception as e:
        raise HTTPException(status_code=400, detail="Failed to execute query")