import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'subtitlecat_service.dart';

class WyzieService {
  static const String _baseUrl = 'https://sub.wyzie.ru/search';

  static final Dio _dio = Dio(BaseOptions(
    headers: {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
    validateStatus: (status) => true,
  ));

  static Future<List<SubtitleCatResult>> search(
      String id, int? season, int? episode) async {
    try {
      final queryParams = {'id': id};
      if (season != null && episode != null) {
        queryParams['s'] = season.toString();
        queryParams['e'] = episode.toString();
      }

      print('Wyzie Search - ID: $id, Season: $season, Episode: $episode');

      final response = await _dio.get(_baseUrl, queryParameters: queryParams);

      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> data = response.data;
        return data.map((item) {
          final id = item['id']?.toString() ?? '';
          final fileName = item['fileName']?.toString() ?? '';
          final url = item['url']?.toString() ?? '';
          final display = item['display']?.toString();
          final flagUrl = item['flagUrl']?.toString();
          final downloadCount = item['downloadCount'] as int?;

          return SubtitleCatResult(
            id: id,
            fileName: fileName,
            downloadLink: url,
            detailsUrl: '',
            language: display,
            flagUrl: flagUrl,
            downloadCount: downloadCount,
            isDirect: true,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Wyzie Search Error: $e');
    }
    return [];
  }
}
