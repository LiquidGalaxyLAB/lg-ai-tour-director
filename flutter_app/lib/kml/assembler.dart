import '../models/location.dart';
import 'generator.dart';

/// Assembles a complete, playable KML document containing a single `<gx:Tour>`
/// that flies the rig through every geocoded stop, plus numbered markers.
///
/// Deploy the returned string with `LGService.sendKml(kml, fileName: 'tour.kml')`
/// then play it on the rig with `playtour=<tourName>` (see
/// `SshConnection.flyGeneratedTour`). The tour's `<name>` MUST match the name
/// passed to `playtour=`.
class KmlAssembler {
  KmlAssembler._();

  /// Default name; the `playtour=` command must use the same string.
  static const String defaultTourName = 'AITourDirector';

  /// Builds the full tour KML. Pass only **geocoded** locations (lat/lng set);
  /// returns `null` if none qualify (nothing to fly to).
  static String? buildTour({
    required List<TourLocation> locations,
    String tourName = defaultTourName,
    double holdSecondsPerStop = 4,
  }) {
    final geocoded = locations
        .where((l) => l.latitude != null && l.longitude != null)
        .toList();
    if (geocoded.isEmpty) return null;

    final playlist = StringBuffer();
    // 1. Opening establishing shot framing every stop.
    playlist.writeln(KmlGenerator.openingOverview(geocoded));
    // 2. One cinematic beat per stop.
    for (final loc in geocoded) {
      playlist.writeln(
        KmlGenerator.lookAtScene(loc, holdSeconds: holdSecondsPerStop),
      );
    }

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>$tourName</name>
    <open>1</open>
${KmlGenerator.markers(geocoded)}
    <gx:Tour>
      <name>$tourName</name>
      <gx:Playlist>
${playlist.toString().trimRight()}
      </gx:Playlist>
    </gx:Tour>
  </Document>
</kml>''';
  }
}
