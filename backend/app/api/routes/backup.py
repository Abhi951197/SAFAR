from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, get_db
from app.core.config import settings
from app.models.backup import BackupSnapshot
from app.models.user import User
from app.services.backups import export_user

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
