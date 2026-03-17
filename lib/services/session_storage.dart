import 'package:shared_preferences/shared_preferences.dart';

/// Securely stores Telegram session string
class SessionStorage {
  static const String _sessionKey = 'tg_session';
  static const String _botTokensKey = 'tg_bot_tokens';
  static const String _chatIdKey = 'tg_chat_id';
  static const String _chatHashKey = 'tg_chat_hash';
  static const String _usernameKey = 'tg_username';

  static Future<void> saveSession({
    required String sessionString,
    String? botToken,
    int? chatId,
    int? chatHash,
    String? username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, sessionString);
    if (botToken != null) {
      await prefs.setStringList(_botTokensKey, [botToken]);
    }
    if (chatId != null) {
      await prefs.setInt(_chatIdKey, chatId);
    }
    if (chatHash != null) {
      await prefs.setInt(_chatHashKey, chatHash);
    }
    if (username != null) {
      await prefs.setString(_usernameKey, username);
    }
  }

  static Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }

  /// Get cached session string
  static Future<String?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionKey);
  }

  /// Get cached chat ID
  static Future<int?> getChatId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_chatIdKey);
  }

  /// Get cached chat hash
  static Future<int?> getChatHash() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_chatHashKey);
  }

  /// Get cached username
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  /// Get cached bot tokens
  static Future<List<String>> getBotTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_botTokensKey) ?? [];
  }

  /// Check if session exists
  static Future<bool> hasSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_sessionKey);
  }

  /// Clear session (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    await prefs.remove(_botTokensKey);
    await prefs.remove(_chatIdKey);
    await prefs.remove(_chatHashKey);
    await prefs.remove(_usernameKey);
  }
}
