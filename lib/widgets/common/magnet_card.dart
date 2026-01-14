import 'package:flutter/material.dart';
import '../../models/magnet.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';

/// Compact Magnet Card with marquee filename and icons
class MagnetCard extends StatelessWidget {
  final MagnetStatus magnet;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRestart;

  const MagnetCard({
    super.key,
    required this.magnet,
    this.onTap,
    this.onDelete,
    this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final status = magnet.magnetStatusCode;
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final isActive = status == MagnetStatusCode.downloading ||
        status == MagnetStatusCode.uploading;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: AppTheme.compactCardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Status + Filename (Marquee)
                Row(
                  children: [
                    // Status icon
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(statusIcon, size: 14, color: statusColor),
                    ),
                    const SizedBox(width: 8),
                    // Filename with marquee effect
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 16,
                            child: _MarqueeText(
                              text: magnet.filename,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                formatBytes(magnet.size),
                                style: const TextStyle(
                                    color: AppTheme.textMuted, fontSize: 11),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  _getStatusLabel(status),
                                  style: TextStyle(
                                      color: statusColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Actions
                    if (status == MagnetStatusCode.error && onRestart != null)
                      _ActionBtn(
                          icon: Icons.refresh,
                          onTap: onRestart!,
                          color: AppTheme.warningColor),
                    if (onDelete != null) ...[
                      const SizedBox(width: 4),
                      _ActionBtn(
                          icon: Icons.delete_outline,
                          onTap: onDelete!,
                          color: AppTheme.errorColor),
                    ],
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right,
                        size: 18, color: AppTheme.textMuted),
                  ],
                ),

                // Progress bar (if active)
                if (isActive) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: magnet.progress / 100,
                            backgroundColor: AppTheme.borderColor,
                            color: statusColor,
                            minHeight: 3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${magnet.progress.toStringAsFixed(0)}%',
                        style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  // Speed & Seeders
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.speed, size: 11, color: AppTheme.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        formatSpeed(magnet.downloadSpeed),
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 10),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.group, size: 11, color: AppTheme.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        '${magnet.seeders} seeders',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(MagnetStatusCode status) {
    switch (status) {
      case MagnetStatusCode.ready:
        return AppTheme.successColor;
      case MagnetStatusCode.downloading:
      case MagnetStatusCode.uploading:
        return AppTheme.primaryColor;
      case MagnetStatusCode.queued:
      case MagnetStatusCode.processing:
        return AppTheme.accentColor;
      case MagnetStatusCode.error:
        return AppTheme.errorColor;
      default:
        return AppTheme.textMuted;
    }
  }

  IconData _getStatusIcon(MagnetStatusCode status) {
    switch (status) {
      case MagnetStatusCode.ready:
        return Icons.check_circle;
      case MagnetStatusCode.downloading:
        return Icons.downloading;
      case MagnetStatusCode.uploading:
        return Icons.upload;
      case MagnetStatusCode.queued:
        return Icons.schedule;
      case MagnetStatusCode.processing:
        return Icons.hourglass_top;
      case MagnetStatusCode.error:
        return Icons.error;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusLabel(MagnetStatusCode status) {
    switch (status) {
      case MagnetStatusCode.ready:
        return 'READY';
      case MagnetStatusCode.downloading:
        return 'DOWNLOADING';
      case MagnetStatusCode.uploading:
        return 'UPLOADING';
      case MagnetStatusCode.queued:
        return 'QUEUED';
      case MagnetStatusCode.processing:
        return 'PROCESSING';
      case MagnetStatusCode.error:
        return 'ERROR';
      default:
        return 'UNKNOWN';
    }
  }
}

/// Small Action Button
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ActionBtn(
      {required this.icon, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

/// Marquee Text Widget for long filenames
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _shouldScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  void _checkScroll() {
    if (_scrollController.hasClients) {
      final shouldScroll = _scrollController.position.maxScrollExtent > 0;
      if (shouldScroll != _shouldScroll) {
        setState(() => _shouldScroll = shouldScroll);
        if (_shouldScroll) _startScroll();
      }
    }
  }

  void _startScroll() async {
    if (!mounted) return;
    await Future.delayed(const Duration(seconds: 2));
    while (mounted && _shouldScroll) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration:
            Duration(milliseconds: widget.text.length * 200), // Much slower
        curve: Curves.linear,
      );
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1),
    );
  }
}
