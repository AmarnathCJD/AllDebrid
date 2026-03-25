import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import '../models/download.dart';
import 'storage_service.dart';

/// Download Service - manages downloads with Dio and custom notifications
class DownloadService {
  final StorageService _storageService;
  final Dio _dio = Dio();
  final Uuid _uuid = const Uuid();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  final StreamController<List<Download>> _downloadsController =
      StreamController.broadcast();
  Stream<List<Download>> get downloads => _downloadsController.stream;

  List<Download> _downloads = [];
  List<Download> get currentDownloads => _downloads;

  final Map<String, CancelToken> _cancelTokens = {};
  final Map<int, String> _notificationToDownloadId = {};

  DownloadService({required StorageService storageService})
      : _storageService = storageService;

  Future<void> initialize() async {
    _downloads = _storageService.getDownloads();

    // Initialize notifications
    await _initializeNotifications();

    // Auto-resume interrupted downloads
    for (final download in _downloads) {
      if (download.status == DownloadStatus.downloading) {
        download.status = DownloadStatus.paused;
      }
    }

    _notifyListeners();
    await _saveDownloads();
  }

  Future<void> _initializeNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(settings: initSettings);
    await Permission.notification.request();
  }

  /// Start a new download
  Future<Download> startDownload({
    required String url,
    required String filename,
    int? totalSize,
    String? customDir,
    Map<String, String>? headers,
  }) async {
    await Permission.notification.request();

    final downloadDir = customDir ?? await _getDownloadDirectory();
    final savePath = '$downloadDir/$filename';

    final download = Download(
      id: _uuid.v4(),
      url: url,
      filename: filename,
      savePath: savePath,
      totalSize: totalSize ?? 0,
      status: DownloadStatus.pending,
      createdAt: DateTime.now(),
      headers: headers,
    );

    _downloads.add(download);
    _notifyListeners();

    // Start download with Dio
    _downloadFile(download);

    await _saveDownloads();
    return download;
  }

  static const int _parallelChunks = 8;
  static const int _minSizeForParallel = 4 * 1024 * 1024; // 4 MB
  static const int _hlsConcurrency = 16; // parallel TS segment downloads

  // Each chunk gets its own Dio so they use separate TCP connections
  static Dio _makeDio(Map<String, String>? extraHeaders) => Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'User-Agent': 'AllDebrid/1.0',
          ...?extraHeaders,
        },
      ));

  Future<void> _downloadFile(Download download) async {
    download.status = DownloadStatus.downloading;
    _notifyListeners();

    final masterCancelToken = CancelToken();
    _cancelTokens[download.id] = masterCancelToken;

    final notificationId = download.hashCode % 100000;
    _notificationToDownloadId[notificationId] = download.id;

    await _showDownloadNotification(
      notificationId, download.filename, 0, download.totalSize, 0,
    );

    try {
      final url = download.url.trim();

      // HLS / M3U8
      if (_isHls(url)) {
        final tsSavePath = download.savePath.endsWith('.ts')
            ? download.savePath
            : '${download.savePath.replaceAll(RegExp(r'\.\w+$'), '')}.ts';
        await _downloadHls(download, url, tsSavePath, masterCancelToken, notificationId);
        download.savePath = tsSavePath;
      } else {
        // Direct file: probe for size + range support
        int fileSize = download.totalSize;
        bool supportsRange = false;

        try {
          final probe = _makeDio(null);
          final head = await probe.head(
            url,
            options: Options(validateStatus: (s) => s != null && s < 400),
          );
          final cl = head.headers.value('content-length');
          if (cl != null) fileSize = int.tryParse(cl) ?? fileSize;
          final ar = head.headers.value('accept-ranges');
          supportsRange = ar != null && ar != 'none';
        } catch (_) {}

        if (fileSize > 0) download.totalSize = fileSize;

        if (supportsRange && fileSize >= _minSizeForParallel) {
          await _downloadParallel(download, fileSize, masterCancelToken, notificationId);
        } else {
          await _downloadSingle(download, masterCancelToken, notificationId);
        }
      }

      download.status = DownloadStatus.completed;
      download.completedAt = DateTime.now();
      download.speed = 0;
      download.downloadedSize = download.totalSize;
      await _showCompletedNotification(notificationId, download);
    } on DioException catch (e) {
      if (e.type != DioExceptionType.cancel) {
        download.status = DownloadStatus.failed;
        download.error = e.message ?? 'Download failed';
        await _showFailedNotification(notificationId, download);
        await _saveDownloads();
      }
    } catch (e) {
      download.status = DownloadStatus.failed;
      download.error = e.toString();
      await _showFailedNotification(notificationId, download);
      await _saveDownloads();
    }

    _cancelTokens.remove(download.id);
    _notifyListeners();
    await _saveDownloads();
  }

  bool _isHls(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.m3u8') || lower.endsWith('.m3u');
  }

  // ─── HLS / M3U8 downloader ────────────────────────────────────────────────

  Future<void> _downloadHls(
    Download download,
    String playlistUrl,
    String savePath,
    CancelToken masterCancelToken,
    int notificationId,
  ) async {
    final headers = download.headers;
    final dio = _makeDio(headers);

    // 1. Fetch master / media playlist
    final playlistResp = await dio.get(
      playlistUrl,
      options: Options(responseType: ResponseType.plain),
    );
    final playlistText = playlistResp.data as String;

    // 2. If master playlist → pick highest bandwidth variant
    String mediaPlaylistUrl = playlistUrl;
    if (playlistText.contains('#EXT-X-STREAM-INF')) {
      mediaPlaylistUrl = _pickBestVariant(playlistText, playlistUrl);
      final mediaResp = await dio.get(
        mediaPlaylistUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final segments = _parseSegments(mediaResp.data as String, mediaPlaylistUrl);
      await _downloadSegments(download, segments, headers, savePath, masterCancelToken, notificationId);
    } else {
      final segments = _parseSegments(playlistText, playlistUrl);
      await _downloadSegments(download, segments, headers, savePath, masterCancelToken, notificationId);
    }
  }

  String _pickBestVariant(String master, String baseUrl) {
    final lines = master.split('\n');
    int bestBw = -1;
    String bestUri = '';
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXT-X-STREAM-INF')) {
        final bwMatch = RegExp(r'BANDWIDTH=(\d+)').firstMatch(line);
        final bw = int.tryParse(bwMatch?.group(1) ?? '') ?? 0;
        if (bw > bestBw && i + 1 < lines.length) {
          final uri = lines[i + 1].trim();
          if (uri.isNotEmpty && !uri.startsWith('#')) {
            bestBw = bw;
            bestUri = uri;
          }
        }
      }
    }
    if (bestUri.isEmpty) return baseUrl;
    return _resolveUrl(bestUri, baseUrl);
  }

  List<String> _parseSegments(String playlist, String baseUrl) {
    final segments = <String>[];
    for (final line in playlist.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      segments.add(_resolveUrl(trimmed, baseUrl));
    }
    return segments;
  }

  String _resolveUrl(String uri, String base) {
    if (uri.startsWith('http://') || uri.startsWith('https://')) return uri;
    final baseUri = Uri.parse(base);
    if (uri.startsWith('/')) {
      return '${baseUri.scheme}://${baseUri.host}$uri';
    }
    final pathParts = baseUri.path.split('/')..removeLast();
    return '${baseUri.scheme}://${baseUri.host}${pathParts.join('/')}/$uri';
  }

  Future<void> _downloadSegments(
    Download download,
    List<String> segments,
    Map<String, String>? headers,
    String savePath,
    CancelToken masterCancelToken,
    int notificationId,
  ) async {
    final total = segments.length;
    download.totalSize = total; // treat segment count as "total" for progress
    final tmpDir = Directory('$savePath.segs');
    await tmpDir.create(recursive: true);

    final downloaded = List<int>.filled(total, 0); // 0=pending,1=done
    int completedCount = 0;
    DateTime lastUpdate = DateTime.now();
    int lastCount = 0;

    // Semaphore: max _hlsConcurrency at once
    int running = 0;
    int nextIdx = 0;
    final completer = Completer<void>();
    Object? firstError;

    void scheduleNext() {
      while (running < _hlsConcurrency && nextIdx < total) {
        if (masterCancelToken.isCancelled) break;
        final i = nextIdx++;
        running++;
        final segDio = _makeDio(headers);
        final ct = CancelToken();
        masterCancelToken.whenCancel.then((_) { if (!ct.isCancelled) ct.cancel(); });

        segDio.download(
          segments[i],
          '${tmpDir.path}/seg_${i.toString().padLeft(6, '0')}',
          cancelToken: ct,
          options: Options(headers: headers),
        ).then((_) {
          downloaded[i] = 1;
          completedCount++;
          running--;

          final now = DateTime.now();
          final elapsed = now.difference(lastUpdate).inMilliseconds;
          if (elapsed >= 500) {
            final diff = completedCount - lastCount;
            download.speed = (elapsed > 0) ? ((diff * 1000) ~/ elapsed) : 0;
            lastUpdate = now;
            lastCount = completedCount;
            download.downloadedSize = completedCount;
            final pct = ((completedCount * 100) / total).toInt();
            _showDownloadNotification(notificationId, download.filename, completedCount, total, pct);
            _notifyListeners();
          }

          if (completedCount == total) {
            completer.complete();
          } else {
            scheduleNext();
          }
        }).catchError((e) {
          running--;
          firstError ??= e;
          // cancel remaining
          if (!masterCancelToken.isCancelled) masterCancelToken.cancel('Segment error');
          if (!completer.isCompleted) completer.completeError(e);
        });
      }

      if (running == 0 && nextIdx >= total && !completer.isCompleted) {
        if (firstError != null) {
          completer.completeError(firstError!);
        } else {
          completer.complete();
        }
      }
    }

    try {
      scheduleNext();
      await completer.future;

      // Concatenate all segments in order
      final outFile = File(savePath);
      final sink = outFile.openWrite();
      for (int i = 0; i < total; i++) {
        final seg = File('${tmpDir.path}/seg_${i.toString().padLeft(6, '0')}');
        if (await seg.exists()) await sink.addStream(seg.openRead());
      }
      await sink.flush();
      await sink.close();

      download.totalSize = await outFile.length();
      download.downloadedSize = download.totalSize;
    } finally {
      try { if (await tmpDir.exists()) await tmpDir.delete(recursive: true); } catch (_) {}
    }
  }

  // ─── Parallel chunked direct download ─────────────────────────────────────

  Future<void> _downloadParallel(
    Download download,
    int fileSize,
    CancelToken masterCancelToken,
    int notificationId,
  ) async {
    final numChunks = _parallelChunks;
    final chunkSize = (fileSize / numChunks).ceil();
    final tmpDir = Directory('${download.savePath}.parts');
    await tmpDir.create(recursive: true);

    final chunkDownloaded = List<int>.filled(numChunks, 0);
    DateTime lastUpdate = DateTime.now();
    int lastBytes = 0;

    void onProgress() {
      final total = chunkDownloaded.fold(0, (a, b) => a + b);
      download.downloadedSize = total;
      final now = DateTime.now();
      final elapsed = now.difference(lastUpdate).inMilliseconds;
      if (elapsed >= 400) {
        final bytesDiff = total - lastBytes;
        download.speed = (elapsed > 0) ? ((bytesDiff * 1000) ~/ elapsed) : 0;
        lastUpdate = now;
        lastBytes = total;
        final progress = ((total * 100) / fileSize).toInt();
        _showDownloadNotification(notificationId, download.filename, total, fileSize, progress);
        _notifyListeners();
      }
    }

    try {
      // Each chunk gets its OWN Dio instance → own TCP connection
      final chunkFutures = List.generate(numChunks, (i) {
        final start = i * chunkSize;
        final end = (i == numChunks - 1) ? fileSize - 1 : start + chunkSize - 1;
        final partPath = '${tmpDir.path}/part_$i';
        final ct = CancelToken();
        masterCancelToken.whenCancel.then((_) { if (!ct.isCancelled) ct.cancel(); });

        final chunkDio = _makeDio(null); // separate TCP connection per chunk
        return chunkDio.download(
          download.url,
          partPath,
          cancelToken: ct,
          options: Options(headers: {'Range': 'bytes=$start-$end'}),
          onReceiveProgress: (received, _) {
            chunkDownloaded[i] = received;
            onProgress();
          },
        );
      });

      await Future.wait(chunkFutures);

      // Merge in order
      final outFile = File(download.savePath);
      final sink = outFile.openWrite();
      for (int i = 0; i < numChunks; i++) {
        await sink.addStream(File('${tmpDir.path}/part_$i').openRead());
      }
      await sink.flush();
      await sink.close();
    } finally {
      try { if (await tmpDir.exists()) await tmpDir.delete(recursive: true); } catch (_) {}
    }
  }

  Future<void> _downloadSingle(
    Download download,
    CancelToken cancelToken,
    int notificationId,
  ) async {
    DateTime lastUpdate = DateTime.now();
    int lastBytes = 0;

    await _makeDio(null).download(
      download.url,
      download.savePath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) async {
        download.downloadedSize = received;
        if (total > 0 && download.totalSize == 0) download.totalSize = total;

        final now = DateTime.now();
        final elapsed = now.difference(lastUpdate).inMilliseconds;
        if (elapsed >= 400) {
          final bytesDiff = received - lastBytes;
          download.speed = (elapsed > 0) ? ((bytesDiff * 1000) ~/ elapsed) : 0;
          lastUpdate = now;
          lastBytes = received;
          final progress = (total > 0) ? ((received * 100) / total).toInt() : 0;
          await _showDownloadNotification(notificationId, download.filename, received, total, progress);
          _notifyListeners();
        }
      },
    );
  }

  Future<void> _showDownloadNotification(
    int id,
    String filename,
    int downloaded,
    int total,
    int progress,
  ) async {
    final downloadedMB = (downloaded / (1024 * 1024)).toStringAsFixed(1);
    final totalMB =
        (total > 0) ? (total / (1024 * 1024)).toStringAsFixed(1) : '?';

    final androidDetails = AndroidNotificationDetails(
      'downloads',
      'Downloads',
      channelDescription: 'Download progress notifications',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      styleInformation: BigTextStyleInformation(
        '$downloadedMB MB / $totalMB MB',
        contentTitle: filename,
        summaryText: '$progress%',
      ),
    );

    await _notifications.show(
      id: id,
      title: filename,
      body: '$progress% • $downloadedMB MB / $totalMB MB',
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  }

  Future<void> _showCompletedNotification(int id, Download download) async {
    final sizeMB = (download.totalSize / (1024 * 1024)).toStringAsFixed(1);

    final androidDetails = AndroidNotificationDetails(
      'downloads',
      'Downloads',
      channelDescription: 'Download progress notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      styleInformation: BigTextStyleInformation(
        'Tap to open',
        contentTitle: '✓ ${download.filename}',
        summaryText: '$sizeMB MB',
      ),
    );

    await _notifications.show(
      id: id,
      title: '✓ Download completed',
      body: download.filename,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: download.id,
    );
  }

  Future<void> _showFailedNotification(int id, Download download) async {
    final androidDetails = AndroidNotificationDetails(
      'downloads',
      'Downloads',
      channelDescription: 'Download progress notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      styleInformation: BigTextStyleInformation(
        download.error ?? 'Unknown error',
        contentTitle: '✗ ${download.filename}',
      ),
    );

    await _notifications.show(
      id: id,
      title: '✗ Download failed',
      body: download.filename,
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  }

  Future<void> pauseDownload(String downloadId) async {
    final idx = _downloads.indexWhere((d) => d.id == downloadId);
    if (idx == -1) return;

    final download = _downloads[idx];
    final cancelToken = _cancelTokens[downloadId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Paused by user');
    }

    download.status = DownloadStatus.paused;
    download.speed = 0;

    // Cancel notification
    final notificationId = download.hashCode % 100000;
    await _notifications.cancel(id: notificationId);

    _notifyListeners();
    await _saveDownloads();
  }

  Future<void> resumeDownload(String downloadId) async {
    final idx = _downloads.indexWhere((d) => d.id == downloadId);
    if (idx == -1) return;

    final download = _downloads[idx];

    if (download.isPaused ||
        download.isFailed ||
        download.status == DownloadStatus.cancelled) {
      download.status = DownloadStatus.downloading;
      _notifyListeners();

      final cancelToken = CancelToken();
      _cancelTokens[download.id] = cancelToken;

      final notificationId = download.hashCode % 100000;
      _notificationToDownloadId[notificationId] = download.id;

      DateTime lastUpdate = DateTime.now();
      int lastBytes = download.downloadedSize;

      try {
        final file = File(download.savePath);
        int startByte = 0;
        if (await file.exists()) {
          startByte = await file.length();
          download.downloadedSize = startByte;
        } else {
          download.downloadedSize = 0;
        }

        if (download.totalSize > 0 && startByte >= download.totalSize) {
          download.status = DownloadStatus.completed;
          download.downloadedSize = download.totalSize;
          download.completedAt = DateTime.now();
          download.speed = 0;
          await _showCompletedNotification(notificationId, download);
          _notifyListeners();
          await _saveDownloads();
          return;
        }

        // Show initial notification
        final progress = (download.totalSize > 0)
            ? ((startByte * 100) / download.totalSize).toInt()
            : 0;
        await _showDownloadNotification(
          notificationId,
          download.filename,
          startByte,
          download.totalSize,
          progress,
        );

        // Resume download with Range header
        final response = await _dio.get<ResponseBody>(
          download.url,
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            headers: {
              'User-Agent': 'AllDebrid/1.0',
              if (startByte > 0) 'Range': 'bytes=$startByte-',
            },
          ),
        );

        final sink = file.openWrite(mode: FileMode.append);
        final stream = response.data!.stream;

        await stream.listen(
          (chunk) async {
            sink.add(chunk);

            final received = chunk.length;
            download.downloadedSize += received;

            // Update total size from Content-Length header
            if (download.totalSize == 0) {
              final contentLength = response.headers.value('content-length');
              if (contentLength != null) {
                final partial = int.tryParse(contentLength) ?? 0;
                if (partial > 0) {
                  download.totalSize = startByte + partial;
                }
              }
            }

            final now = DateTime.now();
            final elapsed = now.difference(lastUpdate).inMilliseconds;
            if (elapsed >= 500) {
              final bytesDiff = download.downloadedSize - lastBytes;
              if (elapsed > 0) {
                download.speed = ((bytesDiff * 1000) ~/ elapsed);
              }
              lastUpdate = now;
              lastBytes = download.downloadedSize;

              // Update notification
              final currentProgress = (download.totalSize > 0)
                  ? ((download.downloadedSize * 100) / download.totalSize)
                      .toInt()
                  : 0;
              await _showDownloadNotification(
                notificationId,
                download.filename,
                download.downloadedSize,
                download.totalSize,
                currentProgress,
              );

              _notifyListeners();
            }
          },
          onDone: () async {
            await sink.flush();
            await sink.close();
          },
          onError: (e) async {
            await sink.close();
            throw e;
          },
          cancelOnError: true,
        ).asFuture();

        download.status = DownloadStatus.completed;
        download.completedAt = DateTime.now();
        download.speed = 0;
        await _showCompletedNotification(notificationId, download);
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          // Status already set
        } else {
          download.status = DownloadStatus.failed;
          download.error = e.message ?? 'Download failed';
          await _showFailedNotification(notificationId, download);
          await _saveDownloads();
        }
      } catch (e) {
        download.status = DownloadStatus.failed;
        download.error = e.toString();
        await _showFailedNotification(notificationId, download);
        await _saveDownloads();
      } finally {
        // Ensure sink is always closed if it was opened
        try {
          // We can't easily access sink here as it's local to the try block
          // But sink.close() is called in onDone/onError of stream listen.
          // This finally block runs after the async gap of stream.listen(...).asFuture()
        } catch (_) {}
      }

      _cancelTokens.remove(download.id);
      _notifyListeners();
      await _saveDownloads();
    }
  }

  Future<void> cancelDownload(String downloadId) async {
    final idx = _downloads.indexWhere((d) => d.id == downloadId);
    if (idx == -1) return;

    final download = _downloads[idx];

    final cancelToken = _cancelTokens[downloadId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Cancelled by user');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    await _deleteFile(download.savePath);

    download.status = DownloadStatus.cancelled;
    download.downloadedSize = 0;
    download.speed = 0;

    final notificationId = download.hashCode % 100000;
    await _notifications.cancel(id: notificationId);

    _notifyListeners();
    await _saveDownloads();
  }

  Future<void> removeDownload(String downloadId) async {
    final idx = _downloads.indexWhere((d) => d.id == downloadId);
    if (idx == -1) return;

    final download = _downloads[idx];

    _downloads.removeAt(idx);
    _notifyListeners();
    _saveDownloads();

    _cleanupDownload(download);
  }

  Future<void> _cleanupDownload(Download download) async {
    final cancelToken = _cancelTokens[download.id];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Removed by user');
    }
    _cancelTokens.remove(download.id);

    final notificationId = download.hashCode % 100000;
    await _notifications.cancel(id: notificationId);

    await _deleteFile(download.savePath);
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        int retries = 3;
        while (retries > 0) {
          try {
            await file.delete();
            break;
          } catch (e) {
            retries--;
            if (retries == 0) debugPrint("Failed to delete file: $e");
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }
    } catch (_) {}
  }

  Future<void> clearCompleted() async {
    _downloads.removeWhere((d) => d.isCompleted);
    _notifyListeners();
    await _saveDownloads();
  }

  Future<void> removeAll() async {
    final List<Download> allDownloads = List.from(_downloads);
    for (final download in allDownloads) {
      await removeDownload(download.id);
    }
  }

  Future<void> pauseAll() async {
    for (final download in _downloads) {
      if (download.isDownloading) {
        await pauseDownload(download.id);
      }
    }
  }

  Future<void> resumeAll() async {
    for (final download in _downloads) {
      if (download.isPaused || download.isFailed) {
        await resumeDownload(download.id);
      }
    }
  }

  Future<String> _getDownloadDirectory() async {
    final customPath = _storageService.getSetting<String>('download_path');
    if (customPath != null && customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (!await dir.exists()) {
        try {
          await dir.create(recursive: true);
        } catch (_) {}
      }
      if (await dir.exists()) return customPath;
    }

    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        final downloadDir = Directory('${dir.path}/AllDebrid/Downloads');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        return downloadDir.path;
      }
    }

    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${appDir.path}/Downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  void _notifyListeners() {
    _downloadsController.add(List.from(_downloads));
  }

  Future<void> _saveDownloads() async {
    await _storageService.saveDownloads(_downloads);
  }

  void dispose() {
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) {
        token.cancel('Service disposed');
      }
    }
    _downloadsController.close();
  }
}
