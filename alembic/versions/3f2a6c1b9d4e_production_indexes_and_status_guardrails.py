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
    "'DELIVERED', 'COMPLETED', 'CANCELLED')"
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

    op.create_check_constraint(
        "ck_orders_status_valid",
        "orders",
        VALID_STATUS_SQL,
    )

    op.create_index(
        "ix_orders_user_id_created_at",
        "orders",
        ["user_id", "created_at"],
        unique=False,
    )
    op.create_index(
        "ix_orders_courier_id_created_at",
        "orders",
        ["courier_id", "created_at"],
        unique=False,
    )
    op.create_index(
        "ix_orders_status_created_at",
        "orders",
        ["status", "created_at"],
        unique=False,
    )
    op.create_index(
        "ix_chat_rooms_order_id_type",
        "chat_rooms",
        ["order_id", "type"],
        unique=False,
    )


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
