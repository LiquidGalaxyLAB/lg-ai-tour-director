import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A polished, self-contained showcase card for the Home screen: a bundled AI
/// tour film that autoplays **muted and looping** inline (so it never demands
/// attention or sound), with a tap opening a fullscreen player with audio.
///
/// Robust by design — if the asset fails to load, it shows a branded gradient
/// placeholder instead of breaking the Home layout.
class ShowcaseVideoCard extends StatefulWidget {
  const ShowcaseVideoCard({
    super.key,
    this.asset = 'assets/video/Tour-video.mp4',
  });

  final String asset;

  @override
  State<ShowcaseVideoCard> createState() => _ShowcaseVideoCardState();
}

class _ShowcaseVideoCardState extends State<ShowcaseVideoCard> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _muted = true; // starts muted so autoplay is allowed everywhere
  bool _playing = true;

  @override
  void initState() {
    super.initState();
    final c = VideoPlayerController.asset(widget.asset);
    _controller = c;
    c
        .initialize()
        .then((_) {
          c
            ..setLooping(true)
            ..setVolume(0)
            ..play();
          if (mounted) setState(() => _ready = true);
        })
        .catchError((Object e) {
          debugPrint('[Showcase] video init failed: $e');
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    if (!_ready) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenPlayer(asset: widget.asset),
      ),
    );
  }

  void _toggleMute() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      _muted = !_muted;
      c.setVolume(_muted ? 0 : 1);
    });
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null) return;
    setState(() {
      _playing = !_playing;
      _playing ? c.play() : c.pause();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = _controller;
    final aspect = (_ready && c != null && c.value.aspectRatio > 0)
        ? c.value.aspectRatio
        : 16 / 9;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: aspect,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video, or a branded fallback.
            if (_ready && c != null)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              )
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: _failed
                      ? const Icon(
                          Icons.movie_outlined,
                          color: Colors.white70,
                          size: 36,
                        )
                      : const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white70),
                          ),
                        ),
                ),
              ),

            // Legibility scrim.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black38, Colors.transparent, Colors.black54],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),

            // Tap the video area → play / pause inline.
            if (_ready)
              Material(
                color: Colors.transparent,
                child: InkWell(onTap: _togglePlay),
              ),

            // Big paused indicator.
            if (_ready && !_playing)
              const IgnorePointer(
                child: Icon(
                  Icons.play_circle_fill_rounded,
                  size: 56,
                  color: Colors.white,
                ),
              ),

            // Top-left label.
            const Positioned(
              top: 12,
              left: 12,
              child: _Badge(
                icon: Icons.movie_creation_rounded,
                label: 'AI FILM',
              ),
            ),

            // Top-right controls: mute + fullscreen.
            if (_ready)
              Positioned(
                top: 8,
                right: 8,
                child: Row(
                  children: [
                    _RoundButton(
                      icon: _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      onTap: _toggleMute,
                    ),
                    const SizedBox(width: 6),
                    _RoundButton(
                      icon: Icons.fullscreen_rounded,
                      onTap: _openFullscreen,
                    ),
                  ],
                ),
              ),

            // Bottom-left caption.
            Positioned(
              left: 14,
              right: 14,
              bottom: 12,
              child: Text(
                'See a sample tour film',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Fullscreen playback with sound, scrubbing and tap-to-pause.
class _FullscreenPlayer extends StatefulWidget {
  const _FullscreenPlayer({required this.asset});

  final String asset;

  @override
  State<_FullscreenPlayer> createState() => _FullscreenPlayerState();
}

class _FullscreenPlayerState extends State<_FullscreenPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.asset);
    _controller.initialize().then((_) {
      _controller
        ..setLooping(true)
        ..setVolume(1)
        ..play();
      if (mounted) setState(() => _ready = true);
    });
  }

  void _toggleMute() {
    setState(() {
      _muted = !_muted;
      _controller.setVolume(_muted ? 0 : 1);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Sample AI Film'),
        actions: [
          if (_ready)
            IconButton(
              icon: Icon(
                _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              ),
              onPressed: _toggleMute,
            ),
        ],
      ),
      body: Center(
        child: _ready
            ? GestureDetector(
                onTap: () => setState(
                  () => _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play(),
                ),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio == 0
                          ? 16 / 9
                          : _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    VideoProgressIndicator(_controller, allowScrubbing: true),
                    if (!_controller.value.isPlaying)
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
