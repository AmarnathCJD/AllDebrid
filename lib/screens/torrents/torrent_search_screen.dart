import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../models/torrent.dart';
import '../../providers/providers.dart';
import '../../services/recent_searches_service.dart';
import '../../services/torrent_scraper_service.dart';
import '../../theme/app_theme.dart';
import '../player/player_screen.dart';

class TorrentSearchScreen extends StatefulWidget {
  final String? initialQuery;

  const TorrentSearchScreen({super.key, this.initialQuery});

  @override
  State<TorrentSearchScreen> createState() => _TorrentSearchScreenState();
}

class _TorrentSearchScreenState extends State<TorrentSearchScreen> {
  final _scraperService = TorrentScraperService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  List<TorrentEntry> _entries = [];
  List<TorrentEntry> _filteredEntries = [];
  List<String> _recentSearches = [];
  bool _isLoading = false;
  bool _isSearchMode = false;
  String? _error;
  Timer? _debounceTimer;
  String _selectedProvider = 'all';

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _isSearchMode = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadRecentSearches();
      final provider = context.read<AppProvider>();
      final baseUrl = provider.getSetting<String>('torrent_base_url');
      if (baseUrl != null && baseUrl.isNotEmpty) {
        _scraperService.updateBaseUrl(baseUrl);
      }

      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        _performSearch();
      } else {
        _loadEntries();
      }
    });

    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {});
  }

  Future<void> _loadRecentSearches() async {
    final searches = await RecentSearchesService.getRecentSearches();
    if (mounted) setState(() => _recentSearches = searches);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _scraperService.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _isSearchMode = true;
      _error = null;
      _entries = [];
    });
    _focusNode.unfocus();

    try {
      final entries = await _scraperService.search(query);
      if (mounted) {
        await RecentSearchesService.addSearch(query);
        await _loadRecentSearches();

        setState(() {
          _entries = entries;
          _applyProviderFilter();
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

  void _applyProviderFilter() {
    if (_selectedProvider == 'all') {
      _filteredEntries = _entries;
    } else {
      _filteredEntries = _entries.where((entry) {
        try {
          return entry.source.toLowerCase() == _selectedProvider.toLowerCase();
        } catch (_) {
          return false;
        }
      }).toList();
    }
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _isSearchMode = false;
      _error = null;
    });

    try {
      final entries = await _scraperService.fetchHomepage();
      if (mounted) {
        setState(() {
          _entries = entries;
          _applyProviderFilter();
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

  void _clearSearch() {
    _searchController.clear();
    setState(() => _isSearchMode = false);
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSliverAppBar(),
              _buildSearchBarSliver(),
              if (!_isSearchMode && _recentSearches.isNotEmpty)
                _buildRecentSearchesSliver(),
              _buildFilterSliver(),
              _buildContentSliver(),
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.backgroundColor,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        expandedTitleScale: 1.5,
        title: Text(
          'DISCOVER',
          style: GoogleFonts.bebasNeue(
            color: Colors.white,
            fontSize: 24,
            letterSpacing: 2.0,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor.withValues(alpha: 0.1),
                    AppTheme.backgroundColor,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (!_isLoading)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: _isSearchMode ? _clearSearch : _loadEntries,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(
                _isSearchMode ? Icons.close_rounded : Icons.refresh_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchBarSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(Icons.search_rounded,
                  color: Colors.white.withValues(alpha: 0.4), size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  onSubmitted: (_) => _performSearch(),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search movies, shows...',
                    hintStyle: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: Icon(Icons.arrow_forward_rounded,
                      color: AppTheme.primaryColor),
                  onPressed: _performSearch,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSearchesSliver() {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: _recentSearches.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final search = _recentSearches[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _searchController.text = search;
                  _performSearch();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded,
                          size: 14, color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 6),
                      Text(
                        search,
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
    );
  }

  Widget _buildFilterSliver() {
    final providers = [
      {'label': 'All', 'value': 'all', 'icon': Icons.grid_view_rounded},
      {'label': 'TamilMV', 'value': 'tamilmv', 'icon': Icons.movie_rounded},
      {'label': 'CSV', 'value': 'csv', 'icon': Icons.data_usage_rounded},
      {'label': 'Rarbg', 'value': 'rarbg', 'icon': Icons.download_done_rounded},
      {'label': '1337x', 'value': '1377x', 'icon': Icons.bolt_rounded},
      {'label': 'YTS', 'value': 'yts', 'icon': Icons.hd_rounded},
      {
        'label': 'TorrentTip',
        'value': 'torrenttip',
        'icon': Icons.lightbulb_rounded
      },
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SizedBox(
          height: 38,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: providers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final p = providers[index];
              final isSelected = _selectedProvider == p['value'];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedProvider = p['value'] as String;
                      _applyProviderFilter();
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: 200.ms,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          p['icon'] as IconData,
                          size: 16,
                          color: isSelected
                              ? Colors.black
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          p['label'] as String,
                          style: GoogleFonts.outfit(
                            color: isSelected
                                ? Colors.black
                                : Colors.white.withValues(alpha: 0.7),
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
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
      ),
    );
  }

  Widget _buildContentSliver() {
    if (_isLoading) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildShimmerItem(),
          childCount: 6,
        ),
      );
    }

    if (_error != null) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredEntries.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 64, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 16),
              Text(
                'No results found',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = _filteredEntries[index];
          return _buildResultCard(entry, index);
        },
        childCount: _filteredEntries.length,
      ),
    );
  }

  Widget _buildShimmerItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Shimmer.fromColors(
        baseColor: Colors.white.withValues(alpha: 0.05),
        highlightColor: Colors.white.withValues(alpha: 0.1),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(TorrentEntry entry, int index) {
    final quality = _extractQuality(entry.title);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openTorrentDetails(entry),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildSourceTag(entry.source),
                    if (quality != null) ...[
                      const SizedBox(width: 8),
                      _buildQualityTag(quality),
                    ],
                    const Spacer(),
                    if (entry.size != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.size!,
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  entry.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildStat(
                      Icons.arrow_upward_rounded,
                      '${entry.seeders ?? 0}',
                      const Color(0xFF4CAF50),
                    ),
                    const SizedBox(width: 16),
                    _buildStat(
                      Icons.arrow_downward_rounded,
                      '${entry.leechers ?? 0}',
                      const Color(0xFFEF5350),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.download_rounded,
                      color: AppTheme.primaryColor.withValues(alpha: 0.8),
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: (50 * index).ms)
        .slideY(begin: 0.1);
  }

  String? _extractQuality(String title) {
    if (title.contains('2160p') || title.contains('4K')) return '4K';
    if (title.contains('1080p')) return '1080P';
    if (title.contains('720p')) return '720P';
    if (title.contains('HDR')) return 'HDR';
    if (title.contains('HEVC')) return 'HEVC';
    return null;
  }

  Widget _buildSourceTag(String source) {
    Color color;
    String label = source.toUpperCase();

    if (label.contains('RARBG')) {
      color = const Color(0xFF9C27B0);
    } else if (label.contains('1377')) {
      color = const Color(0xFFE53935);
    } else if (label.contains('CSV')) {
      color = const Color(0xFF2196F3);
    } else if (label.contains('TAMIL')) {
      color = const Color(0xFFFFC107);
    } else {
      color = AppTheme.primaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.length > 8 ? label.substring(0, 8) : label,
        style: GoogleFonts.outfit(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildQualityTag(String quality) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Text(
        quality,
        style: GoogleFonts.outfit(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // Legacy helper removed or replaced

  void _openTorrentDetails(TorrentEntry entry) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _TorrentDetailsScreen(
          entry: entry,
          scraperService: _scraperService,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
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
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                pinned: true,
                backgroundColor: AppTheme.backgroundColor,
                title: Text(
                  'TORRENT DETAILS',
                  style: GoogleFonts.bebasNeue(letterSpacing: 2),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.entry.title,
                        style: GoogleFonts.sora(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Removed metadata chips since properties don't exist
                      const SizedBox(height: 16),
                      Text(
                        'DOWNLOADS',
                        style: GoogleFonts.outfit(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (_error != null)
                        Text('Error: $_error',
                            style: TextStyle(color: AppTheme.errorColor))
                      else if (_downloads.isEmpty)
                        Text('No download links found.',
                            style: GoogleFonts.outfit(color: Colors.white54))
                      else
                        ..._downloads.map((d) => _buildDownloadTile(d)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadTile(TorrentDownload download) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        title: Text(
          download.name,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: download.size.isNotEmpty
            ? Text(download.size, style: TextStyle(color: Colors.white54))
            : null,
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.rocket_launch_rounded,
              color: AppTheme.primaryColor, size: 20),
        ),
        onTap: () => _handleDownload(download),
      ),
    );
  }

  Future<void> _handleDownload(TorrentDownload download) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Processing magnet link...',
          style: GoogleFonts.outfit(),
        ),
        backgroundColor: Colors.black87,
      ),
    );

    try {
      final magnetLink = download.magnetLink;

      if (magnetLink.isNotEmpty && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerScreen(
              url: magnetLink,
              title: widget.entry.title,
            ),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not retrieve magnet link')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
