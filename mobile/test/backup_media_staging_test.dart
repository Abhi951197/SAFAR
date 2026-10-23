import 'dart:convert';
import 'dart:io';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:safar/src/services/backup_codec_io.dart';
import 'package:safar/src/services/backup_media_staging_io.dart';

void main() {
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('safar-staging-');
  });
  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
      'missing and wrong device keys preserve locked bytes and do not block diary backup',
      () async {
    final cipher = AesGcm.with256bits();
    final key = List<int>.filled(32, 7), nonce = List<int>.filled(12, 2);
    final box = await cipher.encrypt(utf8.encode('a photo'),
        secretKey: SecretKey(key), nonce: nonce);
    final bytes = [...box.cipherText, ...box.mac.bytes];
    final media = [
      for (final name in ['current', 'lost', 'wrong', 'unavailable'])
        <String, dynamic>{
          'media_type': 'image',
          'url': 'https://example.com/$name',
          'encrypted': true,
          'encryption_nonce': base64Encode(nonce),
          'sort_order': 0,
        }
    ];
    final staged = await stageBackupMedia(
        media: media,
        directory: Directory('${root.path}/staged'),
        sourceFor: (url) async {
          if (url.endsWith('unavailable')) throw const HttpException('404');
          return Stream.value(bytes);
        },
        keyFor: (item) async {
          if (item.url.endsWith('lost')) {
            throw StateError('No original device key');
          }
          return base64Encode(
              item.url.endsWith('wrong') ? List<int>.filled(32, 9) : key);
        },
        verify: (file, encodedKey, encodedNonce) async {
          final raw = await file.readAsBytes();
          await cipher.decrypt(
              SecretBox(raw.sublist(0, raw.length - 16),
                  nonce: base64Decode(encodedNonce),
                  mac: Mac(raw.sublist(raw.length - 16))),
              secretKey: SecretKey(base64Decode(encodedKey)));
        });
    expect(staged.locked, 2);
    expect(staged.missing, 1);
    expect(staged.keys.keys, ['https://example.com/current']);
    expect(media[1]['backup_locked'], true);
    expect(media[2]['backup_locked'], true);
    expect(media[3]['backup_missing'], true);
    expect(media[3]['backup_file'], isNull);
    final manifest = {
      'backup_kind': 'personal-v2',
      'full_media_backup': false,
      'media_keys': staged.keys,
      'locked_media_count': staged.locked,
      'missing_media_count': staged.missing,
      'entries': [
        {'content': 'My diary is still safe', 'media': media}
      ]
    };
    Stream<List<int>> records() async* {
      yield* BackupCodec.record(
          'manifest.json', Stream.value(utf8.encode(jsonEncode(manifest))));
      for (final record in staged.files.entries) {
        yield* BackupCodec.record(record.key, record.value.openRead());
      }
      yield BackupCodec.lengthBytes(0);
    }

    final archive = File('${root.path}/backup.safar');
    await BackupCodec.write(archive, 'test-backup-password', records());
    await staged.close();
    final opened = await BackupCodec.open(
        archive, 'test-backup-password', Directory('${root.path}/restored'));
    expect((opened.manifest['entries'] as List).first['content'],
        'My diary is still safe');
    expect(opened.files.length, 3);
    expect(await opened.files['media/1']!.readAsBytes(), bytes);
    expect(await opened.files['media/2']!.readAsBytes(), bytes);
    expect(opened.manifest['full_media_backup'], false);
    await opened.close();
  });

  test('a diary with no media key can still preserve its only attachment',
      () async {
    final media = [
      <String, dynamic>{
        'media_type': 'image',
        'url': 'https://example.com/old',
        'encrypted': true
      }
    ];
    final staged = await stageBackupMedia(
        media: media,
        directory: Directory('${root.path}/only-locked'),
        sourceFor: (_) async => Stream.value([1, 2, 3, 4]),
        keyFor: (_) async => throw StateError('Missing key'),
        verify: (_, __, ___) async => fail('No key should be invented'));
    expect(staged.files.length, 1);
    expect(staged.keys, isEmpty);
    expect(staged.locked, 1);
    expect(await staged.files['media/0']!.readAsBytes(), [1, 2, 3, 4]);
    await staged.close();
  });

  test('disk failure aborts staging and removes incomplete temporary files',
      () async {
    await expectLater(
        stageBackupMedia(
            media: [
              {'media_type': 'image', 'url': 'https://example.com/old'}
            ],
            directory: Directory('${root.path}/disk-failure'),
            sourceFor: (_) async => throw const FileSystemException('No space'),
            keyFor: (_) async => 'unused',
            verify: (_, __, ___) async {}),
        throwsA(isA<FileSystemException>()));
    expect(await Directory('${root.path}/disk-failure').exists(), false);
  });
}
