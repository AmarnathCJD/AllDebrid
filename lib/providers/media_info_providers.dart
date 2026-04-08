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
const int cacheExpiryHours = 24;
const int imageCacheExpiryHours = 168;

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

// ─── Video Sources Provider ────────────────────────────────────────────────

final videoSourcesProvider =
    FutureProvider.family<Map<String, ProviderSourceResult>, VideoSourceKey>(
  (ref, key) async {
    final videoSourceService = VideoSourceService();
    final kissKhService = KissKhService();
    final vidLinkService = VidLinkService();
    final vidEasyService = VidEasyService();
    final tgService = TgService();

    final results = <String, ProviderSourceResult>{};

    try {
      final futures = <Future<ProviderSourceResult?>>[
        _videoFetchRiver(videoSourceService, key),
        _videoFetchKissKh(kissKhService, key),
        _videoFetchVidLink(vidLinkService, key),
        _videoFetchVidEasy(vidEasyService, key),
        _videoFetchTg(tgService, key),
      ];

      final allResults = await Future.wait(futures, eagerError: false);

      for (final result in allResults) {
        if (result != null && (result.sources.isNotEmpty || result.isTg)) {
          results[result.providerName] = result;
        }
      }
    } catch (e) {
      debugPrint('[VideoSourcesProvider] Error: $e');
    }

    return results;
  },
);

// Helper functions for video source fetching
Future<ProviderSourceResult?> _videoFetchRiver(
  VideoSourceService videoSourceService,
  VideoSourceKey key,
) async {
  try {
    final response = await videoSourceService.getVideoSources(
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

Future<ProviderSourceResult?> _videoFetchKissKh(
  KissKhService kissKhService,
  VideoSourceKey key,
) async {
  try {
    final response = await kissKhService.getSources(
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

Future<ProviderSourceResult?> _videoFetchVidLink(
  VidLinkService vidLinkService,
  VideoSourceKey key,
) async {
  try {
    final tmdbInt = int.tryParse(key.tmdbId) ?? 0;
    final response = await vidLinkService.getSources(
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

Future<ProviderSourceResult?> _videoFetchVidEasy(
  VidEasyService vidEasyService,
  VideoSourceKey key,
) async {
  try {
    final tmdbInt = int.tryParse(key.tmdbId) ?? 0;
    final response = await vidEasyService.getSources(
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

Future<ProviderSourceResult?> _videoFetchTg(
  TgService tgService,
  VideoSourceKey key,
) async {
  try {
    if (key.isMovie) {
      final checkResult = await tgService.checkMovie(key.tmdbId);
      if (checkResult != null && checkResult.qualities.isNotEmpty) {
        return const ProviderSourceResult(
          providerName: 'tg',
          sources: [],
          captions: [],
          isTg: true,
        );
      }
    } else {
      final imdbId = key.imdbId;
      if (imdbId != null) {
        final checkResult = await tgService.check(imdbId);
        if (checkResult != null && checkResult.qualities.isNotEmpty) {
          return const ProviderSourceResult(
            providerName: 'tg',
            sources: [],
            captions: [],
            isTg: true,
          );
        }
      }
    }
    return const ProviderSourceResult(
      providerName: 'tg',
      sources: [],
      captions: [],
      isTg: true,
    );
  } catch (e) {
    return const ProviderSourceResult(
      providerName: 'tg',
      sources: [],
      captions: [],
      isTg: true,
    );
  }
}

// ─── Cache Helper Functions ──────────────────────────────────────────────────

class CacheHelper {
  static Future<bool> isStale(String cacheKey,
      {int expiryHours = cacheExpiryHours}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('${cacheKey}_timestamp');
      if (timestamp == null) return true;
      final storedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final difference = now.difference(storedTime).inHours;
      return difference >= expiryHours;
    } catch (e) {
      debugPrint('Error checking cache staleness: $e');
      return true;
    }
  }

  static Future<void> saveToCache(String cacheKey, String data,
      {bool isImage = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, data);
      await prefs.setInt(
          '${cacheKey}_timestamp', DateTime.now().millisecondsSinceEpoch);
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
        await prefs.remove(cacheKey);
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

// ─── Media Details Provider ──────────────────────────────────────────────────

class MediaDetailsState {
  final RiveStreamMediaDetails? details;
  final bool fromCache;

  const MediaDetailsState({
    this.details,
    this.fromCache = false,
  });

  bool get hasData => details != null;
}

final mediaDetailsProvider =
    FutureProvider.family<MediaDetailsState, (String, bool)>(
  (ref, params) async {
    final (id, isMovie) = params;
    final riveService = RiveStreamService();
    final isTmdb = int.tryParse(id) != null;
    String tmdbId = id;

    if (isTmdb) {
      final cacheKey = 'media_details_${isMovie ? "movie" : "tv"}_$tmdbId';
      final cachedData = await CacheHelper.getFromCache(cacheKey);

      if (cachedData != null) {
        try {
          final Map<String, dynamic> json = jsonDecode(cachedData);
          final cachedDetails = RiveStreamMediaDetails.fromJson(json);
          return MediaDetailsState(details: cachedDetails, fromCache: true);
        } catch (e) {
          debugPrint('[MediaDetailsProvider] Cache parse error: $e');
        }
      }
    }

    try {
      final details = await riveService.getMediaDetails(int.parse(tmdbId),
          isMovie: isMovie);

      if (isTmdb && details != null) {
        final cacheKey = 'media_details_${isMovie ? "movie" : "tv"}_$tmdbId';
        await CacheHelper.saveToCache(cacheKey, jsonEncode(details.toJson()));
      }

      return MediaDetailsState(details: details, fromCache: false);
    } catch (e) {
      debugPrint('[MediaDetailsProvider] Fetch error: $e');
      return const MediaDetailsState();
    }
  },
);

// ─── Next Episode Provider ──────────────────────────────────────────────────

final nextEpisodeProvider = FutureProvider.family<(int, int), String>(
  (ref, id) async => (1, 1),
);

// ─── Media Recommendations Provider ────────────────────────────────────────

class PaginatedRecommendations {
  final List<RiveStreamMedia> items;
  final int page;
  final bool hasMore;

  const PaginatedRecommendations({
    required this.items,
    required this.page,
    required this.hasMore,
  });
}

final mediaRecommendationsProvider =
    FutureProvider.family<PaginatedRecommendations, (String, bool)>(
  (ref, params) async {
    final (tmdbId, isMovie) = params;
    final riveService = RiveStreamService();

    try {
      final recommendations = await riveService.getRecommendations(
        int.parse(tmdbId),
        isMovie: isMovie,
        page: 1,
      );
      return PaginatedRecommendations(
        items: recommendations,
        page: 1,
        hasMore: recommendations.length >= 20,
      );
    } catch (e) {
      debugPrint('[MediaRecommendationsProvider] Error: $e');
      return const PaginatedRecommendations(items: [], page: 1, hasMore: false);
    }
  },
);

// ─── Media Cast Provider ────────────────────────────────────────────────────

final mediaCastProvider =
    FutureProvider.family<List<CastMember>, (String, bool)>(
  (ref, params) async {
    final (tmdbId, isMovie) = params;
    final riveService = RiveStreamService();

    try {
      final cast =
          await riveService.getCast(int.parse(tmdbId), isMovie: isMovie);
      return cast.take(10).toList();
    } catch (e) {
      debugPrint('[MediaCastProvider] Error: $e');
      return [];
    }
  },
);

// ─── Season Episodes Provider ──────────────────────────────────────────────

class SeasonEpisodesKey {
  final String id;
  final int season;

  const SeasonEpisodesKey(this.id, this.season);

  @override
  bool operator ==(Object other) =>
      other is SeasonEpisodesKey && id == other.id && season == other.season;

  @override
  int get hashCode => Object.hash(id, season);
}

final seasonEpisodesProvider =
    FutureProvider.family<List<RiveStreamEpisode>, SeasonEpisodesKey>(
  (ref, key) async {
    final riveService = RiveStreamService();
    final tvId = int.tryParse(key.id);

    if (tvId == null) return [];

    try {
      final episodes = await riveService.getSeasonDetails(tvId, key.season);
      return episodes;
    } catch (e) {
      debugPrint('[SeasonEpisodesProvider] Error: $e');
      return [];
    }
  },
);
