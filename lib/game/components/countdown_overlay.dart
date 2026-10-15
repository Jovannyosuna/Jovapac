// =============================================================================
// game/components/countdown_overlay.dart
//
// Cuenta regresiva 3-2-1-0.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'package:pacman_juego/core/constants.dart';
import 'package:pacman_juego/game/pacman_game.dart';

/// Cuenta regresiva de [PacManGame.countdownSeconds] segundos (3, 2, 1, 0) que
/// aparece al empezar una partida o al reanudarla tras perder una vida.
///
/// Cada número entra con un rebote desde más grande, brilla con su propio
/// color, lanza un anillo que se expande y se desvanece al final. Mientras se
/// muestra, el juego permanece congelado. Solo dibuja; el tiempo lo lleva
/// [PacManGame.countdownLeft]. Los textos se maquetan una sola vez.
class CountdownOverlay extends PositionComponent
    with HasGameReference<PacManGame> {
  CountdownOverlay() {
    priority = 100; // Por encima de todo lo demás.
  }

  /// Cada número (3, 2, 1, 0) dura la cuarta parte de la cuenta.
  static const double _stepSeconds = PacManGame.countdownSeconds / 4;

  /// Color de cada paso (3, 2, 1, 0).
  static const List<Color> _colors = [
    Colors.cyanAccent,
    Colors.pinkAccent,
    Colors.yellowAccent,
    neonLime,
  ];

  /// Números ya maquetados (se crean la primera vez que se necesitan).
  final Map<int, TextPainter> _numbers = {};

  /// Mensajes inferiores ya maquetados.
  final Map<String, TextPainter> _captions = {};

  TextPainter _numberPainter(int number, Color color) {
    return _numbers.putIfAbsent(
      number,
      () => TextPainter(
        text: TextSpan(
          text: '$number',
          style: TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.w900,
            color: color,
            shadows: [
              Shadow(color: color.withAlpha(230), blurRadius: 24),
              Shadow(color: color.withAlpha(150), blurRadius: 48),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  TextPainter _captionPainter(String text) {
    return _captions.putIfAbsent(
      text,
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            color: Colors.white.withAlpha(220),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  @override
  void render(Canvas canvas) {
    final left = game.countdownLeft;
    if (left <= 0) return;

    final elapsed = PacManGame.countdownSeconds - left;
    final step = min(3, (elapsed / _stepSeconds).floor()); // 0..3
    final number = 3 - step;
    // Progreso (0 a 1) dentro del número actual.
    final p = ((elapsed - step * _stepSeconds) / _stepSeconds)
        .clamp(0.0, 1.0)
        .toDouble();
    final color = _colors[step];

    final mazeW = game.maxCols * game.tileSize;
    final mazeH = game.mazeGrid.length * game.tileSize;
    final cx = game.mazeOffsetX + mazeW / 2;
    final cy = 24 + mazeH / 2;

    // Velo oscuro sobre el laberinto para que el número destaque.
    canvas.drawRect(
      Rect.fromLTWH(game.mazeOffsetX, 24, mazeW, mazeH),
      Paint()..color = Colors.black.withAlpha(120),
    );

    // Anillo de energía que se expande y se desvanece.
    canvas.drawCircle(
      Offset(cx, cy),
      40 + 130 * Curves.easeOut.transform(p),
      Paint()
        ..color = color.withAlpha(((1 - p) * 200).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 + 6 * (1 - p),
    );

    // Número: entra con rebote (de 2x a 1x) y se desvanece en el último 25 %.
    final enter = Curves.easeOut.transform((p / 0.4).clamp(0.0, 1.0));
    final bounce = Curves.easeOutBack.transform((p / 0.4).clamp(0.0, 1.0));
    final scale = 2.0 - (enter * 0.4 + bounce * 0.6);
    final alpha = p < 0.75 ? 255 : ((1 - (p - 0.75) / 0.25) * 255).round();

    final fade = alpha < 255;
    if (fade) {
      canvas.saveLayer(
        Rect.fromCenter(center: Offset(cx, cy), width: 560, height: 320),
        Paint()..color = Colors.white.withAlpha(alpha),
      );
    }
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);
    final tp = _numberPainter(number, color);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
    if (fade) canvas.restore();

    // Mensaje inferior.
    final caption = _captionPainter(step < 3 ? '¡PREPÁRATE!' : '¡A JUGAR!');
    caption.paint(canvas, Offset(cx - caption.width / 2, cy + 95 - caption.height / 2));
  }
}
