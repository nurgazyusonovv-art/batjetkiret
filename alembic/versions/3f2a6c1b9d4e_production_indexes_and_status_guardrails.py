"""Production indexes and order status guardrails

Revision ID: 3f2a6c1b9d4e
Revises: 90d719f958fb
Create Date: 2026-03-04 10:15:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "3f2a6c1b9d4e"
down_revision: Union[str, Sequence[str], None] = "90d719f958fb"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


VALID_STATUS_SQL = (
    "status IN ('WAITING_COURIER', 'ACCEPTED', 'ON_THE_WAY', "
    "'PREPARING', 'READY', 'DELIVERED', 'COMPLETED', 'CANCELLED')"
)


def upgrade() -> None:
    op.execute("UPDATE orders SET status = 'WAITING_COURIER' WHERE status IS NULL")

    op.alter_column(
        "orders",
        "status",
        existing_type=sa.String(),
        nullable=False,
        server_default=sa.text("'WAITING_COURIER'"),
    )

    op.execute("ALTER TABLE orders DROP CONSTRAINT IF EXISTS ck_orders_status_valid")
    op.execute(f"ALTER TABLE orders ADD CONSTRAINT ck_orders_status_valid CHECK ({VALID_STATUS_SQL})")
    op.execute("CREATE INDEX IF NOT EXISTS ix_orders_user_id_created_at ON orders (user_id, created_at)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_orders_courier_id_created_at ON orders (courier_id, created_at)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_orders_status_created_at ON orders (status, created_at)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_chat_rooms_order_id_type ON chat_rooms (order_id, type)")


def downgrade() -> None:
    op.drop_index("ix_chat_rooms_order_id_type", table_name="chat_rooms")
    op.drop_index("ix_orders_status_created_at", table_name="orders")
    op.drop_index("ix_orders_courier_id_created_at", table_name="orders")
    op.drop_index("ix_orders_user_id_created_at", table_name="orders")

    op.drop_constraint("ck_orders_status_valid", "orders", type_="check")

    op.alter_column(
        "orders",
        "status",
        existing_type=sa.String(),
        nullable=True,
        server_default=None,
    )
