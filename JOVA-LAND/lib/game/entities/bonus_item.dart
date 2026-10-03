import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../app/theme.dart';
import '../core/grid.dart';
import '../core/units.dart';

/// Gold "J" coin that appears twice per level for a limited time.
class BonusItem extends PositionComponent {
  BonusItem() : super(priority: 3, anchor: Anchor.center);

  static const double lifetime = 9;

  Cell? cell;
  int points = 0;
  double _left = 0;
  double _time = 0;

  final Paint _glow = Paint()
    ..color = Palette.gold.withValues(alpha: 0.5)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  final Paint _coin = Paint()
    ..shader = const RadialGradient(
      colors: [Color(0xFFFFF3B0), Palette.gold, Color(0xFFE09A00)],
      stops: [0, 0.55, 1],
    ).createShader(Rect.fromCircle(center: const Offset(-2, -2), radius: 10));
  final Paint _rim = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..color = const Color(0xFFFFF1B0);
  late final TextPainter _letter = TextPainter(
    text: const TextSpan(
      text: 'J',
      style: TextStyle(
        fontFamily: Fonts.display,
        fontSize: 9,
        color: Color(0xFF5A3A00),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  bool get isVisible => cell != null;

  void show(Cell at, int value) {
    cell = at;
    points = value;
    _left = lifetime;
    _time = 0;
    position.setValues((at.col + 0.5) * kTile, (at.row + 0.5) * kTile);
  }

  void hide() => cell = null;

  /// Advances the timer; returns true if the coin just expired.
  bool tick(double dt) {
    if (cell == null) return false;
    _left -= dt;
    if (_left > 0) return false;
    hide();
    return true;
  }

  @override
  void update(double dt) => _time += dt;

  @override
  void render(Canvas canvas) {
    if (cell == null) return;
    if (_left < 2 && (_time * 8).floor().isEven) return;
    final appear = min(1.0, _time * 4);
    final spin = cos(_time * 3).abs() * 0.6 + 0.4;
    final bob = sin(_time * 4) * 1.5;
    canvas
      ..save()
      ..translate(0, bob)
      ..scale(appear * spin, appear);
    canvas.drawCircle(Offset.zero, 11, _glow);
    canvas
      ..drawCircle(Offset.zero, 8, _coin)
      ..drawCircle(Offset.zero, 8, _rim);
    _letter.paint(canvas, Offset(-_letter.width / 2 + 0.5, -_letter.height / 2 + 0.5));
    canvas.restore();
  }
}
