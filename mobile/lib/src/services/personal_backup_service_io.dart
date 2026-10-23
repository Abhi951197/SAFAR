import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as hashes;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/backup_record.dart';
import 'api_client.dart';
import 'backup_codec_io.dart';
import 'backup_media_staging_io.dart';
import 'diary_repository.dart';
import 'media_encryption_service.dart';
import 'media_local_cache_io.dart';

class PersonalBackupService extends ChangeNotifier {
  PersonalBackupService(this.api, this.repository)
      : _userId = Supabase.instance.client.auth.currentUser!.id;
  final ApiClient api;
  final DiaryRepository repository;
  final String _userId;
  static const _storage = FlutterSecureStorage();
  static const _channel = MethodChannel('safar/backups');
  final _http = http.Client();
  Timer? _timer;
  Completer<AuthState?>? _driveConsent;
  bool get waitingForDrive => _driveConsent != null;
  void cancelDriveConnection() {
    final consent = _driveConsent;
    if (consent != null && !consent.isCompleted) consent.complete(null);
  }

  bool _disposed = false;
  bool busy = false, autoEnabled = false, driveEnabled = false;
  String phase = '';
  String? warning, error;
  DateTime? lastDriveBackup;
  DateTime? _driveExpiry;
  List<BackupRecord> localBackups = [];
  bool get supported => Platform.isAndroid;
  bool get driveReady =>
      driveEnabled &&
      _driveExpiry != null &&
      DateTime.now().isBefore(_driveExpiry!);
  String get _prefix => 'safar_backup_$_userId';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _progress(String message) {
    phase = message;
    _notify();
  }

  void _checkAccount() {
    if (Supabase.instance.client.auth.currentUser?.id != _userId) {
      throw StateError('Sign in to the same Safar account.');
    }
  }

  Future<Directory> _folder() async {
    final root = await getApplicationDocumentsDirectory();
    return Directory('${root.path}/safar_backups/$_userId')
      ..createSync(recursive: true);
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    autoEnabled = prefs.getBool('${_prefix}_auto') ?? false;
    driveEnabled = prefs.getBool('${_prefix}_drive') ?? false;
    lastDriveBackup =
        DateTime.tryParse(prefs.getString('${_prefix}_drive_last') ?? '');
    _driveExpiry = DateTime.tryParse(
        await _storage.read(key: '${_prefix}_drive_expiry') ?? '');
    final folder = await _folder();
    await for (final item in folder.list()) {
      if (item is File && item.path.endsWith('.partial')) {
        await item.delete();
      }
    }
    await _reloadLocal();
  }

  Future<void> _reloadLocal() async {
    final folder = await _folder();
    final records = <BackupRecord>[];
    await for (final item in folder.list()) {
      if (item is File && item.path.endsWith('.meta.json')) {
        try {
          final record = BackupRecord.fromJson(
              jsonDecode(await item.readAsString()) as Map<String, dynamic>);
          if (await File(record.path).exists()) records.add(record);
        } catch (_) {/* A damaged sidecar must not hide the other backups. */}
      }
    }
    records.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    localBackups = records;
    _notify();
  }

  Future<void> setAutoEnabled(bool enabled) async {
    if (enabled && await _storage.read(key: '${_prefix}_password') == null) {
      throw StateError(
          'Make your first backup and remember its password before enabling automatic backup.');
    }
    autoEnabled = enabled;
    (await SharedPreferences.getInstance()).setBool('${_prefix}_auto', enabled);
    _notify();
  }

  void scheduleBackup() {
    if (!autoEnabled || _disposed) return;
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 12), () async {
      if (busy || _disposed) {
        scheduleBackup();
        return;
      }
      final password = await _storage.read(key: '${_prefix}_password');
      if (password == null) return;
      try {
        await backup(password);
      } catch (e) {
        error = e.toString();
        _notify();
      }
    });
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    if (busy) throw StateError('A backup operation is already running.');
    _checkAccount();
    busy = true;
    error = null;
    warning = null;
    _notify();
    try {
      return await action();
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      busy = false;
      phase = '';
      _notify();
    }
  }

  Future<BackupRecord> backup(String password, {bool remember = true}) =>
      _run(() async {
        if (password.length < 10) {
          throw const FormatException(
              'Use at least 10 characters for your backup password.');
        }
        _progress('Preparing your diary');
        final manifest = await api.exportBackup();
        _checkAccount();
        final entries =
            (manifest['entries'] as List).cast<Map<String, dynamic>>();
        final media = <Map<String, dynamic>>[];
        for (final entry in entries) {
          media.addAll((entry['media'] as List).cast<Map<String, dynamic>>());
        }
        final temporaryRoot = await getTemporaryDirectory();
        final staged = await stageBackupMedia(
          media: media,
          directory: Directory(
              '${temporaryRoot.path}/backup-stage-${DateTime.now().microsecondsSinceEpoch}'),
          onProgress: (current, total) {
            _checkAccount();
            _progress('Preserving media $current of $total');
          },
          keyFor: MediaEncryptionService.instance.keyForBackup,
          sourceFor: (url) async {
            _checkAccount();
            final cached = await cachedMediaFile(url);
            if (await cached.exists()) return cached.openRead();
            final uri = Uri.parse(url);
            if (uri.scheme != 'https') {
              throw StateError('Insecure media address');
            }
            final response = await _http
                .send(http.Request('GET', uri))
                .timeout(const Duration(seconds: 45));
            if (response.statusCode != 200) {
              throw StateError('Attachment is unavailable');
            }
            return response.stream.timeout(const Duration(seconds: 60));
          },
          verify: (attachment, key, nonce) async {
            final length = await attachment.length();
            if (length <= 16) {
              throw const FormatException('Invalid encrypted attachment');
            }
            final input = await attachment.open();
            late List<int> mac;
            try {
              await input.setPosition(length - 16);
              mac = await input.read(16);
            } finally {
              await input.close();
            }
            await MediaEncryptionService.instance.verifyBackupMedia(
                attachment.openRead(0, length - 16), key, nonce, mac);
          },
        );
        late BackupRecord record;
        late File file;
        try {
          _checkAccount();
          manifest['backup_kind'] = 'personal-v2';
          manifest['media_keys'] = staged.keys;
          manifest['locked_media_count'] = staged.locked;
          manifest['missing_media_count'] = staged.missing;
          manifest['created_at'] = DateTime.now().toUtc().toIso8601String();
          manifest['full_media_backup'] =
              staged.missing == 0 && staged.locked == 0;
          manifest['coverage'] = staged.missing == 0 && staged.locked == 0
              ? 'Diary text, entry links, attachment bytes and verified media keys'
              : 'Diary text and links, available attachment bytes; see locked and missing attachment counts';
          final folder = await _folder();
          final date = DateTime.now();
          final name =
              'Safar-${date.toUtc().toIso8601String().replaceAll(':', '-')}.safar';
          file = File('${folder.path}/$name');
          Stream<List<int>> records() async* {
            yield* BackupCodec.record('manifest.json',
                Stream.value(utf8.encode(jsonEncode(manifest))));
            for (final item in staged.files.entries) {
              _checkAccount();
              yield* BackupCodec.record(item.key, item.value.openRead());
            }
            yield BackupCodec.lengthBytes(0);
          }

          _progress('Encrypting your backup');
          await BackupCodec.write(file, password, records());
          record = BackupRecord(
              path: file.path,
              name: name,
              createdAt: date,
              bytes: await file.length(),
              entries: entries.length,
              media: media.length,
              lockedMedia: staged.locked,
              missingMedia: staged.missing);
          if (staged.locked > 0 || staged.missing > 0) {
            warning =
                'Diary saved. ${staged.locked} attachments preserved as locked files; ${staged.missing} attachments could not be downloaded. Lost media keys cannot be recreated by a new backup.';
          }
        } finally {
          await staged.close();
        }
        await File('${file.path}.meta.json')
            .writeAsString(jsonEncode(record.toJson()), flush: true);
        if (remember) {
          await _storage.write(key: '${_prefix}_password', value: password);
        }
        await _reloadLocal();
        // Incomplete coverage never removes an older backup that has all media keys.
        final retentionCandidates = record.lockedMedia > 0 || record.missingMedia > 0
          ? localBackups.where((old) => old.lockedMedia > 0 || old.missingMedia > 0)
          : localBackups;
        for (final old in retentionCandidates.skip(3)) {
          await File(old.path).delete();
          final meta = File('${old.path}.meta.json');
          if (await meta.exists()) await meta.delete();
        }
        await _reloadLocal();
        if (driveEnabled) {
          try {
            await _uploadDrive(record);
          } catch (e) {
            warning =
                '${warning == null ? '' : '${warning!}\n'}Saved on this phone. Google Drive: $e';
          }
        }
        return record;
      });

  Future<bool> saveCopy(BackupRecord record) async =>
      await _channel.invokeMethod<bool>(
          'saveBackup', {'path': record.path, 'name': record.name}) ??
      false;

  Future<void> connectDrive() => _run(() async {
        _progress('Waiting for Google Drive permission');
        final auth = Supabase.instance.client.auth;
        final consent = Completer<AuthState?>();
        _driveConsent = consent;
        _notify();
        final subscription = auth.onAuthStateChange.listen((event) {
          if (event.event == AuthChangeEvent.signedIn &&
              event.session?.providerToken != null &&
              !consent.isCompleted) {
            consent.complete(event);
          }
        });
        late AuthState event;
        try {
          await auth.signInWithOAuth(OAuthProvider.google,
              scopes: 'https://www.googleapis.com/auth/drive.file',
              redirectTo: 'safar://login-callback',
              queryParams: {
                'prompt': 'consent',
                'login_hint': auth.currentUser?.email ?? ''
              });
          final result = await consent.future
              .timeout(const Duration(minutes: 2), onTimeout: () => null);
          if (result == null) {
            throw StateError(
                'Drive connection was not completed. If Google says the app is being tested, add this account under Google Cloud → Google Auth Platform → Audience → Test users. Or use Save backup to Drive / Files.');
          }
          event = result;
        } finally {
          await subscription.cancel();
          _driveConsent = null;
          _notify();
        }
        _checkAccount();
        final token = event.session!.providerToken!;
        final profile = await _http.get(
            Uri.https('www.googleapis.com', '/oauth2/v2/userinfo'),
            headers: {'Authorization': 'Bearer $token'});
        if (profile.statusCode != 200 ||
            (jsonDecode(profile.body) as Map)['email'] !=
                auth.currentUser?.email) {
          throw StateError(
              'Connect the same Google account you use for Safar.');
        }
        await _storage.write(key: '${_prefix}_drive_token', value: token);
        _driveExpiry = DateTime.now().add(const Duration(minutes: 50));
        await _storage.write(
            key: '${_prefix}_drive_expiry',
            value: _driveExpiry!.toIso8601String());
        // Probe the API before reporting a successful connection.
        await _driveJson('GET', '/drive/v3/files',
            query: {'pageSize': '1', 'fields': 'files(id)'});
        driveEnabled = true;
        await (await SharedPreferences.getInstance())
            .setBool('${_prefix}_drive', true);
      });

  Future<void> disconnectDrive() async {
    driveEnabled = false;
    _driveExpiry = null;
    await _storage.delete(key: '${_prefix}_drive_token');
    await _storage.delete(key: '${_prefix}_drive_expiry');
    await (await SharedPreferences.getInstance())
        .setBool('${_prefix}_drive', false);
    _notify();
  }

  Future<String> _token() async {
    _checkAccount();
    if (_driveExpiry == null || DateTime.now().isAfter(_driveExpiry!)) {
      throw StateError('Reconnect Google Drive to renew permission.');
    }
    final value = await _storage.read(key: '${_prefix}_drive_token');
    if (value == null) throw StateError('Connect Google Drive first.');
    return value;
  }

  Object _driveError(http.Response response) {
    if (response.statusCode == 401) {
      return StateError('Reconnect Google Drive to renew permission.');
    }
    if (response.statusCode == 403 &&
        response.body.contains('SERVICE_DISABLED')) {
      return StateError(
          'Drive access is not enabled for Safar. Ask the app owner to enable the Google Drive API.');
    }
    if (response.statusCode == 403) {
      return StateError(
          'Google Drive permission or storage is unavailable. Reconnect and check your Google storage.');
    }
    return HttpException(
        'Google Drive request failed (${response.statusCode}).');
  }

  Future<Map<String, dynamic>> _driveJson(String method, String path,
      {Map<String, String>? query, Map<String, dynamic>? body}) async {
    final request =
        http.Request(method, Uri.https('www.googleapis.com', path, query));
    request.headers.addAll({
      'Authorization': 'Bearer ${await _token()}',
      'Content-Type': 'application/json'
    });
    if (body != null) request.body = jsonEncode(body);
    final response = await http.Response.fromStream(await _http.send(request));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _driveError(response);
    }
    return response.body.isEmpty
        ? {}
        : jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<String> _driveFolder() async {
    final result = await _driveJson('GET', '/drive/v3/files', query: {
      'q':
          "mimeType='application/vnd.google-apps.folder' and name='Safar Backups' and trashed=false",
      'fields': 'files(id)',
      'pageSize': '10'
    });
    final folders = result['files'] as List;
    if (folders.isNotEmpty) return (folders.first as Map)['id'] as String;
    return (await _driveJson('POST', '/drive/v3/files', body: {
      'name': 'Safar Backups',
      'mimeType': 'application/vnd.google-apps.folder'
    }))['id'] as String;
  }

  Future<void> _uploadDrive(BackupRecord record) async {
    _progress('Uploading encrypted backup to Google Drive');
    final file = File(record.path), size = record.bytes;
    final token = await _token();
    final start = await _http.post(
        Uri.https('www.googleapis.com', '/upload/drive/v3/files',
            {'uploadType': 'resumable', 'fields': 'id,size,md5Checksum'}),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=UTF-8',
          'X-Upload-Content-Type': 'application/octet-stream',
          'X-Upload-Content-Length': '$size'
        },
        body: jsonEncode({
          'name': record.name,
          'parents': [await _driveFolder()],
          'appProperties': {'safarBackup': '2', 'safarUser': _userId}
        }));
    if (start.statusCode < 200 || start.statusCode >= 300) {
      throw _driveError(start);
    }
    final location = start.headers['location'];
    if (location == null) {
      throw StateError('Google Drive did not start the upload.');
    }
    final uploadUri = Uri.parse(location);
    if (uploadUri.scheme != 'https' || uploadUri.host != 'www.googleapis.com') {
      throw StateError('Invalid Drive upload address.');
    }
    // Chunked resumable requests keep memory bounded for videos and large diaries.
    final input = await file.open();
    Map<String, dynamic>? saved;
    try {
      for (var offset = 0; offset < size;) {
        final bytes = await input.read(1024 * 1024);
        final end = offset + bytes.length;
        final response = await _http.put(uploadUri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/octet-stream',
              'Content-Range': 'bytes $offset-${end - 1}/$size'
            },
            body: bytes);
        if (response.statusCode == 200 || response.statusCode == 201) {
          saved = jsonDecode(response.body) as Map<String, dynamic>;
        } else if (response.statusCode != 308) {
          throw _driveError(response);
        }
        offset = end;
        _progress('Google Drive ${(offset * 100 / size).round()}%');
      }
    } finally {
      await input.close();
    }
    final localHash = (await hashes.md5.bind(file.openRead()).first).toString();
    if (saved == null ||
        saved['size'].toString() != '$size' ||
        saved['md5Checksum'] != localHash) {
      throw StateError(
          'Google Drive backup could not be verified. Your phone copy is safe.');
    }
    lastDriveBackup = DateTime.now();
    await (await SharedPreferences.getInstance())
        .setString('${_prefix}_drive_last', lastDriveBackup!.toIso8601String());
  }

  Future<List<DriveBackup>> listDriveBackups() async {
    final result = await _driveJson('GET', '/drive/v3/files', query: {
      'q':
          "trashed=false and appProperties has { key='safarUser' and value='$_userId' }",
      'fields': 'files(id,name,size,modifiedTime)',
      'orderBy': 'modifiedTime desc',
      'pageSize': '100'
    });
    return (result['files'] as List)
        .cast<Map<String, dynamic>>()
        .map((j) => DriveBackup(
            id: j['id'] as String,
            name: j['name'] as String,
            modifiedAt: DateTime.parse(j['modifiedTime'] as String),
            bytes: int.parse(j['size'] as String)))
        .toList();
  }

  Future<int?> restoreFromPhone(String password) async {
    final path = await _channel.invokeMethod<String>('pickBackup');
    if (path == null) return null;
    return _run(() async {
      try {
        return await _restore(File(path), password);
      } finally {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    });
  }

  Future<int> restoreFromDrive(DriveBackup backup, String password) =>
      _run(() async {
        _progress('Downloading from Google Drive');
        final folder = await getTemporaryDirectory();
        final file = File(
            '${folder.path}/drive-${DateTime.now().microsecondsSinceEpoch}.safar');
        try {
          final response = await _http.send(http.Request(
              'GET',
              Uri.https('www.googleapis.com', '/drive/v3/files/${backup.id}',
                  {'alt': 'media'}))
            ..headers['Authorization'] = 'Bearer ${await _token()}');
          if (response.statusCode != 200) {
            throw _driveError(await http.Response.fromStream(response));
          }
          await response.stream.pipe(file.openWrite());
          return await _restore(file, password);
        } finally {
          if (await file.exists()) await file.delete();
        }
      });

  Future<int> _restore(File file, String password) async {
    _progress('Unlocking and verifying your backup');
    final root = await getTemporaryDirectory();
    final opened = await BackupCodec.open(
        file,
        password,
        Directory(
            '${root.path}/restore-${DateTime.now().microsecondsSinceEpoch}'));
    try {
      final manifest = opened.manifest;
      if ((manifest['user'] as Map)['auth_user_id'] != _userId ||
          (manifest['full_media_backup'] != true &&
              manifest['backup_kind'] != 'personal-v2')) {
        throw StateError(
            'Use the same Safar account that created this backup.');
      }
      final entries =
          (manifest['entries'] as List).cast<Map<String, dynamic>>();
      final keys = (manifest['media_keys'] as Map).cast<String, String>();
      final expectedFiles = <String>{};
      for (final entry in entries) {
        for (final item
            in (entry['media'] as List).cast<Map<String, dynamic>>()) {
          if (item['backup_missing'] == true &&
              manifest['backup_kind'] == 'personal-v2') {
            continue;
          }
          final path = item['backup_file'] as String;
          if (!expectedFiles.add(path) || !opened.files.containsKey(path)) {
            throw const FormatException('Backup media is incomplete.');
          }
        }
      }
      if (opened.files.length != expectedFiles.length) {
        throw const FormatException('Unexpected files in backup.');
      }
      final existing = {for (final entry in await api.entries()) entry.id};
      final restoreEntries = <Map<String, dynamic>>[];
      var index = 0;
      for (final entry in entries) {
        _checkAccount();
        final missing = !existing.contains(entry['id']);
        final updatedMedia = <Map<String, dynamic>>[];
        for (final original
            in (entry['media'] as List).cast<Map<String, dynamic>>()) {
          index++;
          _progress('Restoring media $index of ${expectedFiles.length}');
          final media = Map<String, dynamic>.from(original);
          if (media['backup_missing'] == true &&
              manifest['backup_kind'] == 'personal-v2') {
            for (final field in [
              'backup_missing',
              'backup_issue',
              'backup_locked',
              'backup_file'
            ]) {
              media.remove(field);
            }
            updatedMedia.add(media);
            continue;
          }
          final raw = await opened.files[media['backup_file']]!.readAsBytes();
          Uint8List clear = raw;
          var locked = false;
          if (media['encrypted'] == true) {
            final key = keys[media['url']];
            if (key == null) {
              if (manifest['backup_kind'] != 'personal-v2' ||
                  media['backup_locked'] != true) {
                throw const FormatException('A backup media key is missing.');
              }
              locked = true;
            } else {
              clear = await MediaEncryptionService.instance.decryptBackupMedia(
                  raw, key, media['encryption_nonce'] as String);
            }
          }
          if (missing) {
            final encrypted = locked
                ? EncryptedMediaPayload(
                    bytes: raw,
                    nonce: media['encryption_nonce'] as String,
                    version: media['encryption_version'] as int? ?? 1)
                : await MediaEncryptionService.instance.encrypt(clear);
            final uploaded = await api.uploadEncryptedMedia(
                bytes: encrypted.bytes,
                filename: 'restored-${media['id']}.bin',
                mediaType: media['media_type'] as String,
                contentType: media['content_type'] as String? ??
                    'application/octet-stream');
            media.addAll({
              'url': uploaded['url'],
              'public_id': uploaded['public_id'],
              'encrypted': true,
              'encryption_nonce': encrypted.nonce,
              'encryption_version': encrypted.version
            });
          }
          for (final field in [
            'backup_missing',
            'backup_issue',
            'backup_locked',
            'backup_file'
          ]) {
            media.remove(field);
          }
          updatedMedia.add(media);
        }
        if (missing) {
          final updated = Map<String, dynamic>.from(entry)
            ..['media'] = updatedMedia;
          for (final kind in ['image', 'video', 'audio']) {
            final matches = updatedMedia.where((m) => m['media_type'] == kind);
            updated['${kind}_url'] =
                matches.isEmpty ? null : matches.first['url'];
            updated['${kind}_public_id'] =
                matches.isEmpty ? null : matches.first['public_id'];
          }
          restoreEntries.add(updated);
        }
      }
      _progress('Restoring missing diary entries');
      final result = await api.restoreBackup({
        'archive_version': 1,
        'user': manifest['user'],
        'entries': restoreEntries
      });
      // Keep original attachment bytes and per-URL keys locally as well, so existing
      // server entries can be read on a new phone without replacing its current key.
      for (final entry in entries) {
        for (final item
            in (entry['media'] as List).cast<Map<String, dynamic>>()) {
          final url = item['url'] as String;
          if (item['backup_missing'] == true) continue;
          await cacheMediaFile(url, opened.files[item['backup_file']]!.path);
          if (item['encrypted'] == true && keys.containsKey(url)) {
            await MediaEncryptionService.instance
                .rememberRestoredKey(url, keys[url]!);
          }
        }
      }
      final lockedCount = manifest['locked_media_count'] as int? ?? 0;
      final missingCount = manifest['missing_media_count'] as int? ?? 0;
      if (lockedCount > 0 || missingCount > 0) {
        warning =
            'Diary restored. $lockedCount attachments remain locked without their original key; $missingCount attachments were unavailable in this backup.';
      }
      await repository.refreshAll();
      return result['inserted'] as int;
    } finally {
      await opened.close();
    }
  }

  @override
  void dispose() {
    cancelDriveConnection();
    _disposed = true;
    _timer?.cancel();
    _http.close();
    super.dispose();
  }
}
