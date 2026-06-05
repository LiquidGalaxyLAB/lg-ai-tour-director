import 'dart:convert';

import '../core/constants/app_constants.dart';

class LGConnection {
  const LGConnection({
    required this.host,
    this.port = AppConstants.defaultSshPort,
    this.username = AppConstants.defaultLgUsername,
    required this.password,
    this.screenCount = AppConstants.defaultLgScreens,
  });

  final String host;
  final int port;
  final String username;
  final String password;
  final int screenCount;

  factory LGConnection.empty() => const LGConnection(host: '', password: '');

  LGConnection copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    int? screenCount,
  }) {
    return LGConnection(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      screenCount: screenCount ?? this.screenCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'username': username,
    'password': password,
    'screenCount': screenCount,
  };

  factory LGConnection.fromJson(Map<String, dynamic> json) {
    return LGConnection(
      host: (json['host'] as String?) ?? '',
      port: (json['port'] as num?)?.toInt() ?? AppConstants.defaultSshPort,
      username: (json['username'] as String?) ?? AppConstants.defaultLgUsername,
      password: (json['password'] as String?) ?? '',
      screenCount:
          (json['screenCount'] as num?)?.toInt() ??
          AppConstants.defaultLgScreens,
    );
  }

  String encode() => jsonEncode(toJson());

  factory LGConnection.decode(String source) =>
      LGConnection.fromJson(jsonDecode(source) as Map<String, dynamic>);

  bool get isValid => host.trim().isNotEmpty && username.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is LGConnection &&
      other.host == host &&
      other.port == port &&
      other.username == username &&
      other.password == password &&
      other.screenCount == screenCount;

  @override
  int get hashCode => Object.hash(host, port, username, password, screenCount);

  @override
  String toString() =>
      'LGConnection(host: $host, port: $port, username: $username, '
      'screenCount: $screenCount)';
}
