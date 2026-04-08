import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download.dart';

class StorageService {
  static const String _apiKeyKey = 'api_key';
  static const String _downloadsKey = 'downloads';
  static const String _settingsKey = 'settings';

  SharedPreferences? _prefs;
  Map<String, dynamic> _settingsCache = <String, dynamic>{};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final rawSettings = _prefs!.getString(_settingsKey);
    if (rawSettings != null && rawSettings.isNotEmpty) {
      _settingsCache = Map<String, dynamic>.from(jsonDecode(rawSettings));
    }
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  Future<void> saveApiKey(String apiKey) async {
    await prefs.setString(_apiKeyKey, apiKey);
  }

  String? getApiKey() {
    return prefs.getString(_apiKeyKey);
  }

  Future<void> clearApiKey() async {
    await prefs.remove(_apiKeyKey);
  }

  bool hasApiKey() {
    final key = getApiKey();
    return key != null && key.isNotEmpty;
  }

  Future<void> saveDownloads(List<Download> downloads) async {
    final jsonList = downloads.map((d) => d.toJson()).toList();
    await prefs.setString(_downloadsKey, jsonEncode(jsonList));
  }

  List<Download> getDownloads() {
    final jsonString = prefs.getString(_downloadsKey);
    if (jsonString == null) return [];

    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((e) => Download.fromJson(e)).toList();
  }

  Future<void> saveSetting(String key, dynamic value) async {
    if (value == null) {
      _settingsCache.remove(key);
    } else {
      _settingsCache[key] = value;
    }
    await prefs.setString(_settingsKey, jsonEncode(_settingsCache));
  }

  Map<String, dynamic> getSettings() {
    return Map<String, dynamic>.from(_settingsCache);
  }

  T? getSetting<T>(String key, [T? defaultValue]) {
    final settings = getSettings();
    return settings[key] as T? ?? defaultValue;
  }

}
