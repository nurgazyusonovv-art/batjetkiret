"""add attempt_count to password_resets (brute-force lockout)

Revision ID: c3e1a7b42f90
Revises: b7d2e9f4a1c8
Create Date: 2026-06-24 15:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "c3e1a7b42f90"
down_revision: Union[str, Sequence[str], None] = "b7d2e9f4a1c8"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _has_column(bind, table: str, column: str) -> bool:
    insp = sa.inspect(bind)
    return column in {c["name"] for c in insp.get_columns(table)}


def upgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name

    if dialect == "postgresql":
        op.execute(
            "ALTER TABLE password_resets "
            "ADD COLUMN IF NOT EXISTS attempt_count INTEGER NOT NULL DEFAULT 0"
        )
    elif not _has_column(bind, "password_resets", "attempt_count"):
        op.add_column(
            "password_resets",
            sa.Column(
                "attempt_count",
                sa.Integer(),
                nullable=False,
                server_default="0",
            ),
        )


def downgrade() -> None:
    bind = op.get_bind()
    dialect = bind.dialect.name

    if dialect == "postgresql":
        op.execute("ALTER TABLE password_resets DROP COLUMN IF EXISTS attempt_count")
    elif _has_column(bind, "password_resets", "attempt_count"):
        op.drop_column("password_resets", "attempt_count")
