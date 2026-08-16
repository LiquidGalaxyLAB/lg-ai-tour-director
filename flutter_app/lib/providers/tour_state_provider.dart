import 'dart:async';

import 'package:flutter/foundation.dart';
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
    this.isPaused = false,
    this.args,
  });

  final TourStatus status;
  final int currentIndex; // 0-based scene
  final int totalLocations;
  final double sceneProgress; // 0..1 fill of the current scene
  final bool
  isPaused; // user tapped Pause; the flight holds at the next boundary
  final TourFlowArgs? args; // so the "return to tour" banner can re-open it

  bool get isRunning => status == TourStatus.running;

  /// Fraction 0..1 of the whole tour completed (scene-index based).
  double get progress {
    if (totalLocations <= 0) return 0;
    return (currentIndex / totalLocations).clamp(0.0, 1.0);
  }

  int get percent => (progress * 100).round();

  TourState copyWith({
    int? currentIndex,
    double? sceneProgress,
    bool? isPaused,
  }) => TourState(
    status: status,
    currentIndex: currentIndex ?? this.currentIndex,
    totalLocations: totalLocations,
    sceneProgress: sceneProgress ?? this.sceneProgress,
    isPaused: isPaused ?? this.isPaused,
    args: args,
  );
}

class TourStateNotifier extends Notifier<TourState> {
  Timer? _sceneTimer; // advances currentIndex
  Timer? _progressTimer; // fills sceneProgress 0→1

  // Transient "skip to next landmark" request from the Next Scene button. The
  // rig loop reads it (to cut the post-orbit settle short) and clears it at each
  // new scene. Kept off [TourState] since it's a one-shot signal, not UI state.
  bool _skipRequested = false;
  bool get isPaused => state.isPaused;
  bool get skipRequested => _skipRequested;

  static const double _perSceneBufferSeconds = 1.0; // approach + orbit SSH lead
  static const double _startupBufferSeconds = 2.0; // sendKml upload lead

  static Duration get sceneDuration => Duration(
    milliseconds:
        ((KmlGenerator.flyDurationSeconds +
                    KmlGenerator.approachHoldSeconds +
                    KmlGenerator.orbitLoopTotalSeconds +
                    KmlGenerator.orbitLoopSettleSeconds +
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
  void start(TourFlowArgs args, {bool rigDriven = false}) {
    _sceneTimer?.cancel();
    _progressTimer?.cancel();
    _skipRequested = false;
    state = TourState(
      status: TourStatus.running,
      // rigDriven: start "before" scene 0; the flight calls enterScene(0) when
      // it actually arrives at the first landmark (after the overview).
      currentIndex: rigDriven ? -1 : 0,
      totalLocations: args.locations.length,
      sceneProgress: 0.0,
      args: args,
    );
    if (rigDriven) return; // the rig drives scene changes via enterScene()
    _sceneTimer = Timer(overviewDelay, () {
      _restartSceneProgress(); // scene 0 bar starts filling once the rig arrives
      _sceneTimer = Timer.periodic(sceneDuration, (_) => _advance());
    });
  }

  /// Rig-driven scene change: the LG flight calls this AS IT ARRIVES at each
  /// landmark, so narration + the companion UI advance exactly in step with the
  /// real camera — never ahead of a rig that's still flying or orbiting.
  void enterScene(int index) {
    if (state.status != TourStatus.running) return;
    if (index == state.currentIndex) return;
    state = state.copyWith(currentIndex: index);
    _restartSceneProgress();
  }

  // ── Play / Pause / Next Scene controls ──────────────────────────────────────
  // These only flip flags/state. The rig loop (flyGeneratedTour) reads them at
  // scene boundaries — no SSH, no orbit, no sentinel touched here.

  /// Hold at the next scene boundary. The current fly-in/orbit finish first.
  void pause() {
    if (!state.isRunning || state.isPaused) return;
    state = state.copyWith(isPaused: true);
    debugPrint('[TourControl] paused');
  }

  /// Resume from a hold — the rig loop's boundary poll continues.
  void resume() {
    if (!state.isRunning || !state.isPaused) return;
    state = state.copyWith(isPaused: false);
    debugPrint('[TourControl] resumed');
  }

  /// Request skip to the next landmark: cuts the post-orbit settle short and
  /// (if paused) releases the hold. The orbit/fly-in still complete.
  void requestNext() {
    if (!state.isRunning) return;
    _skipRequested = true;
    if (state.isPaused) state = state.copyWith(isPaused: false);
    debugPrint('[TourControl] next scene requested');
  }

  /// The rig loop clears the skip signal at the start of each new scene.
  void clearSkip() => _skipRequested = false;

  /// Rig-driven natural end: the flight finished the last landmark's orbit.
  void markEnded() {
    if (state.status != TourStatus.running) return;
    _sceneTimer?.cancel();
    _progressTimer?.cancel();
    _skipRequested = false;
    state = TourState(
      status: TourStatus.ended,
      currentIndex: state.totalLocations,
      totalLocations: state.totalLocations,
      sceneProgress: 1.0,
      args: state.args,
    );
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
    _skipRequested = false;
    state = const TourState();
  }
}

final tourStateProvider = NotifierProvider<TourStateNotifier, TourState>(
  TourStateNotifier.new,
);
