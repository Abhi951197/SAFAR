from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.api.deps import get_current_user, get_db
from app.models.diary_entry import DiaryEntry, EntryMedia
from app.models.user import User
from app.schemas.diary_entry import DiaryEntryCreate, DiaryEntryRead, DiaryEntryUpdate, EntryMediaWrite

router = APIRouter()


def _get_entry_or_404(db: Session, entry_id: UUID, user_id: UUID) -> DiaryEntry:
    entry = db.scalar(
        select(DiaryEntry)
        .options(selectinload(DiaryEntry.media))
        .where(DiaryEntry.id == entry_id, DiaryEntry.user_id == user_id)
    )
    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Diary entry not found")
    return entry


def _validate_media(media: list[EntryMediaWrite]) -> None:
    counts = {"image": 0, "video": 0, "audio": 0}
    for item in media:
        counts[item.media_type] += 1
    if counts["image"] > 10:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You can attach up to 10 images")
    if counts["video"] > 3:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You can attach up to 3 videos")
    if counts["audio"] > 1:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You can attach 1 audio clip")


def _media_from_legacy(payload: DiaryEntryCreate | DiaryEntryUpdate) -> list[EntryMediaWrite]:
    media = list(payload.media or []) if getattr(payload, "media", None) is not None else []
    existing_types = {item.media_type for item in media}
    next_order = len(media)
    if "image" not in existing_types and getattr(payload, "image_url", None):
        media.append(EntryMediaWrite(media_type="image", url=payload.image_url, public_id=payload.image_public_id, sort_order=0))
        next_order += 1
    if "video" not in existing_types and getattr(payload, "video_url", None):
        media.append(EntryMediaWrite(media_type="video", url=payload.video_url, public_id=payload.video_public_id, sort_order=next_order))
        next_order += 1
    if "audio" not in existing_types and getattr(payload, "audio_url", None):
        media.append(EntryMediaWrite(media_type="audio", url=payload.audio_url, public_id=payload.audio_public_id, sort_order=next_order))
    return media


def _replace_media(entry: DiaryEntry, media: list[EntryMediaWrite]) -> None:
    _validate_media(media)
    entry.media.clear()
    for index, item in enumerate(media):
        entry.media.append(
            EntryMedia(
                media_type=item.media_type,
                url=item.url,
                public_id=item.public_id,
                sort_order=item.sort_order if item.sort_order != 0 else index,
            )
        )


def _sync_legacy_media_fields(entry: DiaryEntry) -> None:
    images = [item for item in entry.media if item.media_type == "image"]
    videos = [item for item in entry.media if item.media_type == "video"]
    audios = [item for item in entry.media if item.media_type == "audio"]
    entry.image_url = images[0].url if images else None
    entry.image_public_id = images[0].public_id if images else None
    entry.video_url = videos[0].url if videos else None
    entry.video_public_id = videos[0].public_id if videos else None
    entry.audio_url = audios[0].url if audios else None
    entry.audio_public_id = audios[0].public_id if audios else None


@router.get("", response_model=list[DiaryEntryRead])
def list_entries(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    entry_type: str | None = Query(default=None, pattern="^(full|quick)$"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[DiaryEntry]:
    query = select(DiaryEntry).options(selectinload(DiaryEntry.media)).where(DiaryEntry.user_id == current_user.id)
    if start_date:
        query = query.where(DiaryEntry.entry_date >= start_date)
    if end_date:
        query = query.where(DiaryEntry.entry_date <= end_date)
    if entry_type:
        query = query.where(DiaryEntry.entry_type == entry_type)
    query = query.order_by(DiaryEntry.entry_date.desc(), DiaryEntry.created_at.desc())
    return list(db.scalars(query).all())


@router.post("", response_model=DiaryEntryRead, status_code=status.HTTP_201_CREATED)
def create_entry(
    payload: DiaryEntryCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> DiaryEntry:
    media = _media_from_legacy(payload)
    entry_data = payload.model_dump(exclude={"media"})
    entry = DiaryEntry(user_id=current_user.id, **entry_data)
    _replace_media(entry, media)
    _sync_legacy_media_fields(entry)
    db.add(entry)
    db.commit()
    db.refresh(entry)
    return entry


@router.get("/{entry_id}", response_model=DiaryEntryRead)
def read_entry(
    entry_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> DiaryEntry:
    return _get_entry_or_404(db, entry_id, current_user.id)


@router.put("/{entry_id}", response_model=DiaryEntryRead)
def update_entry(
    entry_id: UUID,
    payload: DiaryEntryUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> DiaryEntry:
    entry = _get_entry_or_404(db, entry_id, current_user.id)
    payload_data = payload.model_dump(exclude_unset=True, exclude={"media"})
    for key, value in payload_data.items():
        setattr(entry, key, value)
    if payload.media is not None:
        for media_item in list(entry.media):
            db.delete(media_item)
        db.flush()
        entry.media = []
        _replace_media(entry, payload.media)
        _sync_legacy_media_fields(entry)
    db.commit()
    db.refresh(entry)
    return entry


@router.delete("/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_entry(
    entry_id: UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> None:
    entry = _get_entry_or_404(db, entry_id, current_user.id)
    db.delete(entry)
    db.commit()
