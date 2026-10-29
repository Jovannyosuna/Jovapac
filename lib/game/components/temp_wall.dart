// =============================================================================
// game/components/temp_wall.dart
//
// Pared temporal de cera de abeja colocada por Vespakron (con su sonido).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:pacman_juego/audio/game_audio.dart';
import 'package:pacman_juego/config/game_config.dart';
import 'package:pacman_juego/game/pacman_game.dart';
import 'package:pacman_juego/game/utils/geometry.dart';

/// Pared temporal de cera de abeja colocada por Vespakron.
///
/// Ciclo de vida:
/// 1. **Aviso** ([AbilityConfig.builderWarningSeconds]): la cera se está
///    formando (translúcida, con contorno ámbar parpadeante) y suena un chapoteo
///    de cera. Todavía se puede cruzar.
/// 2. **Sólida** ([AbilityConfig.builderDurationSeconds]): bloquea a Pac-Man y
///    a los fantasmas. Suena un golpe sordo. Parpadea durante el último segundo.
/// 3. Se derrite (suena el burbujeo) y desaparece.
///
/// Si alguien está sobre la casilla (o entrando) cuando termina el aviso, la
/// pared espera un momento para no atrapar a nadie dentro.
///
/// Aspecto: un bloque de cera de abeja, con degradado de miel, panal de
/// hexágonos, brillo y gotas. Se dibuja UNA vez en una imagen y se reutiliza en
/// todas las paredes.
class TempWall extends PositionComponent with HasGameReference<PacManGame> {
  TempWall(this.col, this.row);

  /// Columna de la casilla que ocupa la pared.
  final int col;
  /// Fila de la casilla que ocupa la pared.
  final int row;

  /// `false` durante el aviso; `true` cuando ya bloquea el paso.
  bool _solid = false;
  /// Segundos transcurridos en la fase de aviso.
  double _warnTimer = 0.0;
  /// Segundos transcurridos en la fase sólida.
  double _solidTimer = 0.0;

  // --- Imagen de la cera (compartida por todas las paredes) ------------------
  static const double _bakeScale = 8.0;
  static ui.Image? _wax;
  static bool _waxTried = false;
  static final Rect _src = Rect.fromLTWH(0, 0, 24 * _bakeScale, 24 * _bakeScale);
  static final Rect _dst = Rect.fromLTWH(0, 0, 24, 24);
  static final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;
  static final Paint _outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final Paint _fallback = Paint()..color = const Color(0xFFFFB300);

  /// Hexágono (celda de panal) con centro ([cx], [cy]) y radio [r].
  static Path _hex(double cx, double cy, double r) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = pi / 180 * (60 * i - 30);
      final x = cx + r * cos(a);
      final y = cy + r * sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  /// Dibuja el bloque de cera de abeja en una imagen (una sola vez).
  static void _bakeWax() {
    _waxTried = true;
    try {
      const s = 24.0;
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      c.scale(_bakeScale);
      final tile = Rect.fromLTWH(0, 0, s, s);
      final body =
          RRect.fromRectAndRadius(tile.deflate(1), const Radius.circular(4));

      // Cera: degradado de miel clara a ámbar oscuro.
      c.drawRRect(
        body,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFE65100)],
            stops: [0.0, 0.55, 1.0],
          ).createShader(tile),
      );

      // Panal de abeja: hexágonos con borde marrón y relleno alterno.
      c.save();
      c.clipRRect(body);
      final cellFill = Paint()..color = Colors.white.withAlpha(36);
      final cellLine = Paint()
        ..color = const Color(0xFF8D4B00).withAlpha(175)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9;
      const r = 4.4;
      final w = r * sqrt(3);
      for (int row = -1; row < 8; row++) {
        final cy = row * r * 1.5 + 1.0;
        for (int col = -1; col < 6; col++) {
          final cx = col * w + (row.isOdd ? w / 2 : 0.0) + 0.6;
          final hex = _hex(cx, cy, r - 0.3);
          if ((row + col).isEven) c.drawPath(hex, cellFill);
          c.drawPath(hex, cellLine);
        }
      }
      c.restore();

      // Brillo de cera pulida en la esquina superior izquierda.
      c.drawPath(
        Path()
          ..moveTo(3.2, 9)
          ..quadraticBezierTo(3.2, 3.2, 9, 3.2)
          ..lineTo(15, 3.2),
        Paint()
          ..color = Colors.white.withAlpha(150)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );

      // Gotas de cera escurriendo por abajo.
      final drip = Paint()..color = const Color(0xFFFFC107);
      c.drawOval(Rect.fromLTWH(5.5, 20.2, 4.2, 3.4), drip);
      c.drawOval(Rect.fromLTWH(15, 21, 3.4, 2.8), drip);

      // Borde marrón.
      c.drawRRect(
        body,
        Paint()
          ..color = const Color(0xFF8D4B00)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      final picture = recorder.endRecording();
      _wax = picture.toImageSync(
          (s * _bakeScale).round(), (s * _bakeScale).round());
      picture.dispose();
    } catch (_) {
      _wax = null; // Se dibujará un bloque ámbar liso.
    }
  }

  /// Fija el tamaño (una casilla) y la posición en píxeles.
  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(game.tileSize, game.tileSize);
    position = Vector2(
      game.mazeOffsetX + col * game.tileSize,
      24 + row * game.tileSize,
    );
  }

  /// Avanza el ciclo de vida: aviso -> sólida -> se derrite.
  @override
  void update(double dt) {
    super.update(dt);
    if (game.isFrozen) return;

    if (!_solid) {
      // Fase 1: aviso. Todavía no bloquea el paso.
      _warnTimer += dt;
      if (_warnTimer >= AbilityConfig.builderWarningSeconds) {
        // Si alguien está en la casilla, se retrasa 0.3 s para no atrapar a nadie
        // dentro de la pared.
        if (game.isTileOccupied(col, row)) {
          _warnTimer = AbilityConfig.builderWarningSeconds - 0.3; // Espera
        } else {
          // Fase 2: se registra en solidWalls, lo que hace que isWalkable() devuelva
          // false para esta casilla.
          _solid = true;
          game.solidWalls.add(tileKey(col, row));
          GameAudio.sfx('sfx_wax_set.wav');
        }
      }
    } else {
      // Fase 3: pasado el tiempo de duración, la cera se derrite y desaparece.
      _solidTimer += dt;
      if (_solidTimer >= AbilityConfig.builderDurationSeconds) {
        GameAudio.sfx('sfx_wax_melt.wav');
        removeFromParent();
      }
    }
  }

  /// Al eliminarse libera la casilla en los registros del juego (también ocurre
  /// al reiniciar la partida).
  @override
  void onRemove() {
    final key = tileKey(col, row);
    game.solidWalls.remove(key);
    if (game.tempWalls[key] == this) {
      game.tempWalls.remove(key);
    }
    super.onRemove();
  }

  /// Dibuja la cera formándose (aviso) o el bloque de cera sólido.
  @override
  void render(Canvas canvas) {
    if (!_waxTried) _bakeWax();
    final wax = _wax;

    if (!_solid) {
      // La cera se está formando: translúcida, con contorno ámbar parpadeante.
      final blink = (_warnTimer * 6).floor().isEven;
      if (wax != null) {
        _imagePaint.color = Color.fromARGB(blink ? 150 : 85, 255, 255, 255);
        canvas.drawImageRect(wax, _src, _dst, _imagePaint);
      }
      _outline.color = Colors.amberAccent.withAlpha(blink ? 230 : 110);
      canvas.drawRect(_dst.deflate(2), _outline);
      return;
    }

    final left = AbilityConfig.builderDurationSeconds - _solidTimer;
    if (left < 1.0 && (left * 8).floor().isEven) return; // Se derrite parpadeando

    if (wax != null) {
      _imagePaint.color = const Color(0xFFFFFFFF);
      canvas.drawImageRect(wax, _src, _dst, _imagePaint);
    } else {
      canvas.drawRect(_dst, _fallback);
    }
  }
}
