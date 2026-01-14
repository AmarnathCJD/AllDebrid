import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/common_widgets.dart';
import '../../utils/helpers.dart';
import 'unlock_links_screen.dart';
import '../torrents/torrent_search_screen.dart';
import '../magnets/magnet_files_screen.dart';
import '../../services/imdb_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  List<ImdbSearchResult> _recents = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshRecents();
  }

  @override
  void didPopNext() {
    _refreshRecents();
  }

  Future<void> _refreshRecents() async {
    final recents = await ImdbService().getRecents();
    if (mounted) setState(() => _recents = recents);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshUser();
      context.read<MagnetProvider>().fetchMagnets();
      _refreshRecents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              children: [
                Container(color: AppTheme.backgroundColor), // Deep dark base
                // Orb 1 (Primary Amber) - Very Dark/Subtle
                Positioned(
                  top: -60,
                  right: -60,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryColor
                          .withOpacity(0.04), // Reduced opacity
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor
                              .withOpacity(0.08), // Reduced glow
                          blurRadius: 120,
                          spreadRadius: 30,
                        )
                      ],
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .move(
                          duration: 6.seconds,
                          begin: Offset.zero,
                          end: const Offset(-30, 30))
                      .scale(
                          duration: 10.seconds,
                          begin: const Offset(1, 1),
                          end: const Offset(1.1, 1.1)),
                ),
                // Orb 2 (Accent Orange) - Very Dark/Subtle
                Positioned(
                  bottom: 100,
                  left: -80,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentColor
                          .withOpacity(0.02), // Reduced opacity
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentColor
                              .withOpacity(0.05), // Reduced glow
                          blurRadius: 100,
                          spreadRadius: 20,
                        )
                      ],
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).move(
                      duration: 8.seconds,
                      begin: Offset.zero,
                      end: const Offset(30, -30)),
                ),
                // Fireflies (Fancier)
                ...List.generate(12, (index) {
                  // Pseudo-random positioning
                  final r = (index * 137.5);
                  return Positioned(
                    left: (r % 360).toDouble(), // Distributed across width
                    bottom:
                        ((r * 2) % 600).toDouble(), // Distributed across height
                    child: Container(
                      width: (index % 3 + 3).toDouble(),
                      height: (index % 3 + 3).toDouble(),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor
                            .withOpacity(0.5), // Bright core
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppTheme.primaryColor
                                  .withOpacity(0.8), // Strong glow
                              blurRadius: 6,
                              spreadRadius: 1)
                        ],
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                            begin: const Offset(0.5, 0.5),
                            end: const Offset(1.2, 1.2),
                            duration: (2000 + (index * 100)).ms) // Breathing
                        .animate(onPlay: (c) => c.repeat())
                        .moveY(
                            begin: 0,
                            end: -100,
                            duration: (10 + index).seconds) // Slow rise
                        .fadeIn(duration: 1.seconds)
                        .fadeOut(
                            delay: (5 + index).seconds, duration: 2.seconds),
                  );
                }),
              ],
            ),
          ),
          SafeArea(
            child: Consumer2<AppProvider, MagnetProvider>(
              builder: (context, appProvider, magnetProvider, _) {
                final user = appProvider.user;
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildHeroHeader(user)),
                    SliverToBoxAdapter(
                        child: _buildCompactStats(magnetProvider)),
                    SliverToBoxAdapter(child: _buildActionGrid()),
                    SliverToBoxAdapter(child: _buildRecentsSection()),
                    SliverToBoxAdapter(child: _buildActivity(magnetProvider)),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(dynamic user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HELLO',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.username.toUpperCase() ?? 'USER',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          if (user?.isPremium == true)
            Transform.rotate(
              angle: 0.05,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.backgroundColor,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildCompactStats(MagnetProvider magnetProvider) {
    final active =
        magnetProvider.magnets.where((m) => m.statusCode != 4).length;
    final ready = magnetProvider.magnets.where((m) => m.statusCode == 4).length;
    final total = magnetProvider.magnets.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 64),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor.withOpacity(0.45),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _CompactStat(
                    label: 'TOTAL',
                    value: total.toString(),
                    color: AppTheme.textPrimary),
                Container(
                    width: 1, height: 20, color: Colors.white.withOpacity(0.1)),
                _CompactStat(
                    label: 'ACTIVE',
                    value: active.toString(),
                    color: AppTheme.accentColor),
                Container(
                    width: 1, height: 20, color: Colors.white.withOpacity(0.1)),
                _CompactStat(
                    label: 'READY',
                    value: ready.toString(),
                    color: AppTheme.successColor),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 100.ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildActionGrid() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK ACTIONS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _LargeActionButton(
                  icon: Icons.link,
                  title: 'UNLOCK\nLINK',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const UnlockLinksScreen()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _SmallActionButton(
                      icon: Icons.download,
                      title: 'ADD\nMAGNET',
                      onTap: _showAddMagnetDialog,
                    ),
                    const SizedBox(height: 12),
                    _SmallActionButton(
                      icon: Icons.search,
                      title: 'SEARCH\nTORRENTS',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TorrentSearchScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SmallActionButton(
                      icon: Icons.refresh,
                      title: 'REFRESH',
                      onTap: () {
                        context.read<AppProvider>().refreshUser();
                        context.read<MagnetProvider>().fetchMagnets();
                        _refreshRecents();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 300.ms);
  }

  Widget _buildRecentsSection() {
    if (_recents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'RECENTLY VIEWED',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 1,
            ),
          ),
        ),
        SizedBox(
          height: 175,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            scrollDirection: Axis.horizontal,
            itemCount: _recents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = _recents[index];
              return Container(
                width: 112,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: item.posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: AppTheme.cardColor),
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.cardColor,
                          child: const Icon(Icons.movie,
                              color: AppTheme.textMuted),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 60,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.9),
                                Colors.transparent
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                  color: Colors.black,
                                  blurRadius: 2,
                                  offset: Offset(0, 1))
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              if (item.magnetId != null) {
                                try {
                                  final magnet = context
                                      .read<MagnetProvider>()
                                      .magnets
                                      .firstWhere((m) =>
                                          m.id.toString() == item.magnetId);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            MagnetFilesScreen(magnet: magnet)),
                                  ).then((_) => _refreshRecents());
                                } catch (_) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Source torrent not found or unavailable'),
                                        backgroundColor: AppTheme.errorColor),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: (index * 50).ms)
                  .slideX(begin: 0.1, end: 0, duration: 400.ms);
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildActivity(MagnetProvider provider) {
    final recent = provider.magnets.take(4).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT ACTIVITY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
              if (recent.isNotEmpty)
                Text(
                  'VIEW ALL →',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (recent.isEmpty)
            Container(
              height: 140,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderColor, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 32, color: AppTheme.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      'NO ACTIVITY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...recent.map((magnet) => _ActivityCard(magnet: magnet)),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 300.ms);
  }

  void _showAddMagnetDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADD MAGNET',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Paste magnet link or hash...',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 8),
                  CompactButton(
                    text: 'ADD',
                    icon: Icons.add,
                    onPressed: () async {
                      if (controller.text.trim().isNotEmpty) {
                        Navigator.pop(context);
                        await context
                            .read<MagnetProvider>()
                            .uploadMagnet(controller.text.trim());
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Magnet added'),
                                backgroundColor: AppTheme.successColor),
                          );
                        }
                      }
                    },
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

class _CompactStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CompactStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LargeActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _LargeActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 160,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 32, color: AppTheme.backgroundColor),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.backgroundColor,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 74,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primaryColor, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    height: 1.1,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Icon(icon, size: 20, color: AppTheme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final dynamic magnet;

  const _ActivityCard({required this.magnet});

  @override
  Widget build(BuildContext context) {
    final isReady = magnet.statusCode == 4;
    final progress = magnet.size > 0 ? (magnet.downloaded / magnet.size) : 0.0;
    final statusColor = isReady ? AppTheme.successColor : AppTheme.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: AppTheme.borderColor.withOpacity(0.6), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background progress fill (subtle)
          if (!isReady && progress > 0)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * progress,
              child: Container(
                color: statusColor.withOpacity(0.03),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Box
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isReady ? Icons.check_rounded : Icons.download_rounded,
                        color: statusColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            magnet.filename,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isReady ? 'COMPLETED' : 'DOWNLOADING',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: statusColor,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStat(
                      Icons.sd_storage_rounded,
                      formatBytes(magnet.size),
                    ),
                    if (!isReady && magnet.downloadSpeed > 0)
                      _buildStat(
                        Icons.speed_rounded,
                        '${formatBytes(magnet.downloadSpeed)}/s',
                      ),
                    if (magnet.seeders > 0)
                      _buildStat(
                        Icons.people_outline_rounded,
                        '${magnet.seeders} SEEDS',
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Progress Bar
                if (!isReady)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppTheme.surfaceColor,
                      color: statusColor,
                      minHeight: 4,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideX(begin: -0.05, end: 0);
  }

  Widget _buildStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
