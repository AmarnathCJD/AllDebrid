import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/common_widgets.dart';
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

          // Compact Total Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Text(
              '${provider.magnets.length}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppTheme.primaryColor,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Delete All Button
          if (provider.magnets.isNotEmpty)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _confirmDeleteAll(provider),
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      size: 20, color: AppTheme.errorColor),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSegmentedTabs(MagnetProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.borderColor),
        ),
        padding: const EdgeInsets.all(4),
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
    ).animate().fadeIn(delay: 100.ms, duration: 300.ms);
  }

  Widget _buildTabItem(String label, int index, int count) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
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
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withOpacity(0.2)
                          : AppTheme.surfaceColor,
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
                size: 48, color: AppTheme.textMuted.withOpacity(0.5)),
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
                  color: AppTheme.errorColor.withOpacity(0.1),
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
                  color: AppTheme.errorColor.withOpacity(0.1),
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
              // Background progress fill (subtle)
              if (!isReady && progress > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: MediaQuery.of(context).size.width * progress,
                  child: Container(
                    color: statusColor.withOpacity(0.04),
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
                        // Status Icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isReady
                                ? Icons.check_circle_outline
                                : Icons.downloading_rounded,
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
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  // Status Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: statusColor.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      magnet.magnetStatusCode.label
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formatBytes(magnet.size),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Actions
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onDelete,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              height: 40,
                              width: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppTheme.errorColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.delete_outline_rounded,
                                  size: 20, color: AppTheme.errorColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!isReady) ...[
                      const SizedBox(height: 16),
                      // Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppTheme.surfaceColor,
                          color: statusColor,
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Stats
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniStat(
                              Icons.people_outline, '${magnet.seeders} SEEDS'),
                          _buildMiniStat(Icons.speed,
                              '${formatSpeed(magnet.downloadSpeed).toUpperCase()}'),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
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
      ),
    ).animate().fadeIn(delay: (30 * index).ms, duration: 250.ms);
  }

  Widget _buildMiniStat(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppTheme.textMuted,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}
