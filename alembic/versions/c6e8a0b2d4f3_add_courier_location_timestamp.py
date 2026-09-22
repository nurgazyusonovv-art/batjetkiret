"""add location_updated_at to users

Revision ID: c6e8a0b2d4f3
Revises: b5d7f9a1c3e2
Create Date: 2026-09-22 09:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "c6e8a0b2d4f3"
down_revision = "b5d7f9a1c3e2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("location_updated_at", sa.DateTime(), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "location_updated_at")
