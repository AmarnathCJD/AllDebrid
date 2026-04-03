import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/riverpod_compat.dart';

import '../widgets/widgets.dart';
import './home/media_info_screen.dart';
import './settings/settings_screen.dart';
import '../../providers/app_provider.dart';
import '../../services/ai_recommendation_service.dart';
import '../../services/imdb_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/watchlist_actions.dart';

class AIRecommendationPage extends StatefulWidget {
  const AIRecommendationPage({super.key});

  @override
  State<AIRecommendationPage> createState() => _AIRecommendationPageState();
}

class _AIRecommendationPageState extends State<AIRecommendationPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  final ImdbService _imdbService = ImdbService();
  final TextEditingController _promptController = TextEditingController();

  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedMood;
  final Set<String> _resolvingRecommendationKeys = <String>{};

  final List<({String label, IconData icon, String value})> _moods = [
    (label: 'Happy', icon: Icons.wb_sunny_outlined, value: 'happy'),
    (label: 'Vibey', icon: Icons.auto_awesome_outlined, value: 'vibey'),
    (label: 'Sad', icon: Icons.cloud_outlined, value: 'sad'),
    (
      label: 'Emotional',
      icon: Icons.favorite_border_rounded,
      value: 'emotional'
    ),
    (label: 'Thrilling', icon: Icons.bolt_rounded, value: 'thrilling'),
    (label: 'Horror', icon: Icons.nightlight_round, value: 'horror'),
    (label: 'Romantic', icon: Icons.favorite_rounded, value: 'romantic'),
    (
      label: 'Funny',
      icon: Icons.sentiment_very_satisfied_rounded,
      value: 'funny'
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _getRecommendations() async {
    final appProvider = context.read<AppProvider>();
    final apiKey = appProvider.getSetting<String>('nvidia_api_key') ?? '';
    if (apiKey.trim().isEmpty) {
      setState(() {
        _error =
            'Add your NVIDIA API key in Settings to unlock AI recommendations.';
      });
      return;
    }

    final prompt = _buildPrompt();
    if (prompt.isEmpty) {
      setState(() {
        _error = 'Pick a mood or describe what you want to watch.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _recommendations = [];
    });

    try {
      final aiService = AIRecommendationService(apiKey: apiKey);
      final watchlistContext =
          appProvider.watchlist.map(_compactWatchlistItem).toList();
      final likedGenres = _collectTopGenres(appProvider.watchlist);

      final recommendations = await aiService.getRecommendations(
        userInput: prompt,
        watchlist: watchlistContext,
        continueWatching: const [],
        likedGenres: likedGenres,
      );

      if (!mounted) return;

      if (recommendations.isEmpty) {
        setState(() {
          _error = 'No recommendations were generated.';
        });
        return;
      }

      setState(() {
        _recommendations = recommendations;
      });

      showAppSnackBar(
        context,
        'Found ${recommendations.length} recommendations for you.',
        type: AppFeedbackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _buildPrompt() {
    final freeform = _promptController.text.trim();
    if (_selectedMood != null && freeform.isNotEmpty) {
      return 'Mood: $_selectedMood. Request: $freeform';
    }
    if (_selectedMood != null) {
      return 'Mood: $_selectedMood';
    }
    return freeform;
  }

  String _compactWatchlistItem(ImdbSearchResult item) {
    final parts = <String>[item.title];
    if ((item.genres ?? '').trim().isNotEmpty) {
      parts.add('genres: ${item.genres}');
    }
    if ((item.kind ?? '').trim().isNotEmpty) {
      parts.add('type: ${item.kind}');
    }
    if (item.year.trim().isNotEmpty) {
      parts.add('year: ${item.year}');
    }
    return parts.join(' | ');
  }

  List<String> _collectTopGenres(List<ImdbSearchResult> watchlist) {
    final counts = <String, int>{};
    for (final item in watchlist) {
      final rawGenres = item.genres;
      if (rawGenres == null || rawGenres.trim().isEmpty) continue;
      for (final genre in rawGenres.split(',')) {
        final normalized = genre.trim();
        if (normalized.isEmpty) continue;
        counts.update(normalized, (value) => value + 1, ifAbsent: () => 1);
      }
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(6).map((entry) => entry.key).toList();
  }

  String _recommendationKey(Map<String, dynamic> recommendation) {
    final imdbId = (recommendation['imdbId'] ?? '').toString().trim();
    if (imdbId.isNotEmpty) {
      return imdbId;
    }
    return (recommendation['title'] ?? '').toString().trim().toLowerCase();
  }

  bool _isRecommendationSaved(
    Map<String, dynamic> recommendation,
    List<ImdbSearchResult> watchlist,
  ) {
    final imdbId = (recommendation['imdbId'] ?? '').toString().trim();
    if (imdbId.isNotEmpty) {
      return watchlist.any((item) => item.id == imdbId);
    }

    final title =
        (recommendation['title'] ?? '').toString().trim().toLowerCase();
    return watchlist.any((item) => item.title.trim().toLowerCase() == title);
  }

  Future<ImdbSearchResult?> _resolveRecommendationItem(
    Map<String, dynamic> recommendation,
  ) async {
    var item = ImdbSearchResult(
      id: (recommendation['imdbId'] ?? '').toString(),
      title: (recommendation['title'] ?? '').toString(),
      posterUrl: '',
      year: '',
      kind: recommendation['type'] == 'tv' ? 'tvseries' : 'movie',
      genres: (recommendation['genre'] ?? '').toString(),
      description: (recommendation['reason'] ?? '').toString(),
    );

    if (item.id.isNotEmpty) {
      final detailedItem = await _imdbService.fetchDetails(item.id);
      if (detailedItem.title.trim().isNotEmpty) {
        return detailedItem;
      }
      return item;
    }

    final results = await _imdbService.search(item.title);
    if (results.isNotEmpty) {
      return results.first;
    }
    return item.title.trim().isEmpty ? null : item;
  }

  Future<void> _openRecommendationDetails(
    Map<String, dynamic> recommendation,
  ) async {
    final key = _recommendationKey(recommendation);
    setState(() => _resolvingRecommendationKeys.add(key));

    try {
      final item = await _resolveRecommendationItem(recommendation);
      if (!mounted || item == null) return;

      Navigator.push(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, animation, __) => MediaInfoScreen(item: item),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Could not open this title right now.',
        type: AppFeedbackType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _resolvingRecommendationKeys.remove(key));
      }
    }
  }

  Future<void> _saveRecommendation(Map<String, dynamic> recommendation) async {
    final key = _recommendationKey(recommendation);
    final appProvider = context.read<AppProvider>();

    setState(() => _resolvingRecommendationKeys.add(key));
    try {
      final item = await _resolveRecommendationItem(recommendation);
      if (!mounted || item == null) return;

      final added = await addToWatchlistIfMissing(context, appProvider, item);
      if (!added && mounted) {
        showAppSnackBar(
          context,
          'Already in your watchlist',
          type: AppFeedbackType.info,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Could not save this recommendation.',
        type: AppFeedbackType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _resolvingRecommendationKeys.remove(key));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final watchlistCount = appProvider.watchlist.length;
    final hasApiKey = (appProvider.getSetting<String>('nvidia_api_key') ?? '')
        .trim()
        .isNotEmpty;
    final topGenres = _collectTopGenres(appProvider.watchlist);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI MAGIC',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'What\'s Your Vibe?',
                    style: GoogleFonts.outfit(
                      color: AppTheme.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Blend your mood with your watchlist to get sharper picks.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: StatBox(
                          label: 'Watchlist',
                          value: '$watchlistCount',
                          icon: Icons.bookmark_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: StatBox(
                          label: 'AI Setup',
                          value: hasApiKey ? 'Ready' : 'Required',
                          icon: hasApiKey
                              ? Icons.check_circle_rounded
                              : Icons.key_off_rounded,
                          color: hasApiKey
                              ? AppTheme.successColor
                              : AppTheme.warningColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  CompactCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pick Your Mood',
                          style: GoogleFonts.outfit(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _moods.map((mood) {
                            final isSelected = _selectedMood == mood.value;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedMood = mood.value;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                          .withValues(alpha: 0.12)
                                      : AppTheme.elevatedColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : AppTheme.borderColor,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      mood.icon,
                                      size: 16,
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : AppTheme.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      mood.label,
                                      style: GoogleFonts.outfit(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : AppTheme.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _promptController,
                          maxLines: 3,
                          minLines: 2,
                          decoration: const InputDecoration(
                            hintText:
                                'Optional: cozy sci-fi, a fast thriller, something like my watchlist but lighter...',
                          ),
                        ),
                        if (topGenres.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Based on your watchlist: ${topGenres.join(', ')}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: CompactButton(
                            text: hasApiKey
                                ? 'Get Recommendations'
                                : 'Open Settings to Add API Key',
                            icon: hasApiKey
                                ? Icons.auto_awesome_rounded
                                : Icons.settings_rounded,
                            isLoading: _isLoading,
                            onPressed: hasApiKey
                                ? _getRecommendations
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SettingsScreen(),
                                      ),
                                    );
                                  },
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.errorColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    AppTheme.errorColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppTheme.errorColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_recommendations.isNotEmpty) ...[
                    Text(
                      'Recommended For You',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._recommendations.asMap().entries.map((entry) {
                      final recommendation = entry.value;
                      final recommendationKey =
                          _recommendationKey(recommendation);
                      return _RecommendationCard(
                        recommendation: recommendation,
                        isSaved: _isRecommendationSaved(
                          recommendation,
                          appProvider.watchlist,
                        ),
                        isResolving: _resolvingRecommendationKeys
                            .contains(recommendationKey),
                        onAddToWatchlist: () =>
                            _saveRecommendation(recommendation),
                        onOpenDetails: () =>
                            _openRecommendationDetails(recommendation),
                      ).animate().fadeIn(duration: 350.ms).slideY(
                            begin: 0.2,
                            duration: 350.ms,
                            curve: Curves.easeOutCubic,
                            delay: Duration(milliseconds: entry.key * 80),
                          );
                    }),
                  ] else if (!_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 48),
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.98, end: 1.02).animate(
                          CurvedAnimation(
                            parent: _pulseController,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: EmptyState(
                          icon: Icons.auto_awesome_rounded,
                          title: hasApiKey
                              ? 'Start with a mood or prompt'
                              : 'AI setup needed',
                          subtitle: hasApiKey
                              ? 'Pick a vibe, add a short prompt, and I will generate five picks.'
                              : 'Add your NVIDIA API key in Settings to unlock recommendations.',
                        ),
                      ),
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

class _RecommendationCard extends StatelessWidget {
  final Map<String, dynamic> recommendation;
  final bool isSaved;
  final bool isResolving;
  final Future<void> Function() onAddToWatchlist;
  final Future<void> Function() onOpenDetails;

  const _RecommendationCard({
    required this.recommendation,
    required this.isSaved,
    required this.isResolving,
    required this.onAddToWatchlist,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: isResolving ? null : onOpenDetails,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.borderColor.withValues(alpha: 0.3),
            ),
            color: AppTheme.elevatedColor,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recommendation['title'] ?? '',
                          style: GoogleFonts.outfit(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.15),
                              ),
                              child: Text(
                                recommendation['type'].toString().toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                recommendation['genre'] ?? '',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                recommendation['reason'] ?? '',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: CompactButton(
                      text: isSaved ? 'Saved' : 'Save',
                      icon: isSaved
                          ? Icons.bookmark_added_rounded
                          : Icons.bookmark_add_rounded,
                      isSmall: true,
                      isPrimary: !isSaved,
                      isLoading: isResolving,
                      onPressed:
                          isSaved || isResolving ? null : onAddToWatchlist,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CompactButton(
                      text: 'Open',
                      icon: Icons.open_in_new_rounded,
                      isSmall: true,
                      isPrimary: false,
                      isLoading: false,
                      onPressed: isResolving ? null : onOpenDetails,
                    ),
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
