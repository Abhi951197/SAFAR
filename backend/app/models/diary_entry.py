import uuid
from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, Date, DateTime, ForeignKey, Integer, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.user import User


class DiaryEntry(Base):
    __tablename__ = "diary_entries"
    __table_args__ = (
        CheckConstraint("entry_type in ('full', 'quick')", name="ck_diary_entries_entry_type"),
        CheckConstraint("energy is null or (energy >= 1 and energy <= 10)", name="ck_diary_entries_energy"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), index=True)
    title: Mapped[str] = mapped_column(Text)
    content: Mapped[str | None] = mapped_column(Text)
    entry_type: Mapped[str] = mapped_column(Text)
    mood: Mapped[str | None] = mapped_column(Text)
    energy: Mapped[int | None] = mapped_column(Integer)
    best_moment: Mapped[str | None] = mapped_column(Text)
    challenge: Mapped[str | None] = mapped_column(Text)
    image_url: Mapped[str | None] = mapped_column(Text)
    image_public_id: Mapped[str | None] = mapped_column(Text)
    video_url: Mapped[str | None] = mapped_column(Text)
    video_public_id: Mapped[str | None] = mapped_column(Text)
    audio_url: Mapped[str | None] = mapped_column(Text)
    audio_public_id: Mapped[str | None] = mapped_column(Text)
    entry_date: Mapped[date] = mapped_column(Date)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    user: Mapped["User"] = relationship(back_populates="entries")
    media: Mapped[list["EntryMedia"]] = relationship(
        back_populates="entry",
        cascade="all, delete-orphan",
        order_by="EntryMedia.sort_order",
    )


class EntryMedia(Base):
    __tablename__ = "entry_media"
    __table_args__ = (
        CheckConstraint("media_type in ('image', 'video', 'audio')", name="ck_entry_media_media_type"),
        UniqueConstraint("entry_id", "sort_order", name="uq_entry_media_entry_sort_order"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    entry_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("diary_entries.id", ondelete="CASCADE"), index=True)
    media_type: Mapped[str] = mapped_column(Text)
    url: Mapped[str] = mapped_column(Text)
    public_id: Mapped[str | None] = mapped_column(Text)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    entry: Mapped[DiaryEntry] = relationship(back_populates="media")
