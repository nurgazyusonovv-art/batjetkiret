from sqlalchemy import text
from app.core.database import engine, Base
from app.models import *


def _migrate(engine):
    """Incremental schema migrations — each runs in its own connection/transaction."""
    import logging
    logger = logging.getLogger("app.init_db")
    # Note: SQLite <3.37.0 doesn't support IF NOT EXISTS in ALTER TABLE ADD COLUMN,
    # so we use plain ADD COLUMN and let the try/except catch "duplicate column" errors.
    migrations = [
        "ALTER TABLE orders ADD COLUMN order_type VARCHAR DEFAULT 'delivery'",
        "ALTER TABLE orders ADD COLUMN table_number VARCHAR",
        "ALTER TABLE orders ADD COLUMN hidden_for_enterprise BOOLEAN DEFAULT FALSE",
        "ALTER TABLE users ADD COLUMN current_latitude FLOAT",
        "ALTER TABLE users ADD COLUMN current_longitude FLOAT",
        "ALTER TABLE orders ADD COLUMN intercity_city_id INTEGER",
        "ALTER TABLE users ADD COLUMN fcm_token VARCHAR",
    ]
    for sql in migrations:
        try:
            with engine.connect() as conn:
                conn.execute(text(sql))
                conn.commit()
        except Exception as e:
            logger.debug(f"Migration skipped (already applied): {sql.split('ADD COLUMN')[1].strip().split()[0] if 'ADD COLUMN' in sql else sql}")


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
