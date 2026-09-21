"""add user advertisements

Revision ID: f4d9a2c8b6e1
Revises: c3e1a7b42f90
Create Date: 2026-07-13 16:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "f4d9a2c8b6e1"
down_revision = "c3e1a7b42f90"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "advertisements",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(length=120), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("category", sa.String(length=80), nullable=True),
        sa.Column("contact_phone", sa.String(length=32), nullable=True),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="PENDING"),
        sa.Column("duration_days", sa.Integer(), nullable=False, server_default="7"),
        sa.Column("fee_amount", sa.Numeric(10, 2), nullable=False, server_default="0"),
        sa.Column("rejection_reason", sa.Text(), nullable=True),
        sa.Column("approved_by_admin_id", sa.Integer(), nullable=True),
        sa.Column("approved_at", sa.DateTime(), nullable=True),
        sa.Column("starts_at", sa.DateTime(), nullable=True),
        sa.Column("expires_at", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), server_default=sa.func.now(), nullable=True),
        sa.ForeignKeyConstraint(["approved_by_admin_id"], ["users.id"]),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_advertisements_id"), "advertisements", ["id"], unique=False)
    op.create_index("ix_advertisements_user_status", "advertisements", ["user_id", "status"], unique=False)
    op.create_index("ix_advertisements_status_expires", "advertisements", ["status", "expires_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_advertisements_status_expires", table_name="advertisements")
    op.drop_index("ix_advertisements_user_status", table_name="advertisements")
    op.drop_index(op.f("ix_advertisements_id"), table_name="advertisements")
    op.drop_table("advertisements")
