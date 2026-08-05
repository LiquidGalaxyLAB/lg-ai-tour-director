import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

class BalloonImageMaker {
  BalloonImageMaker._();

  static const double w = 494;
  static const double h = 720;
  static const double imageH = 260;
  static const double pad = 26;

  static const Color _bg = Color(0xFF1A1A2E);
  static const Color _title = Color(0xFFFFFFFF);
  static const Color _subtitle = Color(0xFF9AA0A6);
  static const Color _accent = Color(0xFF4285F4);
  static const Color _body = Color(0xFFBDC1C6);
  static const Color _footerColor = Color(0xFF5F6368);

  static Future<Uint8List> render({
    required String locationName,
    required String locationSubtitle,
    required String description,
    Uint8List? imageBytes,
    // Supersample factor: the PNG is rendered at scale× the logical 380×500 so
    // it stays crisp when Google Earth scales the (now larger, fraction-sized)
    // overlay up on a high-res rig.
    double scale = 3,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w * scale, h * scale));
    // Draw in logical w×h coordinates; the scale just supersamples output.
    canvas.scale(scale);

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
      size: 29,
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
      size: 16,
      color: _subtitle,
      maxWidth: contentWidth,
      maxLines: 1,
    );
    canvas.drawParagraph(sub, Offset(pad, y));
    y += sub.height + 12;

    // Accent divider (40×2).
    canvas.drawRect(Rect.fromLTWH(pad, y, 40, 2), Paint()..color = _accent);
    y += 2 + 12;

    // Footer sits in a reserved zone at the bottom; cap the description so it
    // can never run into it (ellipsise the overflow).
    const footerSize = 13.0;
    const footerZone = footerSize * 1.3 + 12; // text height + bottom gap
    const descSize = 22.0;
    const descLineHeight = descSize * 1.55;
    final descMaxLines = ((h - y - footerZone) / descLineHeight).floor().clamp(
      1,
      99,
    );
    final desc = _paragraph(
      description,
      size: descSize,
      color: _body,
      maxWidth: contentWidth,
      height: 1.55,
      maxLines: descMaxLines,
    );
    canvas.drawParagraph(desc, Offset(pad, y));

    // Footer pinned to the bottom-left.
    final footer = _paragraph(
      'Powered by Liquid Galaxy',
      size: footerSize,
      color: _footerColor,
      maxWidth: contentWidth,
      maxLines: 1,
    );
    canvas.drawParagraph(footer, Offset(pad, h - footer.height - 12));

    final picture = recorder.endRecording();
    final rendered = await picture.toImage(
      (w * scale).toInt(),
      (h * scale).toInt(),
    );
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
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.left,
              fontSize: size,
              fontWeight: weight,
              height: height,
              maxLines: maxLines,
              ellipsis: maxLines != null ? '…' : null,
            ),
          )
          ..pushStyle(
            ui.TextStyle(color: color, fontSize: size, fontWeight: weight),
          )
          ..addText(text);
    return builder.build()..layout(ui.ParagraphConstraints(width: maxWidth));
  }
}
