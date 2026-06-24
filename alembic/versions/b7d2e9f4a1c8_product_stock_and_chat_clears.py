"""product stock column and chat_clears table

Revision ID: b7d2e9f4a1c8
Revises: 8c6b8f0f5a91
Create Date: 2026-06-24 13:00:00.000000

"""
from typing import Sequence, Union

from alembic import op


revision: str = "b7d2e9f4a1c8"
down_revision: Union[str, Sequence[str], None] = "8c6b8f0f5a91"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name

    if dialect == "postgresql":
        # Enterprise product stock (default 10 for existing rows).
        op.execute(
            "ALTER TABLE enterprise_products ADD COLUMN IF NOT EXISTS stock INTEGER NOT NULL DEFAULT 10"
        )
        # Per-user "clear chat" markers.
        op.execute(
            "CREATE TABLE IF NOT EXISTS chat_clears ("
            "id SERIAL PRIMARY KEY, "
            "chat_id INTEGER NOT NULL, "
            "user_id INTEGER NOT NULL, "
            "cleared_message_id INTEGER NOT NULL DEFAULT 0, "
            "UNIQUE(chat_id, user_id))"
        )
        op.execute(
            "CREATE INDEX IF NOT EXISTS ix_chat_clears_chat_id ON chat_clears (chat_id)"
        )
        op.execute(
            "CREATE INDEX IF NOT EXISTS ix_chat_clears_user_id ON chat_clears (user_id)"
        )


def downgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name

    if dialect == "postgresql":
        op.execute("DROP TABLE IF EXISTS chat_clears")
        op.execute("ALTER TABLE enterprise_products DROP COLUMN IF EXISTS stock")
