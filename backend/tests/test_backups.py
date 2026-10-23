import copy
import json
import os
import unittest
from datetime import datetime, timezone
from unittest.mock import patch
from uuid import uuid4

for key, value in {
    "DATABASE_URL": "sqlite://", "SUPABASE_URL": "https://example.supabase.co",
    "CLOUDINARY_CLOUD_NAME": "test", "CLOUDINARY_API_KEY": "test", "CLOUDINARY_API_SECRET": "test",
}.items():
    os.environ.setdefault(key, value)

from sqlalchemy import create_engine, func, select
from sqlalchemy.orm import sessionmaker

from app.core.config import settings
from app.db.base import Base
from app.models.backup import BackupSnapshot, RecoveryRun
from app.models.diary_entry import DiaryEntry, EntryMedia
from app.models.user import User
from app.services.backups import PrivateStorage, deliver_pending, queue_snapshot
from app.services.recovery import restore_archive


def archive():
    user_id, auth_id, entry_id = uuid4(), uuid4(), uuid4()
    stamp = datetime.now(timezone.utc).isoformat()
    return {
        "archive_version": 1,
        "user": {"id": str(user_id), "auth_user_id": str(auth_id), "email": "owner@example.com",
                 "name": "Owner", "created_at": stamp, "updated_at": stamp},
        "entries": [{"id": str(entry_id), "user_id": str(user_id), "title": "Archived entry",
            "content": "Archived diary text", "entry_type": "full", "entry_date": "2026-07-01",
            "created_at": stamp, "updated_at": stamp,
            "media": [{"id": str(uuid4()), "entry_id": str(entry_id), "media_type": "image",
                "url": "https://example.com/encrypted.bin", "sort_order": 0, "encrypted": True,
                "encryption_nonce": "test-nonce", "encryption_version": 1, "created_at": stamp}]}],
    }


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.engine = create_engine("sqlite://")
        Base.metadata.create_all(self.engine)
        self.factory = sessionmaker(self.engine, autoflush=False)
        self.db = self.factory()
        self.source = archive()
        self.raw = json.dumps(self.source).encode()

    def tearDown(self):
        self.db.close()
        self.engine.dispose()

    def restore(self):
        result = restore_archive(self.db, self.raw)
        self.db.commit()
        return result

    def test_restore_preserves_media_and_is_idempotent(self):
        self.assertEqual(self.restore(), 1)
        self.assertEqual(self.restore(), 0)
        self.assertEqual(self.db.scalar(select(func.count()).select_from(DiaryEntry)), 1)
        media = self.db.scalar(select(EntryMedia))
        self.assertTrue(media.encrypted)
        self.assertEqual(media.encryption_nonce, "test-nonce")
        self.assertEqual(self.db.scalar(select(func.count()).select_from(RecoveryRun)), 1)

    def test_destination_user_id_is_remapped_and_newer_entries_survive(self):
        source_user = self.source["user"]
        user = User(auth_user_id=source_user["auth_user_id"], email=source_user["email"])
        # UUID objects are required by the DB driver.
        from uuid import UUID
        user.auth_user_id = UUID(source_user["auth_user_id"])
        self.db.add(user)
        self.db.flush()
        newer = DiaryEntry(user_id=user.id, title="Newer", content="Keep me", entry_type="full",
                           entry_date=datetime(2026, 10, 23).date())
        self.db.add(newer)
        self.db.commit()
        self.assertEqual(self.restore(), 1)
        self.assertEqual(self.db.scalar(select(func.count()).select_from(DiaryEntry)), 2)
        restored = self.db.scalar(select(DiaryEntry).where(DiaryEntry.title == "Archived entry"))
        self.assertEqual(restored.user_id, user.id)
        self.assertEqual(newer.content, "Keep me")

    def test_existing_entry_is_never_overwritten(self):
        self.restore()
        entry = self.db.scalar(select(DiaryEntry))
        entry.content = "Edited after original backup"
        self.db.commit()
        changed = copy.deepcopy(self.source)
        changed["user"]["name"] = "Updated archive"
        self.assertEqual(restore_archive(self.db, json.dumps(changed).encode()), 0)
        self.db.commit()
        self.assertEqual(entry.content, "Edited after original backup")

    def test_completed_recovery_does_not_resurrect_later_deletions(self):
        self.restore()
        self.db.delete(self.db.scalar(select(DiaryEntry)))
        self.db.commit()
        self.assertEqual(self.restore(), 0)
        self.assertEqual(self.db.scalar(select(func.count()).select_from(DiaryEntry)), 0)

    def test_mixed_owner_archive_rolls_back(self):
        self.source["entries"][0]["user_id"] = str(uuid4())
        with self.assertRaises(ValueError):
            restore_archive(self.db, json.dumps(self.source).encode())
        self.db.rollback()
        self.assertEqual(self.db.scalar(select(func.count()).select_from(User)), 0)

    def test_backup_and_diary_change_share_transaction(self):
        self.restore()
        before = self.db.scalar(select(func.count()).select_from(BackupSnapshot))
        user = self.db.scalar(select(User))
        entry = self.db.scalar(select(DiaryEntry))
        entry.content = "Should roll back"
        queue_snapshot(self.db, user, force=True)
        self.db.rollback()
        self.assertEqual(self.db.scalar(select(func.count()).select_from(BackupSnapshot)), before)
        self.assertEqual(entry.content, "Archived diary text")

    def test_upload_failure_stays_queued_then_success_clears_only_payload(self):
        self.restore()
        class OfflineStorage:
            def ensure_private_bucket(self): pass
            def upload_verified(self, snapshot): raise OSError("offline")
        class WorkingStorage(OfflineStorage):
            def upload_verified(self, snapshot): pass
        with patch("app.services.backups.SessionLocal", self.factory):
            with patch("app.services.backups.PrivateStorage", OfflineStorage):
                self.assertEqual(deliver_pending(), 0)
            self.db.expire_all()
            pending = self.db.scalars(select(BackupSnapshot)).all()
            self.assertTrue(all(s.payload and s.uploaded_at is None for s in pending))
            with patch("app.services.backups.PrivateStorage", WorkingStorage):
                self.assertEqual(deliver_pending(), len(pending))
            self.db.expire_all()
            self.assertTrue(all(s.payload is None and s.uploaded_at is not None for s in pending))

    def test_public_bucket_is_rejected(self):
        with patch.object(settings, "safar_backup_key", "sb_secret_test"):
            storage = PrivateStorage()
        with patch.object(storage, "request", return_value=b'{"public":true}'):
            with self.assertRaises(ValueError): storage.ensure_private_bucket()

    def test_api_create_update_delete_queue_restorable_snapshots(self):
        from app.api.routes.entries import create_entry, update_entry, delete_entry
        from app.schemas.diary_entry import DiaryEntryCreate, DiaryEntryUpdate
        self.restore()
        user = self.db.scalar(select(User))
        with patch.object(settings, "safar_backup_enabled", True):
            created = create_entry(DiaryEntryCreate(title="New", content="First version", entry_type="full",
                entry_date="2026-10-23"), db=self.db, current_user=user)
            entry_id = created.id
            update_entry(entry_id, DiaryEntryUpdate(content="Second version"), db=self.db, current_user=user)
            delete_entry(entry_id, db=self.db, current_user=user)
        snapshots = self.db.scalars(select(BackupSnapshot)).all()
        versions = [entry["content"] for snapshot in snapshots for entry in snapshot.payload["entries"]
                    if entry["id"] == str(entry_id)]
        self.assertIn("First version", versions)
        self.assertIn("Second version", versions)
        self.assertIsNone(self.db.get(DiaryEntry, entry_id))

    def test_checksum_mismatch_does_not_count_as_verified(self):
        self.restore()
        snapshot = self.db.scalar(select(BackupSnapshot))
        with patch.object(settings, "safar_backup_key", "sb_secret_test"):
            storage = PrivateStorage()
        with patch.object(storage, "request", side_effect=[b'{}', b'corrupt']):
            with self.assertRaises(ValueError): storage.upload_verified(snapshot)


if __name__ == "__main__":
    unittest.main()
