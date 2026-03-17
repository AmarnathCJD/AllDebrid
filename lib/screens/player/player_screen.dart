import 'dart:async';
import 'dart:io';

import 'package:alldebrid_app/services/tg_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/providers.dart';
import '../../services/subtitlecat_service.dart';
import '../../services/cast_service.dart';
import '../../theme/app_theme.dart';
import '../../services/imdb_service.dart';
import '../../services/rivestream_service.dart';
import '../../services/video_source_service.dart';
import '../../services/vidlink_service.dart';
import '../../services/kisskh_service.dart';
import '../../services/wyzie_service.dart';
import 'package:hugeicons/hugeicons.dart';

class PlayerScreen extends StatefulWidget {
  final String url;
  final String? title;
  final bool isLocal;
  final List<VideoSource>? sources;
  final Map<String, String>? httpHeaders;
  /// When provided, the player opens immediately and waits for this future to
  /// resolve before starting playback. [url] should be empty string in this case.
  final Future<String?> Function()? urlResolver;
  /// The quality label that is currently playing (e.g. '480p'). Used to set
  /// the correct active item in the quality picker.
  final String? initialQuality;

  const PlayerScreen({
    super.key,
    required this.url,
    this.title,
    this.isLocal = false,
    this.sources,
    this.httpHeaders,
    this.initialCaptions,
    this.tmdbId,
    this.season,
    this.episode,
    this.mediaItem,
    this.provider,
    this.urlResolver,
    this.initialQuality,
  });

  final int? tmdbId;
  final int? season;
  final int? episode;
  final ImdbSearchResult? mediaItem;
  final String? provider;

  final List<VideoCaption>? initialCaptions;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _controller;
  bool _showControls = false;
  bool _isLocked = false;
  bool _isReady = false;
  bool _isPiP = false;
  BoxFit _fit = BoxFit.cover;
  final List<ExternalSubtitle> _externalSubtitles = [];
  String? _selectedExternalSubtitleUri;
  List<VideoSource> _currentSources = [];

  String _currentQuality = '720p';
  List<String> _availableQualities = [];
  bool get _isImdbTrailer => widget.url.contains('imdb-video.media-imdb.com');

  double _brightness = 0.5;
  double _volumeBoost = 100.0;
  Duration _subtitleDelay = Duration.zero;
  Duration _audioDelay = Duration.zero;

  Timer? _savePositionTimer;
  Timer? _controlsTimer;

  bool _showResumeNotif = false;
  String _resumeTime = '';
  Timer? _resumeNotifTimer;

  double _playbackSpeed = 1.0;
  Timer? _sleepTimer;
  int _sleepMinutesRemaining = 0;
  bool _isNightMode = false;
  Duration? _dragSeekTime;

  bool _isSliderDragging = false;
  double _sliderDraggingValue = 0.0;

  bool _showLeftDoubleTap = false;
  bool _showRightDoubleTap = false;
  Timer? _doubleTapTimer;
  int _leftTapCount = 0;
  int _rightTapCount = 0;
  Timer? _leftTapAccumTimer;
  Timer? _rightTapAccumTimer;

  bool _showStats = false;
  bool _wasPlayingBeforePause = false;
  late ScreenshotController _screenshotController;

  bool _fetchingNextEpisode = false;
  String _currentProvider = 'River';
  int? _currentSeason;
  int? _currentEpisode;
  String? _currentTitle;

  bool _showNotification = false;
  String _notificationMessage = '';
  Timer? _notificationTimer;

  bool _isPreFetching = false;
  bool _preFetchTriggered = false;
  List<VideoSource>? _preFetchedSources;
  List<VideoCaption>? _preFetchedCaptions;
  int? _preFetchedS;
  int? _preFetchedE;

  // Casting support
  bool _isCasting = false;
  String? _connectedDeviceName;
  List<Map<String, dynamic>> _discoveredDevices = [];
  bool _isDiscoveringDevices = false;
  Timer? _deviceDiscoveryTimer;

  // Auto-play next episode
  Timer? _autoPlayCountdownTimer;
  int _autoPlayCountdown = 0;
  bool _showAutoPlayDialog = false;
  bool _cancelAutoPlay = false;
  bool _autoPlayTriggeredForThisEpisode = false;
  StreamSubscription<Duration>? _positionSubscription;

  static const _pipChannel = MethodChannel('com.alldebrid/pip');

  void _setNativePipEnabled(bool enabled) {
    _pipChannel.invokeMethod('setPipEnabled', {'enabled': enabled});
  }

  // Subtitle styling
  Color _subtitleColor = Colors.white;

  // Swipe-up episodes list
  List<RiveStreamEpisode> _seasonEpisodes = [];
  bool _fetchingSeasonEpisodes = false;
  Map<int, List<RiveStreamEpisode>> _episodesCache = {};

  Future<void> _fetchSeasonEpisodes() async {
    if (_currentSeason == null ||
        widget.tmdbId == null ||
        _fetchingSeasonEpisodes) return;

    // Check cache first
    final cacheKey = _currentSeason!;
    if (_episodesCache.containsKey(cacheKey)) {
      setState(() => _seasonEpisodes = _episodesCache[cacheKey]!);
      _showEpisodesSheet();
      return;
    }

    setState(() => _fetchingSeasonEpisodes = true);
    try {
      final episodes = await RiveStreamService()
          .getSeasonDetails(widget.tmdbId!, _currentSeason!);
      if (mounted) {
        setState(() {
          _seasonEpisodes = episodes;
          _episodesCache[cacheKey] = episodes; // Cache the episodes
          _fetchingSeasonEpisodes = false;
        });
        if (episodes.isNotEmpty) _showEpisodesSheet();
      }
    } catch (e) {
      if (mounted) setState(() => _fetchingSeasonEpisodes = false);
      _showNotif('Failed to load episodes', seconds: 2);
    }
  }

  void _showEpisodesSheet() {
    showModalBottomSheet(
      context: context,
      useSafeArea: false,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151515).withValues(alpha: 0.85),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  'Season ${_currentSeason}',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white54, size: 20),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: _seasonEpisodes.length,
              itemBuilder: (context, index) {
                final ep = _seasonEpisodes[index];
                final isCurrent = ep.episodeNumber == _currentEpisode;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    if (ep.episodeNumber != _currentEpisode) {
                      _currentEpisode = ep.episodeNumber;
                      _playNextEpisode();
                    }
                  },
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isCurrent
                          ? AppTheme.primaryColor.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          child: Container(
                            height: 60,
                            color: AppTheme.cardColor,
                            child: ep.fullStillUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: ep.fullStillUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: AppTheme.cardColor,
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: AppTheme.cardColor,
                                      child: const Icon(Icons.movie,
                                          color: Colors.white24, size: 18),
                                    ),
                                  )
                                : Container(
                                    color: AppTheme.cardColor,
                                    child: const Icon(Icons.movie,
                                        color: Colors.white24, size: 18),
                                  ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'E${ep.episodeNumber}',
                                  style: GoogleFonts.outfit(
                                    color: isCurrent
                                        ? AppTheme.primaryColor
                                        : Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                Text(
                                  ep.name ?? 'Ep ${ep.episodeNumber}',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentSeason = widget.season;
    _currentEpisode = widget.episode;
    _currentTitle = widget.title;
    if (widget.provider != null) {
      _currentProvider = widget.provider!;
    }

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pipChannel.setMethodCallHandler((call) async {
      if (call.method == 'onPipChanged') {
        final bool inPip = call.arguments as bool;
        if (mounted) {
          setState(() {
            _isPiP = inPip;
            if (inPip) _showControls = false;
          });
        }
      }
    });

    if (widget.mediaItem != null) {
      ImdbService().addToRecents(widget.mediaItem!);
    }

    _setNativePipEnabled(true);

    _player = Player(
        configuration: const PlayerConfiguration(
      title: 'AllDebrid Player',
    ));
    _controller = VideoController(_player);
    if (widget.sources != null && widget.sources!.isNotEmpty) {
      _availableQualities = widget.sources!
          .map((s) => s.quality.toString())
          .where((q) => !q.toLowerCase().contains('unsorted'))
          .toSet()
          .toList();

      if (_availableQualities.isNotEmpty) {
        // Prefer explicitly passed initialQuality, then URL match, then first
        if (widget.initialQuality != null &&
            _availableQualities.contains(widget.initialQuality)) {
          _currentQuality = widget.initialQuality!;
        } else if (widget.url.isNotEmpty) {
          final urlMatch = widget.sources!.firstWhere(
            (s) => s.url == widget.url,
            orElse: () =>
                VideoSource(url: '', quality: '', format: '', size: ''),
          );
          if (urlMatch.quality.isNotEmpty &&
              _availableQualities.contains(urlMatch.quality)) {
            _currentQuality = urlMatch.quality;
          } else {
            _currentQuality = _availableQualities.first;
          }
        } else {
          _currentQuality = _availableQualities.first;
        }
      }
    } else if (_isImdbTrailer) {
      _availableQualities = ['1080p', '720p', '480p', '270p'];
      for (var quality in _availableQualities) {
        if (widget.url.contains('_$quality.mp4')) {
          _currentQuality = quality;
          break;
        }
      }
      // Default fallback
      _availableQualities = ['Default'];
      _currentQuality = 'Default';
    }

    _currentSources = widget.sources ?? [];
    _screenshotController = ScreenshotController();

    _initPlayer();
    _loadSubtitleSettings();
    _resetControlsTimer();
    _initBrightness();
    _initCast();
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _initCast() async {
    try {
      await CastService.initializeCast();
      print('Cast service initialized');
    } catch (e) {
      print('Error initializing cast: $e');
    }
  }

  Future<void> _takeScreenshot() async {
    try {
      final image = await _screenshotController.capture(
          delay: const Duration(milliseconds: 100));
      if (image != null) {
        final directory = Directory('/storage/emulated/0/Pictures/AllDebrid');
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final file = File('${directory.path}/screenshot_$timestamp.png');
        await file.writeAsBytes(image);
        _showNotif('Screenshot saved', seconds: 2);
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      print('Error taking screenshot: $e');
      _showNotif('Failed to save screenshot', seconds: 2);
    }
  }

  Future<void> _initBrightness() async {
    try {
      final current = await ScreenBrightness.instance.application;
      setState(() => _brightness = current);
    } catch (e) {
      print('Error getting brightness: $e');
    }
  }

  Future<void> _setBrightness(double value) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(value);
      setState(() {
        _brightness = value;
      });
    } catch (e) {
      print('Error setting brightness: $e');
    }
  }

  String get _storageKey {
    if (widget.tmdbId != null &&
        _currentSeason != null &&
        _currentEpisode != null) {
      return 'pos_tmdb_${widget.tmdbId}_s${_currentSeason}_e$_currentEpisode';
    }
    if (widget.tmdbId != null) {
      return 'pos_tmdb_${widget.tmdbId}';
    }
    if (_currentTitle != null && _currentTitle!.isNotEmpty) {
      return 'pos_${_currentTitle.hashCode}';
    }
    return 'pos_${widget.url.hashCode}';
  }

  String get _subtitlesStorageKey =>
      'subs_${_currentTitle?.hashCode ?? widget.url.hashCode}';

  Future<void> _loadPersistedSubtitles() async {
    final provider = context.read<AppProvider>();
    final subsJson = provider.getSetting<List<dynamic>>(_subtitlesStorageKey);
    if (subsJson != null) {
      for (final json in subsJson) {
        try {
          final sub = DownloadedSubtitle.fromJson(json as Map<String, dynamic>);
          // Check if file still exists
          if (await File(sub.path).exists()) {
            await _addExternalSubtitle(sub.path,
                title: sub.title, language: sub.language);
          }
        } catch (e) {
          print('Error loading subtitle: $e');
        }
      }
    }
  }

  Future<void> _savePersistedSubtitles() async {
    final provider = context.read<AppProvider>();
    final subsToSave = _externalSubtitles.map((s) {
      // Extract path from URI
      final path = Uri.parse(s.uri).toFilePath();
      return DownloadedSubtitle(
        path: path,
        title: s.title,
        language: s.language,
      ).toJson();
    }).toList();
    await provider.saveSetting(_subtitlesStorageKey, subsToSave);
  }

  Future<void> _removePersistedSubtitle(String uri) async {
    setState(() {
      _externalSubtitles.removeWhere((s) => s.uri == uri);
      if (_selectedExternalSubtitleUri == uri) {
        _selectedExternalSubtitleUri = null;
      }
    });
    await _savePersistedSubtitles();
    // Clear subtitle from player
    await _player.setSubtitleTrack(SubtitleTrack.no());
  }

  Future<void> _initPlayer() async {
    final provider = context.read<AppProvider>();
    final savedPosMs = provider.getSetting<int>(_storageKey);
    final start =
        savedPosMs != null ? Duration(milliseconds: savedPosMs) : Duration.zero;

    // If a urlResolver is provided, resolve it now (player UI is already visible)
    String resolvedUrl = widget.url;
    if (widget.urlResolver != null) {
      final fetched = await widget.urlResolver!();
      if (!mounted) return;
      if (fetched == null || fetched.isEmpty) {
        setState(() => _isReady = true);
        _showNotif('Failed to load stream URL', seconds: 3);
        return;
      }
      resolvedUrl = fetched;
    }

    Map<String, String>? headers = widget.httpHeaders;
    if (_currentSources.isNotEmpty) {
      try {
        final match = _currentSources.firstWhere(
          (s) => s.url == resolvedUrl,
          orElse: () => VideoSource(url: '', quality: '', format: '', size: ''),
        );
        if (match.url.isNotEmpty && match.headers != null) {
          headers = match.headers;
        }
      } catch (_) {}
    }

    _player.setVolume(0.0);

    await _player.open(
        Media(
          resolvedUrl,
          httpHeaders: headers,
          extras: {
            'title': _currentTitle ?? widget.title ?? 'Video',
            'artist': 'AllDebrid',
            'album': _currentSeason != null
                ? 'Season $_currentSeason'
                : 'AllDebrid Player',
            if (widget.mediaItem?.posterUrl != null &&
                widget.mediaItem!.posterUrl.isNotEmpty) ...{
              'artwork': widget.mediaItem!.posterUrl,
              'image': widget.mediaItem!.posterUrl,
              'thumbnail': widget.mediaItem!.posterUrl,
            },
            'author': 'AllDebrid',
          },
        ),
        play: true);

    if (widget.initialCaptions != null) {
      for (final caption in widget.initialCaptions!) {
        final exists = _externalSubtitles.any((s) => s.uri == caption.file);
        if (!exists) {
          _externalSubtitles.add(ExternalSubtitle(
              uri: caption.file,
              title: caption.label,
              language: caption.label.split(' - ').first.trim()));
        }
      }
    }

    await _loadPersistedSubtitles();

    // Auto-select English subtitle if available
    ExternalSubtitle? engSub;
    try {
      engSub = _externalSubtitles.firstWhere((s) =>
          s.language.toLowerCase().contains('en') ||
          s.title.toLowerCase().contains('english'));
    } catch (_) {}

    if (engSub != null) {
      _selectedExternalSubtitleUri = engSub.uri;
      _player.setSubtitleTrack(SubtitleTrack.uri(engSub.uri,
          title: engSub.title, language: engSub.language));
    }

    if (start > Duration.zero) {
      bool isReady = false;
      for (int i = 0; i < 50; i++) {
        if (_player.state.duration > Duration.zero &&
            _player.state.duration.inMilliseconds >= start.inMilliseconds) {
          isReady = true;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (isReady) {
        await Future.delayed(
            const Duration(milliseconds: 400)); // allow playback to initialize
        await _player.seek(start);

        if (mounted) {
          setState(() {
            _showResumeNotif = true;
            _resumeTime = _formatDuration(start);
          });
          _resumeNotifTimer?.cancel();
          _resumeNotifTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _showResumeNotif = false);
          });
        }
      }
    }

    _player.setVolume(_volumeBoost);

    if (mounted) setState(() => _isReady = true);

    _savePositionTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _savePosition());

    // Listen for video completion and trigger auto-play
    if (widget.episode != null) {
      _initPositionListener();
    }
  }

  Future<void> _savePosition() async {
    if (!mounted || _player.state.duration == Duration.zero) return;
    final currentPos = _player.state.position.inMilliseconds;
    final duration = _player.state.duration.inMilliseconds;
    if (currentPos > 5000) {
      await context.read<AppProvider>().saveSetting(_storageKey, currentPos);
      if (widget.mediaItem != null) {
        await ImdbService().saveWatchProgress(
          widget.mediaItem!,
          currentPos,
          duration,
        );
      }
    }
  }

  void _loadSubtitleSettings() {
    final provider = context.read<AppProvider>();
    final colorHex = provider.getSetting<int>('subtitle_color');
    if (colorHex != null) {
      setState(() {
        _subtitleColor = Color(colorHex);
      });
    }
  }

  void _setSubtitleColor(Color color) {
    setState(() => _subtitleColor = color);
    context.read<AppProvider>().saveSetting('subtitle_color', color.toARGB32());
  }

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    if (_showControls && !_player.state.playing) return;

    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _player.state.playing && !_isLocked) {
        setState(() => _showControls = false);
      }
    });
  }

  void _setVolumeBoost(double value) {
    setState(() {
      _volumeBoost = value;
      _player.setVolume(value);
    });
  }

  void _adjustSync(Duration delta) {
    setState(() {
      _subtitleDelay += delta;
    });
    final seconds = _subtitleDelay.inMilliseconds / 1000.0;
    (_player.platform as dynamic).setProperty('sub-delay', seconds.toString());
  }

  void _adjustAudioSync(Duration delta) {
    setState(() {
      _audioDelay += delta;
    });
    final seconds = _audioDelay.inMilliseconds / 1000.0;
    (_player.platform as dynamic)
        .setProperty('audio-delay', seconds.toString());
  }

  void _setPlaybackSpeed(double speed) {
    setState(() => _playbackSpeed = speed);
    _player.setRate(speed);
  }

  void _toggleNightMode() {
    setState(() {
      _isNightMode = !_isNightMode;
      final filter = _isNightMode ? 'acompressor=ratio=4' : '';
      try {
        (_player.platform as dynamic).setProperty('af', filter);
      } catch (e) {
        debugPrint('Error setting audio filter: $e');
      }
    });
  }

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    setState(() {
      _sleepMinutesRemaining = minutes;
    });

    if (minutes > 0) {
      _sleepTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        if (_sleepMinutesRemaining <= 1) {
          timer.cancel();
          _player.pause();
          if (mounted) Navigator.pop(context);
        } else {
          setState(() {
            _sleepMinutesRemaining--;
          });
        }
      });
    }
  }

  void _seekRelative(Duration delta) {
    if (!_isReady) return;

    final newPos = _player.state.position + delta;
    final duration = _player.state.duration;
    if (newPos < Duration.zero) {
      _player.seek(Duration.zero);
    } else if (newPos > duration) {
      _player.seek(duration);
    } else {
      _player.seek(newPos);
    }

    if (delta.isNegative) {
      _leftTapAccumTimer?.cancel();
      setState(() {
        _leftTapCount++;
        _showLeftDoubleTap = true;
        _showRightDoubleTap = false;
      });
      _leftTapAccumTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _showLeftDoubleTap = false;
            _leftTapCount = 0;
          });
        }
      });
    } else {
      _rightTapAccumTimer?.cancel();
      setState(() {
        _rightTapCount++;
        _showLeftDoubleTap = false;
        _showRightDoubleTap = true;
      });
      _rightTapAccumTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _showRightDoubleTap = false;
            _rightTapCount = 0;
          });
        }
      });
    }
  }

  void _toggleStats() {
    setState(() => _showStats = !_showStats);
  }

  void _showNotif(String message, {int seconds = 3}) {
    if (mounted) {
      setState(() {
        _showNotification = true;
        _notificationMessage = message;
      });
      _notificationTimer?.cancel();
      _notificationTimer = Timer(Duration(seconds: seconds), () {
        if (mounted) setState(() => _showNotification = false);
      });
    }
  }

  Future<void> _discoverCastDevices() async {
    if (_isDiscoveringDevices) return;

    setState(() => _isDiscoveringDevices = true);
    try {
      final devices = await CastService.discoverDevices();
      if (mounted) {
        setState(() {
          _discoveredDevices = devices;
          _isDiscoveringDevices = false;
        });
      }
    } catch (e) {
      print('Error discovering devices: $e');
      if (mounted) setState(() => _isDiscoveringDevices = false);
    }
  }

  void _showCastDialog() {
    _discoverCastDevices();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.6),
          title: Text(
            'CAST',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isCasting && _connectedDeviceName != null)
                  Card(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedRss,
                            color: AppTheme.primaryColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Connected: $_connectedDeviceName',
                              style: GoogleFonts.outfit(
                                color: AppTheme.primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_isDiscoveringDevices)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          height: 30,
                          width: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Discovering devices...',
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_discoveredDevices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'No devices found. Make sure your Cast device is on the same network.',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Text(
                    'Available Devices',
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 12),
                if (_isCasting)
                  InkWell(
                    onTap: () => _stopCasting(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedCancelCircle,
                            color: Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Stop Casting',
                            style: GoogleFonts.outfit(
                              color: Colors.red,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (!_isDiscoveringDevices &&
                    _discoveredDevices.isNotEmpty)
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _discoveredDevices.length,
                      itemBuilder: (context, index) {
                        final device = _discoveredDevices[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildCastDeviceOption(
                            device['name'] as String,
                            _getDeviceIcon(device['type'] as String),
                            () => _connectToDevice(
                              device['name'] as String,
                              device['address'] as String,
                              context,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'CLOSE',
                style: GoogleFonts.outfit(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  dynamic _getDeviceIcon(String type) {
    if (type.contains('Chromecast')) return HugeIcons.strokeRoundedRss;
    if (type.contains('TV')) return HugeIcons.strokeRoundedTv02;
    if (type.contains('PC') || type.contains('Windows')) {
      return HugeIcons.strokeRoundedTv01;
    }
    if (type.contains('AirPlay')) return HugeIcons.strokeRoundedAirdrop;
    return HugeIcons.strokeRoundedRss;
  }

  Widget _buildCastDeviceOption(
    String name,
    dynamic icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: icon,
              color: AppTheme.primaryColor,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white38,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectToDevice(
    String deviceName,
    String deviceAddress,
    BuildContext context,
  ) async {
    Navigator.pop(context);
    _showNotif('Connecting to $deviceName...', seconds: 2);

    try {
      final connected =
          await CastService.connectToDevice(deviceName, deviceAddress);

      if (connected) {
        // Start casting the current video
        final title = _currentTitle ?? widget.title ?? 'Video';
        final castSuccess = await CastService.startCasting(widget.url, title);

        if (castSuccess) {
          setState(() {
            _isCasting = true;
            _connectedDeviceName = deviceName;
          });
          _showNotif('Connected to $deviceName and casting', seconds: 3);
        } else {
          _showNotif('Failed to start casting', seconds: 3);
        }
      } else {
        _showNotif('Failed to connect to $deviceName', seconds: 3);
      }
    } catch (e) {
      print('Error connecting to device: $e');
      _showNotif('Error: $e', seconds: 3);
    }
  }

  Future<void> _stopCasting(BuildContext context) async {
    Navigator.pop(context);

    try {
      await CastService.stopCasting();
      setState(() {
        _isCasting = false;
        _connectedDeviceName = null;
      });
      _showNotif('Casting stopped', seconds: 2);
    } catch (e) {
      print('Error stopping cast: $e');
      _showNotif('Error stopping cast', seconds: 2);
    }
  }

  void _showPlaybackSettings() {
    showDialog(
      context: context,
      builder: (context) => _PlaybackSettingsDialog(
        currentSpeed: _playbackSpeed,
        onSpeedChanged: _setPlaybackSpeed,
        isNightMode: _isNightMode,
        onNightModeToggle: _toggleNightMode,
        sleepMinutes: _sleepMinutesRemaining,
        onSleepTimerChanged: _setSleepTimer,
        currentBoost: _volumeBoost,
        onBoostChanged: _setVolumeBoost,
        audioDelay: _audioDelay,
        onAudioSyncChanged: _adjustAudioSync,
        subtitleDelay: _subtitleDelay,
        onSubtitleSyncChanged: _adjustSync,
        subtitleColor: _subtitleColor,
        onSubtitleColorChanged: _setSubtitleColor,
        onSelectProvider: _showProviderSelector,
        showStats: _showStats,
        onToggleStats: _toggleStats,
        onShareLink: () => Share.share(widget.url),
      ),
    );
  }

  void _showSpeedSelector() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 0),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping the dialog itself
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PLAYBACK SPEED',
                      style: GoogleFonts.outfit(
                        color: AppTheme.primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                        final isSelected = _playbackSpeed == speed;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _setPlaybackSpeed(speed);
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.white.withValues(alpha: 0.08),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : Colors.white.withValues(alpha: 0.15),
                                  width: 1.2,
                                ),
                                boxShadow: [],
                              ),
                              child: Text(
                                '${speed}x',
                                style: GoogleFonts.outfit(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ).animate().scale(
                                  begin: const Offset(0.95, 0.95),
                                  end: const Offset(1.0, 1.0),
                                  duration: 200.ms,
                                  curve: Curves.easeOut,
                                ),
                          ),
                        );
                      }).toList(),
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

  Widget _buildStatsOverlay() {
    final state = _player.state;
    final video = state.track.video;
    final audio = state.track.audio;

    return Positioned(
      top: 40,
      left: 40,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "STATS FOR NERDS",
              style: GoogleFonts.robotoMono(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            _buildStatRow("Resolution", "${state.width} x ${state.height}"),
            _buildStatRow("Video Codec", video.codec ?? "Unknown"),
            _buildStatRow("Audio Codec", audio.codec ?? "Unknown"),
            _buildStatRow("Bitrate", "${(state.rate * 100).toInt()}%"),
            _buildStatRow("Buffer", state.buffering ? "Buffering" : "Healthy"),
            _buildStatRow("Position", _formatDuration(state.position)),
            _buildStatRow("Dropped Frames",
                "0"), // Not exposed by media_kit directly usually
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.robotoMono(fontSize: 10),
          children: [
            TextSpan(
                text: "$label: ",
                style: const TextStyle(color: Colors.white70)),
            TextSpan(
                text: value,
                style: const TextStyle(
                    color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _savePosition();
    _savePositionTimer?.cancel();
    _controlsTimer?.cancel();
    _resumeNotifTimer?.cancel();
    _notificationTimer?.cancel();
    _doubleTapTimer?.cancel();
    _leftTapAccumTimer?.cancel();
    _rightTapAccumTimer?.cancel();
    _autoPlayCountdownTimer?.cancel();
    _deviceDiscoveryTimer?.cancel();
    _positionSubscription?.cancel();

    // Stop casting if active
    if (_isCasting) {
      CastService.stopCasting().ignore();
    }

    _player.dispose();
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    ScreenBrightness.instance.resetApplicationScreenBrightness();
    _setNativePipEnabled(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_player.state.duration > Duration.zero && !_isCasting) {
          if (_wasPlayingBeforePause) {
            _player.play();
          }
        }
        break;
      case AppLifecycleState.paused:
        // App goes to background - save player state
        _wasPlayingBeforePause = _player.state.playing;
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _toggleControls() {
    if (_isLocked || _isPiP) return; // Don't show controls in PiP mode
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetControlsTimer();
  }

  void _lockScreen() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLocked = true;
      _showControls = false;
    });
  }

  void _unlockScreen() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isLocked = false;
      _showControls = true;
    });
    _resetControlsTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: _isReady
                ? Screenshot(
                    controller: _screenshotController,
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: 4.0,
                      child: Video(
                        controller: _controller,
                        fit: _fit,
                        controls: (state) => const SizedBox.shrink(),
                        subtitleViewConfiguration: SubtitleViewConfiguration(
                          style: TextStyle(
                            fontSize: 54.0,
                            fontWeight: FontWeight.bold,
                            color: _subtitleColor,
                            shadows: const [
                              Shadow(
                                offset: Offset(0, 0),
                                blurRadius: 10.0,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      Container(color: Colors.black),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Animate(
                              effects: [
                                FadeEffect(duration: 800.ms),
                                ScaleEffect(
                                    begin: const Offset(0.8, 0.8),
                                    end: const Offset(1.0, 1.0)),
                              ],
                              child: const SizedBox(
                                width: 48,
                                height: 48,
                                child: CircularProgressIndicator(
                                  color: AppTheme.primaryColor,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),

          // 2. Dimmer Layer (Behind Gestures)
          if (_isReady && !_isLocked && !_isPiP)
            IgnorePointer(
              ignoring: true,
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: Container(color: Colors.black26),
              ),
            ),

          if (!_isLocked && !_isPiP)
            Row(
              children: [
                // Left Zone (Brightness + Seek -10s on rapid tap)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragUpdate: (details) {
                      final delta = details.primaryDelta ?? 0;
                      final newBrightness =
                          (_brightness - delta / 300).clamp(0.0, 1.0);
                      _setBrightness(newBrightness);
                    },
                    onTap: _toggleControls,
                    onDoubleTap: () =>
                        _seekRelative(const Duration(seconds: -10)),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Center Zone (Toggle controls + double-tap play/pause)
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onDoubleTap: () {
                      HapticFeedback.selectionClick();
                      _player.playOrPause();
                    },
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Right Zone (Seek +10s on rapid tap)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    onDoubleTap: () =>
                        _seekRelative(const Duration(seconds: 10)),
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
            ),

          if (!_isLocked && !_isPiP) ...[
            Positioned.fill(
              child: Stack(
                children: [
                  // Left seek indicator at 2/8 (25%) from left
                  Align(
                    alignment: const Alignment(-0.5, 0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: _showLeftDoubleTap
                          ? Container(
                              key: ValueKey(_leftTapCount),
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.fast_rewind_rounded,
                                      color: Colors.white, size: 24),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_leftTapCount * 10}s',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('left-hidden')),
                    ),
                  ),
                  // Right seek indicator at 6/8 (75%) from left
                  Align(
                    alignment: const Alignment(0.5, 0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: _showRightDoubleTap
                          ? Container(
                              key: ValueKey(_rightTapCount),
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.fast_forward_rounded,
                                      color: Colors.white, size: 24),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_rightTapCount * 10}s',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('right-hidden')),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Stats Layout (Top Left)
          if (_showStats && !_isPiP) _buildStatsOverlay(),

          // 4. Lock Screen Handler (When Locked)
          if (_isLocked && !_isPiP)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => setState(() => _showControls = !_showControls),
                child: Container(color: Colors.transparent),
              ),
            ),

          // 5. Controls UI (Buttons rely on this being top)
          // Hide controls completely in PiP mode
          if (_isReady && !_isLocked && !_isPiP)
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_showControls, // Ignore if hidden
                child: Stack(
                  children: [
                    // We removed the Container(color:black26) from here because it was blocking gestures.
                    // It is now in Layer 2.

                    if (_islockedUI())
                      _buildLockedUI()
                    else ...[
                      _buildTopBar(),
                      _buildBottomBar(),
                      _buildVerticalBrightnessSlider(),
                      _buildLockBtn(),
                    ]
                  ],
                ),
              ),
            ),

          // Locked UI
          if (_isReady && _isLocked && _showControls && !_isPiP)
            _buildLockedUI(),

          if (_showNotification && !_isPiP) _buildNotification(),
        ],
      ),
    );
  }

  Widget _buildNotification() {
    return Positioned(
      top: 60,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_fetchingNextEpisode) ...[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                _notificationMessage,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _islockedUI() {
    return _isLocked && _showControls;
  }

  Widget _buildLockedUI() {
    return Positioned(
      right: 22,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: IconButton(
            onPressed: _unlockScreen,
            tooltip: 'Unlock Controls',
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedLockSync01,
            ),
            color: Colors.white,
            iconSize: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String text,
    Color accent = AppTheme.primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: accent),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBlock() {
    final title = _currentTitle ?? widget.title ?? 'Video';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Column(
          key: ValueKey(
              '$title|$_showResumeNotif|$_resumeTime|$_isCasting|$_playbackSpeed|$_currentQuality'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    shadows: const [
                      Shadow(blurRadius: 12, color: Colors.black),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_showResumeNotif) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Resumed from $_resumeTime',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (_playbackSpeed != 1.0)
                      _buildMetaChip(
                        icon: Icons.speed_rounded,
                        text: '${_playbackSpeed.toStringAsFixed(2)}x',
                      ),
                    if (_isCasting)
                      _buildMetaChip(
                        icon: Icons.cast_connected_rounded,
                        text: _connectedDeviceName ?? 'Casting',
                        accent: AppTheme.primaryColor,
                      ),
                  ],
                ),
              ],
            ),
          ]),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.88),
              Colors.black.withValues(alpha: 0.22),
              Colors.transparent,
            ],
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: SafeArea(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 80),
                  child: _buildTitleBlock(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Screenshot Button
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: IconButton(
                        onPressed: _takeScreenshot,
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCamera02,
                          color: Colors.white,
                          size: 22.0,
                        ),
                        iconSize: 22,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        tooltip: 'Screenshot',
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quality Picker Button
                    if (_availableQualities.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: IconButton(
                          onPressed: _showQualityPicker,
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedHdd,
                            color: Colors.white,
                            size: 22.0,
                          ),
                          iconSize: 22,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: 'Quality',
                        ),
                      ),
                    if (_availableQualities.isNotEmpty)
                      const SizedBox(width: 8),
                    // Episodes Button - only for TV shows
                    if (widget.episode != null)
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: IconButton(
                          onPressed: () async {
                            await _fetchSeasonEpisodes();
                          },
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedPlayList,
                            color: Colors.white,
                            size: 22.0,
                          ),
                          iconSize: 22,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: 'Episodes',
                        ),
                      ),
                    if (widget.episode != null) const SizedBox(width: 8),
                    // Cast Button
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      child: IconButton(
                        onPressed: _showCastDialog,
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedRss,
                          color:
                              _isCasting ? AppTheme.primaryColor : Colors.white,
                          size: 22.0,
                        ),
                        iconSize: 22,
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        tooltip: 'Cast',
                      ),
                    ),
                    if (widget.episode != null) const SizedBox(width: 8),
                    // Next Episode/Skip Button - only for TV shows
                    if (widget.episode != null)
                      _fetchingNextEpisode
                          ? Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              width: 40,
                              height: 40,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : StreamBuilder<Duration>(
                              stream: _player.stream.position,
                              builder: (context, snapshot) {
                                final pos = snapshot.data ?? Duration.zero;
                                final dur = _player.state.duration;
                                final isNearEnd = dur.inMilliseconds > 0 &&
                                    pos.inMilliseconds >=
                                        (dur.inMilliseconds * 0.98);

                                return Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.1),
                                  ),
                                  child: IconButton(
                                    onPressed: _playNextEpisode,
                                    icon: HugeIcon(
                                      icon: HugeIcons.strokeRoundedNext,
                                      color: isNearEnd
                                          ? AppTheme.primaryColor
                                          : Colors.white,
                                      size: 22.0,
                                    ),
                                    tooltip: 'Next Episode',
                                    iconSize: 22,
                                    padding: const EdgeInsets.all(6),
                                    constraints: const BoxConstraints(),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                    ),
                                  )
                                      .animate(
                                        onPlay: (controller) =>
                                            controller.repeat(reverse: true),
                                      )
                                      .scale(
                                        end: Offset(isNearEnd ? 1.15 : 1.0,
                                            isNearEnd ? 1.15 : 1.0),
                                        duration: 600.ms,
                                      )
                                      .tint(
                                          color: AppTheme.primaryColor,
                                          end: isNearEnd ? 0.7 : 0.0),
                                );
                              },
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

  Future<void> _preFetchNextEpisode() async {
    if (_currentSeason == null || _currentEpisode == null || _isPreFetching) {
      return;
    }

    _isPreFetching = true;
    try {
      var nextS = _currentSeason!;
      var nextE = _currentEpisode! + 1;

      // Check metadata
      if (widget.tmdbId != null) {
        try {
          final rive = RiveStreamService();
          var sDetails = await rive.getSeasonDetails(widget.tmdbId!, nextS);
          var hasNextEp = sDetails.any((e) => e.episodeNumber == nextE);
          if (!hasNextEp) {
            nextS++;
            nextE = 1;
            try {
              sDetails = await rive.getSeasonDetails(widget.tmdbId!, nextS);
              hasNextEp = sDetails.any((e) => e.episodeNumber == nextE);
            } catch (_) {
              hasNextEp = false;
            }
          }
          if (!hasNextEp) {
            _isPreFetching = false;
            return;
          }
        } catch (_) {
          _isPreFetching = false;
          return;
        }
      }

      print(
          '[PreFetch] Starting pre-fetch for S$nextS E$nextE using $_currentProvider');

      final searchTitle = _currentTitle
              ?.replaceAll(
                  RegExp(r'\s*[-\s]*S\d+E\d+.*$', caseSensitive: false), '')
              .trim() ??
          "Video";

      List<VideoSource> sources = [];
      List<VideoCaption> captions = [];

      Map<String, dynamic>? data;
      if (_currentProvider == 'TG') {
        try {
          final tgService = TgService();
          final imdbId = widget.mediaItem?.id ?? '';
          final streams =
              await tgService.getStreams(imdbId, season: nextS, episode: nextE);

          if (streams.isNotEmpty) {
            final qualityOrder = ['1080p', '720p', '480p', '360p', '240p'];
            streams.sort((a, b) {
              final aIdx = qualityOrder.indexOf(a.quality);
              final bIdx = qualityOrder.indexOf(b.quality);
              return (aIdx == -1 ? 999 : aIdx)
                  .compareTo(bIdx == -1 ? 999 : bIdx);
            });
            sources = streams
                .map((s) => VideoSource(
                      url: tgService.getStreamUrl(s.url, s.hash),
                      quality: s.quality,
                      format: 'Stream',
                      size: 'TG',
                    ))
                .toList();
          }
        } catch (e) {
          print('[PreFetch] TG error: $e');
        }
      } else if (_currentProvider == 'River') {
        data = await VideoSourceService().getVideoSources(
            widget.tmdbId.toString(), nextS.toString(), nextE.toString());
      } else if (_currentProvider == 'VidLink') {
        data = await VidLinkService().getSources(widget.tmdbId!,
            isMovie: false, season: nextS, episode: nextE);
      } else if (_currentProvider == 'KissKh') {
        data = await KissKhService().getSources(searchTitle, nextS, nextE);
      } else if (_currentProvider == 'VidEasy') {
        data = await VidEasyService().getSources(
            searchTitle, widget.mediaItem?.year ?? '2020', widget.tmdbId ?? 0,
            isMovie: false, season: nextS, episode: nextE);
      }

      if (data != null) {
        sources = List<VideoSource>.from(data['sources'] ?? []);
        captions = List<VideoCaption>.from(data['captions'] ?? []);
      }

      // Pre-fetch fallback
      if (sources.isEmpty) {
        final fallbacks = ['River', 'VidLink', 'VidEasy', 'KissKh']
          ..remove(_currentProvider);
        for (final p in fallbacks) {
          print('[PreFetch] Falling back to $p...');
          Map<String, dynamic>? res;
          if (p == 'River' && widget.tmdbId != null) {
            res = await VideoSourceService().getVideoSources(
                widget.tmdbId.toString(), nextS.toString(), nextE.toString());
          } else if (p == 'VidLink' && widget.tmdbId != null) {
            res = await VidLinkService().getSources(widget.tmdbId!,
                isMovie: false, season: nextS, episode: nextE);
          } else if (p == 'KissKh') {
            res = await KissKhService().getSources(searchTitle, nextS, nextE);
          } else if (p == 'VidEasy') {
            res = await VidEasyService().getSources(searchTitle,
                widget.mediaItem?.year ?? '2020', widget.tmdbId ?? 0,
                isMovie: false, season: nextS, episode: nextE);
          }
          if (res != null) {
            final newSources = List<VideoSource>.from(res['sources'] ?? []);
            if (newSources.isNotEmpty) {
              sources = newSources;
              captions = List<VideoCaption>.from(res['captions'] ?? []);
              break;
            }
          }
        }
      }

      if (sources.isNotEmpty) {
        _preFetchedSources = sources;
        _preFetchedCaptions = captions;
        _preFetchedS = nextS;
        _preFetchedE = nextE;
        print('[PreFetch] Success! Pre-loaded ${sources.length} sources');
      }
    } finally {
      _isPreFetching = false;
    }
  }

  Future<void> _switchToNewEpisode(int nextS, int nextE,
      List<VideoSource> sources, List<VideoCaption> captions) async {
    final newUrl = sources.first.url;
    Map<String, String>? headers = sources.first.headers ?? widget.httpHeaders;

    _savePosition();
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _autoPlayCountdownTimer?.cancel();

    if (mounted) {
      setState(() {
        _currentSources = sources;
        _availableQualities = sources
            .map((s) => s.quality.toString())
            .where((q) => !q.toLowerCase().contains('unsorted'))
            .toSet()
            .toList();
        if (_availableQualities.isNotEmpty) {
          _currentQuality = _availableQualities.first;
        }
        _currentSeason = nextS;
        _currentEpisode = nextE;
        _showAutoPlayDialog = false;
        _cancelAutoPlay = false;
        _autoPlayTriggeredForThisEpisode = false;
        _preFetchTriggered = false;

        final baseTitle = widget.title
                ?.replaceAll(RegExp(r'\s*[-\s]*S\d+E\d+.*$'), '')
                .trim() ??
            "Video";
        _currentTitle = '$baseTitle S${nextS}E$nextE';

        _externalSubtitles.clear();
        for (final caption in captions) {
          _externalSubtitles.add(ExternalSubtitle(
              uri: caption.file,
              title: caption.label,
              language: caption.label.split(' - ').first.trim()));
        }
        _fetchingNextEpisode = false;
        _isReady = false; // Trigger reload overlay
      });
    }

    _player.setVolume(0.0);
    await _player.open(
        Media(newUrl, httpHeaders: headers, extras: {
          'title': _currentTitle ?? 'Video',
          'artist': 'AllDebrid',
          'album': 'Season $nextS',
          if (widget.mediaItem?.posterUrl != null)
            'artwork': widget.mediaItem!.posterUrl,
        }),
        play: true);

    _player.setVolume(_volumeBoost);
    if (mounted) setState(() => _isReady = true);

    // Re-init position listener
    _initPositionListener();
  }

  void _initPositionListener() {
    _positionSubscription?.cancel();
    _positionSubscription = _player.stream.position.listen((position) {
      final duration = _player.state.duration;
      if (duration > Duration.zero) {
        final isNearEnd =
            position.inMilliseconds >= duration.inMilliseconds - 100;
        final isNearPreFetch =
            position.inMilliseconds >= duration.inMilliseconds - (300 * 1000);

        if (isNearPreFetch && !_preFetchTriggered && !_fetchingNextEpisode) {
          _preFetchTriggered = true;
          _preFetchNextEpisode();
        }
        if (isNearEnd &&
            !_showAutoPlayDialog &&
            !_cancelAutoPlay &&
            !_autoPlayTriggeredForThisEpisode &&
            !_fetchingNextEpisode) {
          _startAutoPlayCountdown();
        }
      }
    });
  }

  void _startAutoPlayCountdown() {
    if (!mounted || _showAutoPlayDialog) return;

    setState(() {
      _showAutoPlayDialog = true;
      _autoPlayCountdown = 5; // 5 second blink
      _cancelAutoPlay = false;
    });

    _autoPlayCountdownTimer?.cancel();
    _autoPlayCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _autoPlayCountdown--;
      });

      if (_autoPlayCountdown <= 0) {
        timer.cancel();
        if (!_cancelAutoPlay) {
          _playNextEpisode();
        }
        setState(() => _showAutoPlayDialog = false);
      }
    });

    // Show minimal notification
    _showNotif('Next episode playing...', seconds: 5);
  }

  Future<void> _playNextEpisode() async {
    if (_currentSeason == null || _currentEpisode == null) {
      _showNotif('Cannot determine next episode info');
      return;
    }

    final needsTmdb = ['River', 'VidLink'];
    if (needsTmdb.contains(_currentProvider) && widget.tmdbId == null) {
      _showNotif('Next episode requires TMDB ID');
      return;
    }

    setState(() => _fetchingNextEpisode = true);

    try {
      var nextS = _currentSeason!;
      var nextE = _currentEpisode! + 1;

      // USE PRE-FETCHED DATA IF AVAILABLE
      if (_preFetchedSources != null &&
          _preFetchedSources!.isNotEmpty &&
          _preFetchedS == nextS &&
          _preFetchedE == nextE) {
        print('[AutoPlay] Using pre-fetched sources for S$nextS E$nextE');
        final sources = _preFetchedSources!;
        final captions = List<VideoCaption>.from(_preFetchedCaptions ?? []);

        _preFetchedSources = null;
        _preFetchedCaptions = null;
        _preFetchedS = null;
        _preFetchedE = null;
        _preFetchTriggered = false;

        setState(() => _fetchingNextEpisode = false);
        _switchToNewEpisode(nextS, nextE, sources, captions);
        return;
      }

      // If no pre-fetch, proceed
      if (widget.tmdbId != null) {
        try {
          final rive = RiveStreamService();
          var sDetails = await rive.getSeasonDetails(widget.tmdbId!, nextS);
          var hasNextEp = sDetails.any((e) => e.episodeNumber == nextE);
          if (!hasNextEp) {
            nextS++;
            nextE = 1;
            try {
              sDetails = await rive.getSeasonDetails(widget.tmdbId!, nextS);
              hasNextEp = sDetails.any((e) => e.episodeNumber == nextE);
            } catch (_) {
              hasNextEp = false;
            }
          }
          if (!hasNextEp) {
            setState(() => _fetchingNextEpisode = false);
            _showNotif('No next episode found');
            return;
          }
        } catch (e) {
          print('Error checking metadata: $e');
        }
      }

      List<VideoSource> sources = [];
      List<VideoCaption> captions = [];
      final searchTitle = _currentTitle
              ?.replaceAll(
                  RegExp(r'\s*[-\s]*S\d+E\d+.*$', caseSensitive: false), '')
              .trim() ??
          "Video";

      // Handle TG (Telegram) provider
      if (_currentProvider == 'TG') {
        try {
          final tgService = TgService();
          final imdbId = widget.mediaItem?.id ?? '';
          final streams =
              await tgService.getStreams(imdbId, season: nextS, episode: nextE);

          if (streams.isNotEmpty) {
            final qualityOrder = ['1080p', '720p', '480p', '360p', '240p'];
            streams.sort((a, b) {
              final aIdx = qualityOrder.indexOf(a.quality);
              final bIdx = qualityOrder.indexOf(b.quality);
              return (aIdx == -1 ? 999 : aIdx)
                  .compareTo(bIdx == -1 ? 999 : bIdx);
            });
            // Include all quality streams so quality picker is populated
            sources = streams
                .map((s) => VideoSource(
                      url: tgService.getStreamUrl(s.url, s.hash),
                      quality: s.quality,
                      format: 'Stream',
                      size: 'TG',
                    ))
                .toList();
          }
        } catch (e) {
          print('[TG] Error fetching streams: $e');
        }
      }

      Map<String, dynamic>? data;
      if (_currentProvider == 'River') {
        data = await VideoSourceService().getVideoSources(
            widget.tmdbId.toString(), nextS.toString(), nextE.toString());
      } else if (_currentProvider == 'VidLink') {
        data = await VidLinkService().getSources(widget.tmdbId!,
            isMovie: false, season: nextS, episode: nextE);
      } else if (_currentProvider == 'KissKh') {
        data = await KissKhService().getSources(searchTitle, nextS, nextE);
      } else if (_currentProvider == 'VidEasy') {
        data = await VidEasyService().getSources(
            searchTitle, widget.mediaItem?.year ?? '2020', widget.tmdbId ?? 0,
            isMovie: false, season: nextS, episode: nextE);
      }

      if (data != null) {
        sources = List<VideoSource>.from(data['sources'] ?? []);
        captions = List<VideoCaption>.from(data['captions'] ?? []);
      }

      // 2. FALLBACK
      if (sources.isEmpty) {
        final fallbacks = ['River', 'VidLink', 'VidEasy', 'KissKh']
          ..remove(_currentProvider);
        for (final p in fallbacks) {
          print('[AutoPlay] Falling back to $p...');
          Map<String, dynamic>? res;
          if (p == 'River' && widget.tmdbId != null) {
            res = await VideoSourceService().getVideoSources(
                widget.tmdbId.toString(), nextS.toString(), nextE.toString());
          } else if (p == 'VidLink' && widget.tmdbId != null) {
            res = await VidLinkService().getSources(widget.tmdbId!,
                isMovie: false, season: nextS, episode: nextE);
          } else if (p == 'KissKh') {
            res = await KissKhService().getSources(searchTitle, nextS, nextE);
          } else if (p == 'VidEasy') {
            res = await VidEasyService().getSources(searchTitle,
                widget.mediaItem?.year ?? '2020', widget.tmdbId ?? 0,
                isMovie: false, season: nextS, episode: nextE);
          }
          if (res != null) {
            final newSources = List<VideoSource>.from(res['sources'] ?? []);
            if (newSources.isNotEmpty) {
              sources = newSources;
              captions = List<VideoCaption>.from(res['captions'] ?? []);
              break;
            }
          }
        }
      }

      if (sources.isEmpty) {
        setState(() => _fetchingNextEpisode = false);
        _showNotif('No stream found for next episode');
        return;
      }

      _switchToNewEpisode(nextS, nextE, sources, captions);
    } catch (e) {
      print('Error playing next episode: $e');
      setState(() => _fetchingNextEpisode = false);
    }
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black, Colors.transparent],
              stops: [0.0, 1.0]),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Scrubber & Time
              StreamBuilder<Duration>(
                  stream: _player.stream.position,
                  initialData: _player.state.position,
                  builder: (context, snapshot) {
                    final pos = snapshot.data ?? Duration.zero;
                    final dur = _player.state.duration;

                    return Column(
                      children: [
                        // Timeline Preview (shows above progress bar when dragging)
                        if (_isSliderDragging)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDuration(_dragSeekTime ?? Duration.zero),
                              style: GoogleFonts.outfit(
                                color: Colors.black,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        Row(
                          children: [
                            Text(_formatDuration(pos),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Stack(
                                children: [
                                  // Buffer Bar
                                  Positioned.fill(
                                    top: 23, // Align with slider track
                                    bottom: 23,
                                    child: StreamBuilder<Duration>(
                                      stream: _player.stream.buffer,
                                      builder: (context, snapshot) {
                                        final buffer =
                                            snapshot.data ?? Duration.zero;
                                        final total =
                                            dur.inMilliseconds.toDouble();
                                        if (total <= 0) {
                                          return const SizedBox.shrink();
                                        }
                                        final value =
                                            (buffer.inMilliseconds / total)
                                                .clamp(0.0, 1.0);
                                        return LinearProgressIndicator(
                                          value: value,
                                          backgroundColor: Colors.transparent,
                                          valueColor: AlwaysStoppedAnimation(
                                              Colors.white
                                                  .withValues(alpha: 0.3)),
                                        );
                                      },
                                    ),
                                  ),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 7),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                              overlayRadius: 20),
                                      activeTrackColor: AppTheme.primaryColor,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: AppTheme.primaryColor,
                                    ),
                                    child: SizedBox(
                                      height: 34,
                                      child: Slider(
                                        value: _isSliderDragging
                                            ? _sliderDraggingValue
                                            : (dur.inMilliseconds > 0)
                                                ? (pos.inMilliseconds /
                                                        dur.inMilliseconds)
                                                    .clamp(0.0, 1.0)
                                                : 0.0,
                                        onChanged: (v) {
                                          setState(() {
                                            _isSliderDragging = true;
                                            _sliderDraggingValue = v;
                                            _dragSeekTime = Duration(
                                                milliseconds:
                                                    (v * dur.inMilliseconds)
                                                        .toInt());
                                          });
                                          _resetControlsTimer();
                                        },
                                        onChangeStart: (v) {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            _isSliderDragging = true;
                                            _sliderDraggingValue = v;
                                            _dragSeekTime = Duration(
                                                milliseconds:
                                                    (v * dur.inMilliseconds)
                                                        .toInt());
                                          });
                                        },
                                        onChangeEnd: (v) {
                                          HapticFeedback.mediumImpact();
                                          _player.seek(Duration(
                                              milliseconds:
                                                  (v * dur.inMilliseconds)
                                                      .toInt()));
                                          setState(() {
                                            _isSliderDragging = false;
                                            _dragSeekTime = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(_formatDuration(dur),
                                style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    );
                  }),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Subtitles + Speed
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: IconButton(
                          onPressed: () => _showTrackSelector(),
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedSubtitle,
                            color: Colors.white,
                            size: 22.0,
                          ),
                          iconSize: 22,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          tooltip: 'Subtitles',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: IconButton(
                          onPressed: _showSpeedSelector,
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedDashboardSpeed02,
                            color: _playbackSpeed != 1.0
                                ? AppTheme.primaryColor
                                : Colors.white,
                            size: 22.0,
                          ),
                          iconSize: 22,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          tooltip: 'Speed',
                        ),
                      ),
                    ],
                  ),

                  // Center: Play/Pause and Seek Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Rewind 10
                      IconButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _player.seek(_player.state.position -
                              const Duration(seconds: 10));
                          _resetControlsTimer();
                        },
                        iconSize: 42,
                        icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedGoBackward10Sec,
                            color: Colors.white,
                            size: 24.0),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 48),
                      // Play/Pause
                      StreamBuilder<bool>(
                          stream: _player.stream.playing,
                          initialData: _player.state.playing,
                          builder: (context, snapshot) {
                            final playing = snapshot.data ?? false;
                            return IconButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                _player.playOrPause();
                                _resetControlsTimer();
                              },
                              iconSize: 56,
                              icon: HugeIcon(
                                icon: playing
                                    ? HugeIcons.strokeRoundedPause
                                    : HugeIcons.strokeRoundedPlay,
                                color: Colors.white,
                                size: 56.0,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            );
                          }),
                      const SizedBox(width: 48),
                      // Forward 10
                      IconButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          _player.seek(_player.state.position +
                              const Duration(seconds: 10));
                          _resetControlsTimer();
                        },
                        iconSize: 42,
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedGoForward10Sec,
                          color: Colors.white,
                          size: 24.0,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),

                  // Right: Resize + Settings Buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: IconButton(
                          onPressed: _cycleFit,
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedCrop,
                            color: Colors.white,
                            size: 22.0,
                          ),
                          iconSize: 22,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          tooltip: 'Resize',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: IconButton(
                          onPressed: _showPlaybackSettings,
                          icon: HugeIcon(
                            icon: HugeIcons.strokeRoundedSettings01,
                            color: Colors.white,
                            size: 22.0,
                          ),
                          iconSize: 22,
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          tooltip: 'Settings',
                        ),
                      ),
                    ],
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBtn(
      {required IconData icon, required VoidCallback onTap}) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: Colors.white,
      iconSize: 28,
    );
  }

  Widget _buildVerticalBrightnessSlider() {
    return Positioned(
      left: 45,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          width: 36,
          height: 160,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 4),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 8),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                  ),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Slider(
                      value: _brightness,
                      onChanged: (v) {
                        _setBrightness(v);
                        _resetControlsTimer();
                      },
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

  Widget _buildLockBtn() {
    return Positioned(
      right: 22,
      top: 0,
      bottom: 0,
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          child: IconButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              _lockScreen();
            },
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedLockSync02,
            ),
            color: Colors.white,
            iconSize: 28,
          ),
        ),
      ),
    );
  }

  void _cycleFit() {
    setState(() {
      _fit = (_fit == BoxFit.contain) ? BoxFit.cover : BoxFit.contain;
    });
  }

  Future<void> _switchQuality(String newQuality) async {
    if (newQuality == _currentQuality) return;

    // Save current position
    final currentPosition = _player.state.position;
    final wasPlaying = _player.state.playing;

    String newUrl = widget.url;
    Map<String, String>? headers = widget.httpHeaders;

    if (_currentProvider == 'TG') {
      // Try to find the URL in already-loaded sources first
      final cached = _currentSources.where((s) {
        final q = s.quality.toString();
        return (q == newQuality || '${q}p' == newQuality) && s.url.isNotEmpty;
      }).toList();

      if (cached.isNotEmpty) {
        newUrl = cached.first.url;
      } else {
        // Fetch from TG service
        try {
          final tgService = TgService();
          final imdbId = widget.mediaItem?.id ?? '';
          final isMovie = _currentSeason == null;

          if (isMovie && widget.tmdbId != null) {
            final streams = await tgService.getMovieStreams(
                widget.tmdbId.toString(),
                quality: newQuality);
            if (streams.isNotEmpty) {
              final match = streams.firstWhere(
                (s) => s.quality == newQuality,
                orElse: () => streams.first,
              );
              newUrl = tgService.getStreamUrl(match.url, match.hash);
            }
          } else {
            final streams = await tgService.getStreams(imdbId,
                season: _currentSeason, episode: _currentEpisode);
            if (streams.isNotEmpty) {
              final match = streams.firstWhere(
                (s) => s.quality == newQuality,
                orElse: () => streams.first,
              );
              newUrl = tgService.getStreamUrl(match.url, match.hash);
            }
          }
        } catch (e) {
          debugPrint('[TG] Error switching quality: $e');
          _showNotif('Failed to switch quality', seconds: 2);
          return;
        }
      }
    } else if (_currentSources.isNotEmpty) {
      final matchingSource = _currentSources.firstWhere(
        (s) {
          final q = s.quality.toString();
          return q == newQuality || '${q}p' == newQuality;
        },
        orElse: () => _currentSources.first,
      );
      newUrl = matchingSource.url;
      if (matchingSource.headers != null) {
        headers = matchingSource.headers;
      }
    } else if (widget.sources != null && widget.sources!.isNotEmpty) {
      final matchingSource = widget.sources!.firstWhere(
        (s) {
          final q = s.quality.toString();
          return q == newQuality || '${q}p' == newQuality;
        },
        orElse: () => widget.sources!.first,
      );
      newUrl = matchingSource.url;
      if (matchingSource.headers != null) {
        headers = matchingSource.headers;
      }
    } else {
      // Legacy URL replacement fallback
      newUrl = widget.url.replaceAll(
          RegExp(r'_(1080p|720p|480p|270p)\.mp4'), '_$newQuality.mp4');
    }

    _player.setVolume(0.0);

    // Load new quality
    await _player.open(
        Media(
          newUrl,
          httpHeaders: headers,
        ),
        play: true);

    // Wait for media to be buffered/ready
    await Future.delayed(const Duration(milliseconds: 800));

    ExternalSubtitle? engSub;
    try {
      engSub = _externalSubtitles.firstWhere((s) =>
          s.language.toLowerCase().contains('en') ||
          s.title.toLowerCase().contains('english'));
    } catch (_) {}

    if (engSub != null) {
      _selectedExternalSubtitleUri = engSub.uri;
      _player.setSubtitleTrack(SubtitleTrack.uri(engSub.uri,
          title: engSub.title, language: engSub.language));
    }

    // Restore position
    try {
      await _player.seek(currentPosition);
    } catch (e) {
      debugPrint('Error seeking after quality change: $e');
    }

    if (!wasPlaying) {
      await _player.pause();
    }
    _player.setVolume(_volumeBoost);

    setState(() => _currentQuality = newQuality);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quality changed to $newQuality',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.cardColor,
          margin:
              const EdgeInsets.only(top: 60, left: 60, right: 60, bottom: 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
      );
    }
  }

  String _getFriendlyQualityName(String quality) {
    final q = quality.trim().toUpperCase();

    // Always extract resolution first — even if label also has season info
    String? res;
    if (q.contains('2160P') || q.contains('4K')) {
      res = '4K';
    } else if (q.contains('1080P')) {
      res = '1080p';
    } else if (q.contains('720P')) {
      res = '720p';
    } else if (q.contains('540P')) {
      res = '540p';
    } else if (q.contains('480P')) {
      res = '480p';
    } else if (q.contains('360P')) {
      res = '360p';
    } else if (q.contains('240P')) {
      res = '240p';
    }

    // Extract codec/format extras
    final extras = <String>[];
    if (q.contains('HDR')) extras.add('HDR');
    if (q.contains('HEVC') || q.contains('H.265') || q.contains('X265')) extras.add('HEVC');
    if (q.contains('H.264') || q.contains('H264') || q.contains('X264') || q.contains('AVC')) extras.add('H.264');
    if (q.contains('DOLBY') || q.contains('DV')) extras.add('Dolby');

    if (res != null) {
      return extras.isNotEmpty ? '$res • ${extras.join(' • ')}' : res;
    }

    // No resolution found — if it's a plain short label like "720p" just clean it
    final plain = quality.trim();
    if (RegExp(r'^\d{3,4}p$', caseSensitive: false).hasMatch(plain)) {
      return plain.toLowerCase();
    }

    // Pure junk label — show 'Auto'
    return 'Auto';
  }

  void _showQualityPicker() {
    if (_availableQualities.isEmpty) {
      _showNotif('No quality options available', seconds: 2);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF151515).withValues(alpha: 0.85),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.hd_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Quality',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close_rounded,
                          color: Colors.white54, size: 20),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: AppTheme.borderColor.withValues(alpha: 0.2),
                indent: 12,
                endIndent: 12,
              ),
              const SizedBox(height: 8),
              ...List.generate(_availableQualities.length, (index) {
                final quality = _availableQualities[index];
                final isSelected = quality == _currentQuality;
                final friendlyName = _getFriendlyQualityName(quality);

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _switchQuality(quality);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              friendlyName,
                              style: GoogleFonts.outfit(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.white,
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Active',
                                style: GoogleFonts.outfit(
                                  color: AppTheme.primaryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrackSelector() {
    showDialog(
      context: context,
      builder: (_) => _UnifiedTrackSelector(
        player: _player,
        externalSubtitles: _externalSubtitles,
        selectedExternalSubtitleUri: _selectedExternalSubtitleUri,
        onPickLocalSubtitle: _pickLocalSubtitle,
        onDownloadSubtitles: _downloadSubtitles,
        onClearExternalSelection: () =>
            setState(() => _selectedExternalSubtitleUri = null),
        onSelectExternalSubtitle: (subtitle) async {
          await _applyExternalSubtitle(subtitle);
          if (mounted) Navigator.pop(context);
        },
        onRemoveExternalSubtitle: (uri) async {
          await _removePersistedSubtitle(uri);
        },
        subtitleDelay: _subtitleDelay,
        onAdjustSync: _adjustSync,
        subtitleColor: _subtitleColor,
        availableQualities: _availableQualities,
        currentQuality: _currentQuality,
        onQualitySelected: (quality) {
          _switchQuality(quality);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _applyExternalSubtitle(ExternalSubtitle subtitle) async {
    _selectedExternalSubtitleUri = subtitle.uri;
    _player.setSubtitleTrack(
      SubtitleTrack.uri(
        subtitle.uri,
        title: subtitle.title,
        language: subtitle.language,
      ),
    );
  }

  Future<void> _addExternalSubtitle(
    String path, {
    String? title,
    String? language,
  }) async {
    final uri = Uri.file(path).toString();
    var fileName = title ?? path.split(Platform.pathSeparator).last;

    fileName = fileName
        .replaceAll(RegExp(r'flowcast', caseSensitive: false), '')
        .replaceAll(RegExp(r'^\s*-\s*'), '')
        .trim();

    final subtitle = ExternalSubtitle(
      uri: uri,
      title: fileName,
      language: language ?? 'Unknown',
    );

    setState(() {
      final exists = _externalSubtitles.any((s) => s.uri == uri);
      if (!exists) {
        _externalSubtitles.add(subtitle);
      }
      _selectedExternalSubtitleUri = uri;
    });

    await _applyExternalSubtitle(subtitle);
    await _savePersistedSubtitles();
  }

  Future<void> _pickLocalSubtitle() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['srt', 'vtt', 'ass', 'ssa', 'sub'],
    );

    final path = result?.files.single.path;
    if (path == null) return;

    await _addExternalSubtitle(path);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subtitle added.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          duration: Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.cardColor,
          margin: EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 0),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
      );
    }
  }

  Future<void> _downloadSubtitles() async {
    final result = await showDialog<DownloadedSubtitle>(
      context: context,
      builder: (_) => SubtitleDownloadDialog(
        initialQuery: widget.title ?? '',
        tmdbId: widget.tmdbId?.toString(),
        imdbId: widget.mediaItem?.id,
        season: widget.season,
        episode: widget.episode,
      ),
    );

    if (result == null) return;
    await _addExternalSubtitle(
      result.path,
      title: result.title,
      language: result.language,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subtitle downloaded and applied.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          duration: Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.cardColor,
          margin: EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 0),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
      );
    }
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  void _showProviderSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Select Provider',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildProviderOption('River'),
            _buildProviderOption('KissKh'),
            _buildProviderOption('VidLink'),
            _buildProviderOption('VidEasy'),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderOption(String name) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _changeProvider(name);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _changeProvider(String providerName) async {
    if (widget.tmdbId == null && widget.title == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot verify media info for provider switch')),
      );
      return;
    }

    setState(() => _isReady = false); // Show loading
    await _player.pause();

    try {
      final isTv = widget.season != null && widget.episode != null;
      var title = widget.title ?? '';
      if (title.contains(' - S')) {
        title = title.split(' - S').first;
      }
      final year = widget.mediaItem?.year ?? '';

      List<VideoSource> newSources = [];
      List<VideoCaption> newCaptions = [];

      if (providerName == 'River') {
        final service = VideoSourceService();
        final result = await service.getVideoSources(
          widget.tmdbId.toString(),
          (widget.season ?? 1).toString(),
          (widget.episode ?? 1).toString(),
          serviceName: isTv ? 'tvVideoProvider' : 'movieVideoProvider',
        );
        newSources = List<VideoSource>.from(result['sources'] ?? []);
        newCaptions = List<VideoCaption>.from(result['captions'] ?? []);
      } else if (providerName == 'KissKh') {
        final service = KissKhService();
        final result = await service.getSources(
          title,
          isTv ? widget.season : 1,
          isTv ? widget.episode : 1,
        );
        newSources =
            (result['sources'] as List).map((e) => e as VideoSource).toList();
        newCaptions =
            (result['captions'] as List).map((e) => e as VideoCaption).toList();
      } else if (providerName == 'VidLink') {
        final service = VidLinkService();
        final result = await service.getSources(
          widget.tmdbId ?? 0,
          isMovie: !isTv,
          season: isTv ? widget.season : null,
          episode: isTv ? widget.episode : null,
        );
        newSources =
            (result['sources'] as List).map((e) => e as VideoSource).toList();
        newCaptions =
            (result['captions'] as List).map((e) => e as VideoCaption).toList();
      } else if (providerName == 'VidEasy') {
        final service = VidEasyService();
        final result = await service.getSources(
          title,
          year,
          widget.tmdbId ?? 0,
          isMovie: !isTv,
          season: isTv ? widget.season : null,
          episode: isTv ? widget.episode : null,
        );
        newSources =
            (result['sources'] as List).map((e) => e as VideoSource).toList();
        newCaptions =
            (result['captions'] as List).map((e) => e as VideoCaption).toList();
      }

      if (newSources.isNotEmpty) {
        _currentProvider = providerName;
        _currentSources = newSources;
        _availableQualities = newSources
            .map((s) => s.quality)
            .where((q) => !q.toLowerCase().contains('unsorted'))
            .toSet()
            .toList();
        _currentQuality = _availableQualities.first;

        // Re-init player with new source
        // Save old position first?
        final oldPos = _player.state.position;

        _player.setVolume(0.0);

        await _player.open(
            Media(newSources.first.url, httpHeaders: newSources.first.headers),
            play: true);

        // Add new captions
        for (final caption in newCaptions) {
          final exists = _externalSubtitles.any((s) => s.uri == caption.file);
          if (!exists) {
            _externalSubtitles.add(ExternalSubtitle(
                uri: caption.file,
                title: caption.label,
                language: caption.label.split(' - ').first.trim()));
          }
        }

        ExternalSubtitle? engSub;
        try {
          engSub = _externalSubtitles.firstWhere((s) =>
              s.language.toLowerCase().contains('en') ||
              s.title.toLowerCase().contains('english'));
        } catch (_) {}

        if (engSub != null) {
          _selectedExternalSubtitleUri = engSub.uri;
          _player.setSubtitleTrack(SubtitleTrack.uri(engSub.uri,
              title: engSub.title, language: engSub.language));
        }

        // Seek to old pos
        await Future.delayed(const Duration(seconds: 1)); // Buffer
        await _player.seek(oldPos);

        _player.setVolume(_volumeBoost);

        setState(() => _isReady = true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switched to $providerName')),
        );
      } else {
        setState(() => _isReady = true); // Revert loading
        await _player.play();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sources found for this provider')),
        );
      }
    } catch (e) {
      print('Provider switch error: $e');
      setState(() => _isReady = true);
      await _player.play();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error switching provider: $e')),
      );
    }
  }
}

class _UnifiedTrackSelector extends StatefulWidget {
  final Player player;
  final List<ExternalSubtitle> externalSubtitles;
  final String? selectedExternalSubtitleUri;
  final Future<void> Function() onPickLocalSubtitle;
  final Future<void> Function() onDownloadSubtitles;
  final VoidCallback onClearExternalSelection;
  final Future<void> Function(ExternalSubtitle subtitle)
      onSelectExternalSubtitle;
  final Future<void> Function(String uri) onRemoveExternalSubtitle;
  final Duration subtitleDelay;
  final Function(Duration) onAdjustSync;
  final Color subtitleColor;
  final List<String> availableQualities;
  final String currentQuality;
  final Function(String quality) onQualitySelected;

  const _UnifiedTrackSelector({
    required this.player,
    required this.externalSubtitles,
    required this.selectedExternalSubtitleUri,
    required this.onPickLocalSubtitle,
    required this.onDownloadSubtitles,
    required this.onClearExternalSelection,
    required this.onSelectExternalSubtitle,
    required this.onRemoveExternalSubtitle,
    required this.subtitleDelay,
    required this.onAdjustSync,
    required this.subtitleColor,
    required this.availableQualities,
    required this.currentQuality,
    required this.onQualitySelected,
  });

  @override
  State<_UnifiedTrackSelector> createState() => _UnifiedTrackSelectorState();
}

class _UnifiedTrackSelectorState extends State<_UnifiedTrackSelector>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF151515).withValues(alpha: 0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              children: [
                Expanded(
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppTheme.primaryColor,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    tabs: const [
                      Tab(text: "Audio"),
                      Tab(text: "Subtitles"),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAudioList(),
                  _buildSubtitleList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioList() {
    final allTracks = widget.player.state.tracks.audio;
    final current = widget.player.state.track.audio;

    // Filter out control tracks (auto, no) - only show actual audio tracks
    final tracks = allTracks
        .where((track) => track.id != 'auto' && track.id != 'no')
        .toList();

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: tracks.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        if (index == 0) {
          final isOff = current.id == 'no' || current.id == 'auto';
          return _buildItem("Off", isOff, null, 'audio');
        }
        final track = tracks[index - 1];
        final isSelected = track == current;
        final title = _getFriendlyTrackName(track);
        return _buildItem(title, isSelected, track, 'audio');
      },
    );
  }

  Widget _buildSubtitleList() {
    final allTracks = widget.player.state.tracks.subtitle;
    final current = widget.player.state.track.subtitle;

    // Filter out control tracks (auto, no) - only show actual subtitle tracks
    final tracks = allTracks
        .where((track) => track.id != 'auto' && track.id != 'no')
        .toList();

    final List<Widget> items = [];

    items.add(
      _SubtitleActions(
        onDownload: widget.onDownloadSubtitles,
        onImport: widget.onPickLocalSubtitle,
      ),
    );
    items.add(const SizedBox(height: 4));

    final isOff = current.id == 'no' || current.id == 'auto';
    items.add(_buildItem("Off", isOff, null, 'subtitle'));
    items.add(const SizedBox(height: 4));

    for (final track in tracks) {
      final isSelected = track == current;
      final title = _getFriendlyTrackName(track);
      items.add(_buildItem(title, isSelected, track, 'subtitle'));
      items.add(const SizedBox(height: 4));
    }

    if (widget.externalSubtitles.isNotEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(
            'External Subtitles',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      );

      for (final subtitle in widget.externalSubtitles) {
        final isSelected = widget.selectedExternalSubtitleUri == subtitle.uri;
        items.add(
          _ExternalSubtitleItem(
            subtitle: subtitle,
            isSelected: isSelected,
            onTap: () => widget.onSelectExternalSubtitle(subtitle),
            onRemove: () => widget.onRemoveExternalSubtitle(subtitle.uri),
          ),
        );
        items.add(const SizedBox(height: 4));
      }
    }

    if (tracks.isEmpty && widget.externalSubtitles.isEmpty) {
      items.add(
        _EmptySubtitleState(
          onDownload: widget.onDownloadSubtitles,
          onImport: widget.onPickLocalSubtitle,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      children: items,
    );
  }

  String _getFriendlyTrackName(dynamic track) {
    String? title = track.title;
    String? lang = track.language;

    final langMap = {
      'eng': 'English',
      'en': 'English',
      'spa': 'Spanish',
      'es': 'Spanish',
      'fre': 'French',
      'fr': 'French',
      'fra': 'French',
      'ger': 'German',
      'de': 'German',
      'deu': 'German',
      'ita': 'Italian',
      'it': 'Italian',
      'jpn': 'Japanese',
      'ja': 'Japanese',
      'kor': 'Korean',
      'ko': 'Korean',
      'chi': 'Chinese',
      'zh': 'Chinese',
      'zho': 'Chinese',
      'rus': 'Russian',
      'ru': 'Russian',
      'hin': 'Hindi',
      'hi': 'Hindi',
      'tam': 'Tamil',
      'ta': 'Tamil',
      'tel': 'Telugu',
      'te': 'Telugu',
      'mal': 'Malayalam',
      'ml': 'Malayalam',
      'kan': 'Kannada',
      'kn': 'Kannada',
      'fil': 'Filipino',
      'ind': 'Indonesian',
      'id': 'Indonesian',
      'por': 'Portuguese',
      'pt': 'Portuguese',
      'tur': 'Turkish',
      'tr': 'Turkish',
      'vie': 'Vietnamese',
      'vi': 'Vietnamese',
      'tha': 'Thai',
      'th': 'Thai',
      'ara': 'Arabic',
      'ar': 'Arabic',
      'heb': 'Hebrew',
      'he': 'Hebrew',
      'ice': 'Icelandic',
      'is': 'Icelandic',
      'dut': 'Dutch',
      'nl': 'Dutch',
      'swe': 'Swedish',
      'sv': 'Swedish',
      'dan': 'Danish',
      'da': 'Danish',
      'nor': 'Norwegian',
      'no': 'Norwegian',
      'fin': 'Finnish',
      'fi': 'Finnish',
      'pol': 'Polish',
      'pl': 'Polish',
      'cze': 'Czech',
      'cs': 'Czech',
      'hun': 'Hungarian',
      'hu': 'Hungarian',
      'gre': 'Greek',
      'el': 'Greek',
      'ukr': 'Ukrainian',
      'uk': 'Ukrainian',
      'may': 'Malay',
      'ms': 'Malay',
      'rum': 'Romanian',
      'ro': 'Romanian',
      'ben': 'Bengali',
      'bn': 'Bengali',
      'pan': 'Punjabi',
      'pa': 'Punjabi',
      'mar': 'Marathi',
      'mr': 'Marathi',
      'guj': 'Gujarati',
      'gu': 'Gujarati',
    };

    // Flag map
    final flagMap = {
      'eng': '🇬🇧',
      'en': '🇬🇧',
      'spa': '🇪🇸',
      'es': '🇪🇸',
      'fre': '🇫🇷',
      'fr': '🇫🇷',
      'fra': '🇫🇷',
      'ger': '🇩🇪',
      'de': '🇩🇪',
      'deu': '🇩🇪',
      'ita': '🇮🇹',
      'it': '🇮🇹',
      'jpn': '🇯🇵',
      'ja': '🇯🇵',
      'kor': '🇰🇷',
      'ko': '🇰🇷',
      'chi': '🇨🇳',
      'zh': '🇨🇳',
      'zho': '🇨🇳',
      'rus': '🇷🇺',
      'ru': '🇷🇺',
      'hin': '🇮🇳',
      'hi': '🇮🇳',
      'tam': '🇮🇳',
      'ta': '🇮🇳',
      'tel': '🇮🇳',
      'te': '🇮🇳',
      'mal': '🇮🇳',
      'ml': '🇮🇳',
      'kan': '🇮🇳',
      'kn': '🇮🇳',
      'fil': '🇵🇭',
      'ind': '🇮🇩',
      'id': '🇮🇩',
      'por': '🇵🇹',
      'pt': '🇵🇹',
      'tur': '🇹🇷',
      'tr': '🇹🇷',
      'vie': '🇻🇳',
      'vi': '🇻🇳',
      'tha': '🇹🇭',
      'th': '🇹🇭',
      'ara': '🇸🇦',
      'ar': '🇸🇦',
      'heb': '🇮🇱',
      'he': '🇮🇱',
      'ice': '🇮🇸',
      'is': '🇮🇸',
      'dut': '🇳🇱',
      'nl': '🇳🇱',
      'swe': '🇸🇪',
      'sv': '🇸🇪',
      'dan': '🇩🇰',
      'da': '🇩🇰',
      'nor': '🇳🇴',
      'no': '🇳🇴',
      'fin': '🇫🇮',
      'fi': '🇫🇮',
      'pol': '🇵🇱',
      'pl': '🇵🇱',
      'cze': '🇨🇿',
      'cs': '🇨🇿',
      'hun': '🇭🇺',
      'hu': '🇭🇺',
      'gre': '🇬🇷',
      'el': '🇬🇷',
      'ukr': '🇺🇦',
      'uk': '🇺🇦',
      'may': '🇲🇾',
      'ms': '🇲🇾',
      'rum': '🇷🇴',
      'ro': '🇷🇴',
      'ben': '🇧🇩',
      'bn': '🇧🇩',
      'pan': '🇮🇳',
      'pa': '🇮🇳',
      'mar': '🇮🇳',
      'mr': '🇮🇳',
      'guj': '🇮🇳',
      'gu': '🇮🇳',
    };

    // Get language display name
    String? displayLang;
    String flag = '';

    if (lang != null && lang.isNotEmpty) {
      final key = lang.toLowerCase();
      displayLang = langMap[key] ?? lang;
      flag = flagMap[key] ?? '';

      // Capitalize first letter if not from map
      if (displayLang.length > 1 && !langMap.containsKey(key)) {
        displayLang = displayLang[0].toUpperCase() + displayLang.substring(1);
      }
    }

    // Build track name with available formatting
    if (title != null && title.isNotEmpty) {
      // Strip common garbage from title
      title = title
          .replaceAll(RegExp(r'flowcast', caseSensitive: false), '')
          .replaceAll(RegExp(r'^\s*-\s*'), '')
          .trim();

      if (displayLang != null && displayLang.isNotEmpty) {
        if (title.toLowerCase() == displayLang.toLowerCase()) {
          return flag.isNotEmpty ? '$flag $displayLang' : displayLang;
        }
        return flag.isNotEmpty
            ? "$flag $displayLang ($title)"
            : "$displayLang ($title)";
      }
      return title;
    }

    if (displayLang != null && displayLang.isNotEmpty) {
      return flag.isNotEmpty ? '$flag $displayLang' : displayLang;
    }

    // Fallback to codec/channel info specifically for audio tracks
    String? codec = track.codec?.toString().toUpperCase();
    String? channels = track.channels?.toString();

    if (codec != null) {
      String name = codec;
      if (channels != null) {
        String channelDesc = channels;
        if (channels == '2' || channels.toLowerCase() == 'stereo') {
          channelDesc = 'Stereo';
        }
        if (channels == '6' || channels.toLowerCase() == '5.1') {
          channelDesc = '5.1';
        }
        name = "$codec - ${channelDesc.capitalize()}";
      }
      // If no title/lang, add ID to distinguish multiple identical tracks
      if ((title == null || title.isEmpty) &&
          (displayLang == null || displayLang.isEmpty)) {
        name += " (Track ${track.id})";
      }
      return name;
    }

    // Last resort: use track ID
    if (track.id != null && track.id != 'auto' && track.id != 'no') {
      return "Track ${track.id}";
    }

    return 'Unknown';
  }

  Widget _buildItem(String title, bool isSelected, dynamic track, String type) {
    return _ExternalSubtitleItem(
      subtitle: ExternalSubtitle(uri: '', title: title, language: ''), // Dummy
      isSelected: isSelected,
      onTap: () {
        if (type == 'audio') {
          widget.player.setAudioTrack(track ?? AudioTrack.no());
        } else {
          widget.onClearExternalSelection();
          widget.player.setSubtitleTrack(track ?? SubtitleTrack.no());
        }
        Navigator.pop(context);
      },
      // Remove sync controls from here
    );
  }
}

class ExternalSubtitle {
  final String uri;
  final String title;
  final String language;

  ExternalSubtitle({
    required this.uri,
    required this.title,
    required this.language,
  });
}

class _SubtitleActions extends StatelessWidget {
  final Future<void> Function() onDownload;
  final Future<void> Function() onImport;

  const _SubtitleActions({
    required this.onDownload,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Import'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExternalSubtitleItem extends StatelessWidget {
  final ExternalSubtitle subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _ExternalSubtitleItem({
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (isSelected)
              const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            else
              const SizedBox(width: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle.title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle.language,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (onRemove != null) ...[
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: Colors.red.withValues(alpha: 0.7),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onRemove,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptySubtitleState extends StatelessWidget {
  final Future<void> Function() onDownload;
  final Future<void> Function() onImport;

  const _EmptySubtitleState({
    required this.onDownload,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          const Icon(Icons.subtitles_off_rounded,
              color: Colors.white70, size: 26),
          const SizedBox(height: 8),
          const Text(
            'No subtitles available',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Use the Download or Import buttons above to add subtitles.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class DownloadedSubtitle {
  final String path;
  final String title;
  final String language;

  const DownloadedSubtitle({
    required this.path,
    required this.title,
    required this.language,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'language': language,
      };

  factory DownloadedSubtitle.fromJson(Map<String, dynamic> json) =>
      DownloadedSubtitle(
        path: json['path'] as String,
        title: json['title'] as String,
        language: json['language'] as String,
      );
}

class SubtitleDownloadDialog extends StatefulWidget {
  final String initialQuery;
  final String? tmdbId;
  final String? imdbId;
  final int? season;
  final int? episode;

  const SubtitleDownloadDialog({
    required this.initialQuery,
    this.tmdbId,
    this.imdbId,
    this.season,
    this.episode,
    super.key,
  });

  @override
  State<SubtitleDownloadDialog> createState() => _SubtitleDownloadDialogState();
}

class _SubtitleDownloadDialogState extends State<SubtitleDownloadDialog> {
  late final TextEditingController _queryController;
  bool _loading = false;
  String? _error;
  List<SubtitleCatResult> _results = [];
  List<SubtitleCatLanguage>? _selectedLanguages;
  String? _selectedResultId;
  String? _selectedResultName;
  String? _downloadingId;
  String _currentProvider = 'SubtitleCat';

  static const Map<String, String> _languageFlagMap = {
    'english': '🇬🇧',
    'hindi': '🇮🇳',
    'malayalam': '🇮🇳',
    'korean': '🇰🇷',
    'japanese': '🇯🇵',
    'tamil': '🇮🇳',
    'telugu': '🇮🇳',
    'kannada': '🇮🇳',
    'spanish': '🇪🇸',
    'french': '🇫🇷',
    'german': '🇩🇪',
    'italian': '🇮🇹',
    'portuguese': '🇵🇹',
    'chinese (simplified)': '🇨🇳',
    'chinese (traditional)': '🇹🇼',
    'arabic': '🇸🇦',
    'russian': '🇷🇺',
  };
  @override
  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    debugPrint(
        'SubtitleDialog Init - TMDB: ${widget.tmdbId}, IMDb: ${widget.imdbId}, Query: ${widget.initialQuery}');

    // Auto-search if we have criteria
    if (widget.tmdbId != null || widget.imdbId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchWyzie());
    } else if (widget.initialQuery.isNotEmpty) {
      // Fallback to text search if no IDs
      WidgetsBinding.instance.addPostFrameCallback((_) => _searchSubtitleCat());
    }
  }

  Future<void> _searchWyzie() async {
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
      _selectedLanguages = null;
      _currentProvider = 'Wyzie';
    });

    try {
      String? searchId;
      if (widget.imdbId != null && widget.imdbId!.isNotEmpty) {
        searchId = widget.imdbId;
      } else if (widget.tmdbId != null) {
        searchId = widget.tmdbId.toString();
      }

      debugPrint(
          'Wyzie Search - ID: $searchId, IMDb: ${widget.imdbId}, TMDB: ${widget.tmdbId}');

      if (searchId != null && searchId.isNotEmpty) {
        final wyzieResults = await WyzieService.search(
          searchId,
          widget.season,
          widget.episode,
        );

        if (mounted) {
          setState(() {
            _results = wyzieResults;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _searchSubtitleCat() async {
    if (_queryController.text.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _results = []; // Clear previous results (e.g. Wyzie)
      _selectedLanguages = null;
      _currentProvider = 'SubtitleCat';
    });

    try {
      debugPrint('SubtitleCat Search - Query: ${_queryController.text}');
      final catResults = await SubtitleCatService.searchSubtitles(
        _queryController.text,
      );

      if (mounted) {
        setState(() {
          _results = catResults;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectSubtitle(SubtitleCatResult result) async {
    setState(() {
      _loading = true;
      _selectedResultId = result.id;
      _selectedResultName = result.fileName;
      _error = null;
    });

    try {
      if (result.isDirect) {
        // Direct download (Wyzie)
        final lang = SubtitleCatLanguage(
          languageName: result.language ?? 'Unknown',
          downloadUrl: result.downloadLink,
          format: result.downloadLink.contains('.srt')
              ? 'srt'
              : 'sub', // rudimentary check
        );
        setState(() {
          _selectedLanguages = [lang];
          _loading = false;
        });
      } else {
        // Normal flow (SubtitleCat)
        final languages = await SubtitleCatService.getSubtitleLanguages(
          result.detailsUrl,
        );
        setState(() {
          _selectedLanguages = languages;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _selectedResultId = null;
        _selectedResultName = null;
      });
    }
  }

  Future<void> _downloadLanguage(SubtitleCatLanguage lang) async {
    setState(() {
      _downloadingId = lang.downloadUrl;
      _error = null;
    });

    try {
      final fileName = _selectedResultId != null
          ? 'subtitle_${_selectedResultId}_${lang.languageName}.${lang.format}'
          : 'subtitle_${DateTime.now().millisecondsSinceEpoch}.${lang.format}';

      final path = await SubtitleCatService.downloadSubtitle(
        lang.downloadUrl,
        fileName,
      );

      if (path != null) {
        final downloaded = DownloadedSubtitle(
          path: path,
          title: _selectedResultName ?? 'Subtitle',
          language: lang.languageName,
        );
        if (mounted) {
          setState(() => _downloadingId = null);
          Navigator.pop(context, downloaded);
        }
        return;
      }

      if (mounted) {
        setState(() => _downloadingId = null);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _downloadingId = null;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.zero),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                (MediaQuery.of(context).size.width * 0.7).clamp(500.0, 750.0),
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 24,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                // SIDEBAR
                Container(
                  width: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppTheme.surfaceColor,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildSidebarItem(
                        icon: Icons.auto_awesome_rounded,
                        tooltip: 'Auto Match (Wyzie)',
                        isSelected: _currentProvider == 'Wyzie',
                        onTap: () {
                          if (_currentProvider != 'Wyzie') {
                            _searchWyzie();
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildSidebarItem(
                        icon: Icons.keyboard_rounded,
                        tooltip: 'Manual Search',
                        isSelected: _currentProvider == 'SubtitleCat',
                        onTap: () {
                          setState(() {
                            _currentProvider = 'SubtitleCat';
                            _results = [];
                            _error = null;
                            _selectedLanguages = null;
                          });
                        },
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                        color: AppTheme.textSecondary,
                        tooltip: 'Close',
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                Container(width: 1, color: AppTheme.borderColor),

                Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: _currentProvider == 'Wyzie'
                                  ? Container(
                                      height: 36,
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.auto_awesome_rounded,
                                              color: AppTheme.primaryColor,
                                              size: 18),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Auto-matching via Wyzie',
                                            style: const TextStyle(
                                              color: AppTheme.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          if (widget.imdbId != null ||
                                              widget.tmdbId != null) ...[
                                            const SizedBox(width: 10),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryColor
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                    color: AppTheme.primaryColor
                                                        .withValues(
                                                            alpha: 0.2)),
                                              ),
                                              child: Text(
                                                widget.imdbId ??
                                                    'TMDB: ${widget.tmdbId}',
                                                style: const TextStyle(
                                                  color: AppTheme.primaryColor,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    )
                                  : Container(
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AppTheme.borderColor),
                                      ),
                                      child: TextField(
                                        controller: _queryController,
                                        autofocus: true,
                                        style: const TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontSize: 13),
                                        cursorColor: AppTheme.primaryColor,
                                        decoration: const InputDecoration(
                                          hintText: 'Search subtitles...',
                                          hintStyle: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 15),
                                          border: InputBorder.none,
                                          prefixIcon: Icon(
                                            Icons.search_rounded,
                                            color: AppTheme.textSecondary,
                                            size: 16,
                                          ),
                                          contentPadding: EdgeInsets.only(
                                              bottom: 12), // Center vertically
                                          isDense: true,
                                        ),
                                        onSubmitted: (_) =>
                                            _searchSubtitleCat(),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            if (_loading)
                              Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        AppTheme.primaryColor),
                                  ),
                                ),
                              )
                            else if (_currentProvider == 'SubtitleCat')
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.2)),
                                ),
                                child: IconButton(
                                  onPressed: _searchSubtitleCat,
                                  icon: const Icon(Icons.arrow_forward_rounded,
                                      color: AppTheme.primaryColor, size: 18),
                                  tooltip: 'Search',
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Error Message
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color:
                                    AppTheme.errorColor.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppTheme.errorColor, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                      color: AppTheme.errorColor, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Content (Results / Languages / Empty)
                      if (_results.isNotEmpty ||
                          _selectedLanguages != null) ...[
                        Divider(height: 1, color: AppTheme.borderColor),
                        Expanded(
                          child: _buildContent(),
                        ),
                      ] else if (!_loading && _error == null) ...[
                        Expanded(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _currentProvider == 'Wyzie'
                                      ? Icons.auto_awesome_outlined
                                      : Icons.search_off_rounded,
                                  size: 48,
                                  color: AppTheme.textSecondary
                                      .withValues(alpha: 0.2),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _currentProvider == 'Wyzie'
                                      ? 'Wyzie automatically matches subtitles.'
                                      : 'Type movie/series name to search.',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (_loading) ...[
                        const Spacer(),
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
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Tooltip(
        message: tooltip,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3))
                : null,
          ),
          child: Icon(
            icon,
            color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_selectedLanguages != null) {
      return _buildLanguageSelection();
    } else if (_loading && _results.isEmpty) {
      return const Center(child: SizedBox()); // Spinner is in header
    } else if (_results.isEmpty && !_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No subtitles found.',
            style: TextStyle(color: Colors.white38),
          ),
        ),
      );
    } else {
      return _buildSearchResults();
    }
  }

  Widget _buildSearchResults() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final item = _results[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _selectSubtitle(item),
            borderRadius: BorderRadius.circular(12),
            hoverColor: Colors.white.withValues(alpha: 0.05),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.article_outlined,
                        size: 16, color: Colors.white70),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.fileName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.isDirect) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (item.flagUrl != null) ...[
                                Image.network(
                                  item.flagUrl!,
                                  width: 12,
                                  height: 12,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox(),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                'Direct Download',
                                style: TextStyle(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.white24, size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageSelection() {
    final languages = _selectedLanguages ?? [];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _selectedLanguages = null),
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white70, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Language',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${languages.length} available',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: languages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final lang = languages[index];
              final downloading = _downloadingId == lang.downloadUrl;
              final flag = _languageFlag(lang.languageName);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Text(flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        lang.languageName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (downloading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      IconButton(
                        onPressed: () => _downloadLanguage(lang),
                        icon: const Icon(Icons.download_rounded),
                        color: AppTheme.primaryColor,
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _languageFlag(String language) {
    final lookup = _languageFlagMap[language.toLowerCase()];
    if (lookup != null) return lookup;
    final letters = language
        .split(' ')
        .map((part) => part.isNotEmpty ? part[0] : '')
        .join()
        .toUpperCase();
    if (letters.isEmpty) return '🌐';
    final maxLen = letters.length.clamp(1, 2).toInt();
    return letters.substring(0, maxLen);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }
}

class _FullScreenSearchInput extends StatefulWidget {
  final String initialText;
  const _FullScreenSearchInput({required this.initialText});

  @override
  State<_FullScreenSearchInput> createState() => _FullScreenSearchInputState();
}

class _FullScreenSearchInputState extends State<_FullScreenSearchInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151515),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Search Subtitles',
            style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Enter movie/series name...',
                hintStyle: const TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
              textInputAction: TextInputAction.search,
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}

class _PlaybackSettingsDialog extends StatefulWidget {
  final double currentSpeed;
  final Function(double) onSpeedChanged;
  final bool isNightMode;
  final VoidCallback onNightModeToggle;
  final int sleepMinutes;
  final Function(int) onSleepTimerChanged;
  final double currentBoost;
  final Function(double) onBoostChanged;
  final Duration audioDelay;
  final Function(Duration) onAudioSyncChanged;
  final Duration subtitleDelay;
  final Function(Duration) onSubtitleSyncChanged;
  final Color subtitleColor;
  final Function(Color) onSubtitleColorChanged;
  final VoidCallback onSelectProvider;
  final bool showStats;
  final VoidCallback onToggleStats;
  final VoidCallback onShareLink;

  const _PlaybackSettingsDialog({
    required this.currentSpeed,
    required this.onSpeedChanged,
    required this.isNightMode,
    required this.onNightModeToggle,
    required this.sleepMinutes,
    required this.onSleepTimerChanged,
    required this.currentBoost,
    required this.onBoostChanged,
    required this.audioDelay,
    required this.onAudioSyncChanged,
    required this.subtitleDelay,
    required this.onSubtitleSyncChanged,
    required this.subtitleColor,
    required this.onSubtitleColorChanged,
    required this.onSelectProvider,
    required this.showStats,
    required this.onToggleStats,
    required this.onShareLink,
  });

  @override
  State<_PlaybackSettingsDialog> createState() =>
      _PlaybackSettingsDialogState();
}

class _PlaybackSettingsDialogState extends State<_PlaybackSettingsDialog> {
  late bool _nightMode;
  late int _sleep;
  late double _boost;
  late Duration _audioDelay;
  late Duration _subtitleDelay;

  String? _adjustingTarget;
  Timer? _adjustingTimer;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _nightMode = widget.isNightMode;
    _sleep = widget.sleepMinutes;
    _boost = widget.currentBoost;
    _audioDelay = widget.audioDelay;
    _subtitleDelay = widget.subtitleDelay;
  }

  void _onAdjust(String target) {
    if (mounted) {
      setState(() => _adjustingTarget = target);
    }
    _adjustingTimer?.cancel();
    _adjustingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _adjustingTarget = null);
    });
  }

  @override
  void dispose() {
    _adjustingTimer?.cancel();
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAdjusting = _adjustingTarget != null;

    return Dialog(
      backgroundColor: const Color(0xFF151515).withValues(alpha: 0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: 550,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            AnimatedOpacity(
              opacity: isAdjusting ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: isAdjusting,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                  child: Row(
                    children: [
                      const HugeIcon(
                        icon: HugeIcons.strokeRoundedSettings01,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'PLAYBACK SETTINGS',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white54, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Divider(
              color: isAdjusting ? Colors.transparent : Colors.white10,
              height: 1,
            ),
            Flexible(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                children: [
                  // Source Provider moved to bottom

                  const SizedBox(height: 16),

                  // Settings Grid
                  LayoutBuilder(builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 16) / 2;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        // Night Mode
                        AnimatedOpacity(
                          opacity: (isAdjusting && _adjustingTarget != 'night')
                              ? 0.0
                              : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: SizedBox(
                            width: itemWidth,
                            child: _buildCompactSettingCard(
                              icon: Icons.nightlight_round,
                              title: 'Night Mode',
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Compress dynamic range',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white38,
                                        fontSize: 10,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Transform.scale(
                                    scale: 0.8,
                                    alignment: Alignment.centerRight,
                                    child: Switch(
                                      value: _nightMode,
                                      activeThumbColor: AppTheme.primaryColor,
                                      onChanged: (val) {
                                        setState(() => _nightMode = val);
                                        widget.onNightModeToggle();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Subtitle Delay
                        AnimatedOpacity(
                          opacity:
                              (isAdjusting && _adjustingTarget != 'subtitle')
                                  ? 0.0
                                  : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: SizedBox(
                            width: itemWidth,
                            child: _buildCompactSettingCard(
                              icon: Icons.subtitles_rounded,
                              title:
                                  'Subtitle Delay: ${_subtitleDelay.inMilliseconds}ms',
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildMiniIconBtn(Icons.remove, () {
                                    _onAdjust('subtitle');
                                    setState(() {
                                      _subtitleDelay -=
                                          const Duration(milliseconds: 50);
                                    });
                                    widget.onSubtitleSyncChanged(
                                        const Duration(milliseconds: -50));
                                  }),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        '${(_subtitleDelay.inMilliseconds / 1000).toStringAsFixed(2)}s',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  _buildMiniIconBtn(Icons.add, () {
                                    _onAdjust('subtitle');
                                    setState(() {
                                      _subtitleDelay +=
                                          const Duration(milliseconds: 50);
                                    });
                                    widget.onSubtitleSyncChanged(
                                        const Duration(milliseconds: 50));
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Volume Boost
                        AnimatedOpacity(
                          opacity: (isAdjusting && _adjustingTarget != 'boost')
                              ? 0.0
                              : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: SizedBox(
                            width: itemWidth,
                            child: _buildCompactSettingCard(
                              icon: Icons.volume_up_rounded,
                              title: 'Boost: ${_boost.toInt()}%',
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 0),
                                  activeTrackColor: AppTheme.primaryColor,
                                  inactiveTrackColor:
                                      Colors.white.withValues(alpha: 0.1),
                                  thumbColor: AppTheme.primaryColor,
                                ),
                                child: Slider(
                                  value: _boost,
                                  min: 100,
                                  max: 200,
                                  divisions: 20,
                                  onChanged: (val) {
                                    setState(() => _boost = val);
                                    widget.onBoostChanged(val);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Audio Delay
                        AnimatedOpacity(
                          opacity: (isAdjusting && _adjustingTarget != 'audio')
                              ? 0.0
                              : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: SizedBox(
                            width: itemWidth,
                            child: _buildCompactSettingCard(
                              icon: Icons.sync_rounded,
                              title:
                                  'Audio Delay: ${_audioDelay.inMilliseconds}ms',
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildMiniIconBtn(Icons.remove, () {
                                    _onAdjust('audio');
                                    setState(() {
                                      _audioDelay -=
                                          const Duration(milliseconds: 50);
                                    });
                                    widget.onAudioSyncChanged(
                                        const Duration(milliseconds: -50));
                                  }),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        '${(_audioDelay.inMilliseconds / 1000).toStringAsFixed(2)}s',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  _buildMiniIconBtn(Icons.add, () {
                                    _onAdjust('audio');
                                    setState(() {
                                      _audioDelay +=
                                          const Duration(milliseconds: 50);
                                    });
                                    widget.onAudioSyncChanged(
                                        const Duration(milliseconds: 50));
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Subtitle Color
                        AnimatedOpacity(
                          opacity: isAdjusting ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: SizedBox(
                            width: itemWidth,
                            child: _buildCompactSettingCard(
                              icon: Icons.palette_rounded,
                              title: 'Subtitle Color',
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // White
                                  GestureDetector(
                                    onTap: () => widget
                                        .onSubtitleColorChanged(Colors.white),
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: widget.subtitleColor ==
                                                  Colors.white
                                              ? AppTheme.primaryColor
                                              : Colors.white24,
                                          width: widget.subtitleColor ==
                                                  Colors.white
                                              ? 3
                                              : 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Yellow
                                  GestureDetector(
                                    onTap: () => widget.onSubtitleColorChanged(
                                        const Color(0xFFFFFF00)),
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFF00),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: widget.subtitleColor ==
                                                  const Color(0xFFFFFF00)
                                              ? AppTheme.primaryColor
                                              : Colors.white24,
                                          width: widget.subtitleColor ==
                                                  const Color(0xFFFFFF00)
                                              ? 3
                                              : 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Share Link Option
                        AnimatedOpacity(
                          opacity: isAdjusting ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: SizedBox(
                            width: itemWidth,
                            child: _buildCompactSettingCard(
                              icon: Icons.share_rounded,
                              title: 'Share Link',
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Share direct stream',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white38,
                                        fontSize: 10,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      widget.onShareLink();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: AppTheme.primaryColor
                                                .withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        'SHARE',
                                        style: GoogleFonts.outfit(
                                          color: AppTheme.primaryColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),

                  AnimatedOpacity(
                    opacity: isAdjusting ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        const SizedBox(height: 24),
                        // Sleep Timer
                        Row(
                          children: [
                            Text(
                              'SLEEP TIMER',
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        if (_sleep > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${_sleep}m remaining',
                                style: GoogleFonts.outfit(
                                  color: AppTheme.primaryColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ))
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [0, 15, 30, 60, 90].map((m) {
                            final isSelected = _sleep == m;
                            return _buildChip(
                              label: m == 0 ? 'Off' : '${m}m',
                              isSelected: isSelected,
                              onTap: () {
                                setState(() => _sleep = m);
                                widget.onSleepTimerChanged(m);
                              },
                            );
                          }).toList(),
                        ),
                      ],
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

  Widget _buildCompactSettingCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 32,
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color:
                isSelected ? Colors.black : Colors.white.withValues(alpha: 0.9),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTapDown: (_) {
        onTap();
        _holdTimer?.cancel();
        _holdTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
          onTap();
        });
      },
      onTapUp: (_) => _holdTimer?.cancel(),
      onTapCancel: () => _holdTimer?.cancel(),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
