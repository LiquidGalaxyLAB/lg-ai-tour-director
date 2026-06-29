import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../models/location.dart';
import '../../models/tour_flow.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/location_image.dart';
import '../../shared/widgets/map_placeholder.dart';

/// Active immersive tour (mockups 8 & 9): current scene + narration subtitles,
/// scene dots, LookAt/Orbit readouts, a synced map, and Pause/Skip/End.
///
/// This is the on-device companion view; deploying KML to the rig is the KML
/// engine's job (not yet wired), so here scenes advance on a timer and narration
/// is spoken best-effort via TTS.
class ActiveTourScreen extends StatefulWidget {
  const ActiveTourScreen({super.key, required this.args});

  final TourFlowArgs args;

  @override
  State<ActiveTourScreen> createState() => _ActiveTourScreenState();
}

class _ActiveTourScreenState extends State<ActiveTourScreen> {
  final FlutterTts _tts = FlutterTts();
  Timer? _timer;
  int _scene = 0;
  double _elapsed = 0;
  bool _paused = false;
  bool _voiceNarration = true;

  // Demo pacing: cap the per-scene dwell so the walkthrough progresses.
  double get _sceneDuration => widget
      .args
      .locations[_scene]
      .suggestedDurationSeconds
      .clamp(6, 14)
      .toDouble();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _voiceNarration = prefs.getBool('pref_voice_narration') ?? true;
    if (!mounted) return;
    _startScene();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_paused) return;
      setState(() => _elapsed += 0.25);
      if (_elapsed >= _sceneDuration) _next();
    });
  }

  Future<void> _startScene() async {
    // Respect the Voice Narration preference — skip TTS entirely when off.
    if (!_voiceNarration) return;
    final loc = widget.args.locations[_scene];
    try {
      await _tts.stop();
      await _tts.speak(loc.whySignificant);
    } catch (_) {
      // TTS is best-effort; ignore failures (e.g. no engine on web).
    }
  }

  void _next() {
    if (_scene >= widget.args.locations.length - 1) {
      _end();
      return;
    }
    setState(() {
      _scene++;
      _elapsed = 0;
    });
    _startScene();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _tts.stop();
    } else {
      _startScene();
    }
  }

  void _end() {
    _timer?.cancel();
    _tts.stop();
    context.pushReplacement('/home/post-tour', extra: widget.args);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = widget.args.locations[_scene];
    final total = widget.args.locations.length;
    final progress = (_elapsed / _sceneDuration).clamp(0.0, 1.0);

    return Scaffold(
      body: Column(
        children: [
          const SafeArea(bottom: false, child: AppHeader()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _SceneDots(total: total, current: _scene),
                const SizedBox(height: 16),
                _SceneCard(location: loc),
                const SizedBox(height: 16),
                _SubtitleCard(text: loc.whySignificant, progress: progress),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.center_focus_strong,
                        title: 'LOOKAT TARGET',
                        rows: const [
                          ('RANGE', '600m'),
                          ('TILT', '60°'),
                          ('HEADING', '0°'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _InfoCard(
                        icon: Icons.threesixty,
                        title: 'CAMERA ORBIT',
                        rows: const [
                          ('RADIUS', '250m'),
                          ('ALTITUDE', '400m'),
                          ('TILT', '65°'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const MapPlaceholder(height: 160, synced: true),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _togglePause,
                        icon: Icon(
                          _paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                        ),
                        label: Text(_paused ? 'Resume' : 'Pause Tour'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _next,
                        icon: const Icon(Icons.skip_next_rounded),
                        label: const Text('Skip Scene'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _end,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                  ),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('End Tour'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneDots extends StatelessWidget {
  const _SceneDots({required this.total, required this.current});
  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++) ...[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: i <= current
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  color: i <= current
                      ? Colors.white
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (i < total - 1)
            Container(
              width: 18,
              height: 2,
              color: i < current
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
        ],
      ],
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.location});
  final TourLocation location;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 170,
        child: Stack(
          fit: StackFit.expand,
          children: [
            LocationImage(location: location, borderRadius: 16),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54],
                  stops: [0.45, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'CURRENT SCENE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    location.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    location.type,
                    style: const TextStyle(color: Colors.white70),
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

class _SubtitleCard extends StatelessWidget {
  const _SubtitleCard({required this.text, required this.progress});
  final String text;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.googleBlueBright,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.subtitles_outlined, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text(
                'NARRATION SUBTITLES',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"$text"',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.rows,
  });
  final IconData icon;
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    k,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    v,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
