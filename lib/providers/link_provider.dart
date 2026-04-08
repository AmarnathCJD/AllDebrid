import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'app_provider.dart';

/// Link State
class LinkState {
  final List<UnlockedLink> unlockedLinks;
  final List<LinkInfo> linkInfos;
  final bool isLoading;
  final String? error;

  const LinkState({
    this.unlockedLinks = const [],
    this.linkInfos = const [],
    this.isLoading = false,
    this.error,
  });

  LinkState copyWith({
    List<UnlockedLink>? unlockedLinks,
    List<LinkInfo>? linkInfos,
    bool? isLoading,
    String? error,
  }) {
    return LinkState(
      unlockedLinks: unlockedLinks ?? this.unlockedLinks,
      linkInfos: linkInfos ?? this.linkInfos,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Link Notifier
class LinkNotifier extends Notifier<LinkState> {
  @override
  LinkState build() => const LinkState();

  AllDebridService? get _service => ref.read(appNotifierProvider).allDebridService;

  /// Get link info for multiple links
  Future<List<LinkInfo>?> getLinkInfo(List<String> links,
      {String? password}) async {
    if (_service == null) return null;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final infos = await _service!.getLinkInfo(links, password: password);
      state = state.copyWith(linkInfos: infos, isLoading: false);
      return infos;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  /// Unlock a link
  Future<UnlockedLink?> unlockLink(String link, {String? password}) async {
    if (_service == null) return null;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final unlocked = await _service!.unlockLink(link, password: password);
      final updated = [unlocked, ...state.unlockedLinks];
      // Keep only last 50 links
      final trimmed = updated.take(50).toList();
      state = state.copyWith(unlockedLinks: trimmed, isLoading: false);
      return unlocked;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  /// Get redirector links
  Future<List<String>?> getRedirectorLinks(String link) async {
    if (_service == null) return null;

    try {
      return await _service!.getRedirectorLinks(link);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Get streaming link
  Future<StreamingLink?> getStreamingLink(String id, String streamId) async {
    if (_service == null) return null;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final link = await _service!.getStreamingLink(id, streamId);
      state = state.copyWith(isLoading: false);
      return link;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  /// Wait for delayed link
  Future<String?> waitForDelayedLink(String delayedId) async {
    if (_service == null) return null;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final link = await _service!.waitForDelayedLink(delayedId);
      state = state.copyWith(isLoading: false);
      return link;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  Future<String?> createZip(List<String> links) async {
    if (_service == null) return null;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final zipId = await _service!.createZip(links);
      state = state.copyWith(isLoading: false);
      return zipId;
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
      return null;
    }
  }

  /// Check if link is supported
  Future<bool> isLinkSupported(String link) async {
    if (_service == null) return false;

    try {
      return await _service!.isLinkSupported(link);
    } catch (e) {
      return false;
    }
  }

  /// Clear unlocked links history
  void clearHistory() {
    state = state.copyWith(unlockedLinks: [], linkInfos: []);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

final linkNotifierProvider = NotifierProvider<LinkNotifier, LinkState>(() {
  return LinkNotifier();
});
