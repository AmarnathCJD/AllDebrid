import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../models/models.dart';

import '../../utils/helpers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/imdb_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../player/player_screen.dart';
import '../../widgets/widgets.dart';
import 'dart:ui';
import '../torrents/discover_screen.dart';

class MagnetsScreen extends StatefulWidget {
  const MagnetsScreen({super.key});

  @override
  State<MagnetsScreen> createState() => _MagnetsScreenState();
}

class _MagnetsScreenState extends State<MagnetsScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MagnetProvider>().fetchMagnets();
    });
  }

  List<dynamic> _getFilteredMagnets(MagnetProvider provider) {
    if (_selectedIndex == 0) return provider.magnets;
    if (_selectedIndex == 1) {
      return provider.magnets.where((m) => m.statusCode != 4).toList();
    }
    return provider.magnets.where((m) => m.statusCode == 4).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Consumer<MagnetProvider>(
          builder: (context, provider, _) {
            final filteredMagnets = _getFilteredMagnets(provider);

            return Column(
              children: [
                _buildHeader(provider),
                _buildSegmentedTabs(provider),
                Expanded(
                  child: _buildList(filteredMagnets, provider),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'magnets_fab',
        onPressed: _showAddMagnetDialog,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add_link_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader(MagnetProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
                  'MAGNETS',
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

          // Discover Button
          Material(
            color: Colors.transparent,
            child: Tooltip(
              message: 'Discover',
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DiscoverScreen()),
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.explore_rounded,
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Delete All / Clean Button
          if (provider.magnets.isNotEmpty)
            Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'Clean All',
                child: InkWell(
                  onTap: () => _confirmDeleteAll(provider),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.transparent),
                    ),
                    child: const Icon(
                      Icons.cleaning_services_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSegmentedTabs(MagnetProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 54,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.cardColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(24),
          // Glass border
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
        ),
        child: Row(
          children: [
            _buildTabItem('ALL', 0, provider.magnets.length),
            _buildTabItem('ACTIVE', 1,
                provider.magnets.where((m) => m.statusCode != 4).length),
            _buildTabItem('READY', 2,
                provider.magnets.where((m) => m.statusCode == 4).length),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 100.ms, duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildTabItem(String label, int index, int count) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withValues(alpha: 0.8)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : AppTheme.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.black.withValues(alpha: 0.2)
                          : AppTheme.surfaceColor.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : AppTheme.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List magnets, MagnetProvider provider) {
    if (magnets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dashboard_customize_outlined,
                size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No items found'.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.fetchMagnets(),
      color: AppTheme.primaryColor,
      backgroundColor: AppTheme.cardColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: magnets.length,
        itemBuilder: (context, index) {
          final magnet = magnets[index];
          return _MagnetCard(
            magnet: magnet,
            index: index,
            onTap: () => _showMagnetBottomSheet(context, magnet, provider),
            onDelete: () => _confirmDelete(magnet, provider),
          );
        },
      ),
    );
  }

  void _showMagnetBottomSheet(
      BuildContext context, dynamic magnet, MagnetProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MagnetBottomSheet(
        magnet: magnet,
        onNavigateToFull: () {},
        onDelete: () {
          Navigator.pop(context);
          _confirmDelete(magnet, provider);
        },
      ),
    );
  }

  Future<void> _confirmDelete(dynamic magnet, MagnetProvider provider) async {
    final confirm = await _showModernDeleteDialog(context, magnet.filename);
    if (confirm == true) {
      provider.deleteMagnet(magnet.id.toString());
    }
  }

  Future<void> _confirmDeleteAll(MagnetProvider provider) async {
    if (provider.magnets.isEmpty) return;

    final confirm = await _showModernDeleteDialog(context, 'ALL MAGNETS');
    if (confirm == true) {
      for (var m in provider.magnets) {
        provider.deleteMagnet(m.id.toString());
      }
    }
  }

  Future<bool?> _showModernDeleteDialog(BuildContext context, String filename) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutQuart,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.95 + (0.05 * value),
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Heading Text
                    Text(
                      'Confirm Deletion',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted.withValues(alpha: 0.7),
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Filename Text with truncation
                    Text(
                      filename,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.pop(context, false),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.pop(context, true),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              height: 46,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFFDC2626), // Red 600
                                    const Color(0xFFB91C1C)
                                        .withValues(alpha: 0.8), // Red 700
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFDC2626)
                                        .withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'Delete',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

class _MagnetCard extends StatelessWidget {
  final dynamic magnet;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MagnetCard({
    required this.magnet,
    required this.index,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final progress = magnet.size > 0 ? (magnet.downloaded / magnet.size) : 0.0;
    final isReady = magnet.statusCode == 4;
    final isError = magnet.statusCode > 4;

    // Determine status color/theme
    final Color statusColor = isReady
        ? const Color(0xFF10B981) // Emerald Green
        : (isError
            ? AppTheme.errorColor
            : const Color(0xFFF59E0B)); // Amber for active

    // Infer file extension/type for icon
    final ext = magnet.filename.contains('.')
        ? magnet.filename.split('.').last.toUpperCase()
        : 'FILE';
    final isVideo = ['MKV', 'MP4', 'AVI', 'MOV', 'WMV'].contains(ext);
    final isAudio = ['MP3', 'FLAC', 'WAV', 'M4A'].contains(ext);
    final isArchive = ['ZIP', 'RAR', '7Z', 'ISO'].contains(ext);

    IconData typeIcon = Icons.insert_drive_file_outlined;
    if (isVideo) {
      typeIcon = Icons.movie_outlined;
    } else if (isAudio) {
      typeIcon = Icons.audiotrack_outlined;
    } else if (isArchive) {
      typeIcon = Icons.archive_outlined;
    }

    return Slidable(
      key: ValueKey(magnet.id),
      startActionPane: isReady
          ? ActionPane(
              motion: const StretchMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) => onTap(),
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  icon: Icons.file_open_rounded,
                  label: 'Open',
                ),
              ],
            )
          : null,
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => onDelete(),
            backgroundColor: AppTheme.errorColor,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        // No explicit border, just pure raised glass effect
        decoration: BoxDecoration(
          // Glassy gradient background
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.cardColor.withValues(alpha: 0.95),
              AppTheme.cardColor.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          // Raised shadow
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: -2,
            ),
            // Subtle highlight glow if active
            if (!isReady && !isError)
              BoxShadow(
                color: statusColor.withValues(alpha: 0.1),
                blurRadius: 15,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                // 1. Dynamic Background for Active State
                if (!isReady && !isError)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      height: 4,
                      width: MediaQuery.of(context).size.width *
                          progress *
                          0.9, // approx width
                      decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(4),
                              bottomRight: Radius.circular(4)),
                          boxShadow: [
                            BoxShadow(
                                color: statusColor,
                                blurRadius: 6,
                                spreadRadius: 1),
                          ]),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(14), // Increased padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Creative Icon Box
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  statusColor.withValues(alpha: 0.2),
                                  statusColor.withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              // Subtle inset border
                              border: Border.all(
                                  color: statusColor.withValues(alpha: 0.1),
                                  width: 1),
                            ),
                            child: Icon(
                              typeIcon,
                              color: statusColor,
                              size: 22,
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Title & Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  magnet.filename,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    // Clean Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color:
                                            statusColor.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (!isReady && !isError) ...[
                                            SizedBox(
                                                width: 8,
                                                height: 8,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: statusColor,
                                                )),
                                            const SizedBox(width: 8),
                                          ],
                                          Text(
                                            magnet.magnetStatusCode.label
                                                .toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: statusColor,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      formatBytes(magnet.size),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFF59E0B), // Orange
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Action: Delete (Highlighted Circular)
                          InkWell(
                            onTap: onDelete,
                            borderRadius:
                                BorderRadius.circular(50), // Fully rounded
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color:
                                    AppTheme.errorColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle, // Circular shape
                                border: Border.all(
                                    color: AppTheme.errorColor
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Icon(Icons.delete_outline,
                                  size: 18, color: AppTheme.errorColor),
                            ),
                          ),
                        ],
                      ),

                      // Active State Stats
                      if (!isReady && !isError) ...[
                        const SizedBox(height: 14),
                        // Modern Progress Bar
                        Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            widthFactor: progress.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    statusColor,
                                    statusColor.withValues(alpha: 0.8)
                                  ]),
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: [
                                    BoxShadow(
                                        color:
                                            statusColor.withValues(alpha: 0.4),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2))
                                  ]),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Detailed Stats Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildDetailStat(Icons.speed,
                                formatSpeed(magnet.downloadSpeed), statusColor),
                            _buildDetailStat(Icons.people_alt_outlined,
                                '${magnet.seeders} Seeds', AppTheme.textMuted),
                            Text(
                              '${(progress * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: statusColor,
                              ),
                            ),
                          ],
                        )
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailStat(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// Bottom Sheet for Magnet Files Quick View
class _MagnetBottomSheet extends StatefulWidget {
  final dynamic magnet;
  final VoidCallback onNavigateToFull;
  final VoidCallback onDelete;

  const _MagnetBottomSheet({
    required this.magnet,
    required this.onNavigateToFull,
    required this.onDelete,
  });

  @override
  State<_MagnetBottomSheet> createState() => _MagnetBottomSheetState();
}

class _MagnetBottomSheetState extends State<_MagnetBottomSheet> {
  bool _isLoading = true;
  List<FlatFile> _files = [];
  Set<String> _selectedFiles = {};
  String? _error;
  final ImdbService _imdbService = ImdbService();
  ImdbSearchResult? _linkedImdb;

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _loadImdbLink();
  }

  Future<void> _loadImdbLink() async {
    // Logic handled in _loadFiles primarily, but kept for structure
  }

  Future<void> _loadFiles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final files = await context
          .read<MagnetProvider>()
          .getMagnetFiles(widget.magnet.id.toString());
      if (files != null) {
        _files = flattenMagnetFiles(files);
        _files.sort((a, b) => a.name.compareTo(b.name));

        if (_files.isNotEmpty) {
          final link = await _imdbService.getLink(_files.first.name);
          if (link != null && mounted) {
            setState(() => _linkedImdb = link);
          }
        }
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Parse season and episode from filename (e.g., "S01E02" -> season=1, episode=2)
  (int? season, int? episode) _parseSeasonEpisode(String filename) {
    final regex = RegExp(r'[Ss](\d{1,2})[Ee](\d{1,2})');
    final match = regex.firstMatch(filename);
    if (match != null) {
      return (int.parse(match.group(1)!), int.parse(match.group(2)!));
    }
    return (null, null);
  }

  void _showMagnetLinkModal() {
    final cleanQuery = cleanFilename(widget.magnet.filename);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ImdbSearchSheet(
        initialQuery: cleanQuery,
        onSelect: _linkAllFiles,
      ),
    );
  }

  Future<void> _linkAllFiles(ImdbSearchResult result) async {
    Navigator.pop(context); // Close sheet

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Fetching details and linking all files...'),
        duration: Duration(seconds: 1)));

    ImdbSearchResult fullResult = result;
    if (result.description == null ||
        result.rating == null ||
        result.kind == null ||
        result.genres == null) {
      try {
        final details = await _imdbService.fetchDetails(result.id);
        fullResult = result.copyWith(
          rating: details.rating ?? result.rating,
          description: details.description ?? result.description,
          genres: details.genres ?? result.genres,
          duration: details.duration ?? result.duration,
          ratingCount: details.ratingCount ?? result.ratingCount,
          stars: details.stars ?? result.stars,
          videoId: details.videoId ?? result.videoId,
          releaseDate: details.releaseDate ?? result.releaseDate,
          country: details.country ?? result.country,
          languages: details.languages ?? result.languages,
          kind: details.kind ?? result.kind,
        );
      } catch (e) {
        debugPrint('Details fetch failed: $e');
      }
    }

    fullResult = fullResult.copyWith(magnetId: widget.magnet.id.toString());

    final kind = fullResult.kind?.toLowerCase();
    final isTvShow = kind == 'tvseries' ||
        kind == 'tv series' ||
        kind == 'series' ||
        kind == 'tvepisode';

    int linkedCount = 0;

    for (var file in _files) {
      ImdbSearchResult fileResult = fullResult;

      if (isTvShow) {
        final (s, e) = _parseSeasonEpisode(file.name);
        if (s != null && e != null) {
          fileResult = fullResult.copyWith(season: s, episode: e);
        }
      }

      await _imdbService.saveLink(file.name, fileResult);
      linkedCount++;
    }

    await _imdbService.addToRecents(fullResult);

    if (mounted) {
      setState(() {
        _linkedImdb = fullResult;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Linked $linkedCount files to ${fullResult.title}'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedFiles.length == _files.length) {
        _selectedFiles.clear();
      } else {
        _selectedFiles = _files.map((f) => f.link).toSet();
      }
    });
  }

  Future<void> _downloadSelected() async {
    if (_selectedFiles.isEmpty) return;

    final magnetProvider = context.read<MagnetProvider>();
    final downloadProvider = context.read<DownloadProvider>();
    int downloaded = 0;

    for (final link in _selectedFiles) {
      final file = _files.firstWhere((f) => f.link == link);
      try {
        final directLink = await magnetProvider.unlockLink(link);
        if (directLink != null) {
          await downloadProvider.startDownload(
            url: directLink,
            filename: file.name,
            totalSize: file.size,
          );
          downloaded++;
        }
      } catch (e) {
        debugPrint('Download error: $e');
      }
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Started $downloaded download(s)'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _isVideo(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v']
        .contains(ext);
  }

  bool _isAudio(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['mp3', 'flac', 'wav', 'aac', 'ogg', 'm4a', 'wma'].contains(ext);
  }

  bool _isImage(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'svg'].contains(ext);
  }

  bool _isText(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['txt', 'nfo', 'log', 'md', 'json', 'xml', 'srt', 'vtt', 'sub']
        .contains(ext);
  }

  Future<void> _handleFileTap(FlatFile file) async {
    try {
      final magnetProvider = context.read<MagnetProvider>();
      final directLink = await magnetProvider.unlockLink(file.link);

      if (directLink == null) {
        throw Exception("Failed to unlock link.");
      }

      if (!mounted) return;

      if (_isVideo(file.name)) {
        // Internal Player
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              url: directLink,
              title: file.name,
            ),
          ),
        );
      } else if (_isAudio(file.name)) {
        // External Player (System)
        await launchUrl(Uri.parse(directLink),
            mode: LaunchMode.externalApplication);
      } else if (_isImage(file.name)) {
        // Internal Image Viewer
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FullScreenImage(url: directLink, title: file.name),
          ),
        );
      } else if (_isText(file.name)) {
        // Internal Text Viewer
        if (file.size > 5 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File too large to preview')),
          );
          return;
        }

        // Fetch content
        try {
          final dio = Dio();
          final response = await dio.get<String>(
            directLink,
            options: Options(responseType: ResponseType.plain),
          );
          if (response.statusCode == 200 && response.data != null && mounted) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => _TextFileViewer(
                filename: file.name,
                content: response.data!,
              ),
            );
          }
        } catch (e) {
          debugPrint("Fetch text error: $e");
        }
      } else {
        // Default external
        await launchUrl(Uri.parse(directLink),
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error opening file: $e'),
              backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReady = widget.magnet.statusCode == 4;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header (Modified)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_linkedImdb != null &&
                          _linkedImdb!.posterUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: _linkedImdb!.posterUrl,
                            width: 60,
                            height: 90,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const SizedBox(),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _linkedImdb != null
                                  ? _linkedImdb!.title
                                  : widget.magnet.filename,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_linkedImdb != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${_linkedImdb!.year} • ${_linkedImdb!.kind?.toUpperCase() ?? "MEDIA"}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isReady
                                        ? AppTheme.successColor
                                            .withValues(alpha: 0.15)
                                        : AppTheme.primaryColor
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    widget.magnet.magnetStatusCode.label
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: isReady
                                          ? AppTheme.successColor
                                          : AppTheme.primaryColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatBytes(widget.magnet.size),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Compact Action Buttons
                      Column(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, size: 20),
                            color: AppTheme.textMuted,
                          ),
                          // Compact Identify Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showMagnetLinkModal,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                child: Icon(
                                  _linkedImdb == null
                                      ? Icons.movie_filter_rounded
                                      : Icons.refresh_rounded,
                                  size: 20,
                                  color: AppTheme.accentColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Download Button (Full Width)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selectedFiles.isNotEmpty && isReady
                          ? _downloadSelected
                          : null,
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: Text(_selectedFiles.isEmpty
                          ? 'SELECT FILES TO DOWNLOAD'
                          : 'DOWNLOAD (${_selectedFiles.length}) ITEMS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor:
                            AppTheme.textMuted.withValues(alpha: 0.2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Files List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: TextStyle(color: AppTheme.errorColor),
                          ),
                        )
                      : _files.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.folder_off_rounded,
                                      size: 48,
                                      color: AppTheme.textMuted
                                          .withValues(alpha: 0.3)),
                                  const SizedBox(height: 16),
                                  Text(
                                    isReady
                                        ? "No files found"
                                        : "Magnet processing...",
                                    style: const TextStyle(
                                        color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: [
                                // Select All
                                if (_files.isNotEmpty && isReady)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 8),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: _selectedFiles.length ==
                                              _files.length,
                                          onChanged: (_) => _toggleSelectAll(),
                                          activeColor: AppTheme.primaryColor,
                                        ),
                                        const Text(
                                          'Select All',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // File List
                                Expanded(
                                  child: ListView.builder(
                                    controller: scrollController,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20),
                                    itemCount: _files.length,
                                    itemBuilder: (context, index) {
                                      final file = _files[index];
                                      final isSelected =
                                          _selectedFiles.contains(file.link);

                                      final isPlayable = _isVideo(file.name) ||
                                          _isAudio(file.name) ||
                                          _isImage(file.name) ||
                                          _isText(file.name);

                                      final actionIcon = _isVideo(file.name)
                                          ? Icons.play_circle_outline_rounded
                                          : Icons.remove_red_eye_rounded;

                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                                  .withValues(alpha: 0.1)
                                              : AppTheme.surfaceColor
                                                  .withValues(alpha: 0.5),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppTheme.primaryColor
                                                : Colors.transparent,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: isReady
                                                ? () {
                                                    setState(() {
                                                      if (isSelected) {
                                                        _selectedFiles
                                                            .remove(file.link);
                                                      } else {
                                                        _selectedFiles
                                                            .add(file.link);
                                                      }
                                                    });
                                                  }
                                                : null,
                                            onLongPress: isReady
                                                ? () {
                                                    setState(() {
                                                      if (isSelected) {
                                                        _selectedFiles
                                                            .remove(file.link);
                                                      } else {
                                                        _selectedFiles
                                                            .add(file.link);
                                                      }
                                                    });
                                                  }
                                                : null,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 12),
                                              child: Row(
                                                children: [
                                                  // Fixed Checkbox
                                                  if (isReady)
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              right: 12),
                                                      child: SizedBox(
                                                        width: 24,
                                                        height: 24,
                                                        child: Checkbox(
                                                          value: isSelected,
                                                          onChanged: (value) {
                                                            setState(() {
                                                              if (value ==
                                                                  true) {
                                                                _selectedFiles
                                                                    .add(file
                                                                        .link);
                                                              } else {
                                                                _selectedFiles
                                                                    .remove(file
                                                                        .link);
                                                              }
                                                            });
                                                          },
                                                          activeColor: AppTheme
                                                              .primaryColor,
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          4)),
                                                        ),
                                                      ),
                                                    ),

                                                  // File Icon (Uniform Color & Size)
                                                  Icon(
                                                    getFileIconData(file.name),
                                                    size: 24,
                                                    color: AppTheme.textMuted
                                                        .withValues(
                                                            alpha:
                                                                0.7), // Consistent color
                                                  ),
                                                  const SizedBox(width: 12),

                                                  // File Info
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          file.name,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color: isSelected
                                                                ? AppTheme
                                                                    .primaryColor
                                                                : AppTheme
                                                                    .textPrimary,
                                                          ),
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                        const SizedBox(
                                                            height: 4),
                                                        Text(
                                                          formatBytes(
                                                              file.size),
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 11,
                                                            color: AppTheme
                                                                .textMuted,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  // Trailing Action Button (Quick Play/Preview)
                                                  if (isReady && isPlayable)
                                                    Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        onTap: () =>
                                                            _handleFileTap(
                                                                file),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(8),
                                                          child: Icon(
                                                            actionIcon,
                                                            size: 30,
                                                            color: AppTheme
                                                                .accentColor,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
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

  IconData getFileIconData(String filename) {
    if (_isVideo(filename)) return Icons.movie_outlined;
    if (_isAudio(filename)) return Icons.audiotrack_outlined;
    if (_isImage(filename)) return Icons.image_outlined;
    if (_isText(filename)) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Color getFileIconColor(String filename) {
    // Returning consistent color as requested, but keeping method if needed later or just used for icons that shouldn't be plain
    return AppTheme.textMuted;
  }
}

class _FullScreenImage extends StatelessWidget {
  final String url;
  final String title;

  const _FullScreenImage({required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded,
                    color: Colors.white54, size: 64),
                SizedBox(height: 16),
                Text('Failed to load image',
                    style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TextFileViewer extends StatelessWidget {
  final String filename;
  final String content;

  const _TextFileViewer({required this.filename, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: AppTheme.borderColor.withValues(alpha: 0.5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'FILE PREVIEW',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        filename,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                content,
                style: GoogleFonts.robotoMono(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImdbSearchSheet extends StatefulWidget {
  final String initialQuery;
  final Function(ImdbSearchResult) onSelect;

  const _ImdbSearchSheet({required this.initialQuery, required this.onSelect});

  @override
  State<_ImdbSearchSheet> createState() => _ImdbSearchSheetState();
}

class _ImdbSearchSheetState extends State<_ImdbSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  final ImdbService _service = ImdbService();
  List<ImdbSearchResult> _results = [];
  bool _loading = false;
  String? _error;
  bool _isLinkingSelection = false;
  String? _linkingId;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialQuery;
    if (widget.initialQuery.isNotEmpty) {
      _search(widget.initialQuery);
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await _service.search(query);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = "Search failed, please try again.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleSelect(ImdbSearchResult item) async {
    if (_isLinkingSelection) return;
    setState(() {
      _isLinkingSelection = true;
      _linkingId = item.id;
    });

    try {
      final details = await _service.fetchDetails(item.id);
      final enriched = item.copyWith(
        rating: details.rating ?? item.rating,
        description: details.description ?? item.description,
        genres: details.genres ?? item.genres,
        duration: details.duration ?? item.duration,
        ratingCount: details.ratingCount ?? item.ratingCount,
        stars: details.stars ?? item.stars,
        videoId: details.videoId ?? item.videoId,
        releaseDate: details.releaseDate ?? item.releaseDate,
        country: details.country ?? item.country,
        languages: details.languages ?? item.languages,
        kind: details.kind ?? item.kind,
      );
      widget.onSelect(enriched);
    } catch (e) {
      debugPrint('Failed to enrich IMDB selection: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLinkingSelection = false;
          _linkingId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height *
          0.75, // Increased height for better UX
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, -10),
          )
        ],
      ),
      child: Column(
        children: [
          // Drag Handle & Header
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.movie_filter_rounded,
                      color: Colors.amber, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Link Metadata',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textMuted),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppTheme.borderColor.withValues(alpha: 0.5)),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: AppTheme.textPrimary),
                autofocus: true,
                onChanged: (text) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Search movie or TV show...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  prefixIcon:
                      const Icon(Icons.search, color: AppTheme.textMuted),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              color: AppTheme.textMuted),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _results = [];
                            });
                          },
                        )
                      : IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded,
                              color: AppTheme.primaryColor),
                          onPressed: () => _search(_controller.text),
                        ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: _search,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Results
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline_rounded,
                                color:
                                    AppTheme.errorColor.withValues(alpha: 0.5),
                                size: 48),
                            const SizedBox(height: 16),
                            Text(_error!,
                                style:
                                    const TextStyle(color: AppTheme.textMuted)),
                          ],
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded,
                                    color: AppTheme.textMuted
                                        .withValues(alpha: 0.3),
                                    size: 48),
                                const SizedBox(height: 16),
                                const Text("Search to find matches",
                                    style:
                                        TextStyle(color: AppTheme.textMuted)),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(20),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.7,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              final isSelecting =
                                  _linkingId != null && _linkingId == item.id;
                              return InkWell(
                                onTap: () => _handleSelect(item),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        CachedNetworkImage(
                                          imageUrl: item.posterUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              Container(
                                            color: AppTheme.surfaceColor,
                                            child: const Center(
                                              child: Icon(Icons.movie_outlined,
                                                  color: AppTheme.textMuted),
                                            ),
                                          ),
                                        ),
                                        // Gradient overlay
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.transparent,
                                                Colors.black
                                                    .withValues(alpha: 0.8),
                                              ],
                                              stops: const [0.6, 1.0],
                                            ),
                                          ),
                                        ),
                                        // Title overlay
                                        Positioned(
                                          bottom: 8,
                                          left: 8,
                                          right: 8,
                                          child: Text(
                                            item.title,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        // Year Badge
                                        if (item.year.isNotEmpty)
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withValues(alpha: 0.65),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.15),
                                                    width: 0.5),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(alpha: 0.2),
                                                    blurRadius: 4,
                                                    spreadRadius: 0,
                                                  )
                                                ],
                                              ),
                                              child: Text(
                                                item.year,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (isSelecting)
                                          Container(
                                            color: Colors.black
                                                .withValues(alpha: 0.6),
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
