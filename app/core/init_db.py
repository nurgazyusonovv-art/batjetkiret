from sqlalchemy import text
from app.core.database import engine, Base
from app.models import *


def _migrate(engine):
    """Incremental SQLite schema migrations (no Alembic)."""
    migrations = [
        "ALTER TABLE orders ADD COLUMN order_type VARCHAR DEFAULT 'delivery'",
        "ALTER TABLE orders ADD COLUMN table_number VARCHAR",
        "ALTER TABLE orders ADD COLUMN hidden_for_enterprise BOOLEAN DEFAULT FALSE NOT NULL",
    ]
    with engine.connect() as conn:
        for sql in migrations:
            try:
                conn.execute(text(sql))
                conn.commit()
            except Exception:
                pass  # Column already exists


def _init_db_with_retry():
    import time
    import logging
    logger = logging.getLogger("app.init_db")
    for attempt in range(10):
        try:
            Base.metadata.create_all(bind=engine)
            _migrate(engine)
            logger.info("Database initialized successfully")
            return
        except Exception as e:
            logger.warning(f"DB init attempt {attempt + 1}/10 failed: {e}")
            if attempt < 9:
                time.sleep(5)
    logger.error("Failed to initialize database after 10 attempts")


def init_db():
    import threading
    t = threading.Thread(target=_init_db_with_retry, daemon=True)
    t.start()


if __name__ == "__main__":
    init_db()
