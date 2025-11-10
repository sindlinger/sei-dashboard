from __future__ import annotations

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session

from .database import Base, engine, get_db
from .routers import auth as auth_router
from .routers import tasks as tasks_router

Base.metadata.create_all(bind=engine)

app = FastAPI(title="SEIAutomation API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router.router)
app.include_router(tasks_router.router)


@app.get("/")
def read_root():
    return {"status": "ok"}

