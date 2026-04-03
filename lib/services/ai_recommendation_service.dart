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

  static const String _systemPrompt = '''
You are an expert movie and TV recommender.
Return only valid JSON.
Do not wrap the JSON in markdown fences.
Recommend exactly 5 titles.
Avoid titles that already appear in the user's watchlist or continue-watching list.
Keep recommendations varied, discoverable, and specific to the user's vibe.

Return this exact schema:
[
  {
    "title": "Title",
    "type": "movie|tv",
    "genre": "Genre1, Genre2",
    "imdbId": "tt1234567",
    "reason": "One short, specific explanation."
  }
]
''';

  Future<List<Map<String, dynamic>>> getRecommendations({
    required String userInput,
    required List<String> watchlist,
    required List<String> continueWatching,
    required List<String> likedGenres,
  }) async {
    if (_apiKey.trim().isEmpty) {
      throw Exception('Missing NVIDIA API key');
    }

    try {
      final userContext = _buildUserContext(
        watchlist: watchlist,
        continueWatching: continueWatching,
        likedGenres: likedGenres,
      );

      final response = await _dio.post(
        _invokeUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_apiKey',
            'Accept': 'application/json',
          },
        ),
        data: {
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': _systemPrompt,
            },
            {
              'role': 'user',
              'content': '$userContext\n\nUser request: $userInput',
            },
          ],
          'max_tokens': 1200,
          'temperature': 0.7,
          'top_p': 0.9,
          'stream': false,
        },
      );

      if (response.statusCode == 200) {
        final content = response.data['choices'][0]['message']['content'];
        if (content is String) {
          final parsed = parseRecommendations(content);
          if (parsed.isNotEmpty) {
            return parsed;
          }
        }
      }
    } catch (_) {
      // Fall back to curated picks so the screen still feels useful.
    }

    return _buildFallbackRecommendations(
      userInput: userInput,
      likedGenres: likedGenres,
      watchlist: watchlist,
    );
  }

  String _buildUserContext({
    required List<String> watchlist,
    required List<String> continueWatching,
    required List<String> likedGenres,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('User context:');

    if (watchlist.isNotEmpty) {
      buffer.writeln(
        'Watchlist (${watchlist.length} items): ${watchlist.take(20).join(', ')}',
      );
    }

    if (continueWatching.isNotEmpty) {
      buffer.writeln(
        'Continue watching: ${continueWatching.take(10).join(', ')}',
      );
    }

    if (likedGenres.isNotEmpty) {
      buffer.writeln('Preferred genres: ${likedGenres.take(8).join(', ')}');
    }

    return buffer.toString();
  }

  static List<Map<String, dynamic>> parseRecommendations(String rawContent) {
    try {
      final cleaned = rawContent
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(cleaned);
      if (jsonMatch == null) {
        return [];
      }

      final jsonText = jsonMatch.group(0)!;
      final parsed = jsonDecode(jsonText);
      if (parsed is! List) {
        return [];
      }

      return parsed
          .whereType<Map>()
          .map((item) => _normalizeRecommendation(
                Map<String, dynamic>.from(item.cast<String, dynamic>()),
              ))
          .where((item) => item['title'].toString().trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Map<String, dynamic> _normalizeRecommendation(
    Map<String, dynamic> item,
  ) {
    final rawType = (item['type'] ?? 'movie').toString().toLowerCase();
    final normalizedType =
        rawType.contains('tv') || rawType.contains('series') ? 'tv' : 'movie';
    final imdbId = (item['imdbId'] ?? '').toString().trim();
    final validImdbId =
        RegExp(r'^tt\d{7,10}$').hasMatch(imdbId) ? imdbId : '';

    final reason = (item['reason'] ?? 'A strong fit for your current vibe.')
        .toString()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return {
      'title': (item['title'] ?? 'Unknown title').toString().trim(),
      'type': normalizedType,
      'genre': (item['genre'] ?? 'Drama').toString().trim(),
      'imdbId': validImdbId,
      'reason': reason.isEmpty ? 'A strong fit for your current vibe.' : reason,
    };
  }

  List<Map<String, dynamic>> _buildFallbackRecommendations({
    required String userInput,
    required List<String> likedGenres,
    required List<String> watchlist,
  }) {
    final seedGenre = likedGenres.isNotEmpty ? likedGenres.first : 'Drama';
    final vibe = userInput.trim().isEmpty ? 'your current mood' : userInput;
    final excluded = watchlist.map((item) => item.toLowerCase()).toSet();

    final picks = [
      {
        'title': 'The Bear',
        'type': 'tv',
        'genre': 'Drama, Comedy',
        'imdbId': 'tt14452776',
        'reason': 'Fast, intense, and emotional. A strong pick for $vibe.',
      },
      {
        'title': 'Past Lives',
        'type': 'movie',
        'genre': 'Romance, Drama',
        'imdbId': 'tt13238346',
        'reason': 'Quiet, intimate, and beautifully written when you want something reflective.',
      },
      {
        'title': 'Silo',
        'type': 'tv',
        'genre': 'Sci-Fi, Mystery',
        'imdbId': 'tt14688458',
        'reason': 'A polished mystery with a strong binge hook and steady tension.',
      },
      {
        'title': 'Dune: Part Two',
        'type': 'movie',
        'genre': 'Sci-Fi, Adventure',
        'imdbId': 'tt15239678',
        'reason': 'Great when you want something cinematic, immersive, and high-stakes.',
      },
      {
        'title': 'Blue Eye Samurai',
        'type': 'tv',
        'genre': '$seedGenre, Action',
        'imdbId': 'tt13309742',
        'reason': 'Stylish, character-driven, and easy to recommend across a lot of moods.',
      },
    ];

    return picks
        .where(
          (item) => !excluded.contains(item['title'].toString().toLowerCase()),
        )
        .toList();
  }

  Future<String> generateStreamingResponse({
    required String userInput,
    required List<String> watchlist,
  }) async {
    if (_apiKey.trim().isEmpty) {
      throw Exception('Missing NVIDIA API key');
    }

    final userContext = _buildUserContext(
      watchlist: watchlist,
      continueWatching: [],
      likedGenres: [],
    );

    final request = await _dio.post(
      _invokeUrl,
      options: Options(
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Accept': 'text/event-stream',
        },
        responseType: ResponseType.stream,
      ),
      data: {
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content': _systemPrompt,
          },
          {
            'role': 'user',
            'content': '$userContext\n\nUser request: $userInput',
          },
        ],
        'max_tokens': 1200,
        'temperature': 0.7,
        'top_p': 0.9,
        'stream': true,
      },
    );

    final stream = request.data.stream as Stream<List<int>>;
    final response = StringBuffer();

    await for (final chunk in stream) {
      response.write(utf8.decode(chunk));
    }

    return response.toString();
  }
}
