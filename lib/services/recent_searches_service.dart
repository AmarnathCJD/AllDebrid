import 'package:shared_preferences/shared_preferences.dart';

class RecentSearchesService {
  static const String _key = 'recent_searches';
  static const int _maxSearches = 10;

  /// Get recent searches
  static Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  /// Add a new search query
  static Future<void> addSearch(String query) async {
    if (query.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> searches = prefs.getStringList(_key) ?? [];

    // Remove if already exists (to move to top)
    searches.remove(query);

    // Add to top
    searches.insert(0, query);

    // Keep only max searches
    if (searches.length > _maxSearches) {
      searches = searches.take(_maxSearches).toList();
    }

    await prefs.setStringList(_key, searches);
  }

  /// Remove a specific search
  static Future<void> removeSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> searches = prefs.getStringList(_key) ?? [];
    searches.remove(query);
    await prefs.setStringList(_key, searches);
  }

  /// Clear all recent searches
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
