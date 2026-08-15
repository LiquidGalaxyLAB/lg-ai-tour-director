import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../lg/lg_service.dart';

/// Real-time phone-map to Liquid Galaxy sync (La Palma pattern, GSoC 2022):
/// store the camera on every move, fire one `flytoview=` write on idle.
/// Reuses the app's single persistent SSH connection; singleton.
class MapSyncService {
  MapSyncService._();

  static final MapSyncService instance = MapSyncService._();

  // Latest camera values captured from onCameraMove (fired to LG on idle).
  double _lat = 0, _lng = 0, _bearing = 0, _tilt = 0;
  // Camera to target distance in metres, used as the LookAt <range>.
  double _range = 0;

  // Only mirror while a screen enabled sync AND the rig is connected.
  bool _syncEnabled = false;

  // LG screen count; the range formula divides by it for the screen spread.
  int _rigCount = 3;

  bool get isEnabled => _syncEnabled;

  /// The rig's screen count, set by screens when they enable sync.
  void updateRigCount(int totalScreens) {
    if (totalScreens > 0) _rigCount = totalScreens;
  }

  /// Store the newest camera values. No SSH here (fires on idle).
  void onCameraMove(CameraPosition position) {
    _lat = position.target.latitude;
    _lng = position.target.longitude;
    _bearing = position.bearing;
    _tilt = position.tilt;
    // La Palma zoom to metres conversion, divided by the screen count.
    _range = 591657550.5 / math.pow(2, position.zoom) / _rigCount;
  }

  /// Gesture settled: mirror the stored camera with one write. No-op when
  /// sync is off or the rig is offline.
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
        'lng=${_lng.toStringAsFixed(5)} range=${_range.toStringAsFixed(0)}',
      );
    } catch (e) {
      debugPrint('[MapSync] sync failed: $e');
    }
  }

  /// The `flytoview=<LookAt>` written to `/tmp/query.txt`. Ground target with
  /// `relativeToSeaFloor`, the format this rig's Google Earth honours.
  String _flyToView() {
    return 'flytoview=<LookAt>'
        '<longitude>$_lng</longitude>'
        '<latitude>$_lat</latitude>'
        '<altitude>0</altitude>'
        '<range>$_range</range>'
        '<tilt>$_tilt</tilt>'
        '<heading>$_bearing</heading>'
        '<gx:altitudeMode>relativeToSeaFloor</gx:altitudeMode>'
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
