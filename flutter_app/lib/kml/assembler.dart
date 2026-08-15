import '../models/location.dart';
import 'generator.dart';

/// Builds a playable KML with one `<gx:Tour>` flying every geocoded stop, plus
/// numbered markers. The tour's `<name>` must match the `playtour=` name.
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
    // Opening establishing shot framing every stop.
    playlist.writeln(KmlGenerator.openingOverview(geocoded));
    // One cinematic beat per stop.
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
