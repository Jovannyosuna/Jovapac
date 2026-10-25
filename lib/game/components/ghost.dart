// =============================================================================
// game/components/ghost.dart
//
// Entidad Fantasma: estados, movimiento, IA de intersecciones, aura de pánico y choque.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'package:pacman_juego/audio/game_audio.dart';
import 'package:pacman_juego/config/game_config.dart';
import 'package:pacman_juego/game/ai/ghost_mode.dart';
import 'package:pacman_juego/game/ai/ghost_personality.dart';
import 'package:pacman_juego/game/pacman_game.dart';
import 'package:pacman_juego/game/utils/game_sprite.dart';
import 'package:pacman_juego/game/utils/geometry.dart';

/// Enemigo del juego. Combina el estado individual del fantasma con el modo
/// global de [GhostModeController]:
///
/// 1. **Esperando / saliendo de la base** ([isLeavingSpawn]): espera su turno
///    de salida ([releaseDelay]) y sube hasta salir de la casa.
/// 2. **Normal**: en cada intersección elige la casilla vecina que minimiza la
///    distancia a su objetivo (Scatter o Chase según el modo global).
/// 3. **Asustado** ([isScared], sprite "niga"): elige direcciones al azar, va
///    más lento y puede ser comido.
/// 4. **Muerto** ([isDead], sprite "mori"): vuela en línea recta a la base y
///    vuelve a salir como fantasma normal.
///
/// Reglas de movimiento:
/// - Nunca da la vuelta en U, salvo cuando el modo global lo exige (cambio
///   Scatter/Chase o inicio de Frightened) o en un callejón sin salida.
/// - No puede volver a entrar a la casa de fantasmas mientras está vivo.
class Ghost extends PositionComponent with HasGameReference<PacManGame> {
  /// Crea un fantasma en [gridPos] del tipo [type]. [releaseDelay] son los
  /// segundos que espera dentro de la base antes de salir.
  Ghost(this.gridPos, this.type, {double releaseDelay = 0.0})
      : personality = GhostPersonality.of(type),
        _releaseTimer = releaseDelay;

  /// Personalidad de este fantasma.
  final GhostType type;

  /// Estrategia de objetivo asociada a [type].
  final GhostPersonality personality;

  /// Posición actual en coordenadas de la cuadrícula (columna, fila).
  Vector2 gridPos;

  /// Casilla de la base a la que regresan los fantasmas comidos.
  final Vector2 spawnGridPos = Vector2(13, 7);

  /// Dirección de movimiento actual.
  Vector2 moveDir = Vector2(0, -1);

  /// Avance hacia la siguiente casilla (0.0 a 1.0).
  double moveProgress = 0.0;

  /// Velocidad normal de un fantasma, en casillas por segundo.
  double get speed => GameSpeeds.tiles(game.levelData.ghostPercent);

  /// Velocidad actual en casillas por segundo, según el estado:
  /// - Asustado: velocidad muy reducida.
  /// - Shardox: sube con Cruise Elroy 1 y 2.
  /// - Dentro de un túnel lateral: se aplica [GameSpeeds.tunnelFactor]
  ///   (1.0 = sin cambio).
  double _currentSpeed() {
    double percent;
    if (isScared) {
      percent = GameSpeeds.ghostFrightened;
    } else if (type == GhostType.shardox) {
      switch (game.elroyLevel) {
        case 2:
          percent = max(GameSpeeds.elroy2, game.levelData.ghostPercent + 0.02);
          break;
        case 1:
          percent = max(GameSpeeds.elroy1, game.levelData.ghostPercent);
          break;
        default:
          percent = game.levelData.ghostPercent;
      }
    } else {
      percent = game.levelData.ghostPercent;
    }

    var tiles = GameSpeeds.tiles(percent);
    if (game.isInTunnel(gridPos, moveDir, moveProgress)) {
      tiles *= GameSpeeds.tunnelFactor;
    }
    return tiles;
  }

  /// Velocidad del mori al regresar a la base, en píxeles por segundo.
  final double moriSpeed = 140.0;

  /// Está asustado (el jugador comió un power-up).
  bool isScared = false;

  /// Fue comido y regresa a la base.
  bool isDead = false;

  /// Está esperando o saliendo de la casa de fantasmas.
  bool isLeavingSpawn = true;

  /// `true` mientras Vance lo tiene congelado: no se mueve ni hace daño.
  bool get isIced => game.isFreezeActive && !isDead;

  /// Segundos que faltan para que el fantasma salga de la base.
  double _releaseTimer;
  /// Cuenta regresiva para la próxima pared (solo Vespakron la usa).
  double _builderTimer = 0.0;
  /// Último valor de reversalTick que este fantasma ya atendió.
  int _seenReversalTick = 0;
  /// `true` cuando debe dar la vuelta en cuanto sea posible.
  bool _pendingReverse = false;

  /// Reloj (s) que anima el aura del estado de pánico.
  double _auraT = 0.0;

  /// Pincel reutilizable del aura (evita crear uno nuevo en cada frame).
  final Paint _auraPaint = Paint();

  /// Generador de azar para el modo asustado.
  final Random random = Random();

  /// Sprite en estado normal.
  GameSprite? ghostSprite;
  /// Sprite en estado asustado (la versión "niga" propia de este personaje).
  GameSprite? scaredSprite;
  /// Sprite del fantasma comido (mori.png).
  GameSprite? moriSprite;

  /// Orden de desempate clásico cuando dos casillas están a igual distancia:
  /// arriba, izquierda, abajo, derecha.
  static final List<Vector2> _tieBreakOrder = [
    Vector2(0, -1),
    Vector2(-1, 0),
    Vector2(0, 1),
    Vector2(1, 0),
  ];

  /// Obtiene un sprite de la caché; devuelve null si no está disponible.
  GameSprite? _tryLoad(String name) {
    try {
      return GameSprite(game.gameImage(name));
    } catch (_) {
      return null;
    }
  }

  /// Carga los sprites, se registra en el juego y fija tamaño y posición.
  @override
  Future<void> onLoad() async {
    super.onLoad();
    // Cada personaje usa SUS propios sprites. Si alguno falta, se dibuja un
    // cuadro de color al renderizar (no se reutiliza el sprite de otro).
    ghostSprite = _tryLoad(personality.spriteAsset);
    scaredSprite = _tryLoad(personality.scaredSpriteAsset);
    moriSprite = _tryLoad('mori.png');

    // Se sincroniza para no dar la vuelta por cambios de modo ocurridos antes de
    // que este fantasma existiera.
    _seenReversalTick = game.modeController.reversalTick;
    // Se registra por tipo para que las habilidades (imán, láser) lo encuentren
    // rápido.
    game.ghosts[type] = this;
    size = Vector2(20, 20);
    _builderTimer = game.levelData.builderFirstDelay;
    updatePixelPosition();
  }

  /// Convierte la posición de cuadrícula a píxeles y la aplica al componente.
  void updatePixelPosition() {
    position = Vector2(
      game.mazeOffsetX + gridPos.x * game.tileSize + 4,
      24 + gridPos.y * game.tileSize + 4,
    );
  }

  /// Se da de baja del registro de fantasmas del juego.
  @override
  void onRemove() {
    if (game.ghosts[type] == this) {
      game.ghosts.remove(type);
    }
    super.onRemove();
  }

  /// Dibuja el campo del imán (solo Shardox) y el cuerpo. Los fantasmas no
  /// muestran nombre ni número durante la partida.
  @override
  void render(Canvas canvas) {
    if (type == GhostType.shardox && game.magnetStrength > 0) {
      _renderMagnetField(canvas);
    }
    // Aura de pánico: resplandor y ondas detrás, chispas orbitando delante.
    final panicked = isScared && !isDead;
    if (panicked) _renderPanicAura(canvas);
    _renderBody(canvas);
    if (panicked) _renderPanicSparks(canvas);
    if (isIced) _renderIce(canvas);
  }

  /// Resplandor pulsante y dos ondas que se expanden alrededor del fantasma
  /// asustado, con el color de su personalidad.
  void _renderPanicAura(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final color = personality.color;
    final pulse = 0.5 + 0.5 * sin(_auraT * 7);

    // Resplandor suave: tres círculos concéntricos translúcidos (sin
    // desenfoque, que es muy pesado en celulares).
    _auraPaint.style = PaintingStyle.fill;
    for (int i = 0; i < 3; i++) {
      _auraPaint.color = color.withAlpha((28 + 22 * pulse).round());
      canvas.drawCircle(center, 15 + 2 * pulse - i * 3.5, _auraPaint);
    }
    // Dos ondas desfasadas que crecen y se desvanecen.
    _auraPaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (int i = 0; i < 2; i++) {
      final phase = (_auraT * 1.3 + i * 0.5) % 1.0;
      _auraPaint.color = color.withAlpha(((1 - phase) * 190).round());
      canvas.drawCircle(center, 9 + 11 * phase, _auraPaint);
    }
  }

  /// Cuatro chispas que giran alrededor del fantasma asustado, bordeándolo.
  void _renderPanicSparks(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final color = personality.color;
    for (int i = 0; i < 4; i++) {
      final angle = _auraT * 3.2 + i * pi / 2;
      final pos = center + Offset(cos(angle), sin(angle)) * 13.0;
      _auraPaint.style = PaintingStyle.fill;
      _auraPaint.color = color.withAlpha(110);
      canvas.drawCircle(pos, 3.2, _auraPaint);
      _auraPaint.color = Colors.white.withAlpha(230);
      canvas.drawCircle(pos, 1.8, _auraPaint);
    }
  }

  /// Aura roja de radio [AbilityConfig.magnetRadiusTiles] que se intensifica
  /// cuanto más cerca está Pac-Man.
  void _renderMagnetField(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final radius = AbilityConfig.magnetRadiusTiles * game.tileSize;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color =
            Colors.redAccent.withAlpha((25 + 60 * game.magnetStrength).round())
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.redAccent.withAlpha(130)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  /// Capa de hielo sobre el guardián congelado: bloque azul translúcido con
  /// borde blanco y destellos. Parpadea en el último segundo (se va a
  /// descongelar).
  void _renderIce(Canvas canvas) {
    final left = game.freezeLeft;
    if (left < 1.0 && (left * 8).floor().isEven) return;
    final block = RRect.fromRectAndRadius(
        const Rect.fromLTRB(-1, -1, 21, 21), const Radius.circular(5));
    _auraPaint
      ..style = PaintingStyle.fill
      ..color = const Color(0x7090E0FF);
    canvas.drawRRect(block, _auraPaint);
    _auraPaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xE6FFFFFF);
    canvas.drawRRect(block, _auraPaint);
    // Destellos de hielo.
    _auraPaint
      ..strokeWidth = 1.0
      ..color = const Color(0xCCFFFFFF);
    canvas.drawLine(const Offset(4, 3), const Offset(8, 7), _auraPaint);
    canvas.drawLine(const Offset(14, 13), const Offset(17, 17), _auraPaint);
    canvas.drawLine(const Offset(16, 3), const Offset(13, 6), _auraPaint);
  }

  /// Dibuja el cuerpo del fantasma según su estado actual.
  void _renderBody(Canvas canvas) {
    // 2) Prioridad de estados: muerto > saliendo de la base > normal/asustado.
    if (isDead) {
      if (moriSprite != null) {
        moriSprite!.drawBody(canvas);
      } else {
        canvas.drawRect(size.toRect(), Paint()..color = Colors.grey);
      }
      return;
    }

    if (isScared) {
      // En los últimos 2 segundos parpadea mostrando su aspecto normal.
      final left = game.modeController.frightenedTimeLeft;
      final blinkNormal = left < 2.0 && (left * 4).floor().isEven;
      if (!blinkNormal) {
        if (scaredSprite != null) {
          scaredSprite!.drawBody(canvas);
        } else {
          canvas.drawRect(size.toRect(), Paint()..color = Colors.blue);
        }
        return;
      }
    }

    if (ghostSprite != null) {
      ghostSprite!.drawBody(canvas);
    } else {
      canvas.drawRect(size.toRect(), Paint()..color = personality.color);
    }
  }

  /// Marca al fantasma como asustado. La inversión de dirección la dispara
  /// [GhostModeController.startFrightened].
  ///
  /// Afecta también a los fantasmas que aún están en la base. No tiene
  /// efecto si ya fue comido.
  void triggerPanic() {
    if (!isDead) {
      isScared = true;
    }
  }

  /// Máquina de estados de cada frame: muerto, saliendo de la base o
  /// recorriendo el laberinto (normal o asustado).
  @override
  void update(double dt) {
    super.update(dt);
    _auraT += dt;
    if (game.isFrozen) return;

    // 1) Se entera de si debe dar la vuelta.
    _syncReversal();
    if (isScared && !game.modeController.isFrightened) {
      isScared = false; // Terminó el modo Frightened.
    }

    if (isDead) {
      _pendingReverse = false;
      _updateDead(dt);
      return;
    }

    // Congelado por Vance: se queda quieto (si está asustado todavía se puede
    // comer).
    if (isIced) {
      if (!isLeavingSpawn) _checkPlayerCollision();
      return;
    }

    if (isLeavingSpawn) {
      _pendingReverse = false;
      _updateLeavingSpawn(dt);
      return;
    }

    // 3) Comportamiento normal por el laberinto.
    _updateRoaming(dt);
    _updateBuilder(dt);
    // 4) Colisión con el jugador: comerlo o ser comido.
    _checkPlayerCollision();
  }

  // ---------------------------------------------------------------------------
  // ESTADOS
  // ---------------------------------------------------------------------------

  /// Mori: vuela en línea recta a la base y revive como fantasma.
  void _updateDead(double dt) {
    final targetPx = Vector2(
      game.mazeOffsetX + spawnGridPos.x * game.tileSize + 4,
      24 + spawnGridPos.y * game.tileSize + 4,
    );
    // Vector hacia la base. El mori avanza en línea recta (ignora los muros).
    final toTarget = targetPx - position;
    final dist = toTarget.length;

    // Si llegaría en este frame, "aterriza" y revive como fantasma normal.
    if (dist <= moriSpeed * dt + 1) {
      isDead = false;
      isScared = false;
      isLeavingSpawn = true;
      _releaseTimer = 0.0; // Sale de inmediato.
      moveProgress = 0.0;
      moveDir = Vector2(0, -1);
      gridPos = spawnGridPos.clone();
      updatePixelPosition();
    } else {
      // toTarget / dist = dirección unitaria; x (velocidad * dt) = paso de este
      // frame.
      position = position + toTarget / dist * (moriSpeed * dt);
    }
  }

  /// Espera su turno de salida y sube hasta salir de la casa (fila 5).
  void _updateLeavingSpawn(double dt) {
    // Todavía en espera dentro de la base.
    if (_releaseTimer > 0) {
      _releaseTimer -= dt;
      return;
    }

    if (moveProgress == 0.0) {
      moveDir = Vector2(0, -1);
      if (!game.isWalkable(gridPos.x.toInt(), gridPos.y.toInt() - 1,
          isGhost: true)) {
        moveDir = Vector2(0, 1);
      }
    }

    final arrived = _advance(dt, speed);
    // La fila 5 es el pasillo justo fuera de la casa: al llegar ahí ya es un
    // fantasma normal.
    if (arrived && gridPos.y <= 5) {
      isLeavingSpawn = false;
    }
  }

  /// Movimiento normal por el laberinto con la IA de intersecciones.
  void _updateRoaming(double dt) {
    // Inversión obligatoria por cambio de modo global o power-up: se aplica
    // de inmediato, incluso a mitad de camino entre dos casillas.
    var justReversed = false;
    if (_pendingReverse) {
      _pendingReverse = false;
      justReversed = _reverseNow();
    }

    // Solo se decide al estar exactamente sobre una casilla.
    if (moveProgress == 0.0 && !justReversed) {
      moveDir = _decideDirection();
    }
    _advance(dt, _currentSpeed());
  }

  /// Da la vuelta en U de inmediato. Devuelve `true` si se aplicó.
  ///
  /// A mitad de camino se intercambian origen y destino, por lo que no hay
  /// saltos visuales. Si está justo sobre una casilla, simplemente invierte
  /// la dirección (si el camino de regreso está libre).
  bool _reverseNow() {
    if (moveProgress > 0.0) {
      // A mitad de camino: la posición lógica pasa a la casilla destino y se
      // invierte la dirección. El avance se espeja (1 - p), por eso no hay saltos
      // visuales.
      gridPos.add(moveDir);
      moveDir = -moveDir;
      moveProgress = 1.0 - moveProgress;
      return true;
    }
    final back = -moveDir;
    if (_canEnterTile(gridPos.x.toInt() + back.x.toInt(),
        gridPos.y.toInt() + back.y.toInt())) {
      moveDir = back;
      return true;
    }
    return false;
  }

  /// Habilidad del Fantasma Constructor (solo Vespakron): cada cierto tiempo, y
  /// solo en modo Chase, pide colocar una pared temporal detrás de Pac-Man.
  void _updateBuilder(double dt) {
    if (type != GhostType.vespakron) return;
    if (isScared || game.modeController.mode != GhostMode.chase) return;

    _builderTimer -= dt;
    if (_builderTimer > 0) return;

    // Si no hay una casilla válida, reintenta en un segundo.
    _builderTimer =
        game.tryPlaceBuilderWall() ? game.levelData.builderCooldown : 1.0;
  }

  /// Colisión con Pac-Man: asustado = muere (200/400/800/1600 pts); normal =
  /// fin de partida.
  void _checkPlayerCollision() {
    if (!game.player.isMounted) return;
    // Un guardián congelado (y no asustado) no hace daño.
    if (isIced && !isScared) return;
    // El choque cuenta solo cuando ya se encimó 1/6 de la silueta:
    // - Asustado: Vance se come al guardián cuando cubre 1/6 del guardián.
    // - Normal: el guardián atrapa a Vance cuando cubre 1/6 de Vance.
    final covered = isScared
        ? game.coverage(personality.spriteAsset, position, 'vance.png',
            game.player.position)
        : game.coverage('vance.png', game.player.position,
            personality.spriteAsset, position);
    if (covered >= kEatOverlapFraction) {
      if (isScared) {
        isDead = true;
        isScared = false;
        moveProgress = 0.0;
        // Comer un fantasma suma 200, 400, 800 o 1600 según la cadena.
        game.addScore(game.nextGhostEatScore());
        GameAudio.sfx('sfx_ghost_eaten.wav');
      } else {
        game.playerDied(
          title: 'Te mató ${personality.displayName}',
          detail: personality.deathDetail(game),
          color: personality.color,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // IA: TOMA DE DECISIONES EN INTERSECCIONES
  // ---------------------------------------------------------------------------

  /// Detecta si el controlador global pidió una inversión de dirección.
  void _syncReversal() {
    final tick = game.modeController.reversalTick;
    if (tick != _seenReversalTick) {
      _seenReversalTick = tick;
      _pendingReverse = true;
    }
  }

  /// Decide la próxima dirección desde la casilla actual.
  ///
  /// 1. (La inversión por cambio de modo se aplica antes, en [_updateRoaming].)
  /// 2. Reúne las casillas vecinas transitables, excluyendo retroceder.
  /// 3. Asustado: elige una al azar.
  /// 4. En otro caso: elige la que minimiza la distancia (al cuadrado) a la
  ///    casilla objetivo; los empates se resuelven por [_tieBreakOrder].
  /// 5. Si no hay salida (callejón), da la vuelta.
  Vector2 _decideDirection() {
    final col = gridPos.x.toInt();
    final row = gridPos.y.toInt();

    // 2) Opciones válidas (sin retroceder).
    final options = <Vector2>[];
    for (final dir in _tieBreakOrder) {
      // Regla clásica: un fantasma no puede retroceder.
      if (dir.x == -moveDir.x && dir.y == -moveDir.y) continue;
      if (_canEnterTile(col + dir.x.toInt(), row + dir.y.toInt())) {
        options.add(dir);
      }
    }

    // 5) Callejón sin salida.
    if (options.isEmpty) return -moveDir;
    if (options.length == 1) return options.first.clone();

    // 3) Asustado: aleatorio.
    if (isScared) {
      return options[random.nextInt(options.length)].clone();
    }

    // 4) Minimizar distancia al objetivo.
    final target = _currentTarget();
    Vector2 best = options.first;
    double bestDist = double.infinity;
    for (final dir in options) {
      // Distancia al cuadrado desde la casilla vecina hasta el objetivo. No se saca
      // raíz cuadrada: para comparar basta y es más rápido.
      final dx = (col + dir.x) - target.x;
      final dy = (row + dir.y) - target.y;
      final d = dx * dx + dy * dy;
      // "<" estricto: en un empate gana la primera dirección del orden de
      // desempate (arriba, izquierda, abajo, derecha).
      if (d < bestDist) {
        bestDist = d;
        best = dir;
      }
    }
    return best.clone();
  }

  /// Casilla objetivo según el modo global y la personalidad.
  Vector2 _currentTarget() {
    // Sin jugador en el árbol (por ejemplo, durante un reinicio) se usa la
    // esquina como valor seguro.
    if (!game.player.isMounted) return personality.scatterTarget;

    // Cruise Elroy: Shardox ignora el modo Scatter y sigue persiguiendo.
    final elroyHunting = kElroyIgnoresScatter &&
        type == GhostType.shardox &&
        game.elroyLevel > 0;

    if (game.modeController.baseMode == GhostMode.scatter && !elroyHunting) {
      return personality.scatterTarget;
    }
    return personality.chaseTarget(_buildContext());
  }

  /// Reúne los datos que necesitan las personalidades.
  GhostContext _buildContext() {
    // Valor por defecto por si Shardox aún no existe; se reemplaza al encontrarlo.
    final shardoxTile = game.ghosts[GhostType.shardox]?.gridPos ?? gridPos;
    return GhostContext(
      ghostTile: gridPos,
      pacTile: game.player.gridPos,
      pacDir: game.player.facing,
      shardoxTile: shardoxTile,
    );
  }

  /// Indica si un fantasma vivo puede entrar a la casilla ([col], [row]).
  ///
  /// Igual que [PacManGame.isWalkable], pero además le prohíbe volver a
  /// entrar a la casa de fantasmas (celdas con valor 2).
  bool _canEnterTile(int col, int row) {
    if (!game.isWalkable(col, row, isGhost: true)) return false;
    if (col < 0 || col >= game.maxCols) return true; // Túnel lateral.
    return game.mazeGrid[row][col] != 2;
  }

  // ---------------------------------------------------------------------------
  // MOVIMIENTO
  // ---------------------------------------------------------------------------

  /// Avanza interpolando hacia la siguiente casilla.
  /// Devuelve `true` si en este frame llegó a ella.
  bool _advance(double dt, double tilesPerSecond) {
    // Igual que en el jugador: casillas/segundo x segundos = fracción de casilla.
    moveProgress += tilesPerSecond * dt;

    final startX = game.mazeOffsetX + gridPos.x * game.tileSize + 4;
    final startY = 24 + gridPos.y * game.tileSize + 4;
    final endX = game.mazeOffsetX + (gridPos.x + moveDir.x) * game.tileSize + 4;
    final endY = 24 + (gridPos.y + moveDir.y) * game.tileSize + 4;
    // Se limita a 1.0 para no pasar de la casilla destino en el último frame.
    final t = min(moveProgress, 1.0);

    position.x = startX + (endX - startX) * t;
    position.y = startY + (endY - startY) * t;

    if (moveProgress >= 1.0) {
      gridPos.add(moveDir);
      moveProgress = 0.0;

      // Túnel lateral.
      if (gridPos.x < 0) {
        gridPos.x = (game.maxCols - 1).toDouble();
      } else if (gridPos.x >= game.maxCols) {
        gridPos.x = 0;
      }
      // Portal: si llegó a un portal, aparece en su pareja.
      final portalDest =
          game.portalLinks[tileKey(gridPos.x.toInt(), gridPos.y.toInt())];
      if (portalDest != null) {
        gridPos.x = (portalDest % 100).toDouble();
        gridPos.y = (portalDest ~/ 100).toDouble();
      }
      updatePixelPosition();
      return true;
    }
    return false;
  }
}
