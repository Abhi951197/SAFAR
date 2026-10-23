import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart' as hashes;

import '../models/diary_entry.dart';
import 'media_local_cache.dart';

class EncryptedMediaPayload {
  const EncryptedMediaPayload({
    required this.bytes,
    required this.nonce,
    required this.version,
  });

  final Uint8List bytes;
  final String nonce;
  final int version;
}

class MediaEncryptionService {
  MediaEncryptionService._();

  static final instance = MediaEncryptionService._();
  static const _keyName = 'safar_media_encryption_key_v1';
  static const encryptionVersion = 1;
  static const _macLength = 16;

  final _storage = const FlutterSecureStorage();
  final _algorithm = AesGcm.with256bits();
  final _cache = <String, Uint8List>{};

  Future<EncryptedMediaPayload> encrypt(Uint8List plainBytes) async {
    final nonceBytes = _randomBytes(12);
    final secretKey = await _secretKey();
    final box = await _algorithm.encrypt(
      plainBytes,
      secretKey: secretKey,
      nonce: nonceBytes,
    );
    return EncryptedMediaPayload(
      bytes: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
      nonce: base64Encode(nonceBytes),
      version: encryptionVersion,
    );
  }

  Future<Uint8List> decryptMedia(EntryMedia media) async {
    final cached = _cache[media.url];
    if (cached != null) return cached;
    if (!media.encrypted) {
      final bytes = await _download(media.url);
      _cache[media.url] = bytes;
      return bytes;
    }
    final nonce = media.encryptionNonce;
    if (nonce == null || nonce.isEmpty) {
      throw Exception('Encrypted media metadata is missing.');
    }
    final encryptedBytes = await _download(media.url);
    if (encryptedBytes.length <= _macLength) {
      throw Exception('Encrypted media is invalid.');
    }
    final cipherText =
        encryptedBytes.sublist(0, encryptedBytes.length - _macLength);
    final macBytes = encryptedBytes.sublist(encryptedBytes.length - _macLength);
    final clearBytes = await _algorithm.decrypt(
      SecretBox(
        cipherText,
        nonce: base64Decode(nonce),
        mac: Mac(macBytes),
      ),
      secretKey: SecretKey(base64Decode(await keyForBackup(media))),
    );
    final bytes = Uint8List.fromList(clearBytes);
    _cache[media.url] = bytes;
    return bytes;
  }

  Future<Uint8List> _download(String url) async {
    final cached = await readCachedMedia(url);
    if (cached != null) return cached;
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Media could not be downloaded.');
    }
    return response.bodyBytes;
  }

  String _mediaKeyName(String url) =>
      'safar_media_key_${hashes.sha256.convert(utf8.encode(url))}';

  Future<String> keyForBackup(EntryMedia media) async {
    final value = await _storage.read(key: _mediaKeyName(media.url)) ??
        await _storage.read(key: _keyName);
    if (value == null || base64Decode(value).length != 32) {
      throw Exception(
          'This phone is missing a media key. Keep the original app installed and use its backup.');
    }
    return value;
  }

  Future<void> rememberRestoredKey(String url, String encodedKey) async {
    if (base64Decode(encodedKey).length != 32) {
      throw const FormatException('Invalid media key');
    }
    await _storage.write(key: _mediaKeyName(url), value: encodedKey);
    _cache.remove(url);
  }

  Future<Uint8List> decryptBackupMedia(
      Uint8List bytes, String key, String nonce) async {
    if (bytes.length <= _macLength) {
      throw const FormatException('Invalid encrypted media');
    }
    return Uint8List.fromList(await _algorithm.decrypt(
        SecretBox(bytes.sublist(0, bytes.length - _macLength),
            nonce: base64Decode(nonce),
            mac: Mac(bytes.sublist(bytes.length - _macLength))),
        secretKey: SecretKey(base64Decode(key))));
  }

  Future<void> verifyBackupMedia(Stream<List<int>> ciphertext, String key,
      String nonce, List<int> mac) async {
    await for (final _ in _algorithm.decryptStream(ciphertext,
        secretKey: SecretKey(base64Decode(key)),
        nonce: base64Decode(nonce),
        mac: Mac(mac))) {
      // Authenticate without retaining the decrypted attachment in memory.
    }
  }

  Future<SecretKey> _secretKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.isNotEmpty) {
      return SecretKey(base64Decode(existing));
    }
    final bytes = _randomBytes(32);
    await _storage.write(key: _keyName, value: base64Encode(bytes));
    return SecretKey(bytes);
  }

  Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
        List<int>.generate(length, (_) => random.nextInt(256)));
  }
}
