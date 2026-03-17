import 'dart:convert';
import 'package:dio/dio.dart';
import 'video_source_service.dart';

class VidLinkService {
  static const String _baseUrl = 'https://vidlink.pro/api/b';
  static const String _encUrl = 'https://enc-dec.app/api/enc-vidlink';

  final Dio _dio = Dio(BaseOptions(
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    },
    validateStatus: (status) => true,
  ));

  // Access Headers for the player
  static const Map<String, String> _playerHeaders = {
    'Referer': 'https://vidlink.pro/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
  };

  Future<Map<String, dynamic>> getSources(int id,
      {bool isMovie = true, int? season, int? episode}) async {
    try {
      final key = await _getEncryptionKey(id);
      if (key == null) {
        return {'sources': <VideoSource>[], 'captions': <VideoCaption>[]};
      }

      String url;
      if (isMovie) {
        url = '$_baseUrl/movie/$key';
      } else {
        if (season == null || episode == null) {
          return {'sources': <VideoSource>[], 'captions': <VideoCaption>[]};
        }
        url = '$_baseUrl/tv/$key/$season/$episode?multiLang=0';
      }

      final response = await _dio.get(url);

      if (response.statusCode == 200 && response.data != null) {
        var data = response.data;
        if (data is String) {
          try {
            data = jsonDecode(data);
          } catch (e) {
            return {'sources': <VideoSource>[], 'captions': <VideoCaption>[]};
          }
        }

        if (data is Map) {
          final stream = data['stream'];
          if (stream != null && stream['playlist'] != null) {
            String playlistUrl = stream['playlist'];
            List<VideoCaption> captions = [];
            if (stream['captions'] != null && stream['captions'] is List) {
              captions = (stream['captions'] as List).map((c) {
                return VideoCaption(
                  label: c['language'] ?? 'Unknown',
                  file: c['url'] ?? '',
                );
              }).toList();
            }

            return {
              'sources': [
                VideoSource(
                  url: playlistUrl,
                  quality: 'Auto',
                  format: 'HLS',
                  size: 'Unknown',
                  headers: _playerHeaders,
                )
              ],
              'captions': captions,
            };
          }
        }
      }
    } catch (e) {}
    return {'sources': <VideoSource>[], 'captions': <VideoCaption>[]};
  }

  Future<String?> _getEncryptionKey(int id) async {
    try {
      final response = await _dio.get(
        _encUrl,
        queryParameters: {'text': id.toString()},
      );
      if (response.statusCode == 200 && response.data['status'] == 200) {
        return response.data['result'];
      }
    } catch (e) {}
    return null;
  }
}

class VidEasyService {
  static const String _apiUrl =
      'https://api.videasy.net/myflixerzupcloud/sources-with-title';
  static const String _decUrl = 'https://enc-dec.app/api/dec-videasy';

  final Dio _dio = Dio(BaseOptions(
    headers: {
      'accept': '*/*',
      'accept-language': 'en-US,en;q=0.9',
      'cache-control': 'no-cache',
      'dnt': '1',
      'origin': 'https://player.videasy.net',
      'pragma': 'no-cache',
      'priority': 'u=1, i',
      'referer': 'https://player.videasy.net/',
      'sec-ch-ua':
          '"Not(A:Brand";v="8", "Chromium";v="144", "Google Chrome";v="144"',
      'sec-ch-ua-mobile': '?0',
      'sec-ch-ua-platform': '"Windows"',
      'sec-fetch-dest': 'empty',
      'sec-fetch-mode': 'cors',
      'sec-fetch-site': 'same-site',
      'user-agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36',
    },
    validateStatus: (status) => true,
  ));

  static const Map<String, String> _playerHeaders = {
    'Referer': 'https://player.videasy.net/',
    'Origin': 'https://player.videasy.net',
  };

  Future<Map<String, dynamic>> getSources(String title, String year, int tmdbId,
      {bool isMovie = true, int? season, int? episode}) async {
    try {
      final queryParams = {
        'title': title,
        'mediaType': isMovie ? 'movie' : 'tv',
        'year': year,
        'tmdbId': tmdbId.toString(),
      };

      if (!isMovie) {
        queryParams['seasonId'] = season.toString();
        queryParams['episodeId'] = episode.toString();
      }

      final response = await _dio.get(_apiUrl, queryParameters: queryParams);

      if (response.statusCode == 200 && response.data != null) {
        final encryptedText = response.data.toString();
        final decryptedData = await _decrypt(encryptedText, tmdbId);
        if (decryptedData != null) {
          return _parseSources(decryptedData);
        }
      }
    } catch (e) {
      print('VidEasy Error: $e');
    }
    return {'sources': <VideoSource>[], 'captions': <VideoCaption>[]};
  }

  Future<Map<String, dynamic>?> _decrypt(String text, int tmdbId) async {
    try {
      final payload = {"text": text, "id": tmdbId.toString()};

      final response = await _dio.post(_decUrl,
          data: payload,
          options: Options(
            headers: {'Content-Type': 'application/json'},
          ));

      if (response.statusCode == 200 && response.data != null) {
        if (response.data['status'] == 200) {
          return response.data['result'];
        }
      }
    } catch (e) {
      print('[VidEasy] Decrypt error: $e');
    }
    return null;
  }

  Map<String, dynamic> _parseSources(Map<String, dynamic> data) {
    var sourcesList = data['sources'];
    var subtitlesList = data['subtitles'];

    List<VideoSource> sources = [];
    List<VideoCaption> captions = [];

    if (sourcesList != null && sourcesList is List) {
      sources = sourcesList.map((s) {
        return VideoSource(
          url: s['url'] ?? '',
          quality: s['quality']?.toString() ?? 'Auto',
          format: 'HLS',
          size: 'Unknown',
          headers: _playerHeaders,
        );
      }).toList();
    }

    if (subtitlesList != null && subtitlesList is List) {
      captions = subtitlesList.map((s) {
        return VideoCaption(
          label: s['label'] ?? s['lang'] ?? 'Unknown',
          file: s['file'] ?? s['url'] ?? '',
        );
      }).toList();
    }

    return {'sources': sources, 'captions': captions};
  }
}
