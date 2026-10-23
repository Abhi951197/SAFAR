import 'dart:io';
import '../models/diary_entry.dart';

class StagedBackupMedia {
  StagedBackupMedia(
      this.directory, this.files, this.keys, this.locked, this.missing);
  final Directory directory;
  final Map<String, File> files;
  final Map<String, String> keys;
  final int locked, missing;
  Future<void> close() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

/// Preserve every available attachment even when its old decryption key is lost.
/// Failures are recorded in the authenticated manifest, never hidden as success.
Future<StagedBackupMedia> stageBackupMedia({
  required List<Map<String, dynamic>> media,
  required Directory directory,
  required Future<Stream<List<int>>> Function(String url) sourceFor,
  required Future<String> Function(EntryMedia media) keyFor,
  required Future<void> Function(File file, String key, String nonce) verify,
  void Function(int current, int total)? onProgress,
}) async {
  await directory.create(recursive: true);
  final files = <String, File>{};
  final keys = <String, String>{};
  var locked = 0, missing = 0;
  try {
    for (var i = 0; i < media.length; i++) {
      onProgress?.call(i + 1, media.length);
      final item = media[i];
      final url = item['url'] as String;
      final name = 'media/$i';
      final file = File('${directory.path}/attachment-$i.bin');
      try {
        await (await sourceFor(url)).pipe(file.openWrite());
      } on FileSystemException {
        rethrow; // Disk failures must not rotate away a previous phone backup.
      } catch (_) {
        if (await file.exists()) await file.delete();
        item['backup_missing'] = true;
        item['backup_issue'] = 'download_unavailable';
        item.remove('backup_file');
        missing++;
        continue;
      }
      item['backup_file'] = name;
      files[name] = file;
      if (item['encrypted'] == true) {
        String? key;
        try {
          key = await keyFor(EntryMedia.fromJson(item));
        } catch (_) {/* Preserve locked bytes below. */}
        if (key != null) {
          try {
            await verify(file, key, item['encryption_nonce'] as String);
          } catch (_) {
            key = null;
          }
        }
        if (key == null) {
          item['backup_locked'] = true;
          item['backup_issue'] = 'original_key_unavailable';
          locked++;
        } else {
          keys[url] = key;
        }
      }
    }
    return StagedBackupMedia(directory, files, keys, locked, missing);
  } catch (_) {
    if (await directory.exists()) await directory.delete(recursive: true);
    rethrow;
  }
}
