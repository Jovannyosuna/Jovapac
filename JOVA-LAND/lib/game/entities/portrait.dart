import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Draws a character portrait as a round token with a neon ring, soft glow
/// and contact shadow. Paints are reused across frames.
class PortraitRenderer {
  final Paint _image = Paint()..filterQuality = FilterQuality.medium;
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.2;
  final Paint _glow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  final Paint _shadow = Paint()
    ..color = const Color(0x66000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
  final Paint _tint = Paint();
  final Path _clip = Path();

  void draw(
    Canvas canvas, {
    required ui.Image image,
    required double radius,
    required Color ring,
    double glow = 0.35,
    double opacity = 1,
    Color? tint,
    bool flip = false,
  }) {
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(0, radius * 0.95), width: radius * 1.7, height: radius * 0.5),
      _shadow..color = Color.fromRGBO(0, 0, 0, 0.4 * opacity),
    );
    if (glow > 0) {
      _glow.color = ring.withValues(alpha: glow * opacity);
      canvas.drawCircle(Offset.zero, radius + 3, _glow);
    }

    _clip
      ..reset()
      ..addOval(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas
      ..save()
      ..clipPath(_clip);
    if (flip) canvas.scale(-1, 1);
    _image.color = Color.fromRGBO(255, 255, 255, opacity);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCircle(center: Offset.zero, radius: radius),
      _image,
    );
    if (tint != null) {
      canvas.drawCircle(Offset.zero, radius, _tint..color = tint);
    }
    canvas.restore();

    _ring.color = ring.withValues(alpha: opacity);
    canvas.drawCircle(Offset.zero, radius, _ring);
  }
}
