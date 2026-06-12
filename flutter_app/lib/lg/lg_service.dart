// import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';
import '../models/lg_connection.dart';
import '../models/rig_config.dart';
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
