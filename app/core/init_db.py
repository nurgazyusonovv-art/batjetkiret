from sqlalchemy import text
from app.core.database import engine, Base
from app.models import *


def _migrate(engine):
    """Incremental schema migrations — each runs in its own connection/transaction."""
    import logging
    logger = logging.getLogger("app.init_db")
    # PostgreSQL-safe migrations using IF NOT EXISTS (supported in PG 9.6+).
    # lock_timeout prevents ALTER TABLE from hanging indefinitely waiting for locks.
    migrations = [
        "ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_type VARCHAR DEFAULT 'delivery'",
        "ALTER TABLE orders ADD COLUMN IF NOT EXISTS table_number VARCHAR",
        "ALTER TABLE orders ADD COLUMN IF NOT EXISTS hidden_for_enterprise BOOLEAN DEFAULT FALSE",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS current_latitude FLOAT",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS current_longitude FLOAT",
        "ALTER TABLE orders ADD COLUMN IF NOT EXISTS intercity_city_id INTEGER",
        "ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR",
        "ALTER TABLE orders ADD COLUMN IF NOT EXISTS items_total NUMERIC(10,2)",
        "ALTER TABLE orders ADD COLUMN IF NOT EXISTS source VARCHAR DEFAULT 'online'",
        "ALTER TABLE enterprises ADD COLUMN IF NOT EXISTS payment_qr_url VARCHAR",
        "ALTER TABLE orders ADD COLUMN IF NOT EXISTS cancel_requested BOOLEAN DEFAULT FALSE",
        "ALTER TABLE orders ADD COLUMN IF NOT EXISTS cancel_request_reason TEXT",
        "ALTER TABLE enterprise_products ADD COLUMN IF NOT EXISTS image_url TEXT",
        "ALTER TABLE ad_popups ADD COLUMN IF NOT EXISTS enterprise_id INTEGER REFERENCES enterprises(id) ON DELETE SET NULL",
        "ALTER TABLE banners ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0",
        "ALTER TABLE banners ADD COLUMN IF NOT EXISTS show_days INTEGER DEFAULT 0",
        "ALTER TABLE banners ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT NOW()",
    ]
    for sql in migrations:
        try:
            with engine.connect() as conn:
                # 3-second lock timeout prevents ALTER TABLE from blocking requests
                conn.execute(text("SET lock_timeout = '3s'"))
                conn.execute(text(sql))
                conn.commit()
        except Exception as e:
            col = sql.split('ADD COLUMN')[1].strip().split()[1] if 'ADD COLUMN' in sql else sql[:40]
            logger.debug(f"Migration skipped: {col} — {e}")

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
