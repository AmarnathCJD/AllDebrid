import 'package:dio/dio.dart';
import 'dart:convert';

class AIRecommendationService {
  static const String _invokeUrl =
      "https://integrate.api.nvidia.com/v1/chat/completions";
  static const String _model = "mistralai/mistral-small-4-119b-2603";

  final Dio _dio = Dio();
  final String _apiKey;

  AIRecommendationService({required String apiKey}) : _apiKey = apiKey;

  static const String _systemPrompt =
      """You are an expert movie and TV show recommender with deep knowledge of entertainment. 
Your role is to provide personalized recommendations based on:
- User's current mood and preferences
- Their watchlist history
- Content they're currently watching
- Genres and themes they enjoy

When given information about a user's viewing habits and current mood, analyze it and recommend 3-5 titles.

For each recommendation, provide:
1. Title
2. Type (Movie/TV Show)
3. IMDb ID (if known, format: ttXXXXXXXX)
4. Genre
5. Why it matches their mood (2-3 sentences)

Format your response as a JSON array with these exact fields:
[
  {
    "title": "Movie/Show Title",
    "type": "movie|tv",
    "genre": "Genre1, Genre2",
    "imdbId": "ttXXXXXXXX",
    "reason": "Why this matches your mood and preferences"
  }
]

Keep recommendations fresh, varied, and actually helpful.""";

  Future<List<Map<String, dynamic>>> getRecommendations({
    required String userInput,
    required List<String> watchlist,
    required List<String> continueWatching,
    required List<String> likedGenres,
  }) async {
    try {
      final userContext = _buildUserContext(
        watchlist: watchlist,
        continueWatching: continueWatching,
        likedGenres: likedGenres,
      );

      final messages = [
        {
          "role": "system",
          "content": _systemPrompt,
        },
        {
          "role": "user",
          "content": "$userContext\n\nUser request: $userInput",
        },
      ];

      final payload = {
        "model": _model,
        "messages": messages,
        "max_tokens": 2048,
        "temperature": 1.00,
        "top_p": 1.00,
        "stream": false,
      };

      final response = await _dio.post(
        _invokeUrl,
        options: Options(
          headers: {
            "Authorization": "Bearer $_apiKey",
            "Accept": "application/json",
          },
        ),
        data: payload,
      );

      if (response.statusCode == 200) {
        final content =
            response.data['choices'][0]['message']['content'] as String;
        return _parseRecommendations(content);
      }
      return [];
    } catch (e) {
      print('Error getting recommendations: $e');
      return [];
    }
  }

  String _buildUserContext({
    required List<String> watchlist,
    required List<String> continueWatching,
    required List<String> likedGenres,
  }) {
    final buffer = StringBuffer();
    buffer.writeln("User Context:");

    if (watchlist.isNotEmpty) {
      buffer.writeln(
          "Watchlist (${watchlist.length} items): ${watchlist.join(', ')}");
    }

    if (continueWatching.isNotEmpty) {
      buffer.writeln("Currently Watching: ${continueWatching.join(', ')}");
    }

    if (likedGenres.isNotEmpty) {
      buffer.writeln("Preferred Genres: ${likedGenres.join(', ')}");
    }

    return buffer.toString();
  }

  List<Map<String, dynamic>> _parseRecommendations(String jsonString) {
    try {
      // Extract JSON array from the response text
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(jsonString);
      if (jsonMatch == null) return [];

      final jsonText = jsonMatch.group(0)!;
      final List<dynamic> parsed = jsonDecode(jsonText);

      return parsed.map((item) {
        return {
          'title': item['title'] ?? 'Unknown',
          'type': item['type'] ?? 'movie',
          'genre': item['genre'] ?? 'Unknown',
          'imdbId': item['imdbId'] ?? '',
          'reason': item['reason'] ?? 'Great recommendation for you!',
        };
      }).toList();
    } catch (e) {
      print('Error parsing recommendations: $e');
      return [];
    }
  }

  Future<String> generateStreamingResponse({
    required String userInput,
    required List<String> watchlist,
  }) async {
    final userContext = _buildUserContext(
        watchlist: watchlist, continueWatching: [], likedGenres: []);

    final messages = [
      {
        "role": "system",
        "content": _systemPrompt,
      },
      {
        "role": "user",
        "content": "$userContext\n\nUser request: $userInput",
      },
    ];

    final payload = {
      "model": _model,
      "messages": messages,
      "max_tokens": 2048,
      "temperature": 1.00,
      "top_p": 1.00,
      "stream": true,
    };

    try {
      final request = await _dio.post(
        _invokeUrl,
        options: Options(
          headers: {
            "Authorization": "Bearer $_apiKey",
            "Accept": "text/event-stream",
          },
          responseType: ResponseType.stream,
        ),
        data: payload,
      );

      final stream = request.data.stream as Stream<List<int>>;
      final response = StringBuffer();

      await for (final chunk in stream) {
        response.write(utf8.decode(chunk));
      }

      return response.toString();
    } catch (e) {
      print('Error in streaming: $e');
      return '';
    }
  }
}
