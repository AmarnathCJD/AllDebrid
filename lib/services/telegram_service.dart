import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TelegramService {
  static final _lib = DynamicLibrary.open("libtg.so");

  // Status codes
  static const int OK = 0;
  static const int NEED_PASSWORD = 1;
  static const int NEED_SIGNUP = 2;

  // FFI function bindings
  static final _initClient =
      _lib.lookupFunction<Int32 Function(), int Function()>('InitClient');

  static final _sendCode = _lib.lookupFunction<Int32 Function(Pointer<Utf8>),
      int Function(Pointer<Utf8>)>('SendCode');

  static final _submitCode = _lib.lookupFunction<Int32 Function(Pointer<Utf8>),
      int Function(Pointer<Utf8>)>('SubmitCode');

  static final _submitPassword = _lib.lookupFunction<
      Int32 Function(Pointer<Utf8>),
      int Function(Pointer<Utf8>)>('SubmitPassword');

  static final _getSession =
      _lib.lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
          'GetSession');

  // Shared preferences key
  static const String _sessionKey = 'telegram_session';

  /// Initialize Telegram client
  static int initClient() {
    try {
      return _initClient();
    } catch (e) {
      throw Exception('Failed to initialize Telegram client: $e');
    }
  }

  /// Send authentication code to phone number
  static int sendCode(String phoneNumber) {
    try {
      final phonePtr = phoneNumber.toNativeUtf8();
      final result = _sendCode(phonePtr);
      malloc.free(phonePtr);
      return result;
    } catch (e) {
      throw Exception('Failed to send code: $e');
    }
  }

  /// Submit authentication code
  static int submitCode(String code) {
    try {
      final codePtr = code.toNativeUtf8();
      final result = _submitCode(codePtr);
      malloc.free(codePtr);
      return result;
    } catch (e) {
      throw Exception('Failed to submit code: $e');
    }
  }

  /// Submit 2FA password
  static int submitPassword(String password) {
    try {
      final passwordPtr = password.toNativeUtf8();
      final result = _submitPassword(passwordPtr);
      malloc.free(passwordPtr);
      return result;
    } catch (e) {
      throw Exception('Failed to submit password: $e');
    }
  }

  /// Get current session string
  static String getSession() {
    try {
      final sessionPtr = _getSession();
      final session = sessionPtr.toDartString();
      malloc.free(sessionPtr);
      return session;
    } catch (e) {
      throw Exception('Failed to get session: $e');
    }
  }

  /// Save session to shared preferences
  static Future<void> saveSession(String session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, session);
  }

  /// Get saved session from shared preferences
  static Future<String?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sessionKey);
  }

  /// Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final session = await getSavedSession();
    return session != null && session.isNotEmpty;
  }

  /// Clear session (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
