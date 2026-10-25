// =============================================================================
// game/components/fog_of_war.dart
//
// Niebla (niveles 4 y 5): solo se ve lo que está cerca de Vance.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:ui' as ui;
import 'package:pacman_juego/game/pacman_game.dart';

/// Oscurece el laberinto salvo un círculo alrededor de Vance. El radio sale del
/// nivel (`LevelData.fogTiles`); en los niveles sin niebla no dibuja nada.
///
/// Se dibuja con UN degradado radial (el pincel se crea una sola vez; solo se
/// mueve el lienzo), así que casi no cuesta rendimiento.
class FogOfWar extends PositionComponent with HasGameReference<PacManGame> {
  FogOfWar() {
    priority = 80; // Sobre los personajes, bajo los textos de la cuenta/muerte.
  }

  Paint? _paint;
  double _radius = 0.0;

  @override
  void render(Canvas canvas) {
    final tiles = game.levelData.fogTiles;
    if (tiles <= 0) return;
    final player = game.player;
    if (!player.isMounted) return;

    final radius = tiles * game.tileSize;
    if (_paint == null || radius != _radius) {
      _radius = radius;
      _paint = Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          radius,
          const [Color(0x00000000), Color(0x73000000), Color(0xF0000000)],
          const [0.0, 0.6, 1.0],
        );
    }

    final cx = player.position.x + player.size.x / 2;
    final cy = player.position.y + player.size.y / 2;
    final mazeW = game.maxCols * game.tileSize;
    final mazeH = game.mazeGrid.length * game.tileSize;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(game.mazeOffsetX, 24, mazeW, mazeH));
    canvas.translate(cx, cy);
    canvas.drawRect(
        Rect.fromLTWH(game.mazeOffsetX - cx, 24 - cy, mazeW, mazeH), _paint!);
    canvas.restore();
  }
}
