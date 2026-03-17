import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/imdb_service.dart';
import '../../services/rivestream_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import '../../theme/app_theme.dart';
import '../torrents/torrent_search_screen.dart';
import '../../services/video_source_service.dart';
import '../player/player_screen.dart';
import 'package:provider/provider.dart' as provider_pkg hide Consumer;
import '../../providers/app_provider.dart';
import 'dart:ui';

import 'package:shimmer/shimmer.dart';
import 'search_page.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
import '../../providers/media_info_providers.dart';
import 'package:hugeicons/hugeicons.dart';

class MediaInfoScreen extends ConsumerStatefulWidget {
  final ImdbSearchResult item;
  final String? heroTag;

  const MediaInfoScreen({super.key, required this.item, this.heroTag});

  @override
  ConsumerState<MediaInfoScreen> createState() => _MediaInfoScreenState();
}

class _MediaInfoScreenState extends ConsumerState<MediaInfoScreen> {
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
  bool _didPrefetchSources = false;
  Player? _trailerPreviewPlayer;
  VideoController? _trailerPreviewController;
  String? _trailerPreviewUrl;
  bool _trailerPreviewLoading = false;
  bool _trailerPreviewAttempted = false;
  bool _trailerPreviewReady = false;
  bool _trailerPreviewMuted = true;
  bool _trailerPreviewPlaying = false;
  bool _trailerPreviewFullscreen = false;
  bool _trailerControlsVisible = true;
  Timer? _trailerControlsTimer;

  static const List<String> _providerOrder = [
    'river',
    'vidlink',
    'videasy',
    'kisskh',
    'tg',
  ];

  static const Map<String, String> _providerDisplayNames = {
    'river': 'River',
    'vidlink': 'VidLink',
    'videasy': 'VidEasy',
    'kisskh': 'KissKh',
    'tg': 'TG',
  };

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController!.addListener(_onScroll);
    _item = widget.item;

    // Start loading immediately but prioritize transition
    _loadDetails();
    _initializeTrailerPreview();
  }

  void _onScroll() {
    if (_scrollController == null || !_scrollController!.hasClients) return;
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 16), () {
      if (_scrollController == null || !_scrollController!.hasClients) return;
      final threshold =
          MediaQuery.of(context).size.height * 0.35 - kToolbarHeight;
      final show = _scrollController!.offset > threshold;
      if (show != _showTitleNotifier.value) {
        _showTitleNotifier.value = show;
      }
    });
  }

  @override
  void dispose() {
    _scrollDebounceTimer?.cancel();
    _trailerControlsTimer?.cancel();
    _trailerPreviewPlayer?.dispose();
    if (_trailerPreviewFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
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

        // 1. Try cache first
        final cachedDetails = await riveService.getCachedMediaDetails(tmdbIdInt,
            isMovie: widget.item.kind?.toLowerCase() == 'movie' ||
                !widget.item.kind!.toLowerCase().contains('tv'));

        if (cachedDetails != null && mounted) {
          _details = cachedDetails;
          setState(() {
            _isLoading = false;
            // Update metadata but DO NOT change poster URL yet to avoid Hero flicker during transition
            _item = _item.copyWith(
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
              backdropUrl: cachedDetails.ogBackdropUrl,
              genres: cachedDetails.genres.join(', '),
              duration: cachedDetails.runtime != null
                  ? '${cachedDetails.runtime} min'
                  : null,
            );
          });

          // Background load extra data after cache hit
          _fetchExtraData(id, isTmdb);
        }

        // 2. Load fresh details
        var details = await riveService.getMediaDetails(
          tmdbIdInt,
          isMovie: widget.item.kind?.toLowerCase() == 'movie' ||
              !widget.item.kind!.toLowerCase().contains('tv'),
        );

        if (details != null && mounted) {
          _details = details;
          setState(() {
            _isLoading = false;
            _item = _item.copyWith(
              id: id,
              description: details.overview,
              rating: details.voteAverage.toStringAsFixed(1),
              year: (details.releaseDate != null &&
                      details.releaseDate!.isNotEmpty)
                  ? details.releaseDate!.split('-').first
                  : (details.firstAirDate != null &&
                          details.firstAirDate!.isNotEmpty
                      ? details.firstAirDate!.split('-').first
                      : widget.item.year),
              backdropUrl: details.ogBackdropUrl,
              genres: details.genres.join(', '),
              duration:
                  details.runtime != null ? '${details.runtime} min' : null,
            );
          });

          if (cachedDetails == null) {
            _fetchExtraData(id, isTmdb);
          }

          _initializeTrailerPreview(retry: true);
        } else if (cachedDetails == null && mounted) {
          setState(() => _isLoading = false);
        }

        // Final "silent" quality upgrade after everything is settled
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            final upgraded = _upgradeImageQuality(_item);
            if (upgraded.posterUrl != _item.posterUrl) {
              setState(() => _item = upgraded);
            }
          }
        });
      } else {
        final details = await _imdbService.fetchDetails(widget.item.id);
        if (mounted) {
          setState(() {
            _isLoading = false;
            _item = widget.item.copyWith(
              kind: details.kind ?? widget.item.kind,
              rating: widget.item.rating ?? details.rating,
              description: widget.item.description ?? details.description,
              year:
                  widget.item.year.isNotEmpty ? widget.item.year : details.year,
              posterUrl: details.posterUrl.isNotEmpty
                  ? details.posterUrl
                  : widget.item.posterUrl,
            );
          });
          _fetchExtraData(widget.item.id, false);
          _initializeTrailerPreview(retry: true);

          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _item = _upgradeImageQuality(_item));
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fetchExtraData(String id, bool isTmdb) {
    if (!mounted) return;
    final isTv = _isTvShow;

    if (isTv && isTmdb) _fetchSeasonEpisodes(_selectedSeason ?? 1);
    if (isTv) _fetchTvMazeInfo();

    _loadRecommendations(id, isTmdb: isTmdb, isMovie: !isTv);
    if (isTmdb) _loadCast(int.parse(id), isMovie: !isTv);

    _primeProviderSources();
  }

  VideoSourceKey? _createVideoSourceKey({
    RiveStreamEpisode? episode,
    int? seasonNumber,
    int? episodeNumber,
  }) {
    final tmdbId = int.tryParse(_item.id);
    if (tmdbId == null) return null;

    final isMovie = !_isTvShow;
    int s = 1;
    int e = 1;

    if (!isMovie) {
      if (episode != null) {
        s = episode.seasonNumber;
        e = episode.episodeNumber;
      } else if (seasonNumber != null && episodeNumber != null) {
        s = seasonNumber;
        e = episodeNumber;
      } else {
        s = _selectedSeason ?? 1;
        e = _selectedEpisode ?? 1;
      }
    }

    final imdbId = (_details?.imdbId != null && _details!.imdbId!.isNotEmpty)
        ? _details!.imdbId
        : (_item.id.startsWith('tt') ? _item.id : null);

    return VideoSourceKey(
      tmdbId: tmdbId.toString(),
      imdbId: imdbId,
      title: _item.title,
      year: _item.year,
      isMovie: isMovie,
      season: s,
      episode: e,
    );
  }

  void _primeProviderSources() {
    if (!mounted || _didPrefetchSources) return;

    final tmdbId = int.tryParse(_item.id);
    if (tmdbId == null) return;

    int s = 1;
    int e = 1;
    if (_isTvShow) {
      final appProvider = context.read<AppProvider>();
      final next = _findNextEpisode(appProvider);
      s = next['season'] ?? 1;
      e = next['episode'] ?? 1;
    }

    final key = _createVideoSourceKey(seasonNumber: s, episodeNumber: e);
    if (key == null) return;

    _didPrefetchSources = true;
    unawaited(ref.read(videoSourcesProvider(key).future));
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

  Future<String?> _resolveTrailerStreamUrl() async {
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
          imdbId = await riveService.getImdbIdFromTmdbId(
            tmdbId,
            isMovie: !_isTvShow,
          );
        }
      }

      if (imdbId != null) {
        try {
          final details = await _imdbService.fetchDetails(imdbId);
          videoId = details.videoId;
          if (videoId == null || videoId.isEmpty) {
            videoId = await _imdbService.findTrailerVideoId(imdbId);
          }
        } catch (_) {}
      }
    }

    if (videoId == null || videoId.isEmpty) return null;
    return _imdbService.fetchTrailerStreamUrl(videoId);
  }

  Future<void> _initializeTrailerPreview({bool retry = false}) async {
    if (_trailerPreviewLoading) return;
    if (_trailerPreviewAttempted && !retry) return;

    _trailerPreviewAttempted = true;
    if (mounted) {
      setState(() {
        _trailerPreviewLoading = true;
        _trailerPreviewReady = false;
      });
    }

    final url = await _resolveTrailerStreamUrl();
    if (!mounted) return;

    if (url == null || url.isEmpty) {
      setState(() {
        _trailerPreviewLoading = false;
        _trailerPreviewReady = false;
      });
      return;
    }

    try {
      final player = Player();
      final controller = VideoController(player);
      player.setVolume(_trailerPreviewMuted ? 0 : 65);
      await player.open(Media(url), play: true);

      if (!mounted) {
        player.dispose();
        return;
      }

      _trailerPreviewPlayer?.dispose();
      setState(() {
        _trailerPreviewPlayer = player;
        _trailerPreviewController = controller;
        _trailerPreviewUrl = url;
        _trailerPreviewLoading = false;
        _trailerPreviewReady = true;
        _trailerPreviewPlaying = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _trailerPreviewLoading = false;
          _trailerPreviewReady = false;
        });
      }
    }
  }

  void _toggleTrailerPreviewMute() {
    final player = _trailerPreviewPlayer;
    if (player == null) return;

    setState(() {
      _trailerPreviewMuted = !_trailerPreviewMuted;
      player.setVolume(_trailerPreviewMuted ? 0 : 65);
    });
  }

  void _toggleTrailerPreviewPlayPause() {
    final player = _trailerPreviewPlayer;
    if (player == null) return;

    if (_trailerPreviewPlaying) {
      player.pause();
    } else {
      player.play();
    }

    setState(() {
      _trailerPreviewPlaying = !_trailerPreviewPlaying;
    });
  }

  Future<void> _replayTrailerPreview() async {
    final player = _trailerPreviewPlayer;
    if (player == null) return;

    await player.seek(Duration.zero);
    await player.play();
    setState(() {
      _trailerPreviewPlaying = true;
    });
  }

  void _toggleTrailerPreviewFullscreen() {
    final player = _trailerPreviewPlayer;
    if (!_trailerPreviewFullscreen && player != null) {
      player.setVolume(65);
    }

    if (_trailerPreviewFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    setState(() {
      _trailerPreviewMuted = false;
      _trailerPreviewFullscreen = !_trailerPreviewFullscreen;
    });
  }

  Widget _buildTrailerReplayOverlay() {
    final player = _trailerPreviewPlayer;
    if (player == null || _trailerPreviewLoading) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: Duration.zero,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          initialData: Duration.zero,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data ?? Duration.zero;
            final totalMs = duration.inMilliseconds;
            final ended =
                totalMs > 0 && position.inMilliseconds >= (totalMs - 350);

            if (!ended) return const SizedBox.shrink();

            return Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _replayTrailerPreview,
                  customBorder: const CircleBorder(),
                  child: Ink(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.92),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.replay_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _playTrailer() async {
    final url = _trailerPreviewUrl ?? await _resolveTrailerStreamUrl();

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

    if (mounted) {
      _showSnackBar('No trailer found', isError: true);
    }
  }

  Widget _buildTrailerProgressBar() {
    final player = _trailerPreviewPlayer;
    if (player == null) return const SizedBox.shrink();

    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: Duration.zero,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          initialData: Duration.zero,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data ?? Duration.zero;
            final safeTotal =
                duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
            final progress =
                (position.inMilliseconds / safeTotal).clamp(0.0, 1.0);

            return ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                minHeight: 1.5,
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor.withValues(alpha: 0.95),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleTrailerControls() {
    if (!mounted) return;
    if (_trailerControlsVisible) {
      _trailerControlsTimer?.cancel();
      setState(() => _trailerControlsVisible = false);
    } else {
      _showTrailerControlsBriefly();
    }
  }

  void _showTrailerControlsBriefly() {
    if (!mounted) return;
    setState(() => _trailerControlsVisible = true);
    _trailerControlsTimer?.cancel();
    _trailerControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _trailerControlsVisible = false);
    });
  }

  String _formatTrailerDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _buildFullscreenTrailerControls({
    required Duration position,
    required Duration duration,
  }) {
    final player = _trailerPreviewPlayer;
    if (player == null) return const SizedBox.shrink();

    final totalMs = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
    final progress = (position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: _trailerControlsVisible ? 1.0 : 0.0,
      child: IgnorePointer(
        ignoring: !_trailerControlsVisible,
        child: Container(
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
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Play/Pause + skip row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      final newPos = position - const Duration(seconds: 10);
                      player.seek(
                          newPos < Duration.zero ? Duration.zero : newPos);
                      _showTrailerControlsBriefly();
                    },
                    icon: const Icon(Icons.replay_10_rounded,
                        color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      _toggleTrailerPreviewPlayPause();
                      _showTrailerControlsBriefly();
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 1.5),
                      ),
                      child: Icon(
                        _trailerPreviewPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () {
                      final newPos = position + const Duration(seconds: 10);
                      player.seek(newPos > duration ? duration : newPos);
                      _showTrailerControlsBriefly();
                    },
                    icon: const Icon(Icons.forward_10_rounded,
                        color: Colors.white, size: 32),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Seekbar row
              Row(
                children: [
                  Text(
                    _formatTrailerDuration(position),
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14),
                        activeTrackColor: AppTheme.primaryColor,
                        inactiveTrackColor:
                            Colors.white.withValues(alpha: 0.2),
                        thumbColor: Colors.white,
                        overlayColor: Colors.white.withValues(alpha: 0.15),
                      ),
                      child: Slider(
                        value: progress,
                        onChanged: (v) {
                          final seekMs = (v * totalMs).round();
                          player.seek(Duration(milliseconds: seekMs));
                          _showTrailerControlsBriefly();
                        },
                      ),
                    ),
                  ),
                  Text(
                    _formatTrailerDuration(duration),
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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

  String _trailerThumbUrl() {
    final detailsBackdrop = _details?.ogBackdropUrl ?? '';
    if (detailsBackdrop.isNotEmpty) return detailsBackdrop;

    final itemBackdrop = _item.backdropUrl ?? '';
    if (itemBackdrop.isNotEmpty) return upgradePosterQuality(itemBackdrop);

    return _upgradeImageQuality(_item).posterUrl;
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
    return PopScope(
      canPop: !_trailerPreviewFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _trailerPreviewFullscreen) {
          _toggleTrailerPreviewFullscreen();
        }
      },
      child: Scaffold(
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
                        const SizedBox(height: 12),
                        _buildNextEpisodeBanner(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Top Shadow Gradient for Status Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top + 80,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_trailerPreviewFullscreen && _trailerPreviewController != null)
            Positioned.fill(
              child: Material(
                color: Colors.black,
                child: StreamBuilder<Duration>(
                  stream: _trailerPreviewPlayer!.stream.position,
                  initialData: Duration.zero,
                  builder: (context, posSnap) {
                    return StreamBuilder<Duration>(
                      stream: _trailerPreviewPlayer!.stream.duration,
                      initialData: Duration.zero,
                      builder: (context, durSnap) {
                        final pos = posSnap.data ?? Duration.zero;
                        final dur = durSnap.data ?? Duration.zero;
                        final ended = dur.inMilliseconds > 0 &&
                            pos.inMilliseconds >= (dur.inMilliseconds - 350);

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: ended ? null : _toggleTrailerControls,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Video — fades out when ended
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 500),
                                opacity: ended ? 0.0 : (_trailerPreviewReady ? 1.0 : 0.0),
                                child: Video(
                                  controller: _trailerPreviewController!,
                                  fit: BoxFit.contain,
                                  controls: (state) => const SizedBox.shrink(),
                                ),
                              ),
                              // Backdrop + replay — fades in when ended
                              if (ended)
                                Positioned.fill(
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: _trailerThumbUrl(),
                                        fit: BoxFit.cover,
                                      ),
                                      Container(
                                        color: Colors.black.withValues(alpha: 0.55),
                                      ),
                                      Center(
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _replayTrailerPreview,
                                            customBorder: const CircleBorder(),
                                            child: Container(
                                              width: 72,
                                              height: 72,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.black.withValues(alpha: 0.35),
                                                border: Border.all(
                                                  color: Colors.white.withValues(alpha: 0.9),
                                                  width: 2,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.replay_rounded,
                                                color: Colors.white,
                                                size: 34,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate().fadeIn(duration: 400.ms),
                              // Close + mute (always visible)
                              Positioned(
                                top: MediaQuery.of(context).padding.top + 4,
                                left: 8,
                                right: 8,
                                child: Row(
                                  children: [
                                    Material(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(999),
                                      child: InkWell(
                                        onTap: _toggleTrailerPreviewFullscreen,
                                        borderRadius: BorderRadius.circular(999),
                                        child: const Padding(
                                          padding: EdgeInsets.all(8),
                                          child: Icon(Icons.arrow_back_ios_new_rounded,
                                              color: Colors.white, size: 18),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (!ended)
                                      Material(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(999),
                                        child: InkWell(
                                          onTap: () {
                                            _toggleTrailerPreviewMute();
                                            _showTrailerControlsBriefly();
                                          },
                                          borderRadius: BorderRadius.circular(999),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: Icon(
                                              _trailerPreviewMuted
                                                  ? Icons.volume_off_rounded
                                                  : Icons.volume_up_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Proper seekable controls (hidden when ended)
                              if (!ended)
                                Positioned.fill(
                                  child: _buildFullscreenTrailerControls(
                                    position: pos,
                                    duration: dur,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.25,
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
            Container(color: const Color(0xFF09090B)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.55),
                    Colors.transparent,
                    AppTheme.backgroundColor.withValues(alpha: 0.6),
                    AppTheme.backgroundColor,
                  ],
                  stops: const [0.0, 0.4, 0.8, 1.0],
                ),
              ),
            ),
            if (_trailerPreviewController != null || _trailerPreviewLoading)
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    MediaQuery.of(context).padding.top,
                    0,
                    0,
                  ),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.zero,
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onDoubleTap: _toggleTrailerPreviewPlayPause,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: _trailerThumbUrl(),
                              fit: (_details?.ogBackdropUrl ?? '').isNotEmpty ||
                                      ((_item.backdropUrl ?? '').isNotEmpty)
                                  ? BoxFit.cover
                                  : BoxFit.contain,
                              fadeInDuration: const Duration(milliseconds: 180),
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.black,
                              ),
                            ),
                            if (_trailerPreviewController != null)
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 260),
                                opacity: _trailerPreviewReady ? 1.0 : 0.0,
                                child: Video(
                                  controller: _trailerPreviewController!,
                                  fit: BoxFit.cover,
                                  controls: (state) => const SizedBox.shrink(),
                                ),
                              ),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.12),
                                    Colors.black.withValues(alpha: 0.42),
                                  ],
                                ),
                              ),
                            ),
                            if (_trailerPreviewController != null)
                              Positioned.fill(
                                child: _buildTrailerReplayOverlay(),
                              ),
                            if (_trailerPreviewReady)
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.42),
                                  borderRadius: BorderRadius.circular(999),
                                  child: InkWell(
                                    onTap: _trailerPreviewController != null
                                        ? _toggleTrailerPreviewMute
                                        : null,
                                    borderRadius: BorderRadius.circular(999),
                                    child: Padding(
                                      padding: const EdgeInsets.all(7),
                                      child: Icon(
                                        _trailerPreviewMuted
                                            ? Icons.volume_off_rounded
                                            : Icons.volume_up_rounded,
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_trailerPreviewReady)
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.42),
                                  borderRadius: BorderRadius.circular(999),
                                  child: InkWell(
                                    onTap: _toggleTrailerPreviewFullscreen,
                                    borderRadius: BorderRadius.circular(999),
                                    child: const Padding(
                                      padding: EdgeInsets.all(7),
                                      child: Icon(
                                        Icons.fullscreen,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              left: 4,
                              right: 4,
                              bottom: 4,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: _buildTrailerProgressBar(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
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
                    child: HugeIcon(
                        icon: HugeIcons.strokeRoundedShare08,
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
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedSearch02,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
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
              final key = 'pos_tmdb_${widget.item.id}_s${s}_e$e';
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
                            : HugeIcon(
                                icon: HugeIcons.strokeRoundedPlayCircle02,
                                color: Colors.black,
                                size: 24.0,
                              ),
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
                            color: isWatchlisted
                                ? AppTheme.primaryColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isWatchlisted
                                  ? Colors.transparent
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: Tooltip(
                              message: isWatchlisted
                                  ? 'Remove from Watchlist'
                                  : 'Save to Watchlist',
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  provider.toggleWatchlist(_item);
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Center(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: HugeIcon(
                                      icon: isWatchlisted
                                          ? HugeIcons.strokeRoundedBookmark03
                                          : HugeIcons.strokeRoundedBookmark02,
                                      key: ValueKey(isWatchlisted),
                                      color: isWatchlisted
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.9),
                                      size: 22.0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
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
                final next = _findNextEpisode(provider);
                final key = _createVideoSourceKey(
                  seasonNumber: next['season'],
                  episodeNumber: next['episode'],
                );
                final asyncSources =
                    key != null ? ref.watch(videoSourcesProvider(key)) : null;

                final availableProviders = <String>[];
                bool isLoadingSources = false;
                bool hasSourceError = false;

                if (asyncSources == null) {
                  hasSourceError = true;
                } else {
                  asyncSources.when(
                    data: (data) {
                      for (final providerKey in _providerOrder) {
                        final result = data[providerKey];
                        if (result == null) continue;
                        final hasSources = result.sources.isNotEmpty;
                        final isTg = result.isTg;
                        if (hasSources || isTg) {
                          availableProviders.add(
                              _providerDisplayNames[providerKey] ??
                                  providerKey);
                        }
                      }
                      return null;
                    },
                    loading: () {
                      isLoadingSources = true;
                      return null;
                    },
                    error: (_, __) {
                      hasSourceError = true;
                      return null;
                    },
                  );
                }

                final isDefProvAvailable =
                    defProv != null && availableProviders.contains(defProv);
                final displayProvider =
                    isDefProvAvailable ? defProv : 'Provider';

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PopupMenuButton<String>(
                      initialValue: isDefProvAvailable ? defProv : null,
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
                        if (isLoadingSources)
                          const PopupMenuItem(
                            enabled: false,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white70,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Checking sources...',
                                    style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        if (!isLoadingSources &&
                            availableProviders.isEmpty &&
                            !hasSourceError)
                          const PopupMenuItem(
                            enabled: false,
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 16, color: Colors.white70),
                                SizedBox(width: 8),
                                Text('No sources found',
                                    style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        const PopupMenuDivider(height: 4),
                        ...availableProviders.map(
                          (name) => PopupMenuItem(
                            value: name,
                            child: Row(
                              children: [
                                const HugeIcon(
                                    icon: HugeIcons.strokeRoundedPlayCircle02),
                                const SizedBox(width: 8),
                                Text(name,
                                    style:
                                        const TextStyle(color: Colors.white)),
                              ],
                            ),
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
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedPlayCircle02,
                                size: 18,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              displayProvider,
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
                                    child: episode.fullStillUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: episode.fullStillUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) => Container(
                                              color: AppTheme.cardColor,
                                            ),
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                              color: AppTheme.cardColor,
                                              child: const Icon(Icons.movie,
                                                  color: Colors.white24),
                                            ),
                                          )
                                        : Container(
                                            color: AppTheme.cardColor,
                                            child: const Icon(Icons.movie,
                                                color: Colors.white24),
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
                                        child: HugeIcon(
                                          icon: HugeIcons
                                              .strokeRoundedCheckmarkSquare02,
                                          size: 14,
                                          color: Colors.green,
                                        ),
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
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedTv02,
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
            child: HugeIcon(
              icon: isAiring
                  ? HugeIcons.strokeRoundedCalendar02
                  : HugeIcons.strokeRoundedLiveStreaming02,
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
            final provider = provider_pkg.Provider.of<AppProvider>(context);
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
                                  if (episode.fullStillUrl.isNotEmpty)
                                    CachedNetworkImage(
                                      imageUrl: episode.fullStillUrl,
                                      fit: BoxFit.cover,
                                    )
                                  else
                                    Container(
                                      color: Colors.white10,
                                      child: const Icon(Icons.movie,
                                          color: Colors.white24),
                                    ),
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
    final key = _createVideoSourceKey(
      episode: episode,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        if (key == null) {
          return _buildSourceSelectorContainer(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No providers available for this title',
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }

        return Consumer(
          builder: (context, ref, _) {
            final asyncSources = ref.watch(videoSourcesProvider(key));

            return _buildSourceSelectorContainer(
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
                  asyncSources.when(
                    loading: () => _buildAllProvidersLoading(),
                    error: (_, __) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Could not load sources',
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    data: (data) {
                      final tiles = _providerOrder.map((providerKey) {
                        final result = data[providerKey];
                        final displayName =
                            _providerDisplayNames[providerKey] ?? providerKey;

                        // Check if provider is available (has sources or is TG)
                        final isAvailable = result != null &&
                            (result.sources.isNotEmpty || result.isTg);

                        if (!isAvailable) {
                          // Grey out unavailable providers
                          return _buildSourceOptionDisabled(displayName);
                        }

                        if (providerKey == 'tg') {
                          return _buildSourceOption(
                            displayName,
                            () => _playTg(
                              episode: episode,
                              seasonNumber: seasonNumber,
                              episodeNumber: episodeNumber,
                              setSheetState: setSheetState,
                            ),
                          );
                        }

                        return _buildSourceOption(
                          displayName,
                          () => _playMovie(
                            provider: displayName,
                            episode: episode,
                            seasonNumber: seasonNumber,
                            episodeNumber: episodeNumber,
                            setSheetState: setSheetState,
                            cachedResult: result,
                          ),
                        );
                      }).toList();

                      return Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: tiles
                            .map((tile) => SizedBox(width: 140, child: tile))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSourceSelectorContainer({required Widget child}) {
    return Container(
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
      child: child,
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

  Widget _buildAllProvidersLoading() {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: _providerOrder.map((providerKey) {
        final displayName = _providerDisplayNames[providerKey] ?? providerKey;
        return SizedBox(
          width: 140,
          child: _buildSourceOption(displayName, () {}),
        );
      }).toList(),
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

  Widget _buildSourceOptionDisabled(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        color: Colors.white.withValues(alpha: 0.02),
      ),
      child: Center(
        child: Text(
          name,
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
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
      StateSetter? setSheetState,
      ProviderSourceResult? cachedResult}) async {
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

    _setLoadingState(isTv: isTv, setSheetState: setSheetState, value: true);

    if (cachedResult != null && cachedResult.sources.isNotEmpty) {
      await _launchPlayer(
        sources: cachedResult.sources,
        captions: cachedResult.captions,
        isTv: isTv,
        actualEpisode: actualEpisode,
        provider: provider,
        headers: cachedResult.headers,
        setSheetState: setSheetState,
      );
      return;
    }

    try {
      final service = VideoSourceService();
      final kissKhService = KissKhService();
      final vidLinkService = VidLinkService();

      final futures = <Future<dynamic>>[];

      final providerKey = provider?.toLowerCase();

      if (providerKey == 'river') {
        futures.add(service.getVideoSources(
          _item.id,
          isTv ? actualEpisode.seasonNumber.toString() : '1',
          isTv ? actualEpisode.episodeNumber.toString() : '1',
          serviceName: isTv ? 'tvVideoProvider' : 'movieVideoProvider',
        ));
      } else if (providerKey == 'kisskh') {
        futures.add(kissKhService.getSources(
          widget.item.title,
          isTv ? actualEpisode.seasonNumber : 1,
          isTv ? actualEpisode.episodeNumber : 1,
        ));
      } else if (providerKey == 'vidlink') {
        futures.add(vidLinkService.getSources(
          int.tryParse(_item.id) ?? 0,
          isMovie: !isTv,
          season: isTv ? actualEpisode.seasonNumber : null,
          episode: isTv ? actualEpisode.episodeNumber : null,
        ));
      } else if (providerKey == 'videasy') {
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

      if (!mounted) return;

      if (sources.isNotEmpty) {
        await _launchPlayer(
          sources: sources,
          captions: captions,
          isTv: isTv,
          actualEpisode: actualEpisode,
          provider: provider,
          headers: (providerKey == 'river' || providerKey == null)
              ? VideoSourceService.flowCastHeaders
              : null,
          setSheetState: setSheetState,
        );
      } else {
        _setLoadingState(
            isTv: isTv, setSheetState: setSheetState, value: false);
        _showSnackBar('No stream sources found for the selected provider',
            isError: true);
      }
    } catch (e) {
      _setLoadingState(isTv: isTv, setSheetState: setSheetState, value: false);
      _showSnackBar('Error: $e', isError: true);
    }
  }

  void _setLoadingState({
    required bool isTv,
    required StateSetter? setSheetState,
    required bool value,
  }) {
    if (!mounted) return;
    if (isTv && setSheetState != null) {
      setSheetState(() => _loadingVideo = value);
    } else {
      setState(() => _loadingMovie = value);
    }
  }

  Future<void> _launchPlayer({
    required List<VideoSource> sources,
    required List<VideoCaption> captions,
    required bool isTv,
    required RiveStreamEpisode? actualEpisode,
    required String? provider,
    required Map<String, String>? headers,
    required StateSetter? setSheetState,
  }) async {
    if (!mounted) return;

    if (isTv && setSheetState != null) {
      Navigator.pop(context);
    }

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PlayerScreen(
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
          httpHeaders: headers,
          provider: provider,
        ),
        transitionDuration: const Duration(milliseconds: 800),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final cinematicCurve = CurvedAnimation(
            parent: animation,
            curve: Curves.fastOutSlowIn,
            reverseCurve: Curves.easeIn,
          );
          return FadeTransition(
            opacity: cinematicCurve,
            child: ScaleTransition(
              scale:
                  Tween<double>(begin: 1.1, end: 1.0).animate(cinematicCurve),
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

    _setLoadingState(isTv: isTv, setSheetState: setSheetState, value: false);
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
  List<TgStreamResult> _tvStreams = [];
  bool _loading = true;
  Timer? _repollTimer;

  @override
  void dispose() {
    _repollTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  void _startStatusPolling(TgService service) {
    _repollTimer?.cancel();
    _repollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _refreshStatus(service);
    });
  }

  Future<bool> _refreshStatus(TgService service) async {
    final statusResult = await service.status(widget.imdbId);

    if (!mounted) return false;

    if (statusResult == null) {
      setState(() {
        _error = 'Failed to check status';
        _loading = false;
      });
      return false;
    }

    if (!statusResult.ready) {
      setState(() {
        _error = 'Content not cached yet. Auto-retrying in 20s...';
        _loading = false;
        _qualities = statusResult.qualities;
      });
      return false;
    }

    final readyQualities =
        statusResult.qualities.where((q) => q.ready).toList();
    if (readyQualities.isEmpty) {
      setState(() {
        _error = 'No ready qualities found';
        _loading = false;
      });
      return false;
    }

    _repollTimer?.cancel();
    setState(() {
      _qualities = readyQualities;
      _loading = false;
      _error = null;
    });
    return true;
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

    if (widget.isTv && widget.season != null && widget.episode != null) {
      setState(() => _statusText = 'Fetching available streams...');

      try {
        final streams = await service.getStreams(
          widget.imdbId,
          season: widget.season,
          episode: widget.episode,
        );

        if (!mounted) return;

        if (streams.isEmpty) {
          setState(() {
            _error = 'No streams available for this episode';
            _loading = false;
          });
          return;
        }

        final qualityLabels = <String>{};
        final qualityMap = <String, int>{};

        for (final stream in streams) {
          qualityLabels.add(stream.quality);
          qualityMap[stream.quality] = (qualityMap[stream.quality] ?? 0) + 1;
        }

        final qualities = qualityLabels
            .map((label) => TgStatusQuality(
                  label: label,
                  files: qualityMap[label] ?? 1,
                  ready: true,
                ))
            .toList();

        _tvStreams = streams; // cache for use in _selectQuality

        if (qualities.length == 1) {
          await _selectQuality(qualities.first);
          return;
        }

        setState(() {
          _qualities = qualities;
          _loading = false;
        });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = 'Error fetching streams: $e';
          _loading = false;
        });
        return;
      }
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

    setState(() => _statusText = 'Checking cache status...');

    final ready = await _refreshStatus(service);
    if (!ready && mounted) {
      _startStatusPolling(service);
    }
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
    final qualityLabel = quality.label;
    final tmdbId = widget.tmdbId;
    final imdbId = widget.imdbId;
    final isTv = widget.isTv;
    final season = widget.season;
    final episode = widget.episode;

    Navigator.pop(context);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Build sources from cached TV streams so quality picker is populated
    final cachedSources = _tvStreams.isNotEmpty
        ? _tvStreams
            .where((s) => !s.quality.toLowerCase().contains('unsorted'))
            .map((s) => VideoSource(
                  url: service.getStreamUrl(s.url, s.hash),
                  quality: s.quality,
                  format: 'Stream',
                  size: 'TG',
                ))
            .toList()
        : <VideoSource>[];

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PlayerScreen(
          url: '',
          urlResolver: () async {
            // Use cached streams if available, else fetch
            final streams = _tvStreams.isNotEmpty
                ? _tvStreams
                : (!isTv && tmdbId != null)
                    ? await service.getMovieStreams(tmdbId.toString(),
                        quality: qualityLabel)
                    : await service.getStreams(imdbId,
                        season: season, episode: episode);
            if (streams.isEmpty) return null;
            final match = streams.firstWhere(
              (s) => s.quality == qualityLabel,
              orElse: () => streams.first,
            );
            return service.getStreamUrl(match.url, match.hash);
          },
          title: widget.title,
          tmdbId: widget.tmdbId,
          sources: cachedSources,
          initialQuality: qualityLabel,
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

  Future<void> _selectFile(TgMovieFile file, {String? quality}) async {
    final service = TgService();
    final messageId = file.messageId;
    final fileSize = file.fileSize;
    final selectedQuality = quality ?? _selectedQuality?.label;

    // Build sources list for quality picker (one per quality, URLs resolved lazily)
    final List<VideoSource> allSources = [];
    if (_movieResult != null) {
      for (final q in _movieResult!.qualities) {
        if (q.files.isNotEmpty) {
          allSources.add(VideoSource(
            url: '',
            quality: q.label,
            format: 'Stream',
            size: _formatFileSize(q.files.first.fileSize),
          ));
        }
      }
    }

    Navigator.pop(context);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => PlayerScreen(
          url: '',
          urlResolver: () async {
            final stream =
                await service.getMovieStreamByMessageId(messageId);
            if (stream == null) return null;
            return service.getStreamUrl(stream.url, stream.hash);
          },
          title: widget.title,
          tmdbId: widget.tmdbId,
          sources: allSources.isNotEmpty
              ? allSources
              : [
                  VideoSource(
                    url: '',
                    quality: 'Stream',
                    format: 'Stream',
                    size: _formatFileSize(fileSize),
                  )
                ],
          initialQuality: selectedQuality,
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
    return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 3.5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            child: const Icon(Icons.telegram_rounded,
                                color: Color(0xFF24A1DE), size: 28),
                          )
                              .animate()
                              .scale(
                                  duration: 600.ms, curve: Curves.easeOutBack)
                              .shimmer(delay: 1.seconds, duration: 2.seconds),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Telegram Cloud',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  _loading
                                      ? _statusText
                                      : 'High-speed cloud streams',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_selectedQuality != null || _error != null)
                            _buildHeaderButton(
                              icon: _selectedQuality != null
                                  ? Icons.arrow_back_rounded
                                  : Icons.refresh_rounded,
                              onTap: () {
                                setState(() {
                                  if (_selectedQuality != null) {
                                    _selectedQuality = null;
                                  } else {
                                    _error = null;
                                    _startFlow();
                                  }
                                });
                              },
                            ),
                          const SizedBox(width: 8),
                          _buildHeaderButton(
                            icon: Icons.close_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Main Content Area
                      if (_loading)
                        _buildLoadingState()
                      else ...[
                        if (_error != null) ...[
                          _buildErrorState(),
                          if (_qualities.isNotEmpty) const SizedBox(height: 16),
                        ],
                        if (_selectedQuality != null)
                          _buildFilesView()
                        else if (_qualities.isNotEmpty)
                          _buildQualitySelection(),
                      ],

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderButton(
      {required IconData icon, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: Colors.white70),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            const CreativeLoadingSpinner(
              size: 48,
              color: Color(0xFF24A1DE),
            ),
            const SizedBox(height: 16),
            Text(
              _statusText,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1500.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates_rounded,
              color: AppTheme.primaryColor.withValues(alpha: 0.8), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (_repollTimer?.isActive != true)
            TextButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _startFlow();
                });
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Retry',
                style: GoogleFonts.outfit(
                  color: const Color(0xFF24A1DE),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQualitySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT STREAM QUALITY',
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: _qualities.asMap().entries.map((entry) {
            final index = entry.key;
            final q = entry.value;
            final hasMultipleFiles = q.files > 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    // Main tap area — plays first/best file directly
                    Expanded(
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.03),
                        child: InkWell(
                          onTap: () => _playQualityDirect(q),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.play_circle_outline_rounded,
                                    color: Color(0xFF24A1DE), size: 14),
                                const SizedBox(width: 8),
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
                                Icon(
                                  q.ready
                                      ? Icons.check_circle_rounded
                                      : Icons.timer_rounded,
                                  size: 12,
                                  color: q.ready
                                      ? Colors.greenAccent
                                      : Colors.orangeAccent,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Arrow button — shows sub-files list (only if multiple)
                    if (hasMultipleFiles) ...[
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      Material(
                        color: Colors.white.withValues(alpha: 0.03),
                        child: InkWell(
                          onTap: () => _selectQuality(q),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${q.files}',
                                  style: GoogleFonts.outfit(
                                    color:
                                        Colors.white.withValues(alpha: 0.35),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color:
                                      Colors.white.withValues(alpha: 0.35),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
                .animate(delay: (index * 40).ms)
                .fadeIn(duration: 250.ms)
                .slideX(begin: 0.05, end: 0);
          }).toList(),
        ),
      ],
    );
  }

  /// Plays the first/best file for a quality directly without showing the file list.
  Future<void> _playQualityDirect(TgStatusQuality quality) async {
    if (_movieResult != null) {
      // Movie path: grab first file and play it
      final qFiles = _movieResult!.qualities.firstWhere(
        (q) => q.label == quality.label,
        orElse: () => _movieResult!.qualities.first,
      );
      if (qFiles.files.isNotEmpty) {
        await _selectFile(qFiles.files.first, quality: quality.label);
      }
      return;
    }
    // TV / status path: delegate to existing _selectQuality (goes straight to player)
    await _selectQuality(quality);
  }

  Widget _buildFilesView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'STREAMING FILES',
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _selectedQuality!.label,
                style: GoogleFonts.outfit(
                  color: AppTheme.primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedQuality!.files.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final file = _selectedQuality!.files[index];
            return _buildFileItem(file, index);
          },
        ),
      ],
    );
  }

  Widget _buildFileItem(TgMovieFile file, int index) {
    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _selectFile(file, quality: _selectedQuality?.label),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.movie_rounded,
                        color: Colors.white70, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      file.name,
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildFileBadge(
                    icon: Icons.storage_rounded,
                    label: _formatFileSize(file.fileSize),
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 8),
                  if (file.ready)
                    _buildFileBadge(
                      icon: Icons.check_circle_rounded,
                      label: 'CACHED',
                      color: Colors.greenAccent,
                      background: Colors.green.withValues(alpha: 0.1),
                    ),
                  const Spacer(),
                  const Icon(Icons.play_circle_fill_rounded,
                      color: Color(0xFF24A1DE), size: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: (index * 80).ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildFileBadge({
    required IconData icon,
    required String label,
    required Color color,
    Color? background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CastDetailView extends StatefulWidget {
  final CastMember member;

  const _CastDetailView({required this.member});

  @override
  State<_CastDetailView> createState() => _CastDetailViewState();
}

class _CastDetailViewState extends State<_CastDetailView> {
  List<RiveStreamMedia> _knownFor = [];

  @override
  void initState() {
    super.initState();
    _fetchKnownFor();
  }

  Future<void> _fetchKnownFor() async {
    final titles =
        await RiveStreamService().getPersonKnownForTitles(widget.member.id);
    if (mounted) setState(() => _knownFor = titles);
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final w = MediaQuery.of(context).size.width * 0.75;
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Material(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Full-bleed poster hero ──
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        transitionDuration: const Duration(milliseconds: 500),
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            SearchPage(
                          initialQuery: member.name,
                          fromCast: true,
                        ),
                        transitionsBuilder: (context, animation,
                                secondaryAnimation, child) =>
                            FadeTransition(opacity: animation, child: child),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Poster
                        member.fullProfileUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: member.fullProfileUrl
                                    .replaceAll('w185', 'original'),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 300,
                                placeholder: (_, __) => Container(
                                  height: 300,
                                  color: AppTheme.elevatedColor,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                          AppTheme.primaryColor),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  height: 300,
                                  color: AppTheme.elevatedColor,
                                  child: Icon(Icons.person,
                                      color: AppTheme.textMuted, size: 64),
                                ),
                              )
                            : Container(
                                height: 300,
                                color: AppTheme.elevatedColor,
                                child: Icon(Icons.person,
                                    color: AppTheme.textMuted, size: 64),
                              ),
                        // Deep gradient from bottom
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  AppTheme.backgroundColor
                                      .withValues(alpha: 0.6),
                                  AppTheme.backgroundColor,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Name + character
                        Positioned(
                          left: 14,
                          right: 14,
                          bottom: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.name,
                                style: GoogleFonts.outfit(
                                  color: AppTheme.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (member.character != null &&
                                  member.character!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 3,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primaryColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        member.character!,
                                        style: GoogleFonts.outfit(
                                          color: AppTheme.primaryColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Glass "Known For" section ──
                  ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                      child: Container(
                        color: AppTheme.backgroundColor,
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Label
                            Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'KNOWN FOR',
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.textMuted,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (_knownFor.isEmpty)
                              ..._shimmerItems()
                            else
                              ..._knownFor.asMap().entries.map((e) {
                                final i = e.key;
                                final item = e.value;
                                final date =
                                    item.releaseDate ?? item.firstAirDate ?? '';
                                final year = date.length >= 4
                                    ? date.substring(0, 4)
                                    : '';
                                return Column(
                                  children: [
                                    if (i > 0)
                                      Divider(
                                        height: 1,
                                        thickness: 0.5,
                                        color: AppTheme.borderColor
                                            .withValues(alpha: 0.4),
                                      ),
                                    GestureDetector(
                                      onTap: () {
                                        final imdbItem = ImdbSearchResult(
                                          id: item.id.toString(),
                                          title: item.displayTitle,
                                          posterUrl: item.fullPosterUrl,
                                          year: item.displayDate.isNotEmpty
                                              ? item.displayDate
                                                  .split('-')
                                                  .first
                                              : '',
                                          kind: item.mediaType == 'movie'
                                              ? 'movie'
                                              : 'tvseries',
                                          rating: item.voteAverage
                                              .toStringAsFixed(1),
                                          description: item.overview,
                                          backdropUrl: item.fullBackdropUrl,
                                        );
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          PageRouteBuilder(
                                            transitionDuration: const Duration(
                                                milliseconds: 400),
                                            pageBuilder: (context, animation,
                                                    secondaryAnimation) =>
                                                MediaInfoScreen(item: imdbItem),
                                            transitionsBuilder: (context,
                                                    animation,
                                                    secondaryAnimation,
                                                    child) =>
                                                FadeTransition(
                                                    opacity: animation,
                                                    child: child),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        child: Row(
                                          children: [
                                            Icon(
                                              item.mediaType == 'movie'
                                                  ? Icons.movie_outlined
                                                  : Icons.tv_outlined,
                                              size: 13,
                                              color: AppTheme.primaryColor
                                                  .withValues(alpha: 0.6),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                item.displayTitle,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.outfit(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            if (year.isNotEmpty)
                                              Text(
                                                year,
                                                style: GoogleFonts.outfit(
                                                  color: AppTheme.textMuted,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            const SizedBox(width: 4),
                                            Icon(Icons.chevron_right,
                                                size: 13,
                                                color: AppTheme.textMuted
                                                    .withValues(alpha: 0.5)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                          ],
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
  }

  List<Widget> _shimmerItems() => List.generate(
        4,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Shimmer.fromColors(
            baseColor: AppTheme.textMuted.withValues(alpha: 0.15),
            highlightColor: AppTheme.textMuted.withValues(alpha: 0.35),
            child: Container(
              height: 11,
              width: double.infinity * (0.5 + i * 0.1),
              decoration: BoxDecoration(
                color: AppTheme.textMuted,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      );
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
    final provider = context.read<AppProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _RatingOptionsPopup(
        currentRating: provider.getRating(widget.mediaId),
        onSelected: (rating, shouldClose) async {
          await provider.setRating(widget.mediaId, rating);
          if (shouldClose && context.mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final rating = provider.getRating(widget.mediaId);

    Color bgColor = Colors.white.withValues(alpha: 0.05);
    Color iconColor = Colors.white70;
    IconData materialIconData = Icons.thumb_up_rounded;
    dynamic hugeIconData = HugeIcons.strokeRoundedThumbsUp;
    bool useMaterialIcon = false;
    double iconSize = 22.0;

    switch (rating) {
      case 1: // Not for me
        bgColor = Colors.redAccent.withValues(alpha: 0.15);
        iconColor = Colors.redAccent;
        hugeIconData = HugeIcons.strokeRoundedThumbsDown;
        break;
      case 2: // I like this
        bgColor = AppTheme.primaryColor.withValues(alpha: 0.15);
        iconColor = AppTheme.primaryColor;
        hugeIconData = HugeIcons.strokeRoundedThumbsUp;
        break;
      case 3: // Love this
        bgColor = Colors.pinkAccent.withValues(alpha: 0.15);
        iconColor = Colors.pinkAccent;
        useMaterialIcon = true;
        materialIconData = Icons.favorite_rounded;
        iconSize = 26.0;
        break;
      default:
        bgColor = Colors.white.withValues(alpha: 0.05);
        iconColor = Colors.white70;
        hugeIconData = HugeIcons.strokeRoundedThumbsUp;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bgColor,
            Colors.white.withValues(alpha: 0.01),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: () => _showRatingMenu(context),
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: useMaterialIcon
              ? Icon(
                  materialIconData,
                  key: ValueKey('material_$rating'),
                  color: iconColor,
                  size: iconSize,
                )
              : HugeIcon(
                  icon: hugeIconData,
                  key: ValueKey('huge_$rating'),
                  color: iconColor,
                  size: iconSize,
                ),
        ),
        tooltip: 'Rate',
      ),
    );
  }
}

class _RatingOptionsPopup extends StatefulWidget {
  final Future<void> Function(int rating, bool shouldClose) onSelected;
  final int currentRating;

  const _RatingOptionsPopup({
    required this.onSelected,
    required this.currentRating,
  });

  @override
  State<_RatingOptionsPopup> createState() => _RatingOptionsPopupState();
}

class _RatingOptionsPopupState extends State<_RatingOptionsPopup> {
  int? selectedStars; // Track selected star rating

  @override
  void initState() {
    super.initState();
    if (widget.currentRating >= 11 && widget.currentRating <= 15) {
      selectedStars = widget.currentRating - 10;
    }
  }

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
          const SizedBox(height: 24),
          Text(
            'Star Rating',
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final isSelected = selectedStars == starValue;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: InkWell(
                  onTap: () async {
                    setState(() {
                      selectedStars = isSelected ? null : starValue;
                    });
                    await widget.onSelected(
                        starValue + 10, false); // keep sheet open
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.amber.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSelected
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: Colors.amber,
                      size: 24,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () async {
              setState(() {
                selectedStars = null;
              });
              await widget.onSelected(0, false);
            },
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
      onTap: () => widget.onSelected(value, true),
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
