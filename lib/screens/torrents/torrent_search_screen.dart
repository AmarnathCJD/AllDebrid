import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_theme.dart';
import '../../models/torrent.dart';
import '../../services/torrent_scraper_service.dart';
import '../../services/imdb_service.dart';
import '../../providers/providers.dart';

import '../../widgets/common/common_widgets.dart';

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
  List<TorrentEntry> _entries = [];
  List<TorrentEntry> _filteredEntries = [];
  bool _isLoading = false;
  bool _isSearchMode = false;
  String? _error;
  Timer? _debounceTimer;
  String _selectedProvider = 'all';
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Set initial query if provided
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _isSearchMode = true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      final baseUrl = provider.getSetting<String>('torrent_base_url');
      if (baseUrl != null && baseUrl.isNotEmpty) {
        _scraperService.updateBaseUrl(baseUrl);
      }

      // If we have initial query, search immediately
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        _performSearch();
      } else {
        _loadEntries();
      }
    });
  }

  void _onScroll() {
    if (_scrollController.offset > 300 && !_showScrollToTop) {
      setState(() => _showScrollToTop = true);
    } else if (_scrollController.offset <= 300 && _showScrollToTop) {
      setState(() => _showScrollToTop = false);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
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
      _entries = []; // Clear entries to show fresh results immediately
    });

    try {
      final entries = await _scraperService.search(query);
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
          _error = e
              .toString()
              .replaceFirst('Exception: ', '')
              .replaceFirst('FormatException: ', '');
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
          return entry.source == _selectedProvider;
        } catch (e) {
          return _selectedProvider == 'tamilmv';
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
        // Keep original order from TamilMV (most recent first)
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
    setState(() {
      _isSearchMode = false;
    });
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildProviderFilter(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                );
              },
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.arrow_upward, size: 20),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.surfaceColor.withValues(alpha: 0.8),
            AppTheme.backgroundColor,
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSearchMode ? 'SEARCH RESULTS' : 'DISCOVER',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _isSearchMode
                          ? 'Find your content'
                          : 'Browse latest torrents',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    if (_filteredEntries.isNotEmpty && !_isLoading) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_filteredEntries.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!_isLoading)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isSearchMode ? _clearSearch : _loadEntries,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.borderColor.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    _isSearchMode ? Icons.close : Icons.refresh_rounded,
                    size: 20,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSearchBar() {
    final hasText = _searchController.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading
              ? null
              : () {
                  showSearch(
                    context: context,
                    delegate: _CustomSearchDelegate(
                      entries: _entries,
                      onSearch: (query) {
                        _searchController.text = query;
                        _debounceTimer?.cancel();
                        _performSearch();
                      },
                      initialQuery: _searchController.text,
                    ),
                  );
                },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.borderColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Icon(
                    Icons.search_rounded,
                    size: 22,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Expanded(
                  child: Text(
                    hasText
                        ? _searchController.text
                        : 'Search movies, shows, anime...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: hasText ? FontWeight.w500 : FontWeight.w400,
                      color: hasText
                          ? AppTheme.textPrimary
                          : AppTheme.textMuted.withValues(alpha: 0.6),
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasText)
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  )
                else
                  Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'TAP',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildProviderFilter() {
    final providers = [
      {'label': 'All', 'value': 'all', 'icon': Icons.apps_rounded},
      {'label': 'TamilMV', 'value': 'tamilmv', 'icon': Icons.movie_rounded},
      {'label': 'CSV', 'value': 'csv', 'icon': Icons.table_chart_rounded},
      {'label': 'Rarbg', 'value': 'rarbg', 'icon': Icons.download_rounded},
      {'label': '1337x', 'value': '1377x', 'icon': Icons.layers_rounded},
      {'label': 'TT', 'value': 'torrenttip', 'icon': Icons.speed_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.borderColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: providers.map((provider) {
                  final isSelected = _selectedProvider == provider['value'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedProvider = provider['value'] as String;
                          _applyProviderFilter();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              provider['icon'] as IconData,
                              size: 16,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textMuted,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              provider['label'] as String,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms, duration: 300.ms);
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: const SkeletonCard(height: 110),
        ),
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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.errorColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'OOPS!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.errorColor,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _isSearchMode ? _performSearch : _loadEntries,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('TRY AGAIN'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.borderColor.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Icon(
                _isSearchMode
                    ? Icons.search_off_rounded
                    : Icons.movie_filter_outlined,
                size: 56,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isSearchMode ? 'NO RESULTS FOUND' : 'NO CONTENT',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isSearchMode
                  ? 'Try different keywords or filters'
                  : 'Check back later for new content',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
    final sourceColor = _getSourceColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.cardColor.withValues(alpha: 0.95),
            AppTheme.cardColor.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: sourceColor.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Box
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            sourceColor.withValues(alpha: 0.2),
                            sourceColor.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: sourceColor.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _getSourceIcon(),
                        color: sourceColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              // Source Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: sourceColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getSourceShortName().toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: sourceColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Result Number
                              Text(
                                '#${index + 1}',
                                style: TextStyle(
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
                const SizedBox(height: 10),

                // Meta Row: Size, Seeders, Leechers
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (entry.size != null && entry.size!.isNotEmpty)
                        _buildMetaStat(
                          Icons.storage_rounded,
                          entry.size!,
                          Colors.blue.shade300,
                        ),
                      if (entry.size != null && entry.seeders != null)
                        const SizedBox(width: 16),
                      if (entry.seeders != null)
                        _buildMetaStat(
                          Icons.trending_up_rounded,
                          '${entry.seeders} Seeds',
                          Colors.green.shade400,
                        ),
                      if (entry.seeders != null && entry.leechers != null)
                        const SizedBox(width: 16),
                      if (entry.leechers != null)
                        _buildMetaStat(
                          Icons.trending_down_rounded,
                          '${entry.leechers} Peers',
                          Colors.red.shade400,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: (40 * index).ms).fadeIn(duration: 350.ms).slideY(
        begin: 0.15, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildMetaStat(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String get _safeSource {
    try {
      return entry.source;
    } catch (e) {
      return 'tamilmv';
    }
  }

  String _getSourceShortName() {
    if (_safeSource == 'tamilmv') {
      return 'TMV';
    }
    return _safeSource.length > 4
        ? _safeSource.substring(0, 4).toUpperCase()
        : _safeSource.toUpperCase();
  }

  Color _getSourceColor() {
    switch (_safeSource) {
      case 'csv':
        return Colors.blue.shade400;
      case 'rarbg':
        return Colors.purple.shade400;
      case '1377x':
        return Colors.orange.shade400;
      case 'torrenttip':
        return Colors.red.shade400;
      case 'tamilmv':
      default:
        return AppTheme.accentColor;
    }
  }

  IconData _getSourceIcon() {
    switch (_safeSource) {
      case 'tamilmv':
        return Icons.local_fire_department_rounded; // 🔥 TamilMV (popular)
      case 'csv':
        return Icons.table_chart_rounded; // 📊 CSV (data)
      case 'rarbg':
        return Icons.cloud_download_rounded; // ☁️ RARBG (cloud)
      case '1377x':
        return Icons.hub_rounded; // 🔗 1337x (network/hub)
      case 'torrenttip':
        return Icons.tips_and_updates_rounded; // 💡 TorrentTip (tips)
      default:
        return Icons.movie_rounded;
    }
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

    final posterUrl = _downloads.isNotEmpty ? _downloads.first.posterUrl : null;
    final languages =
        _extractLanguages(_downloads.isNotEmpty ? _downloads.first.name : '');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (posterUrl != null)
            Stack(
              children: [
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
                          AppTheme.backgroundColor.withValues(alpha: 0.7),
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
                                  color: AppTheme.accentColor
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppTheme.accentColor
                                        .withValues(alpha: 0.5),
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
      await magnetProvider.refreshMagnets(showLoading: false);

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

    final langPattern = RegExp(r'[\[\(]([^\]\)]+?(?:\s*\+\s*[^\]\)]+)+)[\]\)]');
    final match = langPattern.firstMatch(name);

    if (match != null) {
      final langString = match.group(1)!;
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
          Container(
            height: 2,
            color: AppTheme.borderColor,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
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
                ),
                const SizedBox(width: 12),
                if (isAdded)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color:
                                  AppTheme.successColor.withValues(alpha: 0.3),
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
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onRemoveMagnet,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppTheme.errorColor
                                      .withValues(alpha: 0.3),
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
                const SizedBox(width: 8),
                // Copy Magnet Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: download.magnetLink));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Magnet link copied!'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            width: 1),
                      ),
                      child: Icon(
                        Icons.content_copy,
                        size: 16,
                        color: AppTheme.primaryColor,
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

class _QualityBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _QualityBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
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

// IMDb Search Service for fallback suggestions
class _IMDbSearchService {
  static final _imdbService = ImdbService();

  static Future<List<String>> searchMovies(String query) async {
    try {
      final results = await _imdbService.search(query);
      return results.map((result) => result.title).toList().take(8).toList();
    } catch (e) {
      // Silently fail, will use cached suggestions
      return [];
    }
  }
}

// Custom Search Delegate for enhanced search UI
class _CustomSearchDelegate extends SearchDelegate<String> {
  final List<TorrentEntry> entries;
  final Function(String) onSearch;
  final String initialQuery;
  bool _hasRestoredInitialQuery = false;

  _CustomSearchDelegate({
    required this.entries,
    required this.onSearch,
    this.initialQuery = '',
  });

  @override
  String get searchFieldLabel => 'Search movies, shows...';

  InputDecorationTheme get inputDecorationTheme {
    return InputDecorationTheme(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      hintStyle: TextStyle(
        color: AppTheme.textMuted.withValues(alpha: 0.6),
        fontWeight: FontWeight.w400,
      ),
    );
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppTheme.surfaceColor,
        surfaceTintColor: AppTheme.surfaceColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: AppTheme.textMuted.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: GestureDetector(
              onTap: () {
                query = '';
              },
              child: Icon(
                Icons.close_rounded,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    // Set initial query only once, on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasRestoredInitialQuery &&
          query.isEmpty &&
          initialQuery.isNotEmpty) {
        _hasRestoredInitialQuery = true;
        query = initialQuery;
      }
    });

    return GestureDetector(
      onTap: () => close(context, ''),
      child: Icon(
        Icons.arrow_back_rounded,
        color: AppTheme.primaryColor,
      ),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Text(
          'Enter search query',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 14,
          ),
        ),
      );
    }

    // Defer setState call to after build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onSearch(query);
      close(context, query);
    });

    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = query.isEmpty
        ? <String>[]
        : entries
            .where((e) =>
                e.title.toLowerCase().contains(query.toLowerCase()) &&
                !e.title.toLowerCase().startsWith(query.toLowerCase()))
            .map((e) => e.title)
            .toSet()
            .toList()
            .take(8)
            .toList();

    final recentMatches = query.isEmpty
        ? <String>[]
        : entries
            .where((e) => e.title.toLowerCase().startsWith(query.toLowerCase()))
            .map((e) => e.title)
            .toSet()
            .toList()
            .take(8)
            .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (recentMatches.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'MATCHES',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMuted,
                letterSpacing: 1,
              ),
            ),
          ),
          ...recentMatches.map((suggestion) {
            return _buildSuggestionTile(context, suggestion);
          }),
        ],
        if (suggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'RELATED',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.textMuted,
                letterSpacing: 1,
              ),
            ),
          ),
          ...suggestions.map((suggestion) {
            return _buildSuggestionTile(context, suggestion);
          }),
        ],
        // IMDb Suggestions as Fallback using FutureBuilder
        if (recentMatches.isEmpty && suggestions.isEmpty && query.length >= 2)
          FutureBuilder<List<String>>(
            future: _IMDbSearchService.searchMovies(query),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Searching IMDb...',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final imdbSuggestions = snapshot.data ?? [];

              if (imdbSuggestions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: AppTheme.textMuted.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No suggestions',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'FROM IMDb',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.accentColor,
                            letterSpacing: 1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'WEB',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...imdbSuggestions.map((suggestion) {
                    return _buildSuggestionTile(context, suggestion,
                        isImdb: true);
                  }),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildSuggestionTile(
    BuildContext context,
    String suggestion, {
    bool isImdb = false,
  }) {
    return ListTile(
      leading: Icon(
        isImdb ? Icons.language_rounded : Icons.search_rounded,
        size: 18,
        color: isImdb
            ? AppTheme.accentColor.withValues(alpha: 0.7)
            : AppTheme.textMuted.withValues(alpha: 0.6),
      ),
      title: Text(
        suggestion,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.north_west_rounded,
        size: 16,
        color: isImdb
            ? AppTheme.accentColor.withValues(alpha: 0.5)
            : AppTheme.primaryColor.withValues(alpha: 0.5),
      ),
      onTap: () {
        query = suggestion;
        showResults(context);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      tileColor: Colors.transparent,
      hoverColor: AppTheme.primaryColor.withValues(alpha: 0.05),
    );
  }
}
