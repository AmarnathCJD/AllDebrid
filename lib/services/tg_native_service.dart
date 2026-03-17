import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart' as ffilib;
import 'dart:convert' show jsonDecode;
import 'dart:isolate';
import 'package:flutter/foundation.dart';

typedef CreateSessionC = ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>);
typedef CreateSessionDart = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>);

typedef InitTGFetcherC = ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>);
typedef InitTGFetcherDart = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>);

typedef ResolveUsernameC = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>);
typedef ResolveUsernameDart = ffi.Pointer<ffi.Char> Function(
    ffi.Pointer<ffi.Char>);

typedef FetchFileMetadataC = ffi.Pointer<ffi.Char> Function(
    ffi.Int64, ffi.Int64, ffi.Int32);
typedef FetchFileMetadataDart = ffi.Pointer<ffi.Char> Function(int, int, int);

typedef DownloadFileChunkC = ffi.Pointer<ffi.Char> Function(
    ffi.Int64, ffi.Int64, ffi.Int32, ffi.Int64, ffi.Int64);
typedef DownloadFileChunkDart = ffi.Pointer<ffi.Char> Function(
    int, int, int, int, int);

typedef DownloadFileC = ffi.Pointer<ffi.Char> Function(
    ffi.Int64, ffi.Int64, ffi.Int32, ffi.Pointer<ffi.Char>);
typedef DownloadFileDart = ffi.Pointer<ffi.Char> Function(
    int, int, int, ffi.Pointer<ffi.Char>);

typedef EncodeHashC = ffi.Pointer<ffi.Char> Function(ffi.Int32);
typedef EncodeHashDart = ffi.Pointer<ffi.Char> Function(int);

typedef DecodeHashC = ffi.Int32 Function(ffi.Pointer<ffi.Char>);
typedef DecodeHashDart = int Function(ffi.Pointer<ffi.Char>);

typedef StartStreamingServerC = ffi.Int32 Function();
typedef StartStreamingServerDart = int Function();

class TGNativeService {
  static final TGNativeService _instance = TGNativeService._();
  bool _initialized = false;
  String? _cachedSession;
  int _failureCount = 0;
  static ffi.DynamicLibrary? _cachedDylib;
  static final Map<String, FileMetadata> _metadataCache = {};
  static const int _maxRetries = 3;
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _retryDelay = Duration(milliseconds: 500);

  factory TGNativeService() {
    return _instance;
  }

  TGNativeService._();

  /// Helper to get or open dynamic library - cached in main isolate
  static ffi.DynamicLibrary _getDylib() {
    // Return cached library if available
    if (_cachedDylib != null) {
      return _cachedDylib!;
    }

    debugPrint('[TGNative] Loading dynamic library for first time...');
    if (Platform.isAndroid) {
      _cachedDylib = ffi.DynamicLibrary.open('libtg_fetch.so');
      debugPrint('[TGNative] Successfully loaded libtg_fetch.so');
      return _cachedDylib!;
    } else if (Platform.isIOS) {
      _cachedDylib = ffi.DynamicLibrary.process();
      debugPrint('[TGNative] Successfully loaded iOS process library');
      return _cachedDylib!;
    } else {
      debugPrint('[TGNative] ERROR: Unsupported platform');
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Retry wrapper with exponential backoff for unreliable connections
  Future<T> _executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = _maxRetries,
  }) async {
    int attempt = 0;
    Duration delay = _retryDelay;

    while (true) {
      try {
        debugPrint('[TGNative] Attempt ${attempt + 1}/$maxRetries...');
        final result = await operation().timeout(_timeout);
        debugPrint('[TGNative] Operation succeeded on attempt ${attempt + 1}');
        return result;
      } catch (e) {
        attempt++;
        debugPrint('[TGNative] Attempt $attempt failed: $e');
        if (attempt >= maxRetries) {
          _failureCount++;
          debugPrint('[TGNative] Max retries reached. Failure count: $_failureCount');
          rethrow;
        }
        debugPrint('[TGNative] Retrying in ${delay.inMilliseconds}ms...');
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }
  }

  static Future<String> initialize({required String stringSession}) async {
    debugPrint('[TGNative] Initializing TGNativeService...');
    _instance._cachedSession = stringSession;
    debugPrint('[TGNative] Cached session string (length: ${stringSession.length})');

    final username = await _instance._executeWithRetry(() async {
      return await Isolate.run(() {
        try {
          final dylib = _getDylib();
          final initFunc = dylib
              .lookupFunction<InitTGFetcherC, InitTGFetcherDart>('InitTGFetcher');

          final sessionPtr = stringSession.toNativeUtf8();
          final resultPtr = initFunc(sessionPtr.cast());
          final resultStr = resultPtr.cast<ffilib.Utf8>().toDartString();
          ffilib.malloc.free(sessionPtr);
          ffilib.malloc.free(resultPtr.cast());

          final result = jsonDecode(resultStr) as Map<String, dynamic>;
          if (result['error'] != null) {
            throw Exception('Init failed: ${result['error']}');
          }

          final user = result['username']?.toString() ?? 'Unknown User';
          debugPrint('[TGNative] Initialization successful, username: $user');
          return user;
        } catch (e) {
          debugPrint('[TGNative] ERROR in initialize: $e');
          rethrow;
        }
      });
    });

    // Set initialization status on main isolate
    _instance._initialized = true;
    _instance._failureCount = 0;
    debugPrint('[TGNative] Initialization complete. Username: $username');
    return username;
  }

  /// Reconnect if connection was lost
  Future<bool> reconnect() async {
    debugPrint('[TGNative] Reconnecting...');
    if (_cachedSession == null) {
      debugPrint('[TGNative] ERROR: No cached session available');
      throw Exception('No cached session available');
    }

    try {
      await _executeWithRetry(() async {
        return await Isolate.run(() {
          try {
            final dylib = _getDylib();
            final initFunc = dylib
                .lookupFunction<InitTGFetcherC, InitTGFetcherDart>('InitTGFetcher');

            final sessionPtr = _instance._cachedSession!.toNativeUtf8();
            final resultPtr = initFunc(sessionPtr.cast());
            final resultStr = resultPtr.cast<ffilib.Utf8>().toDartString();
            ffilib.malloc.free(sessionPtr);
            ffilib.malloc.free(resultPtr.cast());

            final result = jsonDecode(resultStr) as Map<String, dynamic>;
            if (result['error'] != null) {
              throw Exception('Reconnect failed: ${result['error']}');
            }
            return true;
          } catch (e) {
            debugPrint('[TGNative] ERROR in reconnect: $e');
            rethrow;
          }
        });
      });
      _failureCount = 0;
      debugPrint('[TGNative] Reconnect successful');
      return true;
    } catch (e) {
      debugPrint('[TGNative] Reconnect failed: $e');
      return false;
    }
  }

  /// Get failure count for monitoring connection health
  int getFailureCount() => _failureCount;

  /// Reset failure counter
  void resetFailures() => _failureCount = 0;

  Future<String> createSessionFromBotToken(String botToken) async {
    debugPrint('[TGNative] Creating session from bot token');
    return _executeWithRetry(() async {
      return Isolate.run(() {
        try {
          final dylib = _getDylib();
          final func = dylib.lookupFunction<CreateSessionC, CreateSessionDart>(
              'CreateSessionFromBotToken');

          final tokenPtr = botToken.toNativeUtf8();
          final resultPtr = func(tokenPtr.cast());
          final resultStr = resultPtr.cast<ffilib.Utf8>().toDartString();
          ffilib.malloc.free(tokenPtr);
          ffilib.malloc.free(resultPtr.cast());

          final result = jsonDecode(resultStr) as Map<String, dynamic>;
          if (result['error'] != null) {
            throw Exception('Create session failed: ${result['error']}');
          }

          final session = result['session'] as String;
          return session;
        } catch (e) {
          debugPrint('[TGNative] ERROR in createSessionFromBotToken: $e');
          rethrow;
        }
      });
    });
  }

  /// Resolves a telegram channel/megagroup username to its id and access_hash
  Future<Map<String, dynamic>> resolveUsername(String username) async {
    debugPrint('[TGNative] Resolving username: $username');
    if (!_initialized) {
      debugPrint('[TGNative] ERROR: Service not initialized');
      throw Exception('TGNativeService not initialized');
    }

    return _executeWithRetry(() async {
      return Isolate.run(() {
        try {
          final dylib = _getDylib();
          final func =
              dylib.lookupFunction<ResolveUsernameC, ResolveUsernameDart>(
                  'ResolveUsername');

          final usernamePtr = username.toNativeUtf8();
          final resultPtr = func(usernamePtr.cast());
          final resultStr = resultPtr.cast<ffilib.Utf8>().toDartString();
          ffilib.malloc.free(usernamePtr);
          ffilib.malloc.free(resultPtr.cast());

          final result = jsonDecode(resultStr) as Map<String, dynamic>;
          if (result['error'] != null) {
            throw Exception('Resolve username failed: ${result['error']}');
          }

          return {
            'channel_id': result['channel_id'],
            'access_hash': result['access_hash'],
          };
        } catch (e) {
          debugPrint('[TGNative] ERROR in resolveUsername: $e');
          rethrow;
        }
      });
    });
  }

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Fetch file metadata from Telegram (with caching)
  Future<FileMetadata> fetchFileMetadata({
    required int channelId,
    required int accessHash,
    required int msgId,
  }) async {
    final cacheKey = '$channelId:$accessHash:$msgId';

    // Return cached metadata if available
    if (_metadataCache.containsKey(cacheKey)) {
      debugPrint('[TGNative] Metadata cache hit: $cacheKey');
      return _metadataCache[cacheKey]!;
    }

    debugPrint('[TGNative] Fetching metadata: channelId=$channelId, accessHash=$accessHash, msgId=$msgId');
    if (!_initialized) {
      debugPrint('[TGNative] ERROR: Service not initialized');
      throw Exception('TGNativeService not initialized');
    }

    return _executeWithRetry(() async {
      return Isolate.run(() {
        try {
          final dylib = _getDylib();
          final func =
              dylib.lookupFunction<FetchFileMetadataC, FetchFileMetadataDart>(
                  'FetchFileMetadata');

          final resultPtr = func(channelId, accessHash, msgId);
          final resultStr = resultPtr.cast<ffilib.Utf8>().toDartString();
          ffilib.malloc.free(resultPtr.cast());

          final result = jsonDecode(resultStr) as Map<String, dynamic>;
          if (result['error'] != null) {
            throw Exception('Fetch metadata failed: ${result['error']}');
          }

          final metadata = FileMetadata(
            msgId: result['msg_id'] as int,
            size: result['size'] as int,
            mimeType: result['mime_type'] as String? ?? 'application/octet-stream',
            name: result['name'] as String?,
          );

          // Cache the metadata
          _metadataCache[cacheKey] = metadata;
          return metadata;
        } catch (e) {
          debugPrint('[TGNative] ERROR in fetchFileMetadata: $e');
          rethrow;
        }
      });
    });
  }

  /// Download a chunk of file
  /// Returns hex-encoded bytes
  Future<List<int>> downloadFileChunk({
    required int channelId,
    required int accessHash,
    required int msgId,
    required int start,
    required int end,
  }) async {
    debugPrint('[TGNative] Downloading chunk: msgId=$msgId, range=$start-$end (size=${end - start})');
    if (!_initialized) {
      debugPrint('[TGNative] ERROR: Service not initialized');
      throw Exception('TGNativeService not initialized');
    }

    return _executeWithRetry(() async {
      return Isolate.run(() {
        try {
          final dylib = _getDylib();
          final func =
              dylib.lookupFunction<DownloadFileChunkC, DownloadFileChunkDart>(
                  'DownloadFileChunk');

          final resultPtr = func(channelId, accessHash, msgId, start, end);
          final resultStr = resultPtr.cast<ffilib.Utf8>().toDartString();
          ffilib.malloc.free(resultPtr.cast());

          final result = jsonDecode(resultStr) as Map<String, dynamic>;
          if (result['error'] != null) {
            throw Exception('Download chunk failed: ${result['error']}');
          }

          // Decode hex data
          final hexData = result['data'] as String;
          final bytes = <int>[];
          for (int i = 0; i < hexData.length; i += 2) {
            bytes.add(int.parse(hexData.substring(i, i + 2), radix: 16));
          }
          return bytes;
        } catch (e) {
          debugPrint('[TGNative] ERROR in downloadFileChunk: $e');
          rethrow;
        }
      });
    });
  }

  /// Download complete file to disk
  Future<String> downloadFile({
    required int channelId,
    required int accessHash,
    required int msgId,
    required String filePath,
  }) async {
    debugPrint('[TGNative] Downloading file: msgId=$msgId to filePath=$filePath');
    if (!_initialized) {
      debugPrint('[TGNative] ERROR: Service not initialized');
      throw Exception('TGNativeService not initialized');
    }

    return _executeWithRetry(() async {
      return Isolate.run(() {
        try {
          final dylib = _getDylib();
          final func =
              dylib.lookupFunction<DownloadFileC, DownloadFileDart>('DownloadFile');

          final filePathPtr = filePath.toNativeUtf8();
          final resultPtr = func(channelId, accessHash, msgId, filePathPtr.cast());
          final resultStr = resultPtr.cast<ffilib.Utf8>().toDartString();
          ffilib.malloc.free(filePathPtr);
          ffilib.malloc.free(resultPtr.cast());

          final result = jsonDecode(resultStr) as Map<String, dynamic>;
          if (result['error'] != null) {
            throw Exception('Download file failed: ${result['error']}');
          }

          final path = result['path'] as String;
          return path;
        } catch (e) {
          debugPrint('[TGNative] ERROR in downloadFile: $e');
          rethrow;
        }
      });
    });
  }

  /// Encode message ID to hash
  String encodeHash(int msgId) {
    debugPrint('[TGNative] Encoding hash for msgId: $msgId');
    final dylib = _getDylib();
    final func =
        dylib.lookupFunction<EncodeHashC, EncodeHashDart>('EncodeHash');

    debugPrint('[TGNative] Calling EncodeHash($msgId)');
    final resultPtr = func(msgId);
    final hash = resultPtr.cast<ffilib.Utf8>().toDartString();
    debugPrint('[TGNative] Encoded hash: $hash');
    ffilib.malloc.free(resultPtr.cast());
    return hash;
  }

  /// Decode hash to message ID
  int decodeHash(String hash) {
    debugPrint('[TGNative] Decoding hash: $hash');
    final dylib = _getDylib();
    final func =
        dylib.lookupFunction<DecodeHashC, DecodeHashDart>('DecodeHash');

    final hashPtr = hash.toNativeUtf8();
    debugPrint('[TGNative] Calling DecodeHash($hash)');
    final msgId = func(hashPtr.cast());
    debugPrint('[TGNative] Decoded msgId: $msgId');
    ffilib.malloc.free(hashPtr);
    return msgId;
  }

  /// Start native streaming server and return port
  Future<int> startStreamingServer() async {
    debugPrint('[TGNative] Starting streaming server...');
    return Isolate.run(() {
      try {
        final dylib = _getDylib();
        final func = dylib.lookupFunction<StartStreamingServerC, StartStreamingServerDart>('StartStreamingServer');
        final port = func();
        debugPrint('[TGNative] Streaming server started on port: $port');
        return port;
      } catch (e) {
        debugPrint('[TGNative] ERROR starting streaming server: $e');
        rethrow;
      }
    });
  }
}

/// File metadata from Telegram
class FileMetadata {
  final int msgId;
  final int size;
  final String mimeType;
  final String? name;

  FileMetadata({
    required this.msgId,
    required this.size,
    required this.mimeType,
    this.name,
  });

  @override
  String toString() => 'FileMetadata($name, $size bytes, $mimeType)';
}
