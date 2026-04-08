import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'app_provider.dart';

/// Magnet State
class MagnetState {
  final List<MagnetStatus> magnets;
  final bool isLoading;
  final String? error;
  final Set<String> pendingDeletions;

  const MagnetState({
    this.magnets = const [],
    this.isLoading = false,
    this.error,
    this.pendingDeletions = const {},
  });

  List<MagnetStatus> get activeMagnets =>
      magnets.where((m) => !m.isReady && !m.isError).toList();

  List<MagnetStatus> get readyMagnets =>
      magnets.where((m) => m.isReady).toList();

  List<MagnetStatus> get errorMagnets =>
      magnets.where((m) => m.isError).toList();

  MagnetState copyWith({
    List<MagnetStatus>? magnets,
    bool? isLoading,
    String? error,
    Set<String>? pendingDeletions,
  }) {
    return MagnetState(
      magnets: magnets ?? this.magnets,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      pendingDeletions: pendingDeletions ?? this.pendingDeletions,
    );
  }
}

/// Magnet Notifier
class MagnetNotifier extends Notifier<MagnetState> {
  Timer? _refreshTimer;

  @override
  MagnetState build() {
    ref.onDispose(() {
      stopAutoRefresh();
    });
    return const MagnetState();
  }

  AllDebridService? get _service => ref.read(appNotifierProvider).allDebridService;

  /// Start auto refresh for active magnets
  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (state.activeMagnets.isNotEmpty) {
        unawaited(refreshMagnets(showLoading: false));
      }
    });
  }

  /// Stop auto refresh
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Fetch all magnets
  Future<void> fetchMagnets() async {
    if (_service == null) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final magnets = await _service!.getAllMagnets();
      magnets.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
      state = state.copyWith(magnets: magnets, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  /// Refresh magnets without showing loading
  Future<void> refreshMagnets({bool showLoading = true}) async {
    if (_service == null) return;

    if (showLoading) {
      state = state.copyWith(isLoading: true);
    }

    try {
      final freshMagnets = await _service!.getAllMagnets();
      // Filter out pending deletions
      final filtered = freshMagnets
          .where((m) => !state.pendingDeletions.contains(m.id.toString()))
          .toList();
      filtered.sort((a, b) => b.uploadDate.compareTo(a.uploadDate));
      state = state.copyWith(magnets: filtered, error: null);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      if (showLoading) {
        state = state.copyWith(isLoading: false);
      } else {
        // Still notify without isLoading flag
        state = MagnetState(
          magnets: state.magnets,
          isLoading: state.isLoading,
          error: state.error,
          pendingDeletions: state.pendingDeletions,
        );
      }
    }
  }

  /// Upload a magnet
  Future<MagnetUploadResult?> uploadMagnet(String magnet) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      if (_service != null) {
        try {
          final result = await _service!.uploadSingleMagnet(magnet);
          await refreshMagnets(showLoading: false);
          state = state.copyWith(isLoading: false);
          return result;
        } catch (e) {
          state = state.copyWith(error: e.toString(), isLoading: false);
        }
      } else {
        state = state.copyWith(
          error: "AllDebrid service not available",
          isLoading: false,
        );
      }

      return null;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  /// Get magnet files
  Future<List<MagnetFile>?> getMagnetFiles(String magnetId) async {
    if (_service == null) return null;

    try {
      return await _service!.getMagnetFiles(magnetId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Unlock a restricted link
  Future<String?> unlockLink(String link) async {
    if (_service == null) return null;

    try {
      final unlocked = await _service!.unlockLink(link);
      return unlocked.link;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Delete a magnet
  Future<bool> deleteMagnet(String magnetId) async {
    if (_service == null) return false;

    // Optimistic update
    final newPending = Set<String>.from(state.pendingDeletions);
    newPending.add(magnetId);
    final newMagnets = state.magnets
        .where((m) => m.id.toString() != magnetId)
        .toList();
    state = state.copyWith(magnets: newMagnets, pendingDeletions: newPending);

    try {
      await _service!.deleteMagnet(magnetId);
      // Keep in pending deletions briefly to ensure next refresh doesn't bring it back immediately
      unawaited(Future<void>.delayed(const Duration(seconds: 5), () {
        final updated = Set<String>.from(state.pendingDeletions);
        updated.remove(magnetId);
        state = state.copyWith(pendingDeletions: updated);
      }));
      return true;
    } catch (e) {
      final updated = Set<String>.from(state.pendingDeletions);
      updated.remove(magnetId);
      state = state.copyWith(error: e.toString(), pendingDeletions: updated);
      // Refresh to get it back if we removed it
      unawaited(refreshMagnets(showLoading: false));
      return false;
    }
  }

  /// Restart a magnet
  Future<bool> restartMagnet(String magnetId) async {
    if (_service == null) return false;

    try {
      await _service!.restartMagnet(magnetId);
      await refreshMagnets(showLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final magnetNotifierProvider = NotifierProvider<MagnetNotifier, MagnetState>(() {
  return MagnetNotifier();
});
