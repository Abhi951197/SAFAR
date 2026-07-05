import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/diary_entry.dart';
import '../services/media_encryption_service.dart';
import '../theme/app_theme.dart';

class EncryptedMediaImage extends StatelessWidget {
  const EncryptedMediaImage({
    required this.media,
    required this.fit,
    super.key,
  });

  final EntryMedia media;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (!media.encrypted) {
      return Image.network(
        media.url,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
      );
    }
    return FutureBuilder<Uint8List>(
      future: MediaEncryptionService.instance.decryptMedia(media),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ColoredBox(
            color: AppTheme.primary.withValues(alpha: 0.1),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return ColoredBox(
            color: AppTheme.primary.withValues(alpha: 0.1),
            child: const Center(
                child: Icon(Icons.lock_outline, color: AppTheme.primary)),
          );
        }
        return Image.memory(
          snapshot.data!,
          width: double.infinity,
          height: double.infinity,
          fit: fit,
        );
      },
    );
  }
}
