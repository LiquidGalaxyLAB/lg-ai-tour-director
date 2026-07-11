import 'dart:math' as math;

import '../models/location.dart';

// this is for building the individual KML fragments a cinematic tour

// pure string builders cause the LG community approach, no SDK, no I/O

// fragments are stitched together by [KmlAssembler] and oordinates are assumed

// non-null here: callers filter out un-geocoded locations first
class KmlGenerator {
  KmlGenerator._();

  static const double lookAtTilt = 60;
  static const double lookAtRange = 1200;
  static const double flyDurationSeconds = 4;

  static const double orbitRange = 800;
  static const double orbitTilt = 60;
  // 8 segments of 45° = a full 360° circle. The sweep emits headings
  // 45,90,…,360 (frame at 360° closes the loop back to the 0° arrival), so the
  // whole orbit is 9 keyframes: the arrival at heading 0 + these 8.
  static const int orbitSteps = 8;
  static const double approachHoldSeconds = 10;
  // ~2s per 45° step. GE animates each `flytoview=` at its own built-in speed;
  // if the next heading is written before GE finishes the current swing it gets
  // interrupted and the orbit under-rotates (the old 5×72°/1s bug). 2s per 45°
  // gives GE time to complete each segment, so the full circle actually closes.
  static const double orbitTotalSeconds = 16;

  // Markers

  //numbered `<Placemark>` pin for one stop
  static String placemark(TourLocation loc, int order) {
    return '''
    <Placemark>
      <name>$order. ${_esc(loc.name)}</name>
      <Point><coordinates>${loc.longitude},${loc.latitude},0</coordinates></Point>
    </Placemark>''';
  }

  // all stop markers in order as one block
  static String markers(List<TourLocation> locations) {
    final buffer = StringBuffer();
    for (var i = 0; i < locations.length; i++) {
      buffer.writeln(placemark(locations[i], i + 1));
    }
    return buffer.toString();
  }

  // Camera movement

  static String flyTo({
    required double lat,
    required double lng,
    double altitude = 0,
    double tilt = lookAtTilt,
    double heading = 0,
    double range = lookAtRange,
    double durationSeconds = flyDurationSeconds,
    String mode = 'smooth',
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
      tilt: 0,
      range: range,
      durationSeconds: flyDurationSeconds + 1,
      mode: 'bounce',
    );
    return '$fly\n${wait(holdSeconds)}';
  }

  // ── Live camera driver (flytoview=) ─────────────────────────────────────────
  // This rig's Google Earth honours `flytoview=` in /tmp/query.txt (proven by
  // the working flyToPune) but NOT `playtour=`. So a live tour is driven as an
  // ordered sequence of these views, one query.txt write per stop, with a hold
  // in between — GE animates smoothly to each, giving the same cinematic result.

  /// Ordered camera viewpoints for a live-driven tour: a wide opening overview
  /// framing every stop, then per stop an approach (held long enough for the
  /// imagery to sharpen) followed by a full 360° orbit around the landmark.
  static List<CameraView> tourCameraViews(List<TourLocation> locations) {
    final center = _centroid(locations);
    final overviewRange = _framingRange(locations, center);
    final views = <CameraView>[
      CameraView(
        lat: center.lat,
        lng: center.lng,
        tilt: 0,
        range: overviewRange,
        flySeconds: flyDurationSeconds + 1,
        holdSeconds: 2,
      ),
    ];
    for (final l in locations) {
      views.addAll(_orbitViews(l.latitude!, l.longitude!));
    }
    return views;
  }

  static List<CameraView> _orbitViews(double lat, double lng) {
    return <CameraView>[
      CameraView(
        lat: lat,
        lng: lng,
        tilt: orbitTilt,
        heading: 0,
        range: orbitRange,
        flySeconds: flyDurationSeconds,
        holdSeconds: approachHoldSeconds,
      ),
      ...orbitSweep(lat, lng, range: orbitRange),
    ];
  }

  /// The 360° heading sweep around a fixed point: [orbitSteps] frames advancing
  /// the heading by 360/[orbitSteps]° each (45° for 8 steps) — 45,90,…,360 — the
  /// last frame closing the circle back to the starting heading. Only the
  /// heading changes; [lat]/[lng]/[range]/[altitude]/tilt stay constant so the
  /// camera holds a fixed radius. Reused by the tour and the dev orbit test.
  static List<CameraView> orbitSweep(
    double lat,
    double lng, {
    double range = orbitRange,
    double altitude = 0,
  }) {
    final perStep = orbitTotalSeconds / orbitSteps;
    return <CameraView>[
      for (var i = 1; i <= orbitSteps; i++)
        CameraView(
          lat: lat,
          lng: lng,
          altitude: altitude,
          tilt: orbitTilt,
          heading: (360 / orbitSteps) * i,
          range: range,
          flySeconds: perStep,
          holdSeconds: 0,
        ),
    ];
  }

  // The single-line `flytoview=<LookAt>…</LookAt>` payload to echo into
  // /tmp/query.txt — same shape as the proven flyToPune command.
  static String flyToViewQuery(CameraView v) {
    return 'flytoview=<LookAt>'
        '<longitude>${v.lng}</longitude>'
        '<latitude>${v.lat}</latitude>'
        '<altitude>${v.altitude}</altitude>'
        '<range>${v.range}</range>'
        '<tilt>${v.tilt}</tilt>'
        '<heading>${v.heading}</heading>'
        '<gx:altitudeMode>relativeToSeaFloor</gx:altitudeMode>'
        '</LookAt>';
  }

  // Camera maths

  static _LatLng _centroid(List<TourLocation> locations) {
    var lat = 0.0, lng = 0.0;
    for (final l in locations) {
      lat += l.latitude!;
      lng += l.longitude!;
    }
    return _LatLng(lat / locations.length, lng / locations.length);
  }

  static double _framingRange(List<TourLocation> locations, _LatLng center) {
    var maxMetres = 0.0;
    for (final l in locations) {
      final d = _haversine(center.lat, center.lng, l.latitude!, l.longitude!);
      if (d > maxMetres) maxMetres = d;
    }
    final range = maxMetres * 2.2;
    return range.clamp(2000.0, 8000000.0);
  }

  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0; // metres
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;

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

// one camera viewpoint in a live driven (`flytoview=`) tour, plus how long to
// fly into it and hold there before the next stop
class CameraView {
  const CameraView({
    required this.lat,
    required this.lng,
    required this.range,
    required this.flySeconds,
    required this.holdSeconds,
    this.altitude = 0,
    this.tilt = KmlGenerator.lookAtTilt,
    this.heading = 0,
  });

  final double lat;
  final double lng;
  final double altitude;
  final double tilt;
  final double heading;
  final double range;
  final double flySeconds;
  final double holdSeconds;

  // total seconds to wait after issuing this view before the next one
  Duration get settleDuration =>
      Duration(milliseconds: ((flySeconds + holdSeconds) * 1000).round());
}
