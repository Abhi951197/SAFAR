import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

Future<File> cachedMediaFile(String url) async {
  final root = await getApplicationSupportDirectory();
  final folder = Directory('${root.path}/restored_media');
  await folder.create(recursive: true);
  return File('${folder.path}/${sha256.convert(utf8.encode(url))}.bin');
}

Future<Uint8List?> readCachedMedia(String url) async {
  final file = await cachedMediaFile(url);
  return await file.exists() ? file.readAsBytes() : null;
}

Future<void> cacheMediaFile(String url, String sourcePath) async {
  final destination = await cachedMediaFile(url);
  final temporary = await File(sourcePath).copy('${destination.path}.tmp');
  await temporary.rename(destination.path);
}
