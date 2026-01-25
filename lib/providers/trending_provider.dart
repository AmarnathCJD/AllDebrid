import 'package:flutter/foundation.dart';
import '../services/trending_service.dart';

class TrendingItem {
  final String id;
  final String title;
  final String? posterUrl;
  final String? releaseDate;
  final double? rating;
  final String mediaType;

  TrendingItem({
    required this.id,
    required this.title,
    this.posterUrl,
    this.releaseDate,
    this.rating,
    required this.mediaType,
  });
}

class TrendingProvider extends ChangeNotifier {
  final _trendingService = TrendingService();

  List<TrendingItem> _trendingMovies = [];
  List<TrendingItem> _trendingTVShows = [];
  List<TrendingItem> _netflixShows = [];
  List<TrendingItem> _amazonPrimeShows = [];

  bool _isLoading = false;

  List<TrendingItem> get trendingMovies => _trendingMovies;
  List<TrendingItem> get trendingTVShows => _trendingTVShows;
  List<TrendingItem> get netflixShows => _netflixShows;
  List<TrendingItem> get amazonPrimeShows => _amazonPrimeShows;
  bool get isLoading => _isLoading;

  Future<void> loadTrendingData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final moviesFuture = _trendingService.fetchTrendingMovies();
      final tvShowsFuture = _trendingService.fetchTrendingTVShows();
      final netflixShowsFuture = _trendingService.fetchNetflixShows();
      final netflixMoviesFuture = _trendingService.fetchNetflixMovies();
      final amazonShowsFuture = _trendingService.fetchAmazonPrimeShows();
      final amazonMoviesFuture = _trendingService.fetchAmazonPrimeMovies();

      final results = await Future.wait([
        moviesFuture,
        tvShowsFuture,
        netflixShowsFuture,
        netflixMoviesFuture,
        amazonShowsFuture,
        amazonMoviesFuture,
      ]);

      _trendingMovies = (results[0] as List)
          .map((item) => TrendingItem(
                id: item.id,
                title: item.title,
                posterUrl: item.posterUrl,
                releaseDate: item.releaseDate,
                rating: item.rating,
                mediaType: item.mediaType,
              ))
          .toList();

      _trendingTVShows = (results[1] as List)
          .map((item) => TrendingItem(
                id: item.id,
                title: item.title,
                posterUrl: item.posterUrl,
                releaseDate: item.releaseDate,
                rating: item.rating,
                mediaType: item.mediaType,
              ))
          .toList();

      // Mix Netflix TV and Movies
      final netflixShows = (results[2] as List)
          .map((item) => TrendingItem(
                id: item.id,
                title: item.title,
                posterUrl: item.posterUrl,
                releaseDate: item.releaseDate,
                rating: item.rating,
                mediaType: item.mediaType,
              ))
          .toList();

      final netflixMovies = (results[3] as List)
          .map((item) => TrendingItem(
                id: item.id,
                title: item.title,
                posterUrl: item.posterUrl,
                releaseDate: item.releaseDate,
                rating: item.rating,
                mediaType: item.mediaType,
              ))
          .toList();

      _netflixShows = [...netflixShows, ...netflixMovies];

      // Mix Prime TV and Movies
      final amazonShows = (results[4] as List)
          .map((item) => TrendingItem(
                id: item.id,
                title: item.title,
                posterUrl: item.posterUrl,
                releaseDate: item.releaseDate,
                rating: item.rating,
                mediaType: item.mediaType,
              ))
          .toList();

      final amazonMovies = (results[5] as List)
          .map((item) => TrendingItem(
                id: item.id,
                title: item.title,
                posterUrl: item.posterUrl,
                releaseDate: item.releaseDate,
                rating: item.rating,
                mediaType: item.mediaType,
              ))
          .toList();

      _amazonPrimeShows = [...amazonShows, ...amazonMovies];

      // Shuffle each list
      _trendingMovies.shuffle();
      _trendingTVShows.shuffle();
      _netflixShows.shuffle();
      _amazonPrimeShows.shuffle();
    } catch (e) {
      print('[TRENDING PROVIDER] Error loading trending data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
