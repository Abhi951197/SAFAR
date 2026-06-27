from datetime import date
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.models.diary_entry import DiaryEntry
from app.models.user import User
from app.schemas.diary_entry import DiaryEntryCreate, DiaryEntryRead, DiaryEntryUpdate

router = APIRouter()


def _get_entry_or_404(db: Session, entry_id: UUID, user_id: UUID) -> DiaryEntry:
    entry = db.scalar(select(DiaryEntry).where(DiaryEntry.id == entry_id, DiaryEntry.user_id == user_id))
    if entry is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Diary entry not found")
    return entry


@router.get("", response_model=list[DiaryEntryRead])
def list_entries(
    start_date: date | None = Query(default=None),
    end_date: date | None = Query(default=None),
    entry_type: str | None = Query(default=None, pattern="^(full|quick)$"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> list[DiaryEntry]:
    query = select(DiaryEntry).where(DiaryEntry.user_id == current_user.id)
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
    entry = DiaryEntry(user_id=current_user.id, **payload.model_dump())
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
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(entry, key, value)
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
