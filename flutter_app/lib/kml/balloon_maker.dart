import 'package:flutter/foundation.dart';

/// Builds the KML that places the info balloon on the right-most LG slave
/// screen during a tour.
///
/// The balloon is a **ScreenOverlay** referencing a pre-rendered PNG (built by
/// `BalloonImageMaker` and uploaded to the master web root). A ScreenOverlay
/// icon must be an image — Google Earth does not render HTML there — which is
/// why the card is rasterised on-device rather than embedded as `data:text/html`.
///
/// The overlay floats against the right edge, vertically centred, at 85% of the
/// screen height (≈7.5% margin top and bottom) so it reads as a floating card
/// rather than a full-height panel. Width auto-scales (`x="0"`) to preserve the
/// card's aspect ratio.
class BalloonMaker {
  BalloonMaker._();

  /// Fraction of the screen height the floating card occupies (7.5% margin
  /// top + bottom → 85%).
  static const double heightFraction = 0.85;

  /// ScreenOverlay KML that renders an already-uploaded PNG ([fileName], served
  /// from the master web root on port 81) as the floating info card.
  static String imageOverlay({required String host, required String fileName}) {
    final kml =
        '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <ScreenOverlay>
      <name>InfoBalloon</name>
      <Icon><href>http://$host:81/$fileName</href></Icon>
      <overlayXY x="1" y="0.5" xunits="fraction" yunits="fraction"/>
      <screenXY x="1" y="0.5" xunits="fraction" yunits="fraction"/>
      <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
      <size x="0" y="$heightFraction" xunits="fraction" yunits="fraction"/>
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
