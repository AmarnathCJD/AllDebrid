import 'package:flutter/foundation.dart';
import '../services/rivestream_service.dart';

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
  final _riveService = RiveStreamService();

  List<TrendingItem> _trendingMovies = [];
  List<TrendingItem> _trendingTVShows = [];
  List<TrendingItem> _netflixShows = [];
  List<TrendingItem> _amazonPrimeShows = [];

  bool _isLoading = false;
  bool _hasError = false;

  List<TrendingItem> get trendingMovies => _trendingMovies;
  List<TrendingItem> get trendingTVShows => _trendingTVShows;
  List<TrendingItem> get netflixShows => _netflixShows;
  List<TrendingItem> get amazonPrimeShows => _amazonPrimeShows;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;

  Future<void> loadTrendingData() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      // Fetch Trending
      final trendingResults = await _riveService.getTrending(page: 1);

      // Filter movies and TV shows
      _trendingMovies = trendingResults
          .where((item) => item.mediaType == 'movie')
          .map(_mapToTrendingItem)
          .toList();

      _trendingTVShows = trendingResults
          .where((item) => item.mediaType == 'tv')
          .map(_mapToTrendingItem)
          .toList();

      // Fetch Netflix Content (Provider ID 8)
      // Flatrate
      final netflixResults = await _riveService.getDiscoverContent(
        mediaType: 'tv',
        watchProviders: '8',
        monetizationTypes: 'flatrate',
      );
      // We can also fetch movies if we want to mix them
      final netflixMoviesResults = await _riveService.getDiscoverContent(
        mediaType: 'movie',
        watchProviders: '8',
        monetizationTypes: 'flatrate',
      );

      _netflixShows = [...netflixResults, ...netflixMoviesResults]
          .map(_mapToTrendingItem)
          .toList();

      // Fetch Amazon Prime Content (Provider ID 119)
      final amazonResults = await _riveService.getDiscoverContent(
        mediaType: 'tv',
        watchProviders: '119',
        monetizationTypes: 'flatrate',
      );
      final amazonMoviesResults = await _riveService.getDiscoverContent(
        mediaType: 'movie',
        watchProviders: '119',
        monetizationTypes: 'flatrate',
      );

      _amazonPrimeShows = [...amazonResults, ...amazonMoviesResults]
          .map(_mapToTrendingItem)
          .toList();

      // Shuffle
      _trendingMovies.shuffle();
      _trendingTVShows.shuffle();
      _netflixShows.shuffle();
      _amazonPrimeShows.shuffle();
    } catch (e) {
      print('[TRENDING PROVIDER] Error loading trending data: $e');
      _hasError = true;
      // Keep existing cached data on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  TrendingItem _mapToTrendingItem(RiveStreamMedia item) {
    return TrendingItem(
      id: item.id.toString(),
      title: item.displayTitle,
      posterUrl: item.fullPosterUrl,
      releaseDate: item.displayDate,
      rating: item.voteAverage,
      mediaType: item.mediaType,
    );
  }
}
