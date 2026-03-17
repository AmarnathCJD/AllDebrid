import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/video_source_service.dart';
import '../services/kisskh_service.dart';
import '../services/vidlink_service.dart';
import '../services/tg_service.dart';
import '../services/rivestream_service.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

// Cache configuration
const int cacheExpiryHours = 24; // Cache expires after 24 hours
const int imageCacheExpiryHours = 168; // Image cache expires after 7 days

// ─── Video Source Key ───────────────────────────────────────────────────────

class VideoSourceKey {
  final String tmdbId;
  final String? imdbId;
  final String title;
  final String year;
  final bool isMovie;
  final int season;
  final int episode;

  const VideoSourceKey({
    required this.tmdbId,
    this.imdbId,
    required this.title,
    required this.year,
    required this.isMovie,
    required this.season,
    required this.episode,
  });

  @override
  bool operator ==(Object other) =>
      other is VideoSourceKey &&
      tmdbId == other.tmdbId &&
      isMovie == other.isMovie &&
      season == other.season &&
      episode == other.episode;

  @override
  int get hashCode => Object.hash(tmdbId, isMovie, season, episode);
}

// ─── Provider Source Result ────────────────────────────────────────────────

class ProviderSourceResult {
  final String providerName;
  final List<VideoSource> sources;
  final List<VideoCaption> captions;
  final Map<String, String>? headers;
  final bool isTg;

  const ProviderSourceResult({
    required this.providerName,
    required this.sources,
    required this.captions,
    this.headers,
    this.isTg = false,
  });
}

// ─── Video Sources Provider (family by VideoSourceKey) ──────────────────────

final videoSourcesProvider = AsyncNotifierProvider.family<
    VideoSourcesNotifier,
    Map<String, ProviderSourceResult>,
    VideoSourceKey>(VideoSourcesNotifier.new);

class VideoSourcesNotifier extends FamilyAsyncNotifier<
    Map<String, ProviderSourceResult>, VideoSourceKey> {
  final _videoSourceService = VideoSourceService();
  final _kissKhService = KissKhService();
  final _vidLinkService = VidLinkService();
  final _vidEasyService = VidEasyService();
  final _tgService = TgService();

  @override
  Future<Map<String, ProviderSourceResult>> build(VideoSourceKey key) async {
    final results = <String, ProviderSourceResult>{};

    try {
      // Run all provider fetches in parallel
      final futures = <Future<ProviderSourceResult?>>[
        _fetchRiver(key),
        _fetchKissKh(key),
        _fetchVidLink(key),
        _fetchVidEasy(key),
        _fetchTg(key),
      ];

      final allResults = await Future.wait(futures, eagerError: false);

      // Filter and collect non-null results
      for (final result in allResults) {
        if (result != null && (result.sources.isNotEmpty || result.isTg)) {
          results[result.providerName] = result;
        }
      }

      return results;
    } catch (e) {
      return {}; // Return empty map on error
    }
  }

  Future<ProviderSourceResult?> _fetchRiver(VideoSourceKey key) async {
    try {
      final response = await _videoSourceService.getVideoSources(
        key.tmdbId,
        key.season.toString(),
        key.episode.toString(),
        serviceName: key.isMovie ? 'movieVideoProvider' : 'tvVideoProvider',
      );

      final sources = (response['sources'] as List?)?.cast<VideoSource>() ?? [];
      final captions =
          (response['captions'] as List?)?.cast<VideoCaption>() ?? [];

      if (sources.isNotEmpty) {
        return ProviderSourceResult(
          providerName: 'river',
          sources: sources,
          captions: captions,
          headers: VideoSourceService.flowCastHeaders,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ProviderSourceResult?> _fetchKissKh(VideoSourceKey key) async {
    try {
      final response = await _kissKhService.getSources(
        key.title,
        key.season,
        key.episode,
      );

      final sources = (response['sources'] as List?)?.cast<VideoSource>() ?? [];
      final captions =
          (response['captions'] as List?)?.cast<VideoCaption>() ?? [];

      if (sources.isNotEmpty) {
        return ProviderSourceResult(
          providerName: 'kisskh',
          sources: sources,
          captions: captions,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ProviderSourceResult?> _fetchVidLink(VideoSourceKey key) async {
    try {
      final tmdbInt = int.tryParse(key.tmdbId) ?? 0;
      final response = await _vidLinkService.getSources(
        tmdbInt,
        isMovie: key.isMovie,
        season: key.season,
        episode: key.episode,
      );

      final sources = (response['sources'] as List?)?.cast<VideoSource>() ?? [];
      final captions =
          (response['captions'] as List?)?.cast<VideoCaption>() ?? [];

      if (sources.isNotEmpty) {
        return ProviderSourceResult(
          providerName: 'vidlink',
          sources: sources,
          captions: captions,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ProviderSourceResult?> _fetchVidEasy(VideoSourceKey key) async {
    try {
      final tmdbInt = int.tryParse(key.tmdbId) ?? 0;
      final response = await _vidEasyService.getSources(
        key.title,
        key.year,
        tmdbInt,
        isMovie: key.isMovie,
        season: key.season,
        episode: key.episode,
      );

      final sources = (response['sources'] as List?)?.cast<VideoSource>() ?? [];
      final captions =
          (response['captions'] as List?)?.cast<VideoCaption>() ?? [];

      if (sources.isNotEmpty) {
        return ProviderSourceResult(
          providerName: 'videasy',
          sources: sources,
          captions: captions,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ProviderSourceResult?> _fetchTg(VideoSourceKey key) async {
    try {
      // TG links are generated in real-time on client-side, so don't prefetch them
      // Just check availability and return empty sources
      // Actual stream fetching happens when user clicks play (in _TgFlowSheet)

      if (key.isMovie) {
        // Movie: only check availability
        final checkResult = await _tgService.checkMovie(key.tmdbId);
        if (checkResult != null && checkResult.qualities.isNotEmpty) {
          return const ProviderSourceResult(
            providerName: 'tg',
            sources: [],
            captions: [],
            isTg: true,
          );
        }
        return const ProviderSourceResult(
          providerName: 'tg',
          sources: [],
          captions: [],
          isTg: true,
        );
      } else {
        // TV: only check availability
        final imdbId = key.imdbId;
        if (imdbId == null) {
          return const ProviderSourceResult(
            providerName: 'tg',
            sources: [],
            captions: [],
            isTg: true,
          );
        }

        final checkResult = await _tgService.check(imdbId);
        if (checkResult != null && checkResult.qualities.isNotEmpty) {
          return const ProviderSourceResult(
            providerName: 'tg',
            sources: [],
            captions: [],
            isTg: true,
          );
        }
        return const ProviderSourceResult(
          providerName: 'tg',
          sources: [],
          captions: [],
          isTg: true,
        );
      }
    } catch (e) {
      return const ProviderSourceResult(
        providerName: 'tg',
        sources: [],
        captions: [],
        isTg: true,
      );
    }
  }

  // Optional: method to refetch a single provider
  Future<void> refetchProvider(String providerName, VideoSourceKey key) async {
    ProviderSourceResult? result;

    try {
      switch (providerName) {
        case 'river':
          result = await _fetchRiver(key);
          break;
        case 'kisskh':
          result = await _fetchKissKh(key);
          break;
        case 'vidlink':
          result = await _fetchVidLink(key);
          break;
        case 'videasy':
          result = await _fetchVidEasy(key);
          break;
        case 'tg':
          result = await _fetchTg(key);
          break;
      }

      if (result != null) {
        // Update state to include new result
        state.whenData((data) {
          final updated = {...data, providerName: result!};
          state = AsyncData(updated);
        });
      }
    } catch (e) {
      // Silent fail on individual provider refetch
    }
  }
}

// ─── Next Episode Provider (for TV shows) ──────────────────────────────────

final nextEpisodeProvider =
    AsyncNotifierProvider.family<NextEpisodeNotifier, (int, int), String>(
  NextEpisodeNotifier.new,
);

class NextEpisodeNotifier extends FamilyAsyncNotifier<(int, int), String> {
  @override
  Future<(int, int)> build(String tmdbId) async {
    // Placeholder: actual implementation would:
    // 1. Read AppProvider settings for pos_tmdb_{id}_s{S}_e{E}
    // 2. Find last watched episode
    // 3. Return (nextSeason, nextEpisode)
  // For now, default to S1E1
  return (1, 1);
 }
}

// ─── Cache Helper Functions ──────────────────────────────────────────────────

class CacheHelper {
 static Future<bool> isStale(String cacheKey, {int expiryHours = cacheExpiryHours}) async {
   try {
     final prefs = await SharedPreferences.getInstance();
     final timestamp = prefs.getInt('${cacheKey}_timestamp');
     if (timestamp == null) return true;

     final storedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
     final now = DateTime.now();
     final difference = now.difference(storedTime).inHours;

     final isDataStale = difference >= expiryHours;
     return isDataStale;
   } catch (e) {
     debugPrint('Error checking cache staleness: $e');
     return true;
   }
 }

 static Future<void> saveToCache(String cacheKey, String data, {bool isImage = false}) async {
   try {
     final prefs = await SharedPreferences.getInstance();
     await prefs.setString(cacheKey, data);
     await prefs.setInt(
       '${cacheKey}_timestamp',
       DateTime.now().millisecondsSinceEpoch,
     );
     debugPrint('Cache saved: $cacheKey');
   } catch (e) {
     debugPrint('Failed to save cache: $e');
   }
 }

 static Future<String?> getFromCache(String cacheKey) async {
   try {
     final prefs = await SharedPreferences.getInstance();
     final isExpired = await isStale(cacheKey);

     if (isExpired) {
       await prefs.remove('${cacheKey}');
       await prefs.remove('${cacheKey}_timestamp');
       debugPrint('Cache expired and removed: $cacheKey');
       return null;
     }

     final data = prefs.getString(cacheKey);
     if (data != null) {
       debugPrint('Retrieved from cache: $cacheKey');
     }
     return data;
   } catch (e) {
     debugPrint('Error getting from cache: $e');
     return null;
   }
 }

 static Future<void> invalidateCache(String cacheKey) async {
   try {
     final prefs = await SharedPreferences.getInstance();
     await prefs.remove(cacheKey);
     await prefs.remove('${cacheKey}_timestamp');
     debugPrint('Cache invalidated: $cacheKey');
   } catch (e) {
     debugPrint('Failed to invalidate cache: $e');
   }
 }
}

// ─── Media Details Provider (with 24hr cache) ──────────────────────────────

class MediaDetailsState {
  final RiveStreamMediaDetails? details;
  final bool fromCache;

  const MediaDetailsState({
    this.details,
    this.fromCache = false,
  });

  // Helper to check if we have valid data
  bool get hasData => details != null;
}

final mediaDetailsProvider = AsyncNotifierProvider.family<MediaDetailsNotifier, MediaDetailsState, (String, bool)>(
 MediaDetailsNotifier.new,
);

class MediaDetailsNotifier extends FamilyAsyncNotifier<MediaDetailsState, (String, bool)> {
 final _riveService = RiveStreamService();

 @override
 Future<MediaDetailsState> build((String, bool) params) async {
   final (id, isMovie) = params;
   final isTmdb = int.tryParse(id) != null;
   String tmdbId = id;

   // Try cache first
   if (isTmdb) {
     final cacheKey = 'media_details_${isMovie ? "movie" : "tv"}_$tmdbId';
     final cachedData = await CacheHelper.getFromCache(cacheKey);

     if (cachedData != null) {
       try {
         final Map<String, dynamic> json = jsonDecode(cachedData);
         final cachedDetails = RiveStreamMediaDetails.fromJson(json);
         return MediaDetailsState(details: cachedDetails, fromCache: true);
       } catch (e) {
         debugPrint('Failed to parse cached data: $e');
         await CacheHelper.invalidateCache(cacheKey);
       }
     }

     // Cache miss or stale, fetch from API
     try {
       final tmdbIdInt = int.parse(tmdbId);
       final details = await _riveService.getMediaDetails(
         tmdbIdInt,
         isMovie: isMovie,
       );

       // Cache the fresh data
       final cacheKey = 'media_details_${isMovie ? "movie" : "tv"}_$tmdbId';
       if (details != null) {
        try {
          await CacheHelper.saveToCache(cacheKey, jsonEncode(details.toJson()));
        } catch (_) {
          // Silently fail cache save if toJson not available
        }
      }

       return MediaDetailsState(details: details, fromCache: false);
     } catch(e) {
       // Return error state
       throw Exception('Failed to load media details');
     }
   }

   // For non-TMDB IDs (IMDB), convert first
   try {
     if (id.startsWith('tt')) {
       final tmdbId = await _riveService.findTmdbIdFromImdbId(id);
       if (tmdbId != null) {
         final details = await _riveService.getMediaDetails(
           tmdbId,
           isMovie: isMovie,
         );
         return MediaDetailsState(details: details, fromCache: false);
       }
     }
     throw Exception('Invalid media ID');
   } catch (e) {
     rethrow;
   }
 }

 Future<void> refresh((String, bool) params) async {
   state = const AsyncValue.loading();
   state = await AsyncValue.guard(() => build(params));
 }
}

// ─── Recommendations Provider ───────────────────────────────────────────────

class PaginatedRecommendations {
  final List<RiveStreamMedia> items;
  final int currentPage;
  final bool hasMore;

  const PaginatedRecommendations({
    required this.items,
    required this.currentPage,
    required this.hasMore,
  });
}

final mediaRecommendationsProvider = AsyncNotifierProvider.family<MediaRecommendationsNotifier, PaginatedRecommendations, (String, bool)>(
 MediaRecommendationsNotifier.new,
);

class MediaRecommendationsNotifier extends FamilyAsyncNotifier<PaginatedRecommendations, (String, bool)> {
 final _riveService = RiveStreamService();

 @override
 Future<PaginatedRecommendations> build((String, bool) params) async {
   final (id, isMovie) = params;

   return await _fetchPage(id, isMovie, 1);
 }

 Future<PaginatedRecommendations> _fetchPage(String id, bool isMovie, int page) async {
   try {
     final tmdbId = int.tryParse(id);
     if (tmdbId == null) {
       return PaginatedRecommendations(items: [], currentPage: page, hasMore: false);
     }

     final recommendations = await _riveService.getRecommendations(
       tmdbId,
       isMovie: isMovie,
     );

     return PaginatedRecommendations(
       items: recommendations,
       currentPage: page,
       hasMore: recommendations.length >= 20, // Assumes API returns 20 items per page
     );
   } catch (e) {
     debugPrint('Failed to load recommendations: $e');
     return PaginatedRecommendations(
       items: [],
       currentPage: page,
       hasMore: false,
     );
   }
 }

 Future<void> loadMore((String, bool) params) async {
   final currentState = state.valueOrNull;
   if (currentState == null || !currentState.hasMore) return;

   state = AsyncData(PaginatedRecommendations(
     items: currentState.items,
     currentPage: currentState.currentPage,
     hasMore: true, // Keep true while loading
   ));

   final (id, isMovie) = params;
   final nextPage = currentState.currentPage + 1;

   try {
     final newItems = await _fetchPage(id, isMovie, nextPage);

     state = AsyncData(PaginatedRecommendations(
       items: [...currentState.items, ...newItems.items],
       currentPage: nextPage,
       hasMore: newItems.hasMore,
     ));
   } catch (e) {
     state = AsyncData(PaginatedRecommendations(
       items: currentState.items,
       currentPage: currentState.currentPage,
       hasMore: false, // Disable further loading on error
     ));
   }
 }
}

// ─── Cast Provider ─────────────────────────────────────────────────────────────

final mediaCastProvider = AsyncNotifierProvider.family<MediaCastNotifier, List<CastMember>, (String, bool)>(
 MediaCastNotifier.new,
);

class MediaCastNotifier extends FamilyAsyncNotifier<List<CastMember>, (String, bool)> {
 final _riveService = RiveStreamService();

 @override
 Future<List<CastMember>> build((String, bool) params) async {
   final (id, isMovie) = params;

   try {
     final tmdbId = int.tryParse(id);
     if (tmdbId == null) return [];

     final cast = await _riveService.getCast(tmdbId, isMovie: isMovie);
     return cast;
   } catch (e) {
     debugPrint('Failed to load cast: $e');
     return [];
   }
 }
}

// ─── Selected Season/Episode State Providers ─────────────────────────────────

final selectedSeasonProvider = StateProvider<int>((ref) => 1);
final selectedEpisodeProvider = StateProvider<int>((ref) => 1);

// ─── Scroll Controller Provider for Infinite Scrolling ─────────────────────

final scrollControllerProvider = Provider<ScrollController>((ref) {
 final controller = ScrollController();
 ref.onDispose(() => controller.dispose());
 return controller;
});

// ─── Recommendations Pagination State ──────────────────────────────────────

final recommendationsPageProvider = StateProvider<int>((ref) => 1);
final recommendationsHasMoreProvider = StateProvider<bool>((ref) => true);
