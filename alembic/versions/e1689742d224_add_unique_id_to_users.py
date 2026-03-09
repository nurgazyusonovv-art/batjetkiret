"""add_unique_id_to_users

Revision ID: e1689742d224
Revises: 3f2a6c1b9d4e
Create Date: 2026-03-07 23:08:18.401149

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e1689742d224'
down_revision: Union[str, Sequence[str], None] = '3f2a6c1b9d4e'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Add unique_id column to users table
    op.add_column('users', sa.Column('unique_id', sa.String(), nullable=True))
    op.create_index(op.f('ix_users_unique_id'), 'users', ['unique_id'], unique=True)


def downgrade() -> None:
    """Downgrade schema."""
    # Remove unique_id column from users table
    op.drop_index(op.f('ix_users_unique_id'), table_name='users')
    op.drop_column('users', 'unique_id')
