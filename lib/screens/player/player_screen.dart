import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:simple_pip_mode/simple_pip.dart';
import '../../theme/app_theme.dart';
import '../../providers/providers.dart';

class PlayerScreen extends StatefulWidget {
  final String url;
  final String? title;
  final bool isLocal;

  const PlayerScreen(
      {super.key, required this.url, this.title, this.isLocal = false});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  bool _showControls = true;
  bool _isLocked = false;
  bool _isReady = false;
  double _playbackSpeed = 1.0;
  BoxFit _fit = BoxFit.contain;

  Timer? _savePositionTimer;
  Timer? _controlsTimer;

  SimplePip pip = SimplePip();
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _player = Player();
    _controller = VideoController(_player);

    _initPlayer();
    _resetControlsTimer();

    pip.onPipEntered = _onPipEntered;
  }

  String get _storageKey {
    if (widget.title != null && widget.title!.isNotEmpty) {
      return 'pos_${widget.title.hashCode}';
    }
    return 'pos_${widget.url.hashCode}';
  }

  Future<void> _initPlayer() async {
    final provider = context.read<AppProvider>();
    final savedPosMs = provider.getSetting<int>(_storageKey);
    final start =
        savedPosMs != null ? Duration(milliseconds: savedPosMs) : Duration.zero;

    await _player.open(Media(widget.url));

    if (start > Duration.zero) {
      await _player.seek(start);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Resumed from ${_formatDuration(start)}"),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
        ));
      }
    }
    // _player.setVolume(_volume); // volume removed
    _player.play();

    if (mounted) setState(() => _isReady = true);

    _savePositionTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _savePosition());
  }

  Future<void> _savePosition() async {
    if (!mounted || _player.state.duration == Duration.zero) return;
    final currentPos = _player.state.position.inMilliseconds;
    if (currentPos > 5000) {
      await context.read<AppProvider>().saveSetting(_storageKey, currentPos);
    }
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

  @override
  void dispose() {
    _savePosition();
    _savePositionTimer?.cancel();
    _controlsTimer?.cancel();
    _player.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  void _onPipEntered() {
    setState(() {
      _showControls = false;
    });
  }

  void _toggleControls() {
    if (_isLocked) return;
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
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (_isLocked) {
            setState(() => _showControls = !_showControls);
          } else {
            _toggleControls();
          }
        },
        onDoubleTap: _isLocked ? null : () => _player.playOrPause(),
        child: Stack(
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
                        subtitleViewConfiguration:
                            const SubtitleViewConfiguration(
                          style: TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
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
                  : const CircularProgressIndicator(
                      color: AppTheme.primaryColor),
            ),

            // Locked UI
            if (_isLocked && _showControls)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded,
                        color: Colors.white54, size: 48),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _unlockScreen,
                      style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30))),
                      child: const Text("Unlock Controls",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),

            // Controls Overlay
            if (_isReady && !_isLocked)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Stack(
                    children: [
                      // Gradient / Dim
                      Container(color: Colors.black26),

                      // Top Bar
                      _buildTopBar(),

                      // Center
                      _buildCenterControls(),

                      // Bottom
                      _buildBottomControls(),

                      // Indicators (Volume)
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
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
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(
                  widget.title ?? 'Video',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(blurRadius: 10, color: Colors.black)]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 48), // Balance spacing
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

  Widget _buildBottomControls() {
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
                        Row(
                          children: [
                            Text(_formatDuration(pos),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                            Expanded(
                                child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14),
                                activeTrackColor: AppTheme.primaryColor,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: AppTheme.primaryColor,
                              ),
                              child: Slider(
                                value: (dur.inMilliseconds > 0)
                                    ? (pos.inMilliseconds / dur.inMilliseconds)
                                        .clamp(0.0, 1.0)
                                    : 0.0,
                                onChanged: (v) {
                                  _resetControlsTimer();
                                  _player.seek(Duration(
                                      milliseconds:
                                          (v * dur.inMilliseconds).toInt()));
                                },
                              ),
                            )),
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
                  _buildActionBtn(
                      icon: Icons.speed_rounded, onTap: _changeSpeed),
                  _buildActionBtn(
                      icon: _isLocked
                          ? Icons.lock_rounded
                          : Icons.lock_open_rounded,
                      onTap: _lockScreen),
                  _buildActionBtn(
                      icon: Icons.subtitles_rounded,
                      onTap: () => _showTrackSelector()),
                  _buildActionBtn(
                      icon: _fit == BoxFit.contain
                          ? Icons.aspect_ratio_rounded
                          : Icons.fit_screen_rounded,
                      onTap: _cycleFit),
                  _buildActionBtn(
                      icon: Icons.picture_in_picture_alt_rounded,
                      onTap: () => pip.enterPipMode()),
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

  void _changeSpeed() {
    // Cycle speed
    final speeds = [0.5, 1.0, 1.25, 1.5, 2.0];
    final idx = speeds.indexOf(_playbackSpeed);
    final next = speeds[(idx + 1) % speeds.length];
    setState(() => _playbackSpeed = next);
    _player.setRate(_playbackSpeed);
  }

  void _cycleFit() {
    setState(() {
      _fit = (_fit == BoxFit.contain) ? BoxFit.cover : BoxFit.contain;
    });
  }

  void _showTrackSelector() {
    showDialog(
      context: context,
      builder: (_) => _UnifiedTrackSelector(player: _player),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    }
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}

class _UnifiedTrackSelector extends StatefulWidget {
  final Player player;
  const _UnifiedTrackSelector({required this.player});

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
      backgroundColor: const Color(0xFF151515),
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
            TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primaryColor,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: "Audio"),
                Tab(text: "Subtitles"),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList('audio'),
                  _buildList('subtitle'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(String type) {
    final tracks = type == 'audio'
        ? widget.player.state.tracks.audio
        : widget.player.state.tracks.subtitle;

    final current = type == 'audio'
        ? widget.player.state.track.audio
        : widget.player.state.track.subtitle;

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: tracks.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index == 0) {
          final isOff = current.id == 'no' || current.id == 'auto';
          return _buildItem("Off", isOff, null, type);
        }
        final track = tracks[index - 1];
        final isSelected = track == current;
        final title = _getFriendlyTrackName(track);
        return _buildItem(title, isSelected, track, type);
      },
    );
  }

  String _getFriendlyTrackName(dynamic track) {
    String? title = track.title;
    String? lang = track.language;

    // Common language codes map
    final langMap = {
      'eng': 'English',
      'en': 'English',
      'spa': 'Spanish',
      'es': 'Spanish',
      'fre': 'French',
      'fr': 'French',
      'ger': 'German',
      'de': 'German',
      'ita': 'Italian',
      'it': 'Italian',
      'jpn': 'Japanese',
      'ja': 'Japanese',
      'kor': 'Korean',
      'ko': 'Korean',
      'chi': 'Chinese',
      'zh': 'Chinese',
      'rus': 'Russian',
      'ru': 'Russian',
      'hin': 'Hindi',
      'hi': 'Hindi',
    };

    String displayLang = langMap[lang?.toLowerCase()] ?? lang ?? 'Unknown';
    // Capitalize first letter if not from map
    if (displayLang.length > 1 && !langMap.containsKey(lang?.toLowerCase())) {
      displayLang = displayLang[0].toUpperCase() + displayLang.substring(1);
    }

    if (title != null && title.isNotEmpty) {
      // Clean up title if it contains technical jargon
      // Ideally we prefer "English - SDH" or just "English"
      if (title.toLowerCase() == displayLang.toLowerCase()) {
        return displayLang;
      }
      return "$displayLang ($title)";
    }

    return displayLang;
  }

  Widget _buildItem(String title, bool isSelected, dynamic track, String type) {
    return InkWell(
      onTap: () {
        if (type == 'audio') {
          widget.player.setAudioTrack(track ?? AudioTrack.auto());
        } else {
          widget.player.setSubtitleTrack(track ?? SubtitleTrack.auto());
        }
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (isSelected)
              const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            else
              const SizedBox(width: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
