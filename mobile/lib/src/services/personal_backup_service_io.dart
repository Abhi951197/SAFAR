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
import '../models/diary_entry.dart';
import 'api_client.dart';
import 'backup_codec_io.dart';
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
      if (item is File && item.path.endsWith('.partial')) { await item.delete(); }
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
        final keys = <String, String>{};
        for (final entry in entries) {
          for (final item
              in (entry['media'] as List).cast<Map<String, dynamic>>()) {
            item['backup_file'] = 'media/${media.length}';
            media.add(item);
            if (item['encrypted'] == true) {
              keys[item['url'] as String] = await MediaEncryptionService
                  .instance
                  .keyForBackup(EntryMedia.fromJson(item));
            }
          }
        }
        manifest['media_keys'] = keys;
        manifest['created_at'] = DateTime.now().toUtc().toIso8601String();
        manifest['full_media_backup'] = true;
        manifest['coverage'] =
            'Diary text, entry links, attachment bytes and media keys inside this encrypted archive';
        final folder = await _folder();
        final date = DateTime.now();
        final name =
            'Safar-${date.toUtc().toIso8601String().replaceAll(':', '-')}.safar';
        final file = File('${folder.path}/$name');
        Stream<List<int>> records() async* {
          yield* BackupCodec.record(
              'manifest.json', Stream.value(utf8.encode(jsonEncode(manifest))));
          for (var index = 0; index < media.length; index++) {
            _checkAccount();
            final item = media[index];
            _progress('Backing up media ${index + 1} of ${media.length}');
            final url = item['url'] as String;
            final cached = await cachedMediaFile(url);
            Stream<List<int>> source;
            if (await cached.exists()) {
              source = cached.openRead();
            } else {
              final uri = Uri.parse(url);
              if (uri.scheme != 'https') {
                throw StateError('A media link is not secure.');
              }
              final response = await _http
                  .send(http.Request('GET', uri))
                  .timeout(const Duration(seconds: 45));
              if (response.statusCode != 200) {
                throw StateError(
                    'Media ${index + 1} could not be downloaded. No incomplete backup was saved.');
              }
              source = response.stream.timeout(const Duration(seconds: 60));
            }
            if (item['encrypted'] == true) {
              // Verify the original device key before declaring this a usable backup.
              // A fresh installation may have a different key despite matching URLs.
              final temporaryRoot = await getTemporaryDirectory();
              final attachment = File(
                  '${temporaryRoot.path}/backup-media-${DateTime.now().microsecondsSinceEpoch}.tmp');
              try {
                await source.pipe(attachment.openWrite());
                final length = await attachment.length();
                if (length <= 16) {
                  throw const FormatException('Invalid encrypted attachment.');
                }
                final input = await attachment.open();
                late List<int> mac;
                try {
                  await input.setPosition(length - 16);
                  mac = await input.read(16);
                } finally {
                  await input.close();
                }
                try {
                  await MediaEncryptionService.instance.verifyBackupMedia(
                      attachment.openRead(0, length - 16),
                      keys[url]!,
                      item['encryption_nonce'] as String,
                      mac);
                } catch (_) {
                  throw StateError(
                      'This phone cannot unlock an older attachment. Keep the original app installed and restore a complete backup with its original media keys.');
                }
                yield* BackupCodec.record(
                    item['backup_file'] as String, attachment.openRead());
              } finally {
                if (await attachment.exists()) await attachment.delete();
              }
            } else {
              yield* BackupCodec.record(item['backup_file'] as String, source);
            }
          }
          yield BackupCodec.lengthBytes(0);
        }

        await BackupCodec.write(file, password, records());
        final record = BackupRecord(
            path: file.path,
            name: name,
            createdAt: date,
            bytes: await file.length(),
            entries: entries.length,
            media: media.length);
        await File('${file.path}.meta.json')
            .writeAsString(jsonEncode(record.toJson()), flush: true);
        if (remember) {
          await _storage.write(key: '${_prefix}_password', value: password);
        }
        await _reloadLocal();
        // Keep three completed phone archives; never delete the previous backup on failure.
        for (final old in localBackups.skip(3)) {
          await File(old.path).delete();
          final meta = File('${old.path}.meta.json');
          if (await meta.exists()) await meta.delete();
        }
        await _reloadLocal();
        if (driveEnabled) {
          try {
            await _uploadDrive(record);
          } catch (e) {
            warning = 'Saved on this phone. Google Drive: $e';
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
        final completed = auth.onAuthStateChange.firstWhere((event) =>
            event.event == AuthChangeEvent.signedIn &&
            event.session?.providerToken != null);
        await auth.signInWithOAuth(OAuthProvider.google,
            scopes: 'https://www.googleapis.com/auth/drive.file',
            redirectTo: 'safar://login-callback',
            queryParams: {
              'prompt': 'consent',
              'login_hint': auth.currentUser?.email ?? ''
            });
        final event = await completed.timeout(const Duration(minutes: 3));
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
          manifest['full_media_backup'] != true) {
        throw StateError(
            'Use the same Safar account that created this complete backup.');
      }
      final entries =
          (manifest['entries'] as List).cast<Map<String, dynamic>>();
      final keys = (manifest['media_keys'] as Map).cast<String, String>();
      final expectedFiles = <String>{};
      for (final entry in entries) {
        for (final item
            in (entry['media'] as List).cast<Map<String, dynamic>>()) {
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
          final raw = await opened.files[media['backup_file']]!.readAsBytes();
          Uint8List clear = raw;
          if (media['encrypted'] == true) {
            final key = keys[media['url']];
            if (key == null) {
              throw const FormatException('A backup media key is missing.');
            }
            clear = await MediaEncryptionService.instance.decryptBackupMedia(
                raw, key, media['encryption_nonce'] as String);
          }
          if (missing) {
            final encrypted =
                await MediaEncryptionService.instance.encrypt(clear);
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
          media.remove('backup_file');
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
          await cacheMediaFile(url, opened.files[item['backup_file']]!.path);
          if (item['encrypted'] == true) {
            await MediaEncryptionService.instance
                .rememberRestoredKey(url, keys[url]!);
          }
        }
      }
      await repository.refreshAll();
      return result['inserted'] as int;
    } finally {
      await opened.close();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _http.close();
    super.dispose();
  }
}
