import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;

import 'providers.dart';

T _resolveProvider<T>(riverpod.ProviderContainer container) {
  if (T == AppProvider) {
    return container.read(appProviderProvider) as T;
  }
  if (T == NavigationProvider) {
    return container.read(navigationProviderProvider) as T;
  }
  if (T == MagnetProvider) {
    return container.read(magnetProviderProvider) as T;
  }
  if (T == LinkProvider) {
    return container.read(linkProviderProvider) as T;
  }
  if (T == DownloadProvider) {
    return container.read(downloadProviderProvider) as T;
  }
  if (T == TrendingProvider) {
    return container.read(trendingProviderProvider) as T;
  }
  if (T == KDramaProvider) {
    return container.read(kDramaProviderProvider) as T;
  }
  throw ArgumentError('No Riverpod mapping registered for type $T.');
}

extension RiverpodContextCompat on BuildContext {
  T read<T>() {
    final container = riverpod.ProviderScope.containerOf(this, listen: false);
    return _resolveProvider<T>(container);
  }

  T watch<T>() {
    final container = riverpod.ProviderScope.containerOf(this);
    return _resolveProvider<T>(container);
  }
}

class Provider {
  static T of<T>(BuildContext context, {bool listen = true}) {
    final container =
        riverpod.ProviderScope.containerOf(context, listen: listen);
    return _resolveProvider<T>(container);
  }
}

class Consumer<T> extends riverpod.ConsumerWidget {
  final Widget Function(BuildContext context, T value, Widget? child) builder;
  final Widget? child;

  const Consumer({super.key, required this.builder, this.child});

  @override
  Widget build(BuildContext context, riverpod.WidgetRef ref) {
    final value = _resolveProvider<T>(ref.container);
    return builder(context, value, child);
  }
}
