import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'dart:async';
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

  // Resume support
  Timer? _savePositionTimer;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    _initPlayer();

    // Auto-hide controls
    _resetControlsTimer();
  }

  Future<void> _initPlayer() async {
    // Restore position
    final provider = context.read<AppProvider>();
    final savedPosMs = provider.getSetting<int>('pos_${widget.url.hashCode}');
    final start =
        savedPosMs != null ? Duration(milliseconds: savedPosMs) : Duration.zero;

    await _player.open(Media(widget.url));

    if (start > Duration.zero) {
      await _player.seek(start);
      // Show resumption toast
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resumed from ${_formatDuration(start)}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.black87,
            behavior: SnackBarBehavior.floating,
            width: 200,
          ),
        );
      }
    }

    _player.play();

    if (mounted) setState(() => _isReady = true);

    // Periodic save
    _savePositionTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _savePosition());
  }

  Future<void> _savePosition() async {
    if (!mounted || _player.state.duration == Duration.zero) return;

    final currentPos = _player.state.position.inMilliseconds;
    if (currentPos > 5000) {
      // Only save after 5 seconds
      await context
          .read<AppProvider>()
          .saveSetting('pos_${widget.url.hashCode}', currentPos);
    }
  }

  Timer? _controlsTimer;
  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    if (_showControls && !_player.state.playing)
      return; // Keep controls if paused

    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _player.state.playing && !_isLocked) {
        setState(() => _showControls = false);
      }
    });
  }

  @override
  void dispose() {
    _savePosition(); // Save one last time
    _savePositionTimer?.cancel();
    _controlsTimer?.cancel();
    _player.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: SystemUiOverlay.values);
    super.dispose();
  }

  void _toggleControls() {
    if (_isLocked) {
      setState(() => _showControls = !_showControls);
      _resetControlsTimer();
      return;
    }
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetControlsTimer();
  }

  void _cycleSpeed() {
    const speeds = [0.5, 1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexOf(_playbackSpeed);
    final nextIndex = (currentIndex + 1) % speeds.length;
    setState(() => _playbackSpeed = speeds[nextIndex]);
    _player.setRate(_playbackSpeed);
  }

  void _cycleFit() {
    setState(() {
      if (_fit == BoxFit.contain)
        _fit = BoxFit.cover;
      else if (_fit == BoxFit.cover)
        _fit = BoxFit.fill;
      else
        _fit = BoxFit.contain;
    });
  }

  void _toggleFullscreen() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: SystemUiOverlay.values);
    } else {
      SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  void _showTrackSelection(String type) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _TrackSelector(player: _player, type: type));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        onDoubleTap: () => _player.playOrPause(),
        child: Stack(
          children: [
            Center(
              child: _isReady
                  ? Video(
                      controller: _controller,
                      fit: _fit,
                      controls: (state) => const SizedBox.shrink(),
                    )
                  : const CircularProgressIndicator(
                      color: AppTheme.primaryColor),
            ),

            // UI Overlay
            if (_isReady)
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Stack(
                    children: [
                      Container(color: Colors.black38), // Dim
                      _buildTopBar(),
                      _buildCenterControls(),
                      _buildBottomControls(),
                    ],
                  ),
                ),
              ),

            // Lock Button (Always interactable if visible)
            if (_showControls)
              Positioned(
                left: 24,
                top: MediaQuery.of(context).size.height / 2 - 24,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _isLocked = !_isLocked),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: _isLocked ? Colors.white : Colors.white24,
                          shape: BoxShape.circle,
                          boxShadow: [
                            if (_isLocked)
                              BoxShadow(color: Colors.white24, blurRadius: 10)
                          ]),
                      child: Icon(
                          _isLocked
                              ? Icons.lock_rounded
                              : Icons.lock_open_rounded,
                          color: _isLocked ? Colors.black : Colors.white,
                          size: 24),
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    if (_isLocked) return const SizedBox.shrink();
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black87, Colors.transparent])),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    widget.title ?? 'Video',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Aspect Ratio
                IconButton(
                  icon: Icon(
                      _fit == BoxFit.contain
                          ? Icons.aspect_ratio_rounded
                          : (_fit == BoxFit.cover
                              ? Icons.crop_free_rounded
                              : Icons.fullscreen_rounded),
                      color: Colors.white,
                      size: 20),
                  onPressed: _cycleFit,
                  tooltip: 'Aspect Ratio',
                ),
                // Speed
                TextButton(
                  onPressed: _cycleSpeed,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: Text('${_playbackSpeed}x',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                // Subs
                IconButton(
                  icon: const Icon(Icons.closed_caption_rounded,
                      color: Colors.white),
                  onPressed: () => _showTrackSelection('subtitle'),
                ),
                // Audio
                IconButton(
                  icon: const Icon(Icons.queue_music_rounded,
                      color: Colors.white),
                  onPressed: () => _showTrackSelection('audio'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    if (_isLocked) return const SizedBox.shrink();
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildCircleButton(
              icon: Icons.replay_10_rounded,
              onTap: () {
                _player
                    .seek(_player.state.position - const Duration(seconds: 10));
                _resetControlsTimer();
              }),
          const SizedBox(width: 40),
          StreamBuilder<bool>(
              stream: _player.stream.playing,
              builder: (context, snapshot) {
                final playing = snapshot.data ?? false;
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                  child: IconButton(
                    iconSize: 40,
                    icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: Colors.white),
                    onPressed: () {
                      _player.playOrPause();
                      _resetControlsTimer();
                    },
                  ),
                );
              }),
          const SizedBox(width: 40),
          _buildCircleButton(
              icon: Icons.forward_10_rounded,
              onTap: () {
                _player
                    .seek(_player.state.position + const Duration(seconds: 10));
                _resetControlsTimer();
              }),
        ],
      ),
    );
  }

  Widget _buildCircleButton(
      {required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24)),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    if (_isLocked) return const SizedBox.shrink();
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black87, Colors.transparent])),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreamBuilder<Duration>(
                    stream: _player.stream.position,
                    builder: (context, posSnap) {
                      final position = posSnap.data ?? Duration.zero;
                      final duration = _player.state.duration;
                      return Column(children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(position),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(_formatDuration(duration),
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 8, elevation: 2),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 20),
                            activeTrackColor: AppTheme.primaryColor,
                            inactiveTrackColor: Colors.white24,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: (duration.inMilliseconds > 0)
                                ? (position.inMilliseconds /
                                        duration.inMilliseconds)
                                    .clamp(0.0, 1.0)
                                : 0.0,
                            onChanged: (v) {
                              _resetControlsTimer();
                              final ms = (v * duration.inMilliseconds).round();
                              _player.seek(Duration(milliseconds: ms));
                            },
                          ),
                        ),
                      ]);
                    }),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.fullscreen_rounded,
                          color: Colors.white),
                      onPressed: _toggleFullscreen,
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    var seconds = duration.inSeconds;
    final hours = seconds ~/ 3600;
    seconds = seconds % 3600;
    final minutes = seconds ~/ 60;
    seconds = seconds % 60;

    final h = hours > 0 ? '${hours.toString().padLeft(2, '0')}:' : '';
    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');
    return '$h$m:$s';
  }
}

class _TrackSelector extends StatelessWidget {
  final Player player;
  final String type; // 'audio' or 'subtitle'

  const _TrackSelector({required this.player, required this.type});

  @override
  Widget build(BuildContext context) {
    final tracks = type == 'audio'
        ? player.state.tracks.audio
        : player.state.tracks.subtitle;

    final current = type == 'audio'
        ? player.state.track.audio
        : player.state.track.subtitle;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Select ${type == 'audio' ? 'Audio' : 'Subtitle'}",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          const SizedBox(height: 20),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              separatorBuilder: (_, __) =>
                  const Divider(color: Colors.white10, height: 1),
              itemCount: tracks.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // None/Off
                  final isNone = (type == 'audio')
                      ? (current.id == 'no' || current.id == 'auto')
                      : (current.id == 'no' || current.id == 'auto');

                  return _buildTrackTile(
                      context, "Default / None", "no", isNone);
                }

                final track = tracks[index - 1];
                final isSelected = track == current;
                return _buildTrackTile(
                    context,
                    track.title ?? track.language ?? "Track $index",
                    track.id,
                    isSelected,
                    track);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackTile(
      BuildContext context, String title, String subtitle, bool isSelected,
      [dynamic track]) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Text(title,
          style: TextStyle(
              color: isSelected ? AppTheme.primaryColor : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(subtitle,
          style: const TextStyle(color: Colors.grey, fontSize: 11)),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppTheme.primaryColor)
          : null,
      onTap: () {
        if (type == 'audio') {
          if (track == null)
            player.setAudioTrack(AudioTrack.auto());
          else
            player.setAudioTrack(track);
        } else {
          if (track == null)
            player.setSubtitleTrack(SubtitleTrack.auto());
          else
            player.setSubtitleTrack(track);
        }
        Navigator.pop(context);
      },
    );
  }
}
