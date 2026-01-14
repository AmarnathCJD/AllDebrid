import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../services/imdb_service.dart';

import 'package:open_filex/open_filex.dart';
import '../../widgets/common/common_widgets.dart';
import '../../widgets/common/download_card.dart';
import '../../utils/helpers.dart';
import '../player/player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final ImdbService _imdbService = ImdbService();
  final Map<String, ImdbSearchResult> _imdbCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DownloadProvider>();
      provider.initialize().then((_) => _loadImdbInfo(provider.downloads));
    });
  }

  Future<void> _loadImdbInfo(List<dynamic> downloads) async {
    for (var download in downloads) {
      if (_imdbCache.containsKey(download.filename)) continue;
      final link = await _imdbService.getLink(download.filename);
      if (link != null && mounted) {
        setState(() {
          _imdbCache[download.filename] = link;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Consumer<DownloadProvider>(
          builder: (context, downloadProvider, _) {
            final downloads = downloadProvider.downloads;

            // Trigger load if new downloads appeared or list changed size
            if (downloads.length > _imdbCache.length) {
              _loadImdbInfo(downloads);
            }

            return Column(
              children: [
                _buildHeader(context, downloadProvider),
                if (downloads.isEmpty)
                  const Expanded(
                    child: EmptyState(
                      icon: Icons.download_done_rounded,
                      title: 'No Downloads',
                      subtitle: 'Downloads will appear here',
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: downloads.length,
                      itemBuilder: (context, index) {
                        final download = downloads[index];
                        return DownloadCard(
                          filename: download.filename,
                          progress: download.progress,
                          downloadedSize: download.downloadedSize,
                          totalSize: download.totalSize,
                          speed: download.speed,
                          status: download.status.name,
                          isPaused: download.isPaused,
                          isCompleted: download.isCompleted,
                          isFailed: download.isFailed,
                          onPause: () => context
                              .read<DownloadProvider>()
                              .pauseDownload(download.id),
                          onResume: () => context
                              .read<DownloadProvider>()
                              .resumeDownload(download.id),
                          onCancel: () => context
                              .read<DownloadProvider>()
                              .removeDownload(download.id),
                          onDelete: () => context
                              .read<DownloadProvider>()
                              .removeDownload(download.id),
                          onOpen: () => OpenFilex.open(download.savePath),
                          onStream: isVideoFile(download.filename) ||
                                  isAudioFile(download.filename)
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PlayerScreen(
                                        url: download.savePath,
                                        title: download.filename,
                                        isLocal: true,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                          posterUrl: _imdbCache[download.filename]?.posterUrl,
                          imdbTitle: _imdbCache[download.filename]?.title,
                          imdbYear: _imdbCache[download.filename]?.year,
                        ).animate().fadeIn(delay: (50 * index).ms).slideX();
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, DownloadProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('YOUR',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                        letterSpacing: 1.5)),
                const Text('DOWNLOADS',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        height: 1,
                        color: AppTheme.textPrimary)),
              ],
            ),
          ),
          if (provider.downloads.any((d) => d.isCompleted))
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => provider.clearCompleted(),
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cleaning_services_rounded,
                          size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      const Text('CLEAN',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
