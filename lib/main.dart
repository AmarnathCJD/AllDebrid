import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'providers/providers.dart';
import 'providers/navigation_provider.dart';
import 'services/services.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/settings/api_key_screen.dart';
import 'screens/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MediaKit for video playback
  MediaKit.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surfaceColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize services
  final storageService = StorageService();
  await storageService.init();

  final downloadService = DownloadService(storageService: storageService);

  runApp(
    AllDebridApp(
      storageService: storageService,
      downloadService: downloadService,
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
    return MultiProvider(
      providers: [
        // App Provider
        ChangeNotifierProvider(
          create: (_) => AppProvider(storageService: storageService),
        ),

        // Navigation Provider
        ChangeNotifierProvider(create: (_) => NavigationProvider()),

        // Magnet Provider
        ChangeNotifierProxyProvider<AppProvider, MagnetProvider>(
          create: (context) => MagnetProvider(
            getService: () => context.read<AppProvider>().allDebridService,
          ),
          update: (context, appProvider, previous) =>
              previous ??
              MagnetProvider(getService: () => appProvider.allDebridService),
        ),

        // Link Provider
        ChangeNotifierProxyProvider<AppProvider, LinkProvider>(
          create: (context) => LinkProvider(
            getService: () => context.read<AppProvider>().allDebridService,
          ),
          update: (context, appProvider, previous) =>
              previous ??
              LinkProvider(getService: () => appProvider.allDebridService),
        ),

        // Download Provider
        ChangeNotifierProvider(
          create: (_) => DownloadProvider(downloadService: downloadService),
        ),
      ],
      child: Builder(builder: (context) {
        return MaterialApp(
          title: 'AllDebrid',
          debugShowCheckedModeBanner: false,
          // Now context here can find AppProvider
          theme: AppTheme.createTheme(context.watch<AppProvider>().primaryColor,
              isDark: context.watch<AppProvider>().isDarkMode),
          home: const AppWrapper(),
        );
      }),
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
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Show splash for minimum time
    await Future.delayed(const Duration(seconds: 2));

    // Initialize app
    if (mounted) {
      await context.read<AppProvider>().initialize();
    }

    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const SplashScreen();
    }

    return Consumer<AppProvider>(
      builder: (context, appProvider, _) {
        if (!appProvider.hasApiKey || appProvider.user == null) {
          return const ApiKeyScreen();
        }

        return const MainNavigation();
      },
    );
  }
}
