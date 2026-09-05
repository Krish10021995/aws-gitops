import logging

from fastapi import Depends, FastAPI
from sqlalchemy import select
from sqlalchemy.orm import Session

from api.db import Item, SessionLocal, init_db, ping
from api.schemas import ItemCreate, ItemRead

app = FastAPI(title="demo-api", version="0.1.0")

logger = logging.getLogger("api")


@app.on_event("startup")
def on_startup() -> None:
    try:
        init_db()
    except Exception:
        logger.warning("init_db failed (DB not ready yet); API stays up for readiness checks")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@app.get("/")
def index() -> dict:
    return {"service": "demo-api", "health": "/health", "docs": "/docs"}


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.get("/readyz")
def readyz() -> dict:
    if ping():
        return {"status": "ready", "database": "up"}
    return {"status": "not-ready", "database": "down"}


@app.get("/items", response_model=list[ItemRead])
def list_items(db: Session = Depends(get_db)) -> list[Item]:
    return list(db.execute(select(Item).order_by(Item.id.desc())).scalars())


@app.post("/items", response_model=ItemRead, status_code=201)
def create_item(payload: ItemCreate, db: Session = Depends(get_db)) -> Item:
    item = Item(title=payload.title, description=payload.description, status="pending")
    db.add(item)
    db.commit()
    db.refresh(item)
    return item