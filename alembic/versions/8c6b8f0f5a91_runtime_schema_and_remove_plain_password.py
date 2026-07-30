"""runtime schema guardrails and remove plain enterprise passwords

Revision ID: 8c6b8f0f5a91
Revises: 550659a2bf3d
Create Date: 2026-06-06 21:30:00.000000

"""
from typing import Sequence, Union

from alembic import op


revision: str = "8c6b8f0f5a91"
down_revision: Union[str, Sequence[str], None] = "550659a2bf3d"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name

    if dialect == "postgresql":
        op.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_type VARCHAR DEFAULT 'delivery'")
        op.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS table_number VARCHAR")
        op.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS hidden_for_enterprise BOOLEAN DEFAULT FALSE")
        op.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS intercity_city_id INTEGER")
        op.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS items_total NUMERIC(10,2)")
        op.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS source VARCHAR DEFAULT 'online'")
        op.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS cancel_requested BOOLEAN DEFAULT FALSE")
        op.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS cancel_request_reason TEXT")
        op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS current_latitude FLOAT")
        op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS current_longitude FLOAT")
        op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR")
        op.execute("ALTER TABLE users DROP COLUMN IF EXISTS panel_password")
        op.execute("ALTER TABLE enterprises ADD COLUMN IF NOT EXISTS payment_qr_url VARCHAR")
        op.execute("ALTER TABLE enterprises ADD COLUMN IF NOT EXISTS logo_data TEXT")
        op.execute("ALTER TABLE enterprises ADD COLUMN IF NOT EXISTS open_time VARCHAR")
        op.execute("ALTER TABLE enterprises ADD COLUMN IF NOT EXISTS close_time VARCHAR")
        op.execute("ALTER TABLE enterprises ADD COLUMN IF NOT EXISTS prep_time_minutes INTEGER")
        op.execute("ALTER TABLE enterprises ADD COLUMN IF NOT EXISTS is_open_override BOOLEAN")
        op.execute("ALTER TABLE enterprise_products ADD COLUMN IF NOT EXISTS image_url TEXT")
        op.execute("ALTER TABLE ad_popups ADD COLUMN IF NOT EXISTS enterprise_id INTEGER REFERENCES enterprises(id) ON DELETE SET NULL")
        op.execute("ALTER TABLE banners ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0")
        op.execute("ALTER TABLE banners ADD COLUMN IF NOT EXISTS show_days INTEGER DEFAULT 0")
        op.execute("ALTER TABLE banners ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT NOW()")
        op.execute("ALTER TABLE notifications ADD COLUMN IF NOT EXISTS order_id INTEGER")
        op.execute(
            "CREATE TABLE IF NOT EXISTS push_subscriptions ("
            "id SERIAL PRIMARY KEY, "
            "enterprise_id INTEGER NOT NULL, "
            "subscription_json TEXT NOT NULL, "
            "created_at TIMESTAMP DEFAULT NOW())"
        )
        op.execute(
            "CREATE TABLE IF NOT EXISTS user_push_subscriptions ("
            "id SERIAL PRIMARY KEY, "
            "user_id INTEGER NOT NULL, "
            "subscription_json TEXT NOT NULL, "
            "created_at TIMESTAMP DEFAULT NOW())"
        )
        return

    # SQLite/local fallback. Keep this intentionally narrow because SQLite's
    # ALTER TABLE support differs by version.
    columns = {
        row[1]
        for row in bind.exec_driver_sql("PRAGMA table_info(users)").fetchall()
    }
    if "panel_password" in columns:
        bind.exec_driver_sql("ALTER TABLE users DROP COLUMN panel_password")


def downgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "postgresql":
        op.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS panel_password VARCHAR")
