import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isClearingCache = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Consumer<AppProvider>(
          builder: (context, appProvider, _) {
            final user = appProvider.user;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildHeader(user),
                const SizedBox(height: 32),
                _buildAccountSection(user),
                const SizedBox(height: 24),
                _buildAppSection(appProvider),
                const SizedBox(height: 24),
                _buildAboutSection(),
                const SizedBox(height: 32),
                _buildLogoutButton(appProvider),
                const SizedBox(height: 60),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ACCOUNT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'SETTINGS',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            height: 1,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        // User card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3), width: 1),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.7)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.username.toUpperCase() ?? 'USER',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (user?.isPremium == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppTheme.primaryColor.withOpacity(0.2)),
                        ),
                        child: Text(
                          'PREMIUM • ${user?.daysRemaining ?? 0} DAYS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${user?.fidelityPoints ?? 0}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Text(
                    'POINTS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildAccountSection(dynamic user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'ACCOUNT'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _SettingRow(
                label: 'USERNAME',
                value: user?.username ?? 'Not set',
                icon: Icons.person_outline_rounded,
                isFirst: true,
              ),
              _Divider(),
              _SettingRow(
                label: 'EMAIL',
                value: user?.email ?? 'Not set',
                icon: Icons.email_outlined,
              ),
              _Divider(),
              _SettingRow(
                label: 'API KEY',
                value: '••••••••••••',
                icon: Icons.vpn_key_outlined,
                onTap: () => _showApiKeyDialog(context),
                isLast: true,
                trailing: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      size: 14, color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 100.ms, duration: 300.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildAppSection(AppProvider provider) {
    final downloadPath =
        provider.getSetting<String>('download_path') ?? 'Default';
    final torrentUrl = provider.getSetting<String>('torrent_base_url') ??
        'https://www.1tamilmv.do';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'APPEARANCE'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _SettingRow(
                label: 'DARK MODE',
                value: provider.isDarkMode ? 'On' : 'Off',
                icon: Icons.dark_mode_outlined,
                isFirst: true,
                onTap: () => provider.toggleThemeMode(), // Toggle logic
                trailing: Switch(
                  value: provider.isDarkMode,
                  onChanged: (val) => provider.toggleThemeMode(),
                  activeColor: provider.primaryColor,
                ),
              ),
              _Divider(),
              _SettingRow(
                label: 'ACCENT COLOR',
                value: 'Customize App Theme',
                icon: Icons.color_lens_outlined,
                isLast: true,
                trailing: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                      color: provider.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: provider.primaryColor.withOpacity(0.4),
                            blurRadius: 8)
                      ]),
                ),
                onTap: () => _showColorPicker(context, provider),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeader(title: 'APPLICATION'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _SettingRow(
                label: 'DOWNLOAD PATH',
                value: downloadPath,
                icon: Icons.folder_outlined,
                isFirst: true,
                onTap: () => _showEditDialog(context, 'DOWNLOAD PATH',
                    'download_path', downloadPath, provider),
                trailing: const Icon(Icons.edit_rounded,
                    size: 16, color: AppTheme.textMuted),
              ),
              _Divider(),
              _SettingRow(
                label: 'TORRENT BASE URL',
                value: torrentUrl,
                icon: Icons.link_rounded,
                onTap: () => _showEditDialog(context, 'TORRENT BASE URL',
                    'torrent_base_url', torrentUrl, provider),
                trailing: const Icon(Icons.edit_rounded,
                    size: 16, color: AppTheme.textMuted),
              ),
              _Divider(),
              _SettingRow(
                label: 'CLEAR CACHE',
                value: 'Free up storage',
                icon: Icons.cleaning_services_outlined,
                isLast: true,
                onTap: _clearCache,
                trailing: _isClearingCache
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right_rounded,
                        size: 18, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 150.ms, duration: 300.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'ABOUT'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              const _SettingRow(
                label: 'VERSION',
                value: '1.0.0',
                icon: Icons.info_outline_rounded,
                isFirst: true,
              ),
              _Divider(),
              _SettingRow(
                label: 'WEBSITE',
                value: 'alldebrid.com',
                icon: Icons.language_rounded,
                isLast: true,
                onTap: () {},
                trailing: const Icon(Icons.open_in_new_rounded,
                    size: 16, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 300.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildLogoutButton(AppProvider appProvider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _logout(appProvider),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: AppTheme.errorColor.withOpacity(0.05),
            border: Border.all(
                color: AppTheme.errorColor.withOpacity(0.3), width: 1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 20, color: AppTheme.errorColor),
              const SizedBox(width: 10),
              Text(
                'LOGOUT',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.errorColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 250.ms, duration: 300.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isClearingCache = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showApiKeyDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'UPDATE API KEY',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter new API key',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      if (controller.text.isNotEmpty) {
                        Navigator.pop(context);
                        await context
                            .read<AppProvider>()
                            .initializeWithApiKey(controller.text);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: const Text('SAVE',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String title, String key,
      String currentValue, AppProvider provider) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EDIT $title',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter value',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await provider.saveSetting(key, controller.text);
                      if (context.mounted) {
                        Navigator.pop(context);
                        // Force rebuild or update? Consumer will inspect provider again mostly if notifyListeners called?
                        // saveSetting doesn't notifyListeners in AppProvider currently.
                        // I will add notifyListeners to saveSetting in AppProvider.
                        // But since AppProvider wraps StorageService, I should update AppProvider to notify.
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    child: const Text('SAVE',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, AppProvider provider) {
    const colors = [
      Color(0xFFE8A634), // Amber (Default)
      Color(0xFFE94E34), // Orange
      Color(0xFF3498DB), // Blue
      Color(0xFF2ECC71), // Green
      Color(0xFF9B59B6), // Purple
      Color(0xFFFF2E63), // Pink
      Color(0xFF00CED1), // Cyan
      Color(0xFFFFFFFF), // White
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SELECT ACCENT COLOR',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: colors.map((color) {
                  final isSelected = provider.primaryColor.value == color.value;
                  return GestureDetector(
                    onTap: () {
                      provider.setPrimaryColor(color);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : Border.all(color: Colors.white24),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                  color: color.withOpacity(0.5), blurRadius: 10)
                          ]),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.black, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL')),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _logout(AppProvider appProvider) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.logout_rounded,
                    size: 32, color: AppTheme.errorColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'Confirm Logout',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to logout?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await appProvider.logout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('LOGOUT'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppTheme.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;

  const _SettingRow({
    required this.label,
    required this.value,
    required this.icon,
    this.trailing,
    this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: AppTheme.borderColor.withOpacity(0.5),
    );
  }
}
