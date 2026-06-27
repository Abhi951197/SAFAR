import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/diary_entry.dart';
import '../models/user_profile.dart';
import 'api_client.dart';

class DiaryRepository extends ChangeNotifier {
  DiaryRepository(this._api);

  final ApiClient _api;
  ApiClient get api => _api;
  final _monthFormat = DateFormat('yyyy-MM');
  final _dayFormat = DateFormat('yyyy-MM-dd');

  UserProfile? currentUser;
  List<DiaryEntry> entries = [];
  Map<String, List<DiaryEntry>> entriesByMonth = {};
  DateTime? lastSuccessfulSync;
  bool isHydrated = false;
  bool isRefreshing = false;
  String? errorMessage;

  String? get _authUserId => Supabase.instance.client.auth.currentUser?.id;
  String get _cachePrefix => 'safar_cache_${_authUserId ?? 'anonymous'}';
  String get _profileKey => '${_cachePrefix}_profile';
  String get _entriesKey => '${_cachePrefix}_entries';
  String get _syncKey => '${_cachePrefix}_last_sync';

  Future<void> initialize() async {
    await hydrateFromCache();
    if (entries.isEmpty && currentUser == null) {
      isRefreshing = true;
      notifyListeners();
    }
    await refreshAll(silent: true);
  }

  Future<void> hydrateFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString(_profileKey);
    final entriesJson = prefs.getString(_entriesKey);
    final syncJson = prefs.getString(_syncKey);

    if (profileJson != null) {
      currentUser = UserProfile.fromJson(jsonDecode(profileJson) as Map<String, dynamic>);
    }
    if (entriesJson != null) {
      final decoded = jsonDecode(entriesJson) as List<dynamic>;
      entries = decoded.cast<Map<String, dynamic>>().map(DiaryEntry.fromJson).toList();
      _sortAndIndexEntries();
    }
    if (syncJson != null) {
      lastSuccessfulSync = DateTime.tryParse(syncJson);
    }
    isHydrated = true;
    notifyListeners();
  }

  Future<void> refreshAll({bool silent = false}) async {
    if (!silent) {
      isRefreshing = true;
      errorMessage = null;
      notifyListeners();
    }
    try {
      final results = await Future.wait<dynamic>([
        _api.me(),
        _api.entries(),
      ]);
      currentUser = results[0] as UserProfile;
      entries = results[1] as List<DiaryEntry>;
      lastSuccessfulSync = DateTime.now();
      errorMessage = null;
      _sortAndIndexEntries();
      await _saveCache();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> refreshMonth(DateTime month, {bool prefetchAdjacent = true}) async {
    final key = monthKey(month);
    if (!entriesByMonth.containsKey(key)) {
      entriesByMonth[key] = [];
      notifyListeners();
    }
    try {
      final fetched = await _api.entries(startDate: _monthStart(month), endDate: _monthEnd(month));
      _replaceMonth(key, fetched);
      await _saveCache();
      if (prefetchAdjacent) {
        unawaitedRefreshMonth(DateTime(month.year, month.month - 1), prefetchAdjacent: false);
        unawaitedRefreshMonth(DateTime(month.year, month.month + 1), prefetchAdjacent: false);
      }
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  void unawaitedRefreshMonth(DateTime month, {bool prefetchAdjacent = false}) {
    Future<void>(() => refreshMonth(month, prefetchAdjacent: prefetchAdjacent));
  }

  List<DiaryEntry> entriesForMonth(DateTime month) {
    return List.unmodifiable(entriesByMonth[monthKey(month)] ?? const []);
  }

  Map<String, List<DiaryEntry>> dayIndexForMonth(DateTime month) {
    final result = <String, List<DiaryEntry>>{};
    for (final entry in entriesForMonth(month)) {
      final key = _dayFormat.format(entry.entryDate);
      result.putIfAbsent(key, () => []).add(entry);
    }
    return result;
  }

  Future<DiaryEntry> createEntry(Map<String, dynamic> payload) async {
    final saved = await _api.createEntry(payload);
    _upsertEntry(saved);
    await _saveCache();
    notifyListeners();
    return saved;
  }

  Future<DiaryEntry> updateEntry(String id, Map<String, dynamic> payload) async {
    final saved = await _api.updateEntry(id, payload);
    _upsertEntry(saved);
    await _saveCache();
    notifyListeners();
    return saved;
  }

  Future<void> deleteEntry(DiaryEntry entry) async {
    final previousEntries = List<DiaryEntry>.from(entries);
    _removeEntry(entry.id);
    await _saveCache();
    notifyListeners();
    try {
      await _api.deleteEntry(entry.id);
    } catch (_) {
      entries = previousEntries;
      _sortAndIndexEntries();
      await _saveCache();
      notifyListeners();
      rethrow;
    }
  }

  Future<UserProfile> updateProfile({String? name, String? avatarUrl}) async {
    final saved = await _api.updateProfile(name: name, avatarUrl: avatarUrl);
    currentUser = saved;
    await _saveCache();
    notifyListeners();
    return saved;
  }

  Future<void> clearMemory() async {
    currentUser = null;
    entries = [];
    entriesByMonth = {};
    lastSuccessfulSync = null;
    isHydrated = false;
    errorMessage = null;
    notifyListeners();
  }

  String monthKey(DateTime month) => _monthFormat.format(DateTime(month.year, month.month));

  void _upsertEntry(DiaryEntry entry) {
    final index = entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      entries.add(entry);
    } else {
      entries[index] = entry;
    }
    _sortAndIndexEntries();
  }

  void _removeEntry(String id) {
    entries = entries.where((entry) => entry.id != id).toList();
    _sortAndIndexEntries();
  }

  void _replaceMonth(String key, List<DiaryEntry> fetched) {
    entries = [
      for (final entry in entries)
        if (monthKey(entry.entryDate) != key) entry,
      ...fetched,
    ];
    _sortAndIndexEntries();
  }

  void _sortAndIndexEntries() {
    entries.sort((a, b) {
      final dateCompare = b.entryDate.compareTo(a.entryDate);
      if (dateCompare != 0) return dateCompare;
      return b.createdAt.compareTo(a.createdAt);
    });
    entriesByMonth = {};
    for (final entry in entries) {
      entriesByMonth.putIfAbsent(monthKey(entry.entryDate), () => []).add(entry);
    }
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = currentUser;
    if (profile != null) {
      await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    }
    await prefs.setString(_entriesKey, jsonEncode(entries.map((entry) => entry.toJson()).toList()));
    final sync = lastSuccessfulSync;
    if (sync != null) {
      await prefs.setString(_syncKey, sync.toIso8601String());
    }
  }

  DateTime _monthStart(DateTime month) => DateTime(month.year, month.month);

  DateTime _monthEnd(DateTime month) => DateTime(month.year, month.month + 1, 0);
}
