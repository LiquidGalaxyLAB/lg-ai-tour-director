import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

class BalloonImageMaker {
  BalloonImageMaker._();

  static const double w = 494;
  static const double imageH = 260;
  static const double pad = 26;
  // Canvas height grows to fit the full description, then clamps to maxH so the
  // card stays at ~70% of a portrait screen and never touches any border.
  static const double minH = 720;
  static const double maxH = 860;

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
    // Supersample so the PNG stays crisp when Google Earth scales it up.
    double scale = 3,
  }) async {
    final image = imageBytes == null ? null : await _decode(imageBytes);

    const contentWidth = w - pad * 2;

    // Lay text out first so the canvas can size to the full description.
    final name = _paragraph(
      locationName,
      size: 29,
      color: _title,
      weight: FontWeight.bold,
      maxWidth: contentWidth,
      height: 1.2,
      maxLines: 2,
    );
    final sub = _paragraph(
      locationSubtitle,
      size: 16,
      color: _subtitle,
      maxWidth: contentWidth,
      maxLines: 1,
    );
    final desc = _paragraph(
      description,
      size: 22,
      color: _body,
      maxWidth: contentWidth,
      height: 1.55,
    );
    final footer = _paragraph(
      'Powered by Liquid Galaxy',
      size: 13,
      color: _footerColor,
      maxWidth: contentWidth,
      maxLines: 1,
    );

    // Vertical layout math — mirrors the draw order below.
    final descTop =
        (image != null ? imageH + pad : pad) +
        name.height +
        4 +
        sub.height +
        12 +
        2 +
        12; // accent divider (2px) + gap
    final footerZone = footer.height + 12; // footer text + bottom gap
    final computedH = descTop + desc.height + footerZone;
    final double h = computedH.clamp(minH, maxH).toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w * scale, h * scale));
    // Draw in logical w×h coordinates; the scale just supersamples output.
    canvas.scale(scale);

    // Card background.
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = _bg);

    var y = pad;
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

    canvas.drawParagraph(name, Offset(pad, y));
    y += name.height + 4;

    canvas.drawParagraph(sub, Offset(pad, y));
    y += sub.height + 12;

    // Accent divider (40×2).
    canvas.drawRect(Rect.fromLTWH(pad, y, 40, 2), Paint()..color = _accent);
    y += 2 + 12;

    canvas.drawParagraph(desc, Offset(pad, y));

    // Footer pinned to the bottom-left.
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
