import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glass/glass.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../providers/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/common_widgets.dart';
import '../../utils/helpers.dart';
import 'unlock_links_screen.dart';
import '../torrents/torrent_search_screen.dart';
import '../../services/imdb_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/torrent_scraper_service.dart';
import '../../models/torrent.dart';
import 'media_info_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  List<ImdbSearchResult> _trending = [];
  bool _isFabExpanded = false;

  Timer? _carouselTimer;

  @override
  void initState() {
    super.initState();
    _loadData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().refreshUser();
      context.read<MagnetProvider>().fetchMagnets();
      context.read<TrendingProvider>().loadTrendingData();
      context.read<KDramaProvider>().loadTopDramas();
      context.read<KDramaProvider>().loadLatestDramas();
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-trigger load if needed, or just let init handle it
  }

  @override
  void didPopNext() {
    _loadData();
  }

  Future<void> _loadData() async {
    // 1. Load Caches
    final trendingCache = await ImdbService().getTrendingCache();

    if (mounted) {
      setState(() {
        if (trendingCache.isNotEmpty) {
          _trending = trendingCache;
          _startCarouselTimer();
        }
      });
    }

    // 2. Fetch Fresh Data
    final trending = await ImdbService().getTrending();

    if (trending.isNotEmpty && mounted) {
      setState(() {
        _trending = trending;
      });
      await ImdbService().saveTrendingCache(trending);
      if (trendingCache.isEmpty) _startCarouselTimer();
    }
  }

  void _startCarouselTimer() {
    // CarouselSlider handles this automatically
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<AppProvider>().refreshUser(),
      context.read<MagnetProvider>().fetchMagnets(),
      context.read<TrendingProvider>().loadTrendingData(),
      context.read<KDramaProvider>().loadTopDramas(),
      context.read<KDramaProvider>().loadLatestDramas(),
      _loadData(),
    ]);
  }

  void _handleMediaTap(ImdbSearchResult item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MediaInfoScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Dynamic Background
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
              child: Container(
                color: AppTheme.backgroundColor.withOpacity(0.95),
                child: Stack(
                  children: [
                    // Deep Radial Gradient
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.6),
                            radius: 1.2,
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.12),
                              Color.lerp(
                                  AppTheme.backgroundColor, Colors.black, 0.4)!,
                            ],
                            stops: const [0.0, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Floating Particle 1
                    Positioned(
                      top: 200,
                      left: 50,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryColor.withOpacity(0.15),
                            width: 2,
                          ),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(duration: 8.seconds, begin: 0, end: -50)
                          .fadeIn(duration: 2.seconds)
                          .fadeOut(delay: 6.seconds, duration: 2.seconds),
                    ),

                    // Floating Particle 2
                    Positioned(
                      top: 400,
                      right: 80,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.accentColor.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(duration: 10.seconds, begin: 0, end: 60)
                          .fadeIn(duration: 3.seconds)
                          .fadeOut(delay: 7.seconds, duration: 3.seconds),
                    ),

                    // Floating Particle 3
                    Positioned(
                      bottom: 300,
                      left: 120,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.infoColor.withOpacity(0.3),
                              AppTheme.infoColor.withOpacity(0.0),
                            ],
                          ),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                              duration: 5.seconds,
                              begin: Offset(1, 1),
                              end: Offset(1.3, 1.3))
                          .fadeIn(duration: 2.5.seconds)
                          .fadeOut(delay: 2.5.seconds, duration: 2.5.seconds),
                    ),

                    // Diagonal Lines Artifact
                    Positioned(
                      top: 100,
                      right: 30,
                      child: Transform.rotate(
                        angle: 0.3,
                        child: Container(
                          width: 120,
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppTheme.primaryColor.withOpacity(0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveX(duration: 12.seconds, begin: 0, end: -100)
                          .fadeIn(duration: 4.seconds)
                          .fadeOut(delay: 8.seconds, duration: 4.seconds),
                    ),

                    // Darkish Overlay to dim the yellow artifacts
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.6),
                      ),
                    ),

                    // Firefly 1
                    Positioned(
                      top: 150,
                      right: 80,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryColor,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor,
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(duration: 4.seconds, begin: 0, end: -60)
                          .moveX(duration: 3.seconds, begin: 0, end: 30)
                          .fadeIn(duration: 1.seconds)
                          .fadeOut(delay: 3.seconds, duration: 1.seconds),
                    ),

                    // Firefly 2
                    Positioned(
                      top: 300,
                      left: 60,
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentColor,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accentColor,
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(duration: 5.seconds, begin: 0, end: 70)
                          .moveX(duration: 4.seconds, begin: 0, end: -40)
                          .fadeIn(duration: 1.5.seconds)
                          .fadeOut(delay: 3.5.seconds, duration: 1.5.seconds),
                    ),

                    // Firefly 3
                    Positioned(
                      bottom: 250,
                      right: 120,
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.infoColor,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.infoColor,
                              blurRadius: 7,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(duration: 6.seconds, begin: 0, end: -50)
                          .moveX(duration: 5.seconds, begin: 0, end: 50)
                          .fadeIn(duration: 2.seconds)
                          .fadeOut(delay: 4.seconds, duration: 2.seconds),
                    ),

                    // Firefly 4
                    Positioned(
                      bottom: 400,
                      left: 150,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.yellow,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.yellow,
                              blurRadius: 10,
                              spreadRadius: 3,
                            )
                          ],
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(duration: 5.5.seconds, begin: 0, end: 80)
                          .moveX(duration: 4.5.seconds, begin: 0, end: -30)
                          .fadeIn(duration: 1.8.seconds)
                          .fadeOut(delay: 3.7.seconds, duration: 1.8.seconds),
                    ),

                    // Firefly 5
                    Positioned(
                      top: 450,
                      right: 200,
                      child: Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryColor.withOpacity(0.8),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor,
                              blurRadius: 6,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .moveY(duration: 4.5.seconds, begin: 0, end: -40)
                          .moveX(duration: 3.5.seconds, begin: 0, end: 60)
                          .fadeIn(duration: 1.2.seconds)
                          .fadeOut(delay: 3.3.seconds, duration: 1.2.seconds),
                    ),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            top: false,
            child: Consumer2<AppProvider, MagnetProvider>(
              builder: (context, appProvider, magnetProvider, _) {
                final user = appProvider.user;
                return RefreshIndicator(
                  color: AppTheme.primaryColor,
                  backgroundColor: AppTheme.cardColor,
                  onRefresh: _onRefresh,
                  child: CustomScrollView(
                    physics: const ClampingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                          child: SizedBox(
                              height: MediaQuery.paddingOf(context).top)),

                      SliverToBoxAdapter(child: _buildFeaturedCarousel(user)),

                      // Category Sections
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTrendingSection(),
                            _buildTrendingMoviesSection(),
                            _buildTrendingTVShowsSection(),
                            _buildNetflixSection(),
                            _buildAmazonPrimeSection(),
                            _buildTopKDramasSection(),
                            _buildLatestKDramasSection(),
                            _buildActivity(magnetProvider),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Fixed Top Gradient Overlay (Prevents scroll separation issue)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isFabExpanded) ...[
            _buildFabOption(
              label: 'Unlock Links',
              icon: Icons.unfold_more_rounded,
              color: AppTheme.accentColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UnlockLinksScreen(),
                  ),
                );
              },
              delay: 100,
            ),
            const SizedBox(height: 16),
            _buildFabOption(
              label: 'Add Magnet',
              icon: Icons.post_add_rounded,
              color: AppTheme.infoColor,
              onTap: () => _showAddMagnetDialog(),
              delay: 0,
            ),
            const SizedBox(height: 24),
          ],
          Container(
            width: 50, // Compact size
            height: 50,
            decoration: BoxDecoration(
              // Creative "Petal/Leaf" Shape
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
                topRight: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              gradient: LinearGradient(
                colors: _isFabExpanded
                    ? [Colors.redAccent.shade400, Colors.red.shade900]
                    : [AppTheme.primaryColor, AppTheme.accentColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isFabExpanded ? Colors.red : AppTheme.primaryColor)
                      .withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () {
                setState(() => _isFabExpanded = !_isFabExpanded);
              },
              heroTag: 'main_fab',
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => RotationTransition(
                  turns: child.key == const ValueKey('icon1')
                      ? Tween<double>(begin: 0.75, end: 1.0).animate(anim)
                      : Tween<double>(begin: 0.75, end: 1.0).animate(anim),
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: Icon(
                  _isFabExpanded ? Icons.close_rounded : Icons.widgets_rounded,
                  key: ValueKey(_isFabExpanded ? 'icon2' : 'icon1'),
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          )
              .animate(
                target: _isFabExpanded ? 0 : 1,
                onPlay: (c) => c.repeat(reverse: true),
              )
              .scale(
                  duration: 1.5.seconds,
                  begin: const Offset(1, 1),
                  end: const Offset(1.1, 1.1))
              .then()
              .shimmer(
                  duration: 2.seconds, color: Colors.white.withOpacity(0.5)),
        ],
      ),
    );
  }

  Widget _buildFabOption({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int delay = 0,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ).animate().fade(duration: 200.ms, delay: delay.ms).moveX(
            begin: 20,
            end: 0,
            duration: 200.ms,
            delay: delay.ms,
            curve: Curves.easeOut),

        const SizedBox(width: 12),

        // Button
        GestureDetector(
          onTap: () {
            setState(() => _isFabExpanded = false);
            onTap();
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color,
                  color.withOpacity(0.7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        )
            .animate()
            .scale(duration: 200.ms, delay: delay.ms, curve: Curves.easeOut)
            .fade(duration: 200.ms, delay: delay.ms),
      ],
    );
  }

  Widget _buildFeaturedCarousel(dynamic user) {
    if (_trending.isEmpty) {
      return Container(
        height: 480,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    return SizedBox(
      height: 450,
      child: Stack(
        children: [
          // Dynamic Background Gradient that changes with carousel
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          ),

          CarouselSlider.builder(
            itemCount: _trending.length,
            itemBuilder: (context, index, realIndex) {
              final item = _trending[index];
              return _buildCarouselItemCard(item, true);
            },
            options: CarouselOptions(
              height: 420,
              aspectRatio: 2 / 3,
              viewportFraction: 0.76,
              initialPage: 0,
              enableInfiniteScroll: true,
              reverse: false,
              autoPlay: true,
              autoPlayInterval: const Duration(seconds: 5),
              autoPlayAnimationDuration: const Duration(milliseconds: 800),
              autoPlayCurve: Curves.fastOutSlowIn,
              enlargeCenterPage: true,
              pauseAutoPlayOnTouch: true,
              pauseAutoPlayOnManualNavigate: true,
              enlargeFactor: 0.3,
              scrollDirection: Axis.horizontal,
              scrollPhysics: ClampingScrollPhysics(),
              onPageChanged: (index, reason) {
                // Optional: Add analytics or other tracking
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselItemCard(ImdbSearchResult item, bool isCenter) {
    return GestureDetector(
      onTap: () => _handleMediaTap(item),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5.0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: item.posterUrl,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: (_, __) => Container(color: AppTheme.cardColor),
                errorWidget: (_, __, ___) => Container(
                    color: AppTheme.cardColor,
                    child:
                        const Icon(Icons.broken_image, color: Colors.white24)),
              ),
            ),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.9),
                  ],
                  stops: const [0.5, 0.7, 1.0],
                ),
              ),
            ),

            // Content
            Positioned(
              bottom: 20,
              left: 12,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20, // Reduced font size to avoid overflow
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.8),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]),
                  ),
                  if (item.year.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${item.year}  •  ${item.rating ?? "N/A"} ⭐',
                        style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildHeroButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Watch',
                        isPrimary: true,
                        onTap: () => _handleMediaTap(item),
                      ),
                      const SizedBox(width: 8),
                      _buildHeroButton(
                        icon: Icons.add_rounded,
                        label: 'List',
                        isPrimary: false,
                        onTap: () {},
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color:
              isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isPrimary ? Colors.black : Colors.white, size: 20),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.black : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTrendingSection() {
    if (_trending.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Recommended For You'),
        const SizedBox(height: 16),
        SizedBox(
          height: 245,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _trending.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _buildLandscapeCard(_trending[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeCard(ImdbSearchResult item, int index) {
    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 375),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: GestureDetector(
            onTap: () => _handleMediaTap(item),
            child: Container(
              width: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image with gradient overlay and glow
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        child: CachedNetworkImage(
                          imageUrl: item.posterUrl,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 180,
                          placeholder: (_, __) => Shimmer.fromColors(
                            baseColor: AppTheme.cardColor,
                            highlightColor: AppTheme.cardColor.withOpacity(0.5),
                            child: Container(
                              width: 120,
                              height: 180,
                              color: AppTheme.cardColor,
                            ),
                          ),
                          errorWidget: (_, __, ___) =>
                              const SizedBox(width: 120, height: 180),
                        ),
                      ),
                      // Animated shine effect
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withOpacity(0.3),
                                  Colors.transparent,
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.3, 1.0],
                              ),
                            ),
                          ).animate(onPlay: (c) => c.repeat()).shimmer(
                              duration: 3.seconds,
                              delay: (index * 0.5).seconds),
                        ),
                      ),
                    ],
                  ),
                  // Text below - with gradient background
                  Container(
                    width: 120,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12)),
                      // border: Border.all(
                      //   color: AppTheme.primaryColor.withOpacity(0.2),
                      //   width: 1,
                      // ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.year,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
              .animate()
              .scale(duration: 300.ms, curve: Curves.easeOut)
              .then()
              .slideY(duration: 300.ms, begin: 0.2, curve: Curves.easeOut)
              .then()
              .shimmer(delay: (index * 150).ms, duration: 1.2.seconds),
        ),
      ),
    );
  }

  Widget _buildTrendingMoviesSection() {
    return Consumer<TrendingProvider>(
      builder: (context, trendingProvider, _) {
        if (trendingProvider.trendingMovies.isEmpty) {
          return const SizedBox.shrink();
        }
        return _buildTrendingCarousel(
          'Trending Movies',
          trendingProvider.trendingMovies,
        );
      },
    );
  }

  Widget _buildTrendingTVShowsSection() {
    return Consumer<TrendingProvider>(
      builder: (context, trendingProvider, _) {
        if (trendingProvider.trendingTVShows.isEmpty) {
          return const SizedBox.shrink();
        }
        return _buildTrendingCarousel(
          'Trending TV Shows',
          trendingProvider.trendingTVShows,
        );
      },
    );
  }

  Widget _buildNetflixSection() {
    return Consumer<TrendingProvider>(
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
    return Consumer<TrendingProvider>(
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
            //const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildTopKDramasSection() {
    return Consumer<KDramaProvider>(
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
    return Consumer<KDramaProvider>(
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
        const SizedBox(height: 16),
        SizedBox(
          height: 245,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _buildTrendingCard(items[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingCard(TrendingItem item, int index) {
    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 375),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: GestureDetector(
            onTap: () {
              // Convert TrendingItem to ImdbSearchResult for MediaInfoScreen
              final imdbItem = ImdbSearchResult(
                id: item.id, // TMDB ID - MediaInfoScreen will handle it
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image with gradient overlay
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        child: CachedNetworkImage(
                          imageUrl: item.posterUrl ?? '',
                          fit: BoxFit.cover,
                          width: 120,
                          height: 180,
                          placeholder: (_, __) => Shimmer.fromColors(
                            baseColor: AppTheme.cardColor,
                            highlightColor: AppTheme.cardColor.withOpacity(0.5),
                            child: Container(
                              width: 120,
                              height: 180,
                              color: AppTheme.cardColor,
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 120,
                            height: 180,
                            color: AppTheme.surfaceColor,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Text below
                  Container(
                    width: 120,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12)),
                      // border: Border.all(
                      //   color: AppTheme.primaryColor.withOpacity(0.2),
                      //   width: 1,
                      // ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (item.releaseDate != null)
                          Text(
                            item.releaseDate!,
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                            ),
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
  }

  Widget _buildKDramaCarousel(String title, List<KDramaItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        const SizedBox(height: 16),
        SizedBox(
          height: 245,
          child: ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) =>
                _buildKDramaCard(items[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildKDramaCard(KDramaItem item, int index) {
    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 375),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: GestureDetector(
            onTap: () {
              // Convert KDramaItem to ImdbSearchResult for MediaInfoScreen
              final imdbItem = ImdbSearchResult(
                id: item.id, // K-drama ID from MyDramaList
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
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image with gradient overlay
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12)),
                        child: CachedNetworkImage(
                          imageUrl: item.posterUrl ?? '',
                          fit: BoxFit.cover,
                          width: 120,
                          height: 180,
                          placeholder: (_, __) => Shimmer.fromColors(
                            baseColor: AppTheme.cardColor,
                            highlightColor: AppTheme.cardColor.withOpacity(0.5),
                            child: Container(
                              width: 120,
                              height: 180,
                              color: AppTheme.cardColor,
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 120,
                            height: 180,
                            color: AppTheme.surfaceColor,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Text below
                  Container(
                    width: 120,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12)),
                      // border: Border.all(
                      //   color: AppTheme.accentColor.withOpacity(0.3),
                      //   width: 1,
                      // ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (item.releaseYear != null)
                          Text(
                            '${item.releaseYear}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        if (item.episodes != null)
                          Text(
                            '${item.episodes} eps',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 9,
                            ),
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
  }

  Widget _buildActivity(MagnetProvider provider) {
    final recent = provider.magnets.take(4).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RECENT ACTIVITY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.5,
                ),
              ),
              if (recent.isNotEmpty)
                Text(
                  'VIEW ALL →',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (recent.isEmpty)
            Container(
              height: 140,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderColor, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 32, color: AppTheme.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      'NO ACTIVITY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMuted,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...recent.map((magnet) => _GlassActivityCard(magnet: magnet)),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 300.ms);
  }

  void _showAddMagnetDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADD MAGNET',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Paste magnet link or hash...',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL'),
                  ),
                  const SizedBox(width: 8),
                  CompactButton(
                    text: 'ADD',
                    icon: Icons.add,
                    onPressed: () async {
                      if (controller.text.trim().isNotEmpty) {
                        Navigator.pop(context);
                        await context
                            .read<MagnetProvider>()
                            .uploadMagnet(controller.text.trim());
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Magnet added'),
                                backgroundColor: AppTheme.successColor),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchLinkSheet extends StatefulWidget {
  final ImdbSearchResult item;
  final VoidCallback onLinked;

  const _SearchLinkSheet({required this.item, required this.onLinked});

  @override
  State<_SearchLinkSheet> createState() => _SearchLinkSheetState();
}

class _SearchLinkSheetState extends State<_SearchLinkSheet> {
  final TorrentScraperService _scraper = TorrentScraperService();
  final ImdbService _imdbService = ImdbService();
  List<TorrentEntry> _results = [];
  bool _loading = true;
  bool _detailsLoading = false;
  ImdbSearchResult? _detailedItem;
  int? _selectedSeason;
  int? _selectedEpisode;

  ImdbSearchResult get _currentItem => _detailedItem ?? widget.item;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _search();
  }

  bool get _isTvShow {
    final kind = _currentItem.kind?.toLowerCase();
    return kind == 'tvseries' ||
        kind == 'tv series' ||
        kind == 'series' ||
        kind == 'tvepisode';
  }

  Future<void> _loadDetails() async {
    if (_detailsLoading) return;
    setState(() => _detailsLoading = true);
    try {
      final details = await _imdbService.fetchDetails(widget.item.id);
      debugPrint(
          '[IMDB] Loaded details for ${widget.item.title} (${widget.item.id}) - kind=${details.kind}');
      if (!mounted) return;
      setState(() {
        _detailedItem = widget.item.copyWith(
          kind: details.kind ?? widget.item.kind,
          rating: widget.item.rating ?? details.rating,
          description: widget.item.description ?? details.description,
          posterUrl: widget.item.posterUrl.isNotEmpty
              ? widget.item.posterUrl
              : details.posterUrl,
          year: widget.item.year.isNotEmpty ? widget.item.year : details.year,
        );
      });
    } finally {
      if (mounted) {
        setState(() => _detailsLoading = false);
      }
    }
  }

  Future<void> _search() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final item = _currentItem;
    final queryTitle = item.title.isNotEmpty ? item.title : widget.item.title;
    final queryYear = item.year.isNotEmpty ? item.year : widget.item.year;
    final results = await _scraper.search('$queryTitle $queryYear'.trim());
    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Poster and Info Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster
                Hero(
                  tag: 'poster_${_currentItem.id}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: _currentItem.posterUrl,
                      width: 100,
                      height: 150,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 100,
                        height: 150,
                        color: AppTheme.cardColor,
                        child: const Icon(Icons.movie, size: 40),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentItem.title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_currentItem.year.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _currentItem.year,
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (_currentItem.rating?.isNotEmpty ?? false)
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              _currentItem.rating!,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const Text(
                              ' / 10',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
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

          if (_isTvShow) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SEASON',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: DropdownButton<int>(
                            value: _selectedSeason,
                            hint: const Text('Select',
                                style: TextStyle(color: AppTheme.textMuted)),
                            isExpanded: true,
                            underline: const SizedBox(),
                            dropdownColor: AppTheme.cardColor,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            items: List.generate(20, (i) => i + 1)
                                .map((season) => DropdownMenuItem(
                                      value: season,
                                      child: Text('Season $season'),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedSeason = value),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EPISODE',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: DropdownButton<int>(
                            value: _selectedEpisode,
                            hint: const Text('Select',
                                style: TextStyle(color: AppTheme.textMuted)),
                            isExpanded: true,
                            underline: const SizedBox(),
                            dropdownColor: AppTheme.cardColor,
                            style: const TextStyle(color: AppTheme.textPrimary),
                            items: List.generate(50, (i) => i + 1)
                                .map((episode) => DropdownMenuItem(
                                      value: episode,
                                      child: Text('Ep $episode'),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _selectedEpisode = value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Search Torrents Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to search with pre-filled query
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TorrentSearchScreen(
                        initialQuery:
                            '${_currentItem.title} ${_currentItem.year}'.trim(),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.search_rounded, size: 20),
                label: const Text(
                  'SEARCH TORRENTS',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Quick Link Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'QUICK LINK',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: AppTheme.textMuted,
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: AppTheme.borderColor, height: 1),
          ),
          const SizedBox(height: 12),

          // Results List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 48, color: AppTheme.textMuted),
                            const SizedBox(height: 12),
                            const Text(
                              'No quick links found',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Use "Search Torrents" button above',
                              style: TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final torrent = _results[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.borderColor
                                      .withValues(alpha: 0.5)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              title: Text(
                                torrent.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    if (torrent.size != null &&
                                        torrent.size!.isNotEmpty) ...[
                                      Icon(Icons.storage_rounded,
                                          size: 14, color: AppTheme.textMuted),
                                      const SizedBox(width: 4),
                                      Text(
                                        torrent.size!,
                                        style: const TextStyle(
                                          color: AppTheme.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    if (torrent.seeders != null) ...[
                                      Icon(Icons.arrow_upward_rounded,
                                          size: 14,
                                          color: Colors.green.shade400),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${torrent.seeders}',
                                        style: TextStyle(
                                          color: Colors.green.shade400,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              trailing: Icon(Icons.link_rounded,
                                  color: AppTheme.primaryColor, size: 20),
                              onTap: () async {
                                if (_isTvShow &&
                                    (_selectedSeason == null ||
                                        _selectedEpisode == null)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Please select season and episode'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }

                                // Link logic
                                final infoHash = torrent.infoHash ??
                                    Uri.parse(torrent.url)
                                        .queryParameters['xt']
                                        ?.split(':')
                                        .last ??
                                    '';

                                if (infoHash.isNotEmpty) {
                                  // Add magnet to provider
                                  final result = await context
                                      .read<MagnetProvider>()
                                      .uploadMagnet(infoHash);

                                  if (result != null && result.id != null) {
                                    // Save link to ImdbService (Recents/Link) with season/episode
                                    final baseItem = _currentItem;
                                    final newItem = baseItem.copyWith(
                                      magnetId: result.id.toString(),
                                      season: _selectedSeason,
                                      episode: _selectedEpisode,
                                    );
                                    debugPrint(
                                        '[IMDB] Saving link for ${baseItem.title} (${baseItem.id}) kind=${newItem.kind} S${newItem.season}E${newItem.episode}');
                                    await ImdbService()
                                        .saveLink(baseItem.id, newItem);
                                    await ImdbService().addToRecents(newItem);

                                    if (mounted) {
                                      Navigator.pop(context);
                                      widget.onLinked();
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text('Linked & Magnet Added'),
                                              backgroundColor:
                                                  AppTheme.successColor));
                                    }
                                  }
                                }
                              },
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

class _GlassActivityCard extends StatelessWidget {
  final dynamic magnet;

  const _GlassActivityCard({required this.magnet});

  @override
  Widget build(BuildContext context) {
    final isReady = magnet.statusCode == 4; // Ready
    final progress = magnet.size > 0 ? (magnet.downloaded / magnet.size) : 0.0;

    // Status Logic
    Color statusColor;
    if (isReady) {
      statusColor = AppTheme.successColor;
    } else if (magnet.statusCode == 5) {
      statusColor = AppTheme.errorColor;
    } else {
      statusColor = AppTheme.primaryColor;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isReady ? Icons.check : Icons.download_rounded,
                      color: statusColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          magnet.filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (!isReady)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white10,
                              color: statusColor,
                              minHeight: 3,
                            ),
                          )
                        else
                          Text(
                            'Completed • ${formatBytes(magnet.size)}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isReady)
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ).asGlass(
          tintColor: Colors.black,
          clipBorderRadius: BorderRadius.circular(16),
          blurX: 15,
          blurY: 15,
        ),
      ),
    );
  }
}
