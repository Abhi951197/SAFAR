"""Durable backup outbox and one-time recovery receipts."""
from alembic import op
import sqlalchemy as sa

revision = "202610230001"
down_revision = "202607050001"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "safar_backup_snapshots",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("auth_user_id", sa.Uuid(), nullable=False),
        sa.Column("payload", sa.JSON(), nullable=True),
        sa.Column("sha256", sa.String(64), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("uploaded_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("attempts", sa.Integer(), server_default="0", nullable=False),
        sa.Column("last_error", sa.Text(), nullable=True),
    )
    op.create_index("ix_safar_backup_snapshots_auth_user_id", "safar_backup_snapshots", ["auth_user_id"])
    op.create_index("ix_safar_backup_pending", "safar_backup_snapshots", ["created_at"],
                    postgresql_where=sa.text("uploaded_at IS NULL"))
    op.create_table(
        "safar_recovery_runs",
        sa.Column("sha256", sa.String(64), primary_key=True),
        sa.Column("inserted_entries", sa.Integer(), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    # Safe if the backend later moves back to a Supabase database: server-only tables.
    op.execute("ALTER TABLE safar_backup_snapshots ENABLE ROW LEVEL SECURITY")
    op.execute("ALTER TABLE safar_recovery_runs ENABLE ROW LEVEL SECURITY")


def downgrade():
    op.drop_table("safar_recovery_runs")
    op.drop_table("safar_backup_snapshots")
