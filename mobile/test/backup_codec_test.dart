import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:safar/src/services/backup_codec_io.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('safar-codec-test-');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });
  Stream<List<int>> records({bool terminate = true}) async* {
    yield* BackupCodec.record(
        'manifest.json',
        Stream.value(utf8
            .encode(jsonEncode({'full_media_backup': true, 'entries': []}))));
    yield* BackupCodec.record(
        'media/0', Stream.value(List<int>.generate(1200000, (i) => i % 251)));
    if (terminate) yield BackupCodec.lengthBytes(0);
  }

  const password = 'test-backup-password';
  test('round trips streamed media larger than a frame', () async {
    final file = File('${root.path}/backup.safar');
    await BackupCodec.write(file, password, records());
    final opened = await BackupCodec.open(
        file, password, Directory('${root.path}/opened'));
    expect(opened.manifest['full_media_backup'], true);
    final media = await opened.files['media/0']!.readAsBytes();
    expect(media.length, 1200000);
    expect(media[1199999], 1199999 % 251);
    await opened.close();
  });
  test('rejects wrong password and tampering without leaving decrypted files',
      () async {
    final file = File('${root.path}/backup.safar');
    await BackupCodec.write(file, password, records());
    final stage = Directory('${root.path}/bad');
    await expectLater(
        BackupCodec.open(file, 'wrong-password', stage), throwsFormatException);
    expect(await stage.exists(), false);
    final bytes = await file.readAsBytes();
    bytes[bytes.length - 20] ^= 1;
    await file.writeAsBytes(bytes);
    await expectLater(
        BackupCodec.open(file, password, stage), throwsFormatException);
    expect(await stage.exists(), false);
  });
  test('rejects authenticated but incomplete record stream', () async {
    final file = File('${root.path}/backup.safar');
    await BackupCodec.write(file, password, records(terminate: false));
    await expectLater(
        BackupCodec.open(file, password, Directory('${root.path}/bad')),
        throwsFormatException);
  });
  test('failed media download leaves no completed or partial backup', () async {
    final file = File('${root.path}/backup.safar');
    Stream<List<int>> failure() async* {
      yield [1, 2];
      throw const HttpException('offline');
    }

    await expectLater(BackupCodec.write(file, password, failure()),
        throwsA(isA<HttpException>()));
    expect(await file.exists(), false);
    expect(await File('${file.path}.partial').exists(), false);
  });
}
