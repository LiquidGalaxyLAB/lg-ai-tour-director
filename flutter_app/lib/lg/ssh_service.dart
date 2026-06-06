// import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:dartssh2/dartssh2.dart';
import '../models/lg_connection.dart';
import 'ssh_client.dart';

class SshService {
  SshService._();

  static final SshService instance = SshService._();

  final SSHConnection _ssh = SSHConnection();

  bool get isConnected => _ssh.client != null && !_ssh.client!.isClosed;

  Future<bool> connect(LGConnection connection) async {
    try {
      debugPrint(
        'SshService: Connecting to ${connection.host}. isWeb = $kIsWeb',
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
      debugPrint('SshService: Authenticated successfully');
      _ssh.screenAmount = connection.screenCount;
      return true;
    } catch (e, st) {
      debugPrint('SshService: Connection failed error: $e');
      debugPrint('SshService: Stack trace: $st');
      return false;
    }
  }

  Future<void> disconnect() async {
    await _ssh.disconnect();
  }

  Future<String?> runCommand(String command) async {
    return await _ssh.sendCommand(command);
  }

  Future<void> uploadKml(String kml) async {
    await _ssh.sendKml(kml);
  }

  //   void _log(String message, Object? error, StackTrace? stackTrace) {
  //     developer.log(
  //       message,
  //       name: 'SSHService',
  //       error: error,
  //       stackTrace: stackTrace,
  //     );
  //   }
}
