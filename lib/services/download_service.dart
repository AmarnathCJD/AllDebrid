import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/download.dart';
import 'storage_service.dart';

/// Download Service - manages downloads using Dio
class DownloadService {
  final StorageService _storageService;
  final Dio _dio = Dio();
  final Uuid _uuid = const Uuid();

  final StreamController<List<Download>> _downloadsController =
      StreamController.broadcast();
  Stream<List<Download>> get downloads => _downloadsController.stream;

  List<Download> _downloads = [];
  List<Download> get currentDownloads => _downloads;

  final Map<String, CancelToken> _cancelTokens = {};

  DownloadService({required StorageService storageService})
      : _storageService = storageService;

  Future<void> initialize() async {
    _downloads = _storageService.getDownloads();
    _notifyListeners();
  }

  /// Start a new download
  Future<Download> startDownload({
    required String url,
    required String filename,
    int? totalSize,
    String? customDir,
  }) async {
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

    // Start download in background
    _downloadWithDio(download);

    await _saveDownloads();
    return download;
  }

  Future<void> _downloadWithDio(Download download) async {
    download.status = DownloadStatus.downloading;
    _notifyListeners();

    final cancelToken = CancelToken();
    _cancelTokens[download.id] = cancelToken;

    DateTime lastUpdate = DateTime.now();
    int lastBytes = 0;

    try {
      await _dio.download(
        download.url,
        download.savePath,
        cancelToken: cancelToken,
        options: Options(
          headers: {'User-Agent': 'AllDebridApp/1.0'},
        ),
        onReceiveProgress: (received, total) {
          download.downloadedSize = received;
          if (total > 0 && download.totalSize == 0) {
            download.totalSize = total;
          }

          final now = DateTime.now();
          final elapsed = now.difference(lastUpdate).inMilliseconds;
          if (elapsed >= 500) {
            final bytesDiff = received - lastBytes;
            download.speed = ((bytesDiff * 1000) ~/ elapsed);
            lastUpdate = now;
            lastBytes = received;
          }
          _notifyListeners();
        },
      );

      download.status = DownloadStatus.completed;
      download.completedAt = DateTime.now();
      download.speed = 0;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        // Don't change status, it was already set by pause/cancel
      } else {
        download.status = DownloadStatus.failed;
        download.error = e.message;
      }
    } catch (e) {
      download.status = DownloadStatus.failed;
      download.error = e.toString();
    }

    _cancelTokens.remove(download.id);
    _notifyListeners();
    await _saveDownloads();
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
    _notifyListeners();
    await _saveDownloads();
  }

  Future<void> resumeDownload(String downloadId) async {
    final idx = _downloads.indexWhere((d) => d.id == downloadId);
    if (idx == -1) return;

    final download = _downloads[idx];

    if (download.isPaused || download.isFailed) {
      download.status = DownloadStatus.downloading;
      _notifyListeners();

      final cancelToken = CancelToken();
      _cancelTokens[download.id] = cancelToken;

      DateTime lastUpdate = DateTime.now();
      int lastBytes = download.downloadedSize;

      try {
        final file = File(download.savePath);
        int startByte = 0;
        if (await file.exists()) {
          startByte = await file.length();
          download.downloadedSize = startByte;
        }

        await _dio.download(
          download.url,
          download.savePath,
          cancelToken: cancelToken,
          deleteOnError: false,
          options: Options(
            headers: {
              'User-Agent': 'AllDebridApp/1.0',
              if (startByte > 0) 'Range': 'bytes=$startByte-',
            },
          ),
          onReceiveProgress: (received, total) {
            download.downloadedSize = startByte + received;

            final now = DateTime.now();
            final elapsed = now.difference(lastUpdate).inMilliseconds;
            if (elapsed >= 500) {
              final bytesDiff = download.downloadedSize - lastBytes;
              download.speed = ((bytesDiff * 1000) ~/ elapsed);
              lastUpdate = now;
              lastBytes = download.downloadedSize;
            }
            _notifyListeners();
          },
        );

        download.status = DownloadStatus.completed;
        download.completedAt = DateTime.now();
        download.speed = 0;
      } on DioException catch (e) {
        if (e.type == DioExceptionType.cancel) {
          // Status already set
        } else {
          download.status = DownloadStatus.failed;
          download.error = e.message;
        }
      } catch (e) {
        download.status = DownloadStatus.failed;
        download.error = e.toString();
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

    final file = File(download.savePath);
    if (await file.exists()) {
      await file.delete();
    }

    download.status = DownloadStatus.cancelled;
    download.speed = 0;
    _notifyListeners();
    await _saveDownloads();
  }

  Future<void> removeDownload(String downloadId) async {
    await cancelDownload(downloadId);

    _downloads.removeWhere((d) => d.id == downloadId);
    _notifyListeners();
    await _saveDownloads();
  }

  Future<void> clearCompleted() async {
    _downloads.removeWhere((d) => d.isCompleted);
    _notifyListeners();
    await _saveDownloads();
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
      if (download.isPaused) {
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
