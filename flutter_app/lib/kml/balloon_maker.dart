import 'package:flutter/foundation.dart';

class BalloonMaker {
  BalloonMaker._();

  static const double widthFraction = 0.8;
  static const double heightFraction = 0.6;

  static String imageOverlay({required String host, required String fileName}) {
    final kml =
        '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <ScreenOverlay>
      <name>InfoBalloon</name>
      <Icon><href>http://$host:81/$fileName</href></Icon>
      <overlayXY x="0.5" y="0.5" xunits="fraction" yunits="fraction"/>
      <screenXY x="0.5" y="0.5" xunits="fraction" yunits="fraction"/>
      <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
      <size x="$widthFraction" y="$heightFraction" xunits="fraction" yunits="fraction"/>
    </ScreenOverlay>
  </Document>
</kml>''';
    debugPrint('[BalloonMaker] imageOverlay $fileName → ${kml.length} chars');
    return kml;
  }

  /// Valid KML that clears/hides the balloon (used between locations and on
  /// tour end). An empty `<Document>` blanks the slave overlay without a parse
  /// error — never return an empty string here, Google Earth would throw.
  static String emptyBalloon() {
    const kml =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<kml xmlns="http://www.opengis.net/kml/2.2"><Document></Document></kml>';
    debugPrint('[BalloonMaker] emptyBalloon → ${kml.length} chars');
    return kml;
  }
}
