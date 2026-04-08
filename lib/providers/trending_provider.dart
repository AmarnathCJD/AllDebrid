import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Trending State
class TrendingState {
  final List<TrendingItem> trendingMovies;
  final List<TrendingItem> trendingTVShows;
  final List<TrendingItem> netflixShows;
  final List<TrendingItem> amazonPrimeShows;
  final bool isLoading;
  final bool hasError;

  const TrendingState({
    this.trendingMovies = const [],
    this.trendingTVShows = const [],
    this.netflixShows = const [],
    this.amazonPrimeShows = const [],
    this.isLoading = false,
    this.hasError = false,
  });

  TrendingState copyWith({
    List<TrendingItem>? trendingMovies,
    List<TrendingItem>? trendingTVShows,
    List<TrendingItem>? netflixShows,
    List<TrendingItem>? amazonPrimeShows,
    bool? isLoading,
    bool? hasError,
  }) {
    return TrendingState(
      trendingMovies: trendingMovies ?? this.trendingMovies,
      trendingTVShows: trendingTVShows ?? this.trendingTVShows,
      netflixShows: netflixShows ?? this.netflixShows,
      amazonPrimeShows: amazonPrimeShows ?? this.amazonPrimeShows,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
    );
  }
}

/// Trending Notifier
class TrendingNotifier extends Notifier<TrendingState> {
  final _riveService = RiveStreamService();

  @override
  TrendingState build() => const TrendingState();

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
      state = state.copyWith(
        trendingMovies: cachedTrending
            .where((i) => i.mediaType == 'movie')
            .map(_mapToTrendingItem)
            .toList(),
        trendingTVShows: cachedTrending
            .where((i) => i.mediaType == 'tv')
            .map(_mapToTrendingItem)
            .toList(),
        netflixShows: [...cachedNetflixTV, ...cachedNetflixMovies]
            .map(_mapToTrendingItem)
            .toList(),
        amazonPrimeShows: [...cachedAmazonTV, ...cachedAmazonMovies]
            .map(_mapToTrendingItem)
            .toList(),
      );
    } else {
      state = state.copyWith(isLoading: true);
    }

    // 2. Fetch fresh data in the background
    try {
      final trendingResults = await _riveService.getTrending(page: 1);
      final netflixResults = await _riveService.getDiscoverContent(
          mediaType: 'tv', watchProviders: '8', monetizationTypes: 'flatrate');
      final netflixMoviesResults = await _riveService.getDiscoverContent(
          mediaType: 'movie',
          watchProviders: '8',
          monetizationTypes: 'flatrate');
      final amazonResults = await _riveService.getDiscoverContent(
          mediaType: 'tv',
          watchProviders: '119',
          monetizationTypes: 'flatrate');
      final amazonMoviesResults = await _riveService.getDiscoverContent(
          mediaType: 'movie',
          watchProviders: '119',
          monetizationTypes: 'flatrate');

      state = state.copyWith(
        trendingMovies: trendingResults
            .where((item) => item.mediaType == 'movie')
            .map(_mapToTrendingItem)
            .toList(),
        trendingTVShows: trendingResults
            .where((item) => item.mediaType == 'tv')
            .map(_mapToTrendingItem)
            .toList(),
        netflixShows: [...netflixResults, ...netflixMoviesResults]
            .map(_mapToTrendingItem)
            .toList(),
        amazonPrimeShows: [...amazonResults, ...amazonMoviesResults]
            .map(_mapToTrendingItem)
            .toList(),
        hasError: false,
        isLoading: false,
      );
    } catch (e) {
      print('[TRENDING PROVIDER] Error loading trending data: $e');
      if (!hasCache) {
        state = state.copyWith(hasError: true, isLoading: false);
      } else {
        state = state.copyWith(isLoading: false);
      }
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

final trendingNotifierProvider = NotifierProvider<TrendingNotifier, TrendingState>(() {
  return TrendingNotifier();
});
