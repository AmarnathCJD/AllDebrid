import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/imdb_service.dart';
import '../../services/rivestream_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import '../../theme/app_theme.dart';
import '../torrents/torrent_search_screen.dart';
import '../../services/video_source_service.dart';
import '../player/player_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import 'dart:ui';

import 'package:shimmer/shimmer.dart';
import 'search_page.dart';
import 'package:flutter/services.dart';
import '../../services/kisskh_service.dart';
import '../../services/vidlink_service.dart';
import '../../services/tg_service.dart';
import '../../services/tvmaze_service.dart';
import '../../services/notification_service.dart';
import 'dart:math';
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/helpers.dart';

class MediaInfoScreen extends StatefulWidget {
  final ImdbSearchResult item;

  const MediaInfoScreen({super.key, required this.item});

  @override
  State<MediaInfoScreen> createState() => _MediaInfoScreenState();
}

class _MediaInfoScreenState extends State<MediaInfoScreen> {
  final ImdbService _imdbService = ImdbService();
  final TVMazeService _tvMazeService = TVMazeService();

  late ImdbSearchResult _item;
  RiveStreamMediaDetails? _details;
  bool _isLoading = true;
  int? _selectedSeason = 1;
  int? _selectedEpisode;
  List<RiveStreamEpisode> _episodes = [];
  bool _loadingEpisodes = false;
  bool _loadingVideo = false;
  bool _loadingMovie = false;
  ScrollController? _scrollController;
  List<RiveStreamMedia> _recommendations = [];
  bool _loadingRecommendations = true;
  List<CastMember> _cast = [];
  bool _loadingCast = true;
  bool _overviewExpanded = false;
  TVMazeShowInfo? _tvMazeInfo;
  bool _isReminderSet = false;
  Timer? _scrollDebounceTimer;
  final ValueNotifier<bool> _showTitleNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController!.addListener(_onScroll);
    _item = widget.item;
    _loadDetails();
  }

  void _onScroll() {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 16), () {
      if (_scrollController == null || !_scrollController!.hasClients) return;
      final threshold =
          MediaQuery.of(context).size.height * 0.48 - kToolbarHeight;
      final show = _scrollController!.offset > threshold;
      if (show != _showTitleNotifier.value) {
        _showTitleNotifier.value = show;
      }
    });
  }

  @override
  void dispose() {
    _scrollDebounceTimer?.cancel();
    _showTitleNotifier.dispose();
    _scrollController?.dispose();
    super.dispose();
  }

  ImdbSearchResult _upgradeImageQuality(ImdbSearchResult item) {
    String posterUrl = item.posterUrl;

    if (posterUrl.contains('image.tmdb.org/t/p/')) {
      posterUrl = posterUrl.replaceAllMapped(
        RegExp(r'/t/p/[^/]+/'),
        (match) => '/t/p/original/',
      );
    } else {
      posterUrl = upgradePosterQuality(posterUrl);
    }

    return item.copyWith(posterUrl: posterUrl);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isError
                    ? AppTheme.errorColor.withValues(alpha: 0.1)
                    : AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isError ? Icons.error_rounded : Icons.info_rounded,
                color: isError ? AppTheme.errorColor : AppTheme.primaryColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF18181B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        elevation: 10,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadDetails() async {
    try {
      String id = widget.item.id;
      bool isTmdb = int.tryParse(id) != null;

      if (!isTmdb && id.startsWith('tt')) {
        final riveService = RiveStreamService();
        final tmdbId = await riveService.findTmdbIdFromImdbId(id);
        if (tmdbId != null) {
          id = tmdbId.toString();
          isTmdb = true;
        }
      }

      if (isTmdb) {
        final riveService = RiveStreamService();
        final tmdbIdInt = int.parse(id);

        final cachedDetails = await riveService.getCachedMediaDetails(tmdbIdInt,
            isMovie: widget.item.kind?.toLowerCase() == 'movie' ||
                !widget.item.kind!.toLowerCase().contains('tv'));
        if (cachedDetails != null && mounted) {
          _details = cachedDetails;
          setState(() {
            _isLoading = false;
            _item = _upgradeImageQuality(widget.item.copyWith(
              id: id,
              description: cachedDetails.overview,
              rating: cachedDetails.voteAverage.toStringAsFixed(1),
              year: (cachedDetails.releaseDate != null &&
                      cachedDetails.releaseDate!.isNotEmpty)
                  ? cachedDetails.releaseDate!.split('-').first
                  : (cachedDetails.firstAirDate != null &&
                          cachedDetails.firstAirDate!.isNotEmpty
                      ? cachedDetails.firstAirDate!.split('-').first
                      : widget.item.year),
              backdropUrl: cachedDetails.fullPosterUrl,
              genres: cachedDetails.genres.join(', '),
              duration: cachedDetails.runtime != null
                  ? '${cachedDetails.runtime} min'
                  : null,
              posterUrl: cachedDetails.posterPath != null &&
                      cachedDetails.posterPath!.isNotEmpty
                  ? cachedDetails.ogPosterUrl
                  : _upgradeImageQuality(widget.item).posterUrl,
            ));
          });
        }

        // 2. Load fresh
        var details = await riveService.getMediaDetails(
          tmdbIdInt,
          isMovie: widget.item.kind?.toLowerCase() == 'movie' ||
              !widget.item.kind!.toLowerCase().contains('tv'),
        );

        // Fallback: If direct ID lookup fails (common for MyDramaList IDs), try searching by title + year
        if (details == null && widget.item.title.isNotEmpty) {
          print(
              '[MediaInfo] TMDB 404/Error for ID $tmdbIdInt. Trying title+year search...');
          final isMovie = widget.item.kind?.toLowerCase() == 'movie';
          final foundId = await riveService.findTmdbIdByTitleAndYear(
            widget.item.title,
            widget.item.year,
            isMovie: isMovie,
          );
          if (foundId != null) {
            print('[MediaInfo] Found matching TMDB ID: $foundId via search');
            details =
                await riveService.getMediaDetails(foundId, isMovie: isMovie);
            if (details != null) {
              id = foundId.toString();
            }
          }
        }

        final finalDetails = details;
        if (finalDetails != null && mounted) {
          _details = finalDetails;
          final isTv = _isTvShow;

          setState(() {
            _isLoading = false;
            _item = _upgradeImageQuality(widget.item.copyWith(
              id: id,
              description: finalDetails.overview,
              rating: finalDetails.voteAverage.toStringAsFixed(1),
              year: (finalDetails.releaseDate != null &&
                      finalDetails.releaseDate!.isNotEmpty)
                  ? finalDetails.releaseDate!.split('-').first
                  : (finalDetails.firstAirDate != null &&
                          finalDetails.firstAirDate!.isNotEmpty
                      ? finalDetails.firstAirDate!.split('-').first
                      : widget.item.year),
              backdropUrl: finalDetails.fullPosterUrl,
              genres: finalDetails.genres.join(', '),
              duration: finalDetails.runtime != null
                  ? '${finalDetails.runtime} min'
                  : null,
              posterUrl: finalDetails.posterPath != null &&
                      finalDetails.posterPath!.isNotEmpty
                  ? finalDetails.ogPosterUrl
                  : _upgradeImageQuality(widget.item).posterUrl,
            ));
          });

          Future.delayed(const Duration(milliseconds: 100), () {
            if (isTv) _fetchSeasonEpisodes(1);
          });
          Future.delayed(const Duration(milliseconds: 200), () {
            if (isTv) _fetchTvMazeInfo();
          });
          Future.delayed(const Duration(milliseconds: 300), () {
            _loadRecommendations(id, isTmdb: true, isMovie: !isTv);
          });
          Future.delayed(const Duration(milliseconds: 400), () {
            _loadCast(int.parse(id), isMovie: !isTv);
          });
        }
      } else {
        final details = await _imdbService.fetchDetails(widget.item.id);
        final isTv = _isTvShow;
        if (mounted) {
          setState(() {
            _isLoading = false;
            _item = _upgradeImageQuality(widget.item.copyWith(
              kind: details.kind ?? widget.item.kind,
              rating: widget.item.rating ?? details.rating,
              description: widget.item.description ?? details.description,
              year:
                  widget.item.year.isNotEmpty ? widget.item.year : details.year,
              posterUrl: details.posterUrl.isNotEmpty
                  ? details.posterUrl
                  : _upgradeImageQuality(widget.item).posterUrl,
            ));
          });
          _loadRecommendations(widget.item.id, isTmdb: false, isMovie: !isTv);
          if (isTv) {
            final riveService = RiveStreamService();
            final tmdbId =
                await riveService.findTmdbIdFromImdbId(widget.item.id);
            if (tmdbId != null && mounted) {
              setState(() {
                _item = _item.copyWith(id: tmdbId.toString());
              });
              _fetchSeasonEpisodes(1);
              _fetchTvMazeInfo();
            }
          }
        }
      }
    } catch (e) {
      print('Error loading details: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRecommendations(String id,
      {required bool isTmdb, required bool isMovie}) async {
    try {
      String? imdbId;
      int? tmdbId;
      final riveService = RiveStreamService();

      if (isTmdb) {
        tmdbId = int.tryParse(id);
        if (_details?.imdbId != null && _details!.imdbId!.isNotEmpty) {
          imdbId = _details!.imdbId;
        } else if (tmdbId != null) {
          imdbId =
              await riveService.getImdbIdFromTmdbId(tmdbId, isMovie: isMovie);
        }
      } else {
        imdbId = id;
        tmdbId = await riveService.findTmdbIdFromImdbId(imdbId);
        if (tmdbId == null && _item.title.isNotEmpty) {
          tmdbId = await riveService.findTmdbIdByTitleAndYear(
            _item.title,
            _item.year,
            isMovie: isMovie,
          );
        }
      }

      List<RiveStreamMedia> finalRecs = [];

      if (imdbId != null) {
        final recs = await _imdbService.getRecommendations(imdbId);

        if (recs.isNotEmpty) {
          finalRecs = recs
              .map((e) => RiveStreamMedia(
                    id: 0,
                    title: e.title,
                    posterPath: e.posterUrl,
                    mediaType: isMovie ? 'movie' : 'tv',
                    voteAverage: double.tryParse(e.rating ?? '0') ?? 0.0,
                    releaseDate: e.year.isNotEmpty ? e.year : '',
                    originalTitle: e.id,
                  ))
              .toList();
        }
      }

      // 2. Fallback to TMDB if IMDb failed (AWS WAF 202 issue)
      if (finalRecs.isEmpty && tmdbId != null) {
        print(
            'IMDb recommendations failed or returned empty. Falling back to TMDB...');
        finalRecs =
            await riveService.getRecommendations(tmdbId, isMovie: isMovie);
      }

      if (mounted) {
        setState(() {
          _recommendations = finalRecs;
          _loadingRecommendations = false;
        });
      }
    } catch (e) {
      print('Error loading recommendations: $e');
      if (mounted) setState(() => _loadingRecommendations = false);
    }
  }

  Future<void> _loadCast(int id, {required bool isMovie}) async {
    try {
      final riveService = RiveStreamService();

      // 1. Try cache
      final cachedCast =
          await riveService.getCachedCastAndCrew(id, isMovie: isMovie);
      if (cachedCast.isNotEmpty && mounted) {
        setState(() {
          _cast = (cachedCast['cast'] as List).cast<CastMember>();
          _loadingCast = false;
        });
      }

      // 2. Fetch fresh
      final credits = await riveService.getCastAndCrew(id, isMovie: isMovie);

      if (mounted) {
        setState(() {
          _cast = (credits['cast'] as List).cast<CastMember>();
          _loadingCast = false;
        });
      }
    } catch (e) {
      print('Error loading cast: $e');
      if (mounted) setState(() => _loadingCast = false);
    }
  }

  bool get _isTvShow {
    final kind = _item.kind?.toLowerCase();
    return kind == 'tv' ||
        kind == 'series' ||
        kind == 'tvseries' ||
        kind == 'tv series' ||
        kind == 'tvepisode' ||
        kind == 'tvshow' ||
        kind?.contains('tv') == true;
  }

  Future<void> _playTrailer() async {
    String? videoId = _item.videoId;
    if (videoId == null || videoId.isEmpty) {
      String? imdbId = _details?.imdbId;
      if (imdbId == null && _item.id.startsWith('tt')) {
        imdbId = _item.id;
      }

      if (imdbId == null) {
        final riveService = RiveStreamService();
        final tmdbId = int.tryParse(_item.id);
        if (tmdbId != null) {
          imdbId = await riveService.getImdbIdFromTmdbId(tmdbId,
              isMovie: !_isTvShow);
        }
      }

      if (imdbId != null) {
        try {
          final details = await _imdbService.fetchDetails(imdbId);
          videoId = details.videoId;
          if (videoId == null || videoId.isEmpty) {
            videoId = await _imdbService.findTrailerVideoId(imdbId);
          }
        } catch (e) {}
      }
    }

    if (videoId != null && videoId.isNotEmpty) {
      if (mounted) {
        final url = await _imdbService.fetchTrailerStreamUrl(videoId);
        if (url != null && mounted) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlayerScreen(
                url: url,
                title: '${_item.title} - Trailer',
              ),
            ),
          );

          // Reset to portrait after coming back
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
          return;
        }
      }
    }

    if (mounted) {
      _showSnackBar('No trailer found', isError: true);
    }
  }

  Future<void> _shareMedia() async {
    final title = _item.title;
    final year = _item.year;
    final rating = _item.rating ?? 'N/A';
    final overview = _item.description ?? '';
    final url =
        'https://www.themoviedb.org/${_isTvShow ? 'tv' : 'movie'}/${_item.id}';

    final text = 'Check out $title ($year)\n'
        'Rating: $rating/10\n\n'
        '$overview\n\n'
        'View more: $url';

    XFile? posterFile;
    try {
      final posterUrl = _item.posterUrl;
      if (posterUrl.isNotEmpty) {
        final dio = Dio();
        final response = await dio.get<Uint8List>(
          posterUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        if (response.statusCode == 200 && response.data != null) {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/share_poster.jpg');
          await file.writeAsBytes(response.data!);
          posterFile = XFile(file.path, mimeType: 'image/jpeg');
        }
      }
    } catch (_) {}

    if (posterFile != null) {
      SharePlus.instance.share(ShareParams(
        files: [posterFile],
        text: text,
        title: title,
      ));
      final pathToDelete = posterFile.path;
      Future.delayed(const Duration(seconds: 60), () {
        try {
          final f = File(pathToDelete);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      });
    } else {
      SharePlus.instance.share(ShareParams(
        text: text,
        title: title,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            cacheExtent: 150,
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Container(
                  color: AppTheme.backgroundColor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildHeaderContent(),
                        const SizedBox(height: 20),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.05),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: _isLoading
                              ? Column(
                                  key: const ValueKey('loading_overview'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildShimmerBlock(
                                        width: double.infinity, height: 14),
                                    const SizedBox(height: 8),
                                    _buildShimmerBlock(
                                        width: double.infinity, height: 14),
                                    const SizedBox(height: 8),
                                    _buildShimmerBlock(width: 200, height: 14),
                                  ],
                                )
                              : _buildOverview(),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 450),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                          child: _isLoading
                              ? Padding(
                                  key: const ValueKey('loading_sections'),
                                  padding: const EdgeInsets.only(top: 24),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildShimmerBlock(
                                          width: 150, height: 20),
                                      const SizedBox(height: 12),
                                      _buildShimmerBlock(
                                          width: 170, height: 50),
                                      const SizedBox(height: 24),
                                      Row(
                                        children: [
                                          _buildShimmerBlock(
                                              width: 120, height: 80),
                                          const SizedBox(width: 12),
                                          _buildShimmerBlock(
                                              width: 120, height: 80),
                                        ],
                                      ),
                                    ],
                                  ),
                                )
                              : RepaintBoundary(
                                  child: Column(
                                    key: const ValueKey('loaded_sections'),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_isTvShow) ...[
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 24, bottom: 8),
                                          child: Text(
                                            '${_details?.numberOfSeasons ?? 0} Seasons • ${_details?.numberOfEpisodes ?? 0} Episodes • ${_details?.status ?? 'N/A'}',
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.3),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                        _buildNextEpisodeBanner(),
                                        _buildTvSelector(),
                                        const SizedBox(height: 24),
                                        _buildDetailedInfo(),
                                      ] else ...[
                                        const SizedBox(height: 24),
                                        _buildDetailedInfo(),
                                      ],
                                    ],
                                  ),
                                ),
                        ),
                        const SizedBox(height: 24),
                        _buildCast(),
                        const SizedBox(height: 24),
                        _buildRecommendations(),
                        const SizedBox(height: 24),
                        _buildInfoCards(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.48,
      pinned: true,
      backgroundColor: AppTheme.backgroundColor,
      elevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      title: ValueListenableBuilder<bool>(
        valueListenable: _showTitleNotifier,
        builder: (context, show, child) {
          return AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: show ? 1.0 : 0.0,
            child: Text(
              _item.title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                shadows: [
                  const Shadow(blurRadius: 10, color: Colors.black45),
                ],
              ),
            ),
          );
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'media_${_item.id}',
              child: CachedNetworkImage(
                imageUrl: _item.posterUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (context, url) => Container(
                  color: AppTheme.cardColor,
                  child: const Center(
                    child: CreativeLoadingSpinner(
                      size: 50,
                      color: Color(0xFFE8A634),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppTheme.cardColor,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: AppTheme.textMuted,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    AppTheme.backgroundColor.withValues(alpha: 0.6),
                    AppTheme.backgroundColor,
                  ],
                  stops: const [0.0, 0.4, 0.8, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tagline - fixed space, just hide shimmer when no tagline
        SizedBox(
          height: 35,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isLoading
                ? 0.5
                : (_details?.tagline != null && _details!.tagline!.isNotEmpty
                    ? 1.0
                    : 0.0),
            child: _isLoading
                ? _buildShimmerBlock(width: 140, height: 14)
                : (_details?.tagline != null && _details!.tagline!.isNotEmpty)
                    ? Text(
                        _details!.tagline!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: AppTheme.primaryColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .5,
                          height: 1.3,
                        ),
                      )
                    : SizedBox.shrink(),
          ),
        ),
        // Rating and Year
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: _buildStarRating(double.tryParse(_item.rating!) ?? 0),
            ),
            const SizedBox(width: 8),
            Text(
              _item.rating!,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 1.5,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _item.year,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Title
        Text(
          _item.title,
          style: GoogleFonts.sora(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
            height: 1.0,
            shadows: [
              Shadow(
                color: Colors.black54,
                offset: const Offset(0, 4),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Compact Metadata Row & Action Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  if (_item.genres != null && _item.genres!.isNotEmpty) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: _showGenresDialog,
                        behavior: HitTestBehavior.opaque,
                        child: Tooltip(
                          message: 'View all genres',
                          child: Text(
                            _item.genres!.split(',').take(3).join(' • '),
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_item.duration != null) ...[
                    _buildMetaSeparator(),
                    Text(
                      _item.duration!,
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _shareMedia,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Icon(Icons.share_rounded,
                        color: AppTheme.successColor.withValues(alpha: 0.8),
                        size: 20),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TorrentSearchScreen(
                          initialQuery: _getSearchQuery(),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_rounded,
                            color: AppTheme.primaryColor, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'SEARCH',
                          style: GoogleFonts.outfit(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            final provider = context.watch<AppProvider>();
            bool isResumable = false;
            String playLabel = 'PLAY';
            String? topLabel;
            int s = 1;
            int e = 1;

            if (_isTvShow) {
              final next = _findNextEpisode(provider);
              s = next['season']!;
              e = next['episode']!;
              final key = 'pos_tmdb_${widget.item.id}_s${s}_e${e}';
              final savedPos = provider.getSetting<int>(key) ?? 0;

              isResumable = savedPos > 0;
              playLabel = 'S$s · E$e';
              if (isResumable) {
                topLabel = 'CONTINUE WATCHING';
              }
            } else {
              final key = 'pos_tmdb_${widget.item.id}';
              final savedPos = provider.getSetting<int>(key) ?? 0;
              final runtimeMin = _details?.runtime ?? 120;
              final totalMs = runtimeMin * 60 * 1000;
              isResumable = savedPos > 0 && savedPos < (totalMs * 0.95);
              playLabel = isResumable ? 'RESUME' : 'PLAY';

              if (isResumable) {
                final remainMin = ((totalMs - savedPos) / 60000).ceil();
                topLabel = 'RESUME • $remainMin MIN LEFT';
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (topLabel != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      topLabel,
                      style: GoogleFonts.outfit(
                        color: AppTheme.primaryColor.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: ElevatedButton.icon(
                        onPressed: (_loadingMovie || _loadingVideo)
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                _handlePlayAction(s, e);
                              },
                        icon: (_loadingMovie || _loadingVideo)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black))
                            : const Icon(Icons.play_arrow_rounded,
                                color: Colors.black, size: 24),
                        label: Text(
                          (_loadingMovie || _loadingVideo)
                              ? 'OPENING...'
                              : playLabel,
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.2,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isResumable
                              ? Colors.white
                              : AppTheme.primaryColor,
                          fixedSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideX(
                          begin: -0.1, end: 0, curve: Curves.easeOutBack),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.02)),
                      ),
                      child: IconButton(
                        onPressed: _playTrailer,
                        icon: const Icon(Icons.movie_filter_rounded,
                            color: Colors.white, size: 22),
                        tooltip: 'Watch Trailer',
                      ),
                    ),
                    const SizedBox(width: 8),
                    _NetflixLikeRatingButton(mediaId: _item.id),
                    const SizedBox(width: 8),
                    Builder(
                      builder: (context) {
                        final provider = context.watch<AppProvider>();
                        final isWatchlisted = provider.isInWatchlist(_item.id);

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 54,
                          width: 54,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.02)),
                          ),
                          child: IconButton(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              provider.toggleWatchlist(_item);
                            },
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                isWatchlisted
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                key: ValueKey(isWatchlisted),
                                color: isWatchlisted
                                    ? AppTheme.primaryColor
                                    : Colors.white,
                                size: 24,
                              ),
                            ),
                            tooltip: isWatchlisted
                                ? 'Remove from Watchlist'
                                : 'Add to Watchlist',
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildOverview() {
    final description = _item.description;
    if (description == null || description.isEmpty) {
      return const SizedBox.shrink();
    }

    final isLong = description.length > 200;

    return GestureDetector(
      onTap: isLong
          ? () => setState(() => _overviewExpanded = !_overviewExpanded)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _overviewExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(
              isLong ? '${description.substring(0, 200)}...' : description,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13.5,
                height: 1.7,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.05,
              ),
            ),
            secondChild: Text(
              description,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13.5,
                height: 1.7,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.05,
              ),
            ),
          ),
          if (isLong)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Text(
                    _overviewExpanded ? 'Show Less' : 'Read More',
                    style: GoogleFonts.outfit(
                      color: AppTheme.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _overviewExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 14, color: AppTheme.primaryColor),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTvSelector() {
    if (_details?.numberOfSeasons == null || _details!.numberOfSeasons == 0) {
      return const SizedBox.shrink();
    }

    final seasonsCount = _details!.numberOfSeasons!;
    final items = List.generate(seasonsCount, (i) => i + 1);

    // Ensure _selectedSeason is valid for the items list
    final initialSeason =
        items.contains(_selectedSeason) ? _selectedSeason : items.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 170,
              child: CustomDropdown<int>(
                items: items,
                initialItem: initialSeason,
                itemsListPadding: const EdgeInsets.symmetric(vertical: 8),
                listItemPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                closedHeaderPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                onChanged: (val) {
                  if (val != null && val != _selectedSeason) {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _selectedSeason = val;
                      _selectedEpisode = null;
                    });
                    _fetchSeasonEpisodes(val);
                  }
                },
                headerBuilder: (context, selectedItem, enabled) {
                  return Text(
                    'SEASON $selectedItem',
                    style: GoogleFonts.outfit(
                      color: AppTheme.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  );
                },
                listItemBuilder: (context, item, isSelected, onItemSelect) {
                  return Text(
                    'Season $item',
                    style: GoogleFonts.outfit(
                      color: isSelected ? AppTheme.primaryColor : Colors.white,
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  );
                },
                decoration: CustomDropdownDecoration(
                  closedFillColor: Colors.transparent,
                  expandedFillColor: AppTheme.backgroundColor,
                  closedSuffixIcon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.primaryColor, size: 20),
                  expandedSuffixIcon: Icon(Icons.keyboard_arrow_up_rounded,
                      color: AppTheme.primaryColor, size: 20),
                  listItemDecoration: const ListItemDecoration(
                    selectedColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                ),
              ),
            ),
            Builder(
              builder: (context) {
                final provider = context.watch<AppProvider>();
                final defProv =
                    provider.getSetting<String>('default_tv_provider');

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PopupMenuButton<String>(
                      initialValue: defProv,
                      tooltip: 'Select Default Provider',
                      color: AppTheme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      onSelected: (val) {
                        provider.saveSetting(
                            'default_tv_provider', val == 'None' ? null : val);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'None',
                          child: Row(
                            children: [
                              Icon(Icons.help_outline_rounded,
                                  size: 16, color: Colors.white70),
                              SizedBox(width: 8),
                              Text('Always Ask',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(height: 4),
                        const PopupMenuItem(
                          value: 'River',
                          child: Row(
                            children: [
                              Icon(Icons.play_circle_outline_rounded,
                                  size: 16, color: Color(0xFFE8A634)),
                              SizedBox(width: 8),
                              Text('River',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'KissKh',
                          child: Row(
                            children: [
                              Icon(Icons.play_circle_outline_rounded,
                                  size: 16, color: Color(0xFFE8A634)),
                              SizedBox(width: 8),
                              Text('KissKh',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'VidLink',
                          child: Row(
                            children: [
                              Icon(Icons.play_circle_outline_rounded,
                                  size: 16, color: Color(0xFFE8A634)),
                              SizedBox(width: 8),
                              Text('VidLink',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'VidEasy',
                          child: Row(
                            children: [
                              Icon(Icons.play_circle_outline_rounded,
                                  size: 16, color: Color(0xFFE8A634)),
                              SizedBox(width: 8),
                              Text('VidEasy',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'TG',
                          child: Row(
                            children: [
                              Icon(Icons.play_circle_outline_rounded,
                                  size: 16, color: Color(0xFFE8A634)),
                              SizedBox(width: 8),
                              Text('Telegram',
                                  style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.play_circle_outline_rounded,
                                size: 18,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              defProv ?? 'Provider',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.expand_more_rounded,
                              size: 16,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        if (!_loadingEpisodes && _episodes.isNotEmpty)
          Builder(
            builder: (context) {
              final provider = context.watch<AppProvider>();
              int watchedCount = 0;

              for (final episode in _episodes) {
                final key =
                    'pos_tmdb_${widget.item.id}_s${episode.seasonNumber}_e${episode.episodeNumber}';
                final savedPos = provider.getSetting<int>(key) ?? 0;
                final runtimeMin = _details?.runtime ?? 45;
                final totalMs = runtimeMin * 60 * 1000;
                final progress = (savedPos / totalMs).clamp(0.0, 1.0);
                if (progress > 0.4) watchedCount++;
              }
              final totalEpisodes = _episodes.length;

              return Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 0, top: 16),
                child: Text(
                  '$watchedCount / $totalEpisodes EP',
                  style: GoogleFonts.outfit(
                    color: AppTheme.primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              );
            },
          ),
        if (_loadingEpisodes)
          Shimmer.fromColors(
            baseColor: Colors.white.withValues(alpha: 0.05),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(top: 4, bottom: 24),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, __) => Row(
                children: [
                  Container(
                    width: 120,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 150,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else ...[
          ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _episodes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final episode = _episodes[index];
              final provider = context.watch<AppProvider>();
              final key =
                  'pos_tmdb_${widget.item.id}_s${episode.seasonNumber}_e${episode.episodeNumber}';
              final savedPos = provider.getSetting<int>(key) ?? 0;
              final runtimeMin = _details?.runtime ?? 45;
              final totalMs = runtimeMin * 60 * 1000;
              final progress = (savedPos / totalMs).clamp(0.0, 1.0);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final defProv =
                          provider.getSetting<String>('default_tv_provider');
                      if (defProv != null &&
                          defProv.isNotEmpty &&
                          defProv != 'None') {
                        if (defProv == 'TG') {
                          _playTg(
                              episode: episode,
                              seasonNumber: _selectedSeason,
                              episodeNumber: episode.episodeNumber);
                        } else {
                          _playMovie(
                              provider: defProv,
                              episode: episode,
                              seasonNumber: _selectedSeason,
                              episodeNumber: episode.episodeNumber);
                        }
                      } else {
                        _showEpisodeDetails(episode);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.only(
                          right: 8, bottom: 0, top: 0, left: 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Thumbnail with play button
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              bottomLeft: Radius.circular(10),
                            ),
                            child: SizedBox(
                              width: 120,
                              height: 68,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CachedNetworkImage(
                                      imageUrl: episode.fullStillUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: AppTheme.cardColor,
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: AppTheme.cardColor,
                                        child: const Icon(Icons.movie,
                                            color: Colors.white24),
                                      ),
                                    ),
                                  ),
                                  // Gradient overlay
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            Colors.black.withValues(alpha: 0.0),
                                            Colors.black.withValues(alpha: 0.2),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Progress bar
                                  if (savedPos > 0)
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 2,
                                        backgroundColor:
                                            Colors.white.withValues(alpha: 0.1),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          progress > 0.9
                                              ? Colors.green
                                              : AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                  // Play button
                                  Center(
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.play_arrow_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Episode info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Episode number and rating
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'E${episode.episodeNumber}',
                                        style: TextStyle(
                                          color: AppTheme.primaryColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10,
                                          fontFamily: 'RobotoMono',
                                        ),
                                      ),
                                    ),
                                    if (progress > 0.9)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Icon(Icons.check_circle_rounded,
                                            size: 14, color: Colors.green),
                                      ),
                                    if (episode.voteAverage > 0) ...[
                                      const Spacer(),
                                      const Icon(Icons.star_rounded,
                                          size: 12, color: Colors.amber),
                                      const SizedBox(width: 3),
                                      Text(
                                        episode.voteAverage.toStringAsFixed(1),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Episode name
                                Text(
                                  episode.name ??
                                      'Episode ${episode.episodeNumber}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (episode.airDate != null &&
                                    episode.airDate!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    _formatFriendlyDate(episode.airDate),
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.45),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  String _formatFriendlyDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);
      final isFuture = date.isAfter(now);

      String formattedDate = DateFormat('MMM d, yyyy').format(date);
      String relative;

      if (isFuture) {
        final days = date.difference(now).inDays;
        if (days == 0) {
          relative = 'today';
        } else if (days == 1) {
          relative = 'tomorrow';
        } else {
          relative = 'in $days days';
        }
      } else {
        if (difference.inDays == 0) {
          relative = 'today';
        } else if (difference.inDays == 1) {
          relative = 'yesterday';
        } else if (difference.inDays < 30) {
          relative = '${difference.inDays} days ago';
        } else if (difference.inDays < 365) {
          final months = (difference.inDays / 30).floor();
          relative = '$months ${months == 1 ? 'month' : 'months'} ago';
        } else {
          final years = (difference.inDays / 365).floor();
          relative = '$years ${years == 1 ? 'year' : 'years'} ago';
        }
      }

      return '$formattedDate ($relative)';
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _fetchSeasonEpisodes(int season) async {
    if (!mounted) return;

    final riveService = RiveStreamService();
    final tmdbId = int.tryParse(_item.id);
    if (tmdbId == null) return;

    // 1. Load from cache first
    final cachedEpisodes =
        await riveService.getCachedSeasonDetails(tmdbId, season);
    if (cachedEpisodes.isNotEmpty && mounted) {
      setState(() {
        _episodes = cachedEpisodes;
        _loadingEpisodes = false;
      });
    } else {
      // Only show loading if we don't have any episodes yet (cache was empty)
      if (_episodes.isEmpty) {
        setState(() => _loadingEpisodes = true);
      }
    }

    // 2. Load fresh
    try {
      final episodes = await riveService.getSeasonDetails(tmdbId, season);
      if (mounted) {
        setState(() {
          _episodes = episodes;
          _loadingEpisodes = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingEpisodes = false);
    }
  }

  Future<void> _fetchTvMazeInfo() async {
    try {
      final title = _item.title;
      final info = await _tvMazeService.getShowInfo(title);
      if (mounted && info != null) {
        bool reminderSet = false;
        if (info.nextEpisode != null) {
          reminderSet =
              await NotificationService().isReminderSet(info.nextEpisode!.id);
        }
        setState(() {
          _tvMazeInfo = info;
          _isReminderSet = reminderSet;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleEpisodeReminder(TVMazeNextEpisode nextEp) async {
    final notificationService = NotificationService();
    final isSet = await notificationService.isReminderSet(nextEp.id);

    if (isSet) {
      await notificationService.cancelReminder(nextEp.id);
      _showSnackBar('Reminder removed');
    } else {
      final airDate = nextEp.airDateTime;
      if (airDate != null) {
        // Schedule reminder for the air date
        await notificationService.scheduleEpisodeReminder(
          id: nextEp.id,
          title: 'Next Episode: ${_item.title}',
          body:
              'S${nextEp.season}E${nextEp.number} - ${nextEp.name} is airing now!',
          scheduledDate: airDate,
          payload:
              '{"id": "${_item.id}", "type": "${_item.kind}", "title": "${_item.title}"}',
        );
        _showSnackBar('Reminder set for upcoming episode');
      } else {
        _showSnackBar('Cannot set reminder: Air date unknown', isError: true);
      }
    }

    final updatedIsSet = await notificationService.isReminderSet(nextEp.id);
    if (mounted) {
      setState(() => _isReminderSet = updatedIsSet);
    }
  }

  Widget _buildNextEpisodeBanner() {
    final info = _tvMazeInfo;
    if (info == null || !info.isOngoing) return const SizedBox.shrink();

    final nextEp = info.nextEpisode;
    if (nextEp == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppTheme.successColor,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Currently Airing',
                  style: GoogleFonts.outfit(
                    color: AppTheme.successColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                if (info.show.network != null)
                  Text(
                    info.show.network!,
                    style: GoogleFonts.outfit(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
    }

    final timeUntil = nextEp.timeUntilAir;
    final isAiring = timeUntil != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            child: Icon(
              isAiring ? Icons.schedule_rounded : Icons.live_tv_rounded,
              color: AppTheme.primaryColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      nextEp.episodeLabel,
                      style: GoogleFonts.outfit(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        nextEp.name ?? 'Upcoming Episode',
                        style: GoogleFonts.outfit(
                          color: AppTheme.textPrimary.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                _EpisodeCountdownText(nextEpisode: nextEp),
              ],
            ),
          ),
          if (isAiring) ...[
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _toggleEpisodeReminder(nextEp),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _isReminderSet
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    color:
                        _isReminderSet ? AppTheme.primaryColor : Colors.white24,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.05, end: 0);
  }

  Widget _buildDetailedInfo() {
    return const SizedBox.shrink();
  }

  Widget _buildInfoCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('INFORMATION', 'Details & facts'),
        const SizedBox(height: 8),
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            children: [
              if (_item.duration != null && _item.duration!.isNotEmpty)
                _buildInfoCard(
                    'Duration', Icons.schedule_rounded, _item.duration!),
              _buildReleaseDateCard(),
              _buildInfoCard('Language', Icons.language_rounded,
                  _details?.spokenLanguages.join(', ') ?? 'N/A'),
              _buildInfoCard('Country', Icons.public_rounded,
                  _details?.productionCountries.join(', ') ?? 'N/A'),
              _buildReleaseStatusCard(),
              if (_details?.productionCompanies.isNotEmpty ?? false)
                _buildInfoCard('Studio', Icons.business_rounded,
                    _details!.productionCompanies.first),
              if (_details?.budget != null && _details!.budget! > 0)
                _buildBudgetCard(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReleaseDateCard() {
    final releaseDate =
        _details?.releaseDate ?? _details?.firstAirDate ?? _item.year;
    String displayDate = 'N/A';

    if (releaseDate.isNotEmpty) {
      try {
        final date = DateTime.parse(releaseDate);
        displayDate = DateFormat('MMM dd, yyyy').format(date);
      } catch (e) {
        displayDate = releaseDate;
      }
    }

    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      width: 140,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'RELEASED',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            displayDate,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard() {
    final budget = _details?.budget ?? 0;
    String displayBudget = 'N/A';

    if (budget > 0) {
      if (budget >= 1000000) {
        displayBudget = '\$${(budget / 1000000).toStringAsFixed(1)}M';
      } else if (budget >= 1000) {
        displayBudget = '\$${(budget / 1000).toStringAsFixed(0)}K';
      } else {
        displayBudget = '\$$budget';
      }
    }

    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      width: 140,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money_rounded, size: 18, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'BUDGET',
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            displayBudget,
            style: GoogleFonts.outfit(
              color: Colors.greenAccent,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildReleaseStatusCard() {
    // Determine if released based on date
    bool isReleased = false;
    String statusText = 'N/A';
    IconData statusIcon = Icons.help_outline_rounded;
    Color statusColor = Colors.white;

    if (_details != null) {
      final releaseDate = _details!.releaseDate ?? _details!.firstAirDate;

      if (releaseDate != null && releaseDate.isNotEmpty) {
        try {
          final releaseDateParsed = DateTime.parse(releaseDate);
          final now = DateTime.now();
          isReleased = releaseDateParsed.isBefore(now) ||
              releaseDateParsed.isAtSameMomentAs(now);

          if (isReleased) {
            statusText = _details!.status ?? 'Released';
            statusIcon = Icons.check_circle_rounded;
            statusColor = Colors.green;
          } else {
            statusText = 'Upcoming';
            statusIcon = Icons.calendar_today_rounded;
            statusColor = Colors.orange;
          }
        } catch (e) {
          statusText = _details!.status ?? 'N/A';
        }
      } else {
        statusText = _details!.status ?? 'N/A';
      }
    }

    return _buildInfoCard('Status', statusIcon, statusText, color: statusColor);
  }

  Widget _buildInfoCard(String label, IconData icon, String value,
      {Color? color}) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      width: 140,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color ?? AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: color ?? Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCast() {
    if (_cast.isEmpty && !_loadingCast) return const SizedBox.shrink();

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('CAST', 'Starring'),
          SizedBox(
            height: 140,
            child: _loadingCast
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 5,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (_, __) => Column(
                      children: [
                        Shimmer.fromColors(
                          baseColor: Colors.white.withValues(alpha: 0.05),
                          highlightColor: Colors.white.withValues(alpha: 0.1),
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Shimmer.fromColors(
                          baseColor: Colors.white.withValues(alpha: 0.05),
                          highlightColor: Colors.white.withValues(alpha: 0.1),
                          child: Container(
                            width: 90,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemCount: _cast.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final member = _cast[index];
                      final delay = (index * 50).clamp(0, 500);
                      return Animate(
                        effects: [
                          FadeEffect(duration: 400.ms, delay: delay.ms),
                          SlideEffect(
                            begin: const Offset(0.2, 0),
                            duration: 400.ms,
                            delay: delay.ms,
                            curve: Curves.easeOutQuad,
                          ),
                        ],
                        child: GestureDetector(
                          onTap: () => _showCastModal(member),
                          child: SizedBox(
                            width: 90,
                            child: Column(
                              children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.15),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: member.fullProfileUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: member.fullProfileUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(
                                              color: Colors.white
                                                  .withValues(alpha: 0.05),
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                              color: Colors.white
                                                  .withValues(alpha: 0.05),
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white
                                                    .withValues(alpha: 0.3),
                                                size: 40,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.white
                                                .withValues(alpha: 0.05),
                                            child: Icon(
                                              Icons.person,
                                              color: Colors.white
                                                  .withValues(alpha: 0.3),
                                              size: 40,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  member.name,
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                ),
                                if (member.character != null) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    member.character!,
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showCastModal(CastMember member) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, animation, secondaryAnimation) =>
            _CastDetailView(member: member),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecommendations() {
    if (_recommendations.isEmpty && !_loadingRecommendations) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('MORE LIKE THIS', 'Similar titles'),
          SizedBox(
            height: 230,
            child: _loadingRecommendations
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 4,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, __) => Shimmer.fromColors(
                      baseColor: Colors.white.withValues(alpha: 0.05),
                      highlightColor: Colors.white.withValues(alpha: 0.1),
                      child: Container(
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    itemCount: _recommendations.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final media = _recommendations[index];
                      return InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          final navId =
                              (media.id == 0 && media.originalTitle != null)
                                  ? media.originalTitle!
                                  : media.id.toString();

                          Navigator.push(
                            context,
                            PageRouteBuilder(
                              transitionDuration:
                                  const Duration(milliseconds: 500),
                              reverseTransitionDuration:
                                  const Duration(milliseconds: 400),
                              pageBuilder:
                                  (context, animation, secondaryAnimation) =>
                                      MediaInfoScreen(
                                item: ImdbSearchResult(
                                  id: navId,
                                  title: media.displayTitle,
                                  year: media.displayDate.isNotEmpty
                                      ? media.displayDate.split('-').first
                                      : '',
                                  posterUrl:
                                      upgradePosterQuality(media.fullPosterUrl),
                                  kind: media.mediaType == 'movie'
                                      ? 'movie'
                                      : 'tv',
                                  rating: media.voteAverage.toStringAsFixed(1),
                                  description: media.overview,
                                  backdropUrl: media.fullBackdropUrl,
                                ),
                              ),
                              transitionsBuilder: (context, animation,
                                  secondaryAnimation, child) {
                                final curved = CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                );
                                return FadeTransition(
                                  opacity: curved,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.0, 0.05),
                                      end: Offset.zero,
                                    ).animate(curved),
                                    child: child,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
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
                                blurRadius: 6,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AspectRatio(
                                aspectRatio: 2 / 3,
                                child: CachedNetworkImage(
                                  imageUrl: media.fullPosterUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (_, __) => Container(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    child: Icon(
                                      Icons.movie,
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 49,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          media.displayTitle,
                                          maxLines: 1,
                                          textAlign: TextAlign.start,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        media.displayDate.isNotEmpty
                                            ? media.displayDate.split('-').first
                                            : 'N/A',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
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
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _getSearchQuery() {
    if (_isTvShow && _selectedSeason != null && _selectedEpisode != null) {
      return '${_item.title} S${_selectedSeason.toString().padLeft(2, '0')}E${_selectedEpisode.toString().padLeft(2, '0')}';
    }
    return '${_item.title} ${_item.year}'.trim();
  }

  void _showEpisodeDetails(RiveStreamEpisode episode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bool isLoading = _loadingVideo;
            final provider = Provider.of<AppProvider>(context);
            final key =
                'pos_tmdb_${widget.item.id}_s${episode.seasonNumber}_e${episode.episodeNumber}';
            final savedPos = provider.getSetting<int>(key) ?? 0;
            final runtimeMin = _details?.runtime ?? 45;
            final totalMs = runtimeMin * 60 * 1000;
            final isResumable = savedPos > 0 && savedPos < (totalMs * 0.95);
            final remainMin = ((totalMs - savedPos) / 60000).ceil();

            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: MediaQuery.of(context).orientation ==
                          Orientation.landscape
                      ? MediaQuery.of(context).size.height * 0.7
                      : MediaQuery.of(context).size.height * 0.45,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor
                        .withValues(alpha: 0.95), // Slightly more opaque
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Compact Header: Thumbnail + Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 140,
                              height: 80,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (episode.stillPath != null)
                                    CachedNetworkImage(
                                      imageUrl: episode.fullStillUrl,
                                      fit: BoxFit.cover,
                                    )
                                  else
                                    Container(color: Colors.white10),
                                  // Progress Overlay
                                  if (savedPos > 0)
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: LinearProgressIndicator(
                                        value: (savedPos / totalMs)
                                            .clamp(0.0, 1.0),
                                        backgroundColor: Colors.transparent,
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                Colors.red),
                                        minHeight: 3,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'S${episode.seasonNumber} • E${episode.episodeNumber}',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (episode.voteAverage > 0) ...[
                                      const SizedBox(width: 8),
                                      Icon(Icons.star_rounded,
                                          size: 14, color: Colors.amber),
                                      const SizedBox(width: 2),
                                      Text(
                                        episode.voteAverage.toStringAsFixed(1),
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  episode.name ?? 'Untitled',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      const SizedBox(height: 12),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => _showSourceSelector(
                            episode: episode,
                            setSheetState: setSheetState,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isResumable
                                ? Colors.white
                                : AppTheme.primaryColor,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.black),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isResumable
                                          ? Icons.play_arrow_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.black,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isResumable ? 'RESUME' : 'PLAY',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    if (isResumable) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '(${remainMin}m left)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black
                                              .withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Overview
                      Expanded(
                        child: RawScrollbar(
                          thumbColor: Colors.white24,
                          radius: const Radius.circular(2),
                          thickness: 3,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'OVERVIEW',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  (episode.overview == null ||
                                          episode.overview!.isEmpty)
                                      ? 'No overview available.'
                                      : episode.overview!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                    height: 1.5,
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
          },
        );
      },
    );
  }

  void _showSourceSelector(
      {RiveStreamEpisode? episode,
      int? seasonNumber,
      int? episodeNumber,
      StateSetter? setSheetState}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'SELECT PROVIDER',
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            // First Row
            Row(
              children: [
                Expanded(
                  child: _buildSourceOption(
                    'River',
                    () => _playMovie(
                        provider: 'River',
                        episode: episode,
                        seasonNumber: seasonNumber,
                        episodeNumber: episodeNumber,
                        setSheetState: setSheetState),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSourceOption(
                    'KissKh',
                    () => _playMovie(
                        provider: 'KissKh',
                        episode: episode,
                        seasonNumber: seasonNumber,
                        episodeNumber: episodeNumber,
                        setSheetState: setSheetState),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Second Row
            Row(
              children: [
                Expanded(
                  child: _buildSourceOption(
                    'VidLink',
                    () => _playMovie(
                        provider: 'VidLink',
                        episode: episode,
                        seasonNumber: seasonNumber,
                        episodeNumber: episodeNumber,
                        setSheetState: setSheetState),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSourceOption(
                    'VidEasy',
                    () => _playMovie(
                        provider: 'VidEasy',
                        episode: episode,
                        seasonNumber: seasonNumber,
                        episodeNumber: episodeNumber,
                        setSheetState: setSheetState),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSourceOption(
                    'TG',
                    () => _playTg(
                        episode: episode,
                        seasonNumber: seasonNumber,
                        episodeNumber: episodeNumber,
                        setSheetState: setSheetState),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playTg({
    RiveStreamEpisode? episode,
    int? seasonNumber,
    int? episodeNumber,
    StateSetter? setSheetState,
  }) async {
    RiveStreamEpisode? actualEpisode = episode;
    if (actualEpisode == null &&
        seasonNumber != null &&
        episodeNumber != null) {
      try {
        final episodes = await RiveStreamService()
            .getSeasonDetails(int.parse(_item.id), seasonNumber);
        actualEpisode = episodes.firstWhere(
            (ep) => ep.episodeNumber == episodeNumber,
            orElse: () => episodes.first);
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error fetching episode: $e', isError: true);
        }
        return;
      }
    }

    final bool isTv = actualEpisode != null;

    String? imdbId = _details?.imdbId;
    if ((imdbId == null || imdbId.isEmpty) && _item.id.startsWith('tt')) {
      imdbId = _item.id;
    }
    final tmdbIdInt = int.tryParse(_item.id);
    if (imdbId == null || imdbId.isEmpty) {
      if (tmdbIdInt != null) {
        imdbId = await RiveStreamService()
            .getImdbIdFromTmdbId(tmdbIdInt, isMovie: !isTv);
      }
    }

    if ((imdbId == null || imdbId.isEmpty) && !isTv && tmdbIdInt == null) {
      if (mounted) {
        _showSnackBar('Could not resolve ID for TG', isError: true);
      }
      return;
    }

    if (isTv && (imdbId == null || imdbId.isEmpty)) {
      if (mounted) {
        _showSnackBar('Could not resolve IMDb ID for TV show', isError: true);
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      isScrollControlled: true,
      builder: (ctx) => _TgFlowSheet(
        imdbId: imdbId ?? '',
        isTv: isTv,
        season: isTv ? actualEpisode!.seasonNumber : null,
        episode: isTv ? actualEpisode!.episodeNumber : null,
        title: isTv
            ? '${widget.item.title} - S${actualEpisode!.seasonNumber}E${actualEpisode.episodeNumber}'
            : widget.item.title,
        tmdbId: int.tryParse(_item.id),
        mediaItem: widget.item,
      ),
    );
  }

  Widget _buildSourceOption(String name, VoidCallback onTap) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Center(
            child: Text(
              name,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _playMovie(
      {String? provider,
      RiveStreamEpisode? episode,
      int? seasonNumber,
      int? episodeNumber,
      StateSetter? setSheetState}) async {
    HapticFeedback.lightImpact();
    RiveStreamEpisode? actualEpisode = episode;
    if (actualEpisode == null &&
        seasonNumber != null &&
        episodeNumber != null) {
      try {
        final episodes = await RiveStreamService()
            .getSeasonDetails(int.parse(_item.id), seasonNumber);
        actualEpisode = episodes.firstWhere(
            (ep) => ep.episodeNumber == episodeNumber,
            orElse: () => episodes.first);
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error fetching episode: $e', isError: true);
        }
        return;
      }
    }

    final bool isTv = actualEpisode != null;

    if (isTv && setSheetState != null) {
      setSheetState(() => _loadingVideo = true);
    } else {
      setState(() => _loadingMovie = true);
    }

    try {
      final service = VideoSourceService();
      final kissKhService = KissKhService();
      final vidLinkService = VidLinkService();

      final futures = <Future<dynamic>>[];

      if (provider == 'River') {
        futures.add(service.getVideoSources(
          _item.id,
          isTv ? actualEpisode.seasonNumber.toString() : '1',
          isTv ? actualEpisode.episodeNumber.toString() : '1',
          serviceName: isTv ? 'tvVideoProvider' : 'movieVideoProvider',
        ));
      } else if (provider == 'KissKh') {
        futures.add(kissKhService.getSources(
          widget.item.title,
          isTv ? actualEpisode.seasonNumber : 1,
          isTv ? actualEpisode.episodeNumber : 1,
        ));
      } else if (provider == 'VidLink') {
        futures.add(vidLinkService.getSources(
          int.tryParse(_item.id) ?? 0,
          isMovie: !isTv,
          season: isTv ? actualEpisode.seasonNumber : null,
          episode: isTv ? actualEpisode.episodeNumber : null,
        ));
      } else if (provider == 'VidEasy') {
        final vidEasyService = VidEasyService();
        futures.add(vidEasyService.getSources(
          widget.item.title,
          widget.item.year,
          int.tryParse(_item.id) ?? 0,
          isMovie: !isTv,
          season: isTv ? actualEpisode.seasonNumber : null,
          episode: isTv ? actualEpisode.episodeNumber : null,
        ));
      } else {
        futures.add(Future.value({'sources': [], 'captions': []}));
      }

      final results = await Future.wait(futures);

      var sources = <VideoSource>[];
      var captions = <VideoCaption>[];

      // Combine all found so far
      for (var i = 0; i < results.length; i++) {
        final res = results[i] as Map<String, dynamic>;
        sources.addAll(List<VideoSource>.from(res['sources'] ?? []));
        captions.addAll(List<VideoCaption>.from(res['captions'] ?? []));
      }

      // AUTO FALLBACK: If no sources found and a provider was specified, try other top ones
      if (sources.isEmpty && provider != null) {
        final fallbackProviders = ['River', 'VidLink', 'VidEasy', 'KissKh']
          ..remove(provider);

        for (final p in fallbackProviders) {
          if (!mounted) break;
          print('[PlayAction] Autofalling back to $p...');

          dynamic res;
          if (p == 'River') {
            res = await service.getVideoSources(
              _item.id,
              isTv ? actualEpisode.seasonNumber.toString() : '1',
              isTv ? actualEpisode.episodeNumber.toString() : '1',
              serviceName: isTv ? 'tvVideoProvider' : 'movieVideoProvider',
            );
          } else if (p == 'KissKh') {
            res = await kissKhService.getSources(
              widget.item.title,
              isTv ? actualEpisode.seasonNumber : 1,
              isTv ? actualEpisode.episodeNumber : 1,
            );
          } else if (p == 'VidLink') {
            res = await vidLinkService.getSources(
              int.tryParse(_item.id) ?? 0,
              isMovie: !isTv,
              season: isTv ? actualEpisode.seasonNumber : null,
              episode: isTv ? actualEpisode.episodeNumber : null,
            );
          } else if (p == 'VidEasy') {
            final vidEasyService = VidEasyService();
            res = await vidEasyService.getSources(
              widget.item.title,
              widget.item.year,
              int.tryParse(_item.id) ?? 0,
              isMovie: !isTv,
              season: isTv ? actualEpisode.seasonNumber : null,
              episode: isTv ? actualEpisode.episodeNumber : null,
            );
          }

          if (res != null) {
            final newSources = List<VideoSource>.from(res['sources'] ?? []);
            if (newSources.isNotEmpty) {
              sources.addAll(newSources);
              captions.addAll(List<VideoCaption>.from(res['captions'] ?? []));
              break;
            }
          }
        }
      }

      if (!mounted) return;

      if (sources.isNotEmpty) {
        if (isTv && setSheetState != null)
          Navigator.pop(context); // Close episode sheet
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);

        await Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                PlayerScreen(
              url: sources.first.url,
              title: isTv
                  ? '${widget.item.title} - S${actualEpisode!.seasonNumber}E${actualEpisode.episodeNumber}'
                  : widget.item.title,
              tmdbId: int.tryParse(widget.item.id),
              sources: sources,
              initialCaptions: captions,
              episode: isTv ? actualEpisode!.episodeNumber : null,
              season: isTv ? actualEpisode!.seasonNumber : null,
              mediaItem: widget.item,
              httpHeaders: (provider == 'River' || provider == null)
                  ? VideoSourceService.flowCastHeaders
                  : null,
              provider: provider,
            ),
            transitionDuration: const Duration(milliseconds: 800),
            reverseTransitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final cinematicCurve = CurvedAnimation(
                parent: animation,
                curve: Curves.fastOutSlowIn,
                reverseCurve: Curves.easeIn,
              );
              return FadeTransition(
                opacity: cinematicCurve,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 1.1, end: 1.0)
                      .animate(cinematicCurve),
                  child: child,
                ),
              );
            },
          ),
        );

        // Reset to portrait after coming back from player
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      } else {
        _showSnackBar('No stream sources found for the selected provider',
            isError: true);
      }
    } catch (e) {
      if (mounted) {
        if (isTv && setSheetState != null) {
          setSheetState(() => _loadingVideo = false);
        } else {
          setState(() => _loadingMovie = false);
        }
        _showSnackBar('Error: $e', isError: true);
      }
    }
  }

  Widget _buildMetaSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Text('•', style: TextStyle(color: Colors.white24, fontSize: 16)),
    );
  }

  Widget _buildShimmerBlock({
    required double width,
    required double height,
    Key? key,
  }) {
    return Shimmer.fromColors(
      key: key,
      baseColor: Colors.white.withValues(alpha: 0.05),
      highlightColor: Colors.white.withValues(alpha: 0.1),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  List<Widget> _buildStarRating(double rating) {
    final starRating = rating / 2;
    final fullStars = starRating.floor();
    final decimal = starRating - fullStars;
    final hasHalfStar = decimal >= 0.5;
    final emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0);

    List<Widget> stars = [];

    for (int i = 0; i < fullStars; i++) {
      stars.add(const Icon(
        Icons.star_rounded,
        size: 18,
        color: Colors.amber,
      ));
    }

    if (hasHalfStar) {
      stars.add(const Icon(
        Icons.star_half_rounded,
        size: 18,
        color: Colors.amber,
      ));
    }

    for (int i = 0; i < emptyStars; i++) {
      stars.add(Icon(
        Icons.star_outline_rounded,
        size: 18,
        color: Colors.white.withValues(alpha: 0.3),
      ));
    }

    return stars;
  }

  Map<String, int> _findNextEpisode(AppProvider provider) {
    if (!_isTvShow) return {'season': 1, 'episode': 1};
    final settings = provider.getAllSettings();
    final prefix = 'pos_tmdb_${widget.item.id}_s';

    final keys = settings.keys.where((k) => k.startsWith(prefix)).toList();
    if (keys.isEmpty) return {'season': 1, 'episode': 1};

    final regExp = RegExp(r'_s(\d+)_e(\d+)');
    final List<Map<String, dynamic>> played = [];
    for (var k in keys) {
      final match = regExp.firstMatch(k);
      if (match != null) {
        played.add({
          's': int.parse(match.group(1)!),
          'e': int.parse(match.group(2)!),
          'pos': settings[k] as int,
        });
      }
    }

    played.sort((a, b) {
      if (a['s'] != b['s']) return (a['s'] as int).compareTo(b['s'] as int);
      return (a['e'] as int).compareTo(b['e'] as int);
    });

    final last = played.last;
    final int s = last['s'] as int;
    final int e = last['e'] as int;
    final int pos = last['pos'] as int;

    final runtimeMin = _details?.runtime ?? 45;
    final totalMs = runtimeMin * 60 * 1000;
    if (pos > (totalMs * 0.9)) {
      return {'season': s, 'episode': e + 1};
    }

    return {'season': s, 'episode': e};
  }

  Future<void> _handlePlayAction(int s, int e) async {
    if (!_isTvShow) {
      _showSourceSelector();
      return;
    }

    // For TV shows, show source selector immediately
    // Episode details will be fetched after provider selection
    _showSourceSelector(seasonNumber: s, episodeNumber: e);
  }

  Widget _buildSectionHeader(String title, String? subtitle) {
    return Padding(
      padding: const EdgeInsets.only(left: 0, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGenresDialog() {
    if (_item.genres == null || _item.genres!.isEmpty) return;
    final genres = _item.genres!.split(',').map((g) => g.trim()).toList();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Dialog(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GENRES',
                  style: GoogleFonts.outfit(
                    color: AppTheme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 24),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: genres.map((genre) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                        genre.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'CLOSE',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.0,
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
}

class _TgFlowSheet extends StatefulWidget {
  final String imdbId;
  final bool isTv;
  final int? season;
  final int? episode;
  final String title;
  final int? tmdbId;
  final ImdbSearchResult? mediaItem;

  const _TgFlowSheet({
    required this.imdbId,
    required this.isTv,
    this.season,
    this.episode,
    required this.title,
    this.tmdbId,
    this.mediaItem,
  });

  @override
  State<_TgFlowSheet> createState() => _TgFlowSheetState();
}

class _TgFlowSheetState extends State<_TgFlowSheet> {
  String _statusText = 'Checking availability...';
  String? _error;
  List<TgStatusQuality> _qualities = [];
  TgMovieCheckResult? _movieResult;
  TgQualityFiles? _selectedQuality;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  Future<void> _startFlow() async {
    final service = TgService();

    setState(() {
      _statusText = 'Checking availability...';
      _loading = true;
      _error = null;
    });

    final checkResult = (!widget.isTv && widget.tmdbId != null)
        ? await service.checkMovie(widget.tmdbId.toString())
        : null;

    if (!widget.isTv && widget.tmdbId != null) {
      if (!mounted) return;
      if (checkResult == null || checkResult.qualities.isEmpty) {
        setState(() {
          _error = 'Not available on TG';
          _loading = false;
        });
        return;
      }

      setState(() {
        _movieResult = checkResult;
        _qualities = checkResult.qualities
            .map((q) => TgStatusQuality(
                  label: q.label,
                  files: q.files.length,
                  ready: true,
                ))
            .toList();
        _loading = false;
      });
      return;
    }

    final tvCheckResult = await service.check(widget.imdbId);
    if (!mounted) return;

    if (tvCheckResult == null || tvCheckResult.qualities.isEmpty) {
      setState(() {
        _error = 'Not available on TG';
        _loading = false;
      });
      return;
    }

    // This block is no longer needed as movie logic is handled above

    setState(() => _statusText = 'Checking cache status...');

    final statusResult = await service.status(widget.imdbId);

    if (!mounted) return;

    if (statusResult == null) {
      setState(() {
        _error = 'Failed to check status';
        _loading = false;
      });
      return;
    }

    if (!statusResult.ready) {
      setState(() {
        _error = 'Content is not cached yet. Try again later.';
        _loading = false;
        _qualities = statusResult.qualities;
      });
      return;
    }

    final readyQualities =
        statusResult.qualities.where((q) => q.ready).toList();
    if (readyQualities.isEmpty) {
      setState(() {
        _error = 'No ready qualities found';
        _loading = false;
      });
      return;
    }

    setState(() {
      _qualities = readyQualities;
      _loading = false;
    });
  }

  Future<void> _selectQuality(TgStatusQuality quality) async {
    if (_movieResult != null) {
      final qFiles = _movieResult!.qualities.firstWhere(
        (q) => q.label == quality.label,
        orElse: () => _movieResult!.qualities.first,
      );
      setState(() {
        _selectedQuality = qFiles;
      });
      return;
    }

    final service = TgService();

    setState(() {
      _statusText = 'Fetching stream...';
      _loading = true;
      _error = null;
    });

    final streams = (!widget.isTv && widget.tmdbId != null)
        ? await service.getMovieStreams(widget.tmdbId.toString(),
            quality: quality.label)
        : await service.getStreams(
            widget.imdbId,
            season: widget.season,
            episode: widget.episode,
          );

    if (!mounted) return;

    if (streams.isEmpty) {
      setState(() {
        _error = 'No streams found';
        _loading = false;
      });
      return;
    }

    final match = streams.firstWhere(
      (s) => s.quality == quality.label,
      orElse: () => streams.first,
    );

    final url = '${TgService.baseUrl}${match.url}';

    Navigator.pop(context);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PlayerScreen(
          url: url,
          title: widget.title,
          tmdbId: widget.tmdbId,
          sources: streams
              .map((s) => VideoSource(
                    url: '${TgService.baseUrl}${s.url}',
                    quality: s.quality,
                    format: 'Stream',
                    size: 'Unknown',
                  ))
              .toList(),
          episode: widget.episode,
          season: widget.season,
          mediaItem: widget.mediaItem,
          provider: 'TG',
        ),
        transitionDuration: const Duration(milliseconds: 800),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.fastOutSlowIn,
            reverseCurve: Curves.easeIn,
          );
          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.1, end: 1.0).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  Future<void> _selectFile(TgMovieFile file) async {
    final service = TgService();

    setState(() {
      _statusText = 'Fetching stream...';
      _loading = true;
      _error = null;
    });

    final stream = await service.getMovieStreamByMessageId(file.messageId);

    if (!mounted) return;

    if (stream == null) {
      setState(() {
        _error = 'Failed to fetch stream URL';
        _loading = false;
      });
      return;
    }

    final url = '${TgService.baseUrl}${stream.url}';

    Navigator.pop(context);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PlayerScreen(
          url: url,
          title: widget.title,
          tmdbId: widget.tmdbId,
          sources: [
            VideoSource(
              url: url,
              quality: stream.quality,
              format: 'Stream',
              size: _formatFileSize(file.fileSize),
            )
          ],
          episode: widget.episode,
          season: widget.season,
          mediaItem: widget.mediaItem,
          provider: 'TG',
        ),
        transitionDuration: const Duration(milliseconds: 800),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.fastOutSlowIn,
            reverseCurve: Curves.easeIn,
          );
          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.1, end: 1.0).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "Unknown";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = (log(bytes) / log(1024)).floor();
    return ((bytes / pow(1024, i)).toStringAsFixed(2)) + ' ' + suffixes[i];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.telegram_rounded,
                      color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'TG Provider',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (_selectedQuality != null || _error != null)
                  IconButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedQuality != null) {
                          _selectedQuality = null;
                        } else {
                          _error = null;
                          _startFlow();
                        }
                      });
                    },
                    icon: Icon(
                        _selectedQuality != null
                            ? Icons.arrow_back_rounded
                            : Icons.refresh_rounded,
                        size: 20),
                    color: Colors.white38,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: Colors.white38,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedQuality != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  'SELECT FILE - ${_selectedQuality!.label}',
                  style: GoogleFonts.outfit(
                    color: AppTheme.primaryColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _selectedQuality!.files.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final file = _selectedQuality!.files[index];
                    return Material(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _selectFile(file),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                file.name,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.storage_rounded,
                                      size: 12, color: Colors.white38),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatFileSize(file.fileSize),
                                    style: GoogleFonts.outfit(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (file.ready)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.green.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'READY',
                                        style: GoogleFonts.outfit(
                                          color: Colors.green,
                                          fontSize: 8,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ] else if (_loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation(AppTheme.primaryColor),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusText,
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded,
                        color: Colors.redAccent.withValues(alpha: 0.8),
                        size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: GoogleFonts.outfit(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (!_loading && _error == null && _qualities.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  'SELECT QUALITY',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ..._qualities.map((q) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () => _selectQuality(q),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.play_circle_outline_rounded,
                                  color: AppTheme.primaryColor, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  q.label,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${q.files} files',
                                  style: GoogleFonts.outfit(
                                    color: Colors.greenAccent,
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
                  )),
            ],
            if (!_loading && _qualities.isNotEmpty && _error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: _qualities
                      .map((q) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  q.ready
                                      ? Icons.check_circle_rounded
                                      : Icons.hourglass_top_rounded,
                                  color: q.ready ? Colors.green : Colors.orange,
                                  size: 14,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    q.label,
                                    style: GoogleFonts.outfit(
                                      color:
                                          Colors.white.withValues(alpha: 0.6),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${q.files} files',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CastDetailView extends StatelessWidget {
  final CastMember member;

  const _CastDetailView({required this.member});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Material(
        color: Colors.black.withValues(alpha: 0.78),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile image
                  if (member.fullProfileUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl:
                            member.fullProfileUrl.replaceAll('w185', 'w500'),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 280,
                        placeholder: (_, __) => Container(
                          width: double.infinity,
                          height: 280,
                          color: Colors.white.withValues(alpha: 0.05),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation(AppTheme.primaryColor),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: double.infinity,
                          height: 280,
                          color: Colors.white.withValues(alpha: 0.05),
                          child: Icon(
                            Icons.person,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 80,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 280,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person,
                        color: Colors.white.withValues(alpha: 0.3),
                        size: 80,
                      ),
                    ),
                  const SizedBox(height: 14),
                  // Name
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          transitionDuration: const Duration(milliseconds: 500),
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  SearchPage(
                            initialQuery: member.name,
                            fromCast: true,
                          ),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.1),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: child,
                              ),
                            );
                          },
                        ),
                      );
                    },
                    child: Text(
                      member.name,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Character
                  if (member.character != null &&
                      member.character!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      member.character!,
                      style: GoogleFonts.outfit(
                        color: AppTheme.primaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Creative loading spinner
class CreativeLoadingSpinner extends StatefulWidget {
  final double size;
  final Color color;

  const CreativeLoadingSpinner({
    super.key,
    this.size = 50,
    this.color = const Color(0xFFE8A634),
  });

  @override
  State<CreativeLoadingSpinner> createState() => _CreativeLoadingSpinnerState();
}

class _CreativeLoadingSpinnerState extends State<CreativeLoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer rotating ring
          RotationTransition(
            turns: _controller,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
            ),
          ),
          // Middle rotating ring (opposite direction)
          RotationTransition(
            turns: Tween<double>(begin: 1, end: 0).animate(_controller),
            child: Container(
              width: widget.size * 0.7,
              height: widget.size * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
            ),
          ),
          // Inner pulsing dot
          ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
            ),
            child: Container(
              width: widget.size * 0.25,
              height: widget.size * 0.25,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeCountdownText extends StatefulWidget {
  final TVMazeNextEpisode nextEpisode;

  const _EpisodeCountdownText({required this.nextEpisode});

  @override
  State<_EpisodeCountdownText> createState() => _EpisodeCountdownTextState();
}

class _EpisodeCountdownTextState extends State<_EpisodeCountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nextEp = widget.nextEpisode;
    final timeUntil = nextEp.timeUntilAir;
    final isAiring = timeUntil != null;

    return Text(
      isAiring ? nextEp.countdownText : (nextEp.airdate ?? ''),
      style: GoogleFonts.outfit(
        color: isAiring ? AppTheme.primaryColor : Colors.white38,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    );
  }
}

class _NetflixLikeRatingButton extends StatefulWidget {
  final String mediaId;

  const _NetflixLikeRatingButton({required this.mediaId});

  @override
  State<_NetflixLikeRatingButton> createState() =>
      _NetflixLikeRatingButtonState();
}

class _NetflixLikeRatingButtonState extends State<_NetflixLikeRatingButton> {
  void _showRatingMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _RatingOptionsPopup(
        onSelected: (rating) {
          context.read<AppProvider>().setRating(widget.mediaId, rating);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final rating = provider.getRating(widget.mediaId);

    IconData iconData;
    Color iconColor = Colors.white;

    switch (rating) {
      case 1:
        iconData = Icons.thumb_down_rounded;
        iconColor = Colors.redAccent;
        break;
      case 2:
        iconData = Icons.thumb_up_rounded;
        iconColor = AppTheme.primaryColor;
        break;
      case 3:
        iconData = Icons.favorite_rounded;
        iconColor = Colors.pinkAccent;
        break;
      default:
        iconData = Icons.thumb_up_alt_outlined;
        iconColor = Colors.white70;
    }

    return Container(
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
      ),
      child: IconButton(
        onPressed: () => _showRatingMenu(context),
        icon: Icon(iconData, color: iconColor, size: 22),
        tooltip: 'Rate',
      ),
    );
  }
}

class _RatingOptionsPopup extends StatelessWidget {
  final Function(int) onSelected;

  const _RatingOptionsPopup({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'How did you like this?',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildRatingOption(
                icon: Icons.thumb_down_rounded,
                label: 'Not for me',
                color: Colors.redAccent,
                value: 1,
              ),
              _buildRatingOption(
                icon: Icons.thumb_up_rounded,
                label: 'I like this',
                color: AppTheme.primaryColor,
                value: 2,
              ),
              _buildRatingOption(
                icon: Icons.favorite_rounded,
                label: 'Love this!',
                color: Colors.pinkAccent,
                value: 3,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => onSelected(0),
            child: Text(
              'Remove Rating',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingOption({
    required IconData icon,
    required String label,
    required Color color,
    required int value,
  }) {
    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
