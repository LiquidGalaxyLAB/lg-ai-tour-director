import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SSHConnection {
  /// SSH client for managing the connection.
  SSHClient? client;

  /// Number of screens in the Liquid Galaxy system, default is 3 for this project as per requirements.
  int screenAmount = 3;

  /// Gets the left screen number.
  int get leftScreen {
    return screenAmount ~/ 2 + 2;
  }

  /// Gets the right screen number.
  int get rightScreen {
    return screenAmount ~/ 2 + 1;
  }

  /// Gets the password from the shared preferences. Returns null if not found.
  Future<String?> get password async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('lg_password');
  }

  String get username {
    return client?.username ?? 'lg';
  }

  /// Returns the sftp client
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

  /// Checks if the SSH client is connected.
  ///
  /// Returns `true` if connected, `false` otherwise.
  Future<bool> isConnected() async {
    if (client == null || client!.isClosed) return false;
    try {
      // Attempt to execute a simple command to check the connection status
      final result = await sendCommand('echo "check connection"');
      return result != null;
    } catch (e) {
      // If an exception occurs, the connection is not active
      return false;
    }
  }

  /// Disconnects the SSH client if connected.
  Future<void> disconnect() async {
    if (await isConnected()) {
      client!.close();
    }
  }

  /// Connects to the Liquid Galaxy system
  ///
  /// Returns `true` if the connection is successful, `false` otherwise.
  Future<bool> connect() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (!prefs.containsKey('lg_ip') ||
        !prefs.containsKey('lg_port') ||
        !prefs.containsKey('lg_username') ||
        !prefs.containsKey('lg_password')) {
      return false;
    }
    try {
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

      // In a real LG, screen amount is often 3 or 5.
      final screenAmountString = prefs.getString('lg_screen_amount') ?? "3";
      screenAmount = int.parse(screenAmountString);

      prefs.setString('lg_screen_amount', screenAmountString);
    } catch (e) {
      return false;
    }
    return true;
  }

  /// Sends the [command] to the Liquid Galaxy.
  Future<String?> sendCommand(String command) async {
    try {
      if (client == null) return null;
      final result = await client!.run(command);
      return utf8.decode(result);
    } on SSHChannelOpenError {
      await handleSSHChannelOpenError();
      if (client == null) return null;
      final result = await client!.run(command);
      return utf8.decode(result);
    } catch (e) {
      return null;
    }
  }

  /// Handles an SSH channel open error.
  Future<void> handleSSHChannelOpenError() async {
    await disconnect();
    await connect();
  }

  /// Uploads a file to the Liquid Galaxy.
  ///
  /// requires the [filePath] of the file to upload.
  Future<void> upload(String filePath) async {
    if (!await isConnected()) {
      return;
    }

    try {
      // Load file data from assets
      final ByteData data = await rootBundle.load(filePath);

      // Extract the file name from the provided filePath
      final fileName = filePath.split('/').last;

      final sftp = await getSftp();

      // Upload file directly from byte data
      final remoteFile = await sftp.open(
        '/var/www/html/$fileName',
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
      );

      // Convert ByteData to Uint8List and write it directly
      final uint8ListData = data.buffer.asUint8List();
      await remoteFile.write(Stream.value(uint8ListData).cast<Uint8List>());
      await remoteFile.close();
    } catch (e) {
      debugPrint('Error during file upload: $e');
    }
  }

  /// Sends a KML file to the Liquid Galaxy system.
  ///
  /// [kml] is the KML content to send.
  Future<void> sendKml(String kml, {List<String> images = const []}) async {
    if (!await isConnected()) {
      return;
    }

    try {
      for (String image in images) {
        await upload(image);
      }

      const fileName = 'upload.kml';
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

      // Get the IP of the master to construct the URL for slaves to fetch
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final masterIp = prefs.getString('lg_ip') ?? 'localhost';

      await sendCommand(
        'echo "http://$masterIp:81/$fileName" > /var/www/html/kmls.txt',
      );
    } catch (e) {
      debugPrint('Error during KML file upload: $e');
    }
  }

  /// Sends a KML file to a specific slave screen.
  ///
  /// [screenNumber] is the screen number.
  /// [kml] is the KML content to send.
  Future<void> sendKMLToSlave(int screenNumber, String kml) async {
    if (await isConnected() == false) {
      return;
    }

    await sendCommand(
      "echo '$kml' > /var/www/html/kml/slave_$screenNumber.kml",
    );
  }
}
