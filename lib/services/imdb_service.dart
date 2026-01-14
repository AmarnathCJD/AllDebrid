import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ImdbSearchResult {
  final String id;
  final String title;
  final String year;
  final String posterUrl;
  final String? magnetId;

  ImdbSearchResult({
    required this.id,
    required this.title,
    required this.year,
    required this.posterUrl,
    this.magnetId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'year': year,
        'posterUrl': posterUrl,
        'magnetId': magnetId,
      };

  factory ImdbSearchResult.fromJson(Map<String, dynamic> json) =>
      ImdbSearchResult(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        year: json['year'] ?? '',
        posterUrl: json['posterUrl'] ?? '',
        magnetId: json['magnetId'],
      );

  ImdbSearchResult copyWith({
    String? id,
    String? title,
    String? year,
    String? posterUrl,
    String? magnetId,
  }) {
    return ImdbSearchResult(
      id: id ?? this.id,
      title: title ?? this.title,
      year: year ?? this.year,
      posterUrl: posterUrl ?? this.posterUrl,
      magnetId: magnetId ?? this.magnetId,
    );
  }
}

class ImdbService {
  static const String _storagePrefix = 'imdb_link_';
  final Dio _dio = Dio();

  Future<List<ImdbSearchResult>> search(String query) async {
    try {
      final cleanQuery = Uri.encodeComponent(query);
      final url =
          'https://v3.sg.media-imdb.com/suggestion/x/$cleanQuery.json?includeVideos=0';

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
          return ImdbSearchResult(
            id: item['id'] ?? '',
            title: item['l'] ?? '',
            year: item['y']?.toString() ?? '',
            posterUrl: item['i']?['imageUrl'] ?? '',
          );
        }).toList();
      }
      return [];
    } catch (e) {
      print('IMDb Search Error: $e');
      return [];
    }
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
}
