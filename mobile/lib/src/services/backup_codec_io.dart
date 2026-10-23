import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

// Authenticated, streaming format: no complete video/archive is held in memory.
// Header is authenticated as AAD. Decrypted records are read only after MAC verification.
class BackupCodec {
  static final _magic = ascii.encode('SAFAR02\n');
  static final _cipher = AesGcm.with256bits();
  static const iterations = 210000;

  static Uint8List lengthBytes(int length) =>
      (ByteData(4)..setUint32(0, length)).buffer.asUint8List();
  static List<int> randomBytes(int n) =>
      List.generate(n, (_) => Random.secure().nextInt(256));

  static Future<SecretKey> _key(String password, List<int> salt) => Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  static Stream<List<int>> record(String name, Stream<List<int>> data) async* {
    final header = utf8.encode(jsonEncode({'name': name}));
    yield lengthBytes(header.length);
    yield header;
    await for (final chunk in data) {
      for (var offset = 0; offset < chunk.length; offset += 1024 * 1024) {
        final end = min(offset + 1024 * 1024, chunk.length);
        yield lengthBytes(end - offset);
        yield chunk.sublist(offset, end);
      }
    }
    yield lengthBytes(0);
  }

  static Future<void> write(
      File destination, String password, Stream<List<int>> records) async {
    if (password.length < 10) {
      throw const FormatException(
          'Use a backup password of at least 10 characters.');
    }
    final salt = randomBytes(16), nonce = randomBytes(12);
    final header = utf8.encode(jsonEncode({
      'format': 2,
      'kdf': 'PBKDF2-SHA256',
      'iterations': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(nonce)
    }));
    final prefix = <int>[..._magic, ...lengthBytes(header.length), ...header];
    final temporary = File('${destination.path}.partial');
    IOSink? sink;
    try {
      sink = temporary.openWrite();
      sink.add(prefix);
      Mac? mac;
      await for (final chunk in _cipher.encryptStream(records,
          secretKey: await _key(password, salt),
          nonce: nonce,
          aad: prefix,
          onMac: (value) => mac = value)) {
        sink.add(chunk);
        await sink.flush();
      }
      if (mac == null) {
        throw const FormatException('Backup encryption did not finish.');
      }
      sink.add(mac!.bytes);
      await sink.flush();
      await sink.close();
      sink = null;
      await temporary.rename(destination.path);
    } catch (_) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      if (await temporary.exists()) await temporary.delete();
      rethrow;
    }
  }

  static Future<Uint8List> _read(RandomAccessFile file, int length) async {
    final output = BytesBuilder(copy: false);
    var remaining = length;
    while (remaining > 0) {
      final bytes = await file.read(remaining);
      if (bytes.isEmpty) throw const FormatException('Backup is incomplete.');
      output.add(bytes);
      remaining -= bytes.length;
    }
    return output.takeBytes();
  }

  static Future<int> _length(RandomAccessFile file) async =>
      ByteData.sublistView(await _read(file, 4)).getUint32(0);

  static Future<OpenedBackup> open(
      File source, String password, Directory staging) async {
    await staging.create(recursive: true);
    final decrypted = File('${staging.path}/payload.tmp');
    final input = await source.open();
    try {
      final magic = await _read(input, _magic.length);
      if (ascii.decode(magic) != 'SAFAR02\n') {
        throw const FormatException('This is not a Safar backup.');
      }
      final headerLength = await _length(input);
      if (headerLength > 8192) {
        throw const FormatException('Invalid backup header.');
      }
      final rawHeader = await _read(input, headerLength);
      final h = jsonDecode(utf8.decode(rawHeader)) as Map<String, dynamic>;
      if (h['format'] != 2 ||
          h['kdf'] != 'PBKDF2-SHA256' ||
          h['iterations'] != iterations) {
        throw const FormatException('Unsupported backup version.');
      }
      final salt = base64Decode(h['salt'] as String),
          nonce = base64Decode(h['nonce'] as String);
      if (salt.length != 16 || nonce.length != 12) {
        throw const FormatException('Invalid backup header.');
      }
      final start = await input.position(), end = await input.length();
      if (end < start + 16) {
        throw const FormatException('Backup is incomplete.');
      }
      await input.setPosition(end - 16);
      final mac = Mac(await _read(input, 16));
      await input.close();
      final sink = decrypted.openWrite();
      try {
        await for (final chunk in _cipher.decryptStream(
            source.openRead(start, end - 16),
            secretKey: await _key(password, salt),
            nonce: nonce,
            mac: mac,
            aad: [...magic, ...lengthBytes(headerLength), ...rawHeader])) {
          sink.add(chunk);
          await sink.flush();
        }
        await sink.close();
      } catch (_) {
        try {
          await sink.close();
        } catch (_) {}
        throw const FormatException('Wrong backup password or damaged backup.');
      }
      final reader = await decrypted.open();
      final files = <String, File>{};
      Map<String, dynamic>? manifest;
      try {
        for (var i = 0;; i++) {
          if (i > 50000) {
            throw const FormatException('Too many files in backup.');
          }
          final metadataLength = await _length(reader);
          if (metadataLength == 0) break;
          if (metadataLength > 65536) {
            throw const FormatException('Invalid backup record.');
          }
          final meta =
              jsonDecode(utf8.decode(await _read(reader, metadataLength)))
                  as Map<String, dynamic>;
          final name = meta['name'] as String;
          if (name != 'manifest.json' &&
              !RegExp(r'^media/[0-9]+$').hasMatch(name)) {
            throw const FormatException('Invalid backup filename.');
          }
          if (files.containsKey(name) ||
              (name == 'manifest.json' && manifest != null)) {
            throw const FormatException('Duplicate backup record.');
          }
          // Generated extraction paths never use an untrusted archive filename.
          final file = File('${staging.path}/record-$i.bin');
          final out = file.openWrite();
          var size = 0;
          try {
            while (true) {
              final length = await _length(reader);
              if (length == 0) break;
              if (length > 1024 * 1024) {
                throw const FormatException('Invalid backup chunk.');
              }
              size += length;
              if (name == 'manifest.json' && size > 32 * 1024 * 1024) {
                throw const FormatException('Backup manifest is too large.');
              }
              out.add(await _read(reader, length));
              await out.flush();
            }
          } finally {
            await out.close();
          }
          if (name == 'manifest.json') {
            manifest =
                jsonDecode(await file.readAsString()) as Map<String, dynamic>;
          } else {
            files[name] = file;
          }
        }
        if (await reader.position() != await reader.length() ||
            manifest == null) {
          throw const FormatException('Invalid backup contents.');
        }
      } finally {
        await reader.close();
      }
      await decrypted.delete();
      return OpenedBackup(manifest, files, staging);
    } catch (_) {
      try {
        await input.close();
      } catch (_) {}
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    }
  }
}

class OpenedBackup {
  OpenedBackup(this.manifest, this.files, this.directory);
  final Map<String, dynamic> manifest;
  final Map<String, File> files;
  final Directory directory;
  Future<void> close() async {
    await directory.delete(recursive: true);
  }
}
