import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../services/rivestream_service.dart';
import '../../services/imdb_service.dart';
import '../home/media_info_screen.dart';
import '../../services/ai_recommendation_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/providers.dart';
import '../../utils/watchlist_actions.dart';
import '../../widgets/widgets.dart';

class BrowsePage extends ConsumerStatefulWidget {
  const BrowsePage({super.key});

  @override
  ConsumerState<BrowsePage> createState() => _BrowsePageState();
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

class _BrowsePageState extends ConsumerState<BrowsePage> {
  final RiveStreamService _riveService = RiveStreamService();
  final ScrollController _scrollController = ScrollController();
  late List<DiscoverySection> _allSections;
  late List<GenreInterestItem> _featuredMixItems;
  int _displayedSectionCount = 6;
  static const int _sectionsPerLoad = 3;
  bool _isLoadingMore = false;

  // AI Recommendation state
  List<Map<String, dynamic>> _aiRecommendations = [];
  bool _isAiLoading = false;
  String? _selectedMood;
  final TextEditingController _aiPromptController = TextEditingController();

  final List<({String label, IconData icon, String value})> _moodsList = [
    (label: 'Romantic', icon: Icons.favorite_rounded, value: 'romantic'),
    (label: 'Cozy', icon: Icons.coffee_rounded, value: 'cozy'),
    (label: 'Dark', icon: Icons.nightlight_round, value: 'dark'),
    (label: 'Action', icon: Icons.bolt_rounded, value: 'action'),
    (label: 'Happy', icon: Icons.wb_sunny_outlined, value: 'happy'),
    (label: 'Vibe', icon: Icons.auto_awesome_outlined, value: 'vibey'),
    (label: 'Sad', icon: Icons.cloud_outlined, value: 'sad'),
    (label: 'Hard', icon: Icons.flash_on_rounded, value: 'thrilling'),
    (label: 'Horror', icon: Icons.masks_rounded, value: 'horror'),
    (
      label: 'Funny',
      icon: Icons.sentiment_very_satisfied_rounded,
      value: 'funny'
    ),
    (label: 'Mystery', icon: Icons.search_rounded, value: 'mystery'),
  ];

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
    _aiPromptController.dispose();
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
    unawaited(Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, __) => MediaInfoScreen(item: imdbItem),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ));
  }

  Widget _buildAIRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                'AI MAGIC FOR YOU',
                style: GoogleFonts.outfit(
                  color: AppTheme.primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _aiRecommendations = []),
                child: Icon(Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.3), size: 16),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _aiRecommendations.length,
            itemBuilder: (context, index) {
              final rec = _aiRecommendations[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Hero(
                  tag: 'ai_rec_${rec['title']}',
                  child: _buildAIRecommendationCard(rec),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAIRecommendationCard(Map<String, dynamic> rec) {
    return GestureDetector(
      onTap: () => _openAIRecommendationItem(rec),
      onDoubleTap: () => _toggleAiWatchlist(rec),
      child: Container(
        width: 126,
        decoration: BoxDecoration(
          color: AppTheme.elevatedColor,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor.withValues(alpha: 0.15),
                AppTheme.primaryColor.withValues(alpha: 0.05),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  rec['type'] == 'tv' ? Icons.tv_rounded : Icons.movie_rounded,
                  color: AppTheme.primaryColor.withValues(alpha: 0.4),
                  size: 32,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    rec['title'] ?? '',
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
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
    );
  }

  Future<void> _openAIRecommendationItem(Map<String, dynamic> rec) async {
    HapticFeedback.lightImpact();
    // Simplified resolving - just push title/type and let MediaInfo handle it if possible
    // Or we stick to a "magic" loading state
    final imdbItem = ImdbSearchResult(
      id: (rec['imdbId'] ?? '').toString(),
      title: (rec['title'] ?? '').toString(),
      posterUrl: '',
      year: (rec['year'] ?? '').toString(),
      kind: (rec['type'] ?? '').toString() == 'tv' ? 'tvseries' : 'movie',
      description: (rec['reason'] ?? '').toString(),
    );

    unawaited(Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, __) => MediaInfoScreen(item: imdbItem),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    ));
  }

  void _showAIVibePicker(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final appState = ref.watch(appNotifierProvider);
          return StatefulBuilder(
            builder: (context, modalSetState) => Container(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  top: 24,
                  left: 20,
                  right: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_rounded,
                          color: AppTheme.primaryColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'WHAT\'S YOUR VIBE${appState.user?.username != null ? ', ${appState.user!.username.toUpperCase()}' : ''}?',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _moodsList.map((mood) {
                      final isSelected = _selectedMood == mood.value;
                      return GestureDetector(
                        onTap: () {
                          modalSetState(() => _selectedMood = mood.value);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.white.withValues(alpha: 0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(mood.icon,
                                  size: 14,
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : Colors.white54),
                              const SizedBox(width: 8),
                              Text(
                                mood.label,
                                style: GoogleFonts.outfit(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _aiPromptController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Anything else? (cozy, fast-paced...)',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isAiLoading
                          ? null
                          : () => _getAIRecommendations(modalSetState),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isAiLoading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.black),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'CURATING MAGIC...',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'GENERATE RECOMMENDATIONS',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
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
    );
  }

  Future<void> _getAIRecommendations(
      void Function(void Function()) modalSetState) async {
    final apiKey = ref
            .read(appNotifierProvider.notifier)
            .getSetting<String>('nvidia_api_key') ??
        '';
    if (apiKey.trim().isEmpty) {
      showAppSnackBar(context, 'Please add NVIDIA API key in Settings',
          type: AppFeedbackType.error);
      return;
    }

    final vibe = _selectedMood ?? _aiPromptController.text.trim();
    if (vibe.isEmpty) {
      showAppSnackBar(context, 'Pick a vibe or type something!',
          type: AppFeedbackType.info);
      return;
    }

    modalSetState(() => _isAiLoading = true);
    setState(() => _isAiLoading = true);

    try {
      final aiService = AIRecommendationService(apiKey: apiKey);
      final appState = ref.read(appNotifierProvider);

      // STEP 1: Get Genre IDs for Vibe
      final availableGenresMapping = <String, String>{};
      for (final s in _allSections) {
        availableGenresMapping[s.title] = s.id;
      }

      final targetGenreIds = await aiService.getGenreIdsForVibe(
          vibe: vibe, availableGenres: availableGenresMapping);

      // STEP 2: Fetch pool of items (Genres + User Context)
      final poolSet = <Map<String, dynamic>>[];

      // Fetch from mapped Genres
      for (final genreId in targetGenreIds.take(3)) {
        try {
          final items = await _riveService.getGenreInterest(genreId);
          final mixed = [
            ...(items?.popularMovies ?? []),
            ...(items?.popularTv ?? [])
          ];
          for (final i in mixed.take(15)) {
            poolSet.add({
              'title': i.title,
              'imdbId': i.imdbId,
              'mediaType': i.mediaType,
              'plot': i.plot,
            });
          }
        } catch (_) {}
      }

      // Add context (Watchlist) to pool to help AI see what we like/exclude
      for (final i in appState.watchlist.take(10)) {
        poolSet.add({
          'title': i.title,
          'imdbId': i.id,
          'mediaType': i.kind?.contains('movie') == true ? 'movie' : 'tv',
          'plot': i.description ?? '',
        });
      }

      // STEP 3: Final AI Ranking from pool
      final continueWatching = ref.read(continueWatchingProvider).value ?? [];
      final userHistory = [
        ...appState.watchlist.map((e) => e.title),
        ...continueWatching.map((e) => e.media.title),
      ];

      final results = await aiService.rankRecommendationsFromPool(
        vibe: vibe,
        pool: poolSet.toList(),
        userContextTitles: userHistory,
      );

      if (mounted) {
        setState(() {
          _aiRecommendations = results;
          _isAiLoading = false;
        });
        Navigator.pop(context); // Close modal
        showAppSnackBar(context, 'AI Magic Ready!',
            type: AppFeedbackType.success);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, 'AI Error: $e', type: AppFeedbackType.error);
        modalSetState(() => _isAiLoading = false);
        setState(() => _isAiLoading = false);
      }
    }
  }

  void _toggleWatchlist(GenreInterestItem item) {
    HapticFeedback.mediumImpact();
    final appState = ref.read(appNotifierProvider);
    final imdbItem = ImdbSearchResult(
      id: item.imdbId,
      title: item.title,
      posterUrl: item.poster ?? '',
      year: item.year.toString(),
      kind: item.mediaType == 'movie' ? 'movie' : 'tvseries',
      rating: item.rating.toStringAsFixed(1),
      description: item.plot,
    );
    toggleWatchlistWithFeedback(context, ref, appState, imdbItem);
  }

  void _toggleAiWatchlist(Map<String, dynamic> rec) {
    HapticFeedback.mediumImpact();
    final appState = ref.read(appNotifierProvider);
    final imdbItem = ImdbSearchResult(
      id: (rec['imdbId'] ?? '').toString(),
      title: (rec['title'] ?? '').toString(),
      posterUrl: '',
      year: (rec['year'] ?? '').toString(),
      kind: (rec['type'] ?? '').toString() == 'tv' ? 'tvseries' : 'movie',
      description: (rec['reason'] ?? '').toString(),
    );
    toggleWatchlistWithFeedback(context, ref, appState, imdbItem);
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
                  if (_aiRecommendations.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildAIRecommendationsSection(),
                    ),
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
      child: Column(
        children: [
          ScreenIntroHeader(
            eyebrow: 'EXPLORE',
            title: 'DISCOVER',
            subtitle:
                'Browse hand-picked shelves and quick mood-based discovery.',
            trailing: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded,
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
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh,
                          color: AppTheme.textPrimary, size: 18),
                      SizedBox(width: 12),
                      Text(
                        'Refresh All',
                        style: TextStyle(color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
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
              // AI Button aligned with title
              GestureDetector(
                onTap: () => _showAIVibePicker(context),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.psychology_rounded,
                    color: AppTheme.primaryColor.withValues(alpha: 0.8),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Creative mix items in horizontal scroll (same as regular sections)
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _featuredMixItems.length,
            itemBuilder: (context, index) {
              final item = _featuredMixItems[index];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: 126,
                  child: GestureDetector(
                    onTap: () => _handleItemTap(item),
                    onDoubleTap: () => _toggleWatchlist(item),
                    child: _buildDiscoveryCard(item),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDiscoverySection(DiscoverySection section) {
    if (section.isLoading && section.items.isEmpty) {
      return SizedBox(
        height: 190,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 5,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(right: 10),
            child: SizedBox(
              width: 126,
              child: Shimmer.fromColors(
                baseColor: AppTheme.cardColor,
                highlightColor: AppTheme.elevatedColor.withValues(alpha: 0.8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (section.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: SizedBox(
          height: 140,
          child: EmptyState(
            icon: Icons.movie_filter_outlined,
            title: 'Nothing here yet',
            subtitle: 'Try refreshing or explore another category.',
          ),
        ),
      );
    }

    return SizedBox(
      height: 190,
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
              width: 126,
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
        final appState = ref.watch(appNotifierProvider);
        final isInWatchlist = appState.isInWatchlist(item.imdbId);

        return AnimationConfiguration.staggeredList(
          position: 0,
          child: ScaleAnimation(
            child: FadeInAnimation(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _handleItemTap(item);
                },
                onDoubleTap: () => _toggleWatchlist(item),
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
                      if (!appState.isInWatchlist(imdbItem.id)) {
                        addToWatchlistIfMissing(
                            context, ref, appState, imdbItem);
                      }
                      Navigator.pop(context);
                    },
                    onShare: () {
                      Navigator.pop(context);
                      _shareContent(item);
                    },
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: item.poster ?? '',
                        fit: BoxFit.cover,
                        fadeInDuration: Duration.zero,
                        fadeOutDuration: Duration.zero,
                        placeholder: (_, __) => const AppBlurHashPlaceholder(
                          backgroundColor: AppTheme.cardColor,
                        ),
                        errorWidget: (_, __, ___) =>
                            const AppBlurHashPlaceholder(
                          backgroundColor: AppTheme.cardColor,
                          fallbackIcon:
                              Icon(Icons.movie, color: Colors.white10),
                        ),
                      ),
                      // IN LIST badge
                      if (isInWatchlist)
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
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
    );
  }

  void _shareContent(GenreInterestItem item) {
    HapticFeedback.mediumImpact();
    unawaited(Share.share(
      'Check out "${item.title}" on AllDebrid!\n\nDiscovered through the app.',
      subject: item.title,
    ));
  }

  void _showCardContextMenu(
    BuildContext context, {
    required String title,
    required VoidCallback onAddWatchlist,
    required VoidCallback onShare,
  }) {
    unawaited(showModalBottomSheet(
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
    ));
  }
}
