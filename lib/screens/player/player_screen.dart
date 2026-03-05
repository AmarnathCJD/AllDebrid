import 'dart:async';
import 'dart:io';

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

import '../../providers/providers.dart';
import '../../services/subtitlecat_service.dart';
import '../../theme/app_theme.dart';
import '../../services/imdb_service.dart';
import '../../services/rivestream_service.dart';
import '../../services/video_source_service.dart';
import '../../services/vidlink_service.dart';
import '../../services/kisskh_service.dart';
import '../../services/wyzie_service.dart';
import '../../services/tg_service.dart';

class PlayerScreen extends StatefulWidget {
  final String url;
  final String? title;
  final bool isLocal;
  final List<VideoSource>? sources;
  final Map<String, String>? httpHeaders;

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

  bool _showStats = false;

  bool _fetchingNextEpisode = false;
  String _currentProvider = 'River';
  int? _currentSeason;
  int? _currentEpisode;
  String? _currentTitle;

  bool _showNotification = false;
  String _notificationMessage = '';
  Timer? _notificationTimer;

  // Auto-play next episode
  Timer? _autoPlayCountdownTimer;
  int _autoPlayCountdown = 0;
  bool _showAutoPlayDialog = false;
  bool _cancelAutoPlay = false;

  static const _pipChannel = MethodChannel('com.alldebrid/pip');

  void _setNativePipEnabled(bool enabled) {
    _pipChannel.invokeMethod('setPipEnabled', {'enabled': enabled});
  }

  // Subtitle styling
  Color _subtitleColor = Colors.white;

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
          .map((s) {
            final q = s.quality.toString();
            return q.endsWith('p') ? q : '${q}p';
          })
          .toSet()
          .toList();

      if (_availableQualities.isNotEmpty) {
        _currentQuality = _availableQualities.first;
      }
    } else if (_isImdbTrailer) {
      _availableQualities = ['1080p', '720p', '480p', '270p'];
      for (var quality in _availableQualities) {
        if (widget.url.contains('_${quality}.mp4')) {
          _currentQuality = quality;
          break;
        }
      }
      // Default fallback
      _availableQualities = ['Default'];
      _currentQuality = 'Default';
    }

    _currentSources = widget.sources ?? [];

    _initPlayer();
    _loadSubtitleSettings();
    _resetControlsTimer();
    _initBrightness();
    WidgetsBinding.instance.addObserver(this);
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
      return 'pos_tmdb_${widget.tmdbId}_s${_currentSeason}_e${_currentEpisode}';
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

    Map<String, String>? headers = widget.httpHeaders;
    if (_currentSources.isNotEmpty) {
      try {
        final match = _currentSources.firstWhere(
          (s) => s.url == widget.url,
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
          widget.url,
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
      _player.stream.position.listen((position) {
        final duration = _player.state.duration;
        if (duration > Duration.zero) {
          final isNearEnd = position.inMilliseconds >=
              (duration.inMilliseconds * 0.98); // 98% through
          if (isNearEnd && !_showAutoPlayDialog && !_cancelAutoPlay) {
            _startAutoPlayCountdown();
          }
        }
      });
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
    // content duration might be zero if live, but usually fine
    final duration = _player.state.duration;
    if (newPos < Duration.zero) {
      _player.seek(Duration.zero);
    } else if (newPos > duration) {
      _player.seek(duration);
    } else {
      _player.seek(newPos);
    }

    // Visual feedback
    setState(() {
      if (delta.isNegative) {
        _showLeftDoubleTap = true;
        _showRightDoubleTap = false;
      } else {
        _showLeftDoubleTap = false;
        _showRightDoubleTap = true;
      }
    });

    _doubleTapTimer?.cancel();
    _doubleTapTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _showLeftDoubleTap = false;
          _showRightDoubleTap = false;
        });
      }
    });
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

  void _showSpeedSelector() {
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
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PLAYBACK SPEED',
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                final isSelected = _playbackSpeed == speed;
                return InkWell(
                  onTap: () {
                    _setPlaybackSpeed(speed);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      '${speed}x',
                      style: GoogleFonts.outfit(
                        color:
                            isSelected ? AppTheme.primaryColor : Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
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
    // Auto-PiP is now handled natively via onUserLeaveHint/setAutoEnterEnabled
    // This prevents the "Activity must be resumed" crash and notification swipe bugs.
  }

  void _toggleControls() {
    if (_isLocked || _isPiP) return; // Don't show controls in PiP mode
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetControlsTimer();
  }

  void _lockScreen() {
    setState(() {
      _isLocked = true;
      _showControls = false;
    });
  }

  void _unlockScreen() {
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
                ? InteractiveViewer(
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
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _toggleControls,
              child: Row(
                children: [
                  // Left Zone (Brightness)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _toggleControls,
                      onVerticalDragUpdate: (details) {
                        final delta = details.primaryDelta ?? 0;
                        final newBrightness =
                            (_brightness - delta / 300).clamp(0.0, 1.0);
                        _setBrightness(newBrightness);
                      },
                      onDoubleTap: () => _seekRelative(
                          const Duration(seconds: -10)), // Seek -10s
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Center Zone (Play/Pause)
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _toggleControls,
                      onDoubleTap: () => _player.playOrPause(),
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Right Zone (Seek +10s)
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
            ),

          if (!_isLocked && !_isPiP) ...[
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    child: _showLeftDoubleTap
                        ? Align(
                            alignment: const Alignment(2.25, -0.5),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '10s',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    shadows: [
                                      const Shadow(
                                          blurRadius: 10, color: Colors.black),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Icon(Icons.fast_rewind_rounded,
                                    color: Colors.white, size: 40),
                              ],
                            ).animate().fade(duration: 200.ms).scale(),
                          )
                        : const SizedBox.shrink(),
                  ),
                  const Expanded(flex: 2, child: SizedBox.shrink()),
                  Expanded(
                    child: _showRightDoubleTap
                        ? Align(
                            alignment: const Alignment(-2.25, -0.5),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '10s',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    shadows: [
                                      const Shadow(
                                          blurRadius: 10, color: Colors.black),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Icon(Icons.fast_forward_rounded,
                                    color: Colors.white, size: 40),
                              ],
                            ).animate().fade(duration: 200.ms).scale(),
                          )
                        : const SizedBox.shrink(),
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
                      _buildCenterControls(),
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

          if (_dragSeekTime != null && _isReady && !_isPiP)
            Positioned(
              top: MediaQuery.of(context).size.height / 2 - 120,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _dragSeekTime!.inMilliseconds >
                              _player.state.position.inMilliseconds
                          ? Icons.fast_forward_rounded
                          : Icons.fast_rewind_rounded,
                      color: AppTheme.primaryColor,
                      size: 40,
                      shadows: const [
                        Shadow(blurRadius: 20, color: Colors.black),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDuration(_dragSeekTime!),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        shadows: const [
                          Shadow(blurRadius: 10, color: Colors.black),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_showResumeNotif && !_isPiP) _buildResumeNotification(),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_rounded, color: Colors.white54, size: 48),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _unlockScreen,
            style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30))),
            child: const Text("Unlock Controls",
                style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildResumeNotification() {
    return Positioned(
      top: 24,
      right: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_toggle_off_rounded,
                color: AppTheme.primaryColor, size: 14),
            const SizedBox(width: 8),
            Text(
              'RESUMED AT $_resumeTime',
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.2, end: 0),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
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
              Positioned(
                left: 60,
                right: 60,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _currentTitle ?? widget.title ?? 'Video',
                    key: ValueKey(_currentTitle),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (widget.episode != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: _fetchingNextEpisode
                      ? Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 16, left: 16),
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
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

                            return IconButton(
                              onPressed: _playNextEpisode,
                              icon: Icon(
                                isNearEnd
                                    ? Icons.play_circle_outline_rounded
                                    : Icons.skip_next_rounded,
                                color: isNearEnd
                                    ? AppTheme.primaryColor
                                    : Colors.white,
                              ),
                              tooltip: 'Next Episode',
                              iconSize: 28,
                              padding: const EdgeInsets.all(8),
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
                                    end: isNearEnd ? 0.7 : 0.0);
                          },
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rewind
          IconButton(
            onPressed: () {
              _player
                  .seek(_player.state.position - const Duration(seconds: 10));
              _resetControlsTimer();
            },
            iconSize: 48,
            icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 64),
          // Play/Pause
          StreamBuilder<bool>(
              stream: _player.stream.playing,
              initialData: _player.state.playing,
              builder: (context, snapshot) {
                final playing = snapshot.data ?? false;
                return IconButton(
                  onPressed: () {
                    _player.playOrPause();
                    _resetControlsTimer();
                  },
                  iconSize: 72,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                );
              }),
          const SizedBox(width: 64),
          // Forward
          IconButton(
            onPressed: () {
              _player
                  .seek(_player.state.position + const Duration(seconds: 10));
              _resetControlsTimer();
            },
            iconSize: 48,
            icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
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
    // Basic validation - need at least S/E info
    if (_currentSeason == null || _currentEpisode == null) {
      _showNotif('Cannot determine next episode info');
      return;
    }

    // Providers that STRICTLY require TMDB ID
    final needsTmdb = ['River', 'VidLink'];
    if (needsTmdb.contains(_currentProvider) && widget.tmdbId == null) {
      _showNotif('Next episode requires TMDB ID');
      return;
    }

    setState(() => _fetchingNextEpisode = true);

    try {
      // Use current state for calculation
      var nextS = _currentSeason!;
      var nextE = _currentEpisode! + 1;

      // Only check metadata if we have TMDB ID
      if (widget.tmdbId != null) {
        try {
          final rive = RiveStreamService();
          var sDetails = await rive.getSeasonDetails(widget.tmdbId!, nextS);
          var hasNextEp = sDetails.any((e) => e.episodeNumber == nextE);

          if (!hasNextEp) {
            // Check next season
            // Optimistically try next season, episode 1
            nextS++;
            nextE = 1;
            // Validate next season exists if possible
            try {
              sDetails = await rive.getSeasonDetails(widget.tmdbId!, nextS);
              hasNextEp = sDetails.any((e) => e.episodeNumber == nextE);
            } catch (_) {
              hasNextEp = false;
            }
          }

          if (!hasNextEp) {
            // If we verified it doesn't exist, stop.
            setState(() => _fetchingNextEpisode = false);
            _showNotif('No next episode found');
            return;
          }
        } catch (e) {
          print('Error checking episode metadata: $e');
          // If metadata check fails, we might still try blindly if provider supports it?
          // For now, let's proceed optimistically if we have a provider that might work
        }
      } else {
        // Blindly try next episode if no TMDB ID (KissKh etc)
        // We just increment episode.
        // Note: We won't know to jump to next season S(n+1)E1 automatically without metadata,
        // so we just try S(n)E(n+1).
      }

      Map<String, dynamic> data = {};
      List<VideoSource> sources = [];
      List<VideoCaption> captions = [];

      final searchTitle = _currentTitle
              ?.replaceAll(
                  RegExp(r'\s*[-\s]*S\d+E\d+.*$', caseSensitive: false), '')
              .trim() ??
          "Video";

      if (_currentProvider == 'TG') {
        await (_player.platform as dynamic)
            .setProperty('demuxer-lavf-o', 'seekable=0');
      }
      if (_currentProvider == 'River') {
        final vsService = VideoSourceService();
        data = await vsService.getVideoSources(
          widget.tmdbId.toString(),
          nextS.toString(),
          nextE.toString(),
        );
        sources = (data['sources'] as List<VideoSource>?) ?? [];
        captions = (data['captions'] as List<VideoCaption>?) ?? [];
      } else if (_currentProvider == 'KissKh') {
        final kissKhService = KissKhService();
        // KissKh uses title search
        data = await kissKhService.getSources(
          searchTitle,
          nextS,
          nextE,
        );
        sources = (data['sources'] as List<VideoSource>?) ?? [];
        captions = (data['captions'] as List<VideoCaption>?) ?? [];
      } else if (_currentProvider == 'VidLink') {
        final vidLinkService = VidLinkService();
        data = await vidLinkService.getSources(
          widget.tmdbId!,
          isMovie: false,
          season: nextS,
          episode: nextE,
        );
        sources = (data['sources'] as List<VideoSource>?) ?? [];
        captions = (data['captions'] as List<VideoCaption>?) ?? [];
      } else if (_currentProvider == 'VidEasy') {
        final vidEasyService = VidEasyService();
        data = await vidEasyService.getSources(
          searchTitle,
          widget.mediaItem?.year ?? '2020',
          widget.tmdbId ??
              0, // Fallback to 0 if null, VidEasy might handle or fail
          isMovie: false,
          season: nextS,
          episode: nextE,
        );
        sources = (data['sources'] as List<VideoSource>?) ?? [];
        captions = (data['captions'] as List<VideoCaption>?) ?? [];
      } else if (_currentProvider == 'TG') {
        String? imdbId = widget.mediaItem?.id;
        if (imdbId != null && !imdbId.startsWith('tt')) {
          final tmdbId = int.tryParse(imdbId);
          if (tmdbId != null) {
            imdbId = await RiveStreamService()
                .getImdbIdFromTmdbId(tmdbId, isMovie: false);
          }
        }
        if (imdbId != null && imdbId.isNotEmpty) {
          final tgService = TgService();
          final checkResult = await tgService.check(imdbId);
          if (checkResult != null && checkResult.qualities.isNotEmpty) {
            final statusResult = await tgService.status(imdbId);
            if (statusResult != null && statusResult.ready) {
              final streams = await tgService.getStreams(imdbId,
                  season: nextS, episode: nextE);
              if (streams.isNotEmpty) {
                sources = streams
                    .map((s) => VideoSource(
                          url: '${TgService.baseUrl}${s.url}',
                          quality: s.quality,
                          format: 'Stream',
                          size: 'Unknown',
                        ))
                    .toList();
              }
            }
          }
        }
      }

      if (sources.isEmpty) {
        setState(() => _fetchingNextEpisode = false);
        _showNotif('No stream found for next episode');
        return;
      }

      final newUrl = sources.first.url;
      Map<String, String>? headers =
          sources.first.headers ?? widget.httpHeaders;

      // Save position of current episode before switching
      _savePosition();

      if (mounted) {
        setState(() {
          _currentSources = sources;
          _currentSeason = nextS;
          _currentEpisode = nextE;
          // Dynamically update title if it follows standard format, or just append S/E
          if (widget.title != null) {
            // Try to keep base title
            final baseTitle = widget.title!
                .replaceAll(RegExp(r'\s*[-\s]*S\d+E\d+.*$'), '')
                .trim();
            _currentTitle = '$baseTitle S${nextS}E${nextE}';
          } else {
            _currentTitle = '$searchTitle S${nextS}E${nextE}';
          }

          _externalSubtitles.clear();
          for (final caption in captions) {
            _externalSubtitles.add(ExternalSubtitle(
                uri: caption.file,
                title: caption.label,
                language: caption.label.split(' - ').first.trim()));
          }
          _fetchingNextEpisode = false;
        });
      }

      _player.setVolume(0.0);

      await _player.open(
        Media(newUrl, httpHeaders: headers),
        play: true,
      );

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

      try {
        await Future.delayed(const Duration(milliseconds: 400));
        await _player.stream.buffering
            .firstWhere((b) => !b)
            .timeout(const Duration(seconds: 5));
      } catch (_) {}

      _player.setVolume(_volumeBoost);
    } catch (e) {
      if (mounted) {
        setState(() => _fetchingNextEpisode = false);
      }
      _showNotif('Error: ${e.toString()}');
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
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Thumbnail Preview (placeholder with dark gradient)
                                Container(
                                  width: 120,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppTheme.primaryColor
                                            .withValues(alpha: 0.4),
                                        AppTheme.primaryColor
                                            .withValues(alpha: 0.1),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.image_rounded,
                                      color:
                                          Colors.white.withValues(alpha: 0.3),
                                      size: 32,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Time at position
                                Text(
                                  _formatDuration(_dragSeekTime ??
                                      Duration(
                                          milliseconds: (_sliderDraggingValue *
                                                  dur.inMilliseconds)
                                              .toInt())),
                                  style: GoogleFonts.robotoMono(
                                    color: AppTheme.primaryColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
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
                                              Colors.white.withValues(alpha: 0.3)),
                                        );
                                      },
                                    ),
                                  ),
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(
                                          enabledThumbRadius: 6),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                              overlayRadius: 14),
                                      activeTrackColor: AppTheme.primaryColor,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: AppTheme.primaryColor,
                                    ),
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

              const SizedBox(height: 12),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Quality Selector
                  if (_availableQualities.length > 1)
                    IconButton(
                      onPressed: _showQualitySelector,
                      icon: _buildQualityIcon(),
                      color: Colors.white,
                      iconSize: 28,
                    ),

                  _buildActionBtn(
                      icon: Icons.subtitles_rounded,
                      onTap: () => _showTrackSelector()),

                  _buildActionBtn(
                      icon: _fit == BoxFit.contain
                          ? Icons.aspect_ratio_rounded
                          : Icons.fit_screen_rounded,
                      onTap: _cycleFit),

                  // Speed Control
                  IconButton(
                    onPressed: _showSpeedSelector,
                    icon: const Icon(Icons.speed_rounded),
                    color: _playbackSpeed != 1.0
                        ? AppTheme.primaryColor
                        : Colors.white,
                    iconSize: 28,
                    tooltip: 'Playback Speed',
                  ),

                  _buildActionBtn(
                      icon: Icons.tune_rounded, onTap: _showPlaybackSettings),
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

  Widget _buildQualityIcon() {
    return const Icon(
      Icons.hd,
      color: Colors.white,
      size: 28,
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
      right: 45,
      top: 0,
      bottom: 0,
      child: Center(
        child: IconButton(
          onPressed: _lockScreen,
          icon: const Icon(Icons.lock_open_rounded),
          color: Colors.white,
          iconSize: 28,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withValues(alpha: 0.3),
            padding: const EdgeInsets.all(12),
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

  void _showQualitySelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('Select Quality',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _availableQualities.map((quality) {
              final isSelected = quality == _currentQuality;
              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _changeQuality(quality);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(quality,
                          style: TextStyle(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14)),
                      if (isSelected)
                        const Icon(Icons.check,
                            color: AppTheme.primaryColor, size: 20),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _changeQuality(String newQuality) async {
    if (newQuality == _currentQuality) return;

    // Save current position
    final currentPosition = _player.state.position;
    final wasPlaying = _player.state.playing;

    String newUrl = widget.url;
    Map<String, String>? headers = widget.httpHeaders;

    if (widget.sources != null && widget.sources!.isNotEmpty) {
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
          // if (mounted) Navigator.pop(context); // Remove close behavior on remove
        },
        subtitleDelay: _subtitleDelay,
        onAdjustSync: _adjustSync,
        subtitleColor: _subtitleColor,
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
        _availableQualities = newSources.map((s) => s.quality).toSet().toList();
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
        if (channels == '2' || channels.toLowerCase() == 'stereo')
          channelDesc = 'Stereo';
        if (channels == '6' || channels.toLowerCase() == '5.1')
          channelDesc = '5.1';
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
            style:
                TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
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
                                                        .withValues(alpha: 0.2)),
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
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
                                color: AppTheme.errorColor.withValues(alpha: 0.2)),
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
                                  color:
                                      AppTheme.textSecondary.withValues(alpha: 0.2),
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
                ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3))
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
                                  color: AppTheme.primaryColor.withValues(alpha: 0.8),
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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
                      const Icon(Icons.tune_rounded,
                          color: AppTheme.primaryColor, size: 20),
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
                                      activeColor: AppTheme.primaryColor,
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
                                color: AppTheme.primaryColor.withValues(alpha: 0.15),
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
            color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.9),
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
