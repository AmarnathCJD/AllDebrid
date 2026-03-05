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
    );

    _downloads.add(download);
    _notifyListeners();

    // Start download with Dio
    _downloadFile(download);

    await _saveDownloads();
    return download;
  }

  Future<void> _downloadFile(Download download) async {
    download.status = DownloadStatus.downloading;
    _notifyListeners();

    final cancelToken = CancelToken();
    _cancelTokens[download.id] = cancelToken;

    final notificationId = download.hashCode % 100000;
    _notificationToDownloadId[notificationId] = download.id;

    DateTime lastUpdate = DateTime.now();
    int lastBytes = 0;

    try {
      // Show initial notification
      await _showDownloadNotification(
        notificationId,
        download.filename,
        0,
        download.totalSize,
        0,
      );

      await _dio.download(
        download.url,
        download.savePath,
        cancelToken: cancelToken,
        options: Options(
          headers: {'User-Agent': 'AllDebrid/1.0'},
        ),
        onReceiveProgress: (received, total) async {
          download.downloadedSize = received;
          if (total > 0 && download.totalSize == 0) {
            download.totalSize = total;
          }

          final now = DateTime.now();
          final elapsed = now.difference(lastUpdate).inMilliseconds;

          if (elapsed >= 500) {
            final bytesDiff = received - lastBytes;
            download.speed =
                (elapsed > 0) ? ((bytesDiff * 1000) ~/ elapsed) : 0;
            lastUpdate = now;
            lastBytes = received;

            // Update notification
            final progress =
                (total > 0) ? ((received * 100) / total).toInt() : 0;
            await _showDownloadNotification(
              notificationId,
              download.filename,
              received,
              total,
              progress,
            );

            _notifyListeners();
          }
        },
      );

      // Download completed
      download.status = DownloadStatus.completed;
      download.completedAt = DateTime.now();
      download.speed = 0;
      download.downloadedSize = download.totalSize;

      // Show completion notification
      await _showCompletedNotification(notificationId, download);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // Paused by user
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
    }

    _cancelTokens.remove(download.id);
    _notifyListeners();
    await _saveDownloads();
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
