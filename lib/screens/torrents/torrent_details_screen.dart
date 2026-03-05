import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_theme.dart';
import '../../models/torrent.dart';
import '../../services/torrent_scraper_service.dart';
import '../../providers/magnet_provider.dart';

// Torrent Details Screen
class TorrentDetailsScreen extends StatefulWidget {
  final TorrentEntry entry;
  final TorrentScraperService scraperService;

  const TorrentDetailsScreen({
    super.key,
    required this.entry,
    required this.scraperService,
  });

  @override
  State<TorrentDetailsScreen> createState() => _TorrentDetailsScreenState();
}

class _TorrentDetailsScreenState extends State<TorrentDetailsScreen> {
  List<TorrentDownload> _downloads = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDownloads();
  }

  Future<void> _loadDownloads() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final downloads = await widget.scraperService.fetchTorrentLinks(
        widget.entry.url,
        source: widget.entry.source,
        infoHash: widget.entry.infoHash,
      );
      if (mounted) {
        setState(() {
          _downloads = downloads;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(widget.entry.title.toUpperCase()),
        titleTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.errorColor, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.error_outline,
                    size: 40, color: AppTheme.errorColor),
              ),
              const SizedBox(height: 20),
              Text(
                'ERROR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.errorColor,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadDownloads,
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    if (_downloads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderColor, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.download_outlined,
                  size: 40, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'NO DOWNLOADS',
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AVAILABLE DOWNLOADS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMuted,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                ...(_downloads.asMap().entries.map((entry) {
                  final index = entry.key;
                  final download = entry.value;
                  return Consumer<MagnetProvider>(
                    builder: (context, magnetProvider, _) {
                      final magnetHash = RegExp(r'btih:([a-fA-F0-9]+)')
                          .firstMatch(download.magnetLink)
                          ?.group(1)
                          ?.toUpperCase();
                      final isAdded = magnetHash != null &&
                          magnetProvider.magnets.any((magnet) =>
                              magnet.hash.toUpperCase() == magnetHash);

                      return DownloadCard(
                        download: download,
                        index: index,
                        isAdded: isAdded,
                        onAddMagnet: () => _addToMagnet(download),
                        onRemoveMagnet: () =>
                            _removeMagnet(download, magnetProvider),
                      );
                    },
                  );
                }).toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToMagnet(TorrentDownload download) async {
    try {
      await context.read<MagnetProvider>().uploadMagnet(download.magnetLink);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${download.name}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _removeMagnet(
      TorrentDownload download, MagnetProvider magnetProvider) async {
    try {
      await magnetProvider.refreshMagnets(showLoading: false);

      final magnetHash = RegExp(r'btih:([a-fA-F0-9]+)')
          .firstMatch(download.magnetLink)
          ?.group(1)
          ?.toUpperCase();
      if (magnetHash == null) {
        throw Exception('Invalid magnet link');
      }

      final magnetList = magnetProvider.magnets;
      final magnetItem = magnetList.firstWhere(
        (magnet) => magnet.hash.toUpperCase() == magnetHash,
        orElse: () => throw Exception('Magnet not found'),
      );

      await magnetProvider.deleteMagnet(magnetItem.id.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed ${download.name}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

// Download Card Widget
class DownloadCard extends StatelessWidget {
  final TorrentDownload download;
  final int index;
  final bool isAdded;
  final VoidCallback onAddMagnet;
  final VoidCallback onRemoveMagnet;

  const DownloadCard({
    super.key,
    required this.download,
    required this.index,
    required this.isAdded,
    required this.onAddMagnet,
    required this.onRemoveMagnet,
  });

  Map<String, String?> _extractMetadata(String name) {
    final quality =
        RegExp(r'\b(2160p|4K|1080p|720p|480p|360p)\b', caseSensitive: false)
            .firstMatch(name)
            ?.group(1)
            ?.toUpperCase();

    final source = RegExp(
            r'\b(HDRip|WEBRip|BluRay|CAMRip|PreDVD|WEB-DL|HDTV|DVDRip)\b',
            caseSensitive: false)
        .firstMatch(name)
        ?.group(1)
        ?.toUpperCase();

    return {'quality': quality, 'source': source};
  }

  String _cleanTitle(String name) {
    return name
        .replaceAll(
            RegExp(r'\s*-\s*(1080p|720p|480p|4K|2160p).*$',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\s*\(\d{4}\)', caseSensitive: false), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final metadata = _extractMetadata(download.name);
    final cleanTitle = _cleanTitle(download.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              cleanTitle,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                height: 1.3,
              ),
            ),
          ),

          Divider(height: 1, color: AppTheme.borderColor.withValues(alpha: 0.5)),

          // Details & Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Badges
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (metadata['quality'] != null)
                            _QualityBadge(
                                text: metadata['quality']!,
                                color: AppTheme.primaryColor),
                          if (metadata['source'] != null)
                            _QualityBadge(
                                text: metadata['source']!,
                                color: AppTheme.accentColor),
                          _QualityBadge(
                              text: download.size, color: AppTheme.textMuted),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: isAdded
                          ? OutlinedButton.icon(
                              onPressed: onRemoveMagnet,
                              icon: const Icon(Icons.check_circle_rounded,
                                  size: 18),
                              label: const Text('ADDED'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.successColor,
                                side: BorderSide(color: AppTheme.successColor),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: onAddMagnet,
                              icon:
                                  const Icon(Icons.download_rounded, size: 18),
                              label: const Text('DOWNLOAD'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: download.magnetLink));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Magnet link copied'),
                            backgroundColor: AppTheme.successColor,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                        foregroundColor: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (40 * index).ms, duration: 300.ms);
  }
}

class _QualityBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _QualityBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
