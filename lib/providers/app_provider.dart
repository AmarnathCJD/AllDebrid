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
