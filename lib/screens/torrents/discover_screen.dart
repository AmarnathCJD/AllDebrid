import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_theme.dart';
import '../../models/torrent.dart';
import '../../services/torrent_scraper_service.dart';
import '../../services/imdb_service.dart';
import 'torrent_details_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class DiscoverScreen extends StatefulWidget {
  final String? initialQuery;
  const DiscoverScreen({super.key, this.initialQuery});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<TorrentEntry> _results = [];
  List<TorrentEntry> _filteredResults = [];

  bool _isLoading = false;
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _showSuggestions = false;
  String _selectedProvider = 'All';
  String _currentQuery = '';
  int _currentPage = 1;

  List<ImdbSearchResult> _suggestions = [];
  Timer? _suggestionDebounce;

  late AnimationController _fabController;
  final ImdbService _imdbService = ImdbService();

  final List<Map<String, String>> _providers = [
    {'name': 'All', 'value': 'All'},
    {'name': 'TamilMV', 'value': 'tamilmv'},
    {'name': 'CSV', 'value': 'csv'},
    {'name': 'Rarbg', 'value': 'rarbg'},
    {'name': '1377x', 'value': '1377x'},
    {'name': 'TorrentTip', 'value': 'torrenttip'},
  ];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _searchFocus.addListener(() {
      setState(() => _isSearching = _searchFocus.hasFocus);
    });

    _scrollController.addListener(_onScroll);

    // Load TamilMV cached entries on init
    // Load TamilMV cached entries on init
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      // Use short delay to ensure UI is built
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _isSearching = true;
          _performSearch(widget.initialQuery!);
        }
      });
    } else {
      _loadInitialEntries();
    }
  }

  void _onScroll() {
    // Pagination logic
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && !_isLoading && _currentQuery.isNotEmpty) {
        _loadMoreResults();
      }
    }

    // FAB Visibility Logic
    if (_scrollController.offset > 300) {
      if (_fabController.status != AnimationStatus.completed &&
          _fabController.status != AnimationStatus.forward) {
        _fabController.forward();
      }
    } else {
      if (_fabController.status != AnimationStatus.dismissed &&
          _fabController.status != AnimationStatus.reverse) {
        _fabController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    _fabController.dispose();
    _debounce?.cancel();
    _suggestionDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchSuggestions(String query) async {
    // 1. Don't fetch if currently loading a main search
    if (_isLoading) return;

    // 2. Don't fetch if query matches what we just searched for
    if (query.trim() == _currentQuery.trim()) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
      }
      return;
    }

    try {
      final results = await _imdbService.search(query);

      // 3. Double check loading state before showing
      if (mounted && !_isLoading) {
        setState(() {
          _suggestions = results.take(6).toList();
          _showSuggestions = results.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
      }
    }
  }

  Future<void> _loadInitialEntries() async {
    setState(() => _isLoading = true);

    try {
      final scraper = TorrentScraperService();
      final entries = await scraper.fetchHomepage();

      if (mounted) {
        setState(() {
          _results = entries;
          _filteredResults = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;

    // Cancel any pending suggestion fetch
    _suggestionDebounce?.cancel();
    _searchFocus.unfocus();

    // Close suggestions
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });

    setState(() {
      _isLoading = true;
      _currentQuery = query;
      _currentPage = 1;
    });

    try {
      final scraper = TorrentScraperService();
      final results = await scraper.search(query);

      setState(() {
        _results = results;
        _applyFilters();
        _isLoading = false;
      });

      if (_results.isNotEmpty) {
        // _fabController.forward(); // Handled by scroll listener now
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    try {
      final scraper = TorrentScraperService();
      final results = await scraper.search('$_currentQuery page:$_currentPage');

      if (mounted && results.isNotEmpty) {
        setState(() {
          _results.addAll(results);
          _applyFilters();
          _isLoadingMore = false;
        });
      } else {
        setState(() => _isLoadingMore = false);
      }
    } catch (e) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _applyFilters() {
    var filtered = List<TorrentEntry>.from(_results);

    if (_selectedProvider != 'All') {
      filtered = filtered.where((e) => e.source == _selectedProvider).toList();
    }

    setState(() => _filteredResults = filtered);
  }

  Future<void> _handleRefresh() async {
    if (_searchController.text.isNotEmpty) {
      await _performSearch(_searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () {
              // Close suggestions when tapping outside
              if (_showSuggestions) {
                setState(() {
                  _showSuggestions = false;
                  _searchFocus.unfocus();
                });
              }
            },
            onHorizontalDragEnd: (details) {
              // Swipe left = next provider
              if (details.primaryVelocity! < -500) {
                _changeProvider(1);
              }
              // Swipe right = previous provider
              else if (details.primaryVelocity! > 500) {
                _changeProvider(-1);
              }
            },
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: AppTheme.primaryColor,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(),
                  _buildSearchSection(),
                  if (_searchController.text.isNotEmpty) _buildFilterChips(),
                  _buildBody(),
                ],
              ),
            ),
          ),
          // Overlay suggestions
          if (_showSuggestions && _suggestions.isNotEmpty)
            Positioned(
              top: 165,
              left: 16,
              right: 16,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.cardColor,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.borderColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 4.0,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _suggestions[index];
                        return InkWell(
                          onTap: () {
                            _searchController.text = suggestion.title;
                            _performSearch(suggestion.title);
                            _searchFocus.unfocus();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                suggestion.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  void _changeProvider(int direction) {
    final currentIndex = _providers.indexWhere(
      (p) => p['value'] == _selectedProvider,
    );

    if (currentIndex == -1) return;

    final newIndex = (currentIndex + direction) % _providers.length;
    final normalizedIndex = newIndex < 0 ? _providers.length - 1 : newIndex;

    setState(() {
      _selectedProvider = _providers[normalizedIndex]['value']!;
      _applyFilters();
    });
  }

  Widget _buildSliverAppBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SEARCH',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 1.5,
              ),
            ),
            const Text(
              'DISCOVER',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
                height: 1,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GestureDetector(
          onTap: () {
            _searchFocus.requestFocus();
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _searchFocus.hasFocus
                    ? AppTheme.primaryColor
                    : AppTheme.borderColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Search movies, shows...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 22,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.white.withValues(alpha: 0.5),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onSubmitted: _performSearch,
              onChanged: (value) {
                setState(() {});

                // Only fetch IMDb suggestions, don't auto-search
                if (_suggestionDebounce?.isActive ?? false)
                  _suggestionDebounce!.cancel();
                _suggestionDebounce =
                    Timer(const Duration(milliseconds: 300), () {
                  if (value.length >= 2) {
                    _fetchSuggestions(value);
                  } else {
                    setState(() {
                      _suggestions = [];
                      _showSuggestions = false;
                    });
                  }
                });
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _providers.map((provider) {
              final providerName = provider['name']!;
              final providerValue = provider['value']!;
              final isSelected = providerValue == _selectedProvider;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(providerName),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? Colors.black
                        : Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  selected: isSelected,
                  selectedColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.cardColor,
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  onSelected: (_) {
                    setState(() {
                      _selectedProvider = providerValue;
                      _applyFilters();
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryColor),
        ),
      );
    }

    if (_filteredResults.isEmpty && !_isSearching) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchController.text.isEmpty
                    ? Icons.explore_rounded
                    : Icons.search_off_rounded,
                size: 56,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isEmpty
                    ? 'Discover Torrents'
                    : 'No results found',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _searchController.text.isEmpty
                    ? 'Search for movies, shows, or any content'
                    : 'Try different keywords or change provider',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == _filteredResults.length) {
              return _isLoadingMore
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : const SizedBox.shrink();
            }

            return _TorrentCard(
              entry: _filteredResults[index],
              index: index,
            )
                .animate()
                .fadeIn(delay: (20 * (index % 15)).ms, duration: 250.ms)
                .slideY(begin: 0.03, end: 0, duration: 250.ms);
          },
          childCount: _filteredResults.length + (_isLoadingMore ? 1 : 0),
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _fabController,
        curve: Curves.easeInOut,
      ),
      child: FloatingActionButton.extended(
        heroTag: 'discover_fab',
        onPressed: () {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        },
        backgroundColor: AppTheme.primaryColor,
        //icon: const Icon(Icons.arrow_upward_rounded),
        label: const Icon(Icons.arrow_upward_rounded),
        shape: const CircleBorder(),
        elevation: 0,
      ),
    );
  }
}

// Custom Torrent Card Widget
class _TorrentCard extends StatelessWidget {
  final TorrentEntry entry;
  final int index;

  const _TorrentCard({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    final quality = _extractQuality(entry.title);
    final seeders = entry.seeders ?? 0;
    final leechers = entry.leechers ?? 0;
    final healthRatio =
        seeders + leechers > 0 ? seeders / (seeders + leechers) : 0.0;
    final sourceColor = _getSourceColor(entry.source);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TorrentDetailsScreen(
                  entry: entry,
                  scraperService: TorrentScraperService(),
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  entry.title.replaceAll('.', ' ').trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 10),

                // Tags row - using Wrap to prevent overflow
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Source tag
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: sourceColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        entry.source.toUpperCase().length > 10
                            ? entry.source.toUpperCase().substring(0, 10)
                            : entry.source.toUpperCase(),
                        style: GoogleFonts.robotoMono(
                          color: sourceColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (quality != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: quality == '4K'
                              ? LinearGradient(
                                  colors: [
                                    Colors.amber.withValues(alpha: 0.15),
                                    Colors.orange.withValues(alpha: 0.08),
                                  ],
                                )
                              : null,
                          color: quality != '4K'
                              ? Colors.white.withValues(alpha: 0.06)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          quality,
                          style: GoogleFonts.robotoMono(
                            color: quality == '4K'
                                ? Colors.amber
                                : Colors.white.withValues(alpha: 0.8),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (entry.size != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          entry.size!,
                          style: GoogleFonts.robotoMono(
                            color: Colors.white60,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    // Seeders
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_upward_rounded,
                              size: 10, color: Color(0xFF4CAF50)),
                          const SizedBox(width: 2),
                          Text(
                            '$seeders',
                            style: const TextStyle(
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Leechers
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF5350).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_downward_rounded,
                              size: 10, color: Color(0xFFEF5350)),
                          const SizedBox(width: 2),
                          Text(
                            '$leechers',
                            style: TextStyle(
                              color: const Color(0xFFEF5350).withValues(alpha: 0.8),
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Health bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: healthRatio,
                    minHeight: 2,
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      healthRatio > 0.7
                          ? const Color(0xFF4CAF50)
                          : healthRatio > 0.4
                              ? Colors.amber
                              : const Color(0xFFEF5350),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _extractQuality(String title) {
    if (title.contains('2160p') || title.contains('4K')) return '4K';
    if (title.contains('1080p')) return '1080P';
    if (title.contains('720p')) return '720P';
    if (title.contains('480p')) return '480P';
    return null;
  }

  Color _getSourceColor(String source) {
    final label = source.toUpperCase();
    if (label.contains('RARBG')) return const Color(0xFF9C27B0);
    if (label.contains('1377')) return const Color(0xFFE53935);
    if (label.contains('CSV')) return const Color(0xFF2196F3);
    if (label.contains('TAMIL')) return const Color(0xFFFFC107);
    if (label.contains('TORRENT')) return const Color(0xFF00BCD4);
    return AppTheme.primaryColor;
  }
}

// Custom Particle Painter for animated background
class ParticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 20; i++) {
      final x = (i * 50) % size.width;
      final y = (i * 30) % size.height;
      canvas.drawCircle(Offset(x, y), 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
