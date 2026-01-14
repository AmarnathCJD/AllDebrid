import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/download.dart';
import '../services/download_service.dart';

/// Download Provider - State management for downloads
class DownloadProvider extends ChangeNotifier {
  final DownloadService _downloadService;

  List<Download> _downloads = [];
  bool _isInitialized = false;
  StreamSubscription<List<Download>>? _subscription;

  DownloadProvider({required DownloadService downloadService})
    : _downloadService = downloadService;

  // Getters
  List<Download> get downloads => _downloads;
  bool get isInitialized => _isInitialized;

  List<Download> get activeDownloads =>
      _downloads.where((d) => d.isDownloading).toList();

  List<Download> get pausedDownloads =>
      _downloads.where((d) => d.isPaused).toList();

  List<Download> get completedDownloads =>
      _downloads.where((d) => d.isCompleted).toList();

  List<Download> get failedDownloads =>
      _downloads.where((d) => d.isFailed).toList();

  int get totalSpeed => activeDownloads.fold(0, (sum, d) => sum + d.speed);

  /// Initialize download service
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _downloadService.initialize();
    _downloads = _downloadService.currentDownloads;

    // Listen to download updates
    _subscription = _downloadService.downloads.listen((downloads) {
      _downloads = downloads;
      notifyListeners();
    });

    _isInitialized = true;
    notifyListeners();
  }

  /// Start a new download
  Future<Download?> startDownload({
    required String url,
    required String filename,
    int? totalSize,
  }) async {
    try {
      final download = await _downloadService.startDownload(
        url: url,
        filename: filename,
        totalSize: totalSize,
      );
      return download;
    } catch (e) {
      return null;
    }
  }

  /// Pause a download
  Future<void> pauseDownload(String downloadId) async {
    await _downloadService.pauseDownload(downloadId);
  }

  /// Resume a download
  Future<void> resumeDownload(String downloadId) async {
    await _downloadService.resumeDownload(downloadId);
  }

  /// Cancel a download
  Future<void> cancelDownload(String downloadId) async {
    await _downloadService.cancelDownload(downloadId);
  }

  /// Remove a download
  Future<void> removeDownload(String downloadId) async {
    await _downloadService.removeDownload(downloadId);
  }

  /// Clear completed downloads
  Future<void> clearCompleted() async {
    await _downloadService.clearCompleted();
  }

  /// Pause all downloads
  Future<void> pauseAll() async {
    await _downloadService.pauseAll();
  }

  /// Resume all downloads
  Future<void> resumeAll() async {
    await _downloadService.resumeAll();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _downloadService.dispose();
    super.dispose();
  }
}
