import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Rasterises the info balloon to a PNG with `dart:ui` (no widget tree / no
/// BuildContext — safe to call from the service layer).
///
/// Google Earth's `ScreenOverlay` icon must be an IMAGE, not HTML, so the card
/// is drawn here at exactly 420×580 and deployed like the logo overlay. The
/// design mirrors the original HTML spec: dark card, a 420×240 cover-cropped
/// image, title / subtitle / accent divider / description, and a footer.
class BalloonImageMaker {
  BalloonImageMaker._();

  static const double w = 420;
  static const double h = 580;
  static const double imageH = 240;
  static const double pad = 16;

  static const Color _bg = Color(0xFF1A1A2E);
  static const Color _title = Color(0xFFFFFFFF);
  static const Color _subtitle = Color(0xFF9AA0A6);
  static const Color _accent = Color(0xFF4285F4);
  static const Color _body = Color(0xFFBDC1C6);
  static const Color _footerColor = Color(0xFF5F6368);

  /// Renders the card to PNG bytes. [imageBytes] is the (already downloaded)
  /// location image; when null/undecodable the image box is omitted and the
  /// text fills the card.
  static Future<Uint8List> render({
    required String locationName,
    required String locationSubtitle,
    required String description,
    Uint8List? imageBytes,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));

    // Card background.
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = _bg);

    var y = pad;
    final image = imageBytes == null ? null : await _decode(imageBytes);
    if (image != null) {
      // object-fit: cover — paintImage handles the centre-crop + clipping.
      paintImage(
        canvas: canvas,
        rect: const Rect.fromLTWH(0, 0, w, imageH),
        image: image,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
      y = imageH + pad;
    }

    const contentWidth = w - pad * 2;

    final name = _paragraph(
      locationName,
      size: 22,
      color: _title,
      weight: FontWeight.bold,
      maxWidth: contentWidth,
      height: 1.2,
      maxLines: 2,
    );
    canvas.drawParagraph(name, Offset(pad, y));
    y += name.height + 4;

    final sub = _paragraph(
      locationSubtitle,
      size: 12,
      color: _subtitle,
      maxWidth: contentWidth,
      maxLines: 1,
    );
    canvas.drawParagraph(sub, Offset(pad, y));
    y += sub.height + 12;

    // Accent divider (40×2).
    canvas.drawRect(Rect.fromLTWH(pad, y, 40, 2), Paint()..color = _accent);
    y += 2 + 12;

    final desc = _paragraph(
      description,
      size: 13,
      color: _body,
      maxWidth: contentWidth,
      height: 1.6,
    );
    canvas.drawParagraph(desc, Offset(pad, y));

    // Footer pinned to the bottom-left.
    final footer = _paragraph(
      'Powered by Liquid Galaxy',
      size: 10,
      color: _footerColor,
      maxWidth: contentWidth,
      maxLines: 1,
    );
    canvas.drawParagraph(footer, Offset(pad, h - footer.height - 12));

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(w.toInt(), h.toInt());
    final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    rendered.dispose();
    image?.dispose();
    return png!.buffer.asUint8List();
  }

  static Future<ui.Image?> _decode(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static ui.Paragraph _paragraph(
    String text, {
    required double size,
    required Color color,
    required double maxWidth,
    FontWeight weight = FontWeight.normal,
    double height = 1.3,
    int? maxLines,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.left,
        fontSize: size,
        fontWeight: weight,
        height: height,
        maxLines: maxLines,
        ellipsis: maxLines != null ? '…' : null,
      ),
    )
      ..pushStyle(ui.TextStyle(color: color, fontSize: size, fontWeight: weight))
      ..addText(text);
    return builder.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth));
  }
}
