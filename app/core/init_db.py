from sqlalchemy import text
from app.core.database import engine, Base
from app.models import *


def _migrate(engine):
    """Incremental schema migrations — each runs in its own connection/transaction."""
    import logging
    logger = logging.getLogger("app.init_db")
    migrations = [
        "ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_type VARCHAR DEFAULT 'delivery'",
        "ALTER TABLE orders ADD COLUMN IF NOT EXISTS table_number VARCHAR",
        "ALTER TABLE orders ADD COLUMN IF NOT EXISTS hidden_for_enterprise BOOLEAN DEFAULT FALSE",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS current_latitude FLOAT",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS current_longitude FLOAT",
        "ALTER TABLE orders ADD COLUMN IF NOT EXISTS intercity_city_id INTEGER",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR",
    ]
    for sql in migrations:
        try:
            with engine.connect() as conn:
                conn.execute(text(sql))
                conn.commit()
        except Exception as e:
            logger.warning(f"Migration skipped ({e})")


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
