import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/providers.dart';
import 'providers/navigation_provider.dart';
import 'services/services.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/main_navigation.dart';

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
      child: AllDebridApp(
        storageService: storageService,
        downloadService: downloadService,
      ),
    ),
  );
}

class AllDebridApp extends StatelessWidget {
  final StorageService storageService;
  final DownloadService downloadService;

  const AllDebridApp({
    super.key,
    required this.storageService,
    required this.downloadService,
  });

  @override
  Widget build(BuildContext context) {
    return provider_pkg.MultiProvider(
      providers: [
        provider_pkg.ChangeNotifierProvider(
          create: (_) => AppProvider(storageService: storageService),
        ),
        provider_pkg.ChangeNotifierProvider(create: (_) => NavigationProvider()),
        provider_pkg.ChangeNotifierProxyProvider<AppProvider, MagnetProvider>(
          create: (context) => MagnetProvider(
            getService: () => context.read<AppProvider>().allDebridService,
          ),
          update: (context, appProvider, previous) =>
              previous ??
              MagnetProvider(getService: () => appProvider.allDebridService),
        ),
        provider_pkg.ChangeNotifierProxyProvider<AppProvider, LinkProvider>(
          create: (context) => LinkProvider(
            getService: () => context.read<AppProvider>().allDebridService,
          ),
          update: (context, appProvider, previous) =>
              previous ??
              LinkProvider(getService: () => appProvider.allDebridService),
        ),
        provider_pkg.ChangeNotifierProvider(
          create: (_) => DownloadProvider(downloadService: downloadService),
        ),
        provider_pkg.ChangeNotifierProvider(
          create: (_) => TrendingProvider(),
        ),
        provider_pkg.ChangeNotifierProvider(
          create: (_) => KDramaProvider(),
        ),
      ],
      child: provider_pkg.Selector<AppProvider, (Color, bool)>(
        selector: (_, p) => (p.primaryColor, p.isDarkMode),
        builder: (context, themeData, _) {
          return MaterialApp(
            title: 'AllDebrid',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.createTheme(themeData.$1, isDark: themeData.$2),
            navigatorObservers: [context.read<AppProvider>().routeObserver],
            home: const AppWrapper(),
          );
        },
      ),
    );
  }
}

class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    final appProvider = context.read<AppProvider>();
    // If user has launched before (has API key in storage), skip splash
    final hasLaunchedBefore = appProvider.hasApiKey ||
        (appProvider.getSetting<bool>('has_launched') ?? false);
    if (hasLaunchedBefore) {
      _isInitializing = false;
      Future.microtask(() => _initializeApp(showSplash: false));
    } else {
      Future.microtask(() => _initializeApp(showSplash: true));
    }
  }

  Future<void> _initializeApp({required bool showSplash}) async {
    if (!mounted) return;
    final appProvider = context.read<AppProvider>();
    final trendingProvider = context.read<TrendingProvider>();
    final kdramaProvider = context.read<KDramaProvider>();
    final magnetProvider = context.read<MagnetProvider>();

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
