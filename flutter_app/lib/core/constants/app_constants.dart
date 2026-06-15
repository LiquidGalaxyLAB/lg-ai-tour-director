class AppConstants {
  const AppConstants._();

  //External API base URLs
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/';

  // Gemini model fallback chain. Cheapest/lightest first — extracting ~5
  // locations does not need a top-tier model. If one model is unavailable
  // (404/quota), the service falls through to the next. Stable (non-preview)
  // models only, so the app does not break when a preview is retired.
  static const List<String> geminiModels = [
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash-lite',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];
  static const String geocodingBaseUrl =
      'https://maps.googleapis.com/maps/api/geocode';
  static const String placesBaseUrl =
      'https://maps.googleapis.com/maps/api/place';
  static const String wikimediaBaseUrl = 'https://en.wikipedia.org/api/rest_v1';

  // Liquid Galaxy defaults
  static const int defaultSshPort = 22;
  static const int defaultLgScreens = 3;
  static const String defaultLgUsername = 'lg';

  // KML serving directory on every LG node (master + slaves)
  static const String kmlServingPath = '/var/www/html/';
  static const String masterKmlFilename = 'tour.kml';
  static const String balloonKmlFilename = 'balloon.kml';
  static const String logoKmlFilename = 'logo.kml';

  // Tour generation tuning
  // Base narration speech rate in words/second used to estimate scene timing
  static const double defaultSpeechRateWps = 2.5;
  static const int orbitKeyframeCount = 8;
  static const double orbitRadiusMeters = 600;

  // Test KML Data
  static const String puneKml = '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
  <Document>
    <name>Shaniwar Wada, Pune</name>
    <Placemark>
      <name>Shaniwar Wada</name>
      <description>Historic fortification in the city of Pune, India.</description>
      <LookAt>
        <longitude>73.8553</longitude>
        <latitude>18.5195</latitude>
        <altitude>0</altitude>
        <range>500</range>
        <tilt>45</tilt>
        <heading>0</heading>
        <gx:altitudeMode>relativeToSeaFloor</gx:altitudeMode>
      </LookAt>
      <Point>
        <coordinates>73.8553,18.5195,0</coordinates>
      </Point>
    </Placemark>
  </Document>
</kml>
''';
}
