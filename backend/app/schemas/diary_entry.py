from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


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
    entry_date: date

    @model_validator(mode="after")
    def validate_entry_kind(self) -> "DiaryEntryBase":
        if self.entry_type == "full" and not self.content:
            raise ValueError("Full diary entries require content")
        if self.entry_type == "quick" and not self.mood:
            raise ValueError("Quick diary entries require mood")
        return self


class DiaryEntryCreate(DiaryEntryBase):
    pass


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
    entry_date: date | None = None


class DiaryEntryRead(DiaryEntryBase):
    id: UUID
    user_id: UUID
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
