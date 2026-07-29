import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../lg/lg_service.dart';

class MapSyncService {
  MapSyncService._();

  static final MapSyncService instance = MapSyncService._();

  double _lat = 0, _lng = 0, _bearing = 0, _tilt = 0;
  double _altitude = 0;

  bool _syncEnabled = false;

  int _rigCount = 3;

  bool get isEnabled => _syncEnabled;

  void updateRigCount(int totalScreens) {
    if (totalScreens > 0) _rigCount = totalScreens;
  }

  void onCameraMove(CameraPosition position) {
    _lat = position.target.latitude;
    _lng = position.target.longitude;
    _bearing = position.bearing;
    _tilt = position.tilt;

    _altitude = 591657550.5 / math.pow(2, position.zoom) / _rigCount;
  }

  Future<void> onCameraIdle() async {
    if (!_syncEnabled) {
      debugPrint('[MapSync] skipped (sync disabled)');
      return;
    }
    if (!LGService.instance.isConnected) {
      debugPrint('[MapSync] skipped (not connected)');
      return;
    }
    try {
      final query = _flyToView();
      await LGService.instance.runCommand('echo "$query" > /tmp/query.txt');
      debugPrint(
        '[MapSync] synced lat=${_lat.toStringAsFixed(5)} '
        'lng=${_lng.toStringAsFixed(5)} alt=${_altitude.toStringAsFixed(0)}',
      );
    } catch (e) {
      debugPrint('[MapSync] sync failed: $e');
    }
  }

  String _flyToView() {
    return 'flytoview=<LookAt>'
        '<longitude>$_lng</longitude>'
        '<latitude>$_lat</latitude>'
        '<altitude>$_altitude</altitude>'
        '<heading>$_bearing</heading>'
        '<tilt>$_tilt</tilt>'
        '<range>$_altitude</range>'
        '<gx:altitudeMode>relativeToGround</gx:altitudeMode>'
        '</LookAt>';
  }

  void enable() {
    _syncEnabled = true;
    debugPrint('[MapSync] enabled (rigCount=$_rigCount)');
  }

  void disable() {
    _syncEnabled = false;
    debugPrint('[MapSync] disabled');
  }
}
