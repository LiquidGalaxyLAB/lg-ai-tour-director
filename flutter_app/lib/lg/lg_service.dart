// import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import '../kml/balloon_image_maker.dart';
import '../kml/balloon_maker.dart';
import '../kml/generator.dart';
import '../models/lg_connection.dart';
import '../models/location.dart';
import '../models/rig_config.dart';
import 'ssh_client.dart';

class LGService {
  LGService._();

  static final LGService instance = LGService._();

  final SSHConnection _ssh = SSHConnection();

  bool get isConnected => _ssh.client != null && !_ssh.client!.isClosed;

  Future<bool> connect(LGConnection connection) async {
    try {
      _ssh.client?.close();
    } catch (_) {}
    _ssh.client = null;

    try {
      debugPrint(
        'LGService: Connecting to ${connection.host}. isWeb = $kIsWeb',
      );
      final socket = await SSHSocket.connect(
        connection.host,
        connection.port,
      ).timeout(const Duration(seconds: 8));

      _ssh.client = SSHClient(
        socket,
        username: connection.username,
        onPasswordRequest: () => connection.password,
      );

      await _ssh.client!.authenticated;
      debugPrint('LGService: Authenticated successfully');
      _ssh.screenAmount = connection.screenCount;
      _ssh.host = connection.host;

      _ssh.rememberCredentials(
        host: connection.host,
        port: connection.port,
        username: connection.username,
        password: connection.password,
      );
      return true;
    } catch (e, st) {
      try {
        _ssh.client?.close();
      } catch (_) {}
      _ssh.client = null;
      debugPrint('LGService: Connection failed error: $e');
      debugPrint('LGService: Stack trace: $st');
      return false;
    }
  }

  Future<void> disconnect() async {
    await _ssh.disconnect();
  }

  Future<String?> runCommand(String command) async {
    return await _ssh.sendCommand(command);
  }

  Future<void> sendKml(String kml, {String fileName = 'upload.kml'}) async {
    debugPrint('LGService: Sending KML file "$fileName"');
    await _ssh.sendKml(kml, fileName: fileName);
  }

  Future<void> sendKmlToSlave(int screenNumber, String kml) async {
    debugPrint('LGService: Sending KML to slave screen $screenNumber');
    await _ssh.sendKMLToSlave(screenNumber, kml);
  }

  int get infoScreen => _ssh.rightScreen;

  int _balloonSeq = 0;
  final Dio _balloonDio = Dio();

  /// Renders the info card to a PNG and deploys it as a ScreenOverlay on the
  /// right-most screen. [imageUrl] / [description] are already resolved by the
  /// caller's fallback chain (Wikipedia → Unsplash → generation image →
  /// text-only); an empty [imageUrl] renders a clean text-only card.
  Future<void> deployBalloon({
    required TourLocation location,
    required String imageUrl,
    required String description,
  }) async {
    final imageBytes = imageUrl.isEmpty ? null : await _downloadImage(imageUrl);

    final png = await BalloonImageMaker.render(
      locationName: location.name,
      locationSubtitle: location.address ?? '',
      description: description,
      imageBytes: imageBytes,
    );

    // Unique filename per update so Google Earth can't serve a cached image.
    final fileName = 'infoballoon_${_balloonSeq++}.png';
    await _ssh.uploadBytes(png, fileName);

    final host = _ssh.host ?? 'lg1';
    final kml = BalloonMaker.imageOverlay(host: host, fileName: fileName);
    debugPrint(
      'LGService: Showing info balloon "${location.name}" on screen '
      '$infoScreen ($fileName, ${png.length} bytes)',
    );
    await sendKmlToSlave(infoScreen, kml);
  }

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final res = await _balloonDio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          headers: const {
            'User-Agent':
                'LGAITourDirector/1.0 (GSoC 2026; kabirkhanuja@gmail.com)',
          },
        ),
      );
      final data = res.data;
      return data == null ? null : Uint8List.fromList(data);
    } catch (e) {
      debugPrint('LGService: balloon image download failed: $e');
      return null;
    }
  }

  // clears the info balloon from the right most screen and sweeps the rendered
  // PNGs that accumulated in the web root over the session
  Future<void> clearBalloon() async {
    await sendKmlToSlave(infoScreen, BalloonMaker.emptyBalloon());
    await _ssh.sendCommand('rm -f /var/www/html/infoballoon_*.png');
  }

  static const String _masterKmlPath = '/var/www/html/kml/master.kml';

  Future<bool> ensureMasterLiveRefresh() async {
    try {
      return await _ssh.ensureMasterLiveRefresh();
    } catch (e) {
      debugPrint('[LandmarkRing] ensureMasterLiveRefresh failed: $e');
      return false;
    }
  }

  /// Strip the auto live-refresh + relaunch lg1 (inverse of the above), so the
  /// rig stops reloading master.kml when the app disconnects.
  Future<void> disableMasterLiveRefresh({bool relaunch = true}) async {
    try {
      await _ssh.disableMasterLiveRefresh(relaunch: relaunch);
    } catch (e) {
      debugPrint('[LandmarkRing] disableMasterLiveRefresh failed: $e');
    }
  }

  Future<void> showLandmarkRing(
    double lat,
    double lng, {
    double innerRadius = 150,
    double outerRadius = 200,
    int colorIndex = 0,
  }) async {
    try {
      final kml = KmlGenerator.buildLandmarkRingKml(
        lat,
        lng,
        innerRadius: innerRadius,
        outerRadius: outerRadius,
        colorIndex: colorIndex,
      );
      await _ssh.sendCommand("echo '$kml' > $_masterKmlPath");
      debugPrint(
        '[LandmarkRing] location $colorIndex color: '
        '${KmlGenerator.ringColorName(colorIndex)}',
      );
      debugPrint('[LandmarkRing] show ($lat, $lng) → master.kml');
    } catch (e) {
      debugPrint('[LandmarkRing] error (show): $e');
    }
  }

  Future<void> clearLandmarkRing() async {
    try {
      await _ssh.sendCommand(
        "echo '${BalloonMaker.emptyBalloon()}' > $_masterKmlPath",
      );
      debugPrint('[LandmarkRing] clear');
    } catch (e) {
      debugPrint('[LandmarkRing] error (clear): $e');
    }
  }

  // ── Flicker-free ring (NetworkLinkControl <Update>) — UNDER TEST ────────────
  // Kept SEPARATE from the working show/clear above so the live tour is
  // untouched. Once the test button confirms these are rock-steady, the tour
  // switches to them. See generator.landmarkRingBaseKml / landmarkRingUpdateKml.

  /// Write the persistent (hidden) ring strokes once. Allow a master-refresh
  /// cycle for GE to load them before the first update.
  Future<void> primeLandmarkRing() async {
    try {
      await _ssh.sendCommand(
        "echo '${KmlGenerator.landmarkRingBaseKml()}' > $_masterKmlPath",
      );
      debugPrint('[LandmarkRing] base primed → master.kml');
    } catch (e) {
      debugPrint('[LandmarkRing] error (prime): $e');
    }
  }

  Future<void> showLandmarkRingUpdate(
    double lat,
    double lng, {
    double innerRadius = 150,
    double outerRadius = 200,
  }) async {
    try {
      final kml = KmlGenerator.landmarkRingUpdateKml(
        lat,
        lng,
        visible: true,
        innerRadius: innerRadius,
        outerRadius: outerRadius,
      );
      await _ssh.sendCommand("echo '$kml' > $_masterKmlPath");
      debugPrint('[LandmarkRing] show UPDATE ($lat, $lng) → master.kml');
    } catch (e) {
      debugPrint('[LandmarkRing] error (show update): $e');
    }
  }

  Future<void> clearLandmarkRingUpdate() async {
    try {
      await _ssh.sendCommand(
        "echo '${KmlGenerator.landmarkRingUpdateKml(0, 0, visible: false)}' "
        '> $_masterKmlPath',
      );
      debugPrint('[LandmarkRing] clear UPDATE (hide)');
    } catch (e) {
      debugPrint('[LandmarkRing] error (clear update): $e');
    }
  }

  Future<void> flyTo(
    double lat,
    double lng, {
    double altitude = 0,
    double tilt = 0,
    double bearing = 0,
  }) async {
    debugPrint('LGService: Navigating to ($lat, $lng)');
    await _ssh.flyTo(lat, lng, altitude, tilt, bearing);
  }

  Future<void> cleanup() async {
    debugPrint('LGService: Performing rig cleanup');
    await _ssh.cleanup();
  }

  Future<void> setLogos({
    String logoPath = 'assets/logos/logo.png',
    double widthFraction = 0.3,
  }) async {
    debugPrint('LGService: Showing logo overlay on the left-most screen');
    await _ssh.setLogos(logoPath: logoPath, widthFraction: widthFraction);
  }

  Future<void> clearLogos() async {
    debugPrint('LGService: Clearing logo overlay');
    await _ssh.clearLogos();
  }

  // One-time rig setup: makes the slave screens auto-reload their KML so logo
  // overlay changes appear live. Relaunches afterwards to apply the edit
  Future<void> setRefresh(RigConfig config) async {
    debugPrint('LGService: Setting slave auto-refresh interval');
    await _ssh.setRefresh();
    await relaunchLg(config);
  }

  Future<void> resetRefresh(RigConfig config) async {
    debugPrint('LGService: Removing slave auto-refresh interval');
    await _ssh.resetRefresh();
    await relaunchLg(config);
  }

  Future<void> relaunchLg(RigConfig config) async {
    debugPrint('LGService: Relaunching Google Earth on all screens');
    for (var i = 1; i <= config.totalScreens; i++) {
      if (i == 1) {
        await runCommand('killall -9 googleearth-bin; google-earth-pro &');
      } else {
        final pass = _ssh.client?.onPasswordRequest?.call();
        await runCommand(
          'sshpass -p $pass ssh -t lg$i "killall -9 googleearth-bin; google-earth-pro &"',
        );
      }
    }
  }

  Future<void> rebootLg(RigConfig config) async {
    debugPrint('LGService: Rebooting all LG nodes');
    final password = _ssh.client?.onPasswordRequest?.call() ?? '';

    // Trigger slaves first (lg2, lg3...)
    for (var i = config.totalScreens; i >= 2; i--) {
      await runCommand(
        'sshpass -p $password ssh -t lg$i "echo \'$password\' | sudo -S reboot"',
      );
    }

    // Trigger master last
    await runCommand('echo "$password" | sudo -S reboot');
  }

  Future<void> shutdownLg(RigConfig config) async {
    debugPrint('LGService: Shutting down all LG nodes');
    final password = _ssh.client?.onPasswordRequest?.call() ?? '';

    // Trigger slaves first (lg2, lg3...)
    for (var i = config.totalScreens; i >= 2; i--) {
      await runCommand(
        'sshpass -p $password ssh -t lg$i "echo \'$password\' | sudo -S poweroff"',
      );
    }

    // Trigger master last
    await runCommand('echo "$password" | sudo -S poweroff');
  }
}
