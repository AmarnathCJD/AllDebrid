import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Magnet Provider - State management for magnets
class MagnetProvider extends ChangeNotifier {
  final AllDebridService? Function() _getService;

  List<MagnetStatus> _magnets = [];
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;

  MagnetProvider({required AllDebridService? Function() getService})
      : _getService = getService;

  // Getters
  List<MagnetStatus> get magnets => _magnets;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<MagnetStatus> get activeMagnets =>
      _magnets.where((m) => !m.isReady && !m.isError).toList();

  List<MagnetStatus> get readyMagnets =>
      _magnets.where((m) => m.isReady).toList();

  List<MagnetStatus> get errorMagnets =>
      _magnets.where((m) => m.isError).toList();

  AllDebridService? get _service => _getService();

  /// Start auto refresh for active magnets
  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (activeMagnets.isNotEmpty) {
        refreshMagnets(showLoading: false);
      }
    });
  }

  /// Stop auto refresh
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Fetch all magnets
  Future<void> fetchMagnets() async {
    if (_service == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _magnets = await _service!.getAllMagnets();
      _magnets.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh magnets without showing loading
  Future<void> refreshMagnets({bool showLoading = true}) async {
    if (_service == null) return;

    if (showLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final freshMagnets = await _service!.getAllMagnets();
      // Filter out pending deletions
      _magnets = freshMagnets
          .where((m) => !_pendingDeletions.contains(m.id.toString()))
          .toList();
      _magnets.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (showLoading) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  // Placeholder for local torrent service if we integrate one
  // final TorrentService _torrentService = TorrentService();

  /// Upload a magnet
  Future<MagnetUploadResult?> uploadMagnet(String magnet) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // 1. Try AllDebrid first
    if (_service != null) {
      try {
        final result = await _service!.uploadSingleMagnet(magnet);
        await refreshMagnets(showLoading: false);
        return result;
      } catch (e) {
        // If AllDebrid fails, we fallback to local or show error
        // print('AllDebrid upload failed: $e. Attempting fallback...');
        _error = e.toString();
      }
    } else {
      _error = "AllDebrid service not available";
    }

    // Fallback logic could go here

    _isLoading = false;
    notifyListeners();
    return null;
  }

  /// Get magnet files
  Future<List<MagnetFile>?> getMagnetFiles(String magnetId) async {
    if (_service == null) return null;

    try {
      return await _service!.getMagnetFiles(magnetId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Unlock a restricted link
  Future<String?> unlockLink(String link) async {
    if (_service == null) return null;

    try {
      final unlocked = await _service!.unlockLink(link);
      return unlocked.link;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  final Set<String> _pendingDeletions = {};

  /// Delete a magnet
  Future<bool> deleteMagnet(String magnetId) async {
    if (_service == null) return false;

    // Optimistic update
    _pendingDeletions.add(magnetId);
    _magnets.removeWhere((m) => m.id.toString() == magnetId);
    notifyListeners();

    try {
      await _service!.deleteMagnet(magnetId);
      // Keep in pending deletions briefly to ensure next refresh doesn't bring it back immediately
      // if the server is slow to update its list
      Future.delayed(const Duration(seconds: 5), () {
        _pendingDeletions.remove(magnetId);
      });
      return true;
    } catch (e) {
      _error = e.toString();
      _pendingDeletions.remove(magnetId); // Revert on error
      // We might need to refresh to get it back if we removed it
      refreshMagnets(showLoading: false);
      notifyListeners();
      return false;
    }
  }

  /// Restart a magnet
  Future<bool> restartMagnet(String magnetId) async {
    if (_service == null) return false;

    try {
      await _service!.restartMagnet(magnetId);
      await refreshMagnets(showLoading: false);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}
