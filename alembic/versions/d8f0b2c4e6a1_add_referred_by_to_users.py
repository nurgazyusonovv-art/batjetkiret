"""add referred_by_user_id to users

Revision ID: d8f0b2c4e6a1
Revises: c6e8a0b2d4f3
Create Date: 2026-09-22 12:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "d8f0b2c4e6a1"
down_revision = "c6e8a0b2d4f3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "users", sa.Column("referred_by_user_id", sa.Integer(), nullable=True)
    )
    op.create_index(
        "ix_users_referred_by_user_id", "users", ["referred_by_user_id"]
    )
    if op.get_bind().dialect.name != "sqlite":
        op.create_foreign_key(
            "fk_users_referred_by_user_id",
            "users",
            "users",
            ["referred_by_user_id"],
            ["id"],
            ondelete="SET NULL",
        )


def downgrade() -> None:
    if op.get_bind().dialect.name != "sqlite":
        op.drop_constraint("fk_users_referred_by_user_id", "users", type_="foreignkey")
    op.drop_index("ix_users_referred_by_user_id", table_name="users")
    op.drop_column("users", "referred_by_user_id")
