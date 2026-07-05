import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/diary_entry.dart';
import '../models/user_profile.dart';

typedef UploadProgressCallback = void Function(int sentBytes, int totalBytes);

class ApiClient {
  ApiClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  final _dateFormat = DateFormat('yyyy-MM-dd');

  Uri _uri(String path, [Map<String, String?> query = const {}]) {
    final base = Uri.parse(AppConfig.apiBaseUrl);
    return base.replace(
      path: '${base.path}${path.startsWith('/') ? path : '/$path'}',
      queryParameters: {
        for (final entry in query.entries)
          if (entry.value != null && entry.value!.isNotEmpty)
            entry.key: entry.value!,
      },
    );
  }

  Future<Map<String, String>> _headers() async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) throw ApiException('Please log in again.');
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<UserProfile> me() async {
    final response =
        await _httpClient.get(_uri('/auth/me'), headers: await _headers());
    return UserProfile.fromJson(_decode(response));
  }

  Future<UserProfile> updateProfile({String? name, String? avatarUrl}) async {
    final response = await _httpClient.patch(
      _uri('/auth/me'),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'avatar_url': avatarUrl}),
    );
    return UserProfile.fromJson(_decode(response));
  }

  Future<List<DiaryEntry>> entries(
      {DateTime? startDate, DateTime? endDate}) async {
    final response = await _httpClient.get(
      _uri('/entries', {
        'start_date': startDate == null ? null : _dateFormat.format(startDate),
        'end_date': endDate == null ? null : _dateFormat.format(endDate),
      }),
      headers: await _headers(),
    );
    final decoded = _decodeList(response);
    return decoded.map(DiaryEntry.fromJson).toList();
  }

  Future<DiaryEntry> createEntry(Map<String, dynamic> payload) async {
    final response = await _httpClient.post(
      _uri('/entries'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return DiaryEntry.fromJson(_decode(response));
  }

  Future<DiaryEntry> updateEntry(
      String id, Map<String, dynamic> payload) async {
    final response = await _httpClient.put(
      _uri('/entries/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return DiaryEntry.fromJson(_decode(response));
  }

  Future<void> deleteEntry(String id) async {
    final response = await _httpClient.delete(_uri('/entries/$id'),
        headers: await _headers());
    if (response.statusCode != 204) _throwForResponse(response);
  }

  Future<String> summarizeDiary(String text) async {
    final response = await _httpClient.post(
      _uri('/ai/summarize'),
      headers: await _headers(),
      body: jsonEncode({'text': text}),
    );
    return _decode(response)['summary'] as String;
  }

  Future<String> enhanceDiaryText(String text) async {
    final response = await _httpClient.post(
      _uri('/ai/enhance'),
      headers: await _headers(),
      body: jsonEncode({'text': text}),
    );
    return _decode(response)['enhanced_text'] as String;
  }

  Future<List<String>> suggestDiaryTitles(String text) async {
    final response = await _httpClient.post(
      _uri('/ai/suggest-titles'),
      headers: await _headers(),
      body: jsonEncode({'text': text}),
    );
    final decoded = _decode(response);
    return (decoded['titles'] as List<dynamic>).cast<String>();
  }

  Future<Map<String, String>> uploadImage(
    XFile file, {
    UploadProgressCallback? onProgress,
  }) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) throw ApiException('Please log in again.');
    final response = await _sendMultipart(
      path: '/upload/image',
      fieldName: 'image',
      file: file,
      token: token,
      mediaType: MediaType('image', _imageSubtype(file.name)),
      onProgress: onProgress,
    );
    final decoded = _decode(response);
    return {
      'image_url': decoded['image_url'] as String,
      'image_public_id': decoded['image_public_id'] as String,
    };
  }

  Future<Map<String, String>> uploadVideo(
    XFile file, {
    UploadProgressCallback? onProgress,
  }) =>
      _uploadMedia(
        file: file,
        path: '/upload/video',
        fieldName: 'video',
        mediaType: MediaType('video', _videoSubtype(file.name)),
        onProgress: onProgress,
      );

  Future<Map<String, String>> uploadAudio(
    XFile file, {
    UploadProgressCallback? onProgress,
  }) =>
      _uploadMedia(
        file: file,
        path: '/upload/audio',
        fieldName: 'audio',
        mediaType: MediaType('audio', _audioSubtype(file.name)),
        onProgress: onProgress,
      );

  Future<Map<String, String>> _uploadMedia({
    required XFile file,
    required String path,
    required String fieldName,
    required MediaType mediaType,
    UploadProgressCallback? onProgress,
  }) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) throw ApiException('Please log in again.');
    final response = await _sendMultipart(
      path: path,
      fieldName: fieldName,
      file: file,
      token: token,
      mediaType: mediaType,
      onProgress: onProgress,
    );
    final decoded = _decode(response);
    return {
      'url': decoded['url'] as String,
      'public_id': decoded['public_id'] as String,
    };
  }

  Future<http.Response> _sendMultipart({
    required String path,
    required String fieldName,
    required XFile file,
    required String token,
    required MediaType mediaType,
    UploadProgressCallback? onProgress,
  }) async {
    final totalBytes = await file.length();
    var sentBytes = 0;
    final stream = file.openRead().map((chunk) {
      sentBytes += chunk.length;
      onProgress?.call(sentBytes, totalBytes);
      return chunk;
    });
    final request = http.MultipartRequest('POST', _uri(path));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile(
      fieldName,
      stream,
      totalBytes,
      filename: file.name,
      contentType: mediaType,
    ));
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  String _imageSubtype(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpeg';
    if (lower.endsWith('.webp')) return 'webp';
    return 'png';
  }

  String _videoSubtype(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mov')) return 'quicktime';
    if (lower.endsWith('.webm')) return 'webm';
    return 'mp4';
  }

  String _audioSubtype(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mp3')) return 'mpeg';
    if (lower.endsWith('.m4a')) return 'mp4';
    if (lower.endsWith('.aac')) return 'aac';
    if (lower.endsWith('.wav')) return 'wav';
    if (lower.endsWith('.ogg')) return 'ogg';
    return 'webm';
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwForResponse(response);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _decodeList(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwForResponse(response);
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    return list.cast<Map<String, dynamic>>();
  }

  Never _throwForResponse(http.Response response) {
    String fallback() => response.body.isEmpty
        ? 'Request failed with status ${response.statusCode}.'
        : response.body;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = decoded['detail'];
      if (detail is List) {
        throw ApiException(detail.map((item) => item.toString()).join('\n'));
      }
      throw ApiException(detail?.toString() ?? 'Request failed.');
    } on FormatException {
      throw ApiException(fallback());
    } on TypeError {
      throw ApiException(fallback());
    }
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
