import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RiveStreamService {
  final Dio _dio;

  RiveStreamService()
      : _dio = Dio(BaseOptions(
          baseUrl: 'https://api.themoviedb.org/3',
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ));

  final String _apiKey = 'd56e51fb77b081a9cb5192eaaa7823ad';

  Future<List<RiveStreamMedia>> getTrending({int page = 1}) async {
    try {
      final response = await _dio.get(
        '/trending/all/week',
        queryParameters: {
          'api_key': _apiKey,
          'language': 'en-US',
          'page': page,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['results'] as List?;
        if (results != null) {
          final items =
              results.map((json) => RiveStreamMedia.fromJson(json)).toList();
          _cacheTrending(page, items);
          return items;
        }
      }
      return [];
    } catch (e) {
      print('TMDB Trending Error: $e');
      return [];
    }
  }

  Future<void> _cacheTrending(int page, List<RiveStreamMedia> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'tmdb_trending_page_$page';
      final jsonList = items.map((item) => item.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (e) {
      print('Error caching trending page $page: $e');
    }
  }

  Future<List<RiveStreamMedia>> getCachedTrending({int page = 1}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'tmdb_trending_page_$page';
      final jsonString = prefs.getString(key);
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        return jsonList.map((json) => RiveStreamMedia.fromJson(json)).toList();
      }
    } catch (e) {
      print('Error loading cached trending page $page: $e');
    }
    return [];
  }

  /// Fetch latest movies
  Future<List<RiveStreamMedia>> getLatestMovies({int page = 1}) async {
    try {
      final response = await _dio.get(
        '/movie/now_playing',
        queryParameters: {
          'api_key': _apiKey,
          'language': 'en-US',
          'page': page,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['results'] as List?;
        if (results != null) {
          return results.map((json) {
            // Ensure media_type is set for consistency
            final Map<String, dynamic> data = Map.from(json);
            data['media_type'] = 'movie';
            return RiveStreamMedia.fromJson(data);
          }).toList();
        }
      }
      return [];
    } catch (e) {
      print('TMDB Latest Movies Error: $e');
      return [];
    }
  }

  /// Search for movies/TV shows
  Future<List<RiveStreamMedia>> searchMulti(String query,
      {int page = 1}) async {
    try {
      final response = await _dio.get(
        '/search/multi',
        queryParameters: {
          'api_key': _apiKey,
          'query': query,
          'language': 'en-US',
          'page': page,
          'include_adult': false,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['results'] as List?;
        if (results != null) {
          return results.map((json) => RiveStreamMedia.fromJson(json)).toList();
        }
      }
      return [];
    } catch (e) {
      print('TMDB Search Error: $e');
      return [];
    }
  }

  Future<List<RiveStreamMedia>> getRecommendations(int id,
      {bool isMovie = true}) async {
    try {
      final endpoint =
          isMovie ? '/movie/$id/recommendations' : '/tv/$id/recommendations';

      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'api_key': _apiKey,
          'language': 'en-US',
          'page': 1,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['results'] as List?;
        if (results != null) {
          return results
              .map((json) {
                final Map<String, dynamic> data = Map.from(json);
                data['media_type'] = isMovie ? 'movie' : 'tv';
                return RiveStreamMedia.fromJson(data);
              })
              .where((item) =>
                  item.posterPath != null && item.posterPath!.isNotEmpty)
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('TMDB Recommendations Error: $e');
      return [];
    }
  }

  Future<int?> findTmdbIdFromImdbId(String imdbId) async {
    try {
      final response = await _dio.get(
        '/find/$imdbId',
        queryParameters: {
          'api_key': _apiKey,
          'external_source': 'imdb_id',
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final movieResults = response.data['movie_results'] as List?;
        final tvResults = response.data['tv_results'] as List?;

        if (movieResults != null && movieResults.isNotEmpty) {
          return movieResults[0]['id'];
        }
        if (tvResults != null && tvResults.isNotEmpty) {
          return tvResults[0]['id'];
        }
      }
      return null;
    } catch (e) {
      print('TMDB Find Error: $e');
      return null;
    }
  }

  Future<String?> getImdbIdFromTmdbId(int id, {bool isMovie = true}) async {
    try {
      final endpoint =
          isMovie ? '/movie/$id/external_ids' : '/tv/$id/external_ids';
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'api_key': _apiKey,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final imdbId = response.data['imdb_id'] as String?;
        if (imdbId != null && imdbId.isNotEmpty) {
          return imdbId;
        }
      }

      if (isMovie) {
        final movieResponse = await _dio.get(
          '/movie/$id',
          queryParameters: {
            'api_key': _apiKey,
          },
        );
        if (movieResponse.statusCode == 200 && movieResponse.data != null) {
          return movieResponse.data['imdb_id'] as String?;
        }
      }

      return null;
    } catch (e) {
      print('TMDB External IDs Error for ID $id: $e');
      return null;
    }
  }

  Future<RiveStreamMediaDetails?> getMediaDetails(int id,
      {bool isMovie = true}) async {
    try {
      final endpoint = isMovie ? '/movie/$id' : '/tv/$id';
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'api_key': _apiKey,
          'language': 'en-US',
          'append_to_response': 'external_ids',
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        // For TV shows, the imdb_id is nested in external_ids
        if (!isMovie && response.data['external_ids'] != null) {
          response.data['imdb_id'] = response.data['external_ids']['imdb_id'];
        }
        return RiveStreamMediaDetails.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('TMDB Media Details Error: $e');
      return null;
    }
  }

  /// Get season details (episodes)
  Future<List<RiveStreamEpisode>> getSeasonDetails(
      int tvId, int seasonNumber) async {
    try {
      final response = await _dio.get(
        '/tv/$tvId/season/$seasonNumber',
        queryParameters: {
          'api_key': _apiKey,
          'language': 'en-US',
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final episodes = response.data['episodes'] as List?;
        if (episodes != null) {
          return episodes
              .map((json) => RiveStreamEpisode.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('TMDB Season Details Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getCastAndCrew(int id,
      {bool isMovie = true}) async {
    try {
      final endpoint = isMovie ? '/movie/$id/credits' : '/tv/$id/credits';
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'api_key': _apiKey,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return {
          'cast': (response.data['cast'] as List?)
                  ?.take(10)
                  .map((json) => CastMember.fromJson(json))
                  .toList() ??
              [],
          'crew': response.data['crew'] as List? ?? [],
        };
      }
      return {'cast': [], 'crew': []};
    } catch (e) {
      print('TMDB Credits Error: $e');
      return {'cast': [], 'crew': []};
    }
  }

  Future<List<RiveStreamMedia>> getDiscoverContent({
    required String mediaType,
    String? watchProviders,
    String? monetizationTypes,
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '/discover/$mediaType',
        queryParameters: {
          'api_key': _apiKey,
          'language': 'en-US',
          'page': page,
          'sort_by': 'popularity.desc',
          'include_adult': false,
          'include_video': false,
          'with_watch_providers': watchProviders,
          'with_watch_monetization_types': monetizationTypes,
          'watch_region': 'IN',
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['results'] as List?;
        if (results != null) {
          return results.map((json) {
            final Map<String, dynamic> data = Map.from(json);
            data['media_type'] = mediaType;
            return RiveStreamMedia.fromJson(data);
          }).toList();
        }
      }
      return [];
    } catch (e) {
      print('TMDB Discover Error: $e');
      return [];
    }
  }
}

/// Model for media items (movies/TV shows)
class RiveStreamMedia {
  final int id;
  final String? title; // For movies
  final String? name; // For TV shows
  final String? originalTitle;
  final String? originalName;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String mediaType; // 'movie' or 'tv'
  final String? originalLanguage;
  final List<int> genreIds;
  final double popularity;
  final String? releaseDate; // For movies
  final String? firstAirDate; // For TV shows
  final double voteAverage;
  final int voteCount;
  final bool adult;

  RiveStreamMedia({
    required this.id,
    this.title,
    this.name,
    this.originalTitle,
    this.originalName,
    this.overview,
    this.posterPath,
    this.backdropPath,
    required this.mediaType,
    this.originalLanguage,
    this.genreIds = const [],
    this.popularity = 0.0,
    this.releaseDate,
    this.firstAirDate,
    this.voteAverage = 0.0,
    this.voteCount = 0,
    this.adult = false,
  });

  factory RiveStreamMedia.fromJson(Map<String, dynamic> json) {
    return RiveStreamMedia(
      id: json['id'] ?? 0,
      title: json['title'],
      name: json['name'],
      originalTitle: json['original_title'],
      originalName: json['original_name'],
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      mediaType: json['media_type'] ?? 'movie',
      originalLanguage: json['original_language'],
      genreIds: (json['genre_ids'] as List?)?.cast<int>() ?? [],
      popularity: (json['popularity'] ?? 0.0).toDouble(),
      releaseDate: json['release_date'],
      firstAirDate: json['first_air_date'],
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
      adult: json['adult'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'name': name,
        'original_title': originalTitle,
        'original_name': originalName,
        'overview': overview,
        'poster_path': posterPath,
        'backdrop_path': backdropPath,
        'media_type': mediaType,
        'original_language': originalLanguage,
        'genre_ids': genreIds,
        'popularity': popularity,
        'release_date': releaseDate,
        'first_air_date': firstAirDate,
        'vote_average': voteAverage,
        'vote_count': voteCount,
        'adult': adult,
      };

  String get displayTitle => title ?? name ?? 'Unknown';
  String get displayDate => releaseDate ?? firstAirDate ?? '';
  String get fullPosterUrl {
    if (posterPath == null || posterPath!.isEmpty) return '';
    if (posterPath!.startsWith('http')) return posterPath!;
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }

  String get fullBackdropUrl => backdropPath != null
      ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
      : '';
}

class RiveStreamMediaDetails {
  final int id;
  final String? title;
  final String? name;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double voteAverage;
  final int voteCount;
  final String? releaseDate;
  final String? firstAirDate;
  final int? runtime;
  final List<String> genres;
  final String? status;
  final String? tagline;
  final int? budget;
  final int? revenue;
  final double? popularity;
  final List<String> productionCompanies;
  final List<String> productionCountries;
  final List<String> spokenLanguages;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final String? imdbId;

  RiveStreamMediaDetails({
    required this.id,
    this.title,
    this.name,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.voteAverage = 0.0,
    this.voteCount = 0,
    this.releaseDate,
    this.firstAirDate,
    this.runtime,
    this.genres = const [],
    this.status,
    this.tagline,
    this.budget,
    this.revenue,
    this.popularity,
    this.productionCompanies = const [],
    this.productionCountries = const [],
    this.spokenLanguages = const [],
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.imdbId,
  });

  factory RiveStreamMediaDetails.fromJson(Map<String, dynamic> json) {
    final genresList = (json['genres'] as List?)
            ?.map((g) => g['name'] as String? ?? '')
            .where((g) => g.isNotEmpty)
            .toList() ??
        [];

    final companies = (json['production_companies'] as List?)
            ?.map((c) => c['name'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .toList() ??
        [];

    final countries = (json['production_countries'] as List?)
            ?.map((c) => c['name'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .toList() ??
        [];

    final languages = (json['spoken_languages'] as List?)
            ?.map((l) => l['english_name'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .toList() ??
        [];

    return RiveStreamMediaDetails(
      id: json['id'] ?? 0,
      title: json['title'],
      name: json['name'],
      overview: json['overview'],
      posterPath: json['poster_path'],
      backdropPath: json['backdrop_path'],
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      voteCount: json['vote_count'] ?? 0,
      releaseDate: json['release_date'],
      firstAirDate: json['first_air_date'],
      runtime: json['runtime'],
      genres: genresList,
      status: json['status'],
      tagline: json['tagline'],
      budget: json['budget'],
      revenue: json['revenue'],
      popularity: (json['popularity'] ?? 0.0).toDouble(),
      productionCompanies: companies,
      productionCountries: countries,
      spokenLanguages: languages,
      numberOfSeasons: json['number_of_seasons'],
      numberOfEpisodes: json['number_of_episodes'],
      imdbId: json['imdb_id'],
    );
  }

  String get displayTitle => title ?? name ?? 'Unknown';
  String get fullPosterUrl =>
      posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : '';
  String get ogPosterUrl => posterPath != null
      ? 'https://image.tmdb.org/t/p/original$posterPath'
      : '';
  String get ogBackdropUrl => backdropPath != null
      ? 'https://image.tmdb.org/t/p/original$backdropPath'
      : '';
  String get fullBackdropUrl => backdropPath != null
      ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
      : '';
}

class RiveStreamEpisode {
  final int id;
  final String? name;
  final String? overview;
  final String? stillPath;
  final int episodeNumber;
  final int seasonNumber;
  final double voteAverage;
  final String? airDate;

  RiveStreamEpisode({
    required this.id,
    this.name,
    this.overview,
    this.stillPath,
    required this.episodeNumber,
    required this.seasonNumber,
    this.voteAverage = 0.0,
    this.airDate,
  });

  factory RiveStreamEpisode.fromJson(Map<String, dynamic> json) {
    return RiveStreamEpisode(
      id: json['id'] ?? 0,
      name: json['name'],
      overview: json['overview'],
      stillPath: json['still_path'],
      episodeNumber: json['episode_number'] ?? 0,
      seasonNumber: json['season_number'] ?? 0,
      voteAverage: (json['vote_average'] ?? 0.0).toDouble(),
      airDate: json['air_date'],
    );
  }

  String get fullStillUrl =>
      stillPath != null ? 'https://image.tmdb.org/t/p/w400$stillPath' : '';

  String get ogStillUrl =>
      stillPath != null ? 'https://image.tmdb.org/t/p/original$stillPath' : '';
}

class CastMember {
  final int id;
  final String name;
  final String? character;
  final String? profilePath;
  final int order;

  CastMember({
    required this.id,
    required this.name,
    this.character,
    this.profilePath,
    required this.order,
  });

  factory CastMember.fromJson(Map<String, dynamic> json) {
    return CastMember(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      character: json['character'],
      profilePath: json['profile_path'],
      order: json['order'] ?? 0,
    );
  }

  String get fullProfileUrl =>
      profilePath != null ? 'https://image.tmdb.org/t/p/w185$profilePath' : '';
}
