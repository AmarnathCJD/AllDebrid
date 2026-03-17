import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

// Scroll-driven loading mixin for lazy loading
mixin ScrollDrivenLoading<T extends ConsumerStatefulWidget> on ConsumerState<T>, TickerProviderStateMixin<T> {
  ScrollController? get scrollController;
  Timer? _scrollDebounceTimer;
  bool _isLoadingMore = false;

  bool get isLoadingMore => _isLoadingMore;

  void initScrollListener({double threshold = 200}) {
    scrollController?.addListener(() => _onScroll(threshold: threshold));
  }

  void _onScroll({double threshold = 200}) {
    if (scrollController == null || !scrollController!.hasClients) return;
    if (_isLoadingMore) return;

    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (scrollController == null || !scrollController!.hasClients) return;

      final maxScroll = scrollController!.position.maxScrollExtent;
      final currentScroll = scrollController!.position.pixels;

      if (maxScroll - currentScroll <= threshold) {
        onLoadMore();
      }
    });
  }

  void onLoadMore();

  void disposeScrollListener() {
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = null;
  }
}

// Provider for tracking scroll position
final scrollPositionProvider = StateProvider<double>((ref) => 0);

// Provider for detecting if near bottom
final isNearBottomProvider = Provider.family<bool, ScrollController>((ref, controller) {
  if (!controller.hasClients) return false;
  final maxScroll = controller.position.maxScrollExtent;
  final currentScroll = controller.position.pixels;
  return maxScroll - currentScroll <= 200;
});

// Convenience provider for checking scroll direction (removed - ScrollDirection not defined)