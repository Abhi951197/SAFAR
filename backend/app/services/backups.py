"""Transactional diary snapshots, copied to private storage outside the primary DB.

Snapshots contain diary text and media metadata/URLs, not attachment bytes or
the device's encryption key. They are not a replacement for device key backup.
"""
import asyncio
import hashlib
import json
import logging
from datetime import datetime, timezone
from uuid import uuid5, NAMESPACE_URL
from urllib.error import HTTPError
from urllib.parse import quote, urlsplit
from urllib.request import Request, build_opener, HTTPRedirectHandler

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.core.config import settings
from app.db.session import SessionLocal
from app.models.backup import BackupSnapshot
from app.models.diary_entry import DiaryEntry
from app.models.user import User
from app.schemas.diary_entry import DiaryEntryRead

logger = logging.getLogger(__name__)


def encode_archive(payload: dict) -> bytes:
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()


def _export_entry(entry: DiaryEntry) -> dict:
    result = DiaryEntryRead.model_validate(entry).model_dump(mode="json")
    # Older versions stored one attachment per type directly on the entry.
    # Include those bytes in personal backups as well as the modern media list.
    existing = {(item["media_type"], item["url"]) for item in result["media"]}
    for kind in ("image", "video", "audio"):
        url = result.get(f"{kind}_url")
        if url and (kind, url) not in existing:
            result["media"].append({"id": str(uuid5(NAMESPACE_URL, f"safar:{entry.id}:{kind}:{url}")),
                "entry_id": str(entry.id), "media_type": kind, "url": url,
                "public_id": result.get(f"{kind}_public_id"), "sort_order": len(result["media"]),
                "encrypted": False, "created_at": result["created_at"]})
    return result


def export_user(db: Session, user: User) -> dict:
    db.flush()
    entries = db.scalars(
        select(DiaryEntry).options(selectinload(DiaryEntry.media), selectinload(DiaryEntry.references))
        .where(DiaryEntry.user_id == user.id).order_by(DiaryEntry.id)
        .execution_options(populate_existing=True)
    ).all()
    return {
        "archive_version": 1,
        "user": {key: str(value) if value is not None else None for key, value in {
            "id": user.id, "auth_user_id": user.auth_user_id, "email": user.email,
            "name": user.name, "avatar_url": user.avatar_url,
            "created_at": user.created_at, "updated_at": user.updated_at,
        }.items()},
        "entries": [_export_entry(entry) for entry in entries],
        "coverage": "diary text and media metadata; attachment bytes and device keys excluded",
    }


def queue_snapshot(db: Session, user: User, *, force: bool = False) -> None:
    if not settings.safar_backup_enabled and not force:
        return
    payload = export_user(db, user)
    digest = hashlib.sha256(encode_archive(payload)).hexdigest()
    latest = db.scalar(select(BackupSnapshot).where(BackupSnapshot.auth_user_id == user.auth_user_id)
                       .order_by(BackupSnapshot.created_at.desc(), BackupSnapshot.id.desc()).limit(1))
    if latest is None or latest.sha256 != digest:
        db.add(BackupSnapshot(auth_user_id=user.auth_user_id, payload=payload, sha256=digest))


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        # Never forward the server key to a redirected destination.
        return None


class PrivateStorage:
    def __init__(self):
        self.url = (settings.safar_backup_url or settings.supabase_url).rstrip("/")
        self.key = settings.safar_backup_key or settings.supabase_secret_key
        parsed = urlsplit(self.url)
        if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.query or parsed.fragment:
            raise ValueError("Backup storage requires an HTTPS project URL")
        if not self.key:
            raise ValueError("Backup storage server key is missing")
        self.bucket = quote(settings.safar_backup_bucket, safe="")
        self.opener = build_opener(NoRedirect())

    def request(self, path: str, *, method: str = "GET", body: bytes | None = None) -> bytes:
        headers = {"apikey": self.key, "Content-Type": "application/json"}
        if not self.key.startswith("sb_secret_"):
            headers["Authorization"] = f"Bearer {self.key}"
        req = Request(f"{self.url}/storage/v1/{path}", data=body, headers=headers, method=method)
        with self.opener.open(req, timeout=20) as response:
            return response.read()

    def ensure_private_bucket(self):
        try:
            bucket = json.loads(self.request(f"bucket/{self.bucket}"))
        except HTTPError as exc:
            if exc.code not in (400, 404):
                raise
            self.request("bucket", method="POST", body=encode_archive({
                "id": settings.safar_backup_bucket, "name": settings.safar_backup_bucket, "public": False,
            }))
            bucket = json.loads(self.request(f"bucket/{self.bucket}"))
        if bucket.get("public") is not False:
            raise ValueError("Refusing to upload diaries to a public bucket")

    def upload_verified(self, snapshot: BackupSnapshot):
        data = encode_archive(snapshot.payload)
        path = f"{snapshot.auth_user_id}/{snapshot.created_at.strftime('%Y/%m/%d')}/{snapshot.id}.json"
        try:
            self.request(f"object/{self.bucket}/{path}", method="POST", body=data)
        except HTTPError as exc:
            # A previous attempt may have uploaded successfully before its DB commit.
            if exc.code not in (400, 409):
                raise
        saved = self.request(f"object/authenticated/{self.bucket}/{path}")
        if hashlib.sha256(saved).hexdigest() != snapshot.sha256:
            raise ValueError("Backup read-back checksum mismatch")


def deliver_pending() -> int:
    storage = PrivateStorage()
    storage.ensure_private_bucket()
    delivered = 0
    # Each snapshot is acknowledged separately; a failure remains durably queued.
    attempted_ids = []
    for _ in range(5):
        with SessionLocal() as db:
            snapshot = db.scalar(select(BackupSnapshot).where(BackupSnapshot.uploaded_at.is_(None),
                BackupSnapshot.id.not_in(attempted_ids)).order_by(BackupSnapshot.attempts, BackupSnapshot.created_at)
                .limit(1).with_for_update(skip_locked=True))
            if snapshot is None:
                break
            attempted_ids.append(snapshot.id)
            snapshot.attempts += 1
            try:
                storage.upload_verified(snapshot)
            except Exception as exc:
                snapshot.last_error = type(exc).__name__  # No response bodies, secrets or diary text.
                logger.warning("Diary backup upload deferred (%s)", type(exc).__name__)
            else:
                snapshot.uploaded_at = datetime.now(timezone.utc)
                snapshot.last_error = None
                snapshot.payload = None  # Keep a receipt; the durable copy is now offsite.
                delivered += 1
            db.commit()
    if delivered:
        logger.warning("Private diary backups verified: snapshots=%d", delivered)
    return delivered


async def backup_worker(stop: asyncio.Event):
    while not stop.is_set():
        try:
            await asyncio.to_thread(deliver_pending)
        except Exception as exc:
            logger.warning("Diary backup worker will retry (%s)", type(exc).__name__)
        try:
            await asyncio.wait_for(stop.wait(), timeout=settings.safar_backup_interval_seconds)
        except TimeoutError:
            pass
