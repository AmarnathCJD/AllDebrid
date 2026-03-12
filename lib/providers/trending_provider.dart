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
    final cachedTrending = await _riveService.getCachedTrending(page: 1);
    final cachedNetflixTV = await _riveService.getCachedDiscoverContent(
        mediaType: 'tv',
        watchProviders: '8',
        monetizationTypes: 'flatrate',
        page: 1);
    final cachedNetflixMovies = await _riveService.getCachedDiscoverContent(
        mediaType: 'movie',
        watchProviders: '8',
        monetizationTypes: 'flatrate',
        page: 1);
    final cachedAmazonTV = await _riveService.getCachedDiscoverContent(
        mediaType: 'tv',
        watchProviders: '119',
        monetizationTypes: 'flatrate',
        page: 1);
    final cachedAmazonMovies = await _riveService.getCachedDiscoverContent(
        mediaType: 'movie',
        watchProviders: '119',
        monetizationTypes: 'flatrate',
        page: 1);

    bool hasCache = cachedTrending.isNotEmpty || cachedNetflixTV.isNotEmpty;

    if (hasCache) {
      _trendingMovies = cachedTrending
          .where((i) => i.mediaType == 'movie')
          .map(_mapToTrendingItem)
          .toList();
      _trendingTVShows = cachedTrending
          .where((i) => i.mediaType == 'tv')
          .map(_mapToTrendingItem)
          .toList();
      _netflixShows = [...cachedNetflixTV, ...cachedNetflixMovies]
          .map(_mapToTrendingItem)
          .toList();
      _amazonPrimeShows = [...cachedAmazonTV, ...cachedAmazonMovies]
          .map(_mapToTrendingItem)
          .toList();

      _trendingMovies.shuffle();
      _trendingTVShows.shuffle();
      _netflixShows.shuffle();
      _amazonPrimeShows.shuffle();
      notifyListeners();
    } else {
      _isLoading = true;
      notifyListeners();
    }

    // 2. Fetch fresh data in the background
    try {
      final trendingResults = await _riveService.getTrending(page: 1);
      _trendingMovies = trendingResults
          .where((item) => item.mediaType == 'movie')
          .map(_mapToTrendingItem)
          .toList();
      _trendingTVShows = trendingResults
          .where((item) => item.mediaType == 'tv')
          .map(_mapToTrendingItem)
          .toList();

      final netflixResults = await _riveService.getDiscoverContent(
          mediaType: 'tv', watchProviders: '8', monetizationTypes: 'flatrate');
      final netflixMoviesResults = await _riveService.getDiscoverContent(
          mediaType: 'movie',
          watchProviders: '8',
          monetizationTypes: 'flatrate');
      _netflixShows = [...netflixResults, ...netflixMoviesResults]
          .map(_mapToTrendingItem)
          .toList();

      final amazonResults = await _riveService.getDiscoverContent(
          mediaType: 'tv',
          watchProviders: '119',
          monetizationTypes: 'flatrate');
      final amazonMoviesResults = await _riveService.getDiscoverContent(
          mediaType: 'movie',
          watchProviders: '119',
          monetizationTypes: 'flatrate');
      _amazonPrimeShows = [...amazonResults, ...amazonMoviesResults]
          .map(_mapToTrendingItem)
          .toList();

      _trendingMovies.shuffle();
      _trendingTVShows.shuffle();
      _netflixShows.shuffle();
      _amazonPrimeShows.shuffle();
      _hasError = false;
    } catch (e) {
      print('[TRENDING PROVIDER] Error loading trending data: $e');
      if (!hasCache) _hasError = true;
    } finally {
      if (_isLoading) _isLoading = false;
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
