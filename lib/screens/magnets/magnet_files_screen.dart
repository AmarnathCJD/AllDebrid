import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/common_widgets.dart';
import '../../utils/helpers.dart';
import '../../services/imdb_service.dart';
import '../player/player_screen.dart';

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
        await _imdbService.addToRecents(link);
        if (mounted) {
          setState(() {
            _imdbLinks[file.name] = link!;
          });
        }
      }
    }
  }

  Future<void> _linkImdb(String filename, ImdbSearchResult result) async {
    await _imdbService.saveLink(filename, result);

    final recentItem = result.copyWith(magnetId: widget.magnet.id.toString());
    await _imdbService.addToRecents(recentItem);

    if (mounted) {
      setState(() {
        _imdbLinks[filename] = recentItem;
      });
      Navigator.pop(context); // Close modal
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Linked to ${result.title}'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
            bottom: BorderSide(color: AppTheme.borderColor.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FILES IN',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMuted,
                            letterSpacing: 1)),
                    Text(widget.magnet.filename,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              IconButton(
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppTheme.errorColor)),
            ],
          ),
          if (isDownloading) ...[
            const SizedBox(height: 16),
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
                        color: AppTheme.primaryColor)),
                Text(formatSpeed(widget.magnet.downloadSpeed),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileItem(FlatFile file, int index) {
    final bool canStream = _isStreamable(file.name);
    final String cleanExtension = file.name.split('.').last.toLowerCase();
    final bool isVideo =
        ['mp4', 'mkv', 'avi', 'mov', 'wmv'].contains(cleanExtension);
    final bool isAudio = ['mp3', 'flac', 'wav', 'm4a'].contains(cleanExtension);

    final imdbData = _imdbLinks[file.name];

    // --- LINKED ITEM LAYOUT (Big Poster) ---
    if (imdbData != null && imdbData.posterUrl.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 8)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // BIG POSTER SECTION (Fixed Size 2:3)
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
                          image: CachedNetworkImageProvider(imdbData.posterUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // CONTENT SECTION
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            imdbData.title,
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
                            file.name,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                                height: 1.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 8),

                          // Year Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              imdbData.year,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                          ),

                          const Spacer(),

                          // Size Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppTheme.surfaceColor,
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(formatBytes(file.size),
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textSecondary)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Actions
              if (file.link.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                    height: 1, color: AppTheme.borderColor.withOpacity(0.5)),
                Row(
                  children: [
                    if (canStream) ...[
                      Expanded(
                          child: _buildActionButton(
                              label: 'STREAM',
                              icon: Icons.play_arrow_rounded,
                              color: AppTheme.accentColor,
                              onTap: () => _streamFile(file))),
                      Container(
                          width: 1,
                          height: 40,
                          color: AppTheme.borderColor.withOpacity(0.5)),
                    ],
                    Expanded(
                        child: _buildActionButton(
                            label: 'IMDb',
                            icon: Icons.movie_filter_rounded,
                            color: Colors.amber[700]!,
                            onTap: () => _showImdbSearchModal(file.name))),
                    Container(
                        width: 1,
                        height: 40,
                        color: AppTheme.borderColor.withOpacity(0.5)),
                    Expanded(
                        child: _buildActionButton(
                            label: 'DOWNLOAD',
                            icon: Icons.download_rounded,
                            color: AppTheme.primaryColor,
                            onTap: () => _downloadFile(file))),
                  ],
                ),
              ],
            ],
          ),
        ),
      ).animate().fadeIn(delay: (30 * index).ms).slideX();
    }

    // --- GENERIC ITEM LAYOUT ---
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
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showFilenameDialog(context, file.name),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGenericIcon(canStream, isVideo, isAudio),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatBytes(file.size),
                            style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (file.link.isNotEmpty) ...[
            Container(height: 1, color: AppTheme.borderColor.withOpacity(0.5)),
            Row(
              children: [
                if (canStream) ...[
                  Expanded(
                    child: _buildActionButton(
                      label: 'STREAM',
                      icon: Icons.play_arrow_rounded,
                      color: AppTheme.accentColor,
                      onTap: () => _streamFile(file),
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 40,
                      color: AppTheme.borderColor.withOpacity(0.5)),
                ],
                // IMDB Button
                Expanded(
                  child: _buildActionButton(
                    label: 'IMDb',
                    icon: Icons.movie_filter_rounded,
                    color: Colors.amber[700]!,
                    onTap: () => _showImdbSearchModal(file.name),
                  ),
                ),
                Container(
                    width: 1,
                    height: 40,
                    color: AppTheme.borderColor.withOpacity(0.5)),
                Expanded(
                  child: _buildActionButton(
                    label: 'DOWNLOAD',
                    icon: Icons.download_rounded,
                    color: AppTheme.primaryColor,
                    onTap: () => _downloadFile(file),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: (30 * index).ms).slideX();
  }

  Widget _buildGenericIcon(bool canStream, bool isVideo, bool isAudio) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: (canStream ? AppTheme.accentColor : AppTheme.textSecondary)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isVideo
            ? Icons.movie_rounded
            : (isAudio
                ? Icons.audiotrack_rounded
                : Icons.insert_drive_file_rounded),
        color: canStream ? AppTheme.accentColor : AppTheme.textSecondary,
        size: 24,
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 45,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
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

  Future<void> _streamFile(FlatFile file) async {
    if (file.link.isEmpty) return;

    try {
      // Unlock the link first
      final magnetProvider = context.read<MagnetProvider>();
      final directLink = await magnetProvider.unlockLink(file.link);

      if (directLink == null) {
        throw Exception("Failed to unlock stream link.");
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

  Future<void> _downloadFile(FlatFile file) async {
    if (file.link.isEmpty) return;

    try {
      // 1. Unlock the link to get the direct download URL
      final magnetProvider = context.read<MagnetProvider>();
      final directLink = await magnetProvider.unlockLink(file.link);

      if (directLink == null) {
        throw Exception("Failed to unlock link. Check your AllDebrid account.");
      }

      // 2. Start download with the unlocked link
      final downloadProvider = context.read<DownloadProvider>();
      await downloadProvider.startDownload(
          url: directLink, filename: file.name, totalSize: file.size);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download started'),
            backgroundColor: AppTheme.successColor,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
                  color: AppTheme.errorColor.withOpacity(0.1),
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

  void _showFilenameDialog(BuildContext context, String filename) {
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
              const Icon(Icons.description_rounded,
                  size: 32, color: AppTheme.primaryColor),
              const SizedBox(height: 16),
              Text(
                filename,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CLOSE',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
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

  @override
  void initState() {
    super.initState();
    // Cleaner: Do not prepopulate the search bar with filename as it often leads to poor results
    // Let user type exactly what they want.
    _controller.text = "";
    // _search(""); // Don't auto search empty
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search for movie/series...',
                      hintStyle: const TextStyle(color: AppTheme.textMuted),
                      prefixIcon:
                          const Icon(Icons.search, color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onSubmitted: _search,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _search(_controller.text),
                  style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: const TextStyle(color: AppTheme.errorColor)))
                    : _results.isEmpty
                        ? const Center(
                            child: Text("No results found",
                                style: TextStyle(color: AppTheme.textMuted)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              return InkWell(
                                onTap: () => widget.onSelect(item),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: item.posterUrl,
                                          width: 40,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              Container(
                                                  width: 40,
                                                  height: 60,
                                                  color: Colors.grey),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(item.title,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14)),
                                            if (item.year.isNotEmpty)
                                              Text(item.year,
                                                  style: const TextStyle(
                                                      color: AppTheme.textMuted,
                                                      fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      const Icon(Icons.add_link_rounded,
                                          color: AppTheme.primaryColor),
                                    ],
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
