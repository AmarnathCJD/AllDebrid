import 'package:flutter/foundation.dart';
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
  final Set<String> _expandedShows = {};

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

      var link = await _imdbService.getLink(download.filename);

      if (link != null) {
        if (link.description == null ||
            link.rating == null ||
            link.kind == null) {
          try {
            final details = await _imdbService.fetchDetails(link.id);

            link = link.copyWith(
              rating: details.rating,
              description: details.description,
              genres: details.genres,
              duration: details.duration,
              ratingCount: details.ratingCount,
              releaseDate: details.releaseDate,
              country: details.country,
              languages: details.languages,
              stars: details.stars,
              videoId: details.videoId,
              kind: details.kind ?? link.kind,
            );
            await _imdbService.saveLink(download.filename, link);
          } catch (e) {
            // ignore
          }
        }

        if (mounted) {
          setState(() {
            _imdbCache[download.filename] = link!;
          });
          debugPrint(
              '[Downloads] Cached ${download.filename} kind=${link?.kind} season=${link?.season} episode=${link?.episode}');
        }
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
                    child: RefreshIndicator(
                      onRefresh: () async {
                        final provider = context.read<DownloadProvider>();
                        await provider.initialize();
                        _loadImdbInfo(provider.downloads);
                      },
                      color: AppTheme.primaryColor,
                      backgroundColor: AppTheme.cardColor,
                      child:
                          _buildGroupedDownloads(downloads, downloadProvider),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupedDownloads(
      List<dynamic> downloads, DownloadProvider provider) {
    // Group downloads by IMDb ID for TV shows
    final Map<String, List<dynamic>> tvShowGroups = {};
    final List<dynamic> standaloneItems = [];

    for (final download in downloads) {
      final imdb = _imdbCache[download.filename];
      if (imdb != null) {
        final kind = imdb.kind?.toLowerCase();
        final isTv = kind == 'tvseries' ||
            kind == 'tv series' ||
            kind == 'series' ||
            kind == 'tvepisode';
        if (isTv) {
          final key = imdb.id;
          tvShowGroups.putIfAbsent(key, () => []);
          tvShowGroups[key]!.add(download);
        } else {
          standaloneItems.add(download);
        }
      } else {
        standaloneItems.add(download);
      }
    }

    // Sort episodes within each TV show
    tvShowGroups.forEach((key, episodes) {
      episodes.sort((a, b) {
        final imdbA = _imdbCache[a.filename]!;
        final imdbB = _imdbCache[b.filename]!;
        final seasonCompare = (imdbA.season ?? 0).compareTo(imdbB.season ?? 0);
        if (seasonCompare != 0) return seasonCompare;
        return (imdbA.episode ?? 0).compareTo(imdbB.episode ?? 0);
      });
    });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: tvShowGroups.length + standaloneItems.length,
      itemBuilder: (context, index) {
        if (index < tvShowGroups.length) {
          // TV Show Group
          final showId = tvShowGroups.keys.elementAt(index);
          final episodes = tvShowGroups[showId]!;
          final firstEpisode = episodes.first;
          final imdb = _imdbCache[firstEpisode.filename]!;
          final isExpanded = _expandedShows.contains(showId);

          // Calculate total size of all episodes
          int totalEpisodeSize = 0;
          for (final ep in episodes) {
            totalEpisodeSize += ep.totalSize as int;
          }

          return Column(
            children: [
              // TV Show Header - Full sized with poster
              InkWell(
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedShows.remove(showId);
                    } else {
                      _expandedShows.add(showId);
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12, top: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppTheme.borderColor.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster hero section
                      if (imdb.posterUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(14),
                            topRight: Radius.circular(14),
                          ),
                          child: Stack(
                            children: [
                              Image.network(
                                imdb.posterUrl,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: double.infinity,
                                  height: 200,
                                  color: AppTheme.surfaceColor,
                                  child: const Icon(Icons.tv, size: 40),
                                ),
                              ),
                              // Gradient overlay
                              Container(
                                width: double.infinity,
                                height: 200,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.3),
                                      Colors.black.withOpacity(0.6),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              topRight: Radius.circular(14),
                            ),
                          ),
                          child: const Icon(Icons.tv, size: 40),
                        ),
                      // Details section
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              imdb.title,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            // Year and rating
                            Row(
                              children: [
                                if (imdb.year.isNotEmpty)
                                  Expanded(
                                    child: Text(
                                      imdb.year,
                                      style: const TextStyle(
                                        color: AppTheme.textMuted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                if (imdb.rating != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor
                                          .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '★ ${imdb.rating}',
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Episode count and total size
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${episodes.length} episode${episodes.length > 1 ? 's' : ''}',
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Total: ${formatSize(totalEpisodeSize)}',
                                        style: const TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Expand button
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: AppTheme.primaryColor,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 200.ms),
              // Episodes list (when expanded)
              if (isExpanded)
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
                  child: Column(
                    children: episodes
                        .map(
                          (download) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildEpisodeCard(download, provider),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          );
        } else {
          // Standalone item
          final download = standaloneItems[index - tvShowGroups.length];
          return _buildDownloadCard(download, provider);
        }
      },
    );
  }

  Widget _buildEpisodeCard(dynamic download, DownloadProvider provider) {
    final imdb = _imdbCache[download.filename];
    final isCompleted = download.isCompleted;
    final isDownloading = !isCompleted && download.progress < 1.0;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // Progress bar (if downloading)
          if (isDownloading)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              child: LinearProgressIndicator(
                value: download.progress,
                minHeight: 3,
                backgroundColor: AppTheme.borderColor,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    // S/E Badge
                    if (imdb?.season != null && imdb?.episode != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'S${imdb!.season.toString().padLeft(2, '0')}E${imdb.episode.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    // Filename and info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            download.filename,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isDownloading)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                '${(download.progress * 100).toStringAsFixed(0)}% • ${formatSize(download.downloadedSize)} / ${formatSize(download.totalSize)}',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 9,
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                formatSize(download.totalSize),
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Action buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // If downloading: Play, Pause, Stop buttons
                        if (isDownloading) ...[
                          // Play button (green)
                          if (isVideoFile(download.filename) ||
                              isAudioFile(download.filename))
                            Tooltip(
                              message: 'Play',
                              child: InkWell(
                                onTap: () async {
                                  if (imdb != null) {
                                    await _imdbService.addToRecents(imdb);
                                  }
                                  if (context.mounted) {
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
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.green.shade400.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.play_arrow,
                                    size: 14,
                                    color: Colors.green.shade400,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          // Pause button (yellow/amber)
                          Tooltip(
                            message: download.isPaused ? 'Resume' : 'Pause',
                            child: InkWell(
                              onTap: download.isPaused
                                  ? () => context
                                      .read<DownloadProvider>()
                                      .resumeDownload(download.id)
                                  : () => context
                                      .read<DownloadProvider>()
                                      .pauseDownload(download.id),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFFF59E0B).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  download.isPaused
                                      ? Icons.play_arrow
                                      : Icons.pause,
                                  size: 14,
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Stop button (red)
                          Tooltip(
                            message: 'Stop',
                            child: InkWell(
                              onTap: () => _confirmDeleteEpisode(
                                context,
                                provider,
                                download,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.stop,
                                  size: 14,
                                  color: AppTheme.errorColor,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // If completed: Play, Browse, Delete buttons
                          // Play button (green)
                          if (isVideoFile(download.filename) ||
                              isAudioFile(download.filename))
                            Tooltip(
                              message: 'Play',
                              child: InkWell(
                                onTap: () async {
                                  if (imdb != null) {
                                    await _imdbService.addToRecents(imdb);
                                  }
                                  if (context.mounted) {
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
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    size: 14,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          // Browse button (surface)
                          Tooltip(
                            message: 'Open folder',
                            child: InkWell(
                              onTap: () => OpenFilex.open(
                                download.savePath,
                                type: 'resource/folder',
                              ),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppTheme.borderColor,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.folder_open,
                                  size: 14,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Delete button (red)
                          Tooltip(
                            message: 'Delete',
                            child: InkWell(
                              onTap: () => _confirmDeleteEpisode(
                                context,
                                provider,
                                download,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 14,
                                  color: AppTheme.errorColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteEpisode(
    BuildContext context,
    DownloadProvider provider,
    dynamic download,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Delete Episode?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Are you sure you want to delete "${download.filename}"?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      provider.removeDownload(download.id);
    }
  }

  Widget _buildDownloadCard(dynamic download, DownloadProvider provider) {
    final imdb = _imdbCache[download.filename];

    return DownloadCard(
      filename: download.filename,
      progress: download.progress,
      downloadedSize: download.downloadedSize,
      totalSize: download.totalSize,
      speed: download.speed,
      status: download.status.toString().split('.').last,
      isPaused: download.isPaused,
      isCompleted: download.isCompleted,
      isFailed: download.isFailed,
      onPause: () =>
          context.read<DownloadProvider>().pauseDownload(download.id),
      onResume: () =>
          context.read<DownloadProvider>().resumeDownload(download.id),
      onCancel: () => _confirmDelete(context, provider, download),
      onDelete: () => _confirmDelete(context, provider, download),
      onOpen: () => OpenFilex.open(download.savePath),
      onStream: isVideoFile(download.filename) || isAudioFile(download.filename)
          ? () async {
              if (imdb != null) {
                await _imdbService.addToRecents(imdb);
              }
              if (context.mounted) {
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
            }
          : null,
      posterUrl: imdb?.posterUrl,
      imdbTitle: imdb?.title,
      imdbYear: imdb?.year,
      imdbId: imdb?.id,
      imdbRating: imdb?.rating,
      description: imdb?.description,
      videoId: imdb?.videoId,
      stars: imdb?.stars,
      genres: imdb?.genres,
      duration: imdb?.duration,
      ratingCount: imdb?.ratingCount,
      season: imdb?.season,
      episode: imdb?.episode,
    ).animate().fadeIn(duration: 200.ms);
  }

  Future<void> _confirmDelete(
      BuildContext context, DownloadProvider provider, dynamic download) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Delete Download?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Are you sure you want to delete "${download.filename}"?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      provider.removeDownload(download.id);
    }
  }

  Widget _buildHeader(BuildContext context, DownloadProvider provider) {
    final hasCompleted = provider.downloads.any((d) => d.isCompleted);

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
          if (hasCompleted)
            _buildHeaderAction(
              context,
              Icons.cleaning_services_rounded,
              AppTheme.accentColor,
              'Clean Completed',
              provider.clearCompleted,
              isFilled: true,
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildHeaderAction(
    BuildContext context,
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onTap, {
    bool isFilled = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isFilled ? color : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isFilled
                      ? Colors.transparent
                      : color.withValues(alpha: 0.3)),
            ),
            child: Icon(
              icon,
              color: isFilled ? Colors.white : color,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}
