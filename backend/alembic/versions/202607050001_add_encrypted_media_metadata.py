"""add encrypted media metadata

Revision ID: 202607050001
Revises: 202606270002
Create Date: 2026-07-05
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202607050001"
down_revision: str | None = "202606270002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "entry_media",
        sa.Column("encrypted", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.add_column("entry_media", sa.Column("encryption_nonce", sa.Text(), nullable=True))
    op.add_column("entry_media", sa.Column("encryption_version", sa.Integer(), nullable=True))
    op.add_column("entry_media", sa.Column("content_type", sa.Text(), nullable=True))
    op.add_column("entry_media", sa.Column("size_bytes", sa.Integer(), nullable=True))


def downgrade() -> None:
    op.drop_column("entry_media", "size_bytes")
    op.drop_column("entry_media", "content_type")
    op.drop_column("entry_media", "encryption_version")
    op.drop_column("entry_media", "encryption_nonce")
    op.drop_column("entry_media", "encrypted")
