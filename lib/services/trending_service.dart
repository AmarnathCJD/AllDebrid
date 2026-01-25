import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

class TrendingItem {
  final String id;
  final String title;
  final String? posterUrl;
  final String? releaseDate;
  final double? rating;
  final String mediaType; // 'movie' or 'tv'

  TrendingItem({
    required this.id,
    required this.title,
    this.posterUrl,
    this.releaseDate,
    this.rating,
    required this.mediaType,
  });
}

class TrendingService {
  static const String baseUrl = 'https://www.themoviedb.org';

  Future<List<TrendingItem>> fetchTrendingMovies() async {
    return _fetchTrending(
      'movie',
      'show_me=everything&sort_by=popularity.desc&release_date.lte=2026-07-25',
    );
  }

  Future<List<TrendingItem>> fetchTrendingTVShows() async {
    return _fetchTrending(
      'tv',
      'show_me=everything&sort_by=popularity.desc&with_watch_monetization_types=flatrate%7Cfree%7Cads%7Crent%7Cbuy',
    );
  }

  Future<List<TrendingItem>> fetchNetflixShows() async {
    return _fetchTrending(
      'tv',
      'show_me=everything&sort_by=popularity.desc&with_watch_providers=8&with_watch_monetization_types=flatrate',
    );
  }

  Future<List<TrendingItem>> fetchAmazonPrimeShows() async {
    return _fetchTrending(
      'tv',
      'show_me=everything&sort_by=popularity.desc&with_watch_providers=119&with_watch_monetization_types=flatrate',
    );
  }

  Future<List<TrendingItem>> fetchNetflixMovies() async {
    return _fetchTrending(
      'movie',
      'show_me=everything&sort_by=popularity.desc&with_watch_providers=8&with_watch_monetization_types=flatrate&release_date.lte=2026-07-25',
    );
  }

  Future<List<TrendingItem>> fetchAmazonPrimeMovies() async {
    return _fetchTrending(
      'movie',
      'show_me=everything&sort_by=popularity.desc&with_watch_providers=119&with_watch_monetization_types=flatrate&release_date.lte=2026-07-25',
    );
  }

  Future<List<TrendingItem>> _fetchTrending(
    String mediaType,
    String queryParams,
  ) async {
    try {
      final url =
          '$baseUrl/discover/$mediaType?page=1&region=IN&watch_region=IN&certification_country=IN&$queryParams&vote_average.gte=0&vote_average.lte=10&vote_count.gte=0&with_runtime.gte=0&with_runtime.lte=400';

      final headers = {
        'accept': 'text/html, */*; q=0.01',
        'accept-language': 'en-US,en;q=0.9',
        'cache-control': 'no-cache',
        'content-type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'dnt': '1',
        'pragma': 'no-cache',
        'sec-fetch-dest': 'empty',
        'sec-fetch-mode': 'cors',
        'sec-fetch-site': 'same-origin',
        'user-agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'x-requested-with': 'XMLHttpRequest',
      };

      final response = await http
          .get(
            Uri.parse(url),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return _parseTrendingItems(response.body, mediaType);
      }
      return [];
    } catch (e) {
      print('[TRENDING] Error fetching $mediaType: $e');
      return [];
    }
  }

  List<TrendingItem> _parseTrendingItems(String html, String mediaType) {
    try {
      final document = html_parser.parse(html);
      final items = <TrendingItem>[];

      final cards = document.querySelectorAll('.media_items .card.style_1');

      for (final card in cards) {
        try {
          // Extract ID from data-id or href
          String? id;
          final idAttr = card.querySelector('[data-id]');
          if (idAttr != null) {
            id = idAttr.attributes['data-id'];
          }

          // Extract title
          final titleElement = card.querySelector('h2 a');
          final title = titleElement?.text.trim();

          // Extract poster URL
          final imgElement = card.querySelector('img.poster');
          final posterUrl = imgElement?.attributes['src'];

          // Extract release date
          final dateElement = card.querySelector('.content p');
          final releaseDate = dateElement?.text.trim();

          // Extract rating from data-percent
          final ratingElement = card.querySelector('.user_score_chart');
          final ratingStr = ratingElement?.attributes['data-percent'];
          double? rating;
          if (ratingStr != null) {
            rating = double.tryParse(ratingStr);
          }

          if (id != null && title != null && title.isNotEmpty) {
            items.add(TrendingItem(
              id: id,
              title: title,
              posterUrl: posterUrl,
              releaseDate: releaseDate,
              rating: rating,
              mediaType: mediaType,
            ));
          }
        } catch (e) {
          print('[TRENDING] Error parsing card: $e');
          continue;
        }
      }

      return items;
    } catch (e) {
      print('[TRENDING] Error parsing HTML: $e');
      return [];
    }
  }
}
