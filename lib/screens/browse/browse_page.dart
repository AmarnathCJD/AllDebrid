import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/rivestream_service.dart';
import '../../services/imdb_service.dart';
import '../home/media_info_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';

class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

// Discovery section model for genre-based browsing
class DiscoverySection {
  final String title;
  final String id;
  final Future<List<GenreInterestItem>> Function(RiveStreamService service)
      loader;
  List<GenreInterestItem> items = [];
  bool isLoading = true;

  DiscoverySection({
    required this.title,
    required this.id,
    required this.loader,
  });
}

class _BrowsePageState extends State<BrowsePage> {
  final RiveStreamService _riveService = RiveStreamService();
  final ScrollController _scrollController = ScrollController();
  late List<DiscoverySection> _allSections;
  late List<GenreInterestItem> _featuredMixItems;
  int _displayedSectionCount = 6;
  static const int _sectionsPerLoad = 3;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _featuredMixItems = [];
    _initializeSections();
    _loadAllSections();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
              _scrollController.position.maxScrollExtent - 1000 &&
          !_isLoadingMore &&
          _displayedSectionCount < _allSections.length) {
        _loadMoreSections();
      }
    });
  }

  Future<void> _loadMoreSections() async {
    if (_isLoadingMore || _displayedSectionCount >= _allSections.length) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    final nextIndex = _displayedSectionCount;
    final endIndex = (_displayedSectionCount + _sectionsPerLoad)
        .clamp(0, _allSections.length);

    for (int i = nextIndex; i < endIndex; i++) {
      try {
        final items = await _allSections[i].loader(_riveService);
        if (mounted) {
          setState(() {
            _allSections[i].items = items.take(20).toList();
            _allSections[i].isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _allSections[i].isLoading = false;
            _allSections[i].items = [];
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _displayedSectionCount = endIndex;
        _isLoadingMore = false;
      });
    }
  }

  void _initializeSections() {
    _allSections = [
      // Romance - Top Priority
      DiscoverySection(
        title: 'Romance',
        id: 'in0000152',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000152');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Rom-Com',
        id: 'in0000153',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000153');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Feel-Good',
        id: 'in0000151',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000151');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      // Korean Content - Second Priority
      DiscoverySection(
        title: 'K-Drama',
        id: 'in0000209',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000209');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Korean',
        id: 'in0000225',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000225');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Drama',
        id: 'in0000076',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000076');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      // Regional Languages
      DiscoverySection(
        title: 'Hindi',
        id: 'in0000222',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000222');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Malayalam',
        id: 'in0000240',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000240');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Tamil',
        id: 'in0000235',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000235');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Telugu',
        id: 'in0000236',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000236');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Kannada',
        id: 'in0000241',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000241');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      // Action and Others
      DiscoverySection(
        title: 'Action',
        id: 'in0000001',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000001');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Superhero',
        id: 'in0000008',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000008');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Comedy',
        id: 'in0000034',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000034');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Horror',
        id: 'in0000112',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000112');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Japanese',
        id: 'in0000224',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000224');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'French',
        id: 'in0000219',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000219');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Thriller',
        id: 'in0000103',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000103');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Fantasy',
        id: 'in0000115',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000115');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Sci-Fi',
        id: 'in0000088',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000088');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Mystery',
        id: 'in0000095',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000095');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Adventure',
        id: 'in0000012',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000012');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
      DiscoverySection(
        title: 'Crime',
        id: 'in0000004',
        loader: (service) async {
          final result = await service.getGenreInterest('in0000004');
          return [
            ...(result?.popularMovies ?? []),
            ...(result?.popularTv ?? [])
          ];
        },
      ),
    ];
  }

  Future<void> _loadAllSections() async {
    _loadFeaturedMix();

    for (int i = 0;
        i < _displayedSectionCount && i < _allSections.length;
        i++) {
      try {
        final items = await _allSections[i].loader(_riveService);
        if (mounted) {
          setState(() {
            _allSections[i].items = items.take(20).toList();
            _allSections[i].isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _allSections[i].isLoading = false;
            _allSections[i].items = [];
          });
        }
      }
    }
  }

  Future<void> _loadFeaturedMix() async {
    try {
      final mixes = <GenreInterestItem>[];
      final genreIds = [
        'in0000152',
        'in0000153',
        'in0000209',
        'in0000225',
        'in0000076'
      ];
      for (final id in genreIds) {
        final result = await _riveService.getGenreInterest(id);
        mixes.addAll(result?.popularMovies ?? []);
        mixes.addAll(result?.popularTv ?? []);
      }
      mixes.shuffle();
      if (mounted) {
        setState(() {
          _featuredMixItems = mixes.take(15).toList();
        });
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _featuredMixItems = [];
      for (final section in _allSections) {
        section.isLoading = true;
        section.items = [];
      }
    });

    await _loadAllSections();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleItemTap(GenreInterestItem item) {
    final imdbItem = ImdbSearchResult(
      id: item.imdbId,
      title: item.title,
      posterUrl: item.poster ?? '',
      year: item.year.toString(),
      kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
      rating: item.rating.toStringAsFixed(1),
      description: item.plot,
    );
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, __) => MediaInfoScreen(item: imdbItem),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  void _toggleWatchlist(GenreInterestItem item) {
    HapticFeedback.mediumImpact();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final imdbItem = ImdbSearchResult(
      id: item.imdbId,
      title: item.title,
      posterUrl: item.poster ?? '',
      year: item.year.toString(),
      kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
      rating: item.rating.toStringAsFixed(1),
      description: item.plot,
    );
    final wasInWatchlist = appProvider.isInWatchlist(imdbItem.id);
    appProvider.toggleWatchlist(imdbItem);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            wasInWatchlist ? 'Removed from Watchlist' : 'Added to Watchlist'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E1E1E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              color: AppTheme.primaryColor,
              backgroundColor: AppTheme.cardColor,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  if (_featuredMixItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildFeaturedMixSection(),
                    ),
                  ..._allSections
                      .take(_displayedSectionCount)
                      .toList()
                      .asMap()
                      .entries
                      .map((entry) {
                    final section = entry.value;
                    return SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader(section.title),
                          _buildDiscoverySection(section),
                          const SizedBox(height: 12),
                        ],
                      ),
                    );
                  }),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXPLORE',
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
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  color: AppTheme.textMuted, size: 22),
              color: AppTheme.elevatedColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                      color: AppTheme.borderColor.withValues(alpha: 0.3),
                      width: 1)),
              onSelected: (value) {
                if (value == 'refresh') {
                  _handleRefresh();
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh,
                          color: AppTheme.textPrimary, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        'Refresh All',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFeaturedMixSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FEATURED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Creative Mix',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.68,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _featuredMixItems.length,
            itemBuilder: (context, index) {
              final item = _featuredMixItems[index];
              return GestureDetector(
                onTap: () => _handleItemTap(item),
                onDoubleTap: () => _toggleWatchlist(item),
                child: _buildDiscoveryCard(item),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDiscoverySection(DiscoverySection section) {
    if (section.isLoading && section.items.isEmpty) {
      return SizedBox(
        height: 240,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 5,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 120,
              child: Shimmer.fromColors(
                baseColor: AppTheme.cardColor,
                highlightColor: AppTheme.elevatedColor.withValues(alpha: 0.8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (section.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Center(
          child: Text(
            'No content available',
            style: GoogleFonts.outfit(
              color: AppTheme.textMuted,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: section.items.length,
        itemBuilder: (context, index) {
          final item = section.items[index];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 120,
              child: _buildDiscoveryCard(item),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiscoveryCard(GenreInterestItem item) {
    return StatefulBuilder(
      builder: (context, cardSetState) {
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        final isInWatchlist = appProvider.isInWatchlist(item.imdbId);

        return AnimationConfiguration.staggeredList(
          position: 0,
          child: ScaleAnimation(
            child: FadeInAnimation(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _handleItemTap(item);
                },
                onDoubleTap: () {
                  HapticFeedback.mediumImpact();
                  final imdbItem = ImdbSearchResult(
                    id: item.imdbId,
                    title: item.title,
                    posterUrl: item.poster ?? '',
                    year: item.year.toString(),
                    kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
                    rating: item.rating.toStringAsFixed(1),
                    description: item.plot,
                  );
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
                  cardSetState(() {});
                },
                onLongPress: () {
                  _showCardContextMenu(
                    context,
                    title: item.title,
                    onAddWatchlist: () {
                      final imdbItem = ImdbSearchResult(
                        id: item.imdbId,
                        title: item.title,
                        posterUrl: item.poster ?? '',
                        year: item.year.toString(),
                        kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
                        rating: item.rating.toStringAsFixed(1),
                        description: item.plot,
                      );
                      final wasInWatchlist =
                          appProvider.isInWatchlist(imdbItem.id);
                      if (!wasInWatchlist) {
                        appProvider.toggleWatchlist(imdbItem);
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Added to Watchlist'),
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: const Color(0xFF1E1E1E),
                          ),
                        );
                        cardSetState(() {});
                      }
                      Navigator.pop(context);
                    },
                    onShare: () {
                      Navigator.pop(context);
                      _shareContent(item);
                    },
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 180,
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: item.poster ?? '',
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: AppTheme.cardColor),
                              errorWidget: (_, __, ___) => Container(
                                color: AppTheme.cardColor,
                                child: const Icon(Icons.movie,
                                    color: Colors.white10),
                              ),
                            ),
                            // IN LIST badge
                            if (isInWatchlist)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'IN LIST',
                                    style: GoogleFonts.outfit(
                                      color: Colors.black,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            // Rating badge
                            Positioned(
                              bottom: 6,
                              left: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        color: Colors.amber, size: 10),
                                    const SizedBox(width: 2),
                                    Text(
                                      item.rating.toStringAsFixed(1),
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        item.year.toString(),
                        style: GoogleFonts.outfit(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _shareContent(GenreInterestItem item) {
    HapticFeedback.mediumImpact();
    Share.share(
      'Check out "${item.title}" on AllDebrid!\n\nDiscovered through the app.',
      subject: item.title,
    );
  }

  void _showCardContextMenu(
    BuildContext context, {
    required String title,
    required VoidCallback onAddWatchlist,
    required VoidCallback onShare,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_add, color: Colors.white70),
            title: Text('Add to Watchlist',
                style: GoogleFonts.outfit(color: Colors.white)),
            onTap: onAddWatchlist,
          ),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.white70),
            title:
                Text('Share', style: GoogleFonts.outfit(color: Colors.white)),
            onTap: onShare,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
