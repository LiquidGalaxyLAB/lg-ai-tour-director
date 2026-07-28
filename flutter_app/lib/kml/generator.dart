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
  static const double approachHoldSeconds = 10;

  // Query-driven orbit (one flytoview= per step): the reliable path for rigs
  // whose GE ignores gx:Tour/playtour= (this VirtualBox rig does). The trick is
  // FEW, LARGE steps each held long enough for GE to fully ease into it — 8×45°
  // smooth arcs beats 72 tiny hops that each fight a full SSH round-trip's
  // latency. Prefer [buildOrbitKml] (native gx:Tour) on rigs that support it.
  static const int orbitSteps = 8;
  static const double orbitStepSeconds = 2.0; // per-step settle (GE eases in)
  static const double orbitTotalSeconds = orbitSteps * orbitStepSeconds; // 16

  static const String orbitTourName = 'Orbit';
  static const double orbitTourStepDegrees = 10;
  static const double orbitTourStepSeconds = 1.2; // gx:duration per keyframe

  // Live smooth-orbit (server-side loop) — see [orbitLoopCommand]. Fine heading
  // steps written evenly by the master itself (no per-frame SSH latency).
  //
  // CRITICAL: the heading must advance no FASTER than GE can actually chase a
  // flytoview=. In isolation (the Test Orbit button) GE manages ≈25°/s, but
  // DURING A TOUR it's busy (info-balloon load, pin markers, imagery streaming)
  // and rotates noticeably slower — so a fast pace lags a half-turn behind and
  // the orbit gets cut when the next landmark's fly-to interrupts it. GE takes
  // the SHORT angular path, so a lagging orbit can't be "finished" afterwards
  // (it wraps backward). The only fix is to pace slow enough that GE stays glued
  // through the whole turn. 5° / 0.4s ≈ 12.5°/s completes a true forward 360°
  // even under tour load (~29s). Tune down toward 0.2s only if the rig keeps up.
  static const int orbitLoopStepDegrees = 5; // heading increment per frame
  static const double orbitLoopSleepSeconds =
      0.4; // master-side pause per frame
  // Full 360° wall-clock ≈ (360/step + 1) * sleep ≈ 29.2s.
  static const double orbitLoopTotalSeconds =
      (360 / orbitLoopStepDegrees + 1) * orbitLoopSleepSeconds;

  static const double orbitLoopSettleSeconds = 12;

  // A stop-flag file on the master. [orbitLoopCommand] checks for it each frame,
  // so touching it (from stopTour, on a separate SSH channel) ends the orbit
  // within one frame — lets End Tour interrupt an in-flight orbit instantly.
  static const String orbitStopSentinel = '/tmp/lg_orbit_stop';

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

  static String buildOrbitKml({
    required double lat,
    required double lng,
    required double altitude,
    double range = orbitRange,
    double tilt = orbitTilt,
    double stepDurationSeconds = orbitTourStepSeconds,
  }) {
    final flyToBlocks = StringBuffer();
    double heading = 0;
    for (var step = 0; step <= 36; step++) {
      if (heading >= 360) heading -= 360;
      flyToBlocks.write('''
      <gx:FlyTo>
        <gx:duration>$stepDurationSeconds</gx:duration>
        <gx:flyToMode>smooth</gx:flyToMode>
        <LookAt>
          <longitude>$lng</longitude>
          <latitude>$lat</latitude>
          <heading>$heading</heading>
          <tilt>$tilt</tilt>
          <range>$range</range>
          <gx:fovy>60</gx:fovy>
          <altitude>$altitude</altitude>
          <gx:altitudeMode>relativeToGround</gx:altitudeMode>
        </LookAt>
      </gx:FlyTo>
''');
      heading += orbitTourStepDegrees;
    }

    // gx:Tour wrapped in a <Document> — some GE builds only expose the tour to
    // `playtour=<name>` when it is a Document feature, not a bare root child.
    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>Orbit Tour</name>
    <gx:Tour>
      <name>$orbitTourName</name>
      <gx:Playlist>
$flyToBlocks      </gx:Playlist>
    </gx:Tour>
  </Document>
</kml>''';
  }

  // ── Live smooth orbit via a SINGLE server-side loop ─────────────────────────
  // The landmark stays perfectly centered because longitude/latitude are frozen
  // and only <heading> sweeps 0→360 — LG's canonical orbit trick
  // (LiquidGalaxyLAB/LG-Space-Visualizations orbit_kml.dart). We drive it live
  // with flytoview= (not gx:Tour) because this rig's GE ignores playtour=. Both
  // the framing shot and the orbit share this LookAt geometry (altitude 0,
  // relativeToGround) so there is NO vertical jump when the orbit starts.

  static String _orbitLookAt(
    double lat,
    double lng,
    double range,
    double tilt,
    String heading,
  ) =>
      '<LookAt>'
      '<longitude>$lng</longitude>'
      '<latitude>$lat</latitude>'
      '<altitude>0</altitude>'
      '<range>$range</range>'
      '<tilt>$tilt</tilt>'
      '<heading>$heading</heading>'
      '<gx:altitudeMode>relativeToGround</gx:altitudeMode>'
      '</LookAt>';

  /// A single `flytoview=` payload that frames [lat],[lng] dead-centre at a
  /// fixed [heading] (used for the approach shot before the orbit begins).
  static String orbitFrameQuery(
    double lat,
    double lng, {
    double range = orbitRange,
    double tilt = orbitTilt,
    double heading = 0,
  }) =>
      'flytoview=${_orbitLookAt(lat, lng, range, tilt, heading.toStringAsFixed(1))}';

  /// ONE shell command that plays a smooth 360° orbit around [lat],[lng].
  ///
  /// It writes an incrementing-heading LookAt to `/tmp/query.txt` in a
  /// SERVER-SIDE bash loop, so all the timing runs on the master (`sleep`) and
  /// the whole orbit costs exactly ONE SSH round-trip — no per-frame network
  /// latency, which is what made the client-side per-step loop jumpy. GE gets
  /// evenly-timed heading updates and rotates continuously.
  ///
  /// The loop clears then watches [orbitStopSentinel] each frame, so the orbit
  /// can be ended mid-flight by `touch`ing that file (see stopTour).
  static String orbitLoopCommand({
    required double lat,
    required double lng,
    double range = orbitRange,
    double tilt = orbitTilt,
    int stepDegrees = orbitLoopStepDegrees,
    double sleepSeconds = orbitLoopSleepSeconds,
  }) {
    // `\$h` / `\$(...)` stay literal for the REMOTE shell; $lat/$lng/etc are
    // interpolated by Dart here.
    final lookAt = _orbitLookAt(lat, lng, range, tilt, '\$h');
    return 'rm -f $orbitStopSentinel; '
        'for h in \$(seq 0 $stepDegrees 360); do '
        '[ -f $orbitStopSentinel ] && break; '
        'echo "flytoview=$lookAt" > /tmp/query.txt; '
        'sleep $sleepSeconds; done';
  }

  /// The opening wide shot that frames every stop (top-down), shown once before
  /// diving into the per-landmark approach + orbit. Same framing the tour used
  /// before — just exposed on its own so the driver can run the orbit itself.
  static CameraView overviewView(List<TourLocation> locations) {
    final center = _centroid(locations);
    return CameraView(
      lat: center.lat,
      lng: center.lng,
      tilt: 0,
      range: _framingRange(locations, center),
      flySeconds: flyDurationSeconds + 1,
      holdSeconds: 2,
    );
  }

  // ── Glowing landmark highlight ring ─────────────────────────────────────────

  static String _ringCoordinates(double lat, double lng, double radiusMetres) {
    final latRad = lat * math.pi / 180;
    final metresPerDegLng = 111320 * math.cos(latRad);
    final buffer = StringBuffer();
    for (var deg = 0; deg <= 360; deg += 10) {
      final t = deg * math.pi / 180;
      final pLat = lat + (radiusMetres / 111320) * math.cos(t);
      final pLng = lng + (radiusMetres / metresPerDegLng) * math.sin(t);
      buffer.write('${pLng.toStringAsFixed(7)},${pLat.toStringAsFixed(7)},0 ');
    }
    return buffer.toString().trim();
  }

  static String _ringPlacemark({
    required String id,
    required double lat,
    required double lng,
    required double radius,
    required String lineColor, // KML aabbggrr
    required double lineWidth,
    required String fillColor, // KML aabbggrr (00…… = no fill)
  }) {
    return '''
    <Placemark>
      <name>$id</name>
      <Style>
        <LineStyle><color>$lineColor</color><width>$lineWidth</width></LineStyle>
        <PolyStyle><color>$fillColor</color></PolyStyle>
      </Style>
      <Polygon>
        <extrude>0</extrude>
        <tessellate>1</tessellate>
        <altitudeMode>clampToGround</altitudeMode>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>${_ringCoordinates(lat, lng, radius)}</coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>''';
  }

  /// Complete KML for the two-ring landmark highlight. [innerRadius]/[outerRadius]
  /// are in metres and tunable per landmark (a big fort needs more than a small
  /// temple). Outer ≈ 1.4× inner by default.
  static String buildLandmarkRingKml(
    double lat,
    double lng, {
    double innerRadius = 250,
    double outerRadius = 350,
  }) {
    // Outer first (drawn under), inner on top. aabbggrr, brand blue F48542:
    //   outer line 40 (~25%) width 4 + fill 14 (~8%); inner line CC (~80%) width 2, no fill.
    final outer = _ringPlacemark(
      id: 'landmark-ring-outer',
      lat: lat,
      lng: lng,
      radius: outerRadius,
      lineColor: '40F48542',
      lineWidth: 4,
      fillColor: '14F48542',
    );
    final inner = _ringPlacemark(
      id: 'landmark-ring-inner',
      lat: lat,
      lng: lng,
      radius: innerRadius,
      lineColor: 'CCF48542',
      lineWidth: 2,
      fillColor: '00000000',
    );
    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>LandmarkRing</name>
$outer
$inner
  </Document>
</kml>''';
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
