import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';

import '../../utils/helpers.dart';
import 'magnet_files_screen.dart';

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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => MagnetFilesScreen(magnet: magnet)),
            ),
            onDelete: () => _confirmDelete(magnet, provider),
          );
        },
      ),
    );
  }

  void _confirmDelete(dynamic magnet, MagnetProvider provider) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline_rounded,
                    size: 32, color: AppTheme.errorColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Magnet?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to remove this magnet? This action cannot be undone.',
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
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        provider.deleteMagnet(magnet.id.toString());
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('DELETE'),
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

  void _confirmDeleteAll(MagnetProvider provider) {
    if (provider.magnets.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_forever_rounded,
                    size: 32, color: AppTheme.errorColor),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete All Magnets?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This will remove ALL magnets from your account. This is strictly irreversible.',
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
                      child: Text(
                        'CANCEL',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Delete all logic - iterate and delete
                        for (var m in provider.magnets) {
                          provider.deleteMagnet(m.id.toString());
                        }
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('DELETE ALL'),
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

    return Container(
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
                                              child: CircularProgressIndicator(
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
                              color: AppTheme.errorColor.withValues(alpha: 0.1),
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
                                      color: statusColor.withValues(alpha: 0.4),
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
