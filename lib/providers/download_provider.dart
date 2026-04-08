import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/download.dart';
import '../services/download_service.dart';

/// Download State
class DownloadState {
  final List<Download> downloads;
  final bool isInitialized;

  const DownloadState({
    this.downloads = const [],
    this.isInitialized = false,
  });

  List<Download> get activeDownloads =>
      downloads.where((d) => d.isDownloading).toList();

  List<Download> get pausedDownloads =>
      downloads.where((d) => d.isPaused).toList();

  List<Download> get completedDownloads =>
      downloads.where((d) => d.isCompleted).toList();

  List<Download> get failedDownloads =>
      downloads.where((d) => d.isFailed).toList();

  int get totalSpeed => activeDownloads.fold(0, (sum, d) => sum + d.speed);

  DownloadState copyWith({
    List<Download>? downloads,
    bool? isInitialized,
  }) {
    return DownloadState(
      downloads: downloads ?? this.downloads,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

/// Download Notifier
class DownloadNotifier extends Notifier<DownloadState> {
  late final DownloadService _downloadService;
  StreamSubscription<List<Download>>? _subscription;

  @override
  DownloadState build() {
    _downloadService = ref.watch(downloadServiceProvider);

    ref.onDispose(() {
      unawaited(_subscription?.cancel());
      _downloadService.dispose();
    });

    return const DownloadState();
  }

  /// Initialize download service
  Future<void> initialize() async {
    if (state.isInitialized) return;

    await _downloadService.initialize();
    final downloads = _downloadService.currentDownloads;

    // Listen to download updates
    _subscription = _downloadService.downloads.listen((downloads) {
      state = state.copyWith(downloads: downloads);
    });

    state = state.copyWith(downloads: downloads, isInitialized: true);
  }

  /// Start a new download
  Future<Download?> startDownload({
    required String url,
    required String filename,
    int? totalSize,
    Map<String, String>? headers,
  }) async {
    try {
      final download = await _downloadService.startDownload(
        url: url,
        filename: filename,
        totalSize: totalSize,
        headers: headers,
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

  Future<void> removeAll() async {
    await _downloadService.removeAll();
  }
}

final downloadServiceProvider = Provider<DownloadService>(
  (ref) => throw UnimplementedError(
    'downloadServiceProvider must be overridden',
  ),
);

final downloadNotifierProvider = NotifierProvider<DownloadNotifier, DownloadState>(() {
  return DownloadNotifier();
});
