import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/kdrama_service.dart';

export '../services/kdrama_service.dart' show KDramaItem;

/// KDrama State
class KDramaState {
  final List<KDramaItem> topDramas;
  final List<KDramaItem> latestDramas;
  final List<KDramaItem> topAiringDramas;
  final bool isTopLoading;
  final bool isLatestLoading;
  final bool isTopAiringLoading;

  const KDramaState({
    this.topDramas = const [],
    this.latestDramas = const [],
    this.topAiringDramas = const [],
    this.isTopLoading = false,
    this.isLatestLoading = false,
    this.isTopAiringLoading = false,
  });

  bool get isLoading => isTopLoading || isLatestLoading || isTopAiringLoading;

  KDramaState copyWith({
    List<KDramaItem>? topDramas,
    List<KDramaItem>? latestDramas,
    List<KDramaItem>? topAiringDramas,
    bool? isTopLoading,
    bool? isLatestLoading,
    bool? isTopAiringLoading,
  }) {
    return KDramaState(
      topDramas: topDramas ?? this.topDramas,
      latestDramas: latestDramas ?? this.latestDramas,
      topAiringDramas: topAiringDramas ?? this.topAiringDramas,
      isTopLoading: isTopLoading ?? this.isTopLoading,
      isLatestLoading: isLatestLoading ?? this.isLatestLoading,
      isTopAiringLoading: isTopAiringLoading ?? this.isTopAiringLoading,
    );
  }
}

/// KDrama Notifier
class KDramaNotifier extends Notifier<KDramaState> {
  final _dramaService = KDramaService();

  @override
  KDramaState build() => const KDramaState();

  Future<void> loadTopDramas() async {
    final cachedDramas = await _dramaService
        .getCachedDramas('${KDramaService.baseUrl}/shows/top');
    if (cachedDramas.isNotEmpty) {
      state = state.copyWith(topDramas: cachedDramas);
    } else {
      state = state.copyWith(isTopLoading: true);
    }

    try {
      final dramas = await _dramaService.fetchTopDramas();
      state = state.copyWith(topDramas: dramas, isTopLoading: false);
    } catch (e) {
      debugPrint('[KDRAMA PROVIDER] Error loading top dramas: $e');
      state = state.copyWith(isTopLoading: false);
    }
  }

  Future<void> loadLatestDramas() async {
    // 1. Try cache first
    final cachedDramas = await _dramaService
        .getCachedDramas('${KDramaService.baseUrl}/shows/newest');
    if (cachedDramas.isNotEmpty) {
      state = state.copyWith(latestDramas: cachedDramas);
    } else {
      state = state.copyWith(isLatestLoading: true);
    }

    // 2. Load fresh
    try {
      final dramas = await _dramaService.fetchLatestDramas();
      state = state.copyWith(latestDramas: dramas, isLatestLoading: false);
    } catch (e) {
      debugPrint('[KDRAMA PROVIDER] Error loading latest dramas: $e');
      state = state.copyWith(isLatestLoading: false);
    }
  }

  Future<void> loadTopAiringDramas() async {
    // 1. Try cache first
    final cachedDramas = await _dramaService
        .getCachedDramas('${KDramaService.baseUrl}/shows/top_airing');
    if (cachedDramas.isNotEmpty) {
      state = state.copyWith(topAiringDramas: cachedDramas);
    } else {
      state = state.copyWith(isTopAiringLoading: true);
    }

    // 2. Load fresh
    try {
      final dramas = await _dramaService.fetchTopAiringDramas();
      state = state.copyWith(topAiringDramas: dramas, isTopAiringLoading: false);
    } catch (e) {
      debugPrint('[KDRAMA PROVIDER] Error loading top airing dramas: $e');
      state = state.copyWith(isTopAiringLoading: false);
    }
  }
}

final kDramaNotifierProvider = NotifierProvider<KDramaNotifier, KDramaState>(() {
  return KDramaNotifier();
});
