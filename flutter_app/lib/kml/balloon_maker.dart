import 'package:flutter/foundation.dart';

// builds the contextual info balloon KML deployed to the right-most LG slave
// screen during a tour

/// The balloon is a **ScreenOverlay** whose icon is a `data:text/html,...` URI,
/// not a `BalloonStyle` placemark — a ScreenOverlay gives pixel-perfect, fixed
/// positioning independent of the screen resolution. The card is ALWAYS exactly
/// 420×580px, pinned to the top-right corner, with a 420×240px image box that
/// uses `object-fit: cover` so images crop-to-fill (never stretch/distort)
class BalloonMaker {
  BalloonMaker._();

  static const int width = 420;
  static const int height = 580;
  static const int imageHeight = 240;

  /// Full info-balloon KML for [locationName] / [locationSubtitle] /
  /// [description] / [imageUrl]. When [imageUrl] is empty the image box is
  /// hidden (`display:none`) and the text content fills the whole 580px card
  static String infoBalloon({
    required String locationName,
    required String locationSubtitle,
    required String description,
    required String imageUrl,
  }) {
    final hasImage = imageUrl.trim().isNotEmpty;
    final html = _html(
      locationName: locationName,
      locationSubtitle: locationSubtitle,
      description: description,
      imageUrl: imageUrl,
      hasImage: hasImage,
    );

    // Uri.encodeComponent leaves ' ! ~ * ( ) unescaped; a literal ' would break
    // the slave write (echo '<kml>' > ...), so escape it to its percent form.
    final encoded = Uri.encodeComponent(html).replaceAll("'", '%27');

    final kml =
        '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <ScreenOverlay>
      <name>InfoBalloon</name>
      <Icon>
        <href>data:text/html,$encoded</href>
      </Icon>
      <overlayXY x="1" y="1" xunits="fraction" yunits="fraction"/>
      <screenXY x="1" y="1" xunits="fraction" yunits="fraction"/>
      <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
      <size x="$width" y="$height" xunits="pixels" yunits="pixels"/>
    </ScreenOverlay>
  </Document>
</kml>''';

    debugPrint(
      '[BalloonMaker] infoBalloon "$locationName" '
      '(image: $hasImage) → ${kml.length} chars',
    );
    return kml;
  }

  static String imageOverlay({required String host, required String fileName}) {
    final kml =
        '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <ScreenOverlay>
      <name>InfoBalloon</name>
      <Icon><href>http://$host:81/$fileName</href></Icon>
      <overlayXY x="1" y="1" xunits="fraction" yunits="fraction"/>
      <screenXY x="1" y="1" xunits="fraction" yunits="fraction"/>
      <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
      <size x="$width" y="$height" xunits="pixels" yunits="pixels"/>
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

  static String _html({
    required String locationName,
    required String locationSubtitle,
    required String description,
    required String imageUrl,
    required bool hasImage,
  }) {
    final name = _esc(locationName);
    final subtitle = _esc(locationSubtitle);
    final desc = _esc(description);
    final img = _esc(imageUrl);

    final imageBlock = hasImage
        ? '''  <div class="image-container">
    <img src="$img" alt="$name"/>
  </div>'''
        : '';

    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    width: 420px; height: 580px;
    background: #1A1A2E;
    font-family: Arial, sans-serif;
    color: white;
    overflow: hidden;
  }
  .image-container {
    width: 420px; height: 240px;
    overflow: hidden;
    position: relative;
  }
  .image-container img {
    width: 100%; height: 100%;
    object-fit: cover;
    object-position: center center;
    display: block;
  }
  .content {
    padding: 16px;
  }
  .location-name {
    font-size: 22px;
    font-weight: bold;
    color: #FFFFFF;
    line-height: 1.2;
    margin-bottom: 4px;
  }
  .location-subtitle {
    font-size: 12px;
    color: #9AA0A6;
    margin-bottom: 12px;
  }
  .divider {
    width: 40px; height: 2px;
    background: #4285F4;
    margin-bottom: 12px;
  }
  .description {
    font-size: 13px;
    color: #BDC1C6;
    line-height: 1.6;
  }
  .footer {
    position: absolute;
    bottom: 12px; left: 16px;
    font-size: 10px;
    color: #5F6368;
  }
</style>
</head>
<body>
$imageBlock
  <div class="content">
    <div class="location-name">$name</div>
    <div class="location-subtitle">$subtitle</div>
    <div class="divider"></div>
    <div class="description">$desc</div>
  </div>
  <div class="footer">Powered by Liquid Galaxy</div>
</body>
</html>''';
  }

  /// Minimal HTML-entity escaping so user/Wikipedia text can't break the markup.
  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
