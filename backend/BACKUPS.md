# Diary recovery and automatic backups

This feature runs entirely in the backend. It preserves the existing mobile API
and does not require an APK rebuild.

## Automatic cloud snapshots

Set these service environment variables (never commit their values):

- `SAFAR_BACKUP_ENABLED=true`
- `SAFAR_BACKUP_URL`: HTTPS Supabase project URL (defaults to `SUPABASE_URL`).
- `SAFAR_BACKUP_KEY`: Supabase server secret key (defaults to `SUPABASE_SECRET_KEY`).
- `SAFAR_BACKUP_BUCKET=safar-diary-backups`
- `SAFAR_BACKUP_INTERVAL_SECONDS=60`

The server creates a **private** bucket and refuses to use a public bucket.
No client storage policies are created. Only server credentials can access it.

Saving, editing, or deleting a diary queues a full user snapshot in the same
database transaction as the change. Edits and deletes also preserve the prior
state. On startup the server queues existing accounts' current state. A worker
uploads queued snapshots to versioned, user-specific object paths and reads
each object back to verify its SHA-256 checksum before acknowledging delivery.
Transient failures stay queued and are retried while the server is running.
Free Render services may sleep; pending delivery resumes when the service wakes.
The primary database's undelivered snapshot is retained until upload succeeds.
Once verified, the primary copy of the JSON payload is removed and the delivery
receipt remains. Cloud snapshots are retained; automatic retention deletion is
intentionally not enabled. Monitor storage usage as the archive grows.

Authenticated endpoints:

- `GET /backup/status`: this user's pending count and last verified upload time.
- `GET /backup/export`: this user's current portable JSON archive.

Snapshots include diary text, dates, IDs, and media metadata/URLs/nonces. They
**do not copy attachment bytes** out of Cloudinary or export the phone's media
encryption key. Preserve the installed app's data; encrypted media may depend on
that device key. Text that never reaches the backend is outside this backup's
coverage. A Google Drive integration, in-app backup controls, offline drafts,
and device-key recovery would require a mobile update.

## Explicit additive recovery

An operator can supply `SAFAR_RECOVERY_ARCHIVE_B64` as base64-encoded gzip JSON
in the service's secret environment, then deploy. The input format is the same
as `/backup/export`: `archive_version: 1`, `user`, and `entries` with nested
`media`. JSON must never be committed to the repository.

At startup, after Alembic migrations, recovery validates every record, matches
the destination account by Supabase `auth_user_id`, remaps the database-local
user ID if needed, and inserts only missing diary IDs. Existing records and
newer edits are never overwritten. Another user's ID collision aborts and
rolls back the whole import. A snapshot of the destination before recovery is
queued as well. A persistent checksum receipt makes the exact same recovery
archive run only once, so future restarts cannot resurrect intentionally deleted
diaries. Remove the secret recovery variable after verification (set it empty
when using a merge-only environment-variable API).

The primary `DATABASE_URL` is not changed by recovery or backups. Recovery runs
against the database already configured for the deployed backend.

## Validation

From `backend`: `python -m unittest discover -s tests -v`.
Checks cover account ID remapping, newer-entry preservation, duplicate/repeated
recovery, encrypted-media metadata, transaction rollback, API mutation snapshots,
failed-upload retry, checksum verification, and refusal of public storage.
