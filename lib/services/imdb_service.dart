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
    );
  }

  @override
  String toString() {
    return 'ImdbSearchResult(title: $title, year: $year, id: $id)';
  }
}

class ImdbService {
  static const String _storagePrefix = 'imdb_link_';
  final Dio _dio = Dio();

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
          // Extract video ID from 'v' list if available
          String? videoId;
          if (item['v'] != null &&
              item['v'] is List &&
              (item['v'] as List).isNotEmpty) {
            videoId = item['v'][0]['id'];
          }

          final kind = item['q']?.toString();
          debugPrint('[IMDB] Search result: ${item['l']} - kind=$kind');

          return ImdbSearchResult(
            id: item['id'] ?? '',
            title: item['l'] ?? '',
            year: item['y']?.toString() ?? '',
            posterUrl: item['i']?['imageUrl'] ?? '',
            stars: item['s'], // Cast/Stars
            videoId: videoId,
            rating: item['k']
                ?.toString(), // Sometimes 'k' is rank/rating? No, usually not in suggestion. Keeping null safe.
            description: null, // Description usually not in suggestion
            kind:
                kind, // 'q' contains content type like 'feature', 'tv series', etc
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

        // Try parsing __NEXT_DATA__ first (more reliable data)
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
                posterUrl: image,
                rating: rating,
              ));
            }
            if (results.isNotEmpty) return results;
          }
        } catch (e) {
          // Fallback to CSS scraping
        }

        // CSS Fallback
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
                posterUrl: posterUrl,
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

  Future<ImdbSearchResult> fetchDetails(String id) async {
    // Try OMDb API first (more reliable, no anti-bot)
    try {
      final omdbResponse = await _dio.get(
        'https://www.omdbapi.com/',
        queryParameters: {
          'i': id,
          'apikey': 'trilogy', // Free public key
          'plot': 'full',
        },
      );

      if (omdbResponse.statusCode == 200 &&
          omdbResponse.data['Response'] == 'True') {
        final data = omdbResponse.data;

        return ImdbSearchResult(
          id: id,
          title: data['Title'] ?? '',
          year: data['Year']?.toString() ?? '',
          posterUrl: data['Poster'] != 'N/A' ? data['Poster'] : '',
          rating: data['imdbRating'] != 'N/A' ? data['imdbRating'] : null,
          description: data['Plot'] != 'N/A' ? data['Plot'] : null,
          duration: data['Runtime'] != 'N/A' ? data['Runtime'] : null,
          genres: data['Genre'] != 'N/A' ? data['Genre'] : null,
          stars: data['Actors'] != 'N/A' ? data['Actors'] : null,
          releaseDate: data['Released'] != 'N/A' ? data['Released'] : null,
          ratingCount: data['imdbVotes'] != 'N/A' ? data['imdbVotes'] : null,
          country: data['Country'] != 'N/A' ? data['Country'] : null,
          languages: data['Language'] != 'N/A' ? data['Language'] : null,
          videoId: null, // OMDb doesn't provide trailer
          kind: data['Type']?.toString(),
        );
      }
    } catch (e) {
      // Continue to IMDb scraping
    }

    // Fallback to IMDb scraping
    try {
      final response = await _dio.get(
        'https://www.imdb.com/title/$id/',
        options: Options(headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'gzip, deflate, br',
          'Cache-Control': 'max-age=0',
          'Sec-Fetch-Dest': 'document',
          'Sec-Fetch-Mode': 'navigate',
          'Sec-Fetch-Site': 'none',
          'Upgrade-Insecure-Requests': '1',
        }),
      );

      // Accept both 200 (OK) and 202 (Accepted)
      if (response.statusCode == 200 || response.statusCode == 202) {
        final document = html_parser.parse(response.data);

        // 1. Parse JSON-LD
        Map<String, dynamic>? jsonLd;
        final jsonLdScript =
            document.querySelector('script[type="application/ld+json"]');
        if (jsonLdScript != null) {
          try {
            jsonLd = jsonDecode(jsonLdScript.text);
          } catch (e) {
            // ignore
          }
        }

        // 2. Title
        final title =
            document.querySelector("h1[data-testid=hero__pageTitle]")?.text ??
                jsonLd?['name'] ??
                '';

        // 3. Poster
        final poster = jsonLd?['image'] ??
            document.querySelector("div.ipc-poster img")?.attributes['src'] ??
            '';

        // 4. Description
        String? description = jsonLd?['description'];
        if (description == null || description.isEmpty) {
          description =
              document.querySelector("span[data-testid=plot-xl]")?.text ??
                  document
                      .querySelector("meta[name=description]")
                      ?.attributes['content'];
        }

        // 5. Rating
        String? rating;
        if (jsonLd != null && jsonLd['aggregateRating'] != null) {
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

        // 6. Rating Count
        String? ratingCount;
        if (jsonLd != null && jsonLd['aggregateRating'] != null) {
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

        // 7. Duration
        final duration = document
            .querySelector("li[data-testid=title-techspec_runtime] div")
            ?.text;

        // 8. Release Date & Year
        String? releaseDate = document
            .querySelector("li[data-testid=title-details-releasedate] a")
            ?.text
            .replaceAll('Release date', '')
            .trim();

        String year = '';
        if (releaseDate != null && releaseDate.length >= 4) {
          final yearMatch = RegExp(r'\d{4}').firstMatch(releaseDate);
          if (yearMatch != null) year = yearMatch.group(0)!;
        }
        if (year.isEmpty && jsonLd?['datePublished'] != null) {
          final dateStr = jsonLd!['datePublished'].toString();
          if (dateStr.length >= 4) {
            year = dateStr.substring(0, 4);
          }
        }

        // 9. Genres
        List<String> genreList = [];
        if (jsonLd != null && jsonLd['genre'] != null) {
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

        // 10. Actors
        List<String> actors = [];
        document
            .querySelectorAll("a[data-testid=title-cast-item__actor]")
            .forEach((el) {
          actors.add(el.text);
        });
        if (actors.isEmpty && jsonLd != null && jsonLd['actor'] != null) {
          if (jsonLd['actor'] is List) {
            for (var a in jsonLd['actor']) {
              if (a is Map && a['name'] != null) actors.add(a['name']);
            }
          }
        }

        // 11. Trailer
        String? trailerUrl;
        if (jsonLd != null &&
            jsonLd['trailer'] != null &&
            jsonLd['trailer']['embedUrl'] != null) {
          trailerUrl = jsonLd['trailer']['embedUrl'];
          if (trailerUrl!.contains('/video/')) {
            final uri = Uri.parse(trailerUrl);
            final segments = uri.pathSegments;
            if (segments.contains('video')) {
              final idx = segments.indexOf('video');
              if (idx + 1 < segments.length) {
                trailerUrl = segments[idx + 1]; // vi ID
              }
            }
          }
        }

        // 12. Countries
        List<String> countries = [];
        document
            .querySelectorAll("li[data-testid=title-details-origin] a")
            .forEach((el) {
          countries.add(el.text);
        });

        // 13. Languages
        List<String> langs = [];
        document
            .querySelectorAll("li[data-testid=title-details-languages] a")
            .forEach((el) {
          langs.add(el.text);
        });

        return ImdbSearchResult(
          id: id,
          title: title,
          year: year,
          posterUrl: poster,
          rating: rating,
          description: description,
          duration: duration,
          genres: genreList.join(', '),
          stars: actors.take(5).join(', '),
          releaseDate: releaseDate,
          ratingCount: ratingCount,
          country: countries.join(', '),
          languages: langs.join(', '),
          videoId: trailerUrl,
          kind: jsonLd?['@type']?.toString(),
        );
      }
    } catch (e) {
      // Ignore error
    }
    return ImdbSearchResult(id: id, title: '', year: '', posterUrl: '');
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
}
