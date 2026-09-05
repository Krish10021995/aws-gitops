from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import api.db as db_mod
from api.main import app, get_db

engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSession = sessionmaker(bind=engine, expire_on_commit=False)


def _init_test_db():
    db_mod.Base.metadata.create_all(bind=engine)


def _override_db():
    session = TestingSession()
    try:
        yield session
    finally:
        session.close()


app.dependency_overrides[get_db] = _override_db
client = TestClient(app)


def test_health():
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


def test_create_and_list_items():
    _init_test_db()
    created = {"title": "hello", "description": "world"}
    resp = client.post("/items", json=created)
    assert resp.status_code == 201
    body = resp.json()
    assert body["title"] == "hello"
    assert body["status"] == "pending"

    items = client.get("/items").json()
    assert len(items) == 1
    assert items[0]["title"] == "hello"


def test_create_requires_title():
    resp = client.post("/items", json={"description": "no title"})
    assert resp.status_code == 422