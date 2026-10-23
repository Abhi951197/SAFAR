import uuid
from datetime import datetime

from sqlalchemy import DateTime, Integer, JSON, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class BackupSnapshot(Base):
    __tablename__ = "safar_backup_snapshots"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # No FK: deleting an application user must not cascade into their backups.
    auth_user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), index=True)
    payload: Mapped[dict | None] = mapped_column(JSON)
    sha256: Mapped[str] = mapped_column(String(64))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    uploaded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    last_error: Mapped[str | None] = mapped_column(Text)


class RecoveryRun(Base):
    __tablename__ = "safar_recovery_runs"

    sha256: Mapped[str] = mapped_column(String(64), primary_key=True)
    inserted_entries: Mapped[int] = mapped_column(Integer)
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
