// =============================================================================
// game/components/hud_panel.dart
//
// Marcadores, botón cryo, nombre del nivel y avisos (se dibujan sobre la pantalla).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'package:pacman_juego/game/pacman_game.dart';
import 'package:pacman_juego/game/utils/ability_colors.dart';

/// Texto de un marcador. El juego solo cambia [text]; [HudPanel] lo dibuja.
class HudLabel {
  HudLabel(this.text);
  String text;
}

/// Un texto ya maquetado que se vuelve a maquetar solo cuando cambia el texto
/// o el tamaño de la interfaz.
class _CachedText {
  String _text = '';
  double _u = 0.0;
  TextPainter? _painter;

  TextPainter get(String text, double u, TextStyle Function(double u) style) {
    if (_painter == null || text != _text || u != _u) {
      _text = text;
      _u = u;
      _painter?.dispose();
      _painter = TextPainter(
        text: TextSpan(text: text, style: style(u)),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    return _painter!;
  }
}

/// Interfaz que se dibuja SOBRE la pantalla (no sigue a la cámara):
/// - Puntuación (arriba a la izquierda) y récord (arriba a la derecha).
/// - El botón **cryo** (a la derecha): un anillo que se llena de verde a rojo
///   conforme se carga, brilla cuando está lista y se vacía en cian mientras
///   dura el hielo. Se toca para usarla (el toque lo detecta la pantalla de
///   juego con [hitRadius]).
/// - El nombre del nivel (abajo a la derecha).
/// - Un destello cian al congelar y avisos de texto (por ejemplo, la puerta de
///   la casa de los guardianes).
///
/// Todo se calcula con el tamaño real de la pantalla ([scaleFor]).
class HudPanel extends PositionComponent with HasGameReference<PacManGame> {
  HudPanel() {
    priority = 150; // Sobre el mundo y los avisos de pantalla.
  }

  /// Factor de tamaño de la interfaz según el alto de la pantalla.
  static double scaleFor(Vector2 size) =>
      (size.y / 400).clamp(0.8, 1.8).toDouble();

  /// Centro del botón cryo en pantalla.
  static Offset buttonCenter(Vector2 size) {
    final u = scaleFor(size);
    return Offset(size.x - 92 * u, size.y * 0.74);
  }

  /// Radio dibujado del botón y radio en el que se detecta el toque.
  static double buttonRadius(Vector2 size) => 28 * scaleFor(size);
  static double hitRadius(Vector2 size) => 46 * scaleFor(size);

  final _CachedText _score = _CachedText();
  final _CachedText _high = _CachedText();
  final _CachedText _level = _CachedText();
  final _CachedText _cryo = _CachedText();
  final _CachedText _hint = _CachedText();

  final Paint _bg = Paint()..color = const Color(0xB3120A3C);
  final Paint _track = Paint()
    ..color = const Color(0x33FFFFFF)
    ..style = PaintingStyle.stroke;
  final Paint _arc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _glow = Paint();
  final Paint _icon = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _flash = Paint();

  static const List<Shadow> _shadow = [
    Shadow(color: Color(0xCC000000), offset: Offset(1, 1), blurRadius: 0)
  ];

  @override
  void render(Canvas canvas) {
    final size = game.size;
    if (size.x <= 0 || size.y <= 0) return;
    final u = scaleFor(size);
    game.beginScreenSpace(canvas);

    // Destello cian al congelar (primeros 0.35 s).
    if (game.isFreezeActive) {
      final age = game.levelData.freezeSeconds - game.freezeLeft;
      if (age < 0.35) {
        _flash.color =
            Colors.cyanAccent.withAlpha(((1 - age / 0.35) * 90).round());
        canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), _flash);
      }
    }

    // Puntuación (izquierda) y récord (derecha).
    final score = _score.get(
        game.scoreText.text,
        u,
        (u) => TextStyle(
              color: Colors.cyanAccent,
              fontSize: 14 * u,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              shadows: _shadow,
            ));
    score.paint(canvas, Offset(10 * u, 6 * u));
    final high = _high.get(
        game.highScoreText.text,
        u,
        (u) => TextStyle(
              color: Colors.pinkAccent,
              fontSize: 14 * u,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              shadows: _shadow,
            ));
    high.paint(canvas, Offset(size.x - 40 * u - high.width, 6 * u));

    // Nombre del nivel (abajo a la derecha).
    final data = game.levelData;
    final level = _level.get(
        'NIVEL ${data.number}: ${data.name}',
        u,
        (u) => TextStyle(
              color: data.wallBorder,
              fontSize: 12 * u,
              fontWeight: FontWeight.bold,
              shadows: _shadow,
            ));
    level.paint(canvas, Offset(size.x - 10 * u - level.width, size.y - 6 * u - level.height));

    _renderCryo(canvas, size, u);
    _renderHint(canvas, size, u);
    game.endScreenSpace(canvas);
  }

  /// El botón cryo: anillo de carga, copo de nieve y nombre.
  void _renderCryo(Canvas canvas, Vector2 size, double u) {
    final active = game.isFreezeActive;
    final ready = game.abilityReady && !active;
    final prog = active
        ? (game.freezeLeft / game.levelData.freezeSeconds)
            .clamp(0.0, 1.0)
            .toDouble()
        : game.abilityProgress;
    final c = buttonCenter(size);
    final r = buttonRadius(size);

    if (ready) {
      final pulse = 0.5 + 0.5 * sin(game.fxClock * 6);
      _glow.color = const Color(0xFFF44336).withAlpha((50 + 90 * pulse).round());
      canvas.drawCircle(c, r + (4 + 3 * pulse) * u, _glow);
    }
    canvas.drawCircle(c, r, _bg);
    final ring = Rect.fromCircle(center: c, radius: r - 3 * u);
    _track.strokeWidth = 4 * u;
    _arc
      ..strokeWidth = 4 * u
      ..color = active ? Colors.cyanAccent : chargeColor(prog);
    canvas.drawArc(ring, 0, 2 * pi, false, _track);
    canvas.drawArc(ring, -pi / 2, 2 * pi * prog, false, _arc);

    // Copo de nieve: tres líneas cruzadas.
    _icon
      ..strokeWidth = 1.8 * u
      ..color = (ready || active) ? Colors.white : Colors.white54;
    for (int i = 0; i < 3; i++) {
      final a = pi / 2 + i * pi / 3;
      final d = Offset(cos(a), sin(a)) * (r * 0.42);
      canvas.drawLine(c - d, c + d, _icon);
    }

    final label = _cryo.get(
        'cryo',
        u,
        (u) => TextStyle(
              color: Colors.cyanAccent,
              fontSize: 19 * u,
              fontWeight: FontWeight.w900,
              shadows: _shadow,
            ));
    label.paint(canvas, Offset(c.dx - label.width / 2, c.dy + r + 2 * u));
  }

  /// Aviso de texto temporal, arriba y al centro (con fundido).
  void _renderHint(Canvas canvas, Vector2 size, double u) {
    if (game.hintLeft <= 0 || game.hintText.isEmpty) return;
    final alpha = (game.hintLeft.clamp(0.0, 0.6) / 0.6 * 255).round();
    final tp = _hint.get(
        game.hintText,
        u,
        (u) => TextStyle(
              color: Colors.white,
              fontSize: 17 * u,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              shadows: const [
                Shadow(color: Color(0xFF000000), offset: Offset(1.5, 1.5)),
                Shadow(color: Color(0xFFFF4DA6), blurRadius: 10),
              ],
            ));
    canvas.saveLayer(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = Colors.white.withAlpha(alpha),
    );
    tp.paint(canvas, Offset((size.x - tp.width) / 2, size.y * 0.14));
    canvas.restore();
  }
}
