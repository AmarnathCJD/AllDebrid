import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shimmer/shimmer.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';

import '../../services/imdb_service.dart';
import '../../utils/watchlist_actions.dart';

import 'package:cached_network_image/cached_network_image.dart';
import '../../services/rivestream_service.dart';
import '../../widgets/widgets.dart';
import 'media_info_screen.dart';
import 'search_page.dart';
import '../watchlist/watchlist_screen.dart';
import 'animations/navigation_transitions.dart';

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
      ref.read(appNotifierProvider.notifier).refreshUser(),
      ref.read(magnetNotifierProvider.notifier).fetchMagnets(),
      ref.read(trendingNotifierProvider.notifier).loadTrendingData(),
      ref.read(kDramaNotifierProvider.notifier).loadTopDramas(),
      ref.read(kDramaNotifierProvider.notifier).loadLatestDramas(),
    ]);
    debugPrint('[HomeScreen] _onRefresh() completed');
  }

  void _showCardContextMenu(
    BuildContext context, {
    required String title,
    required VoidCallback onAddWatchlist,
    String? rating,
    String? year,
    String? kind,
  }) {
    unawaited(showDialog(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (rating != null || year != null || kind != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (rating != null && rating.isNotEmpty) ...[
                            const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              rating,
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (year != null && year.isNotEmpty) ...[
                            Text(
                              year,
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (kind != null && kind.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                kind.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
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
                            const Icon(
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
                            const Icon(
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
    ));
  }

  void _showWatchlistContextMenu(
    BuildContext context, {
    required String title,
    required ImdbSearchResult item,
  }) {
    final appState = ref.read(appNotifierProvider);
    unawaited(showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (item.rating != null && item.rating!.isNotEmpty) ...[
                          const Icon(Icons.star_rounded,
                              color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            item.rating!,
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (item.year.isNotEmpty) ...[
                          Text(
                            item.year,
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (item.kind != null && item.kind!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.kind!.toUpperCase(),
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pop(dialogContext);
                    HapticFeedback.mediumImpact();
                    unawaited(toggleWatchlistWithFeedback(
                      context,
                      ref,
                      appState,
                      item,
                      wasInWatchlist: true,
                    ));
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
    ));
  }

  void _showContinueWatchingContextMenu(
    BuildContext context, {
    required String title,
    required String mediaId,
    String? rating,
    String? year,
    String? kind,
  }) {
    unawaited(showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (rating != null || year != null || kind != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (rating != null && rating.isNotEmpty) ...[
                            const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              rating,
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (year != null && year.isNotEmpty) ...[
                            Text(
                              year,
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (kind != null && kind.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                kind.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    HapticFeedback.mediumImpact();
                    try {
                      final imdbService = ImdbService();
                      await imdbService.removeFromContinueWatching(mediaId);
                      ref.invalidate(continueWatchingProvider);
                    } catch (e) {
                      debugPrint('Error removing from continue watching: $e');
                    }
                    if (mounted) {
                      showAppSnackBar(
                        context,
                        'Removed from continue watching',
                        type: AppFeedbackType.info,
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
    ));
  }

  void _handleMediaTap(ImdbSearchResult item) {
    HapticFeedback.lightImpact();
    unawaited(Navigator.push(
      context,
      SmoothPageTransition(
        duration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            MediaInfoScreen(item: item),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final trendingAsync = ref.watch(riveTrendingProvider);
    final continueWatchingAsync = ref.watch(continueWatchingProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBodyBehindAppBar: true,
      body: RepaintBoundary(
        child: Stack(
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
                  cacheExtent: 500,
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
                        child:
                            RepaintBoundary(child: _buildWatchlistSection())),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: trendingAsync.maybeWhen(
                          data: (trendingData) =>
                              _buildRiveTrendingMoviesSection(
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
                        child:
                            RepaintBoundary(child: _buildTopKDramasSection())),
                    const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    SliverToBoxAdapter(
                        child: RepaintBoundary(
                            child: _buildLatestKDramasSection())),
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
                  unawaited(Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const SearchPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  ));
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
      height: 190,
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
            style: const TextStyle(
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
                      const Text(
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
        SizedBox(
          height: 190,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            addSemanticIndexes: false,
            itemBuilder: (context, index) {
              final item = movies[index];
              return _buildRiveMediaCard(item);
            },
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
        SizedBox(
          height: 190,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: tvShows.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            addSemanticIndexes: false,
            itemBuilder: (context, index) {
              final item = tvShows[index];
              return _buildRiveMediaCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRiveMediaCard(RiveStreamMedia item) {
    final appState = ref.read(appNotifierProvider);
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
        unawaited(
            toggleWatchlistWithFeedback(context, ref, appState, imdbItem));
      },
      onLongPress: () {
        _showCardContextMenu(
          context,
          title: item.displayTitle,
          rating: item.voteAverage.toStringAsFixed(1),
          year: item.displayDate.isNotEmpty
              ? item.displayDate.split('-').first
              : '',
          kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
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
            final appState = ref.read(appNotifierProvider);
            unawaited(addToWatchlistIfMissing(
              context,
              ref,
              appState,
              imdbItem,
            ));
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
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
                  placeholder: (_, __) => const AppBlurHashPlaceholder(),
                  errorWidget: (_, __, ___) => const AppBlurHashPlaceholder(
                    fallbackIcon:
                        Icon(Icons.movie, color: Colors.white24, size: 30),
                  ),
                ),
                // IN LIST badge
                if (appState.isInWatchlist(item.id.toString()))
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
      ),
    );
  }

  Widget _buildNetflixSection() {
    final trendingProvider = ref.watch(trendingNotifierProvider);
    if (trendingProvider.netflixShows.isEmpty) {
      return const SizedBox.shrink();
    }
    return _buildTrendingCarousel(
      'Popular on Netflix',
      trendingProvider.netflixShows,
    );
  }

  Widget _buildAmazonPrimeSection() {
    final trendingProvider = ref.watch(trendingNotifierProvider);
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
  }

  Widget _buildTopKDramasSection() {
    final kdramaProvider = ref.watch(kDramaNotifierProvider);
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
  }

  Widget _buildLatestKDramasSection() {
    final kdramaProvider = ref.watch(kDramaNotifierProvider);
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
  }

  Widget _buildTrendingCarousel(String title, List<TrendingItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        const SizedBox(height: 4),
        SizedBox(
          height: 190,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            addSemanticIndexes: false,
            itemBuilder: (context, index) => _buildTrendingCard(items[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingCard(TrendingItem item) {
    final imdbItem = ImdbSearchResult(
      id: item.id,
      title: item.title,
      posterUrl: item.posterUrl ?? '',
      year: item.releaseDate ?? '',
      kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
      rating: item.rating?.toStringAsFixed(1),
    );
    return _PressScaleCard(
      onTap: () {
        HapticFeedback.lightImpact();
        _handleMediaTap(imdbItem);
      },
      onDoubleTap: () {
        HapticFeedback.mediumImpact();
        final appState = ref.read(appNotifierProvider);
        unawaited(
            toggleWatchlistWithFeedback(context, ref, appState, imdbItem));
      },
      onLongPress: () {
        _showCardContextMenu(
          context,
          title: item.title,
          rating: item.rating?.toStringAsFixed(1),
          year: item.releaseDate ?? '',
          kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
          onAddWatchlist: () {
            final appState = ref.read(appNotifierProvider);
            unawaited(addToWatchlistIfMissing(
              context,
              ref,
              appState,
              imdbItem,
            ));
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: CachedNetworkImage(
            imageUrl: item.posterUrl ?? '',
            fit: BoxFit.cover,
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            placeholder: (_, __) => const AppBlurHashPlaceholder(),
            errorWidget: (_, __, ___) => const AppBlurHashPlaceholder(
              fallbackIcon: Icon(Icons.movie, color: Colors.white24, size: 30),
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
        SizedBox(
          height: 190,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            addSemanticIndexes: false,
            itemBuilder: (context, index) => _buildKDramaCard(items[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildKDramaCard(KDramaItem item) {
    final imdbItem = ImdbSearchResult(
      id: item.id,
      title: item.title,
      posterUrl: item.posterUrl ?? '',
      year: item.releaseYear?.toString() ?? '',
      kind: 'tvseries',
      rating: item.rating?.toStringAsFixed(1),
      description: 'Episodes: ${item.episodes ?? "N/A"}',
    );
    return _PressScaleCard(
      onTap: () {
        HapticFeedback.lightImpact();
        _handleMediaTap(imdbItem);
      },
      onDoubleTap: () {
        HapticFeedback.mediumImpact();
        final appState = ref.read(appNotifierProvider);
        unawaited(
            toggleWatchlistWithFeedback(context, ref, appState, imdbItem));
      },
      onLongPress: () {
        _showCardContextMenu(
          context,
          title: item.title,
          rating: item.rating?.toStringAsFixed(1),
          year: item.releaseYear?.toString() ?? '',
          kind: 'tvseries',
          onAddWatchlist: () {
            final appState = ref.read(appNotifierProvider);
            unawaited(addToWatchlistIfMissing(
              context,
              ref,
              appState,
              imdbItem,
            ));
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: 2 / 3,
          child: Hero(
            tag: 'media_poster_${item.id}',
            child: CachedNetworkImage(
              imageUrl: item.posterUrl ?? '',
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              placeholder: (_, __) => const AppBlurHashPlaceholder(),
              errorWidget: (_, __, ___) => const AppBlurHashPlaceholder(
                fallbackIcon:
                    Icon(Icons.movie, color: Colors.white24, size: 30),
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
        SizedBox(
          height: 190,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: continueWatching.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            addSemanticIndexes: false,
            itemBuilder: (context, index) {
              final wp = continueWatching[index];
              final progress = wp.duration > 0
                  ? (wp.position / wp.duration).clamp(0.0, 1.0)
                  : 0.0;
              final remainMin = wp.duration > 0
                  ? ((wp.duration - wp.position) / 60000).ceil()
                  : 0;

              return _PressScaleCard(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _handleMediaTap(wp.media);
                },
                onDoubleTap: () {
                  HapticFeedback.mediumImpact();
                  final appState = ref.read(appNotifierProvider);
                  unawaited(toggleWatchlistWithFeedback(
                    context,
                    ref,
                    appState,
                    wp.media,
                  ));
                },
                onLongPress: () {
                  _showContinueWatchingContextMenu(
                    context,
                    title: wp.media.title,
                    mediaId: wp.media.id,
                    rating: wp.media.rating,
                    year: wp.media.year,
                    kind: wp.media.kind,
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
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AspectRatio(
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
                            placeholder: (_, __) =>
                                const AppBlurHashPlaceholder(),
                            errorWidget: (_, __, ___) =>
                                const AppBlurHashPlaceholder(
                              fallbackIcon: Icon(Icons.movie,
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
                              final filled = constraints.maxWidth * progress;
                              return Stack(
                                children: [
                                  Container(
                                      height: 3,
                                      color:
                                          Colors.white.withValues(alpha: 0.1)),
                                  Container(
                                    width: filled,
                                    height: 3,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          AppTheme.primaryColor
                                              .withValues(alpha: 0.7),
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
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.0,
                              ),
                            ),
                            child: const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 22),
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
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWatchlistSection() {
    final provider = ref.watch(appNotifierProvider);
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
                unawaited(Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const WatchlistScreen(),
                  ),
                ));
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
        SizedBox(
          height: 190,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: watchlist.length > 10 ? 10 : watchlist.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            addSemanticIndexes: false,
            itemBuilder: (context, index) {
              final item = watchlist[index];
              return _buildWatchlistCard(item);
            },
          ),
        ),
      ],
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
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
              errorWidget: (_, __, ___) => const AppBlurHashPlaceholder(
                fallbackIcon:
                    Icon(Icons.movie, color: Colors.white24, size: 30),
              ),
            ),
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
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: genreResult.popularMovies.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    addSemanticIndexes: false,
                    itemBuilder: (context, index) {
                      final item = genreResult.popularMovies[index];
                      return _buildGenreMediaCard(item);
                    },
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
    final appState = ref.read(appNotifierProvider);
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
        toggleWatchlistWithFeedback(context, ref, appState, imdbItem);
      },
      onLongPress: () {
        _showCardContextMenu(
          context,
          title: item.title,
          rating: item.rating.toStringAsFixed(1),
          year: item.year.toString(),
          kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
          onAddWatchlist: () {
            final appState = ref.read(appNotifierProvider);
            unawaited(addToWatchlistIfMissing(
              context,
              ref,
              appState,
              imdbItem,
            ));
            Navigator.pop(context);
          },
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
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
                errorWidget: (_, __, ___) => const AppBlurHashPlaceholder(
                  fallbackIcon:
                      Icon(Icons.movie, color: Colors.white24, size: 30),
                ),
              ),
              // IN LIST badge
              if (appState.isInWatchlist(imdbItem.id))
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
    );
  }
}

// Featured Carousel Widget as Separate StatefulWidget
class _FeaturedCarouselWidget extends ConsumerStatefulWidget {
  final List<RiveStreamMedia> items;

  const _FeaturedCarouselWidget({required this.items});

  @override
  ConsumerState<_FeaturedCarouselWidget> createState() =>
      _FeaturedCarouselWidgetState();
}

class _FeaturedCarouselWidgetState
    extends ConsumerState<_FeaturedCarouselWidget> {
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
        final appState = ref.read(appNotifierProvider);
        unawaited(
            toggleWatchlistWithFeedback(context, ref, appState, imdbItem));
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
                  placeholder: (_, __) => const AppBlurHashPlaceholder(
                    backgroundColor: AppTheme.cardColor,
                  ),
                  errorWidget: (_, __, ___) => const AppBlurHashPlaceholder(
                    backgroundColor: AppTheme.cardColor,
                    fallbackIcon:
                        Icon(Icons.broken_image, color: Colors.white24),
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
