import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/rivestream_service.dart';
import '../../services/imdb_service.dart';
import 'media_info_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:ui';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../utils/helpers.dart';

class SearchPage extends StatefulWidget {
  final String? initialQuery;
  final bool fromCast;
  const SearchPage({super.key, this.initialQuery, this.fromCast = false});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final RiveStreamService _riveService = RiveStreamService();
  final ImdbService _imdbService = ImdbService();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  List<RiveStreamMedia> _searchResults = [];
  List<RiveStreamMedia> _trendingResults = [];
  List<ImdbSearchResult> _recentItems = [];

  bool _isLoadingTrending = false;
  bool _isLoadingSearch = false;
  bool _isLoadingMore = false;

  bool get _isLoading => _isLoadingTrending || _isLoadingSearch;

  int _currentPage = 1;
  Timer? _debounce;
  String _selectedFilter = 'All';
  bool _isSearchFocused = false;
  late final bool _isCastSearch;

  @override
  void initState() {
    super.initState();
    _isCastSearch = widget.fromCast;
    _fetchInitialData();
    _scrollController.addListener(_onScroll);
    _searchFocusNode.addListener(() {
      setState(() => _isSearchFocused = _searchFocusNode.hasFocus);
    });

    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoadingTrending = true);
    await Future.wait([_fetchTrending(), _fetchRecents()]);
    if (mounted) setState(() => _isLoadingTrending = false);
  }

  Future<void> _fetchRecents() async {
    try {
      final recents = await _imdbService.getRecents();
      if (mounted) setState(() => _recentItems = recents);
    } catch (_) {}
  }

  Future<void> _fetchTrending() async {
    try {
      final trending = await _riveService.getTrending(page: 1);
      if (mounted) {
        setState(() {
          _trendingResults =
              trending.where((item) => item.fullPosterUrl.isNotEmpty).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore) return;
    if (_searchController.text.isEmpty && _selectedFilter != 'All') return;
    if (_isCastSearch) return;

    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      List<RiveStreamMedia> newItems = [];
      if (_searchController.text.isNotEmpty) {
        newItems = await _riveService.searchMulti(_searchController.text,
            page: nextPage);
      } else {
        newItems = await _riveService.getTrending(page: nextPage);
      }
      if (mounted) {
        setState(() {
          final filtered =
              newItems.where((item) => item.fullPosterUrl.isNotEmpty).toList();
          if (filtered.isNotEmpty) {
            if (_searchController.text.isNotEmpty) {
              _searchResults.addAll(filtered);
            } else {
              _trendingResults.addAll(filtered);
            }
            _currentPage = nextPage;
          }
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.isNotEmpty) {
        _currentPage = 1;
        _performSearch(query);
      } else {
        setState(() => _searchResults = []);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoadingSearch = true);
    try {
      late List<RiveStreamMedia> results;
      if (_isCastSearch) {
        results =
            await _riveService.searchPersonAndGetFilmography(query, page: 1);
      } else {
        results = await _riveService.searchMulti(query, page: 1);
      }
      if (mounted) {
        setState(() {
          _searchResults =
              results.where((item) => item.fullPosterUrl.isNotEmpty).toList();
          _isLoadingSearch = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSearch = false);
    }
  }

  List<RiveStreamMedia> get _displayedResults {
    final list =
        _searchController.text.isEmpty ? _trendingResults : _searchResults;
    if (_selectedFilter == 'All') return list;
    if (_selectedFilter == 'Movies') {
      return list.where((m) => m.mediaType == 'movie').toList();
    }
    if (_selectedFilter == 'TV Series') {
      return list.where((m) => m.mediaType == 'tv').toList();
    }
    return list;
  }

  void _handleMediaTap(RiveStreamMedia item) {
    final imdbItem = ImdbSearchResult(
      id: item.id.toString(),
      title: item.displayTitle,
      posterUrl: upgradePosterQuality(item.fullPosterUrl),
      year:
          item.displayDate.isNotEmpty ? item.displayDate.split('-').first : '',
      kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
      rating: item.voteAverage.toStringAsFixed(1),
      description: item.overview,
      backdropUrl: item.fullBackdropUrl,
    );
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) =>
            MediaInfoScreen(item: imdbItem),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved =
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0.0, 0.05), end: Offset.zero)
                  .animate(curved),
              child: child,
            ),
          );
        },
      ),
    ).then((_) => _fetchRecents());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildSearchHeader(),
                _buildFilters(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white70, size: 17),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Hero(
              tag: 'search_bar',
              child: Material(
                type: MaterialType.transparency,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: AnimatedContainer(
                      duration: 200.ms,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isSearchFocused
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearchChanged,
                        style: GoogleFonts.inter(
                            color: Colors.white, fontSize: 15),
                        cursorColor: AppTheme.primaryColor,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search movies, shows...',
                          hintStyle: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.3),
                              fontSize: 14),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 40, maxHeight: 44),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 14, right: 8),
                            child: Icon(Icons.search_rounded,
                                color: _isSearchFocused
                                    ? AppTheme.primaryColor
                                    : AppTheme.primaryColor
                                        .withValues(alpha: 0.7),
                                size: 20),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      size: 17),
                                  color: Colors.white54,
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                    setState(() {});
                                  },
                                )
                              : null,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      height: 52,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            _buildFilterChip('All'),
            const SizedBox(width: 10),
            _buildFilterChip('Movies'),
            const SizedBox(width: 10),
            _buildFilterChip('TV Series'),
            if (_searchResults.isNotEmpty ||
                _searchController.text.isNotEmpty) ...[
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_displayedResults.length} results',
                  style: GoogleFonts.robotoMono(
                    color: AppTheme.primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: AnimatedContainer(
            duration: 200.ms,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white70,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _displayedResults.isEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.68,
          crossAxisSpacing: 12,
          mainAxisSpacing: 16,
        ),
        itemCount: 12,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (_displayedResults.isEmpty) {
      if (_searchController.text.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded,
                      size: 64, color: Colors.white.withValues(alpha: 0.06))
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1.0, 1.0),
                    end: const Offset(1.08, 1.08),
                    duration: 2.seconds,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 16),
              Text('No results found',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Try a different search term',
                  style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13)),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        if (_searchController.text.isEmpty && _recentItems.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded,
                          size: 16, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text('RECENTLY VIEWED',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          )),
                    ],
                  ),
                ),
                SizedBox(
                  height: 170,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _recentItems.length,
                    itemBuilder: (context, index) {
                      final item = _recentItems[index];
                      if (item.posterUrl.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                transitionDuration:
                                    const Duration(milliseconds: 500),
                                reverseTransitionDuration:
                                    const Duration(milliseconds: 400),
                                pageBuilder: (context, animation,
                                        secondaryAnimation) =>
                                    MediaInfoScreen(item: item),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  final curved = CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic);
                                  return FadeTransition(
                                    opacity: curved,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                              begin: const Offset(0.0, 0.05),
                                              end: Offset.zero)
                                          .animate(curved),
                                      child: child,
                                    ),
                                  );
                                },
                              ),
                            ).then((_) => _fetchRecents());
                          },
                          child: Column(
                            children: [
                              Expanded(
                                child: AspectRatio(
                                  aspectRatio: 2 / 3,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: item.posterUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) =>
                                          Container(color: Colors.white10),
                                      errorWidget: (_, __, ___) =>
                                          Container(color: Colors.white10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Icon(
                    _searchController.text.isEmpty
                        ? Icons.local_fire_department_rounded
                        : Icons.grid_view_rounded,
                    color: AppTheme.primaryColor,
                    size: 18),
                const SizedBox(width: 8),
                Text(
                  _searchController.text.isEmpty ? 'TRENDING NOW' : 'RESULTS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.68,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _displayedResults[index];
                return AnimationConfiguration.staggeredGrid(
                  position: index,
                  columnCount: 3,
                  duration: const Duration(milliseconds: 400),
                  child: ScaleAnimation(
                    scale: 0.92,
                    child: FadeInAnimation(
                      child: _buildMediaCard(item, index),
                    ),
                  ),
                );
              },
              childCount: _displayedResults.length,
            ),
          ),
        ),
        if (_isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primaryColor),
                ),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );
  }

  Widget _buildMediaCard(RiveStreamMedia item, int index) {
    return _PressScaleCard(
      onTap: () => _handleMediaTap(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'search_media_${item.id}',
                child: CachedNetworkImage(
                  imageUrl: item.fullPosterUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: Colors.white.withValues(alpha: 0.05)),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.white.withValues(alpha: 0.05),
                    child: const Icon(Icons.movie_creation_outlined,
                        color: Colors.white24),
                  ),
                ),
              ),
              Positioned(
                bottom: 5,
                left: 5,
                right: 5,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1), width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (item.displayDate.isNotEmpty)
                            Text(
                              item.displayDate.split('-').first,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const Spacer(),
                          if (item.voteAverage > 0)
                            Row(
                              children: [
                                Icon(Icons.star_rounded,
                                    size: 10, color: AppTheme.primaryColor),
                                const SizedBox(width: 2),
                                Text(
                                  item.voteAverage.toStringAsFixed(1),
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (item.mediaType.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 0.5),
                        ),
                        child: Text(
                          item.mediaType == 'movie' ? 'MOVIE' : 'TV',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PressScaleCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _PressScaleCard({required this.child, this.onTap});

  @override
  State<_PressScaleCard> createState() => _PressScaleCardState();
}

class _PressScaleCardState extends State<_PressScaleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 200),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}
