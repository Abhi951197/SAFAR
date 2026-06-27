import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/diary_entry.dart';
import '../theme/app_theme.dart';

class EntryCard extends StatelessWidget {
  const EntryCard({required this.entry, required this.onTap, super.key});

  final DiaryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final coverImage = entry.imageMedia.isNotEmpty
        ? entry.imageMedia.first.url
        : entry.imageUrl;
    final hasVideo = entry.videoMedia.isNotEmpty || entry.videoUrl != null;
    final hasAudio = entry.audioMedia.isNotEmpty || entry.audioUrl != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: coverImage == null
                      ? Container(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.auto_stories,
                              color: AppTheme.primary),
                        )
                      : Image.network(coverImage, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(entry.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.35)),
                    const SizedBox(height: 6),
                    Text(DateFormat('MMM d, yyyy').format(entry.entryDate),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                    if (hasVideo || hasAudio) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (entry.imageMedia.length > 1)
                            Text('${entry.imageMedia.length} photos',
                                style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                          if (hasVideo)
                            const Icon(Icons.videocam_outlined,
                                size: 15, color: AppTheme.primary),
                          if (hasAudio)
                            const Icon(Icons.mic_none,
                                size: 15, color: AppTheme.primary),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
