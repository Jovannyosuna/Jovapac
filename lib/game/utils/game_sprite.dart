// =============================================================================
// game/utils/game_sprite.dart
//
// Sprite ligero: dibuja una imagen ya reducida sin crear objetos en cada frame.
// =============================================================================

import 'package:flutter/material.dart';
import 'dart:ui' as ui;

/// Imagen de un personaje lista para dibujar a 20 x 20 px.
///
/// Reemplaza al `Sprite` de Flame en los personajes: `Sprite.render` crea
/// varios objetos (vectores y rectángulos) en CADA llamada, y con 5 personajes
/// dibujándose 60 veces por segundo eso es mucha basura para el recolector. Aquí
/// el rectángulo de origen se calcula una sola vez y el de destino es fijo.
class GameSprite {
  GameSprite(this.image)
      : src = Rect.fromLTWH(
            0, 0, image.width.toDouble(), image.height.toDouble());

  final ui.Image image;
  final Rect src;

  /// Lado (px) con que se dibujan los personajes.
  static const double bodySize = 20.0;

  static final Rect _body = Rect.fromLTWH(0, 0, bodySize, bodySize);
  static final Paint _paint = Paint()..filterQuality = FilterQuality.medium;

  /// Dibuja el sprite en el origen (0, 0), a [bodySize] x [bodySize].
  void drawBody(Canvas canvas) {
    canvas.drawImageRect(image, src, _body, _paint);
  }
}
