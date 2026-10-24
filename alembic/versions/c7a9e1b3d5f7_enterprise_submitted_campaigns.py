"""let enterprises submit notification campaigns for admin review

Revision ID: c7a9e1b3d5f7
Revises: d8f0b2c4e6a1
Create Date: 2026-10-24 13:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "c7a9e1b3d5f7"
down_revision = "d8f0b2c4e6a1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "notification_campaigns",
        sa.Column("created_by_enterprise_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "notification_campaigns",
        sa.Column("product_id", sa.Integer(), nullable=True),
    )
    op.add_column(
        "notification_campaigns",
        sa.Column("review_note", sa.Text(), nullable=True),
    )
    op.add_column(
        "notification_campaigns",
        sa.Column("reviewed_at", sa.DateTime(), nullable=True),
    )
    op.create_index(
        "ix_notification_campaigns_created_by_enterprise_id",
        "notification_campaigns",
        ["created_by_enterprise_id"],
    )
    if op.get_bind().dialect.name != "sqlite":
        op.create_foreign_key(
            "fk_notification_campaigns_created_by_enterprise_id",
            "notification_campaigns",
            "enterprises",
            ["created_by_enterprise_id"],
            ["id"],
            ondelete="SET NULL",
        )
        op.create_foreign_key(
            "fk_notification_campaigns_product_id",
            "notification_campaigns",
            "enterprise_products",
            ["product_id"],
            ["id"],
            ondelete="SET NULL",
        )


def downgrade() -> None:
    if op.get_bind().dialect.name != "sqlite":
        op.drop_constraint(
            "fk_notification_campaigns_product_id",
            "notification_campaigns",
            type_="foreignkey",
        )
        op.drop_constraint(
            "fk_notification_campaigns_created_by_enterprise_id",
            "notification_campaigns",
            type_="foreignkey",
        )
    op.drop_index(
        "ix_notification_campaigns_created_by_enterprise_id",
        table_name="notification_campaigns",
    )
    op.drop_column("notification_campaigns", "reviewed_at")
    op.drop_column("notification_campaigns", "review_note")
    op.drop_column("notification_campaigns", "product_id")
    op.drop_column("notification_campaigns", "created_by_enterprise_id")
