import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';

class ImdbSearchResult {
  final String id;
  final String title;
  final String year;
  final String posterUrl;
  final String? magnetId;
  final String? stars;
  final String? videoId;
  final String? rating;
  final String? description;
  final String? genres;
  final String? duration;
  final String? releaseDate;
  final String? ratingCount;
  final String? country;
  final String? languages;
  final String? kind; // 'movie' or 'tvSeries' or 'tvEpisode'
  final int? season;
  final int? episode;
  final String? production;
  final String? backdropUrl;
  final int priority; // 0: Low, 1: Medium, 2: High
  final String? customCategory;

  ImdbSearchResult({
    required this.id,
    required this.title,
    required this.year,
    required this.posterUrl,
    this.magnetId,
    this.stars,
    this.videoId,
    this.rating,
    this.description,
    this.genres,
    this.duration,
    this.releaseDate,
    this.ratingCount,
    this.country,
    this.languages,
    this.kind,
    this.season,
    this.episode,
    this.production,
    this.backdropUrl,
    this.priority = 1,
    this.customCategory,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'year': year,
        'posterUrl': posterUrl,
        'magnetId': magnetId,
        'stars': stars,
        'videoId': videoId,
        'rating': rating,
        'description': description,
        'genres': genres,
        'duration': duration,
        'releaseDate': releaseDate,
        'ratingCount': ratingCount,
        'country': country,
        'languages': languages,
        'kind': kind,
        'season': season,
        'episode': episode,
        'production': production,
        'backdropUrl': backdropUrl,
        'priority': priority,
        'customCategory': customCategory,
      };

  factory ImdbSearchResult.fromJson(Map<String, dynamic> json) =>
      ImdbSearchResult(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        year: json['year']?.toString() ?? '',
        posterUrl: json['posterUrl'] ?? '',
        magnetId: json['magnetId'],
        stars: json['stars'] ?? json['s'],
        videoId: json['videoId'],
        rating: json['rating'],
        description: json['description'],
        genres: json['genres'],
        duration: json['duration'],
        releaseDate: json['releaseDate'],
        ratingCount: json['ratingCount'],
        country: json['country'],
        languages: json['languages'],
        kind: json['kind'] ?? json['q'],
        season: json['season'],
        episode: json['episode'],
        production: json['production'],
        backdropUrl: json['backdropUrl'],
        priority: json['priority'] != null
            ? int.tryParse(json['priority'].toString()) ?? 1
            : 1,
        customCategory: json['customCategory'],
      );

  ImdbSearchResult copyWith({
    String? id,
    String? title,
    String? year,
    String? posterUrl,
    String? magnetId,
    String? stars,
    String? videoId,
    String? rating,
    String? description,
    String? genres,
    String? duration,
    String? releaseDate,
    String? ratingCount,
    String? country,
    String? languages,
    String? kind,
    int? season,
    int? episode,
    String? production,
    String? backdropUrl,
    int? priority,
    String? customCategory,
  }) {
    return ImdbSearchResult(
      id: id ?? this.id,
      title: title ?? this.title,
      year: year ?? this.year,
      posterUrl: posterUrl ?? this.posterUrl,
      magnetId: magnetId ?? this.magnetId,
      stars: stars ?? this.stars,
      videoId: videoId ?? this.videoId,
      rating: rating ?? this.rating,
      description: description ?? this.description,
      genres: genres ?? this.genres,
      duration: duration ?? this.duration,
      releaseDate: releaseDate ?? this.releaseDate,
      ratingCount: ratingCount ?? this.ratingCount,
      country: country ?? this.country,
      languages: languages ?? this.languages,
      kind: kind ?? this.kind,
      season: season ?? this.season,
      episode: episode ?? this.episode,
      production: production ?? this.production,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      priority: priority ?? this.priority,
      customCategory: customCategory ?? this.customCategory,
    );
  }

  @override
  String toString() {
    return 'ImdbSearchResult(title: $title, year: $year, id: $id)';
  }
}

class WatchProgress {
  final ImdbSearchResult media;
  final int position;
  final int duration;
  final int lastUpdated;

  WatchProgress({
    required this.media,
    required this.position,
    required this.duration,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() => {
        'media': media.toJson(),
        'position': position,
        'duration': duration,
        'lastUpdated': lastUpdated,
      };

  factory WatchProgress.fromJson(Map<String, dynamic> json) => WatchProgress(
        media: ImdbSearchResult.fromJson(json['media']),
        position: json['position'] ?? 0,
        duration: json['duration'] ?? 0,
        lastUpdated: json['lastUpdated'] ?? 0,
      );
}

class ImdbService {
  static const String _storagePrefix = 'imdb_link_';
  final Dio _dio = Dio();
  static final Map<String, List<ImdbSearchResult>> _recommendationsCache = {};

  List<ImdbSearchResult> getScrapedRecommendations(String id) {
    return _recommendationsCache[id] ?? [];
  }

  Future<List<ImdbSearchResult>> getRecommendations(String id) async {
    try {
      // 1. Check cache
      if (_recommendationsCache.containsKey(id) &&
          _recommendationsCache[id]!.isNotEmpty) {
        return _recommendationsCache[id]!;
      }

      final url = 'https://imdb.gogram.fun/recommendations/$id';
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'Accept': 'application/json',
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final List<dynamic> recs = data['recommendations'] ?? [];

        final results = recs.map((item) {
          return ImdbSearchResult(
            id: item['imdb_id'] ?? '',
            title: item['title'] ?? '',
            year: item['year']?.toString() ?? '',
            posterUrl: _getPoster(item['poster'] ?? '', width: 500),
          );
        }).toList();

        if (results.isNotEmpty) {
          _recommendationsCache[id] = results;
        }
        return results;
      }
    } catch (e) {
      debugPrint('Error fetching recommendations from API: $e');
    }

    // Fallback: If API fails, return empty list (MediaInfoScreen handles fallbacks to scraping/TMDB)
    return [];
  }

  Future<List<ImdbSearchResult>> search(String query) async {
    try {
      final cleanQuery = Uri.encodeComponent(query);
      // includeVideos=1 to get trailer info
      final url =
          'https://v3.sg.media-imdb.com/suggestion/x/$cleanQuery.json?includeVideos=1';

      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3',
            'Accept': 'application/json',
            'Accept-Language': 'en-US,en;q=0.5',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        final List<dynamic> items = data['d'] ?? [];

        return items.where((item) => item['i'] != null).map((item) {
          String? videoId;
          if (item['v'] != null &&
              item['v'] is List &&
              (item['v'] as List).isNotEmpty) {
            videoId = item['v'][0]['id'];
          }

          final kind = item['q']?.toString();

          return ImdbSearchResult(
            id: item['id'] ?? '',
            title: item['l'] ?? '',
            year: item['y']?.toString() ?? '',
            posterUrl: _getPoster(item['i']?['imageUrl'] ?? '', width: 500),
            stars: item['s'],
            videoId: videoId,
            rating: item['k']?.toString(),
            description: null,
            kind: kind,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<ImdbSearchResult>> getTrending() async {
    try {
      final response = await _dio.get(
        'https://www.imdb.com/chart/moviemeter/',
        options: Options(headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        }),
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.data);
        final List<ImdbSearchResult> results = [];

        // Try parsing __NEXT_DATA__ first
        try {
          final nextData = document.querySelector('script[id="__NEXT_DATA__"]');
          if (nextData != null) {
            final json = jsonDecode(nextData.text);
            final edges = json['props']['pageProps']['pageData']['chartTitles']
                ['edges'] as List;

            for (var edge in edges) {
              final node = edge['node'];
              final id = node['id'];
              final title = node['titleText']['text'];
              final image = node['primaryImage']?['url'] ?? '';
              final year = node['releaseYear']?['year']?.toString() ?? '';
              final rating =
                  node['ratingsSummary']?['aggregateRating']?.toString();

              results.add(ImdbSearchResult(
                id: id,
                title: title,
                year: year,
                posterUrl: _getPoster(image, width: 500),
                rating: rating,
              ));
            }
            if (results.isNotEmpty) return results;
          }
        } catch (e) {}

        final items =
            document.querySelectorAll('.ipc-metadata-list-summary-item');
        for (var item in items) {
          try {
            final titleElement = item.querySelector('h3.ipc-title__text');
            final title =
                titleElement?.text.replaceAll(RegExp(r'^\d+\.\s*'), '') ?? '';

            final linkElement = item.querySelector('a.ipc-title-link-wrapper');
            final idMatch = RegExp(r'/title/(tt\d+)/')
                .firstMatch(linkElement?.attributes['href'] ?? '');
            final id = idMatch?.group(1) ?? '';

            final imgElement = item.querySelector('img.ipc-image');
            final posterUrl = imgElement?.attributes['src'] ?? '';

            final metadataItems =
                item.querySelectorAll('.cli-title-metadata-item');
            final year =
                metadataItems.isNotEmpty ? metadataItems.first.text : '';

            final ratingElement = item.querySelector('.ipc-rating-star--base');
            final rating = ratingElement?.text.split('(').first.trim();

            if (id.isNotEmpty) {
              results.add(ImdbSearchResult(
                id: id,
                title: title,
                year: year,
                posterUrl: _getPoster(posterUrl, width: 500),
                rating: rating,
              ));
            }
          } catch (e) {
            continue;
          }
        }
        return results;
      }
    } catch (e) {
      debugPrint('Error fetching trending: $e');
    }
    return [];
  }

  String _getPoster(String url, {int width = 1000}) {
    if (url.isEmpty || url.contains('nopicture')) return '';
    if (url.contains('._V1_')) {
      return url.replaceAll(RegExp(r'\._V1_.*'), '._V1_SX$width.jpg');
    }
    return url;
  }

  Future<ImdbSearchResult> fetchDetails(String id) async {
    try {
      final response = await _dio.get(
        'https://www.imdb.com/title/$id/',
        options: Options(headers: {
          'accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
          'accept-language': 'en-US,en;q=0.9',
          'cache-control': 'no-cache',
          'dnt': '1',
          'pragma': 'no-cache',
          'priority': 'u=0, i',
          'sec-ch-ua':
              '"Not:A-Brand";v="99", "Google Chrome";v="145", "Chromium";v="145"',
          'sec-ch-ua-mobile': '?0',
          'sec-ch-ua-platform': '"Windows"',
          'sec-fetch-dest': 'document',
          'sec-fetch-mode': 'navigate',
          'sec-fetch-site': 'none',
          'sec-fetch-user': '?1',
          'upgrade-insecure-requests': '1',
          'user-agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 202) {
        final document = html_parser.parse(response.data);

        Map<String, dynamic> jsonLd = {};
        final jsonLdScript =
            document.querySelector('script[type="application/ld+json"]');
        if (jsonLdScript != null) {
          try {
            jsonLd = jsonDecode(jsonLdScript.text);
          } catch (e) {}
        }

        final title =
            document.querySelector("h1[data-testid=hero__pageTitle]")?.text ??
                jsonLd['name'] ??
                '';

        final poster = jsonLd['image'] ??
            document.querySelector("div.ipc-poster img")?.attributes['src'] ??
            '';

        String? description = jsonLd['description'];
        if (description == null || description.isEmpty) {
          description =
              document.querySelector("span[data-testid=plot-xl]")?.text ??
                  document
                      .querySelector("meta[name=description]")
                      ?.attributes['content'];
        }

        if (description != null) {
          description = html_parser.parseFragment(description).text;
        }

        String? rating;
        if (jsonLd['aggregateRating'] != null) {
          final ratingValue = jsonLd['aggregateRating']['ratingValue'];
          if (ratingValue != null) {
            rating = ratingValue.toString();
          }
        }
        if (rating == null) {
          final ratingDiv = document.querySelector(
              "div[data-testid=hero-rating-bar__aggregate-rating__score] span");
          rating = ratingDiv?.text;
        }

        String? ratingCount;
        if (jsonLd['aggregateRating'] != null) {
          final countValue = jsonLd['aggregateRating']['ratingCount'];
          if (countValue != null) {
            ratingCount = countValue.toString();
          }
        }
        if (ratingCount == null) {
          final countDiv = document.querySelector("div.sc-eb51e184-3");
          if (countDiv != null) {
            ratingCount = countDiv.text.replaceAll(',', '');
          }
        }

        String? duration = document
            .querySelector("li[data-testid=title-techspec_runtime] div")
            ?.text;

        if (duration == null && jsonLd['duration'] != null) {
          final dur = jsonLd['duration'].toString();
          final hMatch = RegExp(r'(\d+)H').firstMatch(dur);
          final mMatch = RegExp(r'(\d+)M').firstMatch(dur);
          final h = hMatch != null ? '${hMatch.group(1)}h' : '';
          final m = mMatch != null ? '${mMatch.group(1)}m' : '';
          if (h.isNotEmpty || m.isNotEmpty) {
            duration = '$h $m'.trim();
          }
        }

        String? releaseDate = document
            .querySelector("li[data-testid=title-details-releasedate] a")
            ?.text
            .replaceAll('Release date', '')
            .trim();

        if (releaseDate == null && jsonLd['datePublished'] != null) {
          releaseDate = jsonLd['datePublished'].toString();
        }

        String year = '';
        if (releaseDate != null && releaseDate.length >= 4) {
          final yearMatch = RegExp(r'\d{4}').firstMatch(releaseDate);
          if (yearMatch != null) year = yearMatch.group(0)!;
        }

        List<String> genreList = [];
        if (jsonLd['genre'] != null) {
          if (jsonLd['genre'] is List) {
            for (var g in jsonLd['genre']) {
              genreList.add(g.toString());
            }
          } else if (jsonLd['genre'] is String) {
            genreList = [jsonLd['genre']];
          }
        }
        if (genreList.isEmpty) {
          document
              .querySelectorAll("li[data-testid=storyline-genres] a")
              .forEach((el) => genreList.add(el.text));
        }

        List<String> actors = [];
        document
            .querySelectorAll("a[data-testid=title-cast-item__actor]")
            .forEach((el) {
          actors.add(el.text);
        });
        if (actors.isEmpty && jsonLd['actor'] != null) {
          if (jsonLd['actor'] is List) {
            for (var a in jsonLd['actor']) {
              if (a is Map && a['name'] != null) actors.add(a['name']);
            }
          }
        }

        String? trailerUrl;
        if (jsonLd['trailer'] != null &&
            jsonLd['trailer']['embedUrl'] != null) {
          trailerUrl = jsonLd['trailer']['embedUrl'];
          if (trailerUrl!.contains('/video/')) {
            final uri = Uri.parse(trailerUrl);
            final segments = uri.pathSegments;
            if (segments.contains('video')) {
              final idx = segments.indexOf('video');
              if (idx + 1 < segments.length) {
                trailerUrl = segments[idx + 1];
              }
            }
          }
        }

        List<String> countries = [];
        document
            .querySelectorAll("li[data-testid=title-details-origin] a")
            .forEach((el) {
          countries.add(el.text);
        });

        List<String> langs = [];
        document
            .querySelectorAll("li[data-testid=title-details-languages] a")
            .forEach((el) {
          langs.add(el.text);
        });

        // Production Companies
        List<String> productionCompanies = [];
        document
            .querySelectorAll("li[data-testid=title-details-companies] a")
            .forEach((el) {
          final text = el.text;
          if (!text.toLowerCase().contains('production companies')) {
            productionCompanies.add(text);
          }
        });

        // JSON-LD explicit fallback for production
        if (productionCompanies.isEmpty &&
            jsonLd['productionCompany'] != null) {
          if (jsonLd['productionCompany'] is List) {
            for (var pc in jsonLd['productionCompany']) {
              if (pc is Map && pc['name'] != null) {
                productionCompanies.add(pc['name']);
              }
            }
          }
        }

        // Backdrop/Image (Video Thumbnail or OG Image)
        String? backdrop;
        final ogImage = document
            .querySelector('meta[property="og:image"]')
            ?.attributes['content'];
        if (ogImage != null && !ogImage.contains('nopicture')) {
          backdrop = _getPoster(ogImage);
        }

        try {
          await getRecommendations(id);
        } catch (_) {}

        return ImdbSearchResult(
          id: id,
          title: title,
          year: year,
          posterUrl: _getPoster(poster),
          rating: rating,
          description: description,
          duration: duration,
          genres: genreList.join(', '),
          stars: actors.take(8).join(', '),
          releaseDate: releaseDate,
          ratingCount: ratingCount,
          country: countries.join(', '),
          languages: langs.join(', '),
          videoId: trailerUrl,
          kind: jsonLd['@type']?.toString(),
          production: productionCompanies.join(', '),
          backdropUrl: backdrop,
        );
      }
    } catch (e) {
      debugPrint('Error fetching details: $e');
    }
    return ImdbSearchResult(id: id, title: '', year: '', posterUrl: '');
  }

  Future<String?> fetchTrailerStreamUrl(String videoId) async {
    try {
      final videoPageUrl = 'https://www.imdb.com/video/$videoId/';
      final response = await _dio.get(
        videoPageUrl,
        options: Options(headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        }),
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.data);
        final scriptTag = document.querySelector('script[id="__NEXT_DATA__"]');
        if (scriptTag != null) {
          final json = jsonDecode(scriptTag.text);
          final playbackUrls = json['props']['pageProps']['videoPlaybackData']
              ['video']['playbackURLs'] as List;

          // Find MP4 first
          final mp4Urls =
              playbackUrls.where((u) => u['videoMimeType'] == 'MP4').toList();
          if (mp4Urls.isNotEmpty) {
            // Sort by quality
            mp4Urls.sort((a, b) {
              final qa = a['videoDefinition']?.toString() ?? '';
              final qb = b['videoDefinition']?.toString() ?? '';
              if (qa.contains('1080')) return -1;
              if (qb.contains('1080')) return 1;
              if (qa.contains('720')) return -1;
              if (qb.contains('720')) return 1;
              return 0;
            });
            return mp4Urls.first['url'];
          } else if (playbackUrls.isNotEmpty) {
            return playbackUrls.first['url'];
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching trailer stream: $e');
    }

    // Fallback if needed
    return 'https://imdb-video.media-imdb.com/mc/$videoId/${videoId}_720p.mp4';
  }

  Future<String?> findTrailerVideoId(String imdbId) async {
    try {
      // First try descending (newest first)
      String? videoId = await _scrapeVideoGallery(imdbId, 'date', 'desc');
      if (videoId != null) return videoId;

      // Try ascending
      videoId = await _scrapeVideoGallery(imdbId, 'date', 'asc');
      if (videoId != null) return videoId;

      return null;
    } catch (e) {
      debugPrint('Error finding trailer ID: $e');
      return null;
    }
  }

  Future<String?> _scrapeVideoGallery(
      String imdbId, String sort, String order) async {
    try {
      final url =
          'https://www.imdb.com/title/$imdbId/videogallery/?sort=$sort,$order';
      final response = await _dio.get(
        url,
        options: Options(headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        }),
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.data);

        // Find all clamp-none spans which contain video titles/types
        final spans = document.querySelectorAll(
            'span.ipc-lockup-overlay__text.ipc-lockup-overlay__text--clamp-none');

        // 1. Look for 'Trailer'
        for (var span in spans) {
          if (span.text.contains('Trailer')) {
            final link = span.parent; // usually 'a' tag is parent or close
            // If parent is not 'a', try finding closest 'a'
            var aTag = link;
            while (aTag != null && aTag.localName != 'a') {
              aTag = aTag.parent;
            }

            if (aTag != null) {
              final href = aTag.attributes['href'];
              if (href != null && href.contains('/video/')) {
                // Extract video ID from /video/viXXXXX/
                final match = RegExp(r'/video/(vi\d+)/').firstMatch(href);
                if (match != null) return match.group(1);
              }
            }
          }
        }

        // 2. Look for 'Clip'
        for (var span in spans) {
          if (span.text.contains('Clip')) {
            final link = span.parent;
            var aTag = link;
            while (aTag != null && aTag.localName != 'a') {
              aTag = aTag.parent;
            }
            if (aTag != null) {
              final href = aTag.attributes['href'];
              if (href != null && href.contains('/video/')) {
                final match = RegExp(r'/video/(vi\d+)/').firstMatch(href);
                if (match != null) return match.group(1);
              }
            }
          }
        }

        // 3. Fallback: First video > 30s
        final videoLinks = document.querySelectorAll('a[href*="/video/vi"]');
        for (var link in videoLinks) {
          final href = link.attributes['href'];
          // Try to find duration
          // Usually near the link or inside a shared container
          // This is harder to robustly scrape without exact DOM path,
          // but we can try basic hierarchy check or just return first video.
          if (href != null) {
            final match = RegExp(r'/video/(vi\d+)/').firstMatch(href);
            if (match != null) return match.group(1);
          }
        }
      }
    } catch (e) {
      debugPrint('Error scraping gallery: $e');
    }
    return null;
  }

  Future<void> saveLink(String filename, ImdbSearchResult result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_storagePrefix$filename', jsonEncode(result.toJson()));
  }

  Future<void> removeLink(String filename) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_storagePrefix$filename');
  }

  Future<ImdbSearchResult?> getLink(String filename) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('$_storagePrefix$filename');
    if (data != null) {
      try {
        return ImdbSearchResult.fromJson(jsonDecode(data));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<List<ImdbSearchResult>> getRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('imdb_recents');
    if (data != null) {
      return data.map((e) => ImdbSearchResult.fromJson(jsonDecode(e))).toList();
    }
    return [];
  }

  Future<void> addToRecents(ImdbSearchResult result) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recents = prefs.getStringList('imdb_recents') ?? [];

    recents.removeWhere((e) {
      try {
        final item = ImdbSearchResult.fromJson(jsonDecode(e));
        return item.id == result.id;
      } catch (_) {
        return false;
      }
    });
    recents.insert(0, jsonEncode(result.toJson()));

    if (recents.length > 20) {
      recents = recents.sublist(0, 20);
    }

    await prefs.setStringList('imdb_recents', recents);
  }

  Future<void> clearRecents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('imdb_recents');
  }

  // --- Continue Watching Support ---

  Future<List<WatchProgress>> getContinueWatching() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('imdb_continue_watching');
    if (data != null) {
      return data.map((e) => WatchProgress.fromJson(jsonDecode(e))).toList();
    }
    return [];
  }

  Future<void> saveWatchProgress(
      ImdbSearchResult media, int position, int duration) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList('imdb_continue_watching') ?? [];
    List<WatchProgress> progressList =
        list.map((e) => WatchProgress.fromJson(jsonDecode(e))).toList();

    // Remove existing entry for this media
    progressList.removeWhere((p) => p.media.id == media.id);

    // Add new entry
    progressList.insert(
        0,
        WatchProgress(
          media: media,
          position: position,
          duration: duration,
          lastUpdated: DateTime.now().millisecondsSinceEpoch,
        ));

    // Keep max 20
    if (progressList.length > 20) {
      progressList = progressList.sublist(0, 20);
    }

    // Save
    await prefs.setStringList('imdb_continue_watching',
        progressList.map((p) => jsonEncode(p.toJson())).toList());
  }

  Future<void> removeFromContinueWatching(String id) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> list = prefs.getStringList('imdb_continue_watching') ?? [];
    List<WatchProgress> progressList =
        list.map((e) => WatchProgress.fromJson(jsonDecode(e))).toList();
    progressList.removeWhere((p) => p.media.id == id);
    await prefs.setStringList('imdb_continue_watching',
        progressList.map((p) => jsonEncode(p.toJson())).toList());
  }

  Future<void> saveTrendingCache(List<ImdbSearchResult> results) async {
    final prefs = await SharedPreferences.getInstance();
    final data = results.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('imdb_trending_cache', data);
  }

  Future<List<ImdbSearchResult>> getTrendingCache() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('imdb_trending_cache');
    if (data != null) {
      try {
        return data
            .map((e) => ImdbSearchResult.fromJson(jsonDecode(e)))
            .toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  Future<List<ImdbSearchResult>> getByGenre(String genre) async {
    try {
      final cleanGenre = genre.toLowerCase().trim();
      final url =
          'https://www.imdb.com/search/title/?genres=$cleanGenre&explore=genres&title_type=feature';

      final response = await _dio.get(
        url,
        options: Options(headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36',
          'Accept-Language': 'en-US,en;q=0.9',
        }),
      );

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.data);
        final List<ImdbSearchResult> results = [];

        // Try __NEXT_DATA__
        final nextData = document.querySelector('script[id="__NEXT_DATA__"]');
        if (nextData != null) {
          final json = jsonDecode(nextData.text);
          final edges = json['props']['pageProps']['searchResults']
              ['titleResults']['titleListItems'] as List;

          for (var edge in edges) {
            final id = edge['titleId'];
            final title = edge['titleText'];
            final image = edge['primaryImage']?['url'] ?? '';
            final year = edge['releaseYear']?.toString() ?? '';
            final rating =
                edge['ratingsSummary']?['aggregateRating']?.toString();

            results.add(ImdbSearchResult(
              id: id,
              title: title,
              year: year,
              posterUrl: _getPoster(image, width: 500),
              rating: rating,
            ));
          }
          if (results.isNotEmpty) return results;
        }

        // Fallback to scraping list items if NEXT_DATA fails or structure differs
      }
    } catch (e) {
      debugPrint('Error fetching genre $genre: $e');
    }
    return [];
  }
}
