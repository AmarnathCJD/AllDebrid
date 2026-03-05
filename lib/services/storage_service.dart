import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download.dart';

class StorageService {
  static const String _apiKeyKey = 'api_key';
  static const String _downloadsKey = 'downloads';
  static const String _settingsKey = 'settings';
  static const String _historyKey = 'history';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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
    final settings = getSettings();
    settings[key] = value;
    await prefs.setString(_settingsKey, jsonEncode(settings));
  }

  Map<String, dynamic> getSettings() {
    final jsonString = prefs.getString(_settingsKey);
    if (jsonString == null) return {};
    return Map<String, dynamic>.from(jsonDecode(jsonString));
  }

  T? getSetting<T>(String key, [T? defaultValue]) {
    final settings = getSettings();
    return settings[key] as T? ?? defaultValue;
  }

  Future<void> addToHistory(String link, String filename) async {
    final history = getHistory();
    history.insert(0, {
      'link': link,
      'filename': filename,
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (history.length > 100) {
      history.removeRange(100, history.length);
    }

    await prefs.setString(_historyKey, jsonEncode(history));
  }

  List<Map<String, dynamic>> getHistory() {
    final jsonString = prefs.getString(_historyKey);
    if (jsonString == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(jsonString));
  }

  Future<void> clearHistory() async {
    await prefs.remove(_historyKey);
  }

  Future<void> clearAll() async {
    await prefs.clear();
  }
}
