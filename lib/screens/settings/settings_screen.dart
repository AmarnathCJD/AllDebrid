import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../services/recent_searches_service.dart';
import '../../services/session_storage.dart';
import '../../services/tg_native_service.dart';
import '../../services/tg_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isClearingCache = false;
  bool _hasTgSession = false;
  String? _tgUsername;

  @override
  void initState() {
    super.initState();
    _loadTgStatus();
  }

  Future<void> _loadTgStatus() async {
    final hasSession = await SessionStorage.hasSession();
    final username = await SessionStorage.getUsername();
    if (mounted) {
      setState(() {
        _hasTgSession = hasSession;
        _tgUsername = username;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Consumer<AppProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                  children: [
                    _buildProfileCard(provider),
                    const SizedBox(height: 18),
                    _buildSectionLabel('ACCOUNT'),
                    const SizedBox(height: 7),
                    _buildAccountSection(provider),
                    const SizedBox(height: 18),
                    _buildSectionLabel('STORAGE'),
                    const SizedBox(height: 7),
                    _buildStorageSection(provider),
                    const SizedBox(height: 18),
                    _buildSectionLabel('TELEGRAM'),
                    const SizedBox(height: 7),
                    _buildTelegramSection(provider),
                    const SizedBox(height: 18),
                    _buildSectionLabel('ABOUT'),
                    const SizedBox(height: 7),
                    _buildAboutSection(provider),
                    const SizedBox(height: 18),
                    _buildLogoutButton(provider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'YOUR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Text(
                    'SETTINGS',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      height: 1,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(AppProvider provider) {
    final user = provider.user;
    final username = user?.username ?? 'User';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : 'U';
    final isPremium = user?.isPremium ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.borderColor.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.outfit(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: GoogleFonts.outfit(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPremium ? 'PREMIUM' : 'FREE',
                  style: GoogleFonts.outfit(
                    color:
                        isPremium ? AppTheme.primaryColor : AppTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSection(AppProvider provider) {
    return _SettingsCard(
      children: [
        _SettingsTile(
          icon: Icons.cloud_done_rounded,
          title: 'AllDebrid Account',
          subtitle: provider.hasApiKey ? 'Connected' : 'Not connected',
          badge: provider.hasApiKey ? 'ACTIVE' : 'INACTIVE',
          badgeColor:
              provider.hasApiKey ? AppTheme.successColor : AppTheme.errorColor,
          onTap: () => _showApiKeyDialog(context, provider),
        ),
      ],
    );
  }

  Widget _buildStorageSection(AppProvider provider) {
    return _SettingsCard(
      children: [
        _SettingsTile(
          icon: Icons.history_rounded,
          title: 'Clear History',
          subtitle: 'Remove recent searches',
          onTap: _clearHistory,
        ),
        _SettingsTile(
          icon: Icons.bookmark_remove_rounded,
          title: 'Clear Watchlist',
          subtitle: 'Remove saved items',
          onTap: () => _clearWatchlist(provider),
        ),
        _SettingsTile(
          icon: Icons.cleaning_services_rounded,
          title: 'Clear Cache',
          subtitle: 'Free up storage',
          trailing: _isClearingCache
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
                  ),
                )
              : null,
          onTap: _clearCache,
        ),
      ],
    );
  }

  Widget _buildTelegramSection(AppProvider provider) {
    return _SettingsCard(
      children: [
        _SettingsTile(
          icon: Icons.send_rounded,
          title: 'Telegram Bridge',
          subtitle: _hasTgSession
              ? 'Connected as ${_tgUsername ?? "User"}'
              : 'Connect via Bot Token',
          badge: _hasTgSession ? 'ACTIVE' : 'NOT SET',
          badgeColor:
              _hasTgSession ? AppTheme.successColor : AppTheme.textMuted,
          onTap: () => _showTelegramBotDialog(context, provider),
          trailing: _hasTgSession
              ? IconButton(
                  icon: Icon(Icons.link_off_rounded,
                      size: 20,
                      color: AppTheme.errorColor.withValues(alpha: 0.7)),
                  onPressed: _disconnectTelegram,
                  tooltip: 'Disconnect',
                )
              : null,
        ),
      ],
    );
  }

  Future<void> _disconnectTelegram() async {
    final confirm = await _showConfirmDialog('Disconnect Telegram?',
        'This will disable the native streaming pipeline.');
    if (confirm) {
      await SessionStorage.clearSession();
      await _loadTgStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Telegram Bridge Disconnected'),
          backgroundColor: AppTheme.elevatedColor,
        ));
      }
    }
  }

  Widget _buildAboutSection(AppProvider provider) {
    return _SettingsCard(
      children: [
        _SettingsTile(
          icon: Icons.info_outline_rounded,
          title: 'Version',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.elevatedColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.borderColor.withValues(alpha: 0.5),
                width: 0.8,
              ),
            ),
            child: Text(
              '1.0.0',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(AppProvider provider) {
    return GestureDetector(
      onTap: () => _logout(provider),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.errorColor.withValues(alpha: 0.2),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: AppTheme.errorColor, size: 16),
            const SizedBox(width: 6),
            Text(
              'Log Out',
              style: GoogleFonts.outfit(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dialogs
  void _showApiKeyDialog(BuildContext context, AppProvider provider) {
    final controller = TextEditingController(text: provider.apiKey);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.elevatedColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppTheme.borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        title: Text('AllDebrid API Key',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              fontSize: 18,
            )),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'API Key',
            hintText: 'Enter your API key',
            prefixIcon: const Icon(Icons.vpn_key_rounded),
            filled: true,
            fillColor: AppTheme.surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppTheme.primaryColor,
                width: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL',
                  style: GoogleFonts.outfit(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ))),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await provider.initializeWithApiKey(controller.text);
                if (mounted) Navigator.pop(context);
              }
            },
            child: Text('SAVE',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(AppProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.elevatedColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: AppTheme.borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        title: Text('Log Out?',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              fontSize: 18,
            )),
        content: Text('Your API key will be removed.',
            style: GoogleFonts.outfit(
              color: AppTheme.textSecondary,
              fontSize: 14,
            )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('CANCEL',
                  style: GoogleFonts.outfit(
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('LOG OUT',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await provider.logout();
      if (mounted) setState(() {});
    }
  }

  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);
    PaintingBinding.instance.imageCache.clear();
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isClearingCache = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Cache cleared'),
        backgroundColor: AppTheme.elevatedColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Future<void> _clearHistory() async {
    final confirm =
        await _showConfirmDialog('Clear History?', 'Remove recent searches?');
    if (confirm) {
      await RecentSearchesService.clearAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('History cleared'),
          backgroundColor: AppTheme.elevatedColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _clearWatchlist(AppProvider provider) async {
    final confirm =
        await _showConfirmDialog('Clear Watchlist?', 'Remove all saved items?');
    if (confirm) {
      await provider.clearWatchlist();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Watchlist cleared'),
          backgroundColor: AppTheme.elevatedColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.elevatedColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: AppTheme.borderColor.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            title: Text(title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                )),
            content: Text(content,
                style: GoogleFonts.outfit(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                )),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('CANCEL',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ))),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor),
                child: Text('CONFIRM',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showTelegramBotDialog(BuildContext context, AppProvider provider) {
    final controller = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppTheme.backgroundColor,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            contentPadding: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            content: Container(
              width: MediaQuery.of(context).size.width,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.surfaceColor,
                    AppTheme.backgroundColor,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: const BoxDecoration(),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          'Native Bridge',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Telegram Pipeline Setup',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        if (_hasTgSession) ...[
                          Text(
                            'Your native Telegram pipeline is currently active and serving direct streams.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.successColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successColor
                                        .withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.verified_user_rounded,
                                      color: AppTheme.successColor, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'CONNECTED AS',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.successColor,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                      Text(
                                        _tgUsername ?? "Active Bot",
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    'CLOSE',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                          setState(() => isSaving = true);
                                          await SessionStorage.clearSession();
                                          await _loadTgStatus();
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content: const Text(
                                                  'Telegram Bridge Disconnected'),
                                              backgroundColor:
                                                  AppTheme.elevatedColor,
                                            ));
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.errorColor
                                        .withValues(alpha: 0.15),
                                    foregroundColor: AppTheme.errorColor,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppTheme.errorColor))
                                      : Text(
                                          'DISCONNECT',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            'Enter your Telegram bot token to enable direct peer-to-peer streaming. This removes dependency on external CDNs.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: controller,
                            enabled: !isSaving,
                            style: GoogleFonts.outfit(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              labelText: 'BOT TOKEN',
                              labelStyle: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                              hintText: '123456:ABC-DEF...',
                              prefixIcon: Icon(Icons.vpn_key_rounded,
                                  size: 18, color: AppTheme.primaryColor),
                              filled: true,
                              fillColor:
                                  AppTheme.elevatedColor.withValues(alpha: 0.5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(
                                    color: AppTheme.primaryColor, width: 1.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: isSaving
                                      ? null
                                      : () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Text(
                                    'CANCEL',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                          if (controller.text.isEmpty) return;
                                          setState(() => isSaving = true);
                                          try {
                                            final native = TGNativeService();

                                            // Initialize fetcher briefly to get username
                                            final username = await native
                                                .createSessionFromBotToken(
                                                    controller.text);
                                            final tgUser = await TGNativeService
                                                .initialize(
                                                    stringSession: username);

                                            // Resolve default index channel
                                            final resolved =
                                                await native.resolveUsername(
                                                    'indexmzgroup');
                                            final chatId =
                                                resolved['channel_id'] as int;
                                            final chatHash =
                                                resolved['access_hash'] as int;

                                            // Save to secure storage
                                            await SessionStorage.saveSession(
                                              sessionString: username,
                                              botToken: controller.text,
                                              chatId: chatId,
                                              chatHash: chatHash,
                                              username: tgUser,
                                            );

                                            // Initialize for current session
                                            TgService.telegramChannelId =
                                                chatId;
                                            TgService.telegramAccessHash =
                                                chatHash;
                                            await TgService
                                                .initializeNativeFetcher(
                                                    stringSession: username);

                                            if (context.mounted) {
                                              Navigator.pop(context);
                                              await _loadTgStatus();
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: Text(
                                                    'Telegram Bridge Active: $tgUser'),
                                                backgroundColor:
                                                    AppTheme.successColor,
                                              ));
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                content: Text('Failed: $e'),
                                                backgroundColor:
                                                    AppTheme.errorColor,
                                              ));
                                            }
                                          } finally {
                                            if (context.mounted) {
                                              setState(() => isSaving = false);
                                            }
                                          }
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.black))
                                      : Text(
                                          'CONNECT',
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.black,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Widgets
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.borderColor.withValues(alpha: 0.2),
          width: 0.8,
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 0.6,
                color: AppTheme.borderColor.withValues(alpha: 0.1),
                indent: 62,
                endIndent: 0,
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? badge;
  final Color? badgeColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.badge,
    this.badgeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppTheme.primaryColor.withValues(alpha: 0.05),
        highlightColor: AppTheme.primaryColor.withValues(alpha: 0.02),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? AppTheme.primaryColor)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: (badgeColor ?? AppTheme.primaryColor)
                          .withValues(alpha: 0.25),
                      width: 0.4,
                    ),
                  ),
                  child: Text(
                    badge!,
                    style: GoogleFonts.outfit(
                      color: badgeColor ?? AppTheme.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ] else if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppTheme.textMuted.withValues(alpha: 0.3)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
