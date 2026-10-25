// =============================================================================
// game/components/maze_walls.dart
//
// Los muros del laberinto con el tema de cada nivel, dibujados como una sola imagen.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:ui' as ui;
import 'package:pacman_juego/game/levels/level_data.dart';
import 'package:pacman_juego/game/pacman_game.dart';

/// Los muros del laberinto, dibujados como UNA sola imagen.
///
/// Todos los muros (y un fondo con degradado) se dibujan una sola vez, al
/// cargar o al cambiar de nivel, en una imagen de alta resolución; en cada frame
/// solo se estampa esa imagen. Cada muro es un bloque con esquinas redondeadas:
/// relleno oscuro, halo suave y borde nítido, con los colores del nivel
/// (`wallFill`, `wallHalo` y `wallBorder` de [LevelData]).
class MazeWalls extends PositionComponent with HasGameReference<PacManGame> {
  MazeWalls() {
    priority = -10; // Debajo de todo lo demás.
  }

  /// Resolución de la imagen respecto al lienzo virtual (2 = el doble de nítida).
  static const double _res = 2.0;

  ui.Image? _image;
  ui.Picture? _picture; // Respaldo si no se puede crear la imagen.
  final Paint _paint = Paint()..filterQuality = FilterQuality.medium;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _bake();
  }

  /// Vuelve a dibujar los muros con los colores del nivel actual (al cambiar de
  /// nivel).
  void rebuild() {
    if (!isLoaded) return; // Si aún no cargó, onLoad ya usará el nivel actual.
    _bake();
  }

  /// Dibuja el fondo y todos los muros en una imagen.
  void _bake() {
    _image?.dispose();
    _image = null;
    _picture?.dispose();
    _picture = null;

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
    c.scale(_res);

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
