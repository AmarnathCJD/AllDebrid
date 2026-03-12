import 'package:html/parser.dart' as html_parser;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _kdramaDio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 10),
  receiveTimeout: const Duration(seconds: 10),
  headers: {
    'accept': 'text/html, */*; q=0.01',
    'accept-language': 'en-US,en;q=0.9',
    'cache-control': 'no-cache',
    'user-agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  },
));

class KDramaItem {
  final String id;
  final String title;
  final String? posterUrl;
  final String? releaseYear;
  final int? episodes;
  final double? rating;

  KDramaItem({
    required this.id,
    required this.title,
    this.posterUrl,
    this.releaseYear,
    this.episodes,
    this.rating,
  });
}

class KDramaService {
  static const String baseUrl = 'https://mydramalist.com';

  Future<List<KDramaItem>> fetchTopDramas() async {
    return _fetchDramas('$baseUrl/shows/top');
  }

  Future<List<KDramaItem>> fetchTopAiringDramas() async {
    return _fetchDramas('$baseUrl/shows/top_airing');
  }

  Future<List<KDramaItem>> fetchLatestDramas() async {
    return _fetchDramas('$baseUrl/shows/newest');
  }

  Future<List<KDramaItem>> _fetchDramas(String url) async {
    final cacheKey = 'kdrama_cache_${url.hashCode}';
    try {
      final response = await _kdramaDio.get(url);
      if (response.statusCode == 200) {
        final body = response.data is String
            ? response.data as String
            : response.data.toString();
        _saveToCache(cacheKey, body);
        return _parseDramas(body);
      }
      return [];
    } catch (e) {
      print('[KDRAMA] Error fetching dramas: $e');
      return getCachedDramas(url);
    }
  }

  Future<List<KDramaItem>> getCachedDramas(String url) async {
    try {
      final cacheKey = 'kdrama_cache_${url.hashCode}';
      final prefs = await SharedPreferences.getInstance();
      final html = prefs.getString(cacheKey);
      if (html != null && html.isNotEmpty) {
        return _parseDramas(html);
      }
    } catch (_) {}
    return [];
  }

  void _saveToCache(String key, String value) {
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(key, value))
        .catchError((_) => true);
  }

  List<KDramaItem> _parseDramas(String html) {
    try {
      final document = html_parser.parse(html);
      final items = <KDramaItem>[];

      // Find all drama items in the top list
      final dramaBoxes =
          document.querySelectorAll('.m-t.nav-active-border .box, .box');

      for (final box in dramaBoxes) {
        try {
          // Extract ID from the box id attribute (mdl-735043)
          final boxId = box.attributes['id'] ?? '';
          String? id;
          if (boxId.isNotEmpty && boxId.startsWith('mdl-')) {
            id = boxId.replaceFirst('mdl-', '');
          }

          // Extract title and link
          final titleLink = box.querySelector('.title a');
          final title = titleLink?.text.trim();

          // Extract poster URL
          final posterImg = box.querySelector('.cover img.lazy');
          var posterUrl = posterImg?.attributes['data-src'];
          // Replace 4s with 4f for better image quality
          if (posterUrl != null) {
            posterUrl = posterUrl.replaceAll('_4s.', '_4f.');
          }

          // Extract metadata (year, episodes)
          final metadata = box.querySelector('.text-muted');
          String? releaseYear;
          int? episodes;
          if (metadata != null) {
            final text = metadata.text;
            // Parse "Korean Drama - 2025, 16 episodes"
            final yearMatch = RegExp(r'(\d{4})').firstMatch(text);
            if (yearMatch != null) {
              releaseYear = yearMatch.group(1);
            }
            final episodeMatch = RegExp(r'(\d+)\s+episodes?').firstMatch(text);
            if (episodeMatch != null) {
              episodes = int.tryParse(episodeMatch.group(1) ?? '');
            }
          }

          // Extract rating
          final ratingSpan = box.querySelector('.score');
          double? rating;
          if (ratingSpan != null) {
            rating = double.tryParse(ratingSpan.text.trim());
          }

          if (id != null && title != null && title.isNotEmpty) {
            items.add(KDramaItem(
              id: id,
              title: title,
              posterUrl: posterUrl,
              releaseYear: releaseYear,
              episodes: episodes,
              rating: rating,
            ));
          }
        } catch (e) {
          print('[KDRAMA] Error parsing drama box: $e');
          continue;
        }
      }

      return items;
    } catch (e) {
      print('[KDRAMA] Error parsing HTML: $e');
      return [];
    }
  }
}
