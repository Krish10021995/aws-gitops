import os

from sqlalchemy import Column, DateTime, Integer, String, Text, create_engine
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker
from sqlalchemy.sql import func


def database_url() -> str:
    host = os.getenv("DB_HOST", "localhost")
    port = os.getenv("DB_PORT", "5432")
    name = os.getenv("DB_NAME", "demoapp")
    user = os.getenv("DB_USER", "demoapp")
    password = os.getenv("DB_PASSWORD", "demoapp")
    return f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{name}"


engine: Engine = create_engine(database_url(), pool_pre_ping=True)


class Base(DeclarativeBase):
    pass


class Item(Base):
    __tablename__ = "items"

    id = Column(Integer, primary_key=True, autoincrement=True)
    title = Column(String(200), nullable=False)
    description = Column(Text, default="")
    status = Column(String(20), nullable=False, default="pending")
    created_at = Column(DateTime(timezone=True), server_default=func.now())


SessionLocal = sessionmaker(bind=engine, expire_on_commit=False)