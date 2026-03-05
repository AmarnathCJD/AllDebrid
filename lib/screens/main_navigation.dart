import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';

import 'home/home_screen.dart';
import 'magnets/magnets_screen.dart';
import 'downloads/downloads_screen.dart';
import 'watchlist/watchlist_screen.dart';
import 'settings/settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  @override
  Widget build(BuildContext context) {
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final appProvider = Provider.of<AppProvider>(context);
    final hasKey = appProvider.hasApiKey;

    final screens = hasKey
        ? [
            HomeScreen(key: HomeScreen.homeKey),
            const WatchlistScreen(),
            const MagnetsScreen(),
            const DownloadsScreen(),
            const SettingsScreen(),
          ]
        : [
            HomeScreen(key: HomeScreen.homeKey),
            const WatchlistScreen(),
            const SettingsScreen(),
          ];

    int currentIndex = navigationProvider.currentIndex;
    if (currentIndex >= screens.length) {
      currentIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        navigationProvider.setIndex(0);
      });
    }

    void onNavTap(int index) {
      HapticFeedback.selectionClick();
      if (index == 0 && currentIndex == 0) {
        HomeScreen.homeKey.currentState?.scrollToTop();
      } else {
        navigationProvider.setIndex(index);
      }
    }

    final navItems = hasKey
        ? [
            (Icons.home_outlined, Icons.home_rounded, 'Home'),
            (Icons.bookmark_outlined, Icons.bookmark_rounded, 'Watchlist'),
            (Icons.link_outlined, Icons.link_rounded, 'Magnets'),
            (Icons.download_outlined, Icons.download_rounded, 'Downloads'),
            (Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
          ]
        : [
            (Icons.home_outlined, Icons.home_rounded, 'Home'),
            (Icons.bookmark_outlined, Icons.bookmark_rounded, 'Watchlist'),
            (Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
          ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _PremiumNavBar(
        items: navItems,
        currentIndex: currentIndex,
        onTap: onNavTap,
        primaryColor: AppTheme.primaryColor,
      ),
    );
  }
}

class _PremiumNavBar extends StatelessWidget {
  final List<(IconData, IconData, String)> items;
  final int currentIndex;
  final void Function(int) onTap;
  final Color primaryColor;

  const _PremiumNavBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      color: AppTheme.backgroundColor,
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        bottom: bottomPadding + 6,
        top: 6,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.borderColor.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final (inactiveIcon, activeIcon, label) = items[i];
              final isSelected = i == currentIndex;
              return Expanded(
                child: _NavItemSimple(
                  inactiveIcon: inactiveIcon,
                  activeIcon: activeIcon,
                  label: label,
                  isSelected: isSelected,
                  primaryColor: primaryColor,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemSimple extends StatelessWidget {
  final IconData inactiveIcon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _NavItemSimple({
    required this.inactiveIcon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? activeIcon : inactiveIcon,
            size: 24,
            color: isSelected ? primaryColor : AppTheme.textMuted,
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
