import uuid
from datetime import date

from sqlalchemy import Date, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class EntryReference(Base):
    __tablename__ = "entry_references"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    entry_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("diary_entries.id", ondelete="CASCADE"), index=True)
    target_entry_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("diary_entries.id", ondelete="SET NULL"), index=True)
    target_title: Mapped[str] = mapped_column(Text)
    target_date: Mapped[date] = mapped_column(Date)
    note: Mapped[str | None] = mapped_column(Text)
