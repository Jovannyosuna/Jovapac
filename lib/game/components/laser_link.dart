// =============================================================================
// game/components/laser_link.dart
//
// Láser cruzado entre Kyros y Pyros.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'package:pacman_juego/audio/game_audio.dart';
import 'package:pacman_juego/config/game_config.dart';
import 'package:pacman_juego/game/ai/ghost_personality.dart';
import 'package:pacman_juego/game/components/ghost.dart';
import 'package:pacman_juego/game/pacman_game.dart';
import 'package:pacman_juego/game/utils/geometry.dart';

/// Rayo láser que une permanentemente a Kyros y Pyros.
///
/// Ciclo de [AbilityConfig.laserActiveSeconds] activo +
/// [AbilityConfig.laserCooldownSeconds] de enfriamiento. Durante los últimos
/// [AbilityConfig.laserWarningSeconds] del enfriamiento se muestra una línea
/// punteada de aviso (sin peligro).
///
/// Mientras está ACTIVO, Pac-Man muere al instante si queda sobre la línea o
/// si la atraviesa entre dos frames (se revisa el recorrido completo de Pac-Man
/// en cada frame, así no se puede "saltar" el rayo por moverse rápido).
///
/// El rayo solo existe cuando ambos fantasmas están operativos (vivos, fuera
/// de la base y sin estar asustados). El ciclo se pausa durante Frightened.
class LaserLink extends PositionComponent with HasGameReference<PacManGame> {
  LaserLink() {
    priority = 50; // Se dibuja por encima de las demás entidades.
  }

  /// Duración total de un ciclo: activo + enfriamiento.
  static const double _cycle =
      AbilityConfig.laserActiveSeconds + AbilityConfig.laserCooldownSeconds;

  /// Tiempo dentro del ciclo. Empieza al inicio del enfriamiento para dar
  /// margen al jugador al comenzar la partida.
  double _t = AbilityConfig.laserActiveSeconds;

  /// Reloj que anima el brillo pulsante del rayo.
  double _pulse = 0.0;
  /// Centro del jugador en el frame anterior; permite detectar si cruzó el rayo
  /// entre dos frames.
  Vector2? _prevPac;

  /// Estados del frame anterior (para sonar solo al CAMBIAR de estado).
  bool _wasWarning = false;
  bool _wasActive = false;

  /// Texto del contador, maquetado de nuevo solo cuando cambia.
  String _hudText = '';
  Color _hudColor = Colors.white;
  TextPainter? _hudPainter;

  /// `true` mientras el rayo está encendido y es mortal.
  bool get _isActive => _t < AbilityConfig.laserActiveSeconds;
  /// `true` durante el aviso de la línea punteada (inofensiva).
  bool get _isWarning =>
      !_isActive && _t >= _cycle - AbilityConfig.laserWarningSeconds;

  /// Un fantasma puede sostener el rayo solo si existe, está vivo, ya salió de
  /// la base y no está asustado.
  bool _operational(Ghost? g) =>
      g != null && g.isMounted && !g.isDead && !g.isLeavingSpawn && !g.isScared;

  /// Avanza el ciclo del láser y comprueba si alcanzó al jugador.
  @override
  void update(double dt) {
    super.update(dt);
    if (game.isFrozen) return;

    // El ciclo se pausa mientras los fantasmas están asustados.
    if (!game.modeController.isFrightened) {
      _t += dt;
      if (_t >= _cycle) _t -= _cycle;
    }
    _pulse += dt;

    final pac = game.player.isMounted ? centerOf(game.player) : null;
    final kyros = game.ghosts[GhostType.kyros];
    final pyros = game.ghosts[GhostType.pyros];

    // Sonidos del láser: aviso al empezar la carga y estallido al activarse.
    final bothReady = _operational(kyros) && _operational(pyros);
    final warningNow = _isWarning && bothReady;
    final activeNow = _isActive && bothReady;
    if (warningNow && !_wasWarning) GameAudio.sfx('sfx_laser_warn.wav');
    if (activeNow && !_wasActive) GameAudio.sfx('sfx_laser_on.wav');
    _wasWarning = warningNow;
    _wasActive = activeNow;

    if (pac != null && _isActive && _operational(kyros) && _operational(pyros)) {
      final a = centerOf(kyros!);
      final b = centerOf(pyros!);

      // Caso 1: el jugador está (casi) sobre la línea en este frame.
      final onBeam =
          distPointToSegment(pac, a, b) <= AbilityConfig.laserHitRadius;
      // Caso 2: entre el frame anterior y este, el jugador atravesó el rayo
      // (ocurre con movimientos rápidos).
      final crossed =
          _prevPac != null && segmentsIntersect(_prevPac!, pac, a, b);

      if (onBeam || crossed) {
        game.playerDied(
          title: 'Te mataron Kyros y Pyros',
          detail: 'Te desintegró su láser cruzado que atraviesa paredes.',
          color: Colors.redAccent,
        );
      }
    }
    // Se guarda la posición actual para compararla en el siguiente frame.
    _prevPac = pac;
  }

  /// Dibuja el contador del láser y, si corresponde, el rayo o su aviso.
  @override
  void render(Canvas canvas) {
    _renderHud(canvas);

    final kyros = game.ghosts[GhostType.kyros];
    final pyros = game.ghosts[GhostType.pyros];
    if (!_operational(kyros) || !_operational(pyros)) return;

    final a = centerOf(kyros!);
    final b = centerOf(pyros!);

    if (_isActive) {
      // Valor que oscila entre 0 y 1 y modula la intensidad del halo rojo.
      final pulse = 0.5 + 0.5 * sin(_pulse * 14);
      // Rayo en dos capas: un halo rojo grueso y semitransparente, y encima un
      // núcleo blanco delgado que da el efecto de láser brillante.
      canvas.drawLine(
        Offset(a.x, a.y),
        Offset(b.x, b.y),
        Paint()
          ..color = Colors.redAccent.withAlpha((80 + 90 * pulse).round())
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(a.x, a.y),
        Offset(b.x, b.y),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    } else if (_isWarning) {
      // Línea punteada de aviso (inofensiva).
      final dir = b - a;
      final len = dir.length;
      if (len < 1) return;
      final unit = dir / len;
      final paint = Paint()
        ..color = Colors.redAccent.withAlpha(150)
        ..strokeWidth = 1.5;
      // Trazos de 5 px cada 10 px: forman la línea punteada.
      for (double d = 0; d < len; d += 10) {
        final p1 = a + unit * d;
        final p2 = a + unit * min(d + 5, len);
        canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), paint);
      }
    }
  }

  /// Contador del láser, centrado en la parte superior.
  void _renderHud(Canvas canvas) {
    // Se elige el mensaje y el color según el estado del ciclo: pausa, activo,
    // cargando o enfriamiento.
    String text;
    Color color;
    if (game.modeController.isFrightened) {
      text = 'LÁSER: EN PAUSA';
      color = Colors.grey;
    } else if (_isActive) {
      final left = AbilityConfig.laserActiveSeconds - _t;
      text = 'LÁSER: ACTIVO ${left.toStringAsFixed(1)}s';
      color = Colors.redAccent;
    } else if (_isWarning) {
      text = 'LÁSER: ¡CARGANDO!';
      color = Colors.orangeAccent;
    } else {
      final left = _cycle - _t;
      text = 'LÁSER: LISTO EN ${left.toStringAsFixed(0)}s';
      color = Colors.cyanAccent;
    }

    // El texto se maqueta solo cuando cambia (no en cada frame).
    if (_hudPainter == null || text != _hudText || color != _hudColor) {
      _hudText = text;
      _hudColor = color;
      _hudPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }
    final tp = _hudPainter!;
    tp.paint(canvas, Offset(PacManGame.virtualWidth / 2 - tp.width / 2, 4));
  }
}
