import 'package:flutter/foundation.dart';
import '../services/kdrama_service.dart';

class KDramaItem {
  final String id;
  final String title;
  final String? posterUrl;
  final String? releaseYear;
  final int? episodes;
  final double? rating;

  KDramaItem({
    required this.id,
    required this.title,
    this.posterUrl,
    this.releaseYear,
    this.episodes,
    this.rating,
  });
}

class KDramaProvider extends ChangeNotifier {
  final _dramaService = KDramaService();

  List<KDramaItem> _topDramas = [];
  List<KDramaItem> _latestDramas = [];
  bool _isLoading = false;

  List<KDramaItem> get topDramas => _topDramas;
  List<KDramaItem> get latestDramas => _latestDramas;
  bool get isLoading => _isLoading;

  Future<void> loadTopDramas() async {
    _isLoading = true;
    notifyListeners();

    try {
      final dramas = await _dramaService.fetchTopDramas();

      _topDramas = dramas
          .map((item) => KDramaItem(
                id: item.id,
                title: item.title,
                posterUrl: item.posterUrl,
                releaseYear: item.releaseYear,
                episodes: item.episodes,
                rating: item.rating,
              ))
          .toList();

      // Shuffle list for variety
      _topDramas.shuffle();
    } catch (e) {
      print('[KDRAMA PROVIDER] Error loading top dramas: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadLatestDramas() async {
    _isLoading = true;
    notifyListeners();

    try {
      final dramas = await _dramaService.fetchLatestDramas();

      _latestDramas = dramas
          .map((item) => KDramaItem(
                id: item.id,
                title: item.title,
                posterUrl: item.posterUrl,
                releaseYear: item.releaseYear,
                episodes: item.episodes,
                rating: item.rating,
              ))
          .toList();

      // Shuffle list for variety
      _latestDramas.shuffle();
    } catch (e) {
      print('[KDRAMA PROVIDER] Error loading latest dramas: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
