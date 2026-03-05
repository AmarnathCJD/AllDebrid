import 'dart:convert';
import '../models/models.dart';
import '../services/services.dart';
import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

/// App Provider - Main state management for the app
class AppProvider extends ChangeNotifier {
  final StorageService _storageService;
  AllDebridService? _allDebridService;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  User? _user;
  HostsResponse? _hosts;
  List<ImdbSearchResult> _watchlist = [];

  bool _isDarkMode = true;
  Color _primaryColor = AppTheme.primaryColor;

  AppProvider({required StorageService storageService})
      : _storageService = storageService;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;
  User? get user => _user;
  HostsResponse? get hosts => _hosts;
  bool get hasApiKey => _storageService.hasApiKey();
  String? get apiKey => _storageService.getApiKey();
  AllDebridService? get allDebridService => _allDebridService;
  Color get primaryColor => _primaryColor;
  bool get isDarkMode => _isDarkMode;
  List<ImdbSearchResult> get watchlist => _watchlist;

  Future<void> saveSetting(String key, dynamic value) async {
    await _storageService.saveSetting(key, value);
    notifyListeners();
  }

  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    await _storageService.saveSetting('primary_color', color.value);
    notifyListeners();
  }

  Future<void> toggleThemeMode() async {
    _isDarkMode = !_isDarkMode;
    await _storageService.saveSetting('is_dark_mode', _isDarkMode);
    notifyListeners();
  }

  T? getSetting<T>(String key, [T? defaultValue]) =>
      _storageService.getSetting(key, defaultValue);

  Map<String, dynamic> getAllSettings() => _storageService.getSettings();

  bool isInWatchlist(String id) {
    return _watchlist.any((item) => item.id == id);
  }

  Future<void> toggleWatchlist(ImdbSearchResult item) async {
    final index = _watchlist.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _watchlist.removeAt(index);
    } else {
      _watchlist.insert(0, item);
    }

    final watchlistData =
        _watchlist.map((e) => jsonEncode(e.toJson())).toList();
    await _storageService.saveSetting('watchlist', watchlistData);
    notifyListeners();
  }

  Future<void> reorderWatchlist(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _watchlist.removeAt(oldIndex);
    _watchlist.insert(newIndex, item);

    final watchlistData =
        _watchlist.map((e) => jsonEncode(e.toJson())).toList();
    await _storageService.saveSetting('watchlist', watchlistData);
    notifyListeners();
  }

  Future<void> updateWatchlistPriority(String id, int priority) async {
    final index = _watchlist.indexWhere((item) => item.id == id);
    if (index != -1) {
      _watchlist[index] = _watchlist[index].copyWith(priority: priority);
      final watchlistData =
          _watchlist.map((e) => jsonEncode(e.toJson())).toList();
      await _storageService.saveSetting('watchlist', watchlistData);
      notifyListeners();
    }
  }

  Future<void> clearWatchlist() async {
    _watchlist.clear();
    await _storageService.saveSetting('watchlist', []);
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Load Theme Color
      final colorValue = _storageService.getSetting<int>('primary_color');
      if (colorValue != null) {
        _primaryColor = Color(colorValue);
      }

      // Load Theme Mode
      final isDark = _storageService.getSetting<bool>('is_dark_mode');
      if (isDark != null) {
        _isDarkMode = isDark;
      }

      // Load Watchlist
      final watchlistData =
          _storageService.getSetting<List<dynamic>>('watchlist');
      if (watchlistData != null) {
        _watchlist = watchlistData
            .map((e) {
              try {
                return ImdbSearchResult.fromJson(jsonDecode(e.toString()));
              } catch (_) {
                return null;
              }
            })
            .whereType<ImdbSearchResult>()
            .toList();
      }

      // Check if API key is stored
      final storedApiKey = _storageService.getApiKey();
      if (storedApiKey != null && storedApiKey.isNotEmpty) {
        await _initializeWithApiKey(storedApiKey);
      }

      _isInitialized = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Initialize with API key
  Future<bool> initializeWithApiKey(String apiKey) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _initializeWithApiKey(apiKey);
      await _storageService.saveApiKey(apiKey);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _initializeWithApiKey(String apiKey) async {
    _allDebridService = AllDebridService(apiKey: apiKey);

    // Verify API key by fetching user
    _user = await _allDebridService!.getUser();

    // Fetch hosts
    _hosts = await _allDebridService!.getHosts();
  }

  /// Refresh user data
  Future<void> refreshUser() async {
    if (_allDebridService == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      _user = await _allDebridService!.getUser();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh hosts
  Future<void> refreshHosts() async {
    if (_allDebridService == null) return;

    try {
      _hosts = await _allDebridService!.getHosts();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Logout
  Future<void> logout() async {
    await _storageService.clearApiKey();
    _allDebridService = null;
    _user = null;
    _hosts = null;
    _error = null;
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
