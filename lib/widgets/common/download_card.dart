import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/imdb_service.dart';
import '../../screens/player/player_screen.dart';

class DownloadCard extends StatelessWidget {
  final String filename;
  final double progress;
  final int downloadedSize;
  final int totalSize;
  final int speed;
  final String status;
  final bool isPaused;
  final bool isCompleted;
  final bool isFailed;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onStream;
  final VoidCallback? onOpen;
  final String? posterUrl;
  final String? imdbTitle;
  final String? imdbYear;
  final String? imdbId;
  final String? imdbRating;
  final String? description;
  final String? videoId;
  final String? stars;
  final String? genres;
  final String? duration;
  final String? ratingCount;
  final int? season;
  final int? episode;
  final String? production;
  final String? backdropUrl;
  final String? releaseDate;

  const DownloadCard({
    super.key,
    required this.filename,
    required this.progress,
    required this.downloadedSize,
    required this.totalSize,
    required this.speed,
    required this.status,
    this.isPaused = false,
    this.isCompleted = false,
    this.isFailed = false,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onDelete,
    this.onStream,
    this.onOpen,
    this.posterUrl,
    this.imdbTitle,
    this.imdbYear,
    this.imdbId,
    this.imdbRating,
    this.description,
    this.videoId,
    this.stars,
    this.genres,
    this.duration,
    this.ratingCount,
    this.season,
    this.episode,
    this.production,
    this.backdropUrl,
    this.releaseDate,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final isActive = !isCompleted && !isFailed && !isPaused;
    final bool hasPoster = posterUrl != null && posterUrl!.isNotEmpty;

    return Slidable(
      key: ValueKey(filename),
      startActionPane: isCompleted
          ? ActionPane(
              motion: const StretchMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) {
                    if (onStream != null) onStream!();
                  },
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  icon: Icons.play_circle_filled_rounded,
                  label: 'Play',
                ),
                if (onOpen != null)
                  SlidableAction(
                    onPressed: (context) => onOpen!(),
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    icon: Icons.folder_open_rounded,
                    label: 'Open',
                  ),
              ],
            )
          : null,
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              if (isCompleted && onDelete != null) {
                onDelete!();
              } else if (onCancel != null) {
                onCancel!();
              }
            },
            backgroundColor: AppTheme.errorColor,
            foregroundColor: Colors.white,
            icon:
                isCompleted ? Icons.delete_outline_rounded : Icons.stop_rounded,
            label: isCompleted ? 'Delete' : 'Cancel',
          ),
        ],
      ),
      child: Container(
        height: hasPoster ? 140 : 90, // Compact height if no poster
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: [
              // Left Side: Poster or Compact Icon
              if (hasPoster)
                GestureDetector(
                  onTap: () => _showImdbDetails(context, statusColor),
                  child: Container(
                    width: 100,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(posterUrl!),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                          offset: const Offset(5, 0),
                        ),
                      ],
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
                      // Hint overlay on hover/press could be added here,
                      // but for now we just make it clickable.
                    ),
                  ),
                )
              else
                Container(
                  width: 70,
                  height: double.infinity,
                  color: AppTheme.surfaceColor,
                  child: Center(
                    child: _buildExtensionBadge(),
                  ),
                ),

              // Right Side: Content (The "Remaining Part" with BG)
              Expanded(
                child: Stack(
                  children: [
                    // Subtle Backround Pattern or Color
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme
                            .surfaceColor, // Lighter/Darker separate from Poster
                      ),
                    ),

                    // Active Progress Overlay (Subtle)
                    if (isActive && progress > 0)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: MediaQuery.of(context).size.width *
                            0.7 *
                            progress, // rough estimate width
                        child: Container(
                            color: statusColor.withValues(alpha: 0.03)),
                      ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title & Status
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  imdbTitle ?? filename,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                    height: 1.1,
                                  ),
                                  maxLines:
                                      hasPoster ? 2 : 1, // 1 line for compact
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Mini Status Badge top-right
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _getStatusText(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Year (Only if plain text has space i.e. hasPoster)
                          if (hasPoster && imdbYear != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  imdbYear!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMuted
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                                if (season != null && episode != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],

                          const Spacer(),

                          // Bottom Row: Stats + Actions fused for compact
                          Row(
                            children: [
                              if (totalSize > 0)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isCompleted
                                          ? formatBytes(totalSize)
                                          : '${formatBytes(downloadedSize)} / ${formatBytes(totalSize)}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                    if (isActive || isPaused) ...[
                                      const SizedBox(height: 2),
                                      Container(
                                        width: 80,
                                        height: 3,
                                        decoration: BoxDecoration(
                                            color: AppTheme.borderColor
                                                .withValues(alpha: 0.3),
                                            borderRadius:
                                                BorderRadius.circular(2)),
                                        child: FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor:
                                                progress.clamp(0.0, 1.0),
                                            child: Container(
                                                decoration: BoxDecoration(
                                                    color: statusColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            2)))),
                                      ),
                                      if (isActive && speed > 0) ...[
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.arrow_downward_rounded,
                                                size: 10,
                                                color: AppTheme.accentColor),
                                            const SizedBox(width: 2),
                                            Text(
                                              formatSpeed(speed),
                                              style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppTheme.accentColor),
                                            ),
                                            const SizedBox(width: 6),
                                            Icon(Icons.timer_outlined,
                                                size: 10,
                                                color: AppTheme.textMuted),
                                            const SizedBox(width: 2),
                                            Text(
                                              formatEta(
                                                  totalSize - downloadedSize,
                                                  speed),
                                              style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppTheme.textMuted),
                                            ),
                                          ],
                                        ),
                                      ]
                                    ] else if (speed > 0) ...[
                                      Row(
                                        children: [
                                          Icon(Icons.speed_rounded,
                                              size: 10,
                                              color: AppTheme.textMuted),
                                          const SizedBox(width: 2),
                                          Text(formatSpeed(speed),
                                              style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppTheme.textMuted)),
                                        ],
                                      )
                                    ]
                                  ],
                                ),

                              const Spacer(),

                              // Actions
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isCompleted) ...[
                                    if (onStream != null)
                                      _buildIconBtn(
                                          Icons.play_circle_filled_rounded,
                                          AppTheme.accentColor,
                                          onStream!),
                                    if (onOpen != null)
                                      _buildIconBtn(Icons.folder_open_rounded,
                                          AppTheme.successColor, onOpen!),
                                    _buildIconBtn(Icons.delete_outline_rounded,
                                        AppTheme.textMuted, onDelete!),
                                  ] else ...[
                                    if (onStream != null)
                                      _buildIconBtn(
                                          Icons.play_circle_filled_rounded,
                                          AppTheme.accentColor,
                                          onStream!),
                                    if (isPaused)
                                      _buildIconBtn(Icons.play_arrow_rounded,
                                          AppTheme.successColor, onResume!)
                                    else if (!isActive && !isFailed)
                                      _buildIconBtn(Icons.pause_rounded,
                                          AppTheme.warningColor, onPause!)
                                    else if (isFailed)
                                      _buildIconBtn(Icons.refresh_rounded,
                                          AppTheme.accentColor, onResume!)
                                    else // Downloading
                                      _buildIconBtn(Icons.pause_rounded,
                                          AppTheme.warningColor, onPause!),
                                    _buildIconBtn(Icons.stop_rounded,
                                        AppTheme.errorColor, onCancel!),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding:
              const EdgeInsets.all(4), // Reduced padding for tighter alignment
          child: Icon(icon, size: 26, color: color),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (isCompleted) return AppTheme.successColor;
    if (isFailed) return AppTheme.errorColor;
    if (isPaused) return AppTheme.warningColor;
    return AppTheme.primaryColor;
  }

  Widget _buildExtensionBadge() {
    final ext = filename.contains('.')
        ? filename.split('.').last.toUpperCase()
        : 'FILE';
    final isVideo =
        ['MKV', 'MP4', 'AVI', 'MOV', 'WMV', 'FLV', 'WEBM'].contains(ext);
    final isAudio = ['MP3', 'FLAC', 'WAV', 'M4A', 'AAC', 'OGG'].contains(ext);
    final isImage = ['JPG', 'JPEG', 'PNG', 'GIF', 'WEBP'].contains(ext);
    final isArchive = ['ZIP', 'RAR', '7Z', 'TAR', 'GZ', 'BIN'].contains(ext);

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
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color.withValues(alpha: 0.8), size: 28),
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

  String _getStatusText() {
    if (isCompleted) return 'DONE';
    if (isFailed) return 'FAILED';
    if (isPaused) return 'PAUSED';
    return '${(progress * 100).toStringAsFixed(0)}%';
  }

  void _showImdbDetails(BuildContext context, Color statusColor) async {
    // 1. Prepare data variables (start with what we have)
    String? dRating = imdbRating;
    String? dDesc = description;
    String? dGenres = genres;
    String? dDuration = duration;
    String? dStars = stars;
    String? dRatingCount = ratingCount;
    String? dVideoId = videoId;
    String? dYear = imdbYear;
    String? dProduction = production;
    String? dBackdrop = backdropUrl;
    String? dReleaseDate = releaseDate;
    String? dCountry;
    String? dLanguages;
    String dTitle = imdbTitle ?? filename;

    if ((dRating == null || dDesc == null) &&
        (imdbId != null || imdbTitle != null)) {
      debugPrint('--- IMDB Details Debug ---');
      debugPrint('Title: $dTitle');
      debugPrint('ID: $imdbId');
      debugPrint('Rating: $dRating');
      debugPrint('Desc: $dDesc');
      debugPrint('Poster: $posterUrl');
      debugPrint('Prod: $dProduction');
      debugPrint('Backdrop: $dBackdrop');
      debugPrint('Release: $dReleaseDate');

      try {
        final service = ImdbService();
        // Use ID if available, otherwise search by title
        // For now, simpler to just assume we might have an ID if passed,
        // or we rely on the implementation of fetchDetails to handle it if we passed an ID.
        // But wait, fetchDetails takes an ID.

        String searchId = imdbId ?? '';

        if (searchId.isEmpty && imdbTitle != null) {
          // If we don't have an ID, we might need to search first.
          // But for now let's assume if we have a posterUrl we probably linked it before.
          // If we can't find ID, we skip.
        }

        if (searchId.isNotEmpty) {
          final details = await service.fetchDetails(searchId);
          // Update local variables with fetched data
          if (details.rating != null) dRating = details.rating;
          if (details.description != null) dDesc = details.description;
          if (details.genres != null) dGenres = details.genres;
          if (details.duration != null) dDuration = details.duration;
          if (details.stars != null) dStars = details.stars;
          if (details.ratingCount != null) dRatingCount = details.ratingCount;
          if (details.videoId != null) dVideoId = details.videoId;
          if (details.year.isNotEmpty) dYear = details.year;
          if (details.title.isNotEmpty) dTitle = details.title;
          if (details.production != null) dProduction = details.production;
          if (details.backdropUrl != null) dBackdrop = details.backdropUrl;
          if (details.releaseDate != null) dReleaseDate = details.releaseDate;
          if (details.country != null) dCountry = details.country;
          if (details.languages != null) dLanguages = details.languages;
        }

        debugPrint('--- Fetched Details ---');
        debugPrint('Rating: $dRating');
        debugPrint('Year: $dYear');
        debugPrint('Release: $dReleaseDate');
        debugPrint('Duration: $dDuration');
        debugPrint('Genres: $dGenres');
        debugPrint('Desc: $dDesc');
        debugPrint('Prod: $dProduction');
        debugPrint('Backdrop: $dBackdrop');
        debugPrint('Country: $dCountry');
        debugPrint('Langs: $dLanguages');
      } catch (e) {
        debugPrint('Error fetching details: $e');
      }
    }

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5, // More compact start
        minChildSize: 0.35,
        maxChildSize: 0.75,
        builder: (_, controller) => _buildSheetContent(
            context,
            controller,
            statusColor,
            dTitle,
            dYear,
            dRating,
            dDesc,
            dGenres,
            dDuration,
            dStars,
            dRatingCount,
            dVideoId,
            dProduction,
            dBackdrop,
            dReleaseDate,
            dCountry,
            dLanguages),
      ),
    );
  }

  Widget _buildSheetContent(
      BuildContext context,
      ScrollController controller,
      Color statusColor,
      String title,
      String? year,
      String? rating,
      String? desc,
      String? genres,
      String? duration,
      String? cast,
      String? ratingCount,
      String? videoId,
      String? production,
      String? backdrop,
      String? releaseDate,
      String? country,
      String? languages) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
      ),
      child: Stack(
        children: [
          // Content
          ListView(
            controller: controller,
            padding: EdgeInsets.zero,
            children: [
              // 1. Header Section (Backdrop + Poster + Title)
              Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  // Backdrop Image
                  Container(
                    height: 220,
                    width: double.infinity,
                    foregroundDecoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.cardColor.withValues(alpha: 0.2),
                          AppTheme.cardColor,
                        ],
                        stops: const [0.0, 0.6, 1.0],
                      ),
                    ),
                    child: backdrop != null
                        ? CachedNetworkImage(
                            imageUrl: backdrop,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                Container(color: Colors.black12),
                            errorWidget: (_, __, ___) =>
                                Container(color: Colors.black12),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  statusColor.withValues(alpha: 0.2),
                                  AppTheme.cardColor,
                                ],
                              ),
                            ),
                          ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Poster (Elevated)
                        Container(
                          width: 120,
                          height: 170,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              )
                            ],
                            image: DecorationImage(
                              image:
                                  CachedNetworkImageProvider(posterUrl ?? ''),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Title & Metadata
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (rating != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded,
                                            color: Colors.amber, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          rating,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (duration != null)
                                    Text(
                                      duration,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
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
                ],
              ),
              if (videoId != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  child: Row(
                    children: [
                      // Watch Trailer
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _launchTrailer(context, videoId, title),
                          icon: const Icon(Icons.play_arrow_rounded,
                              color: Colors.black),
                          label: const Text('TRAILER',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Play File (Main Action)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (onStream != null) {
                              Navigator.pop(context);
                              onStream!();
                            }
                          },
                          icon: const Icon(Icons.movie_rounded,
                              color: Colors.white),
                          label: const Text('PLAY MOVIE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (genres != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: genres.split(',').map((g) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Text(
                          g.trim(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color:
                                AppTheme.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              const SizedBox(height: 16),

              if (desc != null && desc.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PLOT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textMuted,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        desc
                            .replaceAll("&quot;", "'")
                            .replaceAll("&amp;", "&")
                            .replaceAll("&#39;", "'")
                            .replaceAll("&#39;", "'")
                            .replaceAll("&apos;", "'")
                            .replaceAll("&gt;", ">")
                            .replaceAll("&lt;", "<"),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: AppTheme.textSecondary.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
              if (cast != null && cast.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CAST',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textMuted,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: cast.split(',').take(3).map((c) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.1),
                                child: Text(
                                  c.trim()[0],
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                c.trim(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // 6. Additional Info (Grid-like)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (production != null) ...[
                      _buildInfoRow('PRODUCTION', production),
                      const SizedBox(height: 16),
                    ],
                    if (country != null) ...[
                      _buildInfoRow('COUNTRY', country),
                      const SizedBox(height: 16),
                    ],
                    if (languages != null) ...[
                      _buildInfoRow('LANGUAGES', languages),
                      const SizedBox(height: 16),
                    ],
                    // Only show header if content exists - simplified for now
                  ],
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),

          // Drag Handle
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppTheme.textMuted,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Future<void> _launchTrailer(
      BuildContext context, String videoId, String movieTitle) async {
    final service = ImdbService();
    final streamUrl = await service.fetchTrailerStreamUrl(videoId);

    if (context.mounted) {
      if (streamUrl != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              url: streamUrl,
              title: '$movieTitle - Trailer',
              isLocal: false,
            ),
          ),
        );
      } else {
        final uri = Uri.parse('https://www.imdb.com/video/$videoId');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not launch trailer')));
        }
      }
    }
  }
}
