// =============================================================================
// game/components/final_heart.dart
//
// El corazón de cristal final del nivel 5.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'package:pacman_juego/game/components/lives_display.dart';
import 'package:pacman_juego/game/pacman_game.dart';

/// El corazón de cristal que aparece en medio de la casa de los guardianes al
/// terminar de comer todo en el último nivel. Flota y brilla; al tomarlo (ver
/// [PacManGame.collectFinalHeart]) se termina la partida con victoria.
class FinalHeart extends PositionComponent with HasGameReference<PacManGame> {
  FinalHeart() {
    priority = -1;
  }

  double _t = 0.0;
  final Paint _glow = Paint();

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
  }

  @override
  void render(Canvas canvas) {
    final g = game;
    final cx = g.mazeOffsetX + PacManGame.heartCol * g.tileSize + g.tileSize / 2;
    final cy = 24 + PacManGame.heartRow * g.tileSize + g.tileSize / 2;
    final bob = sin(_t * 3) * 1.6;
    final pulse = 0.5 + 0.5 * sin(_t * 5);

    // Halo que pulsa.
    for (int i = 0; i < 3; i++) {
      _glow.color =
          const Color(0xFFFF4DA6).withAlpha((24 + 20 * pulse).round());
      canvas.drawCircle(Offset(cx, cy + bob), 16 + 3 * pulse - i * 4.0, _glow);
    }
    canvas.save();
    canvas.translate(cx, cy + bob);
    LivesDisplay.drawBakedHeart(canvas, 0.8 + 0.06 * pulse, 255);
    canvas.restore();
  }
}
