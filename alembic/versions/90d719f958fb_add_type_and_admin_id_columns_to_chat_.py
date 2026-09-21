"""Add type and admin_id columns to chat_rooms table

Revision ID: 90d719f958fb
Revises: 
Create Date: 2026-03-03 18:52:05.689581

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '90d719f958fb'
down_revision: Union[str, Sequence[str], None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema: Add type and admin_id columns to chat_rooms."""
    op.execute("ALTER TABLE chat_rooms ADD COLUMN IF NOT EXISTS type VARCHAR")
    op.execute("UPDATE chat_rooms SET type = 'ORDER' WHERE type IS NULL")
    op.execute("ALTER TABLE chat_rooms ALTER COLUMN type SET NOT NULL")
    op.execute("ALTER TABLE chat_rooms ADD COLUMN IF NOT EXISTS admin_id INTEGER")


def downgrade() -> None:
    """Downgrade schema: Remove type and admin_id columns from chat_rooms."""
    # Drop admin_id column first (no dependencies)
    op.drop_column('chat_rooms', 'admin_id')
    
    # Drop type column last
    op.drop_column('chat_rooms', 'type')
