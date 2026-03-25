import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from routes import tracking

app = FastAPI(
    title="Smart Travel Tracking System",
    description="Backend service for travel status tracking and agent coordination.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from routes import agents

from services.db import engine
from models import db_models

# Create tables on startup
db_models.Base.metadata.create_all(bind=engine)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOADS_DIR = os.getenv(
    "UPLOADS_DIR",
    "/tmp/uploads" if os.getenv("VERCEL") == "1" else os.path.join(BASE_DIR, "uploads"),
)
MEMORIES_DIR = os.path.join(UPLOADS_DIR, "memories")

os.makedirs(MEMORIES_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOADS_DIR), name="uploads")

app.include_router(tracking.router)
app.include_router(agents.router)

@app.get("/")
async def root():
    return {"status": "success", "data": {"message": "Smart Travel Tracking System API is running"}, "message": ""}
