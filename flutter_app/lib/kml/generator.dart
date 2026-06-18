import 'dart:math' as math;

import '../models/location.dart';

/// Builds the individual KML fragments a cinematic tour is made of — placemark
/// markers, `<gx:FlyTo>` camera moves and `<gx:Wait>` holds — plus the camera
/// maths for an opening shot that frames every stop.
///
/// Pure string builders (the LG community approach): no SDK, no I/O. The
/// fragments are stitched together by [KmlAssembler]. Coordinates are assumed
/// non-null here — callers filter out un-geocoded locations first.
class KmlGenerator {
  KmlGenerator._();

  /// Cinematic defaults, tuned for a single landmark.
  static const double lookAtTilt = 60; // 0 = top-down, 90 = horizon
  static const double lookAtRange = 1200; // metres from the camera to the point
  static const double flyDurationSeconds = 4; // time spent flying into a scene

  // ── Markers ───────────────────────────────────────────────────────────────

  /// A numbered `<Placemark>` pin for one stop.
  static String placemark(TourLocation loc, int order) {
    return '''
    <Placemark>
      <name>$order. ${_esc(loc.name)}</name>
      <Point><coordinates>${loc.longitude},${loc.latitude},0</coordinates></Point>
    </Placemark>''';
  }

  /// All stop markers, in order, as one block.
  static String markers(List<TourLocation> locations) {
    final buffer = StringBuffer();
    for (var i = 0; i < locations.length; i++) {
      buffer.writeln(placemark(locations[i], i + 1));
    }
    return buffer.toString();
  }

  // ── Camera moves ────────────────────────────────────────────────────────────

  /// A `<gx:FlyTo>` built from a `<LookAt>` — the core cinematic move.
  static String flyTo({
    required double lat,
    required double lng,
    double altitude = 0,
    double tilt = lookAtTilt,
    double heading = 0,
    double range = lookAtRange,
    double durationSeconds = flyDurationSeconds,
    String mode = 'smooth', // 'smooth' for the tour body, 'bounce' for the open
  }) {
    return '''
      <gx:FlyTo>
        <gx:duration>$durationSeconds</gx:duration>
        <gx:flyToMode>$mode</gx:flyToMode>
        <LookAt>
          <longitude>$lng</longitude>
          <latitude>$lat</latitude>
          <altitude>$altitude</altitude>
          <heading>$heading</heading>
          <tilt>$tilt</tilt>
          <range>$range</range>
          <altitudeMode>relativeToGround</altitudeMode>
        </LookAt>
      </gx:FlyTo>''';
  }

  /// A `<gx:Wait>` hold (used to let narration play before the next move).
  static String wait(double seconds) =>
      '      <gx:Wait><gx:duration>$seconds</gx:duration></gx:Wait>';

  /// The per-location beat: fly in close, then hold for [holdSeconds].
  static String lookAtScene(TourLocation loc, {required double holdSeconds}) {
    return '${flyTo(lat: loc.latitude!, lng: loc.longitude!)}\n'
        '${wait(holdSeconds)}';
  }

  /// Opening overview: a high, wide shot framing all stops, then a short hold.
  static String openingOverview(
    List<TourLocation> locations, {
    double holdSeconds = 2,
  }) {
    final center = _centroid(locations);
    final range = _framingRange(locations, center);
    final fly = flyTo(
      lat: center.lat,
      lng: center.lng,
      tilt: 0, // straight-down-ish wide establishing shot
      range: range,
      durationSeconds: flyDurationSeconds + 1,
      mode: 'bounce',
    );
    return '$fly\n${wait(holdSeconds)}';
  }

  // ── Camera maths ────────────────────────────────────────────────────────────

  static _LatLng _centroid(List<TourLocation> locations) {
    var lat = 0.0, lng = 0.0;
    for (final l in locations) {
      lat += l.latitude!;
      lng += l.longitude!;
    }
    return _LatLng(lat / locations.length, lng / locations.length);
  }

  /// Camera range (metres) so every stop fits in the opening shot: the distance
  /// from the centre to the farthest stop, padded, with a sane floor/ceiling.
  static double _framingRange(List<TourLocation> locations, _LatLng center) {
    var maxMetres = 0.0;
    for (final l in locations) {
      final d = _haversine(center.lat, center.lng, l.latitude!, l.longitude!);
      if (d > maxMetres) maxMetres = d;
    }
    // ×2.2 leaves margin so pins aren't on the very edge of the frame.
    final range = maxMetres * 2.2;
    return range.clamp(2000.0, 8000000.0);
  }

  static double _haversine(
      double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0; // metres
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  /// Minimal XML-escape for names that may contain `&`, `<`, `>`, quotes.
  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

class _LatLng {
  const _LatLng(this.lat, this.lng);
  final double lat;
  final double lng;
}
