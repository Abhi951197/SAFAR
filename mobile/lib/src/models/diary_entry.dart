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
  });

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
  final DateTime entryDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
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
}
