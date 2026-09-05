from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import worker.db as db_mod
from worker.main import BATCH_SIZE, process_batch

engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSession = sessionmaker(bind=engine, expire_on_commit=False)


def _seed(count: int):
    db_mod.Base.metadata.create_all(bind=engine)
    with TestingSession() as s:
        for i in range(count):
            s.add(db_mod.Item(title=f"item-{i}", status="pending"))
        s.commit()


def test_process_batch_marks_rows_and_returns_count():
    _seed(3)
    with TestingSession() as s:
        changed = process_batch(s)
        assert changed == 3
        statuses = [r.status for r in s.query(db_mod.Item).all()]
        assert statuses == ["processed", "processed", "processed"]


def test_process_batch_respects_batch_size():
    _seed(BATCH_SIZE + 5)
    with TestingSession() as s:
        changed = process_batch(s)
        assert changed == BATCH_SIZE
        remaining = s.query(db_mod.Item).filter(db_mod.Item.status == "pending").count()
        assert remaining == 5


def test_process_batch_empty_db_returns_zero():
    db_mod.Base.metadata.drop_all(bind=engine)
    db_mod.Base.metadata.create_all(bind=engine)
    with TestingSession() as s:
        assert process_batch(s) == 0