"""add courier transport to users

Revision ID: e8f0a2b4c6d8
Revises: d7e9f1a3b5c7
Create Date: 2026-07-31 11:30:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "e8f0a2b4c6d8"
down_revision = "d7e9f1a3b5c7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users",
        sa.Column(
            "courier_transport",
            sa.String(),
            server_default="walking",
            nullable=False,
        ),
    )
    op.add_column(
        "users",
        sa.Column("courier_vehicle_plate", sa.String(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("users", "courier_vehicle_plate")
    op.drop_column("users", "courier_transport")
