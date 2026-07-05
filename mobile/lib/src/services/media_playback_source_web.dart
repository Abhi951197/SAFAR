// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../models/diary_entry.dart';
import 'media_encryption_service.dart';

Future<void> setAudioSource(AudioPlayer player, EntryMedia media) async {
  if (!media.encrypted) {
    await player.setUrl(media.url);
    return;
  }
  await player.setUrl(await _blobUrl(media));
}

Future<VideoPlayerController> createVideoController(EntryMedia media) async {
  if (!media.encrypted) {
    return VideoPlayerController.networkUrl(Uri.parse(media.url));
  }
  return VideoPlayerController.networkUrl(Uri.parse(await _blobUrl(media)));
}

Future<String> _blobUrl(EntryMedia media) async {
  final bytes = await MediaEncryptionService.instance.decryptMedia(media);
  final blob =
      html.Blob([bytes], media.contentType ?? 'application/octet-stream');
  return html.Url.createObjectUrlFromBlob(blob);
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
