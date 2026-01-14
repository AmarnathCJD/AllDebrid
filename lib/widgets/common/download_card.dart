import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';

/// Compact Download Card
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
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final isActive = !isCompleted && !isFailed && !isPaused;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Subtle Progress Background
          if (isActive && progress > 0)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * progress,
              child: Container(color: statusColor.withOpacity(0.03)),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (posterUrl != null && posterUrl!.isNotEmpty)
                  // RICH LAYOUT (IMDb)
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Poster (Fixed Size 2:3)
                        Container(
                          width: 100,
                          height: 150, // 2:3 Aspect ratio forced
                          margin: const EdgeInsets.only(right: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                            image: DecorationImage(
                              image: CachedNetworkImageProvider(posterUrl!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              if (imdbTitle != null)
                                Text(
                                  imdbTitle!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.accentColor,
                                    height: 1.2,
                                    letterSpacing: 0.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),

                              const SizedBox(height: 4),

                              // Filename
                              Text(
                                filename,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textMuted,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // Gap for Year
                              const SizedBox(height: 8),

                              // Year (Moved to vacant space)
                              if (imdbYear != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    imdbYear!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),

                              const Spacer(),

                              // Status & Size
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _getStatusText(),
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: statusColor),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (totalSize > 0)
                                    Text(
                                      '${formatBytes(downloadedSize)} / ${formatBytes(totalSize)}',
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
                      ],
                    ),
                  )
                else
                  // CLASSIC LAYOUT
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(_getStatusIcon(),
                            size: 20, color: statusColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              filename,
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
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _getStatusText(),
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor),
                                  ),
                                ),
                                if (totalSize > 0) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '${formatBytes(downloadedSize)} / ${formatBytes(totalSize)}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                if (isActive || isPaused) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalSize > 0 ? (downloadedSize / totalSize) : 0,
                      backgroundColor: AppTheme.surfaceColor,
                      color: statusColor,
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.speed_rounded,
                              size: 14, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            formatSpeed(speed),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ],

                // Action Buttons Row (Separate)
                const SizedBox(height: 16),
                Container(
                    height: 1, color: AppTheme.borderColor.withOpacity(0.5)),
                if (isCompleted || isFailed)
                  Row(
                    children: [
                      if (isCompleted) ...[
                        if (onStream != null) ...[
                          Expanded(
                              child: _buildActionButton(
                                  'STREAM',
                                  Icons.play_circle_outline_rounded,
                                  AppTheme.accentColor,
                                  onStream)),
                          Container(
                              width: 1,
                              height: 40,
                              color: AppTheme.borderColor.withOpacity(0.5)),
                        ],
                        if (onOpen != null) ...[
                          Expanded(
                              child: _buildActionButton(
                                  'OPEN',
                                  Icons.folder_open_rounded,
                                  AppTheme.successColor,
                                  onOpen)),
                          Container(
                              width: 1,
                              height: 40,
                              color: AppTheme.borderColor.withOpacity(0.5)),
                        ],
                      ],
                      Expanded(
                          child: _buildActionButton(
                              'DELETE',
                              Icons.delete_outline_rounded,
                              AppTheme.textMuted,
                              onDelete)),
                    ],
                  )
                else
                  Row(
                    children: [
                      if (isPaused)
                        Expanded(
                            child: _buildActionButton(
                                'RESUME',
                                Icons.play_arrow_rounded,
                                AppTheme.successColor,
                                onResume))
                      else
                        Expanded(
                            child: _buildActionButton(
                                'PAUSE',
                                Icons.pause_rounded,
                                AppTheme.warningColor,
                                onPause)),
                      Container(
                          width: 1,
                          height: 40,
                          color: AppTheme.borderColor.withOpacity(0.5)),
                      Expanded(
                          child: _buildActionButton(
                              'CANCEL',
                              Icons.stop_rounded,
                              AppTheme.errorColor,
                              onCancel)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      String label, IconData icon, Color color, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
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

  IconData _getStatusIcon() {
    if (isCompleted) return Icons.check_circle_outline_rounded;
    if (isFailed) return Icons.error_outline_rounded;
    if (isPaused) return Icons.pause_circle_outline_rounded;
    return Icons.downloading_rounded;
  }

  String _getStatusText() {
    if (isCompleted) return 'COMPLETED';
    if (isFailed) return 'FAILED';
    if (isPaused) return 'PAUSED';
    return 'DOWNLOADING';
  }
}
