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
    op.execute(
        "CREATE TABLE IF NOT EXISTS topup_requests ("
        "id SERIAL PRIMARY KEY, "
        "user_id INTEGER REFERENCES users(id), "
        "unique_id VARCHAR, "
        "telegram_user_id INTEGER, "
        "telegram_username VARCHAR, "
        "screenshot_file_id VARCHAR, "
        "screenshot_url VARCHAR, "
        "screenshot_hash VARCHAR, "
        "amount NUMERIC(10, 2), "
        "approved_amount NUMERIC(10, 2), "
        "status VARCHAR DEFAULT 'PENDING', "
        "admin_note VARCHAR, "
        "approved_by_admin_id INTEGER REFERENCES users(id), "
        "approved_at TIMESTAMP, "
        "expires_at TIMESTAMP, "
        "created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)"
    )
    op.execute("ALTER TABLE topup_requests ADD COLUMN IF NOT EXISTS unique_id VARCHAR")
    op.execute("ALTER TABLE topup_requests ADD COLUMN IF NOT EXISTS telegram_user_id INTEGER")
    op.execute("ALTER TABLE topup_requests ADD COLUMN IF NOT EXISTS telegram_username VARCHAR")
    op.execute("ALTER TABLE topup_requests ADD COLUMN IF NOT EXISTS screenshot_file_id VARCHAR")
    op.execute("ALTER TABLE topup_requests ADD COLUMN IF NOT EXISTS screenshot_url VARCHAR")
    op.execute("ALTER TABLE topup_requests ADD COLUMN IF NOT EXISTS screenshot_hash VARCHAR")
    op.execute("ALTER TABLE topup_requests ADD COLUMN IF NOT EXISTS amount NUMERIC(10, 2)")
    op.execute("ALTER TABLE topup_requests ADD COLUMN IF NOT EXISTS approved_amount NUMERIC(10, 2)")
    op.execute("ALTER TABLE topup_requests ADD COLUMN IF NOT EXISTS expires_at TIMESTAMP")
    op.execute("CREATE INDEX IF NOT EXISTS ix_topup_requests_id ON topup_requests (id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_topup_requests_unique_id ON topup_requests (unique_id)")
    op.execute("CREATE INDEX IF NOT EXISTS ix_topup_requests_screenshot_hash ON topup_requests (screenshot_hash)")


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
