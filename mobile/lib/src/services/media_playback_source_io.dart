import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import '../models/diary_entry.dart';
import 'media_encryption_service.dart';

Future<void> setAudioSource(AudioPlayer player, EntryMedia media) async {
  if (!media.encrypted) {
    await player.setUrl(media.url);
    return;
  }
  final file = await _decryptedTempFile(media);
  await player.setFilePath(file.path);
}

Future<VideoPlayerController> createVideoController(EntryMedia media) async {
  if (!media.encrypted) {
    return VideoPlayerController.networkUrl(Uri.parse(media.url));
  }
  final file = await _decryptedTempFile(media);
  return VideoPlayerController.file(file);
}

Future<File> _decryptedTempFile(EntryMedia media) async {
  final bytes = await MediaEncryptionService.instance.decryptMedia(media);
  final directory = await getTemporaryDirectory();
  final safeId = (media.id ?? media.url.hashCode.toString())
      .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final file = File('${directory.path}/safar-$safeId${extensionFor(media)}');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}

String extensionFor(EntryMedia media) {
  final type = media.contentType ?? '';
  if (type.contains('png')) return '.png';
  if (type.contains('webp')) return '.webp';
  if (type.contains('jpeg') || type.contains('jpg')) return '.jpg';
  if (type.contains('quicktime')) return '.mov';
  if (type.contains('webm')) return '.webm';
  if (type.contains('mp4')) return '.mp4';
  if (type.contains('mpeg')) return '.mp3';
  if (type.contains('wav')) return '.wav';
  if (type.contains('ogg')) return '.ogg';
  if (media.mediaType == 'image') return '.jpg';
  if (media.mediaType == 'audio') return '.m4a';
  return '.mp4';
}
