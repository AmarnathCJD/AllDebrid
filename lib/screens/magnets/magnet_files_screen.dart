import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/common_widgets.dart';
import '../../utils/helpers.dart';
import '../../services/imdb_service.dart';
import '../player/player_screen.dart';
import 'package:http/http.dart' as http;

class MagnetFilesScreen extends StatefulWidget {
  final MagnetStatus magnet;

  const MagnetFilesScreen({super.key, required this.magnet});

  @override
  State<MagnetFilesScreen> createState() => _MagnetFilesScreenState();
}

class _MagnetFilesScreenState extends State<MagnetFilesScreen> {
  bool _isLoading = true;
  List<FlatFile> _files = [];
  String? _error;
  final Map<String, ImdbSearchResult> _imdbLinks = {};
  final ImdbService _imdbService = ImdbService();

  @override
  void initState() {
    super.initState();
    _loadFiles();
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
        await _loadImdbLinks();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadImdbLinks() async {
    for (var file in _files) {
      var link = await _imdbService.getLink(file.name);
      if (link != null) {
        link = link.copyWith(magnetId: widget.magnet.id.toString());
        // await _imdbService.addToRecents(link);
        if (mounted) {
          setState(() {
            _imdbLinks[file.name] = link!;
          });
        }
      }
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

  Future<void> _linkImdb(String filename, ImdbSearchResult result) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Fetching details...'),
        duration: Duration(milliseconds: 500)));

    ImdbSearchResult fullResult = result;
    if (result.description == null ||
        result.rating == null ||
        result.kind == null ||
        result.genres == null) {
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
    }

    fullResult = fullResult.copyWith(magnetId: widget.magnet.id.toString());

    // Check if it's a TV show and parse season/episode from filename
    final kind = fullResult.kind?.toLowerCase();
    final isTvShow = kind == 'tvseries' ||
        kind == 'tv series' ||
        kind == 'series' ||
        kind == 'tvepisode';

    if (isTvShow) {
      final (parsedSeason, parsedEpisode) = _parseSeasonEpisode(filename);
      if (parsedSeason != null && parsedEpisode != null) {
        // Show dialog for user confirmation/editing
        if (mounted) {
          await _showSeasonEpisodeDialog(
              filename, fullResult, parsedSeason, parsedEpisode);
          return; // Dialog will handle saving
        }
      }
    }

    // For non-TV or TV without season/episode info, save normally
    debugPrint(
        '[IMDB] Linking $filename to ${fullResult.title} kind=${fullResult.kind}');

    await _imdbService.saveLink(filename, fullResult);
    await _imdbService.addToRecents(fullResult);

    if (mounted) {
      setState(() {
        _imdbLinks[filename] = fullResult;
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Linked to ${fullResult.title}'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showSeasonEpisodeDialog(
    String filename,
    ImdbSearchResult imdbResult,
    int initialSeason,
    int initialEpisode,
  ) async {
    int? selectedSeason = initialSeason;
    int? selectedEpisode = initialEpisode;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Episode Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filename
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Text(
                    filename,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 20),
                // Season & Episode Selectors
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SEASON',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.borderColor,
                                width: 1,
                              ),
                            ),
                            child: DropdownButton<int>(
                              value: selectedSeason,
                              isExpanded: true,
                              underline: const SizedBox(),
                              dropdownColor: AppTheme.cardColor,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                              items: List.generate(20, (i) => i + 1)
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text('Season $s'),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => selectedSeason = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EPISODE',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.backgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.borderColor,
                                width: 1,
                              ),
                            ),
                            child: DropdownButton<int>(
                              value: selectedEpisode,
                              isExpanded: true,
                              underline: const SizedBox(),
                              dropdownColor: AppTheme.cardColor,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                              ),
                              items: List.generate(50, (i) => i + 1)
                                  .map((e) => DropdownMenuItem(
                                        value: e,
                                        child: Text('Episode $e'),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setDialogState(() => selectedEpisode = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ElevatedButton(
                        onPressed: selectedSeason != null &&
                                selectedEpisode != null
                            ? () async {
                                Navigator.pop(context);
                                // Save with season and episode
                                final linkedResult = imdbResult.copyWith(
                                  season: selectedSeason,
                                  episode: selectedEpisode,
                                );
                                debugPrint(
                                    '[IMDB] Linking $filename to ${linkedResult.title} S${selectedSeason}E${selectedEpisode} kind=${linkedResult.kind}');
                                await _imdbService.saveLink(
                                    filename, linkedResult);
                                await _imdbService.addToRecents(linkedResult);

                                if (mounted) {
                                  setState(() {
                                    _imdbLinks[filename] = linkedResult;
                                  });
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Linked to ${linkedResult.title} S${selectedSeason.toString().padLeft(2, '0')}E${selectedEpisode.toString().padLeft(2, '0')}'),
                                      backgroundColor: AppTheme.successColor,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
    );
  }

  void _showImdbSearchModal(String filename) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ImdbSearchSheet(
        initialQuery: filename,
        onSelect: (result) => _linkImdb(filename, result),
      ),
    );
  }

  bool _isStreamable(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['mp4', 'mkv', 'avi', 'mov', 'wmv', 'mp3', 'flac'].contains(ext);
  }

  bool _isImage(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  bool _isText(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return ['txt', 'nfo', 'log', 'md', 'json', 'xml', 'srt', 'vtt', 'sub']
        .contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (_isLoading)
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: 6,
                  itemBuilder: (_, __) => const SkeletonCard(height: 80),
                ),
              )
            else if (_error != null)
              Expanded(
                  child: Center(
                      child: Text(_error!,
                          style: const TextStyle(color: AppTheme.errorColor))))
            else if (_files.isEmpty)
              const Expanded(
                  child: EmptyState(
                icon: Icons.folder_off_outlined,
                title: 'No Files Found',
                subtitle: 'This magnet link has no files',
              ))
            else
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    return _buildFileItem(_files[index], index);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final status = widget.magnet.statusCode;
    final isDownloading =
        status == 0 || status == 1 || status == 2 || status == 3;
    final progress = (widget.magnet.size > 0 && widget.magnet.downloaded > 0)
        ? (widget.magnet.downloaded / widget.magnet.size)
        : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
            bottom:
                BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Back button + Meta info
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      size: 20, color: AppTheme.textPrimary),
                ),
              ),
              const Spacer(),
              // File count + Size Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_open_rounded,
                        size: 12, color: AppTheme.primaryColor),
                    const SizedBox(width: 4),
                    Text(
                      '${_files.length} ITEMS • ${formatBytes(widget.magnet.size)}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Title Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'FILES IN',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.magnet.filename,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.1,
              letterSpacing: -0.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 24),

          // Action Buttons (Compact Row)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildHeaderAction(
                context,
                icon: Icons.download_rounded,
                label: 'Download',
                color: AppTheme.primaryColor,
                onTap: _files.isEmpty ? null : _downloadAllFiles,
              ),
              _buildHeaderAction(
                context,
                icon: Icons.folder_zip_outlined,
                label: 'Zip',
                color: Colors.amber,
                onTap: _files.isEmpty ? null : _zipAllFiles,
              ),
              _buildHeaderAction(
                context,
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: AppTheme.errorColor,
                onTap: () => _confirmDelete(context),
              ),
            ],
          ),

          if (isDownloading) ...[
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: AppTheme.borderColor,
                  color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(progress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                Row(
                  children: [
                    Text(
                        '${formatBytes(widget.magnet.downloaded)} / ${formatBytes(widget.magnet.size)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                    if (widget.magnet.downloadSpeed > 0) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_downward_rounded,
                          size: 12, color: AppTheme.accentColor),
                      const SizedBox(width: 2),
                      Text(formatSpeed(widget.magnet.downloadSpeed),
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accentColor)),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderAction(BuildContext context,
      {required IconData icon,
      required String label,
      required Color color,
      VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadAllFiles() async {
    if (_files.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Starting all downloads...'),
        backgroundColor: AppTheme.infoColor,
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    int successCount = 0;
    for (var file in _files) {
      if (!mounted) break;
      // Suppress individual feedback to avoid spam
      final success = await _downloadFile(file, showFeedback: false);
      if (success) successCount++;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Started $successCount downloads'),
          backgroundColor:
              successCount > 0 ? AppTheme.successColor : AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _zipAllFiles() async {
    if (_files.isEmpty) return;

    final links = _files.map((f) => f.link).toList();
    if (links.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Creating ZIP archive...'),
        backgroundColor: AppTheme.infoColor,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final zipLink = await context.read<LinkProvider>().createZip(links);
      if (zipLink != null && mounted) {
        context.read<DownloadProvider>().startDownload(
              url: zipLink,
              filename: '${widget.magnet.filename}.zip',
            );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ZIP download started'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create ZIP: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildFileItem(FlatFile file, int index) {
    final bool canStream = _isStreamable(file.name);
    final imdbData = _imdbLinks[file.name];
    final posterUrl = imdbData?.posterUrl;
    final title = imdbData?.title ?? file.name;
    final year = imdbData?.year;

    final bool isImage = _isImage(file.name);
    final bool hasPoster = posterUrl != null && posterUrl.isNotEmpty;

    return Container(
      height: (hasPoster || isImage) ? 140 : 90,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            // LEFT: Poster or Icon area
            if (hasPoster)
              AspectRatio(
                aspectRatio: 2 / 3,
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(posterUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerRight,
                        end: Alignment.centerLeft,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else if (isImage)
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: _ImagePreview(link: file.link, filename: file.name),
                ),
              )
            else
              Container(
                width: 50, // Compact extension badge
                height: double.infinity,
                color: AppTheme.surfaceColor,
                child: Center(
                  child: _buildExtensionBadge(file.name),
                ),
              ),

            // RIGHT: Content
            Expanded(
              child: Stack(
                children: [
                  Container(color: AppTheme.surfaceColor),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          '${index + 1}. $title',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            height: 1.1,
                          ),
                          maxLines: (hasPoster || isImage) ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        if (hasPoster && year != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                year,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      AppTheme.textMuted.withValues(alpha: 0.8),
                                ),
                              ),
                              // Season/Episode badge
                              if (imdbData?.season != null &&
                                  imdbData?.episode != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color:
                                        AppTheme.primaryColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'S${imdbData!.season.toString().padLeft(2, '0')}E${imdbData.episode.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],

                        const Spacer(),

                        // Bottom Row: Size + Actions
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                // Size Info
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    formatBytes(file.size),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                if (canStream) ...[
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () =>
                                        _showImdbSearchModal(file.name),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: hasPoster
                                            ? AppTheme.successColor
                                                .withValues(alpha: 0.1)
                                            : AppTheme.surfaceColor,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: hasPoster
                                                ? AppTheme.successColor
                                                    .withValues(alpha: 0.5)
                                                : AppTheme.borderColor,
                                            width: 1),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                              hasPoster
                                                  ? Icons.check_circle_outline
                                                  : Icons.link,
                                              size: 10,
                                              color: hasPoster
                                                  ? AppTheme.successColor
                                                  : AppTheme.textSecondary),
                                          const SizedBox(width: 4),
                                          Text(
                                            hasPoster ? 'Linked' : 'Link IMDb',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: hasPoster
                                                  ? AppTheme.successColor
                                                  : AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),

                            // Actions
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (canStream) ...[
                                  _buildCompactBtn(
                                    icon: Icons.play_arrow_rounded,
                                    color: AppTheme.successColor,
                                    onTap: () => _streamFile(file),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                if (_isText(file.name)) ...[
                                  _buildCompactBtn(
                                    icon: Icons.description_outlined,
                                    color: AppTheme.infoColor,
                                    onTap: () => _viewTextFile(file),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                _buildCompactBtn(
                                  icon: Icons.download_rounded,
                                  color: AppTheme.primaryColor,
                                  onTap: () => _downloadFile(file),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildCompactBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(6), // Reduced from 8
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color), // Reduced size from 20
        ),
      ),
    );
  }

  Widget _buildExtensionBadge(String filename) {
    final ext = filename.contains('.')
        ? filename.split('.').last.toUpperCase()
        : 'FILE';

    final isVideo =
        ['MKV', 'MP4', 'AVI', 'MOV', 'WMV', 'FLV', 'WEBM'].contains(ext);
    final isAudio = ['MP3', 'FLAC', 'WAV', 'M4A', 'AAC', 'OGG'].contains(ext);
    final isImage = ['JPG', 'JPEG', 'PNG', 'GIF', 'WEBP'].contains(ext);
    final isArchive = ['ZIP', 'RAR', '7Z', 'TAR', 'GZ', 'BIN'].contains(ext);
    final isApp = ['EXE', 'MSI', 'APK', 'DMG', 'ISO'].contains(ext);
    final isTorrent = ['TORRENT'].contains(ext);
    final isSubtitle = ['SRT', 'ASS', 'VTT', 'SAA'].contains(ext);
    final isText = ['TXT', 'LOG', 'CSV', 'JSON', 'XML'].contains(ext);

    Color color = AppTheme.textMuted;
    IconData icon = Icons.insert_drive_file_outlined;

    if (isVideo) {
      color = AppTheme.accentColor;
      icon = Icons.movie_outlined;
    } else if (isAudio) {
      color = AppTheme.successColor;
      icon = Icons.audiotrack_outlined;
    } else if (isImage) {
      color = Colors.purpleAccent;
      icon = Icons.image_outlined;
    } else if (isArchive) {
      color = Colors.orangeAccent;
      icon = Icons.archive_outlined;
    } else if (isApp) {
      color = Colors.teal;
      icon = Icons.android_outlined;
    } else if (isTorrent) {
      color = Colors.blue;
      icon = Icons.file_download_outlined;
    } else if (isSubtitle) {
      color = Colors.purple;
      icon = Icons.subtitles_outlined;
    } else if (isText) {
      color = Colors.grey;
      icon = Icons.text_snippet_outlined;
    } else {
      color = AppTheme.textMuted;
      icon = Icons.insert_drive_file_outlined;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          child: Text(
            ext.length > 4 ? ext.substring(0, 3) : ext,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w900, color: color),
          ),
        ),
      ],
    );
  }

  Future<void> _streamFile(FlatFile file) async {
    if (file.link.isEmpty) return;

    try {
      // Unlock the link first
      final magnetProvider = context.read<MagnetProvider>();
      final directLink = await magnetProvider.unlockLink(file.link);

      if (directLink == null) {
        throw Exception("Failed to unlock stream link.");
      }

      final imdb = _imdbLinks[file.name];
      if (imdb != null) {
        await _imdbService.addToRecents(imdb);
      }

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerScreen(
            url: directLink,
            title: file.name,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stream error: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<bool> _downloadFile(FlatFile file, {bool showFeedback = true}) async {
    if (file.link.isEmpty) return false;

    try {
      // 1. Unlock the link to get the direct download URL
      final magnetProvider = context.read<MagnetProvider>();
      final directLink = await magnetProvider.unlockLink(file.link);

      if (directLink == null) {
        throw Exception("Failed to unlock link. Check your AllDebrid account.");
      }

      if (mounted) {
        final downloadProvider = context.read<DownloadProvider>();
        await downloadProvider.startDownload(
            url: directLink, filename: file.name, totalSize: file.size);
      }

      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download started'),
            backgroundColor: AppTheme.successColor,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start download: $e'),
            backgroundColor: AppTheme.errorColor,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }
  }

  Future<void> _viewTextFile(FlatFile file) async {
    if (file.size > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File too large to preview (Limit: 5MB)')),
      );
      return;
    }

    try {
      final magnetProvider = context.read<MagnetProvider>();
      final directLink = await magnetProvider.unlockLink(file.link);
      if (directLink == null) throw Exception("Could not unlock file link");

      final response = await http.get(Uri.parse(directLink));
      if (response.statusCode != 200) {
        throw Exception("Failed to download file: ${response.statusCode}");
      }
      final content = response.body;

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _TextFileViewer(
          filename: file.name,
          content: content,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context) {
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
                child: const Icon(Icons.delete_outline_rounded,
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
              const Text(
                'Are you sure you want to delete this magnet?',
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
                      onPressed: () {
                        context
                            .read<MagnetProvider>()
                            .deleteMagnet(widget.magnet.id.toString());
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Close screen
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
      if (mounted) setState(() => _error = "Search failed");
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
      height: MediaQuery.of(context).size.height * 0.65, // Compact height
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
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                decoration: InputDecoration(
                  hintText: 'Search movie or TV show...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  prefixIcon:
                      const Icon(Icons.search, color: AppTheme.textMuted),
                  suffixIcon: IconButton(
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

class _ImagePreview extends StatefulWidget {
  final String link;
  final String filename;

  const _ImagePreview({required this.link, required this.filename});

  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {
  String? _unlockedUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _unlock();
  }

  Future<void> _unlock() async {
    try {
      final unlocked =
          await context.read<MagnetProvider>().unlockLink(widget.link);
      if (mounted) {
        setState(() {
          _unlockedUrl = unlocked;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: AppTheme.surfaceColor,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        ),
      );
    }

    if (_unlockedUrl == null) {
      return Container(
        color: AppTheme.surfaceColor,
        child: const Icon(Icons.broken_image_outlined,
            color: AppTheme.textMuted, size: 24),
      );
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                _FullScreenImage(url: _unlockedUrl!, title: widget.filename),
          ),
        );
      },
      child: CachedNetworkImage(
        imageUrl: _unlockedUrl!,
        fit: BoxFit.cover,
        memCacheHeight: 300, // Optimized for list preview
        placeholder: (context, url) => Container(
          color: AppTheme.surfaceColor,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: AppTheme.surfaceColor,
          child: const Icon(Icons.broken_image_outlined,
              color: AppTheme.textMuted, size: 24),
        ),
      ),
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            onPressed: () {
              // We already have the unlocked link, but the user might want to download it properly
              // For now, just show a message or use the existing download provider if possible
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Use the file list to download')),
              );
            },
          ),
        ],
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
