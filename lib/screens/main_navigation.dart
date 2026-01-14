import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_theme.dart';
import 'home/home_screen.dart';
import 'magnets/magnets_screen.dart';
import 'downloads/downloads_screen.dart';
import 'files/file_browser_screen.dart';
import 'settings/settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final _screens = const [
    HomeScreen(),
    MagnetsScreen(),
    DownloadsScreen(),
    FileBrowserScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final currentIndex = navigationProvider.currentIndex;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border(top: BorderSide(color: AppTheme.borderColor)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavBarItem(
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Home',
                  isSelected: currentIndex == 0,
                  onTap: () => navigationProvider.setIndex(0),
                ),
                _NavBarItem(
                  icon: Icons.link_outlined,
                  activeIcon: Icons.link,
                  label: 'Magnets',
                  isSelected: currentIndex == 1,
                  onTap: () => navigationProvider.setIndex(1),
                ),
                _NavBarItem(
                  icon: Icons.download_outlined,
                  activeIcon: Icons.download,
                  label: 'Downloads',
                  isSelected: currentIndex == 2,
                  onTap: () => navigationProvider.setIndex(2),
                ),
                _NavBarItem(
                  icon: Icons.folder_outlined,
                  activeIcon: Icons.folder,
                  label: 'Files',
                  isSelected: currentIndex == 3,
                  onTap: () => navigationProvider.setIndex(3),
                ),
                _NavBarItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Settings',
                  isSelected: currentIndex == 4,
                  onTap: () => navigationProvider.setIndex(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.primaryColor : AppTheme.textMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
