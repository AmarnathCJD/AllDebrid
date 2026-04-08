import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

import 'providers/providers.dart';
import 'services/services.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/home/media_info_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surfaceColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storageService = StorageService();
  await Future.wait([
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
    storageService.init(),
  ]);

  final notificationService = NotificationService();
  unawaited(notificationService.init());

  final downloadService = DownloadService(storageService: storageService);

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
        downloadServiceProvider.overrideWithValue(downloadService),
      ],
      child: const AllDebridApp(),
    ),
  );
}

class AllDebridApp extends ConsumerWidget {
  const AllDebridApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appNotifierProvider);
    return MaterialApp(
      title: 'AllDebrid',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.createTheme(appState.primaryColor,
          isDark: appState.isDarkMode),
      navigatorObservers: [appState.routeObserver],
      home: const AppWrapper(),
    );
  }
}

class AppWrapper extends ConsumerStatefulWidget {
  const AppWrapper({super.key});

  @override
  ConsumerState<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends ConsumerState<AppWrapper> {
  bool _isInitializing = true;
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _appLinksSubscription;

  @override
  void initState() {
    super.initState();
    final appState = ref.read(appNotifierProvider);
    final appNotifier = ref.read(appNotifierProvider.notifier);
    final hasLaunchedBefore = appState.hasApiKey ||
        (appNotifier.getSetting<bool>('has_launched') ?? false);
    if (hasLaunchedBefore) {
      _isInitializing = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_initializeApp(showSplash: false));
      });
    } else {
      unawaited(Future<void>.microtask(() => _initializeApp(showSplash: true)));
    }
    _initDeepLinks();
  }

  void _initDeepLinks() {
    // Handle link when app is already running
    _appLinksSubscription = _appLinks.uriLinkStream.listen(_handleDeepLink);
    // Handle initial link (app opened cold via link)
    unawaited(_appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    }));
  }

  void _handleDeepLink(Uri uri) {
    // Expected: https://p.x32am.com/{tmdbId}
    if (uri.host != 'p.x32am.com') return;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;
    final tmdbId = segments.first;
    if (tmdbId.isEmpty) return;

    // Wait until app is initialized before navigating
    unawaited(Future.doWhile(() async {
      if (!_isInitializing && mounted) return false;
      await Future.delayed(const Duration(milliseconds: 100));
      return _isInitializing;
    }).then((_) {
      if (!mounted) return;
      unawaited(Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (context, animation, secondaryAnimation) =>
              MediaInfoScreen(
            item: ImdbSearchResult(
              id: tmdbId,
              title: '',
              year: '',
              posterUrl: '',
            ),
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ));
    }));
  }

  Future<void> _initializeApp({required bool showSplash}) async {
    if (!mounted) return;
    final appNotifier = ref.read(appNotifierProvider.notifier);
    final trendingNotifier = ref.read(trendingNotifierProvider.notifier);
    final kdramaNotifier = ref.read(kDramaNotifierProvider.notifier);
    final magnetNotifier = ref.read(magnetNotifierProvider.notifier);

    await appNotifier.initialize();
    unawaited(appNotifier.saveSetting('has_launched', true));

    if (mounted) {
      unawaited(trendingNotifier.loadTrendingData());
      unawaited(kdramaNotifier.loadTopDramas());
      unawaited(kdramaNotifier.loadTopAiringDramas());
      unawaited(kdramaNotifier.loadLatestDramas());
      unawaited(magnetNotifier.fetchMagnets());
    }

    if (showSplash) {
      await Future.delayed(const Duration(milliseconds: 120));
    }

    if (mounted && showSplash) {
      setState(() => _isInitializing = false);
    }
  }

  @override
  void dispose() {
    unawaited(_appLinksSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const SplashScreen();
    }

    return const MainNavigation();
  }
}
