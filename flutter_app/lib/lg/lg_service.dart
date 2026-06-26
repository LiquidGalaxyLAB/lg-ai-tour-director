// import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';
import '../kml/balloon_maker.dart';
import '../models/lg_connection.dart';
import '../models/location.dart';
import '../models/rig_config.dart';
import '../models/wikimedia_result.dart';
import 'ssh_client.dart';

class LGService {
  LGService._();

  static final LGService instance = LGService._();

  final SSHConnection _ssh = SSHConnection();

  bool get isConnected => _ssh.client != null && !_ssh.client!.isClosed;

  Future<bool> connect(LGConnection connection) async {
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

  /// Writes [kml] to a slave screen's overlay file (slave_N.kml)
  Future<void> sendKmlToSlave(int screenNumber, String kml) async {
    debugPrint('LGService: Sending KML to slave screen $screenNumber');
    await _ssh.sendKMLToSlave(screenNumber, kml);
  }

  Future<void> showLocationBalloon({
    required TourLocation location,
    required WikimediaResult? media,
    required RigConfig rigConfig,
  }) async {
    final kml = BalloonMaker.infoBalloon(
      locationName: location.name,
      locationSubtitle: location.address ?? '',
      description: media?.description ?? location.whySignificant,
      imageUrl: media?.imageUrl ?? location.imageUrl ?? '',
    );
    await sendKmlToSlave(rigConfig.infoScreen, kml);
  }

  // clears the info balloon from the right most screen
  Future<void> clearBalloon(RigConfig rigConfig) async {
    await sendKmlToSlave(rigConfig.infoScreen, BalloonMaker.emptyBalloon());
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
