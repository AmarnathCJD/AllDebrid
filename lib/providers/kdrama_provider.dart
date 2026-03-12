import 'package:flutter/foundation.dart';
import '../services/kdrama_service.dart';
export '../services/kdrama_service.dart' show KDramaItem;

class KDramaProvider extends ChangeNotifier {
  final _dramaService = KDramaService();

  List<KDramaItem> _topDramas = [];
  List<KDramaItem> _latestDramas = [];
  List<KDramaItem> _topAiringDramas = [];
  bool _isLoading = false;

  List<KDramaItem> get topDramas => _topDramas;
  List<KDramaItem> get latestDramas => _latestDramas;
  List<KDramaItem> get topAiringDramas => _topAiringDramas;
  bool get isLoading => _isLoading;

  Future<void> loadTopDramas() async {
    final cachedDramas = await _dramaService
        .getCachedDramas('${KDramaService.baseUrl}/shows/top');
    if (cachedDramas.isNotEmpty) {
      _topDramas = cachedDramas;
      _topDramas.shuffle();
      notifyListeners();
    } else {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final dramas = await _dramaService.fetchTopDramas();
      _topDramas = dramas;
      _topDramas.shuffle();
    } catch (e) {
      print('[KDRAMA PROVIDER] Error loading top dramas: $e');
    } finally {
      if (_isLoading) _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLatestDramas() async {
    // 1. Try cache first
    final cachedDramas = await _dramaService
        .getCachedDramas('${KDramaService.baseUrl}/shows/newest');
    if (cachedDramas.isNotEmpty) {
      _latestDramas = cachedDramas;
      _latestDramas.shuffle();
      notifyListeners();
    } else {
      _isLoading = true;
      notifyListeners();
    }

    // 2. Load fresh
    try {
      final dramas = await _dramaService.fetchLatestDramas();
      _latestDramas = dramas;
      _latestDramas.shuffle();
    } catch (e) {
      print('[KDRAMA PROVIDER] Error loading latest dramas: $e');
    } finally {
      if (_isLoading) _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTopAiringDramas() async {
    // 1. Try cache first
    final cachedDramas = await _dramaService
        .getCachedDramas('${KDramaService.baseUrl}/shows/top_airing');
    if (cachedDramas.isNotEmpty) {
      _topAiringDramas = cachedDramas;
      _topAiringDramas.shuffle();
      notifyListeners();
    } else {
      _isLoading = true;
      notifyListeners();
    }

    // 2. Load fresh
    try {
      final dramas = await _dramaService.fetchTopAiringDramas();
      _topAiringDramas = dramas;
      _topAiringDramas.shuffle();
    } catch (e) {
      print('[KDRAMA PROVIDER] Error loading top airing dramas: $e');
    } finally {
      if (_isLoading) _isLoading = false;
      notifyListeners();
    }
  }
}
