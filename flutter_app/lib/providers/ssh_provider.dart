import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../kml/assembler.dart';
import '../kml/generator.dart';
import '../lg/lg_service.dart';
import '../models/lg_connection.dart';
import '../models/location.dart';
import '../models/rig_config.dart';
import '../services/media/location_media_resolver.dart';
import 'tour_state_provider.dart';

part 'ssh_provider.g.dart';

enum SshStatus { disconnected, connecting, connected, error }

const Object _unchanged = Object();

class SshState {
  const SshState({
    required this.status,
    required this.connection,
    required this.config,
    this.errorMessage,
  });

  final SshStatus status;
  final LGConnection connection;
  final RigConfig config;
  final String? errorMessage;

  bool get isConnected => status == SshStatus.connected;
  bool get isConnecting => status == SshStatus.connecting;

  SshState copyWith({
    SshStatus? status,
    LGConnection? connection,
    RigConfig? config,
    Object? errorMessage = _unchanged,
  }) {
    return SshState(
      status: status ?? this.status,
      connection: connection ?? this.connection,
      config: config ?? this.config,
      errorMessage: identical(errorMessage, _unchanged)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

@Riverpod(keepAlive: true)
class SshConnection extends _$SshConnection {
  static const String _prefsKey = 'lg_connection';

  @override
  SshState build() {
    _loadSaved();
    return SshState(
      status: SshStatus.disconnected,
      connection: LGConnection.empty(),
      config: RigConfig.fromScreenCount(3),
    );
  }

  bool get isConnected => state.isConnected;

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final connection = LGConnection.decode(raw);
      state = state.copyWith(
        connection: connection,
        config: RigConfig.fromScreenCount(connection.screenCount),
      );
    } catch (_) {}
  }

  Future<void> _persist(LGConnection connection) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, connection.encode());
  }

  Future<bool> connect(LGConnection connection) async {
    final rigConfig = RigConfig.fromScreenCount(connection.screenCount);
    debugPrint('RigConfig Check: $rigConfig');

    state = state.copyWith(
      status: SshStatus.connecting,
      connection: connection,
      config: rigConfig,
      errorMessage: null,
    );
    try {
      final ok = await LGService.instance.connect(connection);
      if (ok) {
        await _persist(connection);
        state = state.copyWith(status: SshStatus.connected, errorMessage: null);

        unawaited(_sendLogoOnConnect());
        // One-time, automatic: enable master.kml live-refresh so the landmark
        // ring shows during tours with no manual Set Refresh (relaunches lg1
        // once on the very first connect, then never again).
        unawaited(_ensureRingRefresh());
        return true;
      }
      state = state.copyWith(
        status: SshStatus.error,
        errorMessage:
            'Could not connect to ${connection.host}:${connection.port}',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: SshStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await LGService.instance.clearLogos();
    } catch (e) {
      debugPrint('SSH: clearLogos on disconnect failed: $e');
    }
    await LGService.instance.disconnect();
    state = state.copyWith(status: SshStatus.disconnected, errorMessage: null);
  }

  Future<String?> runCommand(String command) async {
    return await LGService.instance.runCommand(command);
  }

  Future<void> relaunchLg() async {
    await LGService.instance.relaunchLg(state.config);
  }

  Future<void> rebootLg() async {
    await LGService.instance.rebootLg(state.config);
  }

  Future<void> shutdownLg() async {
    await LGService.instance.shutdownLg(state.config);
  }

  Future<void> sendTestKml() async {
    await LGService.instance.sendKml(
      AppConstants.puneKml,
      fileName: 'test.kml',
    );
  }

  Future<void> flyToPune() async {
    // Shaniwar Wada, Pune coordinates
    await LGService.instance.flyTo(18.5195, 73.8553, tilt: 45);
  }

  /// Smooth 360° orbit that keeps the landmark dead-centre. Frames Shaniwar Wada
  /// first (altitude 0, relativeToGround), then runs the WHOLE orbit as a single
  /// server-side loop — one SSH round-trip, evenly-timed frames, no judder.
  Future<void> testOrbit() async {
    const lat = 18.5195, lng = 73.8553; // Shaniwar Wada, Pune
    const range = 800.0;

    // 1. Frame the landmark dead-centre and let the imagery sharpen.
    await LGService.instance.runCommand(
      'echo "${KmlGenerator.orbitFrameQuery(lat, lng, range: range)}" '
      '> /tmp/query.txt',
    );
    debugPrint('[Orbit] framing Shaniwar Wada — smooth server-side orbit next');
    await Future<void>.delayed(const Duration(seconds: 3));

    // 2. ONE command → the master writes every heading itself, GE rotates
    //    smoothly around the fixed centre point.
    await LGService.instance.runCommand(
      KmlGenerator.orbitLoopCommand(lat: lat, lng: lng, range: range),
    );
    debugPrint('[Orbit] orbit complete');
  }

  Future<void> testLandmarkRing() async {
    const lat = 18.5195, lng = 73.8553; // Shaniwar Wada, Pune
    await LGService.instance.runCommand(
      'echo "${KmlGenerator.orbitFrameQuery(lat, lng)}" > /tmp/query.txt',
    );
    await Future<void>.delayed(const Duration(seconds: 3));
    // 0. One-time: make sure master.kml live-refreshes (relaunches lg1 the first
    //    time only). Wait for GE to come back if it relaunched.
    final relaunched = await LGService.instance.ensureMasterLiveRefresh();
    if (relaunched) {
      debugPrint('[LandmarkRing] test — enabled master refresh + relaunched lg1, '
          'waiting ~15s for GE');
      await Future<void>.delayed(const Duration(seconds: 15));
      // Re-frame the landmark after the relaunch.
      await LGService.instance.runCommand(
        'echo "${KmlGenerator.orbitFrameQuery(lat, lng)}" > /tmp/query.txt',
      );
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    // The SAME working ring the tour uses. (The flicker-free <Update> path was
    // dropped — this rig's GE ignores NetworkLinkControl updates.)
    debugPrint('[LandmarkRing] test — showing at Shaniwar Wada');
    await LGService.instance.showLandmarkRing(lat, lng);
    await Future<void>.delayed(const Duration(seconds: 20));
    await LGService.instance.clearLandmarkRing();
    debugPrint('[LandmarkRing] test — cleared');
  }

  Future<void> testGxTourOrbit() async {
    const lat = 18.5195, lng = 73.8553; // Shaniwar Wada, Pune
    const range = 800.0, altitude = 0.0; // relativeToGround → altitude 0

    const approach = CameraView(
      lat: lat,
      lng: lng,
      altitude: altitude,
      tilt: KmlGenerator.orbitTilt,
      heading: 0,
      range: range,
      flySeconds: 0,
      holdSeconds: 0,
    );
    await LGService.instance.runCommand(
      'echo "${KmlGenerator.flyToViewQuery(approach)}" > /tmp/query.txt',
    );
    debugPrint('[Orbit] approach flytoview sent — framing Shaniwar Wada');
    await Future<void>.delayed(const Duration(seconds: 2));

    debugPrint('[Orbit] gx:Tour building orbit.kml for Shaniwar Wada');
    final kml = KmlGenerator.buildOrbitKml(
      lat: lat,
      lng: lng,
      altitude: altitude,
      range: range,
    );

    // 1. Upload the tour KML + point kmls.txt at it (sendKml does both). The
    //    master GE pulls it in via its kmls.txt NetworkLink, so give it time.
    await LGService.instance.sendKml(kml, fileName: 'orbit.kml');
    final host = state.connection.host;
    debugPrint(
      '[Orbit] orbit.kml deployed (http://$host:81/orbit.kml) — '
      'waiting 5s for the master to load the tour',
    );
    await Future<void>.delayed(const Duration(seconds: 5));

    // 2. Play it by name. Must match <name>Orbit</name> in the KML.
    debugPrint('[Orbit] triggering playtour=${KmlGenerator.orbitTourName}');
    await LGService.instance.runCommand(
      'echo "playtour=${KmlGenerator.orbitTourName}" > /tmp/query.txt',
    );
    debugPrint('[Orbit] gx:Tour playback triggered');
  }

  Future<void> cleanup() async {
    await LGService.instance.cleanup();
  }

  Future<void> testBalloon() async {
    final cases = <TourLocation>[
      const TourLocation(
        name: 'Shaniwar Wada, Pune',
        type: 'Fort',
        whySignificant:
            'Built in 1732 as the seat of the Peshwas, Shaniwar Wada once '
            'stood as the political heart of the Maratha Empire.',
        suggestedDurationSeconds: 15,
        address: 'Pune, Maharashtra, India',
      ),
      const TourLocation(
        name: 'Las Vegas Strip', // Wikipedia thin → Unsplash fallback
        type: 'Landmark',
        whySignificant: 'A vibrant stretch of resorts, casinos and neon.',
        suggestedDurationSeconds: 15,
        address: 'Las Vegas, Nevada, USA',
      ),
      const TourLocation(
        name: 'xyznonexistentplace999', // both miss → text-only
        type: 'Unknown',
        whySignificant: 'No data available for this test location.',
        suggestedDurationSeconds: 15,
      ),
    ];

    for (final loc in cases) {
      final media = await _resolveStopMedia(loc);
      debugPrint(
        '[Balloon][test] "${loc.name}" → '
        'image: ${media.imageUrl.isEmpty ? '(none)' : media.imageUrl}',
      );
    }

    // Deploy the historical case to the rig so it can be eyeballed.
    final demo = cases.first;
    final media = await _resolveStopMedia(demo);
    await LGService.instance.deployBalloon(
      location: demo,
      imageUrl: media.imageUrl,
      description: media.description,
    );
    await Future<void>.delayed(const Duration(seconds: 10));
    await LGService.instance.clearBalloon();
  }

  Future<void> _sendLogoOnConnect() async {
    try {
      await setLogos();
    } catch (e) {
      debugPrint('SSH: auto logo on connect failed: $e');
    }
  }

  Future<void> _ensureRingRefresh() async {
    try {
      await LGService.instance.ensureMasterLiveRefresh();
    } catch (e) {
      debugPrint('SSH: ensureMasterLiveRefresh on connect failed: $e');
    }
  }

  Future<void> setLogos() async {
    await LGService.instance.setLogos(
      logoPath: AppConstants.logoAssetPath,
      widthFraction: AppConstants.logoOverlayWidthFraction,
    );
  }

  Future<void> clearLogos() async {
    await LGService.instance.clearLogos();
  }

  Future<void> setRefresh() async {
    await LGService.instance.setRefresh(state.config);
  }

  Future<void> resetRefresh() async {
    await LGService.instance.resetRefresh(state.config);
  }

  bool _isFlying = false;
  bool _stopRequested = false;

  Future<int> flyGeneratedTour(List<TourLocation> locations) async {
    if (!state.isConnected) {
      debugPrint('SSH: flyGeneratedTour skipped — not connected');
      return 0;
    }
    if (_isFlying) {
      debugPrint('SSH: flyGeneratedTour skipped — a tour is already playing');
      return 0;
    }

    final geocoded = locations
        .where((l) => l.latitude != null && l.longitude != null)
        .toList();
    if (geocoded.isEmpty) {
      debugPrint('SSH: flyGeneratedTour skipped — no geocoded locations');
      return 0;
    }

    _isFlying = true;
    _stopRequested = false; // fresh run — clear any stale End-Tour request
    try {
      // 1. Upload the pin markers (best-effort; camera move is the main event).
      final kml = KmlAssembler.buildTour(locations: geocoded);
      if (kml != null) {
        await LGService.instance.sendKml(kml, fileName: 'tour.kml');
      }


      // 2. Drive the camera via the proven flytoview= hook: an opening overview
      //    framing every stop, then per landmark an approach (held so imagery
      //    sharpens + the balloon shows) followed by a smooth, centred 360°
      //    orbit (one server-side loop — see KmlGenerator.orbitLoopCommand).
      debugPrint(
        'SSH: flying ${geocoded.length} stop(s) via flytoview + orbit',
      );

      // The rig is the master clock: it tells the companion (narration + UI)
      // which landmark it has ARRIVED at, so narration never runs ahead of a
      // still-orbiting camera. enterScene() is a no-op if the companion wasn't
      // started (e.g. flight fired before the Active Tour screen) — it re-syncs
      // as soon as that screen calls start(rigDriven: true).
      final tour = ref.read(tourStateProvider.notifier);

      // 2a. Opening overview (fly-to — pausable/skippable like every fly-to).
      final overview = KmlGenerator.overviewView(geocoded);
      final overviewQuery = KmlGenerator.flyToViewQuery(overview);
      await LGService.instance.runCommand(
        'echo "$overviewQuery" > /tmp/query.txt',
      );
      await _pausableHold(overview.settleDuration, overviewQuery);

      // 2b. Per landmark. Play/Pause/Next act throughout the FLY-TO phases
      //     (fly-in + post-orbit settle); the ORBIT is the one uninterruptible
      //     island (server-side loop — always completes, untouched). The ring
      //     stays up through the whole landmark (cleared only as the NEXT one
      //     starts) so it never vanishes while paused. On RESUME the camera is
      //     re-framed to the landmark first, so the orbit never starts from a
      //     spot the user explored to (no janky half-return).
      final approachHold = Duration(
        milliseconds:
            ((KmlGenerator.flyDurationSeconds +
                        KmlGenerator.approachHoldSeconds) *
                    1000)
                .round(),
      );
      for (var j = 0; j < geocoded.length && !_stopRequested; j++) {
        final l = geocoded[j];
        final lat = l.latitude!, lng = l.longitude!;
        final frameQuery = KmlGenerator.orbitFrameQuery(lat, lng);

        // Boundary: hold here if paused, BEFORE flying to this landmark (so a
        // pause keeps you on the previous stop, not mid-transition).
        while (tour.isPaused && !_stopRequested && !tour.skipRequested) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        if (_stopRequested) break;
        tour.clearSkip();
        // Clear the previous landmark's ring now that we're moving on.
        await LGService.instance.clearLandmarkRing();

        // FLY-IN (fly-to) — pausable + skippable. Balloon deploys on the way.
        await LGService.instance.runCommand(
          'echo "$frameQuery" > /tmp/query.txt',
        );
        unawaited(_showStopBalloon(l));
        final flyIn = await _pausableHold(approachHold, frameQuery);
        if (flyIn == 'stop') break;
        if (flyIn == 'skip') continue; // Next during fly-in → skip this landmark

        // Arrived — narration + ring (both persist through the orbit + settle).
        tour.enterScene(j);
        unawaited(LGService.instance.showLandmarkRing(lat, lng));

        // ORBIT — server-side loop, UNINTERRUPTIBLE and DO-NOT-TOUCH. By here the
        // fly-in hold has handled any pause + reframe, so the camera is framed.
        final sw = Stopwatch()..start();
        await LGService.instance.runCommand(
          KmlGenerator.orbitLoopCommand(lat: lat, lng: lng),
        );
        debugPrint('[Orbit] stop $j sweep ran ${sw.elapsedMilliseconds}ms');
        if (_stopRequested) break;

        // SETTLE (fly-to) — pausable + skippable. Ring stays (cleared next loop).
        final settle = await _pausableHold(
          Duration(
            milliseconds: (KmlGenerator.orbitLoopSettleSeconds * 1000).round(),
          ),
          frameQuery,
        );
        if (settle == 'stop') break;
      }

      // 3. Tour finished naturally — clear the ring + balloon and end the
      //    companion (routes to post-tour). If it was stopped, stopTour()
      //    already cleared the rig, so don't double up.
      if (!_stopRequested) {
        await LGService.instance.clearLandmarkRing();
        await LGService.instance.clearBalloon();
        tour.markEnded();
      }
      return geocoded.length;
    } finally {
      _isFlying = false;
    }
  }

  /// A fly-to phase hold of [total] that honours Play/Pause/Next:
  ///  • End Tour     → returns 'stop'  (caller returns).
  ///  • Next Scene   → returns 'skip'  (caller advances).
  ///  • Pause        → holds indefinitely (no countdown). On RESUME it re-frames
  ///    the camera to [reframeQuery] (the user may have explored away) and gives
  ///    GE ~3s to arrive, then returns 'done' — so whatever runs next (an orbit,
  ///    the next fly-in) starts from the correct camera position.
  ///  • Otherwise    → counts down and returns 'done'.
  /// NEVER used around the orbit command itself — only fly-to waits.
  Future<String> _pausableHold(Duration total, String reframeQuery) async {
    const step = Duration(milliseconds: 200);
    var elapsed = Duration.zero;
    final tour = ref.read(tourStateProvider.notifier);
    while (elapsed < total) {
      if (_stopRequested) return 'stop';
      if (tour.skipRequested) return 'skip';
      if (tour.isPaused) {
        while (tour.isPaused && !_stopRequested && !tour.skipRequested) {
          await Future<void>.delayed(step);
        }
        if (_stopRequested) return 'stop';
        if (tour.skipRequested) return 'skip';
        // Resumed after a pause — snap the camera back before continuing.
        await LGService.instance.runCommand(
          'echo "$reframeQuery" > /tmp/query.txt',
        );
        await Future<void>.delayed(const Duration(seconds: 3));
        return 'done';
      }
      final remaining = total - elapsed;
      final chunk = remaining < step ? remaining : step;
      await Future<void>.delayed(chunk);
      elapsed += chunk;
    }
    return 'done';
  }

  Future<void> stopTour() async {
    _stopRequested = true;
    try {
      // End any in-flight server-side orbit loop within one frame (runs on a
      // separate SSH channel, so it lands even while the orbit command blocks).
      await LGService.instance.runCommand(
        'touch ${KmlGenerator.orbitStopSentinel}',
      );
      await LGService.instance.cleanup();
      await LGService.instance.clearBalloon();
      await LGService.instance.clearLandmarkRing();
    } catch (e) {
      debugPrint('SSH: stopTour cleanup failed: $e');
    }
  }

  Future<void> _showStopBalloon(TourLocation location) async {
    try {
      final media = await _resolveStopMedia(location);
      await LGService.instance.deployBalloon(
        location: location,
        imageUrl: media.imageUrl,
        description: media.description,
      );
    } catch (e) {
      debugPrint('SSH: balloon for "${location.name}" failed: $e');
    }
  }

  Future<({String imageUrl, String description})> _resolveStopMedia(
    TourLocation location,
  ) => LocationMediaResolver.instance.resolve(location);
}
