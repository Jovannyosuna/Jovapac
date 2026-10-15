// =============================================================================
// game/components/rimora_field.dart
//
// Todas las rimoras y mydras del laberinto en un solo componente.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:ui' as ui;
import 'package:pacman_juego/game/pacman_game.dart';
import 'package:pacman_juego/game/utils/geometry.dart';

/// Todas las rimoras y mydras que quedan en el laberinto, en UN solo
/// componente (antes eran unos 200 componentes sueltos, y recorrerlos cada
/// frame era una de las causas de que el juego se trabara).
///
/// - **Rimora** (`rimora.png`): el punto normal. Mide [rimoraSize] y otorga 10
///   puntos.
/// - **Mydra** (`mydra.png`): el punto grande (power-up). Mide [mydraSize]
///   (casi toda la casilla), otorga 100 puntos y asusta a los fantasmas. Si
///   `mydra.png` no existe, usa `rimora.png`.
///
/// Guarda las casillas en un mapa (clave = [tileKey], valor = ¿es mydra?), así
/// comer una es una consulta instantánea.
class RimoraField extends PositionComponent with HasGameReference<PacManGame> {
  RimoraField() {
    priority = -5; // Debajo de los personajes.
  }

  /// Tamaño (px) de una rimora. Se ve en una casilla de 24 px.
  static const double rimoraSize = 12.0;

  /// Tamaño (px) de una mydra (casi toda la casilla, sin invadir las vecinas).
  static const double mydraSize = 20.0;

  /// Casillas con algo que comer: clave = tileKey, valor = `true` si es mydra.
  final Map<int, bool> _cells = {};

  ui.Image? _rimoraImage;
  ui.Image? _mydraImage;
  Rect _rimoraSrc = Rect.zero;
  Rect _mydraSrc = Rect.zero;
  final Paint _paint = Paint()..filterQuality = FilterQuality.low;
  final Paint _fallbackPaint = Paint()..color = Colors.white;

  /// Coloca una rimora (o mydra) en la casilla ([col], [row]).
  void addCell(int col, int row, bool isMydra) {
    _cells[tileKey(col, row)] = isMydra;
  }

  /// Come lo que haya en la casilla: devuelve `null` si no había nada, `false`
  /// si era una rimora y `true` si era una mydra.
  bool? eatAt(int col, int row) => _cells.remove(tileKey(col, row));

  /// Carga las imágenes (reducidas) de la rimora y la mydra.
  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      _rimoraImage = game.gameImage('rimora.png');
    } catch (_) {}
    try {
      _mydraImage = game.gameImage('mydra.png');
    } catch (_) {
      _mydraImage = _rimoraImage; // Sin mydra.png se usa la rimora agrandada.
    }
    final r = _rimoraImage;
    final m = _mydraImage;
    if (r != null) {
      _rimoraSrc = Rect.fromLTWH(0, 0, r.width.toDouble(), r.height.toDouble());
    }
    if (m != null) {
      _mydraSrc = Rect.fromLTWH(0, 0, m.width.toDouble(), m.height.toDouble());
    }
  }

  /// Dibuja todas las rimoras y mydras que quedan.
  @override
  void render(Canvas canvas) {
    final g = game;
    _cells.forEach((key, isMydra) {
      final col = key % 100;
      final row = key ~/ 100;
      final size = isMydra ? mydraSize : rimoraSize;
      final x = g.mazeOffsetX + col * g.tileSize + (g.tileSize - size) / 2;
      final y = 24 + row * g.tileSize + (g.tileSize - size) / 2;
      final image = isMydra ? _mydraImage : _rimoraImage;
      if (image != null) {
        canvas.drawImageRect(image, isMydra ? _mydraSrc : _rimoraSrc,
            Rect.fromLTWH(x, y, size, size), _paint);
      } else {
        canvas.drawCircle(Offset(x + size / 2, y + size / 2), size / 2, _fallbackPaint);
      }
    });
  }
}
