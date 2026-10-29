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
/// Ciclo de [game.levelData.laserActive] activo +
/// [game.levelData.laserCooldown] de enfriamiento. Durante los últimos
/// [AbilityConfig.laserWarningSeconds] del enfriamiento se muestra una línea
/// punteada de aviso (sin peligro).
///
/// Mientras está ACTIVO, Pac-Man muere al instante si queda sobre la línea o
/// si la atraviesa entre dos frames (se revisa el recorrido completo de Pac-Man
/// en cada frame, así no se puede "saltar" el rayo por moverse rápido).
///
/// El rayo solo existe cuando ambos fantasmas están operativos (vivos, fuera
/// de la base y sin estar asustados). El ciclo se pausa durante Frightened.
///
/// Optimización: usa vectores y pinceles reutilizables, así que no crea objetos
/// nuevos en cada frame, y el texto del contador solo se vuelve a maquetar
/// cuando cambia (una vez por segundo).
class LaserLink extends PositionComponent with HasGameReference<PacManGame> {
  LaserLink() {
    priority = 50; // Se dibuja por encima de las demás entidades.
  }

  /// Duración total de un ciclo: activo + enfriamiento.
  double get _cycle =>
      game.levelData.laserActive + game.levelData.laserCooldown;

  /// Tiempo dentro del ciclo. Empieza al inicio del enfriamiento para dar
  /// margen al jugador al comenzar la partida.
  double _t = 0.0;

  /// Reloj que anima el brillo pulsante del rayo.
  double _pulse = 0.0;

  // Vectores reutilizables (se rellenan con setValues; así no se crean nuevos).
  final Vector2 _a = Vector2.zero(); // Centro de Kyros.
  final Vector2 _b = Vector2.zero(); // Centro de Pyros.
  final Vector2 _cur = Vector2.zero(); // Centro del jugador (este frame).
  final Vector2 _prev = Vector2.zero(); // Centro del jugador (frame anterior).
  bool _hasPrev = false;

  // Posición de los guardianes en el frame anterior (para detectar saltos).
  double _pax = 0.0;
  double _pay = 0.0;
  double _pbx = 0.0;
  double _pby = 0.0;
  bool _hasPrevGhosts = false;

  // Pinceles reutilizables.
  final Paint _haloPaint = Paint()
    ..strokeWidth = 7
    ..strokeCap = StrokeCap.round;
  final Paint _corePaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  final Paint _dashPaint = Paint()
    ..color = const Color(0x96FF5252)
    ..strokeWidth = 1.5;

  /// Estados del frame anterior (para sonar solo al CAMBIAR de estado).
  bool _wasWarning = false;
  bool _wasActive = false;

  /// Empieza al inicio del enfriamiento del nivel actual.
  @override
  Future<void> onLoad() async {
    super.onLoad();
    _t = game.levelData.laserActive;
  }

  /// `true` mientras el rayo está encendido y es mortal.
  bool get _isActive => _t < game.levelData.laserActive;
  /// `true` durante el aviso de la línea punteada (inofensiva).
  bool get _isWarning =>
      !_isActive && _t >= _cycle - AbilityConfig.laserWarningSeconds;

  /// Un fantasma puede sostener el rayo solo si existe, está vivo, ya salió de
  /// la base y no está asustado.
  bool _operational(Ghost? g) =>
      g != null &&
      g.isMounted &&
      !g.isDead &&
      !g.isLeavingSpawn &&
      !g.isScared &&
      !g.isIced;

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

    final player = game.player;
    final hasPac = player.isMounted;
    if (hasPac) {
      _cur.setValues(player.position.x + player.size.x / 2,
          player.position.y + player.size.y / 2);
    }
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

    // Posición de los dos guardianes. Si alguno "salta" de un extremo del mapa al
    // otro (túnel lateral o portal), el rayo cruzaría toda la pantalla durante
    // un frame; ese frame no cuenta como contacto.
    var ghostsJumped = false;
    if (bothReady) {
      final ax = kyros!.position.x + kyros.size.x / 2;
      final ay = kyros.position.y + kyros.size.y / 2;
      final bx = pyros!.position.x + pyros.size.x / 2;
      final by = pyros.position.y + pyros.size.y / 2;
      if (_hasPrevGhosts) {
        final da = (ax - _pax) * (ax - _pax) + (ay - _pay) * (ay - _pay);
        final db = (bx - _pbx) * (bx - _pbx) + (by - _pby) * (by - _pby);
        ghostsJumped = da > 576 || db > 576; // Más de 24 px en un frame.
      }
      _pax = ax;
      _pay = ay;
      _pbx = bx;
      _pby = by;
      _hasPrevGhosts = true;
      _a.setValues(ax, ay);
      _b.setValues(bx, by);
    } else {
      _hasPrevGhosts = false;
    }

    if (hasPac && activeNow && !ghostsJumped) {
      // Caso 1: el jugador está (casi) sobre la línea en este frame.
      final onBeam =
          distPointToSegment(_cur, _a, _b) <= AbilityConfig.laserHitRadius;
      // Caso 2: entre el frame anterior y este, el jugador atravesó el rayo
      // (ocurre con movimientos rápidos). Si Vance se teletransportó (túnel o
      // portal), su recorrido "salta" por toda la pantalla y NO es un cruce real.
      final jx = _cur.x - _prev.x;
      final jy = _cur.y - _prev.y;
      final jumped = jx * jx + jy * jy > 576; // Más de 24 px en un frame.
      final crossed =
          _hasPrev && !jumped && segmentsIntersect(_prev, _cur, _a, _b);

      if (onBeam || crossed) {
        game.playerDied(
          title: 'Te mataron Kyros y Pyros',
          detail: 'Te desintegró su láser cruzado que atraviesa paredes.',
          color: Colors.redAccent,
        );
      }
    }
    // Se guarda la posición actual para compararla en el siguiente frame.
    if (hasPac) _prev.setFrom(_cur);
    _hasPrev = hasPac;
  }

  /// Dibuja el contador del láser y, si corresponde, el rayo o su aviso.
  @override
  void render(Canvas canvas) {
    final kyros = game.ghosts[GhostType.kyros];
    final pyros = game.ghosts[GhostType.pyros];
    if (!_operational(kyros) || !_operational(pyros)) return;

    final ax = kyros!.position.x + kyros.size.x / 2;
    final ay = kyros.position.y + kyros.size.y / 2;
    final bx = pyros!.position.x + pyros.size.x / 2;
    final by = pyros.position.y + pyros.size.y / 2;

    if (_isActive) {
      // Valor que oscila entre 0 y 1 y modula la intensidad del halo rojo.
      final pulse = 0.5 + 0.5 * sin(_pulse * 14);
      // Rayo en dos capas: un halo rojo grueso y semitransparente, y encima un
      // núcleo blanco delgado que da el efecto de láser brillante.
      _haloPaint.color = Colors.redAccent.withAlpha((80 + 90 * pulse).round());
      canvas.drawLine(Offset(ax, ay), Offset(bx, by), _haloPaint);
      canvas.drawLine(Offset(ax, ay), Offset(bx, by), _corePaint);
    } else if (_isWarning) {
      // Línea punteada de aviso (inofensiva): trazos de 5 px cada 10 px.
      final dx = bx - ax;
      final dy = by - ay;
      final len = sqrt(dx * dx + dy * dy);
      if (len < 1) return;
      final ux = dx / len;
      final uy = dy / len;
      for (double d = 0; d < len; d += 10) {
        final e = min(d + 5, len);
        canvas.drawLine(Offset(ax + ux * d, ay + uy * d),
            Offset(ax + ux * e, ay + uy * e), _dashPaint);
      }
    }
  }
}
