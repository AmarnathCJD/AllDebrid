/// Export all providers
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/download_service.dart';
import '../services/storage_service.dart';

import 'app_provider.dart';
import 'download_provider.dart';
import 'kdrama_provider.dart';
import 'link_provider.dart';
import 'magnet_provider.dart';
import 'navigation_provider.dart';
import 'trending_provider.dart';

export 'app_provider.dart';
export 'magnet_provider.dart';
export 'link_provider.dart';
export 'download_provider.dart';
export 'trending_provider.dart';
export 'kdrama_provider.dart';
export 'navigation_provider.dart';

Provider<T> _bridgeChangeNotifierProvider<T extends ChangeNotifier>(
  Provider<T> instanceProvider,
) {
  return Provider<T>((ref) {
    final notifier = ref.watch(instanceProvider);
    void listener() => ref.notifyListeners();
    notifier.addListener(listener);
    ref.onDispose(() => notifier.removeListener(listener));
    return notifier;
  });
}

final storageServiceProvider = Provider<StorageService>(
  (ref) =>
      throw UnimplementedError('storageServiceProvider must be overridden'),
);

final downloadServiceProvider = Provider<DownloadService>(
  (ref) =>
      throw UnimplementedError('downloadServiceProvider must be overridden'),
);

final _appProviderInstance = Provider<AppProvider>(
  (ref) => AppProvider(storageService: ref.watch(storageServiceProvider)),
);

final appProviderProvider =
    _bridgeChangeNotifierProvider<AppProvider>(_appProviderInstance);

final _navigationProviderInstance = Provider<NavigationProvider>(
  (ref) => NavigationProvider(),
);

final navigationProviderProvider =
    _bridgeChangeNotifierProvider<NavigationProvider>(
  _navigationProviderInstance,
);

final _magnetProviderInstance = Provider<MagnetProvider>(
  (ref) => MagnetProvider(
    getService: () => ref.read(appProviderProvider).allDebridService,
  ),
);

final magnetProviderProvider =
    _bridgeChangeNotifierProvider<MagnetProvider>(_magnetProviderInstance);

final _linkProviderInstance = Provider<LinkProvider>(
  (ref) => LinkProvider(
    getService: () => ref.read(appProviderProvider).allDebridService,
  ),
);

final linkProviderProvider =
    _bridgeChangeNotifierProvider<LinkProvider>(_linkProviderInstance);

final _downloadProviderInstance = Provider<DownloadProvider>(
  (ref) =>
      DownloadProvider(downloadService: ref.watch(downloadServiceProvider)),
);

final downloadProviderProvider =
    _bridgeChangeNotifierProvider<DownloadProvider>(_downloadProviderInstance);

final _trendingProviderInstance = Provider<TrendingProvider>(
  (ref) => TrendingProvider(),
);

final trendingProviderProvider =
    _bridgeChangeNotifierProvider<TrendingProvider>(_trendingProviderInstance);

final _kDramaProviderInstance = Provider<KDramaProvider>(
  (ref) => KDramaProvider(),
);

final kDramaProviderProvider =
    _bridgeChangeNotifierProvider<KDramaProvider>(_kDramaProviderInstance);
