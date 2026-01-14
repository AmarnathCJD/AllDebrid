import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// AllDebrid API Service
class AllDebridService {
  static const String baseUrl = 'https://api.alldebrid.com';
  static const String apiVersion = 'v4';
  static const String apiVersion41 = 'v4.1';

  final String apiKey;
  final Dio _dio;

  AllDebridService({required this.apiKey})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'User-Agent': 'AllDebridApp/1.0',
          },
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.queryParameters['apikey'] = apiKey;
        options.queryParameters['agent'] = 'AllDebridApp';
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (error, handler) {
        return handler.next(error);
      },
    ));
  }

  // ==================== USER ====================

  Future<User> getUser() async {
    final response = await _dio.get('/$apiVersion/user');
    _checkError(response.data);
    return User.fromJson(response.data['data']);
  }

  Future<bool> ping() async {
    final response = await _dio.get('/$apiVersion/ping');
    _checkError(response.data);
    return response.data['data']?['ping'] == 'pong';
  }

  // ==================== LINKS ====================

  Future<List<LinkInfo>> getLinkInfo(List<String> links,
      {String? password}) async {
    final data = <String, dynamic>{};
    for (int i = 0; i < links.length; i++) {
      data['link[$i]'] = links[i];
    }
    if (password != null) {
      data['password'] = password;
    }

    final response = await _dio.post(
      '/$apiVersion/link/infos',
      data: FormData.fromMap(data),
    );
    _checkError(response.data);

    final infos = response.data['data']['infos'] as List;
    return infos.map((e) => LinkInfo.fromJson(e)).toList();
  }

  Future<UnlockedLink> unlockLink(String link, {String? password}) async {
    final data = {'link': link};
    if (password != null) {
      data['password'] = password;
    }

    final response = await _dio.post(
      '/$apiVersion/link/unlock',
      data: FormData.fromMap(data),
    );
    _checkError(response.data);
    return UnlockedLink.fromJson(response.data['data']);
  }

  Future<List<String>> getRedirectorLinks(String link) async {
    debugPrint('Calling redirector with link: $link');
    final response = await _dio.get(
      '/$apiVersion/link/redirector',
      queryParameters: {'link': link},
    );
    _checkError(response.data);
    return List<String>.from(response.data['data']['links'] ?? []);
  }

  Future<StreamingLink> getStreamingLink(String id, String streamId) async {
    final response = await _dio.post(
      '/$apiVersion/link/streaming',
      data: FormData.fromMap({'id': id, 'stream': streamId}),
    );
    _checkError(response.data);
    return StreamingLink.fromJson(response.data['data']);
  }

  Future<DelayedLink> getDelayedLink(String delayedId) async {
    final response = await _dio.post(
      '/$apiVersion/link/delayed',
      data: FormData.fromMap({'id': delayedId}),
    );
    _checkError(response.data);
    return DelayedLink.fromJson(response.data['data']);
  }

  Future<String?> waitForDelayedLink(String delayedId,
      {Duration timeout = const Duration(minutes: 5)}) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final delayed = await getDelayedLink(delayedId);
      if (delayed.isReady) {
        return delayed.link;
      }
      await Future.delayed(const Duration(seconds: 5));
    }
    return null;
  }

  // ==================== MAGNETS ====================

  Future<List<MagnetUploadResult>> uploadMagnets(List<String> magnets) async {
    final data = <String, dynamic>{};
    for (int i = 0; i < magnets.length; i++) {
      data['magnets[$i]'] = magnets[i];
    }

    final response = await _dio.post(
      '/$apiVersion/magnet/upload',
      data: FormData.fromMap(data),
    );
    _checkError(response.data);

    final results = response.data['data']['magnets'] as List;
    return results.map((e) => MagnetUploadResult.fromJson(e)).toList();
  }

  Future<MagnetUploadResult> uploadSingleMagnet(String magnet) async {
    final results = await uploadMagnets([magnet]);
    if (results.isEmpty) {
      throw Exception('No magnet upload result returned');
    }
    if (results.first.hasError) {
      throw Exception(results.first.error);
    }
    return results.first;
  }

  Future<List<MagnetStatus>> getMagnetStatus(
      {String? magnetId, String? statusFilter}) async {
    final data = <String, dynamic>{};
    if (magnetId != null) data['id'] = magnetId;
    if (statusFilter != null) data['status'] = statusFilter;

    final response = await _dio.post(
      '/$apiVersion41/magnet/status',
      data: data.isNotEmpty ? FormData.fromMap(data) : null,
    );
    _checkError(response.data);

    final magnets = response.data['data']['magnets'] as List;
    return magnets.map((e) => MagnetStatus.fromJson(e)).toList();
  }

  Future<List<MagnetStatus>> getAllMagnets() => getMagnetStatus();
  Future<List<MagnetStatus>> getActiveMagnets() =>
      getMagnetStatus(statusFilter: 'active');
  Future<List<MagnetStatus>> getReadyMagnets() =>
      getMagnetStatus(statusFilter: 'ready');

  Future<List<MagnetFile>> getMagnetFiles(String magnetId) async {
    final response = await _dio.post(
      '/$apiVersion/magnet/files',
      data: FormData.fromMap({'id[]': magnetId}),
    );
    _checkError(response.data);

    final magnets = response.data['data']['magnets'] as List;
    if (magnets.isEmpty) return [];

    final magnetData = magnets.first;
    if (magnetData['error'] != null) {
      throw Exception(magnetData['error']['message']);
    }

    final files = magnetData['files'] as List?;
    return files?.map((e) => MagnetFile.fromJson(e)).toList() ?? [];
  }

  Future<void> deleteMagnet(String magnetId) async {
    final response = await _dio.post(
      '/$apiVersion/magnet/delete',
      data: FormData.fromMap({'id': magnetId}),
    );
    _checkError(response.data);
  }

  Future<void> restartMagnet(String magnetId) async {
    final response = await _dio.post(
      '/$apiVersion/magnet/restart',
      data: FormData.fromMap({'id': magnetId}),
    );
    _checkError(response.data);
  }

  // ==================== HOSTS ====================

  Future<HostsResponse> getHosts() async {
    final response = await _dio.get('/$apiVersion/hosts');
    _checkError(response.data);
    return HostsResponse.fromJson(response.data['data']);
  }

  Future<bool> isLinkSupported(String link) async {
    try {
      final infos = await getLinkInfo([link]);
      if (infos.isEmpty) return false;
      return !infos.first.hasError;
    } catch (e) {
      return false;
    }
  }

  // ==================== HELPERS ====================

  void _checkError(Map<String, dynamic> data) {
    if (data['status'] == 'error' && data['error'] != null) {
      throw AllDebridException(
        code: data['error']['code'] ?? 'UNKNOWN',
        message: data['error']['message'] ?? 'Unknown error',
      );
    }
  }

  /// Utility methods
  static bool isMagnetUri(String s) {
    return s.toLowerCase().startsWith('magnet:?');
  }

  static bool isInfoHash(String s) {
    if (s.length != 40 && s.length != 32) return false;
    return RegExp(r'^[a-fA-F0-9]+$').hasMatch(s);
  }

  static String toMagnetUri(String hash) {
    return 'magnet:?xt=urn:btih:$hash';
  }

  static String? extractHashFromMagnet(String magnet) {
    final match = RegExp(r'btih:([a-zA-Z0-9]+)').firstMatch(magnet);
    return match?.group(1)?.toLowerCase();
  }
}

class AllDebridException implements Exception {
  final String code;
  final String message;

  AllDebridException({required this.code, required this.message});

  @override
  String toString() => '[$code] $message';
}
