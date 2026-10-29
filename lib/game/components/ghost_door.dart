// =============================================================================
// game/components/ghost_door.dart
//
// La puerta (línea delgada) de la casa de los guardianes.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:pacman_juego/game/pacman_game.dart';

/// La puerta de la casa de los guardianes: una línea rosa muy delgada en la
/// entrada (fila 6, columnas 12 a 14) que solo ellos pueden cruzar. En el
/// último nivel desaparece cuando se comen todas las rimoras y mydras.
class GhostDoor extends PositionComponent with HasGameReference<PacManGame> {
  GhostDoor() {
    priority = -2;
  }

  final Paint _paint = Paint()
    ..color = const Color(0xFFFFB3DD)
    ..strokeWidth = 1.4
    ..strokeCap = StrokeCap.round;

  @override
  void render(Canvas canvas) {
    if (game.houseOpen) return;
    final g = game;
    final y = 24 + 6 * g.tileSize + 1.0;
    final x0 = g.mazeOffsetX + 12 * g.tileSize + 1.5;
    final x1 = g.mazeOffsetX + 15 * g.tileSize - 1.5;
    canvas.drawLine(Offset(x0, y), Offset(x1, y), _paint);
  }
}
