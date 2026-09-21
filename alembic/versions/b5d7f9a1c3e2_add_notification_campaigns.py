"""add notification campaigns

Revision ID: b5d7f9a1c3e2
Revises: a1c3e5f7b9d2
Create Date: 2026-09-21 12:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "b5d7f9a1c3e2"
down_revision = "a1c3e5f7b9d2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "notification_campaigns",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("message", sa.String(), nullable=False),
        sa.Column("image_url", sa.String(), nullable=True),
        sa.Column("enterprise_id", sa.Integer(), nullable=True),
        sa.Column("notification_type", sa.String(), nullable=True),
        sa.Column("scheduled_at", sa.DateTime(), nullable=True),
        sa.Column("status", sa.String(), nullable=False, server_default="scheduled"),
        sa.Column("sent_at", sa.DateTime(), nullable=True),
        sa.Column("sent_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("pushed_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("error", sa.Text(), nullable=True),
        sa.Column("created_by_admin_id", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now()),
    )
    op.create_index(
        "ix_notification_campaigns_due",
        "notification_campaigns",
        ["status", "scheduled_at"],
    )
    if op.get_bind().dialect.name != "sqlite":
        op.create_foreign_key(
            "fk_notification_campaigns_enterprise_id",
            "notification_campaigns",
            "enterprises",
            ["enterprise_id"],
            ["id"],
            ondelete="SET NULL",
        )


def downgrade() -> None:
    if op.get_bind().dialect.name != "sqlite":
        op.drop_constraint(
            "fk_notification_campaigns_enterprise_id",
            "notification_campaigns",
            type_="foreignkey",
        )
    op.drop_index("ix_notification_campaigns_due", table_name="notification_campaigns")
    op.drop_table("notification_campaigns")
