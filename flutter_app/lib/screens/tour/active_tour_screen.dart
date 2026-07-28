import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../models/location.dart';
import '../../models/tour_flow.dart';
import '../../providers/ssh_provider.dart';
import '../../providers/tour_state_provider.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/location_image.dart';
import '../../shared/widgets/map_placeholder.dart';

class ActiveTourScreen extends ConsumerStatefulWidget {
  const ActiveTourScreen({super.key, required this.args});

  final TourFlowArgs args;

  @override
  ConsumerState<ActiveTourScreen> createState() => _ActiveTourScreenState();
}

class _ActiveTourScreenState extends ConsumerState<ActiveTourScreen> {
  final FlutterTts _tts = FlutterTts();
  bool _voiceNarration = true;

  int _spokenIndex = -1;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _voiceNarration = prefs.getBool('pref_voice_narration') ?? true;
    if (!mounted) return;

    final notifier = ref.read(tourStateProvider.notifier);
    final tour = ref.read(tourStateProvider);
    final rigDriven = ref.read(sshConnectionProvider).isConnected;
    final resuming =
        tour.isRunning && tour.totalLocations == widget.args.locations.length;
    if (resuming) {
      _spokenIndex = tour.currentIndex;
      if (!tour.isPaused) _speak(tour.currentIndex); // stay silent if paused
    } else if (rigDriven) {
      // The LG flight drives scene changes (enterScene) as it arrives at each
      // landmark, so narration stays locked to the real camera. Nothing to time
      // here — just wait for the flight's first enterScene(0).
      _spokenIndex = -1;
      notifier.start(widget.args, rigDriven: true);
    } else {
      // No rig connected (companion-only, e.g. web preview): fall back to the
      // fixed rig-matched timer so the UI still advances on its own.
      _spokenIndex = 0;
      notifier.start(widget.args);
      await Future<void>.delayed(TourStateNotifier.overviewDelay);
      if (!mounted) return;
      if (ref.read(tourStateProvider).currentIndex == 0) _speak(0);
    }
  }

  /// Speaks the narration for [index]. Best-effort — ignores TTS failures.
  Future<void> _speak(int index) async {
    if (!_voiceNarration) return;
    if (index < 0 || index >= widget.args.locations.length) return;
    try {
      await _tts.stop();
      await _tts.speak(widget.args.locations[index].whySignificant);
    } catch (_) {}
  }

  void _complete() {
    if (_ending) return;
    _ending = true;
    _tts.stop();
    ref.read(tourStateProvider.notifier).finish();
    context.pushReplacement('/home/post-tour', extra: widget.args);
  }

  Future<void> _end() async {
    if (_ending) return;
    _ending = true;
    await _tts.stop();
    ref.read(tourStateProvider.notifier).finish();
    try {
      await ref.read(sshConnectionProvider.notifier).stopTour();
    } catch (e) {
      debugPrint('ActiveTour: LG stop on End Tour failed: $e');
    }
    if (!mounted) return;
    context.pushReplacement('/home/post-tour', extra: widget.args);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.args.locations.length;

    final view = ref.watch(
      tourStateProvider.select(
        (s) => (index: s.currentIndex, status: s.status, paused: s.isPaused),
      ),
    );
    final sceneIndex = view.index.clamp(0, total - 1);
    final loc = widget.args.locations[sceneIndex];

    ref.listen<TourState>(tourStateProvider, (prev, next) {
      if (next.status == TourStatus.ended) {
        _complete();
        return;
      }
      if (next.isRunning && next.currentIndex != _spokenIndex) {
        _spokenIndex = next.currentIndex;
        _speak(next.currentIndex);
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        context.go('/home');
      },
      child: Scaffold(
        body: Column(
          children: [
            const SafeArea(bottom: false, child: AppHeader()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _SceneDots(total: total, current: sceneIndex),
                  const SizedBox(height: 16),
                  _SceneCard(location: loc),
                  const SizedBox(height: 16),
                  _SubtitleCard(text: loc.whySignificant),
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
                          onPressed: () {
                            final n = ref.read(tourStateProvider.notifier);
                            if (view.paused) {
                              n.resume();
                              _speak(sceneIndex); // restart current narration
                            } else {
                              n.pause();
                              _tts.stop();
                            }
                          },
                          icon: Icon(
                            view.paused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                          ),
                          label: Text(view.paused ? 'Resume' : 'Pause'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: sceneIndex >= total - 1
                              ? null
                              : () {
                                  ref
                                      .read(tourStateProvider.notifier)
                                      .requestNext();
                                  _tts.stop();
                                },
                          icon: const Icon(Icons.skip_next_rounded),
                          label: const Text('Next Scene'),
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

class _SubtitleCard extends ConsumerWidget {
  const _SubtitleCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(
      tourStateProvider.select((s) => s.sceneProgress),
    );
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
