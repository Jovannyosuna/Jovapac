// =============================================================================
// game/components/portal_tiles.dart
//
// Portales del laberinto: remolinos animados (niveles 2 y 5).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'package:pacman_juego/game/levels/level_data.dart';
import 'package:pacman_juego/game/pacman_game.dart';

/// Dibuja los portales del nivel actual como remolinos de energía que giran.
/// Los de la pareja A son cian y los de la pareja B son rosas, así se sabe cuál
/// lleva a cuál. La lógica del teletransporte está en Vance y en los guardianes
/// (usan [PacManGame.portalLinks]); este componente solo los dibuja.
class PortalTiles extends PositionComponent with HasGameReference<PacManGame> {
  PortalTiles() {
    priority = -3; // Debajo de los personajes.
  }

  final Paint _glow = Paint();
  final Paint _ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round;
  final Paint _core = Paint()..color = const Color(0xC8FFFFFF);

  @override
  void render(Canvas canvas) {
    final links = game.portalLinks;
    if (links.isEmpty) return;
    final t = game.fxClock;
    for (final key in links.keys) {
      final col = key % 100;
      final row = key ~/ 100;
      final code = game.mazeGrid[row][col];
      final color = (code == TileCode.portalA1 || code == TileCode.portalA2)
          ? Colors.cyanAccent
          : Colors.pinkAccent;
      final cx = game.mazeOffsetX + col * game.tileSize + game.tileSize / 2;
      final cy = 24 + row * game.tileSize + game.tileSize / 2;
      final pulse = 0.5 + 0.5 * sin(t * 4 + col);

      _glow.color = color.withAlpha((40 + 40 * pulse).round());
      canvas.drawCircle(Offset(cx, cy), 11 + 1.5 * pulse, _glow);
      for (int i = 0; i < 3; i++) {
        _ring.color = color.withAlpha(220 - i * 55);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: 9.0 - i * 2.6),
          t * (2.2 + i) * (i.isEven ? 1 : -1),
          4.0,
          false,
          _ring,
        );
      }
      canvas.drawCircle(Offset(cx, cy), 1.6, _core);
    }
  }
}
