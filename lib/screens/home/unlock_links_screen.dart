import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/common/common_widgets.dart';

class UnlockLinksScreen extends StatefulWidget {
  const UnlockLinksScreen({super.key});

  @override
  State<UnlockLinksScreen> createState() => _UnlockLinksScreenState();
}

class _UnlockLinksScreenState extends State<UnlockLinksScreen> {
  final _controller = TextEditingController();
  final List<_LinkItem> _items = [];
  bool _isProcessRunning = false;
  bool _downloadAsZip = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('UNLOCK LINKS'),
        titleTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      body: Column(
        children: [
          _buildInputArea(),
          const Divider(height: 1),
          Expanded(child: _buildResultsList()),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border:
            Border(bottom: BorderSide(color: AppTheme.borderColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PASTE LINKS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.borderColor, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _controller,
              maxLines: 4,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: 'One link per line...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Download as ZIP option
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => setState(() => _downloadAsZip = !_downloadAsZip),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: AppTheme.primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(4),
                        color: _downloadAsZip
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                      ),
                      child: _downloadAsZip
                          ? Icon(Icons.check,
                              size: 14, color: AppTheme.backgroundColor)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'DOWNLOAD AS ZIP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _downloadAsZip
                            ? AppTheme.primaryColor
                            : AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isProcessRunning ? null : _processLinks,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _isProcessRunning
                        ? AppTheme.surfaceColor
                        : AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isProcessRunning
                          ? AppTheme.borderColor
                          : AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isProcessRunning)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        )
                      else
                        Icon(Icons.lock_open,
                            size: 18, color: AppTheme.backgroundColor),
                      const SizedBox(width: 10),
                      Text(
                        _isProcessRunning ? 'PROCESSING...' : 'UNLOCK ALL',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _isProcessRunning
                              ? AppTheme.textMuted
                              : AppTheme.backgroundColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    if (_items.isEmpty) {
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
              child: Icon(Icons.link_off, size: 40, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'NO LINKS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Paste links above to unlock',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _LinkResultCard(
          item: item,
          index: index,
          onDownload: () => _downloadItem(item),
        );
      },
    );
  }

  Future<void> _processLinks() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final urls = text.split('\n').where((s) => s.trim().isNotEmpty).toList();
    if (urls.isEmpty) return;

    setState(() {
      _isProcessRunning = true;
      _items.clear();
      for (final url in urls) {
        _items.add(_LinkItem(originalUrl: url.trim()));
      }
    });

    FocusScope.of(context).unfocus();

    // Process all items
    for (final item in List.from(_items)) {
      await _unlockSingleItem(item);
    }

    if (mounted) {
      setState(() => _isProcessRunning = false);

      // If download as ZIP is selected, trigger ZIP download
      if (_downloadAsZip) {
        _downloadAllAsZip();
      }
    }
  }

  Future<void> _unlockSingleItem(_LinkItem item) async {
    setState(() => item.status = _LinkStatus.processing);

    final provider = context.read<LinkProvider>();

    try {
      final isFolderDomain = item.originalUrl.contains('mega.nz') ||
          item.originalUrl.contains('drive.google.com') ||
          item.originalUrl.contains('1fichier.com/dir/');

      // Try redirector first
      try {
        debugPrint('Attempting redirector check for ${item.originalUrl}');
        final redirectorLinks =
            await provider.getRedirectorLinks(item.originalUrl);
        debugPrint(
            'Redirector result: ${redirectorLinks?.length ?? 0} links found');

        if (redirectorLinks != null && redirectorLinks.isNotEmpty) {
          if (mounted) {
            setState(() {
              item.status = _LinkStatus.success;
              item.filename = "Folder (${redirectorLinks.length} files)";
              item.fileSize = "${redirectorLinks.length} links";

              // Add all redirector links as new items
              for (final link in redirectorLinks) {
                _items.add(_LinkItem(originalUrl: link, isFromFolder: true));
              }
            });
          }

          // Process the new links
          final newItems = _items
              .where((i) => i.isFromFolder && i.status == _LinkStatus.pending)
              .toList();
          for (final newItem in newItems) {
            await _unlockSingleItem(newItem);
          }
          return;
        }
      } catch (e) {
        debugPrint('Redirector check failed: $e');
      }

      // Standard unlock
      debugPrint('Attempting standard unlock for ${item.originalUrl}');
      var result = await provider.unlockLink(item.originalUrl);

      if (result == null) {
        throw Exception(provider.error ?? 'Unknown error');
      }
      debugPrint(
          'Unlock success: ${result.filename}, Delayed: ${result.delayed}');

      // Handle delayed links
      if (result.delayed > 0) {
        if (mounted) {
          setState(() {
            item.filename = 'Processing (Delayed)...';
            item.status = _LinkStatus.processing;
          });
        }

        debugPrint('Waiting for delayed link ID: ${result.id}');
        final downloadLink =
            await provider.waitForDelayedLink(result.id.toString());
        if (downloadLink == null) {
          throw Exception('Timed out waiting for delayed link');
        }
        debugPrint('Delayed link resolved: $downloadLink');

        if (mounted) {
          setState(() {
            item.status = _LinkStatus.success;
            item.filename = result.filename;
            item.fileSize = formatBytes(result.filesize);
            item.downloadUrl = downloadLink;
          });
        }
        return;
      }

      // Immediate success
      if (mounted) {
        setState(() {
          item.status = _LinkStatus.success;
          item.filename = result.filename;
          item.fileSize = formatBytes(result.filesize);
          item.downloadUrl = result.link;
        });
      }
    } catch (e) {
      debugPrint('Unlock failed: $e');
      if (mounted) {
        setState(() {
          item.status = _LinkStatus.error;
          item.error = e.toString();
        });
      }
    }
  }

  void _downloadItem(_LinkItem item) {
    if (item.downloadUrl == null || item.filename == null) return;

    context.read<DownloadProvider>().startDownload(
          url: item.downloadUrl!,
          filename: item.filename!,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${item.filename}'),
        backgroundColor: AppTheme.successColor,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _downloadAllAsZip() {
    final successItems = _items
        .where((i) => i.status == _LinkStatus.success && i.downloadUrl != null)
        .toList();

    if (successItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No files to download'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    // TODO: Implement ZIP download - for now, download individually
    for (final item in successItems) {
      _downloadItem(item);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${successItems.length} files'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
}

class _LinkResultCard extends StatelessWidget {
  final _LinkItem item;
  final int index;
  final VoidCallback onDownload;

  const _LinkResultCard({
    required this.item,
    required this.index,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = item.status == _LinkStatus.success
        ? AppTheme.successColor
        : item.status == _LinkStatus.error
            ? AppTheme.errorColor
            : AppTheme.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: item.status == _LinkStatus.success
              ? AppTheme.successColor
              : AppTheme.borderColor,
          width: item.status == _LinkStatus.success ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (item.filename ?? item.originalUrl).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (item.status == _LinkStatus.success && item.fileSize != null)
                  Text(
                    item.fileSize!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                  )
                else if (item.status == _LinkStatus.error)
                  Text(
                    item.error ?? 'Error',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    'PROCESSING...',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
          ),
          if (item.status == _LinkStatus.processing)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (item.status == _LinkStatus.success &&
              item.downloadUrl != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onDownload,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.download,
                          size: 16, color: AppTheme.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.check_circle,
                    size: 18, color: AppTheme.successColor),
              ],
            )
          else if (item.status == _LinkStatus.error)
            Icon(Icons.error, size: 18, color: AppTheme.errorColor),
        ],
      ),
    ).animate().fadeIn(delay: (30 * index).ms, duration: 250.ms);
  }
}

enum _LinkStatus { pending, processing, success, error }

class _LinkItem {
  final String originalUrl;
  final bool isFromFolder;
  _LinkStatus status = _LinkStatus.pending;
  String? filename;
  String? fileSize;
  String? downloadUrl;
  String? error;

  _LinkItem({
    required this.originalUrl,
    this.isFromFolder = false,
  });
}
