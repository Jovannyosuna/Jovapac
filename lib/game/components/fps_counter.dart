// =============================================================================
// game/components/fps_counter.dart
//
// Contador de cuadros por segundo (solo para medir rendimiento).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:pacman_juego/game/pacman_game.dart';

/// Muestra los cuadros por segundo (FPS) y el peor cuadro de los últimos
/// 0.5 s, abajo a la izquierda de la pantalla. Se activa con `kShowFps = true`
/// en `config/game_config.dart`. Sirve para medir si el juego va fluido.
///
/// Referencia: 60 (o 90 / 120 según tu pantalla) = fluido. Si el "peor cuadro"
/// baja mucho, hay tirones aunque el promedio se vea bien.
class FpsCounter extends PositionComponent with HasGameReference<PacManGame> {
  FpsCounter() {
    priority = 200; // Por encima de todo.
  }

  double _time = 0.0;
  int _frames = 0;
  double _worstDt = 0.0;
  TextPainter? _painter;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    _frames++;
    if (dt > _worstDt) _worstDt = dt;
    if (_time >= 0.5) {
      final fps = (_frames / _time).round();
      final worst = _worstDt > 0 ? (1 / _worstDt).round() : 0;
      _painter?.dispose();
      _painter = TextPainter(
        text: TextSpan(
          text: 'FPS $fps   (peor cuadro: $worst)',
          style: const TextStyle(
              color: Colors.limeAccent,
              fontSize: 11,
              fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _time = 0.0;
      _frames = 0;
      _worstDt = 0.0;
    }
  }

  @override
  void render(Canvas canvas) {
    final painter = _painter;
    final size = game.size;
    if (painter == null || size.x <= 0) return;
    game.beginScreenSpace(canvas);
    painter.paint(canvas, Offset(10, size.y - painter.height - 6));
    game.endScreenSpace(canvas);
  }
}
