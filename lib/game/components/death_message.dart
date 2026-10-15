// =============================================================================
// game/components/death_message.dart
//
// Texto "quién te mató y cómo" al perder una vida.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'package:pacman_juego/game/pacman_game.dart';

/// Texto SIN cuadro que aparece en el centro del laberinto mientras Pac-Man
/// parpadea tras perder una vida: arriba quién fue y abajo cómo. Entra con un
/// fundido suave y sale antes de que empiece la cuenta regresiva. Un contorno
/// negro lo mantiene legible sobre el laberinto. Los textos se maquetan una
/// sola vez por muerte.
class DeathMessage extends PositionComponent with HasGameReference<PacManGame> {
  DeathMessage() {
    priority = 90; // Por encima del laberinto y las entidades.
  }

  /// Texto de la muerte para el que están maquetados los painters.
  String _key = '';
  List<TextPainter> _title = const [];
  List<TextPainter> _detail = const [];

  /// Crea los dos painters de un texto: contorno negro y relleno de color.
  List<TextPainter> _build(
      String text, double fontSize, Color color, double maxWidth) {
    TextPainter make(TextStyle style) => TextPainter(
          text: TextSpan(text: text, style: style),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxWidth);
    return [
      make(TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = fontSize * 0.18 + 1
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.black,
      )),
      make(TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: color,
        shadows: [Shadow(color: color.withAlpha(180), blurRadius: 16)],
      )),
    ];
  }

  void _paintCentered(Canvas canvas, List<TextPainter> painters, Offset center) {
    for (final tp in painters) {
      tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
    }
  }

  @override
  void render(Canvas canvas) {
    if (!game.isDying) return;

    final key = '${game.deathTitle}|${game.deathDetail}';
    if (key != _key) {
      _key = key;
      _title = _build(game.deathTitle.toUpperCase(), 30, game.deathColor, 600);
      _detail = _build(game.deathDetail, 16, Colors.white, 560);
    }

    final t = game.deathElapsed;
    final fadeIn = (t / 0.25).clamp(0.0, 1.0).toDouble();
    final fadeOut =
        ((PacManGame.deathBlinkSeconds - t) / 0.4).clamp(0.0, 1.0).toDouble();
    final alpha = (min(fadeIn, fadeOut) * 255).round();
    final rise = (1 - fadeIn) * 10; // Sube suavemente al aparecer.

    final mazeW = game.maxCols * game.tileSize;
    final mazeH = game.mazeGrid.length * game.tileSize;
    final cx = game.mazeOffsetX + mazeW / 2;
    final cy = 24 + mazeH / 2;

    // Todo el texto se desvanece junto con una sola capa.
    canvas.saveLayer(
      Rect.fromLTWH(game.mazeOffsetX, 24, mazeW, mazeH),
      Paint()..color = Colors.white.withAlpha(alpha),
    );
    _paintCentered(canvas, _title, Offset(cx, cy - 14 + rise));
    _paintCentered(canvas, _detail, Offset(cx, cy + 26 + rise));
    canvas.restore();
  }
}
