// =============================================================================
// game/components/maze_walls.dart
//
// Los muros del laberinto, dibujados como una sola imagen.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:ui' as ui;
import 'package:pacman_juego/game/pacman_game.dart';

/// Los muros del laberinto, dibujados como UNA sola imagen.
///
/// Antes cada muro era un componente que pintaba 3 rectángulos redondeados en
/// cada frame (más de 450 dibujos por frame). Ahora todos los muros se dibujan
/// una sola vez, al cargar, en una imagen de alta resolución; en cada frame solo
/// se estampa esa imagen. Cada muro es un bloque neón violeta con esquinas
/// redondeadas: relleno oscuro, halo suave y borde nítido.
class MazeWalls extends PositionComponent with HasGameReference<PacManGame> {
  MazeWalls() {
    priority = -10; // Debajo de todo lo demás.
  }

  /// Resolución de la imagen respecto al lienzo virtual (2 = el doble de nítida).
  static const double _res = 2.0;

  ui.Image? _image;
  ui.Picture? _picture; // Respaldo si no se puede crear la imagen.
  final Paint _paint = Paint()..filterQuality = FilterQuality.medium;

  /// Dibuja todos los muros en una imagen.
  @override
  Future<void> onLoad() async {
    super.onLoad();
    final g = game;
    final w = g.maxCols * g.tileSize;
    final h = g.mazeGrid.length * g.tileSize;

    final fill = Paint()..color = const Color(0xFF120A3C);
    final halo = Paint()
      ..color = const Color(0xFF8B5CFF).withAlpha(70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final border = Paint()
      ..color = const Color(0xFF8B5CFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    c.scale(_res);
    for (int row = 0; row < g.mazeGrid.length; row++) {
      for (int col = 0; col < g.mazeGrid[row].length; col++) {
        if (g.mazeGrid[row][col] != 1) continue;
        final rect = Rect.fromLTWH(
            col * g.tileSize, row * g.tileSize, g.tileSize, g.tileSize);
        final rrect =
            RRect.fromRectAndRadius(rect.deflate(1.5), const Radius.circular(6));
        c.drawRRect(rrect, fill);
        c.drawRRect(rrect, halo);
        c.drawRRect(rrect, border);
      }
    }
    final picture = recorder.endRecording();
    try {
      _image = picture.toImageSync((w * _res).ceil(), (h * _res).ceil());
      picture.dispose();
    } catch (_) {
      _picture = picture; // Si no se puede, se reproduce el dibujo cada frame.
    }
  }

  @override
  void render(Canvas canvas) {
    final g = game;
    canvas.save();
    canvas.translate(g.mazeOffsetX, 24);
    final image = _image;
    if (image != null) {
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(
            0, 0, g.maxCols * g.tileSize, g.mazeGrid.length * g.tileSize),
        _paint,
      );
    } else if (_picture != null) {
      canvas.scale(1 / _res);
      canvas.drawPicture(_picture!);
    }
    canvas.restore();
  }
}
