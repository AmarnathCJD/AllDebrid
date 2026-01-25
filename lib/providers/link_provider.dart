import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Link Provider - State management for link operations
class LinkProvider extends ChangeNotifier {
  final AllDebridService? Function() _getService;

  List<UnlockedLink> _unlockedLinks = [];
  List<LinkInfo> _linkInfos = [];
  bool _isLoading = false;
  String? _error;

  LinkProvider({required AllDebridService? Function() getService})
      : _getService = getService;

  // Getters
  List<UnlockedLink> get unlockedLinks => _unlockedLinks;
  List<LinkInfo> get linkInfos => _linkInfos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AllDebridService? get _service => _getService();

  /// Get link info for multiple links
  Future<List<LinkInfo>?> getLinkInfo(List<String> links,
      {String? password}) async {
    if (_service == null) return null;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _linkInfos = await _service!.getLinkInfo(links, password: password);
      return _linkInfos;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Unlock a link
  Future<UnlockedLink?> unlockLink(String link, {String? password}) async {
    if (_service == null) return null;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final unlocked = await _service!.unlockLink(link, password: password);
      _unlockedLinks.insert(0, unlocked);

      // Keep only last 50 links
      if (_unlockedLinks.length > 50) {
        _unlockedLinks = _unlockedLinks.take(50).toList();
      }

      return unlocked;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get redirector links
  Future<List<String>?> getRedirectorLinks(String link) async {
    if (_service == null) return null;

    try {
      return await _service!.getRedirectorLinks(link);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Get streaming link
  Future<StreamingLink?> getStreamingLink(String id, String streamId) async {
    if (_service == null) return null;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      return await _service!.getStreamingLink(id, streamId);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Wait for delayed link
  Future<String?> waitForDelayedLink(String delayedId) async {
    if (_service == null) return null;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      return await _service!.waitForDelayedLink(delayedId);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createZip(List<String> links) async {
    if (_service == null) return null;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      return await _service!.createZip(links);
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check if link is supported
  Future<bool> isLinkSupported(String link) async {
    if (_service == null) return false;

    try {
      return await _service!.isLinkSupported(link);
    } catch (e) {
      return false;
    }
  }

  /// Clear unlocked links history
  void clearHistory() {
    _unlockedLinks.clear();
    _linkInfos.clear();
    notifyListeners();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
