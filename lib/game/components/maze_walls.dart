// =============================================================================
// game/components/maze_walls.dart
//
// Los muros del laberinto con el tema de cada nivel (dibujo vectorial, nítido con zoom).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:ui' as ui;
import 'package:pacman_juego/game/levels/level_data.dart';
import 'package:pacman_juego/game/pacman_game.dart';

/// Los muros del laberinto con un fondo en degradado, grabados UNA vez en un
/// `Picture` (lista de dibujo) y repetidos en cada frame.
///
/// Con la cámara ampliada, una imagen de pocos píxeles se vería borrosa; un
/// dibujo vectorial se ve nítido a cualquier zoom, y como la cámara solo muestra
/// una parte del mapa, el motor solo pinta lo visible. Cada muro es un bloque
/// con esquinas redondeadas: relleno oscuro, halo suave y borde nítido, con los
/// colores del nivel (`wallFill`, `wallHalo` y `wallBorder` de [LevelData]).
class MazeWalls extends PositionComponent with HasGameReference<PacManGame> {
  MazeWalls() {
    priority = -10; // Debajo de todo lo demás.
  }

  ui.Picture? _picture;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _bake();
  }

  /// Vuelve a grabar los muros con los colores del nivel actual (al cambiar de
  /// nivel).
  void rebuild() {
    if (!isLoaded) return; // Si aún no cargó, onLoad ya usará el nivel actual.
    _bake();
  }

  /// Graba el fondo y todos los muros.
  void _bake() {
    _picture?.dispose();
    final g = game;
    final data = g.levelData;
    final w = g.maxCols * g.tileSize;
    final h = g.mazeGrid.length * g.tileSize;

    final fill = Paint()..color = data.wallFill;
    final halo = Paint()
      ..color = data.wallHalo.withAlpha(70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final border = Paint()
      ..color = data.wallBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);

    // Fondo con degradado del nivel.
    c.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [data.bgTop, data.bgBottom],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    for (int row = 0; row < g.mazeGrid.length; row++) {
      for (int col = 0; col < g.mazeGrid[row].length; col++) {
        if (g.mazeGrid[row][col] != TileCode.wall) continue;
        final rect = Rect.fromLTWH(
            col * g.tileSize, row * g.tileSize, g.tileSize, g.tileSize);
        final rrect =
            RRect.fromRectAndRadius(rect.deflate(1.5), const Radius.circular(6));
        c.drawRRect(rrect, fill);
        c.drawRRect(rrect, halo);
        c.drawRRect(rrect, border);
      }
    }
    _picture = recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    final picture = _picture;
    if (picture == null) return;
    canvas.save();
    canvas.translate(game.mazeOffsetX, 24);
    canvas.drawPicture(picture);
    canvas.restore();
  }
}
