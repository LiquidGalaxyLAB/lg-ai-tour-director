import 'dart:developer' as developer;
import 'package:dartssh2/dartssh2.dart';
import '../models/lg_connection.dart';
import 'ssh_client.dart';

class SshService {
  SshService._();

  static final SshService instance = SshService._();

  final SSHConnection _ssh = SSHConnection();

  bool get isConnected => _ssh.client != null && !_ssh.client!.isClosed;

  Future<bool> connect(LGConnection connection) async {
    // We need to sync the settings since SSHConnection uses SharedPreferences
    // while LGConnection is passed from the UI.
    // For this implementation, we'll use the logic inside SSHConnection but
    // ensure it's configured with the provided connection details.

    // Note: SSHConnection.connect() reads from SharedPreferences.
    // We'll manually set the values to ensure it connects with what the user just typed.
    try {
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
      _ssh.screenAmount = connection.screenCount;
      return true;
    } catch (e, st) {
      _log('connect failed', e, st);
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

  void _log(String message, Object? error, StackTrace? stackTrace) {
    developer.log(
      message,
      name: 'SSHService',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
