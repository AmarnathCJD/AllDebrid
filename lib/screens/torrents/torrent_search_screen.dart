import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../models/torrent.dart';
import '../../services/torrent_scraper_service.dart';
import '../../providers/providers.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/common/common_widgets.dart';

class TorrentSearchScreen extends StatefulWidget {
  const TorrentSearchScreen({super.key});

  @override
  State<TorrentSearchScreen> createState() => _TorrentSearchScreenState();
}

class _TorrentSearchScreenState extends State<TorrentSearchScreen> {
  final _scraperService = TorrentScraperService();
  final _searchController = TextEditingController();
  List<TorrentEntry> _entries = [];
  List<TorrentEntry> _filteredEntries = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      final baseUrl = provider.getSetting<String>('torrent_base_url');
      if (baseUrl != null && baseUrl.isNotEmpty) {
        _scraperService.updateBaseUrl(baseUrl);
      }
      _loadEntries();
    });
    _searchController.addListener(_filterEntries);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scraperService.dispose();
    super.dispose();
  }

  void _filterEntries() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredEntries = _entries;
      } else {
        _filteredEntries = _entries.where((entry) {
          return entry.title.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final entries = await _scraperService.fetchHomepage();
      if (mounted) {
        // Sort entries: by year (newest first), then alphabetically
        entries.sort((a, b) {
          final yearA = RegExp(r'\((\d{4})\)').firstMatch(a.title)?.group(1);
          final yearB = RegExp(r'\((\d{4})\)').firstMatch(b.title)?.group(1);

          // First compare by year (newest first)
          if (yearA != null && yearB != null) {
            final yearCompare = int.parse(yearB).compareTo(int.parse(yearA));
            if (yearCompare != 0) return yearCompare;
          } else if (yearA != null) {
            return -1; // Items with year come before items without
          } else if (yearB != null) {
            return 1;
          }

          // If years are same (or both missing), compare alphabetically
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });

        setState(() {
          _entries = entries;
          _filteredEntries = entries;
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
        title: const Text('TORRENT SEARCH'),
        titleTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEntries,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border:
            Border(bottom: BorderSide(color: AppTheme.borderColor, width: 1)),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.borderColor, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          decoration: const InputDecoration(
            hintText: 'Search movies...',
            prefixIcon: Icon(Icons.search, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        itemBuilder: (_, __) => const SkeletonCard(height: 100),
      );
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
                onPressed: _loadEntries,
                child: const Text('RETRY'),
              ),
            ],
          ),
        ),
      );
    }

    if (_entries.isEmpty) {
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
              child: Icon(Icons.movie_outlined,
                  size: 40, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'NO CONTENT',
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

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _filteredEntries.length,
      itemBuilder: (context, index) {
        final entry = _filteredEntries[index];
        return _TorrentEntryCard(
          entry: entry,
          index: index,
          onTap: () => _openTorrentDetails(entry),
        );
      },
    );
  }

  void _openTorrentDetails(TorrentEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TorrentDetailsScreen(
          entry: entry,
          scraperService: _scraperService,
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavBarItem(
                icon: Icons.dashboard_outlined,
                activeIcon: Icons.dashboard,
                label: 'Home',
                isSelected: true,
                onTap: () {
                  context.read<NavigationProvider>().setIndex(0);
                  Navigator.pop(context);
                },
              ),
              _NavBarItem(
                icon: Icons.link_outlined,
                activeIcon: Icons.link,
                label: 'Magnets',
                isSelected: false,
                onTap: () {
                  context.read<NavigationProvider>().setIndex(1);
                  Navigator.pop(context);
                },
              ),
              _NavBarItem(
                icon: Icons.download_outlined,
                activeIcon: Icons.download,
                label: 'Downloads',
                isSelected: false,
                onTap: () {
                  context.read<NavigationProvider>().setIndex(2);
                  Navigator.pop(context);
                },
              ),
              _NavBarItem(
                icon: Icons.folder_outlined,
                activeIcon: Icons.folder,
                label: 'Files',
                isSelected: false,
                onTap: () {
                  context.read<NavigationProvider>().setIndex(3);
                  Navigator.pop(context);
                },
              ),
              _NavBarItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: 'Settings',
                isSelected: false,
                onTap: () {
                  context.read<NavigationProvider>().setIndex(4);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TorrentEntryCard extends StatelessWidget {
  final TorrentEntry entry;
  final int index;
  final VoidCallback onTap;

  const _TorrentEntryCard({
    required this.entry,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor, width: 2),
            ),
            child: Row(
              children: [
                // Colored accent bar
                Container(
                  width: 4,
                  height: 70,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryColor,
                        AppTheme.accentColor,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.movie_filter,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 14),
                // Title
                Expanded(
                  child: Text(
                    entry.title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: 0.4,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppTheme.textMuted),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (40 * index).ms, duration: 300.ms)
        .slideX(begin: 0.1, end: 0);
  }
}

class _TorrentDetailsScreen extends StatefulWidget {
  final TorrentEntry entry;
  final TorrentScraperService scraperService;

  const _TorrentDetailsScreen({
    required this.entry,
    required this.scraperService,
  });

  @override
  State<_TorrentDetailsScreen> createState() => _TorrentDetailsScreenState();
}

class _TorrentDetailsScreenState extends State<_TorrentDetailsScreen> {
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
      final downloads =
          await widget.scraperService.fetchTorrentLinks(widget.entry.url);
      if (mounted) {
        print('DEBUG: Fetched ${downloads.length} downloads');
        for (var d in downloads) {
          print('  - Name: "${d.name}", Size: "${d.size}"');
        }
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

    // Get poster and languages from first download
    final posterUrl = _downloads.isNotEmpty ? _downloads.first.posterUrl : null;
    final languages =
        _extractLanguages(_downloads.isNotEmpty ? _downloads.first.name : '');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster with overlay and title
          if (posterUrl != null)
            Stack(
              children: [
                // Poster image with correct aspect ratio
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: Image.network(
                    posterUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppTheme.surfaceColor,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 60,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: AppTheme.surfaceColor,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Gradient overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.backgroundColor.withOpacity(0.7),
                          AppTheme.backgroundColor,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.entry.title.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.textPrimary,
                            letterSpacing: 0.5,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        if (languages.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: languages.map((lang) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color:
                                        AppTheme.accentColor.withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  lang.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.accentColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          // Download cards section
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

                      return _DownloadCard(
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
      // Refresh to get latest magnets
      await magnetProvider.refreshMagnets(showLoading: false);

      // Find the magnet item by hash (extract from magnet link)
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

  List<String> _extractLanguages(String name) {
    final languages = <String>[];

    // Extract languages from patterns like [Hindi + Eng] or (Tamil + Telugu)
    final langPattern = RegExp(r'[\[\(]([^\]\)]+?(?:\s*\+\s*[^\]\)]+)+)[\]\)]');
    final match = langPattern.firstMatch(name);

    if (match != null) {
      final langString = match.group(1)!;
      // Split by + and clean up
      languages.addAll(
        langString.split('+').map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    }

    return languages;
  }
}

class _DownloadCard extends StatelessWidget {
  final TorrentDownload download;
  final int index;
  final bool isAdded;
  final VoidCallback onAddMagnet;
  final VoidCallback onRemoveMagnet;

  const _DownloadCard({
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
    // Remove quality, source, codec, and language info to get clean title
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title section with gradient background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.surfaceColor,
                  AppTheme.backgroundColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Text(
              cleanTitle.toUpperCase(),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
                letterSpacing: 0.5,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Divider
          Container(
            height: 2,
            color: AppTheme.borderColor,
          ),
          // Meta section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Badges
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
                const SizedBox(width: 12),
                // Add/Remove button based on status
                if (isAdded)
                  Row(
                    children: [
                      // ADDED badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.successColor.withOpacity(0.3),
                              width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: AppTheme.successColor,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'ADDED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.successColor,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Remove button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onRemoveMagnet,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTheme.errorColor.withOpacity(0.3),
                                  width: 1),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: AppTheme.errorColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  // Add button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onAddMagnet,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_circle,
                              size: 16,
                              color: AppTheme.backgroundColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'ADD',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.backgroundColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (40 * index).ms, duration: 300.ms);
  }
}

// Quality badge widget
class _QualityBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _QualityBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
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

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.primaryColor : AppTheme.textMuted;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
