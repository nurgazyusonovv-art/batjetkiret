"""add view count to advertisements

Revision ID: a2b4c6d8e0f1
Revises: f4d9a2c8b6e1
Create Date: 2026-07-13 18:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "a2b4c6d8e0f1"
down_revision = "f4d9a2c8b6e1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "advertisements",
        sa.Column("view_count", sa.Integer(), nullable=False, server_default="0"),
    )
    op.alter_column("advertisements", "view_count", server_default=None)


def downgrade() -> None:
    op.drop_column("advertisements", "view_count")
