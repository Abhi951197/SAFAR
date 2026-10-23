"""Explicit, one-time, additive recovery of a user's archived entries."""
import base64
import gzip
import hashlib
import io
import logging
from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app.models.backup import RecoveryRun
from app.models.diary_entry import DiaryEntry, EntryMedia
from app.models.entry_reference import EntryReference
from app.models.user import User
from app.schemas.diary_entry import DiaryEntryRead
from app.services.backups import queue_snapshot

logger = logging.getLogger(__name__)


class ArchivedUser(BaseModel):
    id: UUID
    auth_user_id: UUID
    email: EmailStr
    name: str | None = None
    avatar_url: str | None = None
    created_at: datetime
    updated_at: datetime


class RecoveryArchive(BaseModel):
    archive_version: int = Field(ge=1, le=1)
    user: ArchivedUser
    entries: list[DiaryEntryRead]


def decode_archive(encoded: str) -> bytes:
    if len(encoded) > 2_000_000:
        raise ValueError("Recovery archive is too large")
    compressed = base64.b64decode(encoded, validate=True)
    with gzip.GzipFile(fileobj=io.BytesIO(compressed)) as stream:
        data = stream.read(5_000_001)
    if len(data) > 5_000_000:
        raise ValueError("Expanded recovery archive is too large")
    return data


def restore_archive(db: Session, data: bytes, *, explicit_restore: bool = False) -> int:
    archive = RecoveryArchive.model_validate_json(data)
    digest = hashlib.sha256(data).hexdigest()
    if db.bind.dialect.name == "postgresql":
        db.execute(text("SELECT pg_advisory_xact_lock(1935763058)"))
    completed = db.get(RecoveryRun, digest)
    if completed and not explicit_restore:
        return 0
    ids = [entry.id for entry in archive.entries]
    if len(set(ids)) != len(ids):
        raise ValueError("Duplicate IDs in recovery archive")
    if any(entry.user_id != archive.user.id for entry in archive.entries):
        raise ValueError("Recovery archive contains another user's entries")
    user = db.scalar(select(User).where(User.auth_user_id == archive.user.auth_user_id))
    if user is None:
        email_owner = db.scalar(select(User).where(User.email == archive.user.email))
        if email_owner is not None:
            raise ValueError("Email belongs to a different authentication identity")
        if db.get(User, archive.user.id) is not None:
            raise ValueError("Archived user ID is already in use")
        user = User(**archive.user.model_dump())
        db.add(user)
        db.flush()
    # Save the destination's state before adding anything. Never overwrite it.
    queue_snapshot(db, user, force=True)
    db.flush()
    inserted = 0
    inserted_ids = set()
    for item in archive.entries:
        existing = db.get(DiaryEntry, item.id)
        if existing is not None:
            if existing.user_id != user.id:
                raise ValueError("Diary ID belongs to a different user")
            continue
        entry = DiaryEntry(**item.model_dump(exclude={"media", "user_id", "references"}), user_id=user.id)
        for media in item.media:
            if media.entry_id != item.id:
                raise ValueError("Media points to another entry")
            if db.get(EntryMedia, media.id) is not None:
                raise ValueError("Media ID already exists")
            entry.media.append(EntryMedia(**media.model_dump(exclude={"entry_id"})))
        db.add(entry)
        db.flush()
        inserted += 1
        inserted_ids.add(item.id)
    # Resolve links only after all archived entries exist, preserving existing edits.
    for item in archive.entries:
        if item.id not in inserted_ids:
            continue
        for ref in item.references:
            if ref.entry_id != item.id or ref.target_entry_id == item.id:
                raise ValueError("Invalid archived reference")
            target = db.get(DiaryEntry, ref.target_entry_id) if ref.target_entry_id else None
            if target is not None and target.user_id != user.id:
                raise ValueError("Reference belongs to another account")
            if db.get(EntryReference, ref.id) is not None:
                raise ValueError("Reference ID collision")
            db.add(EntryReference(id=ref.id, entry_id=item.id,
                target_entry_id=target.id if target else None, target_title=ref.target_title,
                target_date=ref.target_date, note=ref.note))
    db.flush()
    queue_snapshot(db, user, force=True)
    if completed is None:
        db.add(RecoveryRun(sha256=digest, inserted_entries=inserted))
    db.flush()
    present = db.scalar(select(func.count()).select_from(DiaryEntry)
                        .where(DiaryEntry.user_id == user.id, DiaryEntry.id.in_(ids)))
    total = db.scalar(select(func.count()).select_from(DiaryEntry).where(DiaryEntry.user_id == user.id))
    if present != len(ids):
        raise ValueError("Recovery verification failed")
    logger.warning("Diary recovery checked: inserted=%d archived=%d present=%d total_user_entries=%d",
                   inserted, len(archive.entries), present, total)
    return inserted
