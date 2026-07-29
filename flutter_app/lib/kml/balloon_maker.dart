import 'package:flutter/foundation.dart';

class BalloonMaker {
  BalloonMaker._();

  // Card width as a FRACTION of the screen so it scales with any rig's
  // resolution (pixel sizing looked tiny on the high-res GalaxyLAB panels).
  // Height is auto (`y="0"`) so the portrait aspect is preserved — never
  // stretched. Tune this one number on the rig: bigger = larger card.
  // 0.5 covered the whole landmark on the rig; 0.42 keeps it readable while the
  // scene stays visible behind it.
  static const double _widthFraction = 0.42;

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
