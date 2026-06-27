"""add entry media fields

Revision ID: 202606270001
Revises: 202606200001
Create Date: 2026-06-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202606270001"
down_revision: str | None = "202606200001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("diary_entries", sa.Column("video_url", sa.Text(), nullable=True))
    op.add_column("diary_entries", sa.Column("video_public_id", sa.Text(), nullable=True))
    op.add_column("diary_entries", sa.Column("audio_url", sa.Text(), nullable=True))
    op.add_column("diary_entries", sa.Column("audio_public_id", sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column("diary_entries", "audio_public_id")
    op.drop_column("diary_entries", "audio_url")
    op.drop_column("diary_entries", "video_public_id")
    op.drop_column("diary_entries", "video_url")
