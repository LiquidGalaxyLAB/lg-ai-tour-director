import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../kml/generator.dart';
import '../../models/location.dart';
import '../../models/tour_flow.dart';
import '../../providers/ssh_provider.dart';
import '../../providers/tour_state_provider.dart';
import '../../services/maps/map_sync_service.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/location_image.dart';
import '../../shared/widgets/sync_map_view.dart';
import 'fullscreen_map_screen.dart';

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

  // Subtitle-language name (from Tour Preferences) → BCP-47 locale for TTS.
  static const _ttsBcp47 = {
    'English': 'en-US',
    'Spanish': 'es-ES',
    'French': 'fr-FR',
    'Hindi': 'hi-IN',
    'Arabic': 'ar-SA',
    'German': 'de-DE',
    'Portuguese': 'pt-BR',
    'Chinese': 'zh-CN',
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // The rig owns the camera during the tour, so map sync starts off and is
    // enabled only while paused (never during the orbit).
    MapSyncService.instance.disable();

    final prefs = await SharedPreferences.getInstance();
    _voiceNarration = prefs.getBool('pref_voice_narration') ?? true;
    // Speak narration in the chosen subtitle language (best-effort per device).
    final lang = prefs.getString('pref_subtitle_language') ?? 'English';
    try {
      await _tts.setLanguage(_ttsBcp47[lang] ?? 'en-US');
    } catch (_) {}
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
      // The LG flight drives scene changes (enterScene) on arrival, so
      // narration stays locked to the camera; just await the first enterScene(0).
      _spokenIndex = -1;
      notifier.start(widget.args, rigDriven: true);
    } else {
      // No rig connected (companion-only): fall back to the timer so the UI
      // still advances.
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
    MapSyncService.instance.disable();
    super.dispose();
  }

  /// Enable map to rig sync (while paused), matching the rig's screen count.
  void _enableSync() {
    MapSyncService.instance.updateRigCount(
      ref.read(sshConnectionProvider).config.totalScreens,
    );
    MapSyncService.instance.enable();
  }

  Future<void> _setNarration(bool on) async {
    setState(() => _voiceNarration = on);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pref_voice_narration', on);
    } catch (_) {}
    if (!mounted) return;
    if (on) {
      // Pick up the current scene's voice mid-tour.
      final total = widget.args.locations.length;
      final idx = ref.read(tourStateProvider).currentIndex.clamp(0, total - 1);
      _speak(idx);
    } else {
      await _tts.stop(); // silence now; the subtitle card stays visible
    }
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
                          title: 'lookat_target'.tr(),
                          rows: [
                            (
                              'range'.tr(),
                              '${KmlGenerator.orbitRange.toInt()}m',
                            ),
                            ('tilt'.tr(), '${KmlGenerator.orbitTilt.toInt()}°'),
                            ('heading'.tr(), '0°'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoCard(
                          icon: Icons.threesixty,
                          title: 'camera_orbit'.tr(),
                          // Real server-side orbit loop (orbitLoopCommand).
                          rows: [
                            ('sweep'.tr(), '360°'),
                            (
                              'step'.tr(),
                              '${KmlGenerator.orbitLoopStepDegrees}°',
                            ),
                            ('tilt'.tr(), '${KmlGenerator.orbitTilt.toInt()}°'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SyncMapView(
                    locations: widget.args.locations,
                    height: 160,
                    frameAllLocations: false,
                    focusLocation: loc,
                    onExpand: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FullscreenMapScreen(
                          locations: widget.args.locations,
                          focus: loc,
                          pauseTour: true, // pause the flight while exploring
                        ),
                      ),
                    ),
                  ),
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
                              MapSyncService.instance.disable();
                            } else {
                              n.pause();
                              _tts.stop();
                              // Paused → free to explore; mirror pans to the rig.
                              _enableSync();
                            }
                          },
                          icon: Icon(
                            view.paused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                          ),
                          label: Text(
                            view.paused ? 'resume'.tr() : 'pause'.tr(),
                          ),
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
                                  // Skipping resumes the flight → rig owns the
                                  // camera again, so stop mirroring.
                                  MapSyncService.instance.disable();
                                },
                          icon: const Icon(Icons.skip_next_rounded),
                          label: Text('next_scene'.tr()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _setNarration(!_voiceNarration),
                    icon: Icon(
                      _voiceNarration
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                    ),
                    label: Text(
                      _voiceNarration
                          ? 'narration_on'.tr()
                          : 'narration_off'.tr(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _end,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text('end_tour'.tr()),
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
                    child: Text(
                      'current_scene'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    location.name,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
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
          Row(
            children: [
              const Icon(
                Icons.subtitles_outlined,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'narration_subtitles'.tr(),
                style: const TextStyle(
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
