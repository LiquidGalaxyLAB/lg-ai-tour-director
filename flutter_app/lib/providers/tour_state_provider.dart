import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../kml/generator.dart';
import '../models/tour_flow.dart';

enum TourStatus { idle, running, ended }

/// Snapshot of the currently-active tour. [progress] is the coarse
/// scene-index-based completion; [sceneProgress] is the smooth 0..1 fill of the
/// CURRENT scene (for the subtitle bar). Neither reflects the rig's real KML
/// playback time — both are driven by the notifier's fixed rig-matched timers.
class TourState {
  const TourState({
    this.status = TourStatus.idle,
    this.currentIndex = 0,
    this.totalLocations = 0,
    this.sceneProgress = 0.0,
    this.args,
  });

  final TourStatus status;
  final int currentIndex; // 0-based scene
  final int totalLocations;
  final double sceneProgress; // 0..1 fill of the current scene
  final TourFlowArgs? args; // so the "return to tour" banner can re-open it

  bool get isRunning => status == TourStatus.running;

  /// Fraction 0..1 of the whole tour completed (scene-index based).
  double get progress {
    if (totalLocations <= 0) return 0;
    return (currentIndex / totalLocations).clamp(0.0, 1.0);
  }

  int get percent => (progress * 100).round();

  TourState copyWith({int? currentIndex, double? sceneProgress}) => TourState(
    status: status,
    currentIndex: currentIndex ?? this.currentIndex,
    totalLocations: totalLocations,
    sceneProgress: sceneProgress ?? this.sceneProgress,
    args: args,
  );
}

/// App-level tour state that also OWNS the tour's timers, so progress advances
/// even when the user has left the Active Tour screen (the banner keeps moving
/// on Home). A plain top-level [NotifierProvider] is never auto-disposed, so it
/// lives at the ProviderScope root for the session.
///
/// Two timers: a scene-transition timer (advances [currentIndex] once per
/// [sceneDuration]) and a 100ms intra-scene timer (fills [sceneProgress] 0→1
/// across the current scene, for the smooth subtitle bar). The per-scene
/// interval is the FIXED rig-matched dwell (same [KmlGenerator] constants the
/// flight uses), NOT the AI's suggested durations — keeps the companion in sync
/// with Google Earth.
class TourStateNotifier extends Notifier<TourState> {
  Timer? _sceneTimer; // advances currentIndex
  Timer? _progressTimer; // fills sceneProgress 0→1

  static const double _perSceneBufferSeconds = 1.0; // approach + orbit SSH lead
  static const double _startupBufferSeconds = 2.0; // sendKml upload lead

  /// Fixed per-landmark dwell (approach fly + hold + smooth 360° orbit + SSH
  /// buffer) ≈ 29.6s — matches the flytoview approach + one orbitLoopCommand.
  static Duration get sceneDuration => Duration(
    milliseconds:
        ((KmlGenerator.flyDurationSeconds +
                    KmlGenerator.approachHoldSeconds +
                    KmlGenerator.orbitLoopTotalSeconds +
                    _perSceneBufferSeconds) *
                1000)
            .round(),
  );

  /// Lead-in before the first landmark (the rig's opening overview + upload).
  static Duration get overviewDelay => Duration(
    milliseconds:
        ((KmlGenerator.flyDurationSeconds + 3 + _startupBufferSeconds) * 1000)
            .round(),
  );

  @override
  TourState build() {
    ref.onDispose(() {
      _sceneTimer?.cancel();
      _progressTimer?.cancel();
    });
    return const TourState();
  }

  /// A tour has begun — mark running and start the timers: an overview lead-in,
  /// then advance one scene every [sceneDuration] while the intra-scene bar
  /// fills across each scene.
  void start(TourFlowArgs args) {
    _sceneTimer?.cancel();
    _progressTimer?.cancel();
    state = TourState(
      status: TourStatus.running,
      currentIndex: 0,
      totalLocations: args.locations.length,
      sceneProgress: 0.0,
      args: args,
    );
    _sceneTimer = Timer(overviewDelay, () {
      _restartSceneProgress(); // scene 0 bar starts filling once the rig arrives
      _sceneTimer = Timer.periodic(sceneDuration, (_) => _advance());
    });
  }

  void _advance() {
    if (state.status != TourStatus.running) return;
    final next = state.currentIndex + 1;
    if (next >= state.totalLocations) {
      // Reached the end naturally — stop timers and flag `ended` so the Active
      // Tour screen (if still open) can route to the post-tour recap.
      _sceneTimer?.cancel();
      _progressTimer?.cancel();
      state = TourState(
        status: TourStatus.ended,
        currentIndex: state.totalLocations,
        totalLocations: state.totalLocations,
        sceneProgress: 1.0,
        args: state.args,
      );
      return;
    }
    state = state.copyWith(currentIndex: next);
    _restartSceneProgress(); // reset + refill for the new scene
  }

  /// Resets the current scene's fill to 0 and ticks it up to 1 over exactly one
  /// [sceneDuration] (10 ticks/second).
  void _restartSceneProgress() {
    _progressTimer?.cancel();
    state = state.copyWith(sceneProgress: 0.0);
    final stepPerTick = 0.1 / (sceneDuration.inMilliseconds / 1000.0);
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (state.status != TourStatus.running) {
        _progressTimer?.cancel();
        return;
      }
      final next = (state.sceneProgress + stepPerTick).clamp(0.0, 1.0);
      state = state.copyWith(sceneProgress: next);
      if (next >= 1.0) _progressTimer?.cancel();
    });
  }

  /// Tour finished (End Tour button, or after consuming an `ended`) → idle.
  void finish() {
    _sceneTimer?.cancel();
    _progressTimer?.cancel();
    state = const TourState();
  }
}

final tourStateProvider = NotifierProvider<TourStateNotifier, TourState>(
  TourStateNotifier.new,
);
