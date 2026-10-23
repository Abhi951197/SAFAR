import 'package:flutter/foundation.dart';
import '../models/backup_record.dart';
import 'api_client.dart';
import 'diary_repository.dart';

class PersonalBackupService extends ChangeNotifier {
  PersonalBackupService(ApiClient api, DiaryRepository repository);
  bool get waitingForDrive => false;
  void cancelDriveConnection() {}
  bool get supported => false;
  bool get busy => false;
  bool get autoEnabled => false;
  bool get driveEnabled => false;
  bool get driveReady => false;
  String get phase => '';
  String? get warning => null;
  String? get error => null;
  DateTime? get lastDriveBackup => null;
  List<BackupRecord> get localBackups => const [];
  Future<void> initialize() async {}
  void scheduleBackup() {}
  Future<void> setAutoEnabled(bool enabled) async {}
  Future<void> disconnectDrive() async {}
  Future<void> connectDrive() async => throw UnsupportedError(
      'Use the Android app for phone and Drive backups.');
  Future<BackupRecord> backup(String password, {bool remember = true}) async =>
      throw UnsupportedError('Use Android.');
  Future<bool> saveCopy(BackupRecord record) async => false;
  Future<int?> restoreFromPhone(String password) async => null;
  Future<List<DriveBackup>> listDriveBackups() async => [];
  Future<int> restoreFromDrive(DriveBackup backup, String password) async => 0;
}
