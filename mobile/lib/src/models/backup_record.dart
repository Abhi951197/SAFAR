class BackupRecord {
  const BackupRecord(
      {required this.path,
      required this.name,
      required this.createdAt,
      required this.bytes,
      required this.entries,
      required this.media,
      this.lockedMedia = 0,
      this.missingMedia = 0});
  final String path, name;
  final DateTime createdAt;
  final int bytes, entries, media, lockedMedia, missingMedia;
  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'created_at': createdAt.toIso8601String(),
        'bytes': bytes,
        'entries': entries,
        'locked_media': lockedMedia,
        'missing_media': missingMedia,
        'media': media
      };
  factory BackupRecord.fromJson(Map<String, dynamic> j) => BackupRecord(
      path: j['path'] as String,
      name: j['name'] as String,
      createdAt: DateTime.parse(j['created_at'] as String),
      bytes: j['bytes'] as int,
      entries: j['entries'] as int,
      media: j['media'] as int,
      lockedMedia: j['locked_media'] as int? ?? 0,
      missingMedia: j['missing_media'] as int? ?? 0);
}

class DriveBackup {
  const DriveBackup(
      {required this.id,
      required this.name,
      required this.modifiedAt,
      required this.bytes});
  final String id, name;
  final DateTime modifiedAt;
  final int bytes;
}
