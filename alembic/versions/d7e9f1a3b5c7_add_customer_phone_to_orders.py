"""add customer phone to orders

Revision ID: d7e9f1a3b5c7
Revises: a2b4c6d8e0f1
Create Date: 2026-07-31 10:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "d7e9f1a3b5c7"
down_revision = "a2b4c6d8e0f1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "orders",
        sa.Column("customer_phone", sa.String(), nullable=True),
    )
    op.create_index(
        "ix_orders_customer_phone",
        "orders",
        ["customer_phone"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_orders_customer_phone", table_name="orders")
    op.drop_column("orders", "customer_phone")
