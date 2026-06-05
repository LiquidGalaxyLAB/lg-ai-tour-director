class AppConstants {
  const AppConstants._();

  //External API base URLs
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String geocodingBaseUrl =
      'https://maps.googleapis.com/maps/api/geocode';
  static const String placesBaseUrl =
      'https://maps.googleapis.com/maps/api/place';
  static const String wikimediaBaseUrl = 'https://en.wikipedia.org/api/rest_v1';

  // Liquid Galaxy defaults
  static const int defaultSshPort = 22;
  static const int defaultLgScreens = 3;
  static const String defaultLgUsername = 'lg';

  /// KML serving directory on every LG node (master + slaves)
  static const String kmlServingPath = '/var/www/html/';
  static const String masterKmlFilename = 'tour.kml';
  static const String balloonKmlFilename = 'balloon.kml';
  static const String logoKmlFilename = 'logo.kml';

  // Tour generation tuning
  /// Base narration speech rate in words/second used to estimate scene timing
  static const double defaultSpeechRateWps = 2.5;
  static const int orbitKeyframeCount = 8;
  static const double orbitRadiusMeters = 600;
}
