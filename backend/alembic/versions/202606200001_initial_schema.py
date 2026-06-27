"""initial schema

Revision ID: 202606200001
Revises:
Create Date: 2026-06-20
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

revision: str = "202606200001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("auth_user_id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.Text(), nullable=True),
        sa.Column("email", sa.Text(), nullable=False),
        sa.Column("avatar_url", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("auth_user_id"),
        sa.UniqueConstraint("email"),
    )
    op.create_index("ix_users_auth_user_id", "users", ["auth_user_id"])

    op.create_table(
        "diary_entries",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("title", sa.Text(), nullable=False),
        sa.Column("content", sa.Text(), nullable=True),
        sa.Column("entry_type", sa.Text(), nullable=False),
        sa.Column("mood", sa.Text(), nullable=True),
        sa.Column("energy", sa.Integer(), nullable=True),
        sa.Column("best_moment", sa.Text(), nullable=True),
        sa.Column("challenge", sa.Text(), nullable=True),
        sa.Column("image_url", sa.Text(), nullable=True),
        sa.Column("image_public_id", sa.Text(), nullable=True),
        sa.Column("entry_date", sa.Date(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=False),
        sa.CheckConstraint("entry_type in ('full', 'quick')", name="ck_diary_entries_entry_type"),
        sa.CheckConstraint("energy is null or (energy >= 1 and energy <= 10)", name="ck_diary_entries_energy"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_diary_entries_user_id", "diary_entries", ["user_id"])
    op.create_index("ix_diary_entries_user_entry_date", "diary_entries", ["user_id", "entry_date"])
    op.create_index("ix_diary_entries_user_created_at", "diary_entries", ["user_id", sa.text("created_at DESC")])


def downgrade() -> None:
    op.drop_index("ix_diary_entries_user_created_at", table_name="diary_entries")
    op.drop_index("ix_diary_entries_user_entry_date", table_name="diary_entries")
    op.drop_index("ix_diary_entries_user_id", table_name="diary_entries")
    op.drop_table("diary_entries")
    op.drop_index("ix_users_auth_user_id", table_name="users")
    op.drop_table("users")
