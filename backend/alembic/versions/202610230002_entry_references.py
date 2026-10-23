"""Links between a user's diary entries."""
from alembic import op
import sqlalchemy as sa

revision = "202610230002"
down_revision = "202610230001"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table("entry_references",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("entry_id", sa.Uuid(), sa.ForeignKey("diary_entries.id", ondelete="CASCADE"), nullable=False),
        sa.Column("target_entry_id", sa.Uuid(), sa.ForeignKey("diary_entries.id", ondelete="SET NULL"), nullable=True),
        sa.Column("target_title", sa.Text(), nullable=False),
        sa.Column("target_date", sa.Date(), nullable=False),
        sa.Column("note", sa.Text(), nullable=True))
    op.create_index("ix_entry_references_entry_id", "entry_references", ["entry_id"])
    op.create_index("ix_entry_references_target_entry_id", "entry_references", ["target_entry_id"])
    op.execute("ALTER TABLE entry_references ENABLE ROW LEVEL SECURITY")


def downgrade():
    op.drop_table("entry_references")
