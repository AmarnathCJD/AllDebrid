import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';
import '../services/session_storage.dart';
import '../theme/app_theme.dart';

/// App State - Immutable state holder
class AppState {
  final bool isInitialized;
  final bool isLoading;
  final String? error;
  final User? user;
  final HostsResponse? hosts;
  final List<ImdbSearchResult> watchlist;
  final Map<String, int> ratings;
  final bool isDarkMode;
  final Color primaryColor;
  final AllDebridService? allDebridService;
  final String? apiKey;
  final RouteObserver<PageRoute> routeObserver;

  const AppState({
    this.isInitialized = false,
    this.isLoading = false,
    this.error,
    this.user,
    this.hosts,
    this.watchlist = const [],
    this.ratings = const {},
    this.isDarkMode = true,
    this.primaryColor = AppTheme.primaryColor,
    this.allDebridService,
    this.apiKey,
    required this.routeObserver,
  });

  bool get hasApiKey => apiKey != null && apiKey!.isNotEmpty;

  bool isInWatchlist(String id) {
    return watchlist.any((item) => item.id == id);
  }

  AppState copyWith({
    bool? isInitialized,
    bool? isLoading,
    String? error,
    User? user,
    HostsResponse? hosts,
    List<ImdbSearchResult>? watchlist,
    Map<String, int>? ratings,
    bool? isDarkMode,
    Color? primaryColor,
    AllDebridService? allDebridService,
    String? apiKey,
  }) {
    return AppState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      user: user ?? this.user,
      hosts: hosts ?? this.hosts,
      watchlist: watchlist ?? this.watchlist,
      ratings: ratings ?? this.ratings,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      primaryColor: primaryColor ?? this.primaryColor,
      allDebridService: allDebridService ?? this.allDebridService,
      apiKey: apiKey ?? this.apiKey,
      routeObserver: routeObserver,
    );
  }
}

/// App Notifier - State management for the app
class AppNotifier extends Notifier<AppState> {
  late final StorageService _storageService;
  Timer? _watchlistDebounce;

  @override
  AppState build() {
    // Get storage service from ref
    _storageService = ref.watch(storageServiceProvider);

    // Set up dispose
    ref.onDispose(() {
      _watchlistDebounce?.cancel();
    });

    final routeObserver = RouteObserver<PageRoute>();
    final apiKey = _storageService.getApiKey();

    return AppState(
      routeObserver: routeObserver,
      apiKey: apiKey,
    );
  }

  RouteObserver<PageRoute> get routeObserver => state.routeObserver;

  Future<void> saveSetting(String key, dynamic value,
      {bool notify = false}) async {
    await _storageService.saveSetting(key, value);
    if (notify) {
      // Trigger state rebuild by creating new state reference
      state = state;
    }
  }

  Future<void> setPrimaryColor(Color color) async {
    await _storageService.saveSetting('primary_color', color.toARGB32());
    state = state.copyWith(primaryColor: color);
  }

  Future<void> toggleThemeMode() async {
    final newDarkMode = !state.isDarkMode;
    await _storageService.saveSetting('is_dark_mode', newDarkMode);
    state = state.copyWith(isDarkMode: newDarkMode);
  }

  T? getSetting<T>(String key, [T? defaultValue]) =>
      _storageService.getSetting(key, defaultValue);

  Map<String, dynamic> getAllSettings() => _storageService.getSettings();

  bool isInWatchlist(String id) {
    return state.watchlist.any((item) => item.id == id);
  }

  Future<void> toggleWatchlist(ImdbSearchResult item) async {
    final watchlist = List<ImdbSearchResult>.from(state.watchlist);
    final index = watchlist.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      watchlist.removeAt(index);
    } else {
      watchlist.insert(0, item);
    }

    final watchlistData =
        watchlist.map((e) => jsonEncode(e.toJson())).toList();
    await _storageService.saveSetting('watchlist', watchlistData);
    state = state.copyWith(watchlist: watchlist);
  }

  Future<void> reorderWatchlist(int oldIndex, int newIndex) async {
    final watchlist = List<ImdbSearchResult>.from(state.watchlist);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = watchlist.removeAt(oldIndex);
    watchlist.insert(newIndex, item);

    final watchlistData =
        watchlist.map((e) => jsonEncode(e.toJson())).toList();
    await _storageService.saveSetting('watchlist', watchlistData);
    state = state.copyWith(watchlist: watchlist);
  }

  Future<void> updateWatchlistPriority(String id, int priority) async {
    final watchlist = List<ImdbSearchResult>.from(state.watchlist);
    final index = watchlist.indexWhere((item) => item.id == id);
    if (index != -1) {
      watchlist[index] = watchlist[index].copyWith(priority: priority);

      _watchlistDebounce?.cancel();
      _watchlistDebounce = Timer(const Duration(milliseconds: 600), () async {
        final watchlistData =
            watchlist.map((e) => jsonEncode(e.toJson())).toList();
        await _storageService.saveSetting('watchlist', watchlistData);
        state = state.copyWith(watchlist: watchlist);
      });
    }
  }

  Future<void> clearWatchlist() async {
    await _storageService.saveSetting('watchlist', []);
    state = state.copyWith(watchlist: []);
  }

  Future<void> initialize() async {
    if (state.isInitialized) return;

    state = state.copyWith(isLoading: true);

    try {
      // Load Theme Color
      var primaryColor = state.primaryColor;
      final colorValue = _storageService.getSetting<int>('primary_color');
      if (colorValue != null) {
        primaryColor = Color(colorValue);
      }

      // Load Theme Mode
      var isDarkMode = state.isDarkMode;
      final isDark = _storageService.getSetting<bool>('is_dark_mode');
      if (isDark != null) {
        isDarkMode = isDark;
      }

      // Load Watchlist
      var watchlist = <ImdbSearchResult>[];
      final watchlistData =
          _storageService.getSetting<List<dynamic>>('watchlist');
      if (watchlistData != null) {
        watchlist = watchlistData
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

      var allDebridService = state.allDebridService;
      var user = state.user;
      var hosts = state.hosts;
      final storedApiKey = _storageService.getApiKey();
      if (storedApiKey != null && storedApiKey.isNotEmpty) {
        // Skip network calls during init — set up service only, fetch in bg
        allDebridService = AllDebridService(apiKey: storedApiKey);
        unawaited(_fetchRemoteDataInBackground(allDebridService));
      }

      unawaited(SessionStorage.getSession().then((tgSession) async {
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
      })); // fire-and-forget

      final ratingsData = _storageService.getSetting<String>('ratings') ?? '{}';
      final ratings = Map<String, int>.from(jsonDecode(ratingsData));

      state = state.copyWith(
        isInitialized: true,
        isLoading: false,
        primaryColor: primaryColor,
        isDarkMode: isDarkMode,
        watchlist: watchlist,
        allDebridService: allDebridService,
        ratings: ratings,
        user: user,
        hosts: hosts,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Initialize with API key
  Future<bool> initializeWithApiKey(String apiKey) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final service = AllDebridService(apiKey: apiKey);
      final user = await service.getUser();
      final hosts = await service.getHosts();
      await _storageService.saveApiKey(apiKey);

      state = state.copyWith(
        isLoading: false,
        allDebridService: service,
        apiKey: apiKey,
        user: user,
        hosts: hosts,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return false;
    }
  }

  /// Fetch user + hosts in background without blocking init.
  Future<void> _fetchRemoteDataInBackground(AllDebridService service) async {
    try {
      final user = await service.getUser();
      final hosts = await service.getHosts();
      state = state.copyWith(user: user, hosts: hosts);
    } catch (e) {
      // Non-fatal: app already showed, just missing user info
    }
  }

  Future<void> refreshUser() async {
    if (state.allDebridService == null) return;

    state = state.copyWith(isLoading: true);
    debugPrint('[AppProvider] State update from refreshUser (start)');

    try {
      final user = await state.allDebridService!.getUser();
      state = state.copyWith(user: user, error: null, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> refreshHosts() async {
    if (state.allDebridService == null) return;

    try {
      final hosts = await state.allDebridService!.getHosts();
      state = state.copyWith(hosts: hosts);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> logout() async {
    await _storageService.clearApiKey();
    state = AppState(
      routeObserver: state.routeObserver,
      isDarkMode: state.isDarkMode,
      primaryColor: state.primaryColor,
    );
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  int getRating(String id) {
    return state.ratings[id] ?? 0;
  }

  Future<void> setRating(String id, int rating) async {
    final ratings = Map<String, int>.from(state.ratings);
    if (rating == 0) {
      ratings.remove(id);
    } else {
      ratings[id] = rating;
    }
    await _storageService.saveSetting('ratings', jsonEncode(ratings));
    debugPrint('[AppProvider] State update from setRating');
    state = state.copyWith(ratings: ratings);
  }
}

// Storage service provider (to be overridden in main.dart)
final storageServiceProvider = Provider<StorageService>(
  (ref) => throw UnimplementedError(
    'storageServiceProvider must be overridden',
  ),
);

// Provider definition
final appNotifierProvider = NotifierProvider<AppNotifier, AppState>(() {
  return AppNotifier();
});
