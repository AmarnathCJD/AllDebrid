import 'package:alldebrid_app/services/ai_recommendation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AIRecommendationService.parseRecommendations', () {
    test('parses fenced JSON and normalizes tv type', () {
      const raw = '''
```json
[
  {
    "title": "Silo",
    "type": "TV Series",
    "genre": "Sci-Fi, Mystery",
    "imdbId": "tt14688458",
    "reason": "A tense, polished mystery."
  }
]
```
''';

      final parsed = AIRecommendationService.parseRecommendations(raw);

      expect(parsed, hasLength(1));
      expect(parsed.first['title'], 'Silo');
      expect(parsed.first['type'], 'tv');
      expect(parsed.first['imdbId'], 'tt14688458');
    });

    test('drops invalid imdb ids but keeps the recommendation', () {
      const raw = '''
[
  {
    "title": "Past Lives",
    "type": "movie",
    "genre": "Drama",
    "imdbId": "invalid",
    "reason": "Quiet and emotional."
  }
]
''';

      final parsed = AIRecommendationService.parseRecommendations(raw);

      expect(parsed, hasLength(1));
      expect(parsed.first['title'], 'Past Lives');
      expect(parsed.first['type'], 'movie');
      expect(parsed.first['imdbId'], '');
    });
  });
}
