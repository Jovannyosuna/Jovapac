// =============================================================================
// game/components/hud_panel.dart
//
// Botón de la habilidad de hielo (columna derecha) y nombre del nivel.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'package:pacman_juego/game/pacman_game.dart';
import 'package:pacman_juego/game/utils/ability_colors.dart';

/// Panel de información del juego:
/// - El botón redondo de la habilidad de hielo, en la columna derecha. Muestra
///   un anillo que se llena de verde a rojo conforme se carga, brilla cuando
///   está lista y se vacía en cian mientras dura el hielo. Se toca para usarla
///   (el toque lo detecta la pantalla de juego con [hitRadius]).
/// - Un destello cian en el laberinto en el instante de congelar.
/// - El nombre del nivel, abajo a la derecha del laberinto.
class HudPanel extends PositionComponent with HasGameReference<PacManGame> {
  HudPanel() {
    priority = 60;
  }

  /// Centro del botón en el lienzo virtual (columna derecha, bajo los corazones).
  static const double buttonX = 837.0;
  static const double buttonY = 262.0;

  /// Radio dibujado del botón y radio en el que se detecta el toque.
  static const double buttonRadius = 26.0;
  static const double hitRadius = 40.0;

  static final TextPainter _label = TextPainter(
    text: const TextSpan(
      text: 'HIELO',
      style: TextStyle(
        color: Colors.cyanAccent,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final Paint _bg = Paint()..color = const Color(0xB3120A3C);
  final Paint _track = Paint()
    ..color = const Color(0x33FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;
  final Paint _arc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  final Paint _glow = Paint();
  final Paint _icon = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..strokeCap = StrokeCap.round;
  final Paint _flash = Paint();

  int _shownLevel = 0;
  TextPainter? _levelPainter;

  @override
  void render(Canvas canvas) {
    final active = game.isFreezeActive;
    final ready = game.abilityReady && !active;
    final prog = active
        ? (game.freezeLeft / game.levelData.freezeSeconds)
            .clamp(0.0, 1.0)
            .toDouble()
        : game.abilityProgress;
    const center = Offset(buttonX, buttonY);

    // Destello cian al congelar (primeros 0.35 s).
    if (active) {
      final age = game.levelData.freezeSeconds - game.freezeLeft;
      if (age < 0.35) {
        _flash.color =
            Colors.cyanAccent.withAlpha(((1 - age / 0.35) * 90).round());
        canvas.drawRect(
          Rect.fromLTWH(game.mazeOffsetX, 24, game.maxCols * game.tileSize,
              game.mazeGrid.length * game.tileSize),
          _flash,
        );
      }
    }

    // Brillo pulsante cuando la habilidad está lista.
    if (ready) {
      final pulse = 0.5 + 0.5 * sin(game.fxClock * 6);
      _glow.color = const Color(0xFFF44336).withAlpha((50 + 90 * pulse).round());
      canvas.drawCircle(center, buttonRadius + 4 + 3 * pulse, _glow);
    }

    canvas.drawCircle(center, buttonRadius, _bg);
    final ringRect = Rect.fromCircle(center: center, radius: buttonRadius - 2);
    canvas.drawArc(ringRect, 0, 2 * pi, false, _track);
    _arc.color = active ? Colors.cyanAccent : chargeColor(prog);
    canvas.drawArc(ringRect, -pi / 2, 2 * pi * prog, false, _arc);

    // Copo de nieve: tres líneas cruzadas.
    _icon.color = (ready || active) ? Colors.white : Colors.white54;
    for (int i = 0; i < 3; i++) {
      final a = pi / 2 + i * pi / 3;
      final dx = cos(a) * 11;
      final dy = sin(a) * 11;
      canvas.drawLine(center + Offset(-dx, -dy), center + Offset(dx, dy), _icon);
    }

    _label.paint(
        canvas, Offset(buttonX - _label.width / 2, buttonY + buttonRadius + 6));

    // Nombre del nivel (abajo a la derecha del laberinto).
    final level = game.levelData;
    if (_shownLevel != level.number) {
      _shownLevel = level.number;
      _levelPainter?.dispose();
      _levelPainter = TextPainter(
        text: TextSpan(
          text: 'NIVEL ${level.number}: ${level.name}',
          style: TextStyle(
            color: level.wallBorder,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    final tp = _levelPainter!;
    tp.paint(canvas, Offset(774 - tp.width, 413));
  }
}
