import 'dart:convert';
import 'package:dio/dio.dart';
import 'video_source_service.dart';

class KissKhService {
  static const String _baseUrl = 'https://kisskh.ws/api';
  static const String _encUrl = 'https://enc-dec.app/api/enc-kisskh';
  static const String _decUrl = 'https://enc-dec.app/api/dec-kisskh';

  final Dio _dio = Dio(BaseOptions(
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'en-US,en;q=0.9',
      'Cache-Control': 'no-cache',
      'DNT': '1',
      'Pragma': 'no-cache',
      'Referer': 'https://kisskh.ws/',
      'Origin': 'https://kisskh.ws',
    },
    validateStatus: (status) => true,
  ));

  Future<Map<String, dynamic>> getSources(
      String title, int? season, int? episode) async {
    try {
      String searchQuery = title;
      if (season != null && season > 1) {
        searchQuery = '$title Season $season';
      }

      var searchResults = await _search(searchQuery);

      if (searchResults.isEmpty && season != null && season > 1) {
        searchResults = await _search(title);
      }

      List<Map<String, dynamic>> scoredResults = [];

      for (var result in searchResults) {
        final resultTitle = (result['title'] ?? '').toString();
        final searchTitle = title;
        double score = _calculateSimilarity(
            searchTitle.toLowerCase(), resultTitle.toLowerCase());

        final titleLower = resultTitle.toLowerCase();

        if (titleLower.contains('(short)')) {
          score *= 0.7;
        }

        if (titleLower.contains('(live action)')) {
          score *= 1.15;
        }
        final episodeCount = result['episodesCount'] ?? 0;

        scoredResults.add({
          'result': result,
          'score': score,
          'title': result['title'],
          'episodes': episodeCount,
        });
      }

      scoredResults.sort(
          (a, b) => (b['score'] as double).compareTo(a['score'] as double));

      if (scoredResults.isEmpty ||
          (scoredResults.first['score'] as double) < 0.3) {
        return {'sources': <VideoSource>[], 'captions': <VideoCaption>[]};
      }

      final bestMatch = scoredResults.first['result'] as Map<String, dynamic>;

      final drama = bestMatch;
      final dramaId = drama['id'];

      final episodesList = await _getEpisodes(dramaId);
      if (episodesList.isEmpty) {
        return {'sources': <VideoSource>[], 'captions': <VideoCaption>[]};
      }

      final targetEpNum = episode ?? 1;
      final targetEpisode = episodesList.firstWhere(
        (e) => (e['number'] as num?)?.toInt() == targetEpNum,
        orElse: () => {},
      );

      if (targetEpisode.isEmpty) {
        return {'sources': <VideoSource>[], 'captions': <VideoCaption>[]};
      }

      final episodeId = targetEpisode['id'];

      final videoKey = await _getEncryptionKey(episodeId, 'vid');
      final subKey = await _getEncryptionKey(episodeId, 'sub');

      if (videoKey == null) {
        return {'sources': <VideoSource>[], 'captions': <VideoCaption>[]};
      }

      List<VideoCaption> captions = [];
      if (subKey != null) {
        try {
          final subUrl = '$_baseUrl/Sub/$episodeId';
          final subResponse = await _dio.get(
            subUrl,
            queryParameters: {'kkey': subKey},
          );

          if (subResponse.statusCode == 200 && subResponse.data is List) {
            final listData = subResponse.data as List;
            captions = listData
                .map((s) {
                  final src = s['src'];
                  final label = s['label'] ?? s['land'] ?? 'Unknown';
                  if (src != null) {
                    return VideoCaption(
                      label: label.toString(),
                      file: '$_decUrl?url=${Uri.encodeComponent(src)}',
                    );
                  }
                  return null;
                })
                .whereType<VideoCaption>()
                .toList();
          }
        } catch (_) {}
      }

      final params = {
        'err': 'false',
        'ts': 'null',
        'time': 'null',
        'kkey': videoKey,
      };

      final response = await _dio.get(
        '$_baseUrl/DramaList/Episode/$episodeId.png',
        queryParameters: params,
      );

      if (response.statusCode == 200 && response.data != null) {
        var respData = response.data;
        if (respData is String) {
          try {
            respData = jsonDecode(respData);
          } catch (_) {}
        }

        if (respData is Map) {
          final videoUrl = respData['Video'];

          if (videoUrl != null && videoUrl.toString().isNotEmpty) {
            return {
              'sources': [
                VideoSource(
                  url: videoUrl,
                  quality: 'Auto',
                  format: 'HLS',
                  size: 'Unknown',
                  headers: _dio.options.headers
                      .map((k, v) => MapEntry(k, v.toString())),
                )
              ],
              'captions': captions,
            };
          }
        }
      }

      return {'sources': <VideoSource>[], 'captions': <VideoCaption>[]};
    } catch (e) {
      return {'sources': <VideoSource>[], 'captions': <VideoCaption>[]};
    }
  }

  Future<List<dynamic>> _search(String query) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/DramaList/Search',
        queryParameters: {'q': query, 'type': '0'},
      );
      if (response.statusCode == 200 && response.data is List) {
        return response.data;
      }
    } catch (_) {}
    return [];
  }

  Future<List<dynamic>> _getEpisodes(int dramaId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/DramaList/Drama/$dramaId',
        queryParameters: {'isq': 'false'},
      );
      if (response.statusCode == 200) {
        return response.data['episodes'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  Future<String?> _getEncryptionKey(int id, String type) async {
    try {
      final response = await _dio.get(
        _encUrl,
        queryParameters: {'text': id.toString(), 'type': type},
      );
      if (response.statusCode == 200 && response.data['status'] == 200) {
        return response.data['result'];
      }
    } catch (_) {}
    return null;
  }

  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    String normalize(String s) {
      return s
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    }

    final normalized1 = normalize(s1);
    final normalized2 = normalize(s2);

    if (normalized1 == normalized2) return 1.0;

    if (normalized1.contains(normalized2) ||
        normalized2.contains(normalized1)) {
      final shorter =
          normalized1.length < normalized2.length ? normalized1 : normalized2;
      final longer =
          normalized1.length >= normalized2.length ? normalized1 : normalized2;
      return shorter.length / longer.length * 0.95;
    }

    final len1 = normalized1.length;
    final len2 = normalized2.length;

    List<List<int>> dp = List.generate(
      len1 + 1,
      (i) => List.filled(len2 + 1, 0),
    );

    for (int i = 0; i <= len1; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= len2; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= len1; i++) {
      for (int j = 1; j <= len2; j++) {
        if (normalized1[i - 1] == normalized2[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 +
              [
                dp[i - 1][j],
                dp[i][j - 1],
                dp[i - 1][j - 1],
              ].reduce((a, b) => a < b ? a : b);
        }
      }
    }

    final distance = dp[len1][len2];
    final maxLen = len1 > len2 ? len1 : len2;

    return 1.0 - (distance / maxLen);
  }
}
