import 'dart:async';
import 'dart:convert';
import '../models/models.dart';
import '../services/services.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

/// App Provider - Main state management for the app
class AppProvider extends ChangeNotifier {
  final StorageService _storageService;
  final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
  AllDebridService? _allDebridService;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;
  User? _user;
  HostsResponse? _hosts;
  List<ImdbSearchResult> _watchlist = [];
  Map<String, int> _ratings = {};
  Timer? _watchlistDebounce;

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

      _watchlistDebounce?.cancel();
      _watchlistDebounce = Timer(const Duration(milliseconds: 600), () async {
        final watchlistData =
            _watchlist.map((e) => jsonEncode(e.toJson())).toList();
        await _storageService.saveSetting('watchlist', watchlistData);
        notifyListeners();
      });
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

      final storedApiKey = _storageService.getApiKey();
      if (storedApiKey != null && storedApiKey.isNotEmpty) {
        // Skip network calls during init — set up service only, fetch in bg
        await _initializeWithApiKey(storedApiKey, fetchRemote: false);
        _fetchRemoteDataInBackground(); // fire-and-forget
      }

      SessionStorage.getSession().then((tgSession) async {
        if (tgSession != null && tgSession.isNotEmpty) {
          try {
            final chatId = await SessionStorage.getChatId();
            final chatHash = await SessionStorage.getChatHash();
            if (chatId != null) TgService.telegramChannelId = chatId;
            if (chatHash != null) TgService.telegramAccessHash = chatHash;
            await TgService.initializeNativeFetcher(stringSession: tgSession);
          } catch (e) {
            debugPrint('[AppProvider] Failed to auto-init native TG: $e');
          }
        }
      }); // fire-and-forget

      final ratingsData = _storageService.getSetting<String>('ratings') ?? '{}';
      _ratings = Map<String, int>.from(jsonDecode(ratingsData));

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

  Future<void> _initializeWithApiKey(String apiKey, {bool fetchRemote = true}) async {
    _allDebridService = AllDebridService(apiKey: apiKey);

    if (fetchRemote) {
      _user = await _allDebridService!.getUser();
      _hosts = await _allDebridService!.getHosts();
    }
  }

  /// Fetch user + hosts in background without blocking init.
  Future<void> _fetchRemoteDataInBackground() async {
    if (_allDebridService == null) return;
    try {
      final user = await _allDebridService!.getUser();
      final hosts = await _allDebridService!.getHosts();
      _user = user;
      _hosts = hosts;
      notifyListeners();
    } catch (e) {
      // Non-fatal: app already showed, just missing user info
    }
  }

  Future<void> refreshUser() async {
    if (_allDebridService == null) return;

    _isLoading = true;
    debugPrint('[AppProvider] notifyListeners from refreshUser (start)');
    notifyListeners();

    try {
      _user = await _allDebridService!.getUser();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      debugPrint('[AppProvider] notifyListeners from refreshUser (done)');
      notifyListeners();
    }
  }

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

  Future<void> logout() async {
    await _storageService.clearApiKey();
    _allDebridService = null;
    _user = null;
    _hosts = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  int getRating(String id) {
    return _ratings[id] ?? 0;
  }

  Future<void> setRating(String id, int rating) async {
    if (rating == 0) {
      _ratings.remove(id);
    } else {
      _ratings[id] = rating;
    }
    await _storageService.saveSetting('ratings', jsonEncode(_ratings));
    debugPrint('[AppProvider] notifyListeners from setRating');
    notifyListeners();
  }
}
