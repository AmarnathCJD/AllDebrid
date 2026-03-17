import 'package:dio/dio.dart';
import 'tg_native_service.dart';

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
  static int telegramChannelId = 0;
  static int telegramAccessHash = 0;
  static int? nativePort;

  final Dio _dio = Dio(BaseOptions(
    validateStatus: (status) => true,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'User-Agent': 'AllDebrid',
      'Accept': 'application/json',
    },
  ));

  static Future<String> initializeNativeFetcher({
    required String stringSession,
  }) async {
    try {
      print('[TG] Initializing native fetcher...');
      final username =
          await TGNativeService.initialize(stringSession: stringSession);
      nativePort = await TGNativeService().startStreamingServer();
      print(
          '[TG] Native fetcher initialized. User: $username, Local Port: $nativePort');

      // Auto-resolve index channel if not set
      if (telegramChannelId == 0) {
        try {
          print('[TG] Auto-resolving default index channel...');
          final resolved =
              await TGNativeService().resolveUsername('indexmzgroup');
          telegramChannelId = resolved['channel_id'];
          telegramAccessHash = resolved['access_hash'];
          print('[TG] Resolved index channel: $telegramChannelId');
        } catch (e) {
          print('[TG] Auto-resolve failed: $e');
        }
      }
      return username;
    } catch (e) {
      print('[TG] Native fetcher init failed: $e');
      rethrow;
    }
  }

  /// Get the stream URL, preferring native if available
  String getStreamUrl(String remoteUrl, String hash) {
    if (nativePort != null && nativePort! > 0) {
      try {
        final msgId = TGNativeService().decodeHash(hash);
        final localUrl =
            'http://127.0.0.1:$nativePort/stream?msg_id=$msgId&channel_id=$telegramChannelId&access_hash=$telegramAccessHash';
        print('[TG] Using native pipeline URL: $localUrl');
        return localUrl;
      } catch (e) {
        print('[TG] Error generating native URL, falling back: $e');
      }
    }

    final fallbackUrl = '${TgService.baseUrl}$remoteUrl';
    print(
        '[TG] Falling back to remote CDN URL (nativePort=$nativePort): $fallbackUrl');
    return fallbackUrl;
  }

  static Future<String> createSessionFromBotToken(String botToken) async {
    try {
      final service = TGNativeService();
      return await service.createSessionFromBotToken(botToken);
    } catch (e) {
      rethrow;
    }
  }

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

  /// Download file directly from Telegram using native library
  /// msgId can be an int or hex hash string
  Future<List<int>> downloadFileChunk(
    dynamic msgId, {
    required int start,
    required int end,
  }) async {
    final nativeService = TGNativeService();
    if (!nativeService.isInitialized) {
      throw Exception('Native Telegram fetcher not initialized');
    }

    final actualMsgId =
        msgId is String ? nativeService.decodeHash(msgId) : (msgId as int);

    return await nativeService.downloadFileChunk(
      channelId: telegramChannelId,
      accessHash: telegramAccessHash,
      msgId: actualMsgId,
      start: start,
      end: end,
    );
  }

  /// Fetch file metadata from Telegram
  Future<FileMetadata> fetchFileMetadata(dynamic msgId) async {
    final nativeService = TGNativeService();
    if (!nativeService.isInitialized) {
      throw Exception('Native Telegram fetcher not initialized');
    }

    final actualMsgId =
        msgId is String ? nativeService.decodeHash(msgId) : (msgId as int);

    return await nativeService.fetchFileMetadata(
      channelId: telegramChannelId,
      accessHash: telegramAccessHash,
      msgId: actualMsgId,
    );
  }

  /// Download complete file to disk
  Future<String> downloadFileToDisk(
    dynamic msgId,
    String filePath,
  ) async {
    final nativeService = TGNativeService();
    if (!nativeService.isInitialized) {
      throw Exception('Native Telegram fetcher not initialized');
    }

    final actualMsgId =
        msgId is String ? nativeService.decodeHash(msgId) : (msgId as int);

    return await nativeService.downloadFile(
      channelId: telegramChannelId,
      accessHash: telegramAccessHash,
      msgId: actualMsgId,
      filePath: filePath,
    );
  }

  /// Encode message ID to compact hash
  String encodeHash(int msgId) {
    return TGNativeService().encodeHash(msgId);
  }
}
