import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart' as provider_pkg;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/providers.dart';
import '../../providers/home_providers.dart';
import '../../theme/app_theme.dart';

import '../../services/imdb_service.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../services/rivestream_service.dart';
import 'media_info_screen.dart';
import 'search_page.dart';
import '../watchlist/watchlist_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static final homeKey = GlobalKey<_HomeScreenState>();

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  final ScrollController _scrollController = ScrollController();

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handleRiveMediaNavigation(RiveStreamMedia item) {
    _handleMediaTap(ImdbSearchResult(
      id: item.id.toString(),
      title: item.displayTitle,
      posterUrl: item.fullPosterUrl,
      year:
          item.displayDate.isNotEmpty ? item.displayDate.split('-').first : '',
      kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
      rating: item.voteAverage.toStringAsFixed(1),
      description: item.overview,
    ));
  }

  late AnimationController _headerAnimController;

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppProvider>().refreshUser();
      context.read<MagnetProvider>().fetchMagnets();
      context.read<TrendingProvider>().loadTrendingData();
      context.read<KDramaProvider>().loadTopDramas();
      context.read<KDramaProvider>().loadLatestDramas();
    });
  }

  void _onScroll() {
    if (_scrollController.offset > 100) {
      if (!_headerAnimController.isCompleted) {
        _headerAnimController.forward();
      }
    } else {
      if (_headerAnimController.isCompleted) {
        _headerAnimController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _headerAnimController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('[HomeScreen] didChangeDependencies called');
  }

  @override
  void didPopNext() {
    ref.invalidate(continueWatchingProvider);
  }

  Future<void> _onRefresh() async {
    debugPrint('[HomeScreen] _onRefresh() called');
    ref.invalidate(riveTrendingProvider);
    ref.invalidate(continueWatchingProvider);
    await Future.wait([
      context.read<AppProvider>().refreshUser(),
      context.read<MagnetProvider>().fetchMagnets(),
      context.read<TrendingProvider>().loadTrendingData(),
      context.read<KDramaProvider>().loadTopDramas(),
      context.read<KDramaProvider>().loadLatestDramas(),
    ]);
    debugPrint('[HomeScreen] _onRefresh() completed');
  }

  void _showCardContextMenu(
    BuildContext context, {
    required String title,
    required VoidCallback onAddWatchlist,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF151515).withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(vertical: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    InkWell(
                      onTap: onAddWatchlist,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bookmark_rounded,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Add to Watchlist',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        HapticFeedback.mediumImpact();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.share_rounded,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Share',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
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

  void _showWatchlistContextMenu(
    BuildContext context, {
    required String title,
    required ImdbSearchResult item,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF151515).withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(vertical: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    HapticFeedback.mediumImpact();
                    context.read<AppProvider>().toggleWatchlist(item);
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Removed from Watchlist'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Color(0xFF1E1E1E),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.bookmark_remove_rounded,
                          color: Colors.red[400],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Remove from Watchlist',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14,
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
      ),
    );
  }

  void _showContinueWatchingContextMenu(
    BuildContext context, {
    required String title,
    required String mediaId,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF151515).withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(vertical: 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(context);
                    HapticFeedback.mediumImpact();
                    try {
                      final imdbService = ImdbService();
                      await imdbService.removeFromContinueWatching(mediaId);
                      ref.invalidate(continueWatchingProvider);
                    } catch (e) {
                      debugPrint('Error removing from continue watching: $e');
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Removed from Continue Watching'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: Color(0xFF1E1E1E),
                        ),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          color: Colors.red[400],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Remove from List',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 14,
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
      ),
    );
  }

  void _handleMediaTap(ImdbSearchResult item) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) =>
            MediaInfoScreen(item: item),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final forwardCurved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutExpo,
          );
          final backwardCurved = CurvedAnimation(
            parent: secondaryAnimation,
            curve: Curves.easeInCubic,
          );

          return Stack(
            children: [
              // Background fade
              ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1.0)
                    .animate(backwardCurved),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.0, end: 1.0)
                      .animate(forwardCurved),
                  child: Container(color: Colors.black54),
                ),
              ),
              // Content with diagonal slide + fade + scale
              FadeTransition(
                opacity:
                    Tween<double>(begin: 0.0, end: 1.0).animate(forwardCurved),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0.08),
                    end: Offset.zero,
                  ).animate(forwardCurved),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.90, end: 1.0)
                        .animate(forwardCurved),
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[HomeScreen] build() called');
    final trendingAsync = ref.watch(riveTrendingProvider);
    final continueWatchingAsync = ref.watch(continueWatchingProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Static Background
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.8),
            ),
          ),

          SafeArea(
            top: false,
            child: RefreshIndicator(
              color: AppTheme.primaryColor,
              backgroundColor: AppTheme.cardColor,
              onRefresh: _onRefresh,
              child: CustomScrollView(
                controller: _scrollController,
                cacheExtent: 150,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                      child: SizedBox(
                          height: MediaQuery.paddingOf(context).top + 12)),
                  const SliverToBoxAdapter(child: SizedBox(height: 4)),
                  SliverToBoxAdapter(child: _buildHeader()),
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: trendingAsync.when(
                        data: (trendingData) => _FeaturedCarouselWidget(
                            items: trendingData.featured),
                        loading: () => SizedBox(
                          height: 530,
                          child: Shimmer.fromColors(
                            baseColor: Colors.white.withValues(alpha: 0.05),
                            highlightColor:
                                Colors.white.withValues(alpha: 0.08),
                            period: const Duration(milliseconds: 1000),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 30, vertical: 20),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        error: (_, __) => SizedBox(
                          height: 530,
                          child: Shimmer.fromColors(
                            baseColor: Colors.white.withValues(alpha: 0.05),
                            highlightColor:
                                Colors.white.withValues(alpha: 0.08),
                            period: const Duration(milliseconds: 1000),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 30, vertical: 20),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: continueWatchingAsync.when(
                        data: (items) => items.isEmpty
                            ? const SizedBox.shrink()
                            : _buildContinueWatchingSection(items),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: continueWatchingAsync.when(
                      data: (items) => items.isEmpty
                          ? const SizedBox.shrink()
                          : const SizedBox(height: 8),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                  SliverToBoxAdapter(
                      child: RepaintBoundary(child: _buildWatchlistSection())),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: trendingAsync.maybeWhen(
                        data: (trendingData) => _buildRiveTrendingMoviesSection(
                            trendingData.movies),
                        orElse: () => _buildShimmerCardRow(),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: trendingAsync.maybeWhen(
                        data: (trendingData) =>
                            _buildRiveTrendingTVShowsSection(
                                trendingData.tvShows),
                        orElse: () => _buildShimmerCardRow(),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                      child: RepaintBoundary(child: _buildNetflixSection())),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                      child:
                          RepaintBoundary(child: _buildAmazonPrimeSection())),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                      child: RepaintBoundary(child: _buildTopKDramasSection())),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                      child:
                          RepaintBoundary(child: _buildLatestKDramasSection())),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                      child: RepaintBoundary(
                          child: _buildGenreSection('Action', 'ls000'))),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                      child: RepaintBoundary(
                          child: _buildGenreSection('Comedy', 'ls001'))),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                      child: RepaintBoundary(
                          child: _buildGenreSection('Horror', 'ls002'))),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverToBoxAdapter(
                      child: RepaintBoundary(
                          child: _buildGenreSection('Sci-Fi', 'ls003'))),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _scrollController,
        builder: (context, child) {
          final offset =
              _scrollController.hasClients ? _scrollController.offset : 0.0;
          return AnimatedOpacity(
            opacity: offset > 300 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: AnimatedSlide(
              offset: offset > 300 ? Offset.zero : const Offset(0, 2),
              duration: const Duration(milliseconds: 300),
              child: FloatingActionButton(
                heroTag: 'scroll_to_top',
                backgroundColor: AppTheme.primaryColor,
                onPressed: () {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                  );
                },
                child:
                    const Icon(Icons.arrow_upward_rounded, color: Colors.black),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return ScaleTransition(
      scale:
          Tween<double>(begin: 1.0, end: 0.92).animate(_headerAnimController),
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity:
            Tween<double>(begin: 1.0, end: 0.5).animate(_headerAnimController),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const SearchPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  );
                },
                child: Hero(
                  tag: 'search_bar',
                  child: Material(
                    color: Colors.transparent,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded,
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.7)),
                              const SizedBox(width: 12),
                              Text(
                                'Search movies, shows...',
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontSize: 15,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'MOVIES & TV',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildShimmerCardRow() {
    return SizedBox(
      height: 230,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        addRepaintBoundaries: false,
        addSemanticIndexes: false,
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          period: const Duration(milliseconds: 1000),
          child: Container(
            width: 120,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title,
      {VoidCallback? onTap, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          if (trailing != null)
            trailing
          else if (onTap != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'VIEW ALL',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white.withValues(alpha: 0.4),
                        size: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRiveTrendingMoviesSection(List<RiveStreamMedia> movies) {
    if (movies.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Trending Movies'),
          _buildShimmerCardRow(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Trending Movies'),
        const SizedBox(height: 0),
        AnimationLimiter(
          child: SizedBox(
            height: 230,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: movies.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              addRepaintBoundaries: false,
              addSemanticIndexes: false,
              itemBuilder: (context, index) {
                final item = movies[index];
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 350),
                  child: SlideAnimation(
                    horizontalOffset: 30.0,
                    child: FadeInAnimation(
                      child: _buildRiveMediaCard(item),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRiveTrendingTVShowsSection(List<RiveStreamMedia> tvShows) {
    if (tvShows.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Trending TV Shows'),
          _buildShimmerCardRow(),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Trending TV Shows'),
        const SizedBox(height: 0),
        AnimationLimiter(
          child: SizedBox(
            height: 230,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: tvShows.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              addRepaintBoundaries: false,
              addSemanticIndexes: false,
              itemBuilder: (context, index) {
                final item = tvShows[index];
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 350),
                  child: SlideAnimation(
                    horizontalOffset: 30.0,
                    child: FadeInAnimation(
                      child: _buildRiveMediaCard(item),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRiveMediaCard(RiveStreamMedia item) {
    final appProvider = context.read<AppProvider>();
    return _PressScaleCard(
      onTap: () {
        HapticFeedback.lightImpact();
        _handleRiveMediaNavigation(item);
      },
      onDoubleTap: () {
        HapticFeedback.mediumImpact();
        final imdbItem = ImdbSearchResult(
          id: item.id.toString(),
          title: item.displayTitle,
          posterUrl: item.fullPosterUrl,
          year: item.displayDate.isNotEmpty
              ? item.displayDate.split('-').first
              : '',
          kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
          rating: item.voteAverage.toStringAsFixed(1),
          description: item.overview,
          backdropUrl: item.fullBackdropUrl,
        );
        final appProvider = context.read<AppProvider>();
        final wasInWatchlist = appProvider.isInWatchlist(imdbItem.id);
        appProvider.toggleWatchlist(imdbItem);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasInWatchlist
                ? 'Removed from Watchlist'
                : 'Added to Watchlist'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E1E1E),
          ),
        );
      },
      onLongPress: () {
        _showCardContextMenu(
          context,
          title: item.displayTitle,
          onAddWatchlist: () {
            final imdbItem = ImdbSearchResult(
              id: item.id.toString(),
              title: item.displayTitle,
              posterUrl: item.fullPosterUrl,
              year: item.displayDate.isNotEmpty
                  ? item.displayDate.split('-').first
                  : '',
              kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
              rating: item.voteAverage.toStringAsFixed(1),
              description: item.overview,
              backdropUrl: item.fullBackdropUrl,
            );
            context.read<AppProvider>().toggleWatchlist(imdbItem);
            Navigator.pop(context);
          },
        );
      },
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.03),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: Hero(
                  tag: 'trending_media_${item.id}',
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: item.fullPosterUrl,
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholder: (_, __) => Container(
                            color: Colors.white.withValues(alpha: 0.05)),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.white.withValues(alpha: 0.05),
                          child: const Icon(Icons.movie,
                              color: Colors.white24, size: 30),
                        ),
                      ),
                      // IN LIST badge
                      if (appProvider.isInWatchlist(item.id.toString()))
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'IN LIST',
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Column(
                  children: [
                    Text(
                      item.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 10),
                        const SizedBox(width: 3),
                        Text(
                          item.voteAverage.toStringAsFixed(1),
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }

  Widget _buildNetflixSection() {
    return provider_pkg.Consumer<TrendingProvider>(
      builder: (context, trendingProvider, _) {
        if (trendingProvider.netflixShows.isEmpty) {
          return const SizedBox.shrink();
        }
        return _buildTrendingCarousel(
          'Popular on Netflix',
          trendingProvider.netflixShows,
        );
      },
    );
  }

  Widget _buildAmazonPrimeSection() {
    return provider_pkg.Consumer<TrendingProvider>(
      builder: (context, trendingProvider, _) {
        if (trendingProvider.amazonPrimeShows.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            _buildTrendingCarousel(
              'Popular on Prime Video',
              trendingProvider.amazonPrimeShows,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopKDramasSection() {
    return provider_pkg.Consumer<KDramaProvider>(
      builder: (context, kdramaProvider, _) {
        if (kdramaProvider.topDramas.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            _buildKDramaCarousel(
              'Top K-Dramas',
              kdramaProvider.topDramas,
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildLatestKDramasSection() {
    return provider_pkg.Consumer<KDramaProvider>(
      builder: (context, kdramaProvider, _) {
        if (kdramaProvider.latestDramas.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            _buildKDramaCarousel(
              'Latest K-Dramas',
              kdramaProvider.latestDramas,
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildTrendingCarousel(String title, List<TrendingItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        const SizedBox(height: 4),
        AnimationLimiter(
          child: SizedBox(
            height: 230,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              addRepaintBoundaries: false,
              addSemanticIndexes: false,
              itemBuilder: (context, index) =>
                  _buildTrendingCard(items[index], index),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingCard(TrendingItem item, int index) {
    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 350),
      child: SlideAnimation(
        horizontalOffset: 30.0,
        child: FadeInAnimation(
          child: _PressScaleCard(
            onTap: () {
              final imdbItem = ImdbSearchResult(
                id: item.id,
                title: item.title,
                posterUrl: item.posterUrl ?? '',
                year: item.releaseDate ?? '',
                kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
                rating: item.rating?.toStringAsFixed(1),
              );
              _handleMediaTap(imdbItem);
            },
            child: Container(
              width: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 2 / 3,
                      child: CachedNetworkImage(
                        imageUrl: item.posterUrl ?? '',
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholder: (_, __) => Container(
                            color: Colors.white.withValues(alpha: 0.05)),
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.white.withValues(alpha: 0.05),
                          child: const Icon(Icons.movie,
                              color: Colors.white24, size: 30),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Colors.amber, size: 10),
                              const SizedBox(width: 3),
                              Text(
                                item.rating?.toStringAsFixed(1) ?? '0.0',
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKDramaCarousel(String title, List<KDramaItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        const SizedBox(height: 0),
        AnimationLimiter(
          child: SizedBox(
            height: 230,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              addRepaintBoundaries: false,
              addSemanticIndexes: false,
              itemBuilder: (context, index) =>
                  _buildKDramaCard(items[index], index),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKDramaCard(KDramaItem item, int index) {
    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 350),
      child: SlideAnimation(
        horizontalOffset: 30.0,
        child: FadeInAnimation(
          child: _PressScaleCard(
            onTap: () {
              final imdbItem = ImdbSearchResult(
                id: item.id,
                title: item.title,
                posterUrl: item.posterUrl ?? '',
                year: item.releaseYear?.toString() ?? '',
                kind: 'tvseries',
                rating: item.rating?.toStringAsFixed(1),
                description: 'Episodes: ${item.episodes ?? "N/A"}',
              );
              _handleMediaTap(imdbItem);
            },
            child: Container(
              width: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 2 / 3,
                      child: Hero(
                        tag: 'media_poster_${item.id}',
                        child: CachedNetworkImage(
                          imageUrl: item.posterUrl ?? '',
                          fit: BoxFit.cover,
                          fadeInDuration: Duration.zero,
                          fadeOutDuration: Duration.zero,
                          placeholder: (_, __) => Container(
                              color: Colors.white.withValues(alpha: 0.05)),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.white.withValues(alpha: 0.05),
                            child: const Icon(Icons.movie,
                                color: Colors.white24, size: 30),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star_rounded,
                                  color: Colors.amber, size: 10),
                              const SizedBox(width: 3),
                              Text(
                                item.rating?.toStringAsFixed(1) ?? '0.0',
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueWatchingSection(List<WatchProgress> continueWatching) {
    if (continueWatching.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Continue Watching'),
        const SizedBox(height: 0),
        AnimationLimiter(
          child: SizedBox(
            height: 230,
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: continueWatching.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              addRepaintBoundaries: false,
              addSemanticIndexes: false,
              itemBuilder: (context, index) {
                final wp = continueWatching[index];
                final progress = wp.duration > 0
                    ? (wp.position / wp.duration).clamp(0.0, 1.0)
                    : 0.0;
                final isTv = wp.media.kind != 'movie';
                final remainMin = wp.duration > 0
                    ? ((wp.duration - wp.position) / 60000).ceil()
                    : 0;

                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 350),
                  child: SlideAnimation(
                    horizontalOffset: 20.0,
                    child: FadeInAnimation(
                      child: _PressScaleCard(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _handleMediaTap(wp.media);
                        },
                        onDoubleTap: () {
                          HapticFeedback.mediumImpact();
                          final appProvider = context.read<AppProvider>();
                          final wasInWatchlist =
                              appProvider.isInWatchlist(wp.media.id);
                          appProvider.toggleWatchlist(wp.media);
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(wasInWatchlist
                                  ? 'Removed from Watchlist'
                                  : 'Added to Watchlist'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: const Color(0xFF1E1E1E),
                            ),
                          );
                        },
                        onLongPress: () {
                          _showContinueWatchingContextMenu(
                            context,
                            title: wp.media.title,
                            mediaId: wp.media.id,
                          );
                        },
                        child: Container(
                          width: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.08),
                                Colors.white.withValues(alpha: 0.03),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AspectRatio(
                                aspectRatio: 2 / 3,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Hero(
                                      tag:
                                          'hero_watchlist_${wp.media.id}_${wp.media.posterUrl.hashCode}',
                                      child: CachedNetworkImage(
                                        imageUrl: wp.media.posterUrl,
                                        fit: BoxFit.cover,
                                        fadeInDuration: Duration.zero,
                                        fadeOutDuration: Duration.zero,
                                        placeholder: (_, __) => Container(
                                            color: Colors.white
                                                .withValues(alpha: 0.05)),
                                        errorWidget: (_, __, ___) => Container(
                                          color: Colors.white
                                              .withValues(alpha: 0.05),
                                          child: const Icon(Icons.movie,
                                              color: Colors.white24, size: 30),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: LayoutBuilder(
                                        builder: (ctx, constraints) {
                                          final filled =
                                              constraints.maxWidth * progress;
                                          return Stack(
                                            children: [
                                              Container(
                                                  height: 2,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.1)),
                                              Container(
                                                width: filled,
                                                height: 2,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                    colors: [
                                                      AppTheme.primaryColor
                                                          .withValues(
                                                              alpha: 0.7),
                                                      AppTheme.primaryColor,
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    Center(
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.6),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.4),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Icon(Icons.play_arrow_rounded,
                                            color: Colors.white, size: 20),
                                      ),
                                    ),
                                    if (remainMin > 0)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.6),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${remainMin}m',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 8),
                                child: Column(
                                  children: [
                                    Text(
                                      wp.media.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          isTv ? 'SERIES' : 'MOVIE',
                                          style: GoogleFonts.outfit(
                                            color: AppTheme.primaryColor
                                                .withValues(alpha: 0.8),
                                            fontSize: 7.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
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
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWatchlistSection() {
    return provider_pkg.Consumer<AppProvider>(
      builder: (context, provider, _) {
        final watchlist = provider.watchlist;
        if (watchlist.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'Watchlist',
              trailing: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WatchlistScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Text(
                          'VIEW ALL',
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            AnimationLimiter(
              child: SizedBox(
                height: 230,
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: watchlist.length > 10 ? 10 : watchlist.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  addRepaintBoundaries: false,
                  addSemanticIndexes: false,
                  itemBuilder: (context, index) {
                    final item = watchlist[index];
                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 350),
                      child: SlideAnimation(
                        horizontalOffset: 30.0,
                        child: FadeInAnimation(
                          child: _buildWatchlistCard(item),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWatchlistCard(ImdbSearchResult item) {
    return _PressScaleCard(
      onTap: () {
        HapticFeedback.lightImpact();
        _handleMediaTap(item);
      },
      onLongPress: () {
        _showWatchlistContextMenu(
          context,
          title: item.title,
          item: item,
        );
      },
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.03),
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: Hero(
                  tag: 'hero_search_${item.id}_${item.posterUrl.hashCode}',
                  child: CachedNetworkImage(
                    imageUrl: item.posterUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (_, __) =>
                        Container(color: Colors.white.withValues(alpha: 0.05)),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: const Icon(Icons.movie,
                          color: Colors.white24, size: 30),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Column(
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 10),
                        const SizedBox(width: 3),
                        Text(
                          item.rating ?? '0.0',
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
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
      ),
    );
  }

  Widget _buildGenreSection(String title, String genreId) {
    return ref.watch(genreProvider(genreId)).when(
          data: (genreResult) {
            if (genreResult == null || genreResult.popularMovies.isEmpty) {
              return const SizedBox.shrink();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(title),
                const SizedBox(height: 0),
                AnimationLimiter(
                  child: SizedBox(
                    height: 230,
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: genreResult.popularMovies.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      addRepaintBoundaries: false,
                      addSemanticIndexes: false,
                      itemBuilder: (context, index) {
                        final item = genreResult.popularMovies[index];
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 350),
                          child: SlideAnimation(
                            horizontalOffset: 30.0,
                            child: FadeInAnimation(
                              child: _buildGenreMediaCard(item),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(title),
              _buildShimmerCardRow(),
            ],
          ),
          error: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(title),
              _buildShimmerCardRow(),
            ],
          ),
        );
  }

  Widget _buildGenreMediaCard(GenreInterestItem item) {
    final appProvider = context.read<AppProvider>();
    final imdbItem = ImdbSearchResult(
      id: item.imdbId,
      title: item.title,
      posterUrl: item.poster ?? '',
      year: item.year.toString(),
      kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
      rating: item.rating.toStringAsFixed(1),
      description: item.plot ?? '',
    );
    return _PressScaleCard(
      onTap: () {
        HapticFeedback.lightImpact();
        _handleMediaTap(imdbItem);
      },
      onDoubleTap: () {
        HapticFeedback.mediumImpact();
        final wasInWatchlist = appProvider.isInWatchlist(imdbItem.id);
        appProvider.toggleWatchlist(imdbItem);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasInWatchlist
                ? 'Removed from Watchlist'
                : 'Added to Watchlist'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E1E1E),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: item.poster ?? '',
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    placeholder: (_, __) =>
                        Container(color: Colors.white.withValues(alpha: 0.05)),
                    errorWidget: (_, __, ___) => Container(
                      color: Colors.white.withValues(alpha: 0.05),
                      child: const Icon(Icons.movie,
                          color: Colors.white24, size: 30),
                    ),
                  ),
                  // IN LIST badge
                  if (appProvider.isInWatchlist(imdbItem.id))
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'IN LIST',
                          style: GoogleFonts.outfit(
                            color: Colors.black,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (item.mediaType == 'tvseries')
                        Expanded(
                          child: Text(
                            'S1:E1',
                            style: GoogleFonts.outfit(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.9),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 10),
                      if (item.mediaType == 'movie') const SizedBox(width: 3),
                      Text(
                        item.rating.toStringAsFixed(1),
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
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
    );
  }
}

// Featured Carousel Widget as Separate StatefulWidget
class _FeaturedCarouselWidget extends StatefulWidget {
  final List<RiveStreamMedia> items;

  const _FeaturedCarouselWidget({required this.items});

  @override
  State<_FeaturedCarouselWidget> createState() =>
      _FeaturedCarouselWidgetState();
}

class _FeaturedCarouselWidgetState extends State<_FeaturedCarouselWidget> {
  int _currentCarouselIndex = 0;

  void _handleRiveMediaNavigation(RiveStreamMedia item, BuildContext context) {
    final homeState = context.findAncestorStateOfType<_HomeScreenState>();
    if (homeState != null) {
      homeState._handleRiveMediaNavigation(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return SizedBox(
        height: 530,
        child: Shimmer.fromColors(
          baseColor: Colors.white.withValues(alpha: 0.05),
          highlightColor: Colors.white.withValues(alpha: 0.12),
          period: const Duration(milliseconds: 1000),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 530,
      child: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 20),
              CarouselSlider.builder(
                itemCount: widget.items.length,
                itemBuilder: (context, index, realIndex) {
                  final item = widget.items[index];
                  return _buildRiveCarouselItemCard(
                      item, index == _currentCarouselIndex, context);
                },
                options: CarouselOptions(
                  height: 440,
                  viewportFraction: 0.82,
                  initialPage: 0,
                  enableInfiniteScroll: true,
                  autoPlay: true,
                  autoPlayInterval: const Duration(seconds: 8),
                  autoPlayAnimationDuration: const Duration(milliseconds: 700),
                  autoPlayCurve: Curves.easeInOutQuart,
                  enlargeCenterPage: true,
                  enlargeStrategy: CenterPageEnlargeStrategy.scale,
                  enlargeFactor: 0.20,
                  pauseAutoPlayOnTouch: true,
                  onPageChanged: (index, reason) {
                    setState(() {
                      _currentCarouselIndex = index;
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
              _buildCarouselIndicators(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiveCarouselItemCard(
      RiveStreamMedia item, bool isCenter, BuildContext context) {
    return _PressScaleCard(
      onTap: () {
        HapticFeedback.lightImpact();
        _handleRiveMediaNavigation(item, context);
      },
      onDoubleTap: () {
        HapticFeedback.mediumImpact();
        final imdbItem = ImdbSearchResult(
          id: item.id.toString(),
          title: item.displayTitle,
          posterUrl: item.fullPosterUrl,
          year: item.displayDate.isNotEmpty
              ? item.displayDate.split('-').first
              : '',
          kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
          rating: item.voteAverage.toStringAsFixed(1),
          description: item.overview,
          backdropUrl: item.fullBackdropUrl,
        );
        final appProvider = context.read<AppProvider>();
        final wasInWatchlist = appProvider.isInWatchlist(imdbItem.id);
        appProvider.toggleWatchlist(imdbItem);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasInWatchlist
                ? 'Removed from Watchlist'
                : 'Added to Watchlist'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E1E1E),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 15,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster with subtle zoom hint if centered
              Hero(
                tag: 'carousel_media_${item.id}',
                child: CachedNetworkImage(
                  imageUrl: item.fullPosterUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  placeholder: (_, __) => Container(color: AppTheme.cardColor),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.cardColor,
                    child:
                        const Icon(Icons.broken_image, color: Colors.white24),
                  ),
                ),
              ),

              // Cinematic Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                    stops: const [0.5, 0.7, 1.0],
                  ),
                ),
              ),

              // Glass Info Panel
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.displayTitle.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.bebasNeue(
                              color: Colors.white,
                              fontSize: 26,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryColor,
                                      AppTheme.primaryColor
                                          .withValues(alpha: 0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'IMDB ${item.voteAverage.toStringAsFixed(1)}',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                item.displayDate.split('-').first,
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (item.mediaType == 'tv') ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.1),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    'TV SERIES',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white70,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
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

  Widget _buildCarouselIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: widget.items.asMap().entries.map((entry) {
        final bool isSelected = _currentCarouselIndex == entry.key;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isSelected ? 24 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withValues(alpha: 0.5),
                    ],
                  )
                : null,
            color: isSelected ? null : Colors.white.withValues(alpha: 0.2),
          ),
        );
      }).toList(),
    );
  }
}

class _PressScaleCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;

  const _PressScaleCard({
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  });

  @override
  State<_PressScaleCard> createState() => _PressScaleCardState();
}

class _PressScaleCardState extends State<_PressScaleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _elevation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
      reverseDuration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _elevation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      onDoubleTap: () {
        HapticFeedback.heavyImpact();
        widget.onDoubleTap?.call();
      },
      onLongPress: () {
        HapticFeedback.mediumImpact();
        widget.onLongPress?.call();
      },
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        _controller.forward();
      },
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_scale, _elevation]),
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: _elevation.value * 2,
                  offset: Offset(0, _elevation.value),
                ),
              ],
            ),
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
