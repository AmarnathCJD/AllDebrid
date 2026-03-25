import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../services/ai_recommendation_service.dart';
import '../../providers/app_provider.dart';
import '../../services/imdb_service.dart';
import './home/media_info_screen.dart';

class AIRecommendationPage extends StatefulWidget {
  const AIRecommendationPage({super.key});

  @override
  State<AIRecommendationPage> createState() => _AIRecommendationPageState();
}

class _AIRecommendationPageState extends State<AIRecommendationPage>
    with TickerProviderStateMixin {
  late AnimationController _micController;
  late AIRecommendationService _aiService;
  final ImdbService _imdbService = ImdbService();

  List<Map<String, dynamic>> _recommendations = [];
  bool _isLoading = false;
  String? _error;
  String? _selectedMood;

  final List<Map<String, String>> _moods = [
    {'label': 'Happy', 'icon': '😊', 'value': 'happy'},
    {'label': 'Vibey', 'icon': '✨', 'value': 'vibey'},
    {'label': 'Sad', 'icon': '😢', 'value': 'sad'},
    {'label': 'Emotional', 'icon': '💔', 'value': 'emotional'},
    {'label': 'Thrilling', 'icon': '🔥', 'value': 'thrilling'},
    {'label': 'Horror', 'icon': '👻', 'value': 'horror'},
    {'label': 'Romantic', 'icon': '💕', 'value': 'romantic'},
    {'label': 'Funny', 'icon': '😂', 'value': 'funny'},
  ];

  @override
  void initState() {
    super.initState();
    _micController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Initialize AI service with API key (you'll need to add this to AppProvider)
    final appProvider = context.read<AppProvider>();
    _aiService = AIRecommendationService(
      apiKey: appProvider.getSetting<String>('nvidia_api_key') ?? '',
    );
  }

  @override
  void dispose() {
    _micController.dispose();
    super.dispose();
  }

  Future<void> _getRecommendations() async {
    if (_selectedMood == null) {
      setState(() => _error = 'Select a mood first');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _recommendations = [];
    });

    try {
      final appProvider = context.read<AppProvider>();
      final watchlistTitles =
          appProvider.watchlist.map((item) => item.title).toList();

      final recommendations = await _aiService.getRecommendations(
        userInput: _selectedMood!,
        watchlist: watchlistTitles,
        continueWatching: [],
        likedGenres: [],
      );

      if (recommendations.isNotEmpty) {
        setState(() {
          _recommendations = recommendations;
        });
      } else {
        setState(() => _error = 'Could not generate recommendations');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tell me your mood and I\'ll find your next favorite',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Mood Selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pick Your Mood',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _moods.map((mood) {
                      final isSelected = _selectedMood == mood['value'];
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedMood = mood['value']);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : AppTheme.borderColor.withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                            color: isSelected
                                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                : AppTheme.elevatedColor,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                mood['icon']!,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                mood['label']!,
                                style: GoogleFonts.outfit(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : Colors.white,
                                  fontSize: 12,
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
                  const SizedBox(height: 16),
                  // Get Recommendations Button
                  GestureDetector(
                    onTap: _isLoading ? null : _getRecommendations,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.accentColor,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.black.withValues(alpha: 0.8),
                                  ),
                                ),
                              )
                            : Text(
                                'Get Recommendations',
                                style: GoogleFonts.outfit(
                                  color: Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppTheme.errorColor.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AppTheme.errorColor.withValues(alpha: 0.3),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Recommendations List
            if (_recommendations.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _recommendations.length,
                  itemBuilder: (context, index) {
                    final rec = _recommendations[index];
                    return _RecommendationCard(
                      recommendation: rec,
                      imdbService: _imdbService,
                      delay: Duration(milliseconds: index * 100),
                    ).animate().fadeIn(duration: 400.ms).slideY(
                          begin: 0.3,
                          duration: 400.ms,
                          curve: Curves.easeOutCubic,
                        );
                  },
                ),
              )
            else if (!_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 64,
                        color: Colors.white10,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tell me your mood',
                        style: GoogleFonts.outfit(
                          color: Colors.white30,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
  final ImdbService imdbService;
  final Duration delay;

  const _RecommendationCard({
    required this.recommendation,
    required this.imdbService,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () async {
          // Search for the IMDB ID if not provided
          var item = ImdbSearchResult(
            id: recommendation['imdbId'] ?? '',
            title: recommendation['title'],
            posterUrl: '',
            year: '',
            kind: recommendation['type'] == 'tv' ? 'tvseries' : 'movie',
          );

          if (item.id.isEmpty) {
            // Search IMDB
            final results = await imdbService.search(recommendation['title']);
            if (results.isNotEmpty) {
              item = results.first;
            }
          }

          if (context.mounted) {
            Navigator.push(
              context,
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 500),
                pageBuilder: (_, animation, __) => MediaInfoScreen(item: item),
                transitionsBuilder: (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
              ),
            );
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.borderColor.withValues(alpha: 0.3),
              width: 1,
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
                          recommendation['title'],
                          style: GoogleFonts.outfit(
                            color: Colors.white,
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
                                recommendation['type'].toUpperCase(),
                                style: TextStyle(
                                  color: AppTheme.primaryColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                recommendation['genre'],
                                style: TextStyle(
                                  color: Colors.white54,
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
                  Icon(
                    Icons.auto_awesome_rounded,
                    color: AppTheme.primaryColor,
                    size: 24,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                recommendation['reason'],
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
