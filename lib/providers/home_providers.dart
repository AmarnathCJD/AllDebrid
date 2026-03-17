import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/imdb_service.dart';
import '../services/rivestream_service.dart';

// ─── Continue Watching Provider ────────────────────────────────────────────

final continueWatchingProvider =
    AsyncNotifierProvider<ContinueWatchingNotifier, List<WatchProgress>>(
  ContinueWatchingNotifier.new,
);

class ContinueWatchingNotifier extends AsyncNotifier<List<WatchProgress>> {
  @override
  Future<List<WatchProgress>> build() async {
    final items = await ImdbService().getContinueWatching();
    return items.where((wp) {
      if (wp.duration <= 0) return true;
      final progress = wp.position / wp.duration;
      return progress < 0.95;
    }).toList();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final items = await ImdbService().getContinueWatching();
      // Filter out items with 95%+ completion (considered finished)
      return items.where((wp) {
        if (wp.duration <= 0) return true;
        final progress = wp.position / wp.duration;
        return progress < 0.95;
      }).toList();
    });
  }
}

// ─── Rive Trending Provider ────────────────────────────────────────────────

class RiveTrendingState {
  final List<RiveStreamMedia> featured;
  final List<RiveStreamMedia> movies;
  final List<RiveStreamMedia> tvShows;

  const RiveTrendingState({
    this.featured = const [],
    this.movies = const [],
    this.tvShows = const [],
  });
}

final riveTrendingProvider =
    AsyncNotifierProvider<RiveTrendingNotifier, RiveTrendingState>(
  RiveTrendingNotifier.new,
);

class RiveTrendingNotifier extends AsyncNotifier<RiveTrendingState> {
  final _riveService = RiveStreamService();

  @override
  Future<RiveTrendingState> build() async {
    // 1. Try cache first
    final cachedResults = await Future.wait([
      _riveService.getCachedTrending(page: 1),
      _riveService.getCachedTrending(page: 2),
    ]);

    if (cachedResults[0].isNotEmpty || cachedResults[1].isNotEmpty) {
      // Return cached data immediately, then fetch fresh in background
      Future.microtask(_fetchFresh);
      return _buildState(cachedResults[0], cachedResults[1]);
    }

    // No cache, fetch fresh
    return await _fetchFreshAndReturn();
  }

  Future<void> _fetchFresh() async {
    final freshResults = await Future.wait([
      _riveService.getTrending(page: 1),
      _riveService.getTrending(page: 2),
    ]);
    state = AsyncData(_buildState(freshResults[0], freshResults[1]));
  }

  Future<RiveTrendingState> _fetchFreshAndReturn() async {
    final results = await Future.wait([
      _riveService.getTrending(page: 1),
      _riveService.getTrending(page: 2),
    ]);
    return _buildState(results[0], results[1]);
  }

  RiveTrendingState _buildState(
    List<RiveStreamMedia> page1,
    List<RiveStreamMedia> page2,
  ) {
    return RiveTrendingState(
      featured: page1,
      movies: page2.where((m) => m.mediaType == 'movie').toList(),
      tvShows: page2.where((m) => m.mediaType == 'tv').toList(),
    );
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchFreshAndReturn);
  }
}

// ─── Carousel Index Provider ───────────────────────────────────────────────

final carouselIndexProvider = StateProvider<int>((ref) => 0);

// ─── Genre Provider ────────────────────────────────────────────────────────

final genreProvider =
    AsyncNotifierProvider.family<GenreNotifier, GenreInterestResult?, String>(
        GenreNotifier.new);

class GenreNotifier extends FamilyAsyncNotifier<GenreInterestResult?, String> {
  final _riveService = RiveStreamService();

  @override
  Future<GenreInterestResult?> build(String genreId) async {
    return await _riveService.getGenreInterest(genreId);
  }
}
