from common.v1.schemas import HealthStatus  # noqa
from fastapi import FastAPI, Request
from neo4j import GraphDatabase
from src.v1.router import v1_router as v1_router  # noqa


def lifespan(app: FastAPI):
    """Makes a single conn to the db on startup. Autocloses on shutdown."""
    URI = "bolt://localhost:7687"
    AUTH = ("", "")
    with GraphDatabase.driver(URI, auth=AUTH) as driver:
        app.db = driver
        yield


app = FastAPI(
    title="CAIZEN API",
    description="A real-time cloud resource and attack graph platform.",
    version="0.0.1",
    lifespan=lifespan,
)
app.include_router(v1_router, prefix="/v1")


@app.get("/status", response_model=HealthStatus)
def health_status(request: Request) -> HealthStatus:
    """Health endpoint for the API -- Tests the graph db connection"""
    db = request.app.db
    try:
        db.run("MATCH (n) RETURN count(n) as count limit 1")
        return HealthStatus(status="ok", msg="Graph DB alive")
    except Exception:
        return HealthStatus(status="error", msg="Graph DB unavailable")
