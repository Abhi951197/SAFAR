"""create entry media table

Revision ID: 202606270002
Revises: 202606270001
Create Date: 2026-06-27
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "202606270002"
down_revision: str | None = "202606270001"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "entry_media",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("entry_id", sa.Uuid(), nullable=False),
        sa.Column("media_type", sa.Text(), nullable=False),
        sa.Column("url", sa.Text(), nullable=False),
        sa.Column("public_id", sa.Text(), nullable=True),
        sa.Column("sort_order", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint("media_type in ('image', 'video', 'audio')", name="ck_entry_media_media_type"),
        sa.ForeignKeyConstraint(["entry_id"], ["diary_entries.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("entry_id", "sort_order", name="uq_entry_media_entry_sort_order"),
    )
    op.create_index("ix_entry_media_entry_id", "entry_media", ["entry_id"])

    op.execute(
        """
        insert into entry_media (id, entry_id, media_type, url, public_id, sort_order, created_at)
        select gen_random_uuid(), id, 'image', image_url, image_public_id, 0, now()
        from diary_entries
        where image_url is not null
        """
    )
    op.execute(
        """
        insert into entry_media (id, entry_id, media_type, url, public_id, sort_order, created_at)
        select gen_random_uuid(), id, 'video', video_url, video_public_id, 1, now()
        from diary_entries
        where video_url is not null
        """
    )
    op.execute(
        """
        insert into entry_media (id, entry_id, media_type, url, public_id, sort_order, created_at)
        select gen_random_uuid(), id, 'audio', audio_url, audio_public_id, 2, now()
        from diary_entries
        where audio_url is not null
        """
    )


def downgrade() -> None:
    op.drop_index("ix_entry_media_entry_id", table_name="entry_media")
    op.drop_table("entry_media")
