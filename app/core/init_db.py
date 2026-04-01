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
        "ALTER TABLE orders ADD COLUMN items_total NUMERIC(10,2)",
        "ALTER TABLE orders ADD COLUMN source VARCHAR DEFAULT 'online'",
        "ALTER TABLE enterprises ADD COLUMN payment_qr_url VARCHAR",
        "ALTER TABLE orders ADD COLUMN cancel_requested BOOLEAN DEFAULT FALSE",
        "ALTER TABLE orders ADD COLUMN cancel_request_reason TEXT",
        "ALTER TABLE enterprise_products ADD COLUMN image_url TEXT",
    ]
    for sql in migrations:
        try:
            with engine.connect() as conn:
                conn.execute(text(sql))
                conn.commit()
        except Exception as e:
            logger.debug(f"Migration skipped (already applied): {sql.split('ADD COLUMN')[1].strip().split()[0] if 'ADD COLUMN' in sql else sql}")

    # Data migration: backfill items_total for existing enterprise local/dine-in orders
    # For these orders price was already set to items total (not delivery fee).
    # Two queries: one with source filter (if source column exists), one fallback by order_type.
    try:
        with engine.connect() as conn:
            conn.execute(text(
                "UPDATE orders SET items_total = price "
                "WHERE items_total IS NULL AND enterprise_id IS NOT NULL "
                "AND source IN ('local', 'dine_in')"
            ))
            conn.commit()
    except Exception as e:
        logger.warning(f"items_total backfill (source filter) failed: {e}")
    # Fallback: enterprise orders without source (treated as local)
    try:
        with engine.connect() as conn:
            conn.execute(text(
                "UPDATE orders SET items_total = price "
                "WHERE items_total IS NULL AND enterprise_id IS NOT NULL "
                "AND (source IS NULL OR source NOT IN ('online'))"
            ))
            conn.commit()
            logger.info("Backfilled items_total for existing enterprise orders")
    except Exception as e:
        logger.warning(f"items_total backfill (fallback) failed: {e}")


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
