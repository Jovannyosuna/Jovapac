// =============================================================================
// game/components/rimora_field.dart
//
// Todas las rimoras y mydras del laberinto en un solo componente (un dibujo por lote).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:pacman_juego/game/pacman_game.dart';
import 'package:pacman_juego/game/utils/geometry.dart';

/// Un lote de sprites iguales (todas las rimoras, o todas las mydras) listo
/// para dibujarse con UNA sola llamada (`drawRawAtlas`).
///
/// Las posiciones se guardan en un arreglo de números que se arma una vez; al
/// comer una rimora solo se pone su escala en 0 (deja de verse). Así dibujar
/// las ~200 rimoras cuesta una llamada por frame y no crea ningún objeto.
class _Layer {
  _Layer(this.size);

  /// Lado (px) con que se dibuja cada sprite del lote.
  final double size;

  final List<int> cols = [];
  final List<int> rows = [];
  final List<double> xs = [];
  final List<double> ys = [];
  final List<bool> alive = [];

  ui.Image? image;
  Float32List? transforms;
  Float32List? rects;

  int add(int col, int row) {
    cols.add(col);
    rows.add(row);
    alive.add(true);
    return cols.length - 1;
  }

  /// Calcula la posición en pantalla (esquina superior izquierda) de cada uno.
  void layout(PacManGame g) {
    xs.clear();
    ys.clear();
    for (int i = 0; i < cols.length; i++) {
      xs.add(g.mazeOffsetX + cols[i] * g.tileSize + (g.tileSize - size) / 2);
      ys.add(24 + rows[i] * g.tileSize + (g.tileSize - size) / 2);
    }
  }

  /// Arma los arreglos del atlas con la imagen [img].
  void build(ui.Image img) {
    image = img;
    final n = cols.length;
    final t = Float32List(n * 4);
    final r = Float32List(n * 4);
    final scale = size / img.width;
    for (int i = 0; i < n; i++) {
      // RSTransform sin rotación: [escala, 0, x, y]. Escala 0 = oculto.
      t[i * 4] = alive[i] ? scale : 0.0;
      t[i * 4 + 1] = 0.0;
      t[i * 4 + 2] = xs[i];
      t[i * 4 + 3] = ys[i];
      // Región de origen: la imagen completa.
      r[i * 4] = 0.0;
      r[i * 4 + 1] = 0.0;
      r[i * 4 + 2] = img.width.toDouble();
      r[i * 4 + 3] = img.height.toDouble();
    }
    transforms = t;
    rects = r;
  }

  /// Oculta el sprite número [i] (ya fue comido).
  void hide(int i) {
    alive[i] = false;
    final t = transforms;
    if (t != null) t[i * 4] = 0.0;
  }
}

/// Dónde está lo que hay en una casilla: en qué lote y con qué número.
class _Slot {
  _Slot(this.isMydra, this.index);
  final bool isMydra;
  final int index;
}

/// Todas las rimoras y mydras que quedan en el laberinto, en UN solo
/// componente y con UN dibujo por lote.
///
/// - **Rimora** (`rimora.png`): el punto normal. Mide [rimoraSize] y otorga 10
///   puntos.
/// - **Mydra** (`mydra.png`): el punto grande (power-up). Mide [mydraSize]
///   (casi toda la casilla), otorga 100 puntos y asusta a los fantasmas. Si
///   `mydra.png` no existe, usa `rimora.png`.
///
/// Guarda las casillas en un mapa (clave = [tileKey]), así comer una es una
/// consulta instantánea.
class RimoraField extends PositionComponent with HasGameReference<PacManGame> {
  RimoraField() {
    priority = -5; // Debajo de los personajes.
  }

  /// Tamaño (px) de una rimora. Se ve en una casilla de 24 px.
  static const double rimoraSize = 9.0;

  /// Tamaño (px) de una mydra (casi toda la casilla, sin invadir las vecinas).
  static const double mydraSize = 20.0;

  final _Layer _rimoras = _Layer(rimoraSize);
  final _Layer _mydras = _Layer(mydraSize);

  /// Casillas con algo que comer: clave = tileKey.
  final Map<int, _Slot> _slots = {};

  final Paint _paint = Paint()..filterQuality = FilterQuality.low;
  final Paint _fallbackPaint = Paint()..color = Colors.white;

  /// Coloca una rimora (o mydra) en la casilla ([col], [row]).
  void addCell(int col, int row, bool isMydra) {
    final layer = isMydra ? _mydras : _rimoras;
    _slots[tileKey(col, row)] = _Slot(isMydra, layer.add(col, row));
  }

  /// Come lo que haya en la casilla: devuelve `null` si no había nada, `false`
  /// si era una rimora y `true` si era una mydra.
  bool? eatAt(int col, int row) {
    final slot = _slots.remove(tileKey(col, row));
    if (slot == null) return null;
    (slot.isMydra ? _mydras : _rimoras).hide(slot.index);
    return slot.isMydra;
  }

  /// Carga las imágenes y arma los lotes de dibujo.
  @override
  Future<void> onLoad() async {
    super.onLoad();
    _rimoras.layout(game);
    _mydras.layout(game);
    ui.Image? rimoraImage;
    ui.Image? mydraImage;
    try {
      rimoraImage = game.gameImage('rimora.png');
    } catch (_) {}
    try {
      mydraImage = game.gameImage('mydra.png');
    } catch (_) {
      mydraImage = rimoraImage; // Sin mydra.png se usa la rimora agrandada.
    }
    if (rimoraImage != null) _rimoras.build(rimoraImage);
    if (mydraImage != null) _mydras.build(mydraImage);
  }

  void _drawLayer(Canvas canvas, _Layer layer) {
    final image = layer.image;
    final t = layer.transforms;
    final r = layer.rects;
    if (image != null && t != null && r != null) {
      // Un solo dibujo para todo el lote.
      canvas.drawRawAtlas(image, t, r, null, null, null, _paint);
      return;
    }
    // Respaldo si falta la imagen: círculos blancos.
    for (int i = 0; i < layer.xs.length; i++) {
      if (!layer.alive[i]) continue;
      canvas.drawCircle(
        Offset(layer.xs[i] + layer.size / 2, layer.ys[i] + layer.size / 2),
        layer.size / 2,
        _fallbackPaint,
      );
    }
  }

  /// Dibuja todas las rimoras y mydras que quedan.
  @override
  void render(Canvas canvas) {
    _drawLayer(canvas, _rimoras);
    _drawLayer(canvas, _mydras);
  }
}
