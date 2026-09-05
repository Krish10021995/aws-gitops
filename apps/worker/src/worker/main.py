import json
import logging
import os
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from sqlalchemy import select, text, update
from sqlalchemy.orm import Session

from worker.db import Item, SessionLocal, engine

log = logging.getLogger("worker")
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

POLL_SECONDS = float(os.getenv("POLL_SECONDS", "5"))
BATCH_SIZE = int(os.getenv("BATCH_SIZE", "50"))

_counter: dict[str, int] = {"processed": 0}


def process_batch(session: Session | None = None) -> int:
    """Mark up to BATCH_SIZE pending rows as processed. Returns how many changed."""
    owns_session = session is None
    session = session or SessionLocal()
    try:
        ids = list(
            session.execute(
                select(Item.id).where(Item.status == "pending").limit(BATCH_SIZE)
            ).scalars()
        )
        if not ids:
            return 0
        result = session.execute(
            update(Item)
            .where(Item.id.in_(ids), Item.status == "pending")
            .values(status="processed")
        )
        session.commit()
        return int(result.rowcount)
    finally:
        if owns_session:
            session.close()


def ping() -> bool:
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False


def run_forever(stop_event: threading.Event) -> None:
    while not stop_event.is_set():
        try:
            n = process_batch()
            if n:
                _counter["processed"] += n
                log.info("processed %d item(s), total=%d", n, _counter["processed"])
        except Exception:
            log.exception("batch failed; DB may be down")
        stop_event.wait(POLL_SECONDS)


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path in ("/healthz", "/"):
            status, body = 200, {"status": "ok", "processed": _counter["processed"]}
        elif self.path == "/readyz":
            if ping():
                status, body = 200, {"status": "ready", "database": "up"}
            else:
                status, body = 503, {"status": "not-ready", "database": "down"}
        else:
            status, body = 404, {"error": "not found"}

        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, format: str, *args) -> None:
        return


HEALTH_PORT = int(os.getenv("HEALTH_PORT", "8080"))


def serve_health() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", HEALTH_PORT), HealthHandler)
    log.info("health server on :%d", HEALTH_PORT)
    server.serve_forever()


def main() -> None:
    stop_event = threading.Event()
    server_thread = threading.Thread(target=serve_health, daemon=True)
    server_thread.start()
    run_forever(stop_event)


if __name__ == "__main__":
    main()