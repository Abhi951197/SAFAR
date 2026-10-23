# Personal backups and connected memories

Android 1.1 adds Profile → Backups & restore. A password-protected `.safar` archive contains diary text, entry references, attachment bytes and the keys required to decrypt those attachments. The backup password and media keys remain on the phone and inside the encrypted archive; they are not sent to the diary restore API.

## Use

1. Choose a backup password of at least 10 characters and keep it somewhere safe. Safar cannot reset the password of an existing archive.
2. Tap **Back up now**. The archive explicitly counts attachments that remain locked or could not be downloaded. Only an archive with every attachment and its verified key is marked fully recoverable. A disk/encryption failure leaves previous backups intact.
3. Use **Save a copy** beside a phone backup to choose Documents, an SD card or an Android document provider. Safar's own app folder is removed when the app is uninstalled. Recent archives are retained inside the app; a backup with locked or missing media never rotates away an older complete archive. Exported copies are not removed by Safar.
4. Optionally connect the same Google account used for Safar. New backups upload directly from the phone to **My Drive / Safar Backups**. Upload size and MD5 checksum are checked. Google storage quotas and available phone storage apply. Drive copies are retained until the user removes them.
5. Enable **Back up after diary changes** after a successful backup with its password remembered securely. This runs after a short delay while Safar is open. It is not an Android background scheduler. If Drive permission expires, phone backups continue and the screen asks the user to reconnect.
6. Restore on the same Safar account using the original password. Choose a local file (the Android picker can also browse Drive) or select a Drive backup. Internet access is required to restore missing diary records and re-upload attachments. Existing diary records are preserved. Restored attachment bytes and keys also remain locally for existing entries.

## Google configuration

The app reuses Supabase's Google OAuth browser flow and `safar://login-callback`. It requests Google's `drive.file` scope, limiting access to files created/opened for Safar. Enable the **Google Drive API** in the Google Cloud project that owns the existing web OAuth client (`33551217855-…apps.googleusercontent.com`), and allow that scope on the OAuth consent configuration. If the consent app is in testing, users must be permitted test users. No web OAuth client secret belongs in the APK.

The client stores the temporary Google access token in Android secure storage and asks for reconnection after its usable session. This version deliberately does not promise unattended Drive uploads after Google permission expires. Phone backup remains available, and **Save a copy** can use Android's Drive document provider independently of Safar's OAuth API integration.

## Persistent release signing and existing-installation limitation

The earlier GitHub workflow generated debug signing keys on fresh runners. The 1.1.0 and 1.1.1 runner APK certificates differ, so Android cannot update between them in place. The old private signing key cannot be reconstructed from an APK. Do not uninstall an installation that holds media keys or unsaved data just to bypass this error.

The delivered 1.1.1 APK has been re-signed with a persistent Safar release key and verified with the Android apksig library. It still cannot update an old debug-signed installation. The private release keystore and its passwords are in the owner's separately saved private backup/signing bundle; no private signing material is committed to the repository. Keep an offline copy of that bundle. It also contains the password for the separately downloadable server recovery archive.

Before running future GitHub APK builds, open repository **Settings → Secrets and variables → Actions → New repository secret** and add these four names, copying their matching values from the private bundle:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The GitHub connection used for this repair cannot write Actions secrets, so the repository owner must complete this account configuration. The workflow now refuses release builds when these secrets are missing or the certificate differs from `mobile/android/release-cert.sha256`; it never falls back to another temporary debug key. Once configured, future APKs use the same certificate as the delivered release APK. The app's application ID remains unchanged.

The signing configuration commit intentionally skips CI because these owner-only secrets are not configured yet. The preceding app commit passed Flutter analysis, all eight tests and a release APK build. The delivered binary's application entries were checked against that build before its new signature was verified. The signing preparation script was verified locally with the saved keystore; an end-to-end GitHub build with these secrets remains to be run after the owner configures them.

## Connected memories

An entry can link up to 20 entries from the same account, found by title, text or date. Each connection can include a short note. Entry detail shows outgoing **Connected memories** and incoming **Mentioned in** links. Deleted targets leave a dated title placeholder. An ordinary edit from an older APK preserves links because the references field is optional on update. Personal and server metadata backups include references.

## Format and validation

Version 2 archives use PBKDF2-HMAC-SHA256 (210,000 iterations, random 16-byte salt) and AES-256-GCM (random 12-byte nonce). The format header is authenticated. Records are framed and processed incrementally with 1 MiB maximum chunks. The full authentication tag is checked before parsing or restoring records. Generated extraction paths prevent archive path traversal. The manifest is bounded to 32 MiB; the restore API accepts up to 5,000 entries per request. Backup creation streams attachments; media restore uses the existing app's in-memory encryption/upload path one attachment at a time.

Backend tests cover ownership, additive restoration, repeated explicit restores and reference backlinks. Flutter tests cover streamed archives, password errors, tampering, incomplete records and interrupted downloads. Google OAuth consent, Android's file picker and installation over an existing APK still need device-level verification. Existing server snapshots remain a secondary recovery mechanism for text and metadata; personal full-media backups are stored on the user's phone and Drive.


## Version 1.1.1: missing keys and Google testing errors

Uninstalling Safar removes Android app storage and can remove the only original media key. A new backup password cannot recreate that key. This version saves diary text and links even if an attachment key is unavailable, preserves available encrypted attachment bytes as locked files, and explicitly records failed downloads. It does not advertise these archives as fully recoverable media backups. Restore preserves locked bytes and metadata; a lost key remains necessary to unlock them. Incomplete-coverage backups do not rotate away older complete backups.

Use **Save backup to Drive / Files** to create an encrypted archive and select a destination in Android's document picker. If the Google Drive document provider is available, select the Drive account that matches the Safar login. This does not invoke Safar's OAuth client or its testing restrictions. Drive's own app handles the selected provider; verify its upload/sync status in Drive. If Drive is absent from the picker, enable/install Drive or save to Documents and upload the file from Drive. Restore uses **Restore from a file**, which can browse the same provider.

For the optional direct Drive connection, `Error 403: access_denied` with "app is currently being tested" is controlled by Google Cloud, not a Supabase storage policy. In the Cloud project owning the configured web OAuth client, open **Google Auth Platform → Audience → Test users**, add the affected Google account and save. To serve other users, configure the intended production audience and complete the verification steps Google requires. The app now allows cancelling a blocked consent flow instead of waiting until it times out.
