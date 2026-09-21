"""add courier vehicle details

Revision ID: f9a1b3c5d7e9
Revises: e8f0a2b4c6d8
Create Date: 2026-07-31 12:30:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "f9a1b3c5d7e9"
down_revision = "e8f0a2b4c6d8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column("courier_vehicle_brand", sa.String(), nullable=True),
    )
    op.add_column(
        "users",
        sa.Column("courier_vehicle_color", sa.String(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "courier_vehicle_color")
    op.drop_column("users", "courier_vehicle_brand")
