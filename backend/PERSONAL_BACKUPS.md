# Personal backups and connected memories

Android 1.1 adds Profile → Backups & restore. A password-protected `.safar` archive contains diary text, entry references, attachment bytes and the keys required to decrypt those attachments. The backup password and media keys remain on the phone and inside the encrypted archive; they are not sent to the diary restore API.

## Use

1. Choose a backup password of at least 10 characters and keep it somewhere safe. Safar cannot reset the password of an existing archive.
2. Tap **Back up now**. The archive is complete only after every attachment downloads and encryption finishes. A failed backup leaves previous completed backups intact.
3. Use **Save a copy** beside a phone backup to choose Documents, an SD card or an Android document provider. Safar's own app folder is removed when the app is uninstalled. The latest three completed archives are retained inside the app; exported copies are not removed by Safar.
4. Optionally connect the same Google account used for Safar. New backups upload directly from the phone to **My Drive / Safar Backups**. Upload size and MD5 checksum are checked. Google storage quotas and available phone storage apply. Drive copies are retained until the user removes them.
5. Enable **Back up after diary changes** after a successful backup with its password remembered securely. This runs after a short delay while Safar is open. It is not an Android background scheduler. If Drive permission expires, phone backups continue and the screen asks the user to reconnect.
6. Restore on the same Safar account using the original password. Choose a local file (the Android picker can also browse Drive) or select a Drive backup. Internet access is required to restore missing diary records and re-upload attachments. Existing diary records are preserved. Restored attachment bytes and keys also remain locally for existing entries.

## Google configuration

The app reuses Supabase's Google OAuth browser flow and `safar://login-callback`. It requests Google's `drive.file` scope, limiting access to files created/opened for Safar. Enable the **Google Drive API** in the Google Cloud project that owns the existing web OAuth client (`33551217855-…apps.googleusercontent.com`), and allow that scope on the OAuth consent configuration. If the consent app is in testing, users must be permitted test users. No web OAuth client secret belongs in the APK.

The client stores the temporary Google access token in Android secure storage and asks for reconnection after its usable session. This version deliberately does not promise unattended Drive uploads after Google permission expires. Phone backup remains available, and **Save a copy** can use Android's Drive document provider independently of Safar's OAuth API integration.

## Existing Android signing limitation

The repository signs release builds with the runner's debug key. A fresh GitHub runner can generate a different signing certificate. Android requires the original signing key to update an installed app. **Do not uninstall an existing installation to bypass an update failure:** it may hold the only key for older encrypted attachments. Recover and reuse the original keystore before replacing that installation. Future production builds should use a stable release keystore stored in GitHub Actions secrets, never in the public repository.

## Connected memories

An entry can link up to 20 entries from the same account, found by title, text or date. Each connection can include a short note. Entry detail shows outgoing **Connected memories** and incoming **Mentioned in** links. Deleted targets leave a dated title placeholder. An ordinary edit from an older APK preserves links because the references field is optional on update. Personal and server metadata backups include references.

## Format and validation

Version 2 archives use PBKDF2-HMAC-SHA256 (210,000 iterations, random 16-byte salt) and AES-256-GCM (random 12-byte nonce). The format header is authenticated. Records are framed and processed incrementally with 1 MiB maximum chunks. The full authentication tag is checked before parsing or restoring records. Generated extraction paths prevent archive path traversal. The manifest is bounded to 32 MiB; the restore API accepts up to 5,000 entries per request. Backup creation streams attachments; media restore uses the existing app's in-memory encryption/upload path one attachment at a time.

Backend tests cover ownership, additive restoration, repeated explicit restores and reference backlinks. Flutter tests cover streamed archives, password errors, tampering, incomplete records and interrupted downloads. Google OAuth consent, Android's file picker and installation over an existing APK still need device-level verification. Existing server snapshots remain a secondary recovery mechanism for text and metadata; personal full-media backups are stored on the user's phone and Drive.
