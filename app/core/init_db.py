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


def init_db():
    import time
    import logging
    logger = logging.getLogger("app.init_db")
    for attempt in range(5):
        try:
            Base.metadata.create_all(bind=engine)
            _migrate(engine)
            logger.info("Database initialized successfully")
            return
        except Exception as e:
            logger.warning(f"DB init attempt {attempt + 1}/5 failed: {e}")
            if attempt < 4:
                time.sleep(3)
    logger.error("Failed to initialize database after 5 attempts")


if __name__ == "__main__":
    init_db()
