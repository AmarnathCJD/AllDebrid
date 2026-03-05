import 'package:dio/dio.dart';

class TgCheckResult {
  final bool success;
  final String imdbId;
  final List<String> qualities;

  TgCheckResult({
    required this.success,
    required this.imdbId,
    required this.qualities,
  });
}

class TgStatusQuality {
  final String label;
  final int files;
  final bool ready;

  TgStatusQuality({
    required this.label,
    required this.files,
    required this.ready,
  });
}

class TgStatusResult {
  final bool success;
  final bool ready;
  final List<TgStatusQuality> qualities;

  TgStatusResult({
    required this.success,
    required this.ready,
    required this.qualities,
  });
}

class TgStreamResult {
  final String quality;
  final String hash;
  final String url;

  TgStreamResult({
    required this.quality,
    required this.hash,
    required this.url,
  });
}

class TgMovieFile {
  final String name;
  final int fileSize;
  final String messageId;
  final bool ready;

  TgMovieFile({
    required this.name,
    required this.fileSize,
    required this.messageId,
    required this.ready,
  });

  factory TgMovieFile.fromJson(Map<String, dynamic> json) => TgMovieFile(
        name: json['name']?.toString() ?? 'Unknown',
        fileSize: json['file_size'] ?? 0,
        messageId: json['message_id']?.toString() ?? '',
        ready: json['ready'] == true,
      );
}

class TgQualityFiles {
  final String label;
  final List<TgMovieFile> files;

  TgQualityFiles({
    required this.label,
    required this.files,
  });

  factory TgQualityFiles.fromJson(Map<String, dynamic> json) => TgQualityFiles(
        label: json['label']?.toString() ?? 'Unknown',
        files: (json['files'] as List? ?? [])
            .map((f) => TgMovieFile.fromJson(f))
            .toList(),
      );
}

class TgMovieCheckResult {
  final bool success;
  final String title;
  final String tmdbId;
  final String year;
  final List<TgQualityFiles> qualities;

  TgMovieCheckResult({
    required this.success,
    required this.title,
    required this.tmdbId,
    required this.year,
    required this.qualities,
  });

  factory TgMovieCheckResult.fromJson(Map<String, dynamic> json) =>
      TgMovieCheckResult(
        success: json['success'] == true,
        title: json['title']?.toString() ?? '',
        tmdbId: json['tmdb_id']?.toString() ?? '',
        year: json['year']?.toString() ?? '',
        qualities: (json['qualities'] as List? ?? [])
            .map((q) => TgQualityFiles.fromJson(q))
            .toList(),
      );
}

class TgService {
  static const String baseUrl = 'https://cdok.gogram.fun';
  final Dio _dio = Dio(BaseOptions(
    validateStatus: (status) => true,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': 'AllDebrid',
      'Accept': 'application/json',
    },
  ));

  Future<TgCheckResult?> check(String imdbId) async {
    try {
      print('[TG] Checking $baseUrl/check?imdb_id=$imdbId');
      final response = await _dio.get(
        '$baseUrl/check',
        queryParameters: {'imdb_id': imdbId},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final qualities = (response.data['qualities'] as List?)
                ?.map((q) => q.toString())
                .toList() ??
            [];
        return TgCheckResult(
          success: true,
          imdbId: imdbId,
          qualities: qualities,
        );
      }
    } catch (e) {
      print('[TG] Check error: $e');
    }
    return null;
  }

  Future<TgMovieCheckResult?> checkMovie(String tmdbId) async {
    try {
      print('[TG] Checking Movie $baseUrl/check-movie?tmdb_id=$tmdbId');
      final response = await _dio.get(
        '$baseUrl/check-movie',
        queryParameters: {'tmdb_id': tmdbId},
      );

      if (response.statusCode == 200) {
        return TgMovieCheckResult.fromJson(response.data);
      }
    } catch (e) {
      print('[TG] checkMovie error: $e');
    }
    return null;
  }

  Future<TgStatusResult?> status(String imdbId) async {
    try {
      final response = await _dio.get(
        '$baseUrl/status',
        queryParameters: {'imdb_id': imdbId},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true || data['qualities'] != null) {
          final qualitiesList = (data['qualities'] as List?) ?? [];
          final qualities = qualitiesList.map((q) {
            if (q is String) {
              return TgStatusQuality(
                label: q,
                files: 1,
                ready: true,
              );
            }
            final map = q as Map<String, dynamic>;
            return TgStatusQuality(
              label: map['label']?.toString() ??
                  map['quality']?.toString() ??
                  'Unknown',
              files: map['files'] ?? 0,
              ready: map['ready'] == true,
            );
          }).toList();

          return TgStatusResult(
            success: true,
            ready: data['ready'] == true || qualities.any((q) => q.ready),
            qualities: qualities,
          );
        }
      }
    } catch (e) {
      print('[TG] Status error: $e');
    }
    return null;
  }

  Future<TgStatusResult?> statusMovie(String tmdbId) async {
    try {
      print('[TG] Checking status Movie $baseUrl/status-movie?tmdb_id=$tmdbId');
      final response = await _dio.get(
        '$baseUrl/status-movie',
        queryParameters: {'tmdb_id': tmdbId},
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true || data['qualities'] != null) {
          final qualitiesList = (data['qualities'] as List?) ?? [];
          final qualities = qualitiesList.map((q) {
            if (q is String) {
              return TgStatusQuality(
                label: q,
                files: 1,
                ready: true,
              );
            }
            final map = q as Map<String, dynamic>;
            return TgStatusQuality(
              label: map['label']?.toString() ??
                  map['quality']?.toString() ??
                  'Unknown',
              files: map['files'] ?? 0,
              ready: map['ready'] == true,
            );
          }).toList();

          return TgStatusResult(
            success: true,
            ready: data['ready'] == true || qualities.any((q) => q.ready),
            qualities: qualities,
          );
        }
      }
    } catch (e) {
      print('[TG] statusMovie error: $e');
    }
    return null;
  }

  Future<List<TgStreamResult>> getStreams(
    String imdbId, {
    int? season,
    int? episode,
  }) async {
    try {
      final Map<String, dynamic> params = {'imdb_id': imdbId};
      if (season != null && episode != null) {
        params['s'] = season;
        params['e'] = episode;
      }

      final response = await _dio.get(
        '$baseUrl/get',
        queryParameters: params,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final results = response.data['results'] as List? ?? [];
        return results
            .map((r) => TgStreamResult(
                  quality: r['quality']?.toString() ?? 'Unknown',
                  hash: r['hash']?.toString() ?? '',
                  url: r['url']?.toString() ?? '',
                ))
            .toList();
      }
    } catch (e) {
      print('[TG] GetStreams error: $e');
    }
    return [];
  }

  Future<List<TgStreamResult>> getMovieStreams(String tmdbId,
      {String? quality}) async {
    try {
      final Map<String, dynamic> params = {'tmdb_id': tmdbId};
      if (quality != null) {
        params['quality'] = quality;
      }

      final response = await _dio.get(
        '$baseUrl/get-movie',
        queryParameters: params,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final results = response.data['results'] as List? ?? [];
        return results
            .map((r) => TgStreamResult(
                  quality: r['quality']?.toString() ?? 'Unknown',
                  hash: r['hash']?.toString() ?? '',
                  url: r['url']?.toString() ?? '',
                ))
            .toList();
      }
    } catch (e) {
      print('[TG] getMovieStreams error: $e');
    }
    return [];
  }

  Future<TgStreamResult?> getMovieStreamByMessageId(String messageId) async {
    try {
      final response = await _dio.get(
        '$baseUrl/get-movie',
        queryParameters: {'message_id': messageId},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data;
        final r = (data['results'] != null &&
                data['results'] is List &&
                (data['results'] as List).isNotEmpty)
            ? data['results'][0]
            : data;

        if (r['url'] != null) {
          return TgStreamResult(
            quality: r['quality']?.toString() ?? 'Unknown',
            hash: r['hash']?.toString() ?? '',
            url: r['url']?.toString() ?? '',
          );
        }
      }
    } catch (e) {
      print('[TG] getMovieStreamByMessageId error: $e');
    }
    return null;
  }
}
