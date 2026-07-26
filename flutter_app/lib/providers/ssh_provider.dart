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
      debugPrint('SSH: flying ${geocoded.length} stop(s) via flytoview + orbit');

      // The rig is the master clock: it tells the companion (narration + UI)
      // which landmark it has ARRIVED at, so narration never runs ahead of a
      // still-orbiting camera. enterScene() is a no-op if the companion wasn't
      // started (e.g. flight fired before the Active Tour screen) — it re-syncs
      // as soon as that screen calls start(rigDriven: true).
      final tour = ref.read(tourStateProvider.notifier);

      // 2a. Opening overview.
      final overview = KmlGenerator.overviewView(geocoded);
      await LGService.instance.runCommand(
        'echo "${KmlGenerator.flyToViewQuery(overview)}" > /tmp/query.txt',
      );
      await _interruptibleDelay(overview.settleDuration);

      // 2b. Per landmark: advance narration to this stop AS WE ARRIVE, approach
      //     (same relativeToGround geometry as the orbit start → no vertical
      //     jump), fire the balloon, hold for imagery, then a full 360° orbit.
      //     Each landmark only ends when its orbit truly completes, so the next
      //     fly-to + narration fire together — the camera is given its "justice".
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

        tour.enterScene(j); // narration for THIS stop starts now

        await LGService.instance.runCommand(
          'echo "${KmlGenerator.orbitFrameQuery(lat, lng)}" > /tmp/query.txt',
        );
        unawaited(_showStopBalloon(l)); // fire on arrival; shows through orbit
        await _interruptibleDelay(approachHold);
        if (_stopRequested) break;

        // Blocks ~29s while the master sweeps the heading; End Tour ends it
        // early by touching the stop-sentinel (see stopTour) on another channel.
        final sw = Stopwatch()..start();
        await LGService.instance.runCommand(
          KmlGenerator.orbitLoopCommand(lat: lat, lng: lng),
        );
        debugPrint('[Orbit] stop $j orbit ran ${sw.elapsedMilliseconds}ms');
      }

      // 3. Tour finished naturally — clear the info balloon and end the
      //    companion (routes to post-tour). If it was stopped, stopTour()
      //    already cleared the rig, so don't double up.
      if (!_stopRequested) {
        await LGService.instance.clearBalloon();
        tour.markEnded();
      }
      return geocoded.length;
    } finally {
      _isFlying = false;
    }
  }

  Future<void> _interruptibleDelay(Duration total) async {
    const step = Duration(milliseconds: 200);
    var elapsed = Duration.zero;
    while (elapsed < total) {
      if (_stopRequested) return;
      final remaining = total - elapsed;
      final chunk = remaining < step ? remaining : step;
      await Future<void>.delayed(chunk);
      elapsed += chunk;
    }
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
