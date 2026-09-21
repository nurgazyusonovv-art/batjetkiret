"""add image, enterprise and type to notifications

Revision ID: a1c3e5f7b9d2
Revises: f9a1b3c5d7e9
Create Date: 2026-09-21 10:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "a1c3e5f7b9d2"
down_revision = "f9a1b3c5d7e9"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("notifications", sa.Column("image_url", sa.String(), nullable=True))
    op.add_column("notifications", sa.Column("enterprise_id", sa.Integer(), nullable=True))
    op.add_column("notifications", sa.Column("notification_type", sa.String(), nullable=True))
    # SQLite cannot ALTER TABLE ADD CONSTRAINT; the column works without the
    # constraint there, and production (PostgreSQL) still gets it.
    if op.get_bind().dialect.name != "sqlite":
        op.create_foreign_key(
            "fk_notifications_enterprise_id",
            "notifications",
            "enterprises",
            ["enterprise_id"],
            ["id"],
            ondelete="SET NULL",
        )


def downgrade() -> None:
    if op.get_bind().dialect.name != "sqlite":
        op.drop_constraint(
            "fk_notifications_enterprise_id", "notifications", type_="foreignkey"
        )
    op.drop_column("notifications", "notification_type")
    op.drop_column("notifications", "enterprise_id")
    op.drop_column("notifications", "image_url")
