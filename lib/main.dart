import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';

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

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final storageService = StorageService();
  await storageService.init();

  final notificationService = NotificationService();
  await notificationService.init();

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
    final themeData = ref.watch(
      appProviderProvider.select((p) => (p.primaryColor, p.isDarkMode)),
    );
    return MaterialApp(
      title: 'AllDebrid',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.createTheme(themeData.$1, isDark: themeData.$2),
      navigatorObservers: [ref.read(appProviderProvider).routeObserver],
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

  @override
  void initState() {
    super.initState();
    final appProvider = ref.read(appProviderProvider);
    // If user has launched before (has API key in storage), skip splash
    final hasLaunchedBefore = appProvider.hasApiKey ||
        (appProvider.getSetting<bool>('has_launched') ?? false);
    if (hasLaunchedBefore) {
      _isInitializing = false;
      Future.microtask(() => _initializeApp(showSplash: false));
    } else {
      Future.microtask(() => _initializeApp(showSplash: true));
    }
    _initDeepLinks();
  }

  void _initDeepLinks() {
    // Handle link when app is already running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
    // Handle initial link (app opened cold via link)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    // Expected: https://p.x32am.com/{tmdbId}
    if (uri.host != 'p.x32am.com') return;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return;
    final tmdbId = segments.first;
    if (tmdbId.isEmpty) return;

    // Wait until app is initialized before navigating
    Future.doWhile(() async {
      if (!_isInitializing && mounted) return false;
      await Future.delayed(const Duration(milliseconds: 100));
      return _isInitializing;
    }).then((_) {
      if (!mounted) return;
      Navigator.push(
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
      );
    });
  }

  Future<void> _initializeApp({required bool showSplash}) async {
    if (!mounted) return;
    final appProvider = ref.read(appProviderProvider);
    final trendingProvider = ref.read(trendingProviderProvider);
    final kdramaProvider = ref.read(kDramaProviderProvider);
    final magnetProvider = ref.read(magnetProviderProvider);

    await appProvider.initialize();
    await appProvider.saveSetting('has_launched', true);

    if (mounted) {
      trendingProvider.loadTrendingData();
      kdramaProvider.loadTopDramas();
      kdramaProvider.loadTopAiringDramas();
      kdramaProvider.loadLatestDramas();
      magnetProvider.fetchMagnets();
    }

    if (showSplash) {
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (mounted && showSplash) {
      setState(() => _isInitializing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const SplashScreen();
    }

    return const MainNavigation();
  }
}
