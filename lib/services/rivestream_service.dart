import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RiveStreamService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  final String _apiKey = 'd56e51fb77b081a9cb5192eaaa7823ad';

  Future<Response> _get(String path,
      {Map<String, dynamic>? queryParameters}) async {
    try {
      final proxyResponse = await _dio.get(
        'https://imdb.gogram.fun/tmdb$path',
        queryParameters: {
          'api_key': _apiKey,
          'language': 'en-US',
          ...?queryParameters,
        },
      );
      print('Proxy Response: ${proxyResponse.data}');
      if (proxyResponse.statusCode == 200) return proxyResponse;
    } catch (_) {}

    return await _dio.get(
      'https://api.themoviedb.org/3$path',
      queryParameters: {
        'api_key': _apiKey,
        'language': 'en-US',
        ...?queryParameters,
      },
    );
  }

  Future<List<RiveStreamMedia>> getTrending({int page = 1}) async {
    try {
      final response =
          await _get('/trending/all/week', queryParameters: {'page': page});
      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['results'] as List?;
        if (results != null) {
          final items =
              results.map((json) => RiveStreamMedia.fromJson(json)).toList();
          _cacheTrending(page, items);
          return items;
        }
      }
    } catch (e) {
      print('TMDB Trending Error: $e');
    }
    return [];
  }

  Future<void> _cacheTrending(int page, List<RiveStreamMedia> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'tmdb_trending_page_$page';
      final jsonList = items.map((item) => item.toJson()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (_) {}
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
    } catch (_) {}
    return [];
  }

  Future<List<RiveStreamMedia>> searchMulti(String query,
      {int page = 1}) async {
    try {
      final response = await _get('/search/multi', queryParameters: {
        'query': query,
        'page': page,
        'include_adult': false,
      });
      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['results'] as List?;
        if (results != null) {
          return results.map((json) => RiveStreamMedia.fromJson(json)).toList();
        }
      }
    } catch (e) {
      print('TMDB Search Error: $e');
    }
    return [];
  }

  Future<List<RiveStreamMedia>> searchPersonAndGetFilmography(String personName,
      {int page = 1}) async {
    try {
      final searchResponse = await _get('/search/person', queryParameters: {
        'query': personName,
        'page': 1,
        'include_adult': false,
      });

      if (searchResponse.statusCode != 200 || searchResponse.data == null)
        return [];
      final results = searchResponse.data['results'] as List?;
      if (results == null || results.isEmpty) return [];

      final personData = results.first as Map<String, dynamic>;
      final personId = personData['id'] as int?;
      if (personId == null) return [];

      final filmographyResponse =
          await _get('/person/$personId/combined_credits');
      if (filmographyResponse.statusCode != 200 ||
          filmographyResponse.data == null) return [];

      final castList = filmographyResponse.data['cast'] as List?;
      if (castList == null || castList.isEmpty) return [];

      final resultsList = <RiveStreamMedia>[];
      for (final json in castList) {
        try {
          final Map<String, dynamic> data = Map.from(json);
          final posterPath = data['poster_path'];
          if (posterPath == null || posterPath.toString().isEmpty) continue;

          if (!data.containsKey('media_type') || data['media_type'] == null) {
            data['media_type'] = data['title'] != null ? 'movie' : 'tv';
          }

          final media = RiveStreamMedia.fromJson(data);
          if (media.fullPosterUrl.isNotEmpty) resultsList.add(media);
        } catch (_) {}
      }
      return resultsList;
    } catch (e) {
      print('TMDB Person Search Error: $e');
    }
    return [];
  }

  Future<List<RiveStreamMedia>> getRecommendations(int id,
      {bool isMovie = true}) async {
    try {
      final endpoint =
          isMovie ? '/movie/$id/recommendations' : '/tv/$id/recommendations';
      final response = await _get(endpoint, queryParameters: {'page': 1});

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
    } catch (e) {
      print('TMDB Recommendations Error: $e');
    }
    return [];
  }

  Future<int?> findTmdbIdFromImdbId(String imdbId) async {
    try {
      final response = await _get('/find/$imdbId',
          queryParameters: {'external_source': 'imdb_id'});
      if (response.statusCode == 200 && response.data != null) {
        final movieResults = response.data['movie_results'] as List?;
        final tvResults = response.data['tv_results'] as List?;
        if (movieResults != null && movieResults.isNotEmpty)
          return movieResults[0]['id'];
        if (tvResults != null && tvResults.isNotEmpty)
          return tvResults[0]['id'];
      }
    } catch (e) {
      print('TMDB Find Error: $e');
    }
    return null;
  }

  Future<int?> findTmdbIdByTitleAndYear(String title, String year,
      {bool isMovie = true}) async {
    try {
      final response = await _get(isMovie ? '/search/movie' : '/search/tv',
          queryParameters: {
            'query': title,
            if (isMovie && year.isNotEmpty) 'primary_release_year': year,
            if (!isMovie && year.isNotEmpty) 'first_air_date_year': year,
          });

      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          for (final result in results) {
            final resultTitle =
                (isMovie ? result['title'] : result['name']) as String?;
            if (resultTitle?.toLowerCase() == title.toLowerCase())
              return result['id'];
          }
          return results[0]['id'];
        }
      }
    } catch (e) {
      print('TMDB Search By Title Error: $e');
    }
    return null;
  }

  Future<String?> getImdbIdFromTmdbId(int id, {bool isMovie = true}) async {
    try {
      final endpoint =
          isMovie ? '/movie/$id/external_ids' : '/tv/$id/external_ids';
      final response = await _get(endpoint);

      if (response.statusCode == 200 && response.data != null) {
        final imdbId = response.data['imdb_id'] as String?;
        if (imdbId != null && imdbId.isNotEmpty) return imdbId;
      }

      if (isMovie) {
        final movieResponse = await _get('/movie/$id');
        if (movieResponse.statusCode == 200 && movieResponse.data != null) {
          return movieResponse.data['imdb_id'] as String?;
        }
      }
    } catch (e) {
      print('TMDB External IDs Error for ID $id: $e');
    }
    return null;
  }

  Future<RiveStreamMediaDetails?> getMediaDetails(int id,
      {bool isMovie = true}) async {
    final cacheKey = 'tmdb_details_${isMovie ? "movie" : "tv"}_$id';
    try {
      final endpoint = isMovie ? '/movie/$id' : '/tv/$id';
      final response = await _get(endpoint,
          queryParameters: {'append_to_response': 'external_ids'});

      if (response.statusCode == 200 && response.data != null) {
        if (!isMovie && response.data['external_ids'] != null) {
          response.data['imdb_id'] = response.data['external_ids']['imdb_id'];
        }
        final details = RiveStreamMediaDetails.fromJson(response.data);
        _saveToCache(cacheKey, jsonEncode(response.data));
        return details;
      }
    } catch (e) {
      print('TMDB Media Details Error: $e');
    }
    return getCachedMediaDetails(id, isMovie: isMovie);
  }

  Future<RiveStreamMediaDetails?> getCachedMediaDetails(int id,
      {bool isMovie = true}) async {
    try {
      final cacheKey = 'tmdb_details_${isMovie ? "movie" : "tv"}_$id';
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        if (!isMovie && json['external_ids'] != null) {
          json['imdb_id'] = json['external_ids']['imdb_id'];
        }
        return RiveStreamMediaDetails.fromJson(json);
      }
    } catch (_) {}
    return null;
  }

  Future<List<RiveStreamEpisode>> getSeasonDetails(
      int tvId, int seasonNumber) async {
    final cacheKey = 'tmdb_season_${tvId}_$seasonNumber';
    try {
      final response = await _get('/tv/$tvId/season/$seasonNumber');
      if (response.statusCode == 200 && response.data != null) {
        final episodes = response.data['episodes'] as List?;
        if (episodes != null) {
          _saveToCache(cacheKey, jsonEncode(episodes));
          return episodes
              .map((json) => RiveStreamEpisode.fromJson(json))
              .toList();
        }
      }
    } catch (e) {
      print('TMDB Season Details Error: $e');
    }
    return getCachedSeasonDetails(tvId, seasonNumber);
  }

  Future<List<RiveStreamEpisode>> getCachedSeasonDetails(
      int tvId, int seasonNumber) async {
    try {
      final cacheKey = 'tmdb_season_${tvId}_$seasonNumber';
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw != null) {
        final episodes = jsonDecode(raw) as List<dynamic>;
        return episodes
            .map((json) => RiveStreamEpisode.fromJson(json))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> getCastAndCrew(int id,
      {bool isMovie = true}) async {
    final cacheKey = 'tmdb_credits_${isMovie ? "movie" : "tv"}_$id';
    try {
      final endpoint = isMovie ? '/movie/$id/credits' : '/tv/$id/credits';
      final response = await _get(endpoint);

      if (response.statusCode == 200 && response.data != null) {
        final List<CastMember> cast = (response.data['cast'] as List?)
                ?.take(10)
                .map((json) => CastMember.fromJson(json))
                .toList() ??
            <CastMember>[];
        final result = {
          'cast': cast,
          'crew': response.data['crew'] as List? ?? [],
        };
        _saveToCache(cacheKey, jsonEncode(response.data));
        return result;
      }
    } catch (e) {
      print('TMDB Credits Error: $e');
    }
    return getCachedCastAndCrew(id, isMovie: isMovie);
  }

  Future<Map<String, dynamic>> getCachedCastAndCrew(int id,
      {bool isMovie = true}) async {
    try {
      final cacheKey = 'tmdb_credits_${isMovie ? "movie" : "tv"}_$id';
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final List<CastMember> cast = (data['cast'] as List?)
                ?.take(10)
                .map((json) => CastMember.fromJson(json))
                .toList() ??
            <CastMember>[];
        return {
          'cast': cast,
          'crew': data['crew'] as List? ?? [],
        };
      }
    } catch (_) {}
    return {'cast': [], 'crew': []};
  }

  Future<List<RiveStreamMedia>> getDiscoverContent({
    required String mediaType,
    String? watchProviders,
    String? monetizationTypes,
    int page = 1,
  }) async {
    final cacheKey =
        'tmdb_discover_${mediaType}_${watchProviders ?? "all"}_${monetizationTypes ?? "all"}_$page';
    try {
      final response = await _get('/discover/$mediaType', queryParameters: {
        'page': page,
        'sort_by': 'popularity.desc',
        'include_adult': false,
        'include_video': false,
        'with_watch_providers': watchProviders,
        'with_watch_monetization_types': monetizationTypes,
        'watch_region': 'IN',
      });

      if (response.statusCode == 200 && response.data != null) {
        final results = response.data['results'] as List?;
        if (results != null) {
          final items = results.map((json) {
            final Map<String, dynamic> data = Map.from(json);
            data['media_type'] = mediaType;
            return RiveStreamMedia.fromJson(data);
          }).toList();
          final jsonList = items.map((i) => i.toJson()).toList();
          _saveToCache(cacheKey, jsonEncode(jsonList));
          return items;
        }
      }
    } catch (e) {
      print('TMDB Discover Error: $e');
    }
    return getCachedDiscoverContent(
        mediaType: mediaType,
        watchProviders: watchProviders,
        monetizationTypes: monetizationTypes,
        page: page);
  }

  Future<List<RiveStreamMedia>> getCachedDiscoverContent({
    required String mediaType,
    String? watchProviders,
    String? monetizationTypes,
    int page = 1,
  }) async {
    try {
      final cacheKey =
          'tmdb_discover_${mediaType}_${watchProviders ?? "all"}_${monetizationTypes ?? "all"}_$page';
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        return list.map((json) => RiveStreamMedia.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  void _saveToCache(String key, String value) {
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(key, value))
        .catchError((_) => true);
  }
}

class RiveStreamMedia {
  final int id;
  final String? title;
  final String? name;
  final String? originalTitle;
  final String? originalName;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String mediaType;
  final String? originalLanguage;
  final List<int> genreIds;
  final double popularity;
  final String? releaseDate;
  final String? firstAirDate;
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
      posterPath: json['poster_path'] ?? json['poster'],
      backdropPath: json['backdrop_path'] ?? json['backdrop'],
      mediaType: json['media_type'] ?? 'movie',
      originalLanguage: json['original_language'],
      genreIds: (json['genre_ids'] as List?)?.cast<int>() ?? [],
      popularity: (json['popularity'] ?? 0.0).toDouble(),
      releaseDate: json['release_date'],
      firstAirDate: json['first_air_date'],
      voteAverage: (json['vote_average'] ?? json['rating'] ?? 0.0).toDouble(),
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
            ?.map((g) => g is String ? g : (g['name'] as String? ?? ''))
            .where((g) => g.isNotEmpty)
            .toList() ??
        [];
    final companies = (json['production_companies'] as List?)
            ?.map((c) => c is String ? c : (c['name'] as String? ?? ''))
            .where((name) => name.isNotEmpty)
            .toList() ??
        [];
    final countries = (json['production_countries'] as List?)
            ?.map((c) => c is String ? c : (c['name'] as String? ?? ''))
            .where((name) => name.isNotEmpty)
            .toList() ??
        [];
    final languages = (json['spoken_languages'] as List?)
            ?.map((l) => l is String ? l : (l['english_name'] as String? ?? ''))
            .where((name) => name.isNotEmpty)
            .toList() ??
        [];

    return RiveStreamMediaDetails(
      id: json['id'] ?? 0,
      title: json['title'],
      name: json['name'],
      overview: json['overview'],
      posterPath: json['poster_path'] ?? json['poster'],
      backdropPath: json['backdrop_path'] ?? json['backdrop'],
      voteAverage: (json['vote_average'] ?? json['rating'] ?? 0.0).toDouble(),
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
      stillPath: json['still_path'] ?? json['still'],
      episodeNumber: json['episode_number'] ?? 0,
      seasonNumber: json['season_number'] ?? 0,
      voteAverage: (json['vote_average'] ?? json['rating'] ?? 0.0).toDouble(),
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
      profilePath: json['profile_path'] ?? json['profile_image'],
      order: json['order'] ?? 0,
    );
  }

  String get fullProfileUrl =>
      profilePath != null ? 'https://image.tmdb.org/t/p/w185$profilePath' : '';
}
