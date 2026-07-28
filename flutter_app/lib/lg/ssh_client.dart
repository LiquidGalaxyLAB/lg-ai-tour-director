import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SSHConnection {
  SSHClient? client;
  int screenAmount = 3;
  String? host;
  int port = 22;
  String? _user;
  String? _pass;

  // Remembers the live credentials so [_reconnect] can rebuild the client.
  void rememberCredentials({
    required String host,
    required int port,
    required String username,
    required String password,
  }) {
    this.host = host;
    this.port = port;
    _user = username;
    _pass = password;
  }

  Future<bool> _reconnect() async {
    if (host == null || _user == null) return false;
    try {
      client?.close();
    } catch (_) {}
    try {
      debugPrint('SSH: Reconnecting to $host:$port ...');
      final socket = await SSHSocket.connect(
        host!,
        port,
      ).timeout(const Duration(seconds: 8));
      final fresh = SSHClient(
        socket,
        username: _user!,
        onPasswordRequest: () => _pass ?? '',
      );
      await fresh.authenticated;
      client = fresh;
      debugPrint('SSH: Reconnected successfully');
      return true;
    } catch (e) {
      debugPrint('SSH: Reconnect failed: $e');
      return false;
    }
  }

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
    if (client == null) return false;
    // A closed transport is recoverable — try to silently reconnect so callers
    // that guard on isConnected() (setLogos, cleanup, flyTo...) self-heal.
    if (client!.isClosed) return await _reconnect();
    return true;
  }

  Future<void> disconnect() async {
    try {
      client?.close();
    } catch (_) {}
    // Null the client so we don't auto-reconnect after an explicit disconnect
    client = null;
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
    if (client == null) {
      debugPrint('SSH: Attempted sendCommand "$command" but client is null.');
      return null;
    }
    // Proactively heal a transport that died between commands
    if (client!.isClosed && !await _reconnect()) {
      debugPrint('SSH: client closed and reconnect failed for "$command"');
      return null;
    }
    try {
      debugPrint('SSH: Executing command >>> $command');
      final result = await client!.run(command);
      final decoded = utf8.decode(result);
      debugPrint('SSH: Command Result <<< ${decoded.trim()}');
      return decoded;
    } on SSHChannelOpenError {
      debugPrint('SSH: Channel open error. Attempting to reconnect...');
      if (!await _reconnect()) return null;
      return _runOnce(command);
    } on SSHStateError catch (e) {
      // "Transport is closed" mid-flight : reconnect once and retry
      debugPrint('SSH: $e. Attempting to reconnect...');
      if (!await _reconnect()) return null;
      return _runOnce(command);
    } catch (e) {
      debugPrint('SSH: Command execution failed: $e');
      return null;
    }
  }

  // Single best-effort run used after a reconnect: never throws
  Future<String?> _runOnce(String command) async {
    try {
      final result = await client!.run(command);
      return utf8.decode(result);
    } catch (e) {
      debugPrint('SSH: Retry after reconnect failed: $e');
      return null;
    }
  }

  Future<void> handleSSHChannelOpenError() async {
    await _reconnect();
  }

  Future<void> flyTo(
    double lat,
    double lng,
    double altitude,
    double tilt,
    double bearing,
  ) async {
    if (!await isConnected()) return;

    // lg standard flyto command
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

  /// Writes raw [bytes] to `/var/www/html/<remoteFileName>` on the master.
  /// Used for dynamically generated assets (e.g. the rendered info balloon PNG)
  /// that don't exist as a bundled asset for [upload].
  Future<void> uploadBytes(Uint8List bytes, String remoteFileName) async {
    if (!await isConnected()) return;
    try {
      final sftp = await getSftp();
      final remoteFile = await sftp.open(
        '/var/www/html/$remoteFileName',
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );
      await remoteFile.write(Stream.value(bytes).cast<Uint8List>());
      await remoteFile.close();
    } catch (e) {
      debugPrint('Error during bytes upload ($remoteFileName): $e');
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
      final masterIp = host ?? 'lg1';

      // 1. Update kmls.txt (for the NetworkLink)
      await sendCommand(
        'echo "http://$masterIp:81/$fileName" > /var/www/html/kmls.txt',
      );

      // 2. Trigger immediate load via query.txt
      await sendCommand(
        'echo "http://$masterIp:81/$fileName" > /tmp/query.txt',
      );
    } catch (e) {
      debugPrint('Error during KML file upload: $e');
    }
  }

  Future<void> cleanup() async {
    if (!await isConnected()) return;

    try {
      // ensuring that the directories exist with correct permissions
      await sendCommand('mkdir -p /var/www/html/kml');

      // clearing kmls.txt on master
      await sendCommand('> /var/www/html/kmls.txt');

      // removing generated kmls on master
      await sendCommand('rm -f /var/www/html/*.kml');

      // clearing slave screens if applicable
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

  /// Uploads [logoPath] to the master web server and shows it as a
  /// ScreenOverlay on the left-most screen, anchored to the top-left corner.
  ///
  /// The overlay width is [widthFraction] of the screen; the height is left to
  /// auto-scale (`<size y="0">`) so the image keeps its native aspect ratio —
  /// the picture is never stretched/squished, only uniformly resized.
  Future<void> setLogos({
    String logoPath = 'assets/logos/logo.png',
    double widthFraction = 0.3,
  }) async {
    if (!await isConnected()) return;

    try {
      // 1. Push the image onto the master's web root (/var/www/html/<file>).
      await upload(logoPath);

      final fileName = logoPath.split('/').last;
      final masterIp = host ?? 'lg1';

      // 2. ScreenOverlay: image top-left corner pinned near the screen's
      //    top-left; sized by width only so the aspect ratio is preserved.
      final kml =
          '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Tour Director Logo</name>
    <ScreenOverlay>
      <name>LogoOverlay</name>
      <Icon><href>http://$masterIp:81/$fileName</href></Icon>
      <overlayXY x="0" y="1" xunits="fraction" yunits="fraction"/>
      <screenXY x="0.04" y="0.98" xunits="fraction" yunits="fraction"/>
      <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
      <size x="$widthFraction" y="0" xunits="fraction" yunits="fraction"/>
    </ScreenOverlay>
  </Document>
</kml>''';

      // 3. Render it on the left-most screen.
      await sendKMLToSlave(leftScreen, kml);
    } catch (e) {
      debugPrint('Error during setLogos: $e');
    }
  }

  // Removes the logo overlay by blanking the left-most screen's slave file
  Future<void> clearLogos() async {
    if (!await isConnected()) return;

    try {
      await sendKMLToSlave(
        leftScreen,
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<kml xmlns="http://www.opengis.net/kml/2.2"><Document></Document></kml>',
      );
    } catch (e) {
      debugPrint('Error during clearLogos: $e');
    }
  }

  static const List<String> _slaveLoaderFiles = [
    '~/earth/kml/slave/myplaces.kml',
    '~/.googleearth/myplaces.kml',
  ];

  Future<void> setRefresh({int seconds = 2}) async {
    if (!await isConnected()) return;
    final pass = _pass ?? '';
    final files = _slaveLoaderFiles.join(' ');

    // Master (lg1, THIS host): make its own master.kml NetworkLink refresh live
    // too, so geometry written to /var/www/html/kml/master.kml (the landmark
    // ring) appears without a GE relaunch. Local home file → no sshpass/sudo.
    await sendCommand(
      "sed -i -e '${_masterStripExpr()}' -e '${_masterInjectExpr(seconds)}' "
      '~/.googleearth/myplaces.kml',
    );

    for (var i = 2; i <= screenAmount; i++) {
      final strip = _stripExpr(i);
      final inject =
          "/slave_$i.kml/ s#</href>#</href>"
          "<refreshMode>onInterval</refreshMode>"
          "<refreshInterval>$seconds</refreshInterval>#";
      final remote =
          "echo $pass | sudo -S sed -i -e '$strip' -e '$inject' $files";
      await sendCommand('sshpass -p $pass ssh -t lg$i "$remote"');
    }
  }

  Future<void> resetRefresh() async {
    if (!await isConnected()) return;
    final pass = _pass ?? '';
    final files = _slaveLoaderFiles.join(' ');

    await sendCommand(
      "sed -i -e '${_masterStripExpr()}' ~/.googleearth/myplaces.kml",
    );

    for (var i = 2; i <= screenAmount; i++) {
      final remote = "echo $pass | sudo -S sed -i -e '${_stripExpr(i)}' $files";
      await sendCommand('sshpass -p $pass ssh -t lg$i "$remote"');
    }
  }

  /// One-time, automatic: make the master's own master.kml NetworkLink refresh
  /// live so content written to /var/www/html/kml/master.kml (the landmark ring)
  /// appears WITHOUT a manual Set Refresh or relaunch. Idempotent — checks the
  /// master's myplaces first and only edits + relaunches lg1's GE if it isn't
  /// already enabled. Returns true iff it relaunched (caller should then wait
  /// for GE to come back before writing content).
  Future<bool> ensureMasterLiveRefresh({int seconds = 2}) async {
    if (!await isConnected()) return false;
    final probe = await sendCommand(
      "grep -c 'master\\.kml</href><refreshMode>' "
      '~/.googleearth/myplaces.kml 2>/dev/null',
    );
    if (probe != null && (int.tryParse(probe.trim()) ?? 0) > 0) {
      debugPrint('SSH: master.kml live-refresh already enabled');
      return false;
    }
    debugPrint('SSH: enabling master.kml live-refresh (one-time) + relaunch lg1');
    await sendCommand(
      "sed -i -e '${_masterStripExpr()}' -e '${_masterInjectExpr(seconds)}' "
      '~/.googleearth/myplaces.kml',
    );
    await sendCommand('killall -9 googleearth-bin; google-earth-pro &');
    return true;
  }

  String _stripExpr(int i) =>
      "/slave_$i.kml/ s#<refreshMode>onInterval</refreshMode>"
      "<refreshInterval>[0-9]*</refreshInterval>##";

  // Same idea as [_stripExpr] but for the master's own master.kml NetworkLink
  // (dot escaped so it can't match master_1.kml).
  String _masterStripExpr() =>
      "/master\\.kml/ s#<refreshMode>onInterval</refreshMode>"
      "<refreshInterval>[0-9]*</refreshInterval>##";
  String _masterInjectExpr(int seconds) =>
      "/master\\.kml/ s#</href>#</href>"
      "<refreshMode>onInterval</refreshMode>"
      "<refreshInterval>$seconds</refreshInterval>#";
}
