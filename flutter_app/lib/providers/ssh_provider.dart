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
import '../services/media/unsplash_service.dart';
import '../services/media/wikimedia_service.dart';

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

  Future<void> cleanup() async {
    await LGService.instance.cleanup();
  }

  /// TEMP dev helper : exercises the full image fallback chain across three
  /// cases (Wikipedia hit / Unsplash fallback / text-only), logging each
  /// resolved source, then deploys the historical one to the rig and clears it
  /// after 10s. Remove once verified.
  Future<void> testBalloon() async {
    final cases = <TourLocation>[
      const TourLocation(
        name: 'Shaniwar Wada, Pune', // exact miss → sanitised Wikipedia hit
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
      debugPrint('[Balloon][test] "${loc.name}" → '
          'image: ${media.imageUrl.isEmpty ? '(none)' : media.imageUrl}');
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

  /// Deploys the geocoded [locations] as pin markers, then flies the rig's
  /// Google Earth through them as a cinematic tour.
  ///
  /// The camera is driven via the proven `flytoview=` query.txt hook (the same
  /// one [flyToPune] uses) — one view per stop with a hold between — because
  /// this rig's GE build does NOT honour `playtour=`. The `<gx:Tour>` KML is
  /// still uploaded so the numbered pins are available.
  ///
  /// Returns the number of stops flown. Returns 0 without doing anything if not
  /// connected, no location has coordinates, or a tour is already playing.
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
    try {
      // 1. Upload the pin markers (best-effort; camera move is the main event).
      final kml = KmlAssembler.buildTour(locations: geocoded);
      if (kml != null) {
        await LGService.instance.sendKml(kml, fileName: 'tour.kml');
      }

      // 2. Drive the camera through each view via the proven flytoview= hook.
      //    View 0 is the framing overview; each landmark then occupies a block
      //    of (1 approach + orbitSteps orbit) views, so landmark j starts at
      //    view index 1 + j*(1+orbitSteps). As each landmark's block begins we
      //    fire its info balloon (fetch + deploy) WITHOUT awaiting, so the
      //    camera flight never blocks on the network.
      final views = KmlGenerator.tourCameraViews(geocoded);
      const perLandmark = 1 + KmlGenerator.orbitSteps;
      debugPrint('SSH: flying ${geocoded.length} stop(s) via flytoview');
      for (var i = 0; i < views.length; i++) {
        if (i > 0 && (i - 1) % perLandmark == 0) {
          final j = (i - 1) ~/ perLandmark;
          if (j < geocoded.length) unawaited(_showStopBalloon(geocoded[j]));
        }
        await LGService.instance.runCommand(
          'echo "${KmlGenerator.flyToViewQuery(views[i])}" > /tmp/query.txt',
        );
        await Future<void>.delayed(views[i].settleDuration);
      }

      // 3. Tour finished — clear the info balloon from the right-most screen.
      await LGService.instance.clearBalloon();
      return geocoded.length;
    } finally {
      _isFlying = false;
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

  /// Resolves the best image + description for [location] via the fallback
  /// chain: Wikipedia (with sanitise retry) → Unsplash → the generation-time
  /// image → text-only. Description prefers Wikipedia's extract, else the AI's
  /// significance text. Never throws — returns empty strings on total miss.
  Future<({String imageUrl, String description})> _resolveStopMedia(
    TourLocation location,
  ) async {
    // 1. Wikipedia (exact, then sanitised inside the service).
    final wiki = await WikimediaService.instance.fetchLocationMedia(
      location.name,
    );
    if (wiki != null && wiki.imageUrl.isNotEmpty) {
      debugPrint('[Balloon] source: wikipedia for "${location.name}"');
      return (imageUrl: wiki.imageUrl, description: wiki.description);
    }

    // No Wikipedia image — fall back to the AI significance text for the body.
    final description = location.whySignificant;

    // 2. Unsplash.
    final unsplash = await UnsplashService.instance.fetchPhotoUrl(location.name);
    if (unsplash != null && unsplash.isNotEmpty) {
      debugPrint('[Balloon] source: unsplash for "${location.name}"');
      return (imageUrl: unsplash, description: description);
    }

    // 3. Image fetched at generation time, if any.
    final generated = location.imageUrl ?? '';
    if (generated.isNotEmpty) {
      debugPrint('[Balloon] source: fallback (generation image) '
          'for "${location.name}"');
      return (imageUrl: generated, description: description);
    }

    // 4. Nothing — text-only card.
    debugPrint('[Balloon] source: text-only for "${location.name}"');
    return (imageUrl: '', description: description);
  }
}
