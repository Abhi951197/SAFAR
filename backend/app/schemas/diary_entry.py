from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


class EntryMediaWrite(BaseModel):
    media_type: Literal["image", "video", "audio"]
    url: str
    public_id: str | None = None
    sort_order: int = Field(default=0, ge=0)
    encrypted: bool = False
    encryption_nonce: str | None = None
    encryption_version: int | None = None
    content_type: str | None = None
    size_bytes: int | None = Field(default=None, ge=0)


class EntryMediaRead(EntryMediaWrite):
    id: UUID
    entry_id: UUID
    created_at: datetime

    model_config = {"from_attributes": True}


class EntryReferenceWrite(BaseModel):
    id: UUID | None = None
    target_entry_id: UUID | None = None
    note: str | None = Field(default=None, max_length=240)


class EntryReferenceRead(BaseModel):
    id: UUID
    entry_id: UUID
    target_entry_id: UUID | None
    target_title: str
    target_date: date
    note: str | None = None
    model_config = {"from_attributes": True}


class DiaryEntryBase(BaseModel):
    title: str = Field(min_length=1, max_length=160)
    content: str | None = None
    entry_type: Literal["full", "quick"]
    mood: str | None = None
    energy: int | None = Field(default=None, ge=1, le=10)
    best_moment: str | None = None
    challenge: str | None = None
    image_url: str | None = None
    image_public_id: str | None = None
    video_url: str | None = None
    video_public_id: str | None = None
    audio_url: str | None = None
    audio_public_id: str | None = None
    media: list[EntryMediaWrite] = Field(default_factory=list)
    entry_date: date

    @model_validator(mode="after")
    def validate_entry_kind(self) -> "DiaryEntryBase":
        if self.entry_type == "full" and not self.content:
            raise ValueError("Full diary entries require content")
        if self.entry_type == "quick" and not self.mood:
            raise ValueError("Quick diary entries require mood")
        return self


class DiaryEntryCreate(DiaryEntryBase):
    references: list[EntryReferenceWrite] = Field(default_factory=list, max_length=20)


class DiaryEntryUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=160)
    content: str | None = None
    entry_type: Literal["full", "quick"] | None = None
    mood: str | None = None
    energy: int | None = Field(default=None, ge=1, le=10)
    best_moment: str | None = None
    challenge: str | None = None
    image_url: str | None = None
    image_public_id: str | None = None
    video_url: str | None = None
    video_public_id: str | None = None
    audio_url: str | None = None
    audio_public_id: str | None = None
    media: list[EntryMediaWrite] | None = None
    entry_date: date | None = None
    references: list[EntryReferenceWrite] | None = Field(default=None, max_length=20)


class DiaryEntryRead(DiaryEntryBase):
    id: UUID
    user_id: UUID
    created_at: datetime
    updated_at: datetime
    media: list[EntryMediaRead] = Field(default_factory=list)
    references: list[EntryReferenceRead] = Field(default_factory=list)

    model_config = {"from_attributes": True}
