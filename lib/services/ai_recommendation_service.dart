import 'dart:convert';
import 'package:dio/dio.dart';

class AIRecommendationService {
  static const String _invokeUrl =
      'https://integrate.api.nvidia.com/v1/chat/completions';
  static const String _model = 'mistralai/mistral-small-4-119b-2603';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 20),
    ),
  );
  final String _apiKey;

  AIRecommendationService({required String apiKey}) : _apiKey = apiKey;

  /// Step 1: Map a user's vibe to specific genre IDs from our catalog.
  Future<List<String>> getGenreIdsForVibe({
    required String vibe,
    required Map<String, String> availableGenres,
  }) async {
    if (_apiKey.trim().isEmpty) throw Exception('Missing API key');

    final genreList = availableGenres.entries
        .map((e) => '"${e.key}" (ID: ${e.value})')
        .join(', ');

    try {
      final response = await _dio.post(
        _invokeUrl,
        options: Options(headers: {'Authorization': 'Bearer $_apiKey'}),
        data: {
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are an expert film curator. Return only a JSON array of up to 4 Genre IDs that most closely match the user\'s requested vibe. Catalog: $genreList'
            },
            {
              'role': 'user',
              'content': 'Vibe: $vibe\nReturn only the JSON list of IDs.'
            },
          ],
          'temperature': 0.1,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'].toString();
        final match = RegExp(r'\[[\s\S]*\]').firstMatch(content);
        if (match != null) {
          final List<dynamic> ids = jsonDecode(match.group(0)!);
          return ids.whereType<String>().toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Step 2: From a pool of potential items, pick the best 10 that fit the vibe and user context.
  Future<List<Map<String, dynamic>>> rankRecommendationsFromPool({
    required String vibe,
    required List<Map<String, dynamic>> pool,
    required List<String> userContextTitles,
  }) async {
    if (_apiKey.trim().isEmpty) throw Exception('Missing API key');
    if (pool.isEmpty) return [];

    // Filter out duplicates and limit pool for AI context windows
    final uniquePool = <String, Map<String, dynamic>>{};
    for (final item in pool) {
      if (item['title'] != null) {
        uniquePool[item['title'].toString().toLowerCase()] = item;
      }
    }
    
    final candidateList = uniquePool.values.take(30).map((i) => 
      '{"title": "${i['title']}", "id": "${i['imdbId']}", "type": "${i['mediaType']}", "plot": "${i['plot']}"}'
    ).join(', ');

    try {
      final response = await _dio.post(
        _invokeUrl,
        options: Options(headers: {'Authorization': 'Bearer $_apiKey'}),
        data: {
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': '''
              You are an AI personalization engine. 
              From the provided JSON pool, pick the 10 BEST titles that fit the "Vibe".
              Exclude any titles mentioned in the User Context.
              Return precisely this JSON format:
              [{"title": "Title", "type": "movie|tv", "imdbId": "tt...", "reason": "Short vibe reason"}]
              '''
            },
            {
              'role': 'user',
              'content': 'Vibe: $vibe\nUser Context (Already Watched): ${userContextTitles.join(', ')}\n\nPool: [$candidateList]'
            },
          ],
          'temperature': 0.5,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'].toString();
        final match = RegExp(r'\[[\s\S]*\]').firstMatch(content);
        if (match != null) {
          final List<dynamic> parsed = jsonDecode(match.group(0)!);
          return parsed.whereType<Map>().map((i) => Map<String, dynamic>.from(i)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // Legacy support for basic recommendation
  Future<List<Map<String, dynamic>>> getRecommendations({
    required String userInput,
    required List<String> watchlist,
    required List<String> continueWatching,
    required List<String> likedGenres,
  }) async {
    // Basic implementation for backward compatibility or direct calls
    return []; 
  }

  /// Parses raw JSON recommendations from the AI response safely.
  static List<Map<String, dynamic>> parseRecommendations(String rContent) {
    try {
      // Find JSON block if it exists
      String content = rContent;
      if (rContent.contains('```json')) {
        final start = rContent.indexOf('```json') + 7;
        final end = rContent.lastIndexOf('```');
        content = rContent.substring(start, end).trim();
      } else if (rContent.contains('```')) {
        final start = rContent.indexOf('```') + 3;
        final end = rContent.lastIndexOf('```');
        content = rContent.substring(start, end).trim();
      }

      final dynamic decoded = jsonDecode(content);
      if (decoded is List) {
        return decoded.map((item) {
          final Map<String, dynamic> rec = Map<String, dynamic>.from(item as Map);

          // Normalize type
          final type = rec['type']?.toString().toLowerCase() ?? 'movie';
          rec['type'] = (type.contains('tv') || type.contains('series')) ? 'tv' : 'movie';

          // Normalize IMDB ID
          final imdb = rec['imdbId']?.toString() ?? '';
          rec['imdbId'] = imdb.startsWith('tt') ? imdb : '';

          return rec;
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

