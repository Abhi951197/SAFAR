from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.core.config import settings
from app.models.backup import BackupSnapshot
from app.models.user import User
from app.models.diary_entry import DiaryEntry
from app.services.backups import export_user
from app.services.recovery import RecoveryArchive, restore_archive

router = APIRouter()


@router.get("/status")
def backup_status(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    own = BackupSnapshot.auth_user_id == user.auth_user_id
    pending = db.scalar(select(func.count()).select_from(BackupSnapshot)
                        .where(own, BackupSnapshot.uploaded_at.is_(None)))
    last = db.scalar(select(func.max(BackupSnapshot.uploaded_at)).where(own))
    return {
        "enabled": settings.safar_backup_enabled,
        "pending_snapshots": pending,
        "last_verified_backup_at": last,
        "coverage": "Diary text and media metadata; attachment bytes and device encryption keys excluded.",
    }


@router.get("/export")
def export_diaries(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    return export_user(db, user)


@router.post("/restore")
def restore_diaries(archive: RecoveryArchive, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    if archive.user.auth_user_id != user.auth_user_id:
        raise HTTPException(403, "Sign in to the same Safar account that created this backup")
    if len(archive.entries) > 5000:
        raise HTTPException(413, "Restore at most 5000 entries at a time")
    try:
        inserted = restore_archive(db, archive.model_dump_json().encode(), explicit_restore=True)
        db.commit()
    except ValueError:
        db.rollback()
        raise HTTPException(422, "Backup could not be restored; no diary records were changed") from None
    total = db.scalar(select(func.count()).select_from(DiaryEntry)
                      .where(DiaryEntry.user_id == user.id))
    return {"inserted": inserted, "total": total}
