import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SSHConnection {
  SSHClient? client;
  int screenAmount = 3;

  int get leftScreen {
    return screenAmount ~/ 2 + 2;
  }

  int get rightScreen {
    return screenAmount ~/ 2 + 1;
  }

  Future<String?> get password async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('lg_password');
  }

  String get username {
    return client?.username ?? 'lg';
  }

  Future<SftpClient> getSftp() async {
    SftpClient sftp;
    try {
      sftp = await client!.sftp();
    } on SSHChannelOpenError {
      await handleSSHChannelOpenError();
      sftp = await client!.sftp();
    }
    return sftp;
  }

  Future<bool> isConnected() async {
    if (client == null || client!.isClosed) return false;
    try {
      final result = await sendCommand('echo "check connection"');
      return result != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnect() async {
    if (await isConnected()) {
      client!.close();
    }
  }

  Future<bool> connect() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey('lg_ip') ||
        !prefs.containsKey('lg_port') ||
        !prefs.containsKey('lg_username') ||
        !prefs.containsKey('lg_password')) {
      return false;
    }
    try {
      debugPrint('SSH: Attempting connection. isWeb = $kIsWeb');
      final socket = await SSHSocket.connect(
        prefs.getString('lg_ip')!,
        int.parse(prefs.getString('lg_port')!),
      ).timeout(const Duration(seconds: 8));

      client = SSHClient(
        socket,
        username: prefs.getString('lg_username')!,
        onPasswordRequest: () => prefs.getString('lg_password')!,
      );

      await client!.authenticated;
      debugPrint('SSH: Authenticated successfully');

      final screenAmountString = prefs.getString('lg_screen_amount') ?? "3";
      screenAmount = int.parse(screenAmountString);

      prefs.setString('lg_screen_amount', screenAmountString);
    } catch (e, st) {
      debugPrint('SSH: Connection failed error: $e');
      debugPrint('SSH: Stack trace: $st');
      return false;
    }
    return true;
  }

  Future<String?> sendCommand(String command) async {
    try {
      if (client == null) {
        debugPrint('SSH: Attempted sendCommand "$command" but client is null.');
        return null;
      }
      debugPrint('SSH: Executing command >>> $command');
      final result = await client!.run(command);
      final decoded = utf8.decode(result);
      debugPrint('SSH: Command Result <<< ${decoded.trim()}');
      return decoded;
    } on SSHChannelOpenError {
      debugPrint('SSH: Channel open error. Attempting to reconnect...');
      await handleSSHChannelOpenError();
      if (client == null) return null;
      final result = await client!.run(command);
      return utf8.decode(result);
    } catch (e) {
      debugPrint('SSH: Command execution failed: $e');
      return null;
    }
  }

  Future<void> handleSSHChannelOpenError() async {
    await disconnect();
    await connect();
  }

  Future<void> flyTo(
    double lat,
    double lng,
    double altitude,
    double tilt,
    double bearing,
  ) async {
    if (!await isConnected()) return;

    // Liquid Galaxy standard flyto command
    final command =
        'echo "flytoview=<LookAt><longitude>$lng</longitude><latitude>$lat</latitude><altitude>$altitude</altitude><range>0</range><tilt>$tilt</tilt><heading>$bearing</heading><gx:altitudeMode>relativeToSeaFloor</gx:altitudeMode></LookAt>" > /tmp/query.txt';

    debugPrint('SSH: Sending flyTo command for ($lat, $lng)');
    await sendCommand(command);
  }

  Future<void> upload(String filePath) async {
    if (!await isConnected()) {
      return;
    }

    try {
      final ByteData data = await rootBundle.load(filePath);

      final fileName = filePath.split('/').last;

      final sftp = await getSftp();

      final remoteFile = await sftp.open(
        '/var/www/html/$fileName',
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
      );

      final uint8ListData = data.buffer.asUint8List();
      await remoteFile.write(Stream.value(uint8ListData).cast<Uint8List>());
      await remoteFile.close();
    } catch (e) {
      debugPrint('Error during file upload: $e');
    }
  }

  Future<void> sendKml(
    String kml, {
    List<String> images = const [],
    String fileName = 'upload.kml',
  }) async {
    if (!await isConnected()) {
      return;
    }

    try {
      for (String image in images) {
        await upload(image);
      }

      final sftpClient = await getSftp();

      final remoteFile = await sftpClient.open(
        '/var/www/html/$fileName',
        mode:
            SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );

      final kmlBytes = Uint8List.fromList(kml.codeUnits);
      await remoteFile.write(Stream.value(kmlBytes).cast<Uint8List>());
      await remoteFile.close();

      SharedPreferences prefs = await SharedPreferences.getInstance();
      final masterIp = prefs.getString('lg_ip') ?? 'lg1';

      // Use localhost or the actual IP for the KML URL to ensure resolvability
      // On most LG rigs, slaves resolve 'lg1' to the master, but for local tests,
      // the master's own Apache might be accessed via its IP or localhost.
      await sendCommand(
        'echo "http://$masterIp/$fileName" > /var/www/html/kmls.txt',
      );
    } catch (e) {
      debugPrint('Error during KML file upload: $e');
    }
  }

  Future<void> cleanup() async {
    if (!await isConnected()) return;

    try {
      // Clear kmls.txt on master
      await sendCommand('> /var/www/html/kmls.txt');

      // Remove generated KMLs on master
      await sendCommand('rm -f /var/www/html/*.kml');

      // Clear slave screens if applicable
      for (var i = 1; i <= screenAmount; i++) {
        await sendCommand("echo '' > /var/www/html/kml/slave_$i.kml");
      }
    } catch (e) {
      debugPrint('Error during LG cleanup: $e');
    }
  }

  Future<void> sendKMLToSlave(int screenNumber, String kml) async {
    if (await isConnected() == false) {
      return;
    }

    await sendCommand(
      "echo '$kml' > /var/www/html/kml/slave_$screenNumber.kml",
    );
  }
}
