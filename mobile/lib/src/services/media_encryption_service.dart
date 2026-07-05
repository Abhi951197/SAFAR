import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/diary_entry.dart';

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
      final response = await http.get(Uri.parse(media.url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Media could not be downloaded.');
      }
      final bytes = response.bodyBytes;
      _cache[media.url] = bytes;
      return bytes;
    }
    final nonce = media.encryptionNonce;
    if (nonce == null || nonce.isEmpty) {
      throw Exception('Encrypted media metadata is missing.');
    }
    final response = await http.get(Uri.parse(media.url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Encrypted media could not be downloaded.');
    }
    final encryptedBytes = response.bodyBytes;
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
      secretKey: await _secretKey(),
    );
    final bytes = Uint8List.fromList(clearBytes);
    _cache[media.url] = bytes;
    return bytes;
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
