import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../lg/lg_service.dart';
import '../models/lg_connection.dart';

part 'ssh_provider.g.dart';

enum SshStatus { disconnected, connecting, connected, error }

const Object _unchanged = Object();

class SshState {
  const SshState({
    required this.status,
    required this.connection,
    this.errorMessage,
  });

  final SshStatus status;
  final LGConnection connection;
  final String? errorMessage;

  bool get isConnected => status == SshStatus.connected;
  bool get isConnecting => status == SshStatus.connecting;

  SshState copyWith({
    SshStatus? status,
    LGConnection? connection,
    Object? errorMessage = _unchanged,
  }) {
    return SshState(
      status: status ?? this.status,
      connection: connection ?? this.connection,
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
    );
  }

  bool get isConnected => state.isConnected;

  Future<void> _loadSaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      state = state.copyWith(connection: LGConnection.decode(raw));
    } catch (_) {}
  }

  Future<void> _persist(LGConnection connection) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, connection.encode());
  }

  Future<bool> connect(LGConnection connection) async {
    state = state.copyWith(
      status: SshStatus.connecting,
      connection: connection,
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
}
