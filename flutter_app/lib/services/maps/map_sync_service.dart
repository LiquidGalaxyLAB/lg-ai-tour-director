import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../lg/lg_service.dart';

/// Real-time phone-map → Liquid Galaxy sync.
///
/// Pattern (Yash Raj Bharti's La Palma Volcano Tracker, GSoC 2022): the phone's
/// Google Map stores its camera on every [onCameraMove], but only fires ONE SSH
/// `flytoview=` write when the gesture settles ([onCameraIdle]). That keeps the
/// rig mirroring the phone without spamming dozens of commands per pan/pinch.
///
/// It reuses the app's single persistent SSH connection ([LGService.runCommand])
/// — it never opens its own — and writes to the SAME `/tmp/query.txt` the master
/// polls. It is a singleton, mirroring [LGService.instance].
class MapSyncService {
  MapSyncService._();

  static final MapSyncService instance = MapSyncService._();

  // Latest camera values captured from onCameraMove (fired to LG on idle).
  double _lat = 0, _lng = 0, _bearing = 0, _tilt = 0;
  // Camera→target distance in metres (the La Palma zoom→metres conversion). Used
  // as the LookAt <range>; the target itself sits on the ground (<altitude>0).
  double _range = 0;

  // Only mirror to the rig while a screen has explicitly turned sync on AND the
  // rig is connected. Off by default so a stray pan never touches the rig.
  bool _syncEnabled = false;

  // Number of LG screens — the La Palma formula divides by it so the zoom
  // matches the rig's multi-screen horizontal spread. Defaults to 3.
  int _rigCount = 3;

  bool get isEnabled => _syncEnabled;

  /// The rig's screen count (from `RigConfig.totalScreens`). Screens set this
  /// when they enable sync so the range conversion matches the actual rig.
  void updateRigCount(int totalScreens) {
    if (totalScreens > 0) _rigCount = totalScreens;
  }

  /// Store the newest camera values. Cheap — NO SSH here (fires on idle).
  void onCameraMove(CameraPosition position) {
    _lat = position.target.latitude;
    _lng = position.target.longitude;
    _bearing = position.bearing;
    _tilt = position.tilt;
    // La Palma zoom→metres conversion (Maps zoom 0-21 → Earth range), divided
    // by the rig's screen count for the multi-screen spread.
    _range = 591657550.5 / math.pow(2, position.zoom) / _rigCount;
  }

  /// The gesture settled — mirror the stored camera to the rig with a single
  /// `flytoview=` write. Silent no-op when sync is off or the rig is offline.
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

  /// The `flytoview=<LookAt>` written to `/tmp/query.txt`. Same shape the tour
  /// uses (KmlGenerator.flyToViewQuery) — ground target (`altitude` 0), `range`
  /// = viewing distance, `relativeToSeaFloor` — which is the format this rig's
  /// Google Earth actually honours. (The La Palma `relativeToGround` + lifted
  /// altitude did not move GE on this rig.)
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
