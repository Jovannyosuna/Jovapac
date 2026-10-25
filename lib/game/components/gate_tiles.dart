// =============================================================================
// game/components/gate_tiles.dart
//
// Compuertas de energía (niveles 3 y 5): barreras que se abren y se cierran.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'package:pacman_juego/game/pacman_game.dart';

/// Dibuja las compuertas de energía. Las de fase A son cian y las de fase B
/// naranja. Cerrada = barrera brillante que bloquea el paso; abierta = solo
/// unas esquinas tenues. Un segundo antes de cambiar de fase parpadean para
/// avisar. La lógica (quién bloquea) está en [PacManGame.isWalkable].
class GateTiles extends PositionComponent with HasGameReference<PacManGame> {
  GateTiles() {
    priority = -4; // Debajo de los personajes.
  }

  static const Color _colorA = Color(0xFF40E0FF);
  static const Color _colorB = Color(0xFFFF6E40);

  final Paint _fill = Paint();
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;

  void _drawGate(Canvas canvas, int key, Color color, bool open, bool warn) {
    final x = game.mazeOffsetX + (key % 100) * game.tileSize;
    final y = 24 + (key ~/ 100) * game.tileSize;
    final pulse = 0.5 + 0.5 * sin(game.fxClock * 9);
    final flicker = warn && (game.fxClock * 10).floor().isEven;

    if (open) {
      // Abierta: cuatro esquinitas tenues.
      _line.color = color.withAlpha(flicker ? 200 : 70);
      const a = 5.0;
      for (final dx in const [3.0, 21.0]) {
        for (final dy in const [3.0, 21.0]) {
          final sx = dx < 12 ? 1.0 : -1.0;
          final sy = dy < 12 ? 1.0 : -1.0;
          canvas.drawLine(
              Offset(x + dx, y + dy), Offset(x + dx + sx * a, y + dy), _line);
          canvas.drawLine(
              Offset(x + dx, y + dy), Offset(x + dx, y + dy + sy * a), _line);
        }
      }
      return;
    }

    // Cerrada: barrera de energía con tres barras brillantes.
    _fill.color = color.withAlpha(flicker ? 40 : (70 + 50 * pulse).round());
    canvas.drawRect(Rect.fromLTWH(x + 2, y + 2, 20, 20), _fill);
    _line.color = color.withAlpha(flicker ? 120 : (190 + 60 * pulse).round());
    for (final dy in const [6.0, 12.0, 18.0]) {
      canvas.drawLine(Offset(x + 2, y + dy), Offset(x + 22, y + dy), _line);
    }
    canvas.drawRect(Rect.fromLTWH(x + 2, y + 2, 20, 20), _line);
  }

  @override
  void render(Canvas canvas) {
    if (game.gateKeysA.isEmpty && game.gateKeysB.isEmpty) return;
    final warn = game.gateWarning;
    for (final key in game.gateKeysA) {
      _drawGate(canvas, key, _colorA, game.gateAOpen, warn);
    }
    for (final key in game.gateKeysB) {
      _drawGate(canvas, key, _colorB, !game.gateAOpen, warn);
    }
  }
}
