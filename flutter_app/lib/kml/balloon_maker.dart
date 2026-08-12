import 'package:flutter/foundation.dart';

class BalloonMaker {
  BalloonMaker._();

  static const double _widthFraction = 0.71;

  static String imageOverlay({required String host, required String fileName}) {
    final kml =
        '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <ScreenOverlay>
      <name>InfoBalloon</name>
      <Icon><href>http://$host:81/$fileName</href></Icon>
      <overlayXY x="0.5" y="0.5" xunits="fraction" yunits="fraction"/>
      <screenXY x="0.5" y="0.55" xunits="fraction" yunits="fraction"/>
      <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
      <size x="$_widthFraction" y="0" xunits="fraction" yunits="fraction"/>
    </ScreenOverlay>
  </Document>
</kml>''';
    debugPrint('[BalloonMaker] imageOverlay $fileName → ${kml.length} chars');
    return kml;
  }

  static String emptyBalloon() {
    const kml =
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<kml xmlns="http://www.opengis.net/kml/2.2"><Document></Document></kml>';
    debugPrint('[BalloonMaker] emptyBalloon → ${kml.length} chars');
    return kml;
  }
}
