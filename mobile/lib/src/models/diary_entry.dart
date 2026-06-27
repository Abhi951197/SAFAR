class EntryMedia {
  EntryMedia({
    this.id,
    this.entryId,
    required this.mediaType,
    required this.url,
    this.publicId,
    required this.sortOrder,
    this.createdAt,
  });

  final String? id;
  final String? entryId;
  final String mediaType;
  final String url;
  final String? publicId;
  final int sortOrder;
  final DateTime? createdAt;

  factory EntryMedia.fromJson(Map<String, dynamic> json) {
    return EntryMedia(
      id: json['id'] as String?,
      entryId: json['entry_id'] as String?,
      mediaType: json['media_type'] as String,
      url: json['url'] as String,
      publicId: json['public_id'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (entryId != null) 'entry_id': entryId,
      'media_type': mediaType,
      'url': url,
      'public_id': publicId,
      'sort_order': sortOrder,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}

class DiaryEntry {
  DiaryEntry({
    required this.id,
    required this.userId,
    required this.title,
    required this.entryType,
    required this.entryDate,
    required this.createdAt,
    required this.updatedAt,
    this.content,
    this.mood,
    this.energy,
    this.bestMoment,
    this.challenge,
    this.imageUrl,
    this.imagePublicId,
    this.videoUrl,
    this.videoPublicId,
    this.audioUrl,
    this.audioPublicId,
    List<EntryMedia>? media,
  }) : media = _mergedMedia(media, imageUrl, imagePublicId, videoUrl,
            videoPublicId, audioUrl, audioPublicId);

  final String id;
  final String userId;
  final String title;
  final String? content;
  final String entryType;
  final String? mood;
  final int? energy;
  final String? bestMoment;
  final String? challenge;
  final String? imageUrl;
  final String? imagePublicId;
  final String? videoUrl;
  final String? videoPublicId;
  final String? audioUrl;
  final String? audioPublicId;
  final List<EntryMedia> media;
  final DateTime entryDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    final mediaJson = json['media'] as List<dynamic>? ?? const [];
    return DiaryEntry(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      content: json['content'] as String?,
      entryType: json['entry_type'] as String,
      mood: json['mood'] as String?,
      energy: json['energy'] as int?,
      bestMoment: json['best_moment'] as String?,
      challenge: json['challenge'] as String?,
      imageUrl: json['image_url'] as String?,
      imagePublicId: json['image_public_id'] as String?,
      videoUrl: json['video_url'] as String?,
      videoPublicId: json['video_public_id'] as String?,
      audioUrl: json['audio_url'] as String?,
      audioPublicId: json['audio_public_id'] as String?,
      media: mediaJson
          .cast<Map<String, dynamic>>()
          .map(EntryMedia.fromJson)
          .toList(),
      entryDate: DateTime.parse(json['entry_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'content': content,
      'entry_type': entryType,
      'mood': mood,
      'energy': energy,
      'best_moment': bestMoment,
      'challenge': challenge,
      'image_url': imageUrl,
      'image_public_id': imagePublicId,
      'video_url': videoUrl,
      'video_public_id': videoPublicId,
      'audio_url': audioUrl,
      'audio_public_id': audioPublicId,
      'media': media.map((item) => item.toJson()).toList(),
      'entry_date': _dateOnly(entryDate),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static String _dateOnly(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String get preview {
    final source = entryType == 'quick'
        ? [bestMoment, challenge].whereType<String>().join(' ')
        : content ?? '';
    if (source.length <= 90) return source;
    return '${source.substring(0, 90)}...';
  }

  List<EntryMedia> get imageMedia =>
      media.where((item) => item.mediaType == 'image').toList();
  List<EntryMedia> get videoMedia =>
      media.where((item) => item.mediaType == 'video').toList();
  List<EntryMedia> get audioMedia =>
      media.where((item) => item.mediaType == 'audio').toList();

  static List<EntryMedia> _mergedMedia(
    List<EntryMedia>? source,
    String? imageUrl,
    String? imagePublicId,
    String? videoUrl,
    String? videoPublicId,
    String? audioUrl,
    String? audioPublicId,
  ) {
    final merged = <EntryMedia>[...?source];
    final existing =
        merged.map((item) => '${item.mediaType}:${item.url}').toSet();
    void addLegacy(String type, String? url, String? publicId) {
      if (url == null || existing.contains('$type:$url')) return;
      merged.add(EntryMedia(
          mediaType: type,
          url: url,
          publicId: publicId,
          sortOrder: merged.length));
    }

    addLegacy('image', imageUrl, imagePublicId);
    addLegacy('video', videoUrl, videoPublicId);
    addLegacy('audio', audioUrl, audioPublicId);
    merged.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return List.unmodifiable(merged);
  }
}
