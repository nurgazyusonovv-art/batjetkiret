"""update_topup_requests_for_telegram_bot

Revision ID: 73408a22c33c
Revises: e1689742d224
Create Date: 2026-03-07 23:16:17.630720

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '73408a22c33c'
down_revision: Union[str, Sequence[str], None] = 'e1689742d224'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Drop old topup_requests table and create new one with Telegram bot fields
    op.drop_table('topup_requests')
    
    op.create_table(
        'topup_requests',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=True),
        sa.Column('unique_id', sa.String(), nullable=False),
        sa.Column('telegram_user_id', sa.Integer(), nullable=False),
        sa.Column('telegram_username', sa.String(), nullable=True),
        sa.Column('screenshot_file_id', sa.String(), nullable=False),
        sa.Column('amount', sa.Numeric(10, 2), nullable=False),
        sa.Column('status', sa.String(), server_default='PENDING', nullable=True),
        sa.Column('admin_note', sa.String(), nullable=True),
        sa.Column('approved_by_admin_id', sa.Integer(), nullable=True),
        sa.Column('approved_at', sa.DateTime(), nullable=True),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.ForeignKeyConstraint(['approved_by_admin_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_topup_requests_id'), 'topup_requests', ['id'], unique=False)
    op.create_index(op.f('ix_topup_requests_unique_id'), 'topup_requests', ['unique_id'], unique=False)


def downgrade() -> None:
    """Downgrade schema."""
    # Restore old topup_requests table structure
    op.drop_index(op.f('ix_topup_requests_unique_id'), table_name='topup_requests')
    op.drop_index(op.f('ix_topup_requests_id'), table_name='topup_requests')
    op.drop_table('topup_requests')
    
    # Recreate old structure (optional, depending on needs)
    op.create_table(
        'topup_requests',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('requested_amount', sa.Numeric(10, 2), nullable=False),
        sa.Column('approved_amount', sa.Numeric(10, 2), nullable=True),
        sa.Column('screenshot_url', sa.String(), nullable=False),
        sa.Column('screenshot_hash', sa.String(), nullable=False),
        sa.Column('status', sa.String(), server_default='PENDING', nullable=True),
        sa.Column('admin_note', sa.String(), nullable=True),
        sa.Column('approved_by_admin_id', sa.Integer(), nullable=True),
        sa.Column('approved_at', sa.DateTime(), nullable=True),
        sa.Column('expires_at', sa.DateTime(), nullable=False),
        sa.Column('created_at', sa.DateTime(), server_default=sa.text('(CURRENT_TIMESTAMP)'), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.ForeignKeyConstraint(['approved_by_admin_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('screenshot_hash')
    )
    op.create_index(op.f('ix_topup_requests_id'), 'topup_requests', ['id'], unique=False)
