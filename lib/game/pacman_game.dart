// =============================================================================
// game/pacman_game.dart
//
// Núcleo del juego (PacManGame): estado, vidas, puntuación, entrada, siluetas de choque y sonido.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:pacman_juego/audio/game_audio.dart';
import 'package:pacman_juego/config/game_config.dart';
import 'package:pacman_juego/data/player_profile.dart';
import 'package:pacman_juego/game/ai/ghost_mode.dart';
import 'package:pacman_juego/game/ai/ghost_personality.dart';
import 'package:pacman_juego/game/components/countdown_overlay.dart';
import 'package:pacman_juego/game/components/death_message.dart';
import 'package:pacman_juego/game/components/final_heart.dart';
import 'package:pacman_juego/game/components/fog_of_war.dart';
import 'package:pacman_juego/game/components/ghost_door.dart';
import 'package:pacman_juego/game/components/fps_counter.dart';
import 'package:pacman_juego/game/components/gate_tiles.dart';
import 'package:pacman_juego/game/components/hud_panel.dart';
import 'package:pacman_juego/game/components/portal_tiles.dart';
import 'package:pacman_juego/game/levels/level_data.dart';
import 'package:pacman_juego/game/components/ghost.dart';
import 'package:pacman_juego/game/components/laser_link.dart';
import 'package:pacman_juego/game/components/lives_display.dart';
import 'package:pacman_juego/game/components/maze_walls.dart';
import 'package:pacman_juego/game/components/player_pacman.dart';
import 'package:pacman_juego/game/components/rimora_field.dart';
import 'package:pacman_juego/game/components/temp_wall.dart';
import 'package:pacman_juego/game/utils/geometry.dart';

/// Motor principal del juego.
///
/// Administra el laberinto, la puntuación, el estado de la partida (en curso,
/// perdida o ganada), el escalado a cualquier tamaño de pantalla y la entrada
/// por teclado.
class PacManGame extends FlameGame with KeyboardEvents {
  /// Nivel con el que empieza la partida (al reiniciar se vuelve a este).
  final int startLevel;

  PacManGame({this.startLevel = 1}) {
    level = max(1, min(startLevel, kLevels.length));
    _loadLevelGrid();
  }

  /// Nivel actual (1 a [kLevels].length).
  int level = 1;

  /// Datos del nivel actual (mapa, colores, dificultad, mecánicas).
  LevelData get levelData => kLevels[level - 1];

  /// Reloj general (s) que anima portales, compuertas y brillos.
  double fxClock = 0.0;

  /// Los muros del laberinto (se redibujan al cambiar de nivel).
  late MazeWalls mazeWalls;

  // --- Mecánicas especiales de los niveles ------------------------------------

  /// Portales: casilla de entrada -> casilla de salida (ambas como tileKey).
  final Map<int, int> portalLinks = {};

  /// Casillas (tileKey) de las compuertas de fase A y de fase B.
  final List<int> gateKeysA = [];
  final List<int> gateKeysB = [];

  /// `true` = fase A (las compuertas A están abiertas y las B cerradas).
  bool gateAOpen = true;

  /// `true` durante el último segundo antes de cambiar de fase.
  bool gateWarning = false;

  double _gateTimer = 0.0;

  // --- Habilidad de hielo -------------------------------------------------------

  /// Puntos acumulados hacia el próximo uso (0 a [kAbilityCostPoints]).
  double abilityCharge = 0.0;

  /// Segundos que le quedan al hielo (0 = no hay hielo activo).
  double freezeLeft = 0.0;

  /// Avance de la carga (0.0 a 1.0).
  double get abilityProgress =>
      (abilityCharge / kAbilityCostPoints).clamp(0.0, 1.0).toDouble();

  /// `true` cuando la habilidad está cargada y se puede usar.
  bool get abilityReady => abilityCharge >= kAbilityCostPoints;

  /// `true` mientras los guardianes están congelados.
  bool get isFreezeActive => freezeLeft > 0;

  /// `true` mientras se muestra el menú de "nivel completado".
  bool levelComplete = false;

  /// `true` para mostrar el letrero del nivel durante la cuenta regresiva (al
  /// empezar un nivel, no al reaparecer tras perder una vida).
  bool showLevelBanner = true;
  /// Jugador actual. Se vuelve a crear cada vez que inicia una partida.
  late PlayerPacman player;

  /// Puntuación de la partida en curso.
  int score = 0;

  /// Mejor puntuación obtenida mientras la app está abierta.
  int highScore = 0;

  /// Indica que el jugador fue atrapado por un fantasma.
  bool isGameOver = false;

  /// Indica que el jugador comió todos los puntos.
  bool isGameWon = false;

  // ---------------------------------------------------------------------------
  // VIDAS, MUERTE Y CUENTA REGRESIVA
  // ---------------------------------------------------------------------------

  /// Vidas con las que empieza cada partida.
  static const int maxLives = 3;

  /// Segundos que parpadea Pac-Man al perder una vida.
  static const double deathBlinkSeconds = 3.0;

  /// Duración de la cuenta regresiva (3, 2, 1, 0) al empezar o reanudar.
  static const double countdownSeconds = 3.0;

  /// Vidas que le quedan al jugador.
  int lives = maxLives;

  /// `true` mientras Pac-Man parpadea tras perder una vida.
  bool isDying = false;

  /// Segundos transcurridos desde que murió (los usa el parpadeo).
  double deathElapsed = 0.0;

  /// Segundos que faltan de la cuenta regresiva (0 = no hay cuenta).
  double countdownLeft = 0.0;

  /// `true` mientras se muestra la cuenta regresiva.
  bool get isCountingDown => countdownLeft > 0;

  /// `true` cuando las entidades deben quedarse quietas: partida terminada,
  /// animación de muerte o cuenta regresiva.
  bool get isFrozen =>
      isGameOver || isGameWon || isDying || isCountingDown || levelComplete;

  /// `true` si en esta partida se superó el récord guardado en el perfil.
  bool newRecord = false;

  /// Texto "quién te mató" (título), "cómo" (detalle) y su color. Se muestran
  /// sin cuadro mientras Pac-Man parpadea.
  String deathTitle = '';
  String deathDetail = '';
  Color deathColor = Colors.redAccent;

  /// Último número de la cuenta regresiva que ya sonó (-1 = ninguno).
  int _lastCountStep = -1;

  /// `true` mientras la música de fondo debe estar sonando.
  bool _musicOn = false;

  /// Estado Frightened del frame anterior (para cambiar la música).
  bool _wasFrightened = false;

  /// Segundos desde el último autoguardado del récord.
  double _autosave = 0.0;

  /// Segundos desde la última revisión de que la música siga sonando.
  double _musicCheck = 0.0;

  /// Matriz del laberinto actual (16 filas x 27 columnas). Se arma desde el mapa
  /// de texto del nivel (`LevelData.rows`); los códigos están en [TileCode].
  List<List<int>> mazeGrid = [];

  /// Tamaño en píxeles (virtuales) de cada casilla del laberinto.
  final double tileSize = 24.0;

  /// Desplazamiento horizontal del laberinto para centrarlo en el área virtual.
  final double mazeOffsetX = 126.0;

  /// Número de columnas del laberinto.
  final int maxCols = 27;

  /// Texto del marcador de puntos (lo dibuja [HudPanel] sobre la pantalla).
  final HudLabel scoreText = HudLabel('SCORE: 0');

  /// Texto del marcador de récord.
  final HudLabel highScoreText = HudLabel('HIGH SCORE: 0');

  /// Rimoras y mydras que quedan en el laberinto (un solo componente).
  late RimoraField rimoraField;

  /// Controlador global de modos de los fantasmas (Scatter / Chase / Frightened).
  final GhostModeController modeController = GhostModeController();

  /// Total de puntos al iniciar la partida.
  int totalRimoras = 0;

  /// Puntos que todavía quedan en el laberinto.
  int rimorasRemaining = 0;

  /// Filas que tienen salida a los extremos del mapa (túneles laterales).
  Set<int> tunnelRows = {};

  /// Cuántas columnas desde cada extremo cuentan como zona de túnel.
  final int tunnelDepth = 6;

  /// Nivel de Cruise Elroy de Shardox según los puntos restantes:
  /// 0 = normal, 1 = Elroy 1, 2 = Elroy 2.
  int get elroyLevel {
    // Primero se evalúa el nivel 2 (más estricto); si no se cumple, el nivel 1.
    if (rimorasRemaining <= (totalRimoras * GameSpeeds.elroy2DotsFraction).round()) {
      return 2;
    }
    if (rimorasRemaining <= (totalRimoras * GameSpeeds.elroy1DotsFraction).round()) {
      return 1;
    }
    return 0;
  }

  /// Indica si una entidad que está en [gridPos], avanzando hacia [dir] con
  /// [progress] (0.0 a 1.0), se encuentra dentro de un túnel lateral.
  ///
  /// Nota: con `GameSpeeds.tunnelFactor = 1.0` el túnel ya no modifica la
  /// velocidad; la función se conserva por si se quiere volver a ajustar.
  bool isInTunnel(Vector2 gridPos, Vector2 dir, double progress) {
    // Posición intermedia real de la entidad, redondeada a la casilla más cercana.
    final col = (gridPos.x + dir.x * progress).round();
    final row = (gridPos.y + dir.y * progress).round();
    if (!tunnelRows.contains(row)) return false;
    return col < tunnelDepth || col >= maxCols - tunnelDepth;
  }

  // ---------------------------------------------------------------------------
  // HABILIDADES ESPECIALES Y ESTADO ASUSTADO GRUPAL
  // ---------------------------------------------------------------------------

  /// Fantasmas activos por tipo (consulta rápida entre habilidades).
  final Map<GhostType, Ghost> ghosts = {};

  /// Casillas bloqueadas por paredes temporales ya sólidas.
  final Set<int> solidWalls = {};

  /// Paredes temporales activas o en aviso, por casilla.
  final Map<int, TempWall> tempWalls = {};

  /// Últimas casillas visitadas por Pac-Man (la más reciente al final).
  final List<Vector2> pacTrail = [];

  /// Intensidad de la atracción del Fantasma Imán (0 = inactiva, 1 = máxima).
  double magnetStrength = 0.0;

  /// Dirección unitaria desde Pac-Man hacia el Fantasma Imán.
  Vector2 magnetDir = Vector2.zero();

  /// Motivo de la derrota, para mostrarlo en el menú de Game Over.
  String? deathCause;

  /// Pasa a `true` al terminar onLoad(). Evita usar objetos `late` (como
  /// [player]) antes de que existan.
  bool _ready = false;

  /// Sprites ya decodificados en tamaño pequeño. Los PNG originales pueden ser
  /// enormes (por ejemplo 1024 x 1024): decodificarlos completos gasta mucha
  /// memoria y vuelve lento el juego, sobre todo en celular. Aquí se
  /// decodifican DIRECTAMENTE a un tamaño cercano al que se ven en pantalla, y
  /// la imagen grande nunca llega a existir en memoria.
  final Map<String, ui.Image> _small = {};

  /// Imagen de [name] lista para dibujar. Lanza una excepción si no se cargó.
  ui.Image gameImage(String name) {
    final image = _small[name];
    if (image == null) throw StateError('Imagen no cargada: $name');
    return image;
  }

  /// Carga `assets/images/[name]` decodificándola a [maxSide] píxeles de ancho.
  Future<void> _loadSprite(String name, int maxSide) async {
    try {
      final data = await rootBundle.load('assets/images/$name');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        targetWidth: maxSide,
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      _small[name] = frame.image;
    } catch (e) {
      debugPrint('No se pudo cargar $name: $e');
    }
  }

  /// Lado (px) de las siluetas de los personajes: igual que su tamaño en pantalla.
  static const int _maskSize = 20;

  /// Siluetas (1 = píxel dibujado, 0 = transparente) de cada sprite, a 20 x 20.
  final Map<String, Uint8List> _masks = {};

  /// Calcula la silueta del sprite [name]: lo dibuja a 20 x 20 px (el tamaño que
  /// tiene en pantalla) y marca los píxeles que no son transparentes.
  Future<void> _buildMask(String name) async {
    try {
      final src = gameImage(name);
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        src,
        Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
        Rect.fromLTWH(0, 0, _maskSize.toDouble(), _maskSize.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      final small = picture.toImageSync(_maskSize, _maskSize);
      picture.dispose();
      final data = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
      small.dispose();
      if (data == null) return;
      final mask = Uint8List(_maskSize * _maskSize);
      for (int i = 0; i < mask.length; i++) {
        mask[i] = data.getUint8(i * 4 + 3) > 60 ? 1 : 0; // Canal alfa.
      }
      _masks[name] = mask;
    } catch (e) {
      debugPrint('No se pudo calcular la silueta de $name: $e');
    }
  }

  /// Qué fracción (0.0 a 1.0) de la silueta de [targetSprite] (en [targetPos])
  /// está cubierta por la silueta de [coverSprite] (en [coverPos]).
  ///
  /// Mide píxeles dibujados, no rectángulos: el fondo transparente del PNG no
  /// cuenta. Si falta una silueta se usa el cuadrado completo.
  double coverage(String targetSprite, Vector2 targetPos, String coverSprite,
      Vector2 coverPos) {
    const n = _maskSize;
    final dx = (coverPos.x - targetPos.x).round();
    final dy = (coverPos.y - targetPos.y).round();
    if (dx.abs() >= n || dy.abs() >= n) return 0.0;
    final target = _masks[targetSprite];
    final cover = _masks[coverSprite];
    var total = 0;
    var covered = 0;
    for (int y = 0; y < n; y++) {
      for (int x = 0; x < n; x++) {
        if (target != null && target[y * n + x] == 0) continue;
        total++;
        final cx = x - dx;
        final cy = y - dy;
        if (cx < 0 || cx >= n || cy < 0 || cy >= n) continue;
        if (cover == null || cover[cy * n + cx] == 1) covered++;
      }
    }
    return total == 0 ? 0.0 : covered / total;
  }

  /// Posición fraccionaria en la cuadrícula del centro de [c].
  /// Un valor entero corresponde al centro exacto de una casilla.
  Vector2 tilePosOf(PositionComponent c) => Vector2(
        // Centro del componente en píxeles -> se resta el desplazamiento del laberinto
        // -> se divide entre el tamaño de casilla. El -0.5 hace que el centro exacto
        // de una casilla valga un número entero.
        (c.position.x + c.size.x / 2 - mazeOffsetX) / tileSize - 0.5,
        (c.position.y + c.size.y / 2 - 24) / tileSize - 0.5,
      );

  /// Registra una casilla visitada por Pac-Man (la usa el Fantasma Constructor).
  void recordPacTile(Vector2 tile) {
    if (pacTrail.isNotEmpty &&
        pacTrail.last.x == tile.x &&
        pacTrail.last.y == tile.y) {
      return;
    }
    pacTrail.add(tile.clone());
    // Solo se conservan las últimas 24 casillas (el rastro más reciente).
    if (pacTrail.length > 24) pacTrail.removeAt(0);
  }

  /// Se llama cuando Pac-Man come una mydra: activa el modo Frightened y
  /// asusta a TODOS los fantasmas a la vez.
  void onMydraEaten() {
    modeController.startFrightened();
    GameAudio.sfx('sfx_mydra.wav');
    // Se asusta a los cuatro fantasmas registrados.
    for (final g in ghosts.values) {
      g.triggerPanic();
    }
  }

  /// Puntos por comer un guardián asustado ([kGhostPoints]).
  int nextGhostEatScore() => kGhostPoints;

  /// Calcula la atracción del Fantasma Imán (Shardox) sobre Pac-Man.
  void _updateMagnet() {
    magnetStrength = 0.0;
    final shardox = ghosts[GhostType.shardox];
    if (shardox == null || !shardox.isMounted || !player.isMounted) return;
    if (shardox.isDead ||
        shardox.isLeavingSpawn ||
        shardox.isScared ||
        shardox.isIced) {
      return;
    }

    // Vector (en casillas) que apunta desde el jugador hacia Shardox. Ambos
    // miden lo mismo, así que basta restar sus esquinas. Se calcula con números
    // simples para no crear objetos en cada frame.
    final dx = (shardox.position.x - player.position.x) / tileSize;
    final dy = (shardox.position.y - player.position.y) / tileSize;
    final dist = sqrt(dx * dx + dy * dy);
    // Fuera del radio de acción (o superpuestos: evita dividir entre casi cero).
    if (dist > AbilityConfig.magnetRadiusTiles || dist < 0.001) return;

    // Intensidad lineal: 0 en el borde del radio y 1 pegado a Shardox.
    magnetStrength = 1.0 - dist / AbilityConfig.magnetRadiusTiles;
    // Dirección normalizada (longitud 1). El jugador la usa para saber si avanza
    // hacia Shardox o se aleja de él.
    magnetDir.setValues(dx / dist, dy / dist);
  }

  /// Indica si una entidad ubicada en [grid], que avanza hacia [dir] con avance
  /// [progress], está sobre la casilla ([col], [row]) o entrando a ella.
  bool _entityTouchesTile(
      Vector2 grid, Vector2 dir, double progress, int col, int row) {
    if (grid.x.round() == col && grid.y.round() == row) return true;
    if (progress > 0.0) {
      return (grid.x + dir.x).round() == col && (grid.y + dir.y).round() == row;
    }
    return false;
  }

  /// Indica si Pac-Man o algún fantasma está en la casilla ([col], [row]) o
  /// avanzando hacia ella.
  bool isTileOccupied(int col, int row) {
    if (player.isMounted &&
        _entityTouchesTile(
            player.gridPos, player.moveDir, player.moveProgress, col, row)) {
      return true;
    }
    for (final g in ghosts.values) {
      // Un fantasma muerto (mori) vuela en línea recta y no ocupa casillas.
      if (g.isDead) continue;
      if (_entityTouchesTile(g.gridPos, g.moveDir, g.moveProgress, col, row)) {
        return true;
      }
    }
    return false;
  }

  /// Intenta que el Fantasma Constructor coloque una pared temporal en una
  /// casilla por la que Pac-Man pasó hace unos pasos, para cortarle la
  /// retirada. Devuelve `true` si se colocó.
  bool tryPlaceBuilderWall() {
    if (tempWalls.length >= AbilityConfig.builderMaxWalls) return false;
    if (!player.isMounted || pacTrail.length < 6) return false;

    final pacTile = tilePosOf(player);
    // Prueba las casillas del rastro de hace 4, 5, 3, 6 y 7 pasos, en ese orden
    // de preferencia.
    for (final back in const [4, 5, 3, 6, 7]) {
      // El último elemento del rastro es la casilla actual; se resta "back" para
      // retroceder en el tiempo.
      final index = pacTrail.length - 1 - back;
      if (index < 0) continue;
      final col = pacTrail[index].x.toInt();
      final row = pacTrail[index].y.toInt();
      if (!_isValidBuilderTile(col, row, pacTile)) continue;

      final wall = TempWall(col, row);
      tempWalls[tileKey(col, row)] = wall;
      add(wall);
      GameAudio.sfx('sfx_wax.wav');
      return true;
    }
    return false;
  }

  /// Reglas de seguridad para colocar una pared temporal:
  /// - Solo en pasillos (no muros ni casa de fantasmas ni zona de túnel).
  /// - A una distancia mínima de Pac-Man y sin nadie encima.
  /// - Sin dejar a Pac-Man encerrado en una zona demasiado pequeña.
  bool _isValidBuilderTile(int col, int row, Vector2 pacTile) {
    if (row < 0 || row >= mazeGrid.length || col < 0 || col >= maxCols) {
      return false;
    }
    final cell = mazeGrid[row][col];
    // 1) Solo pasillos: nada de muros ni de la casa de fantasmas.
    if (cell != TileCode.rimora &&
        cell != TileCode.mydra &&
        cell != TileCode.empty) {
      return false;
    }

    final key = tileKey(col, row);
    // 2) No duplicar una pared en la misma casilla.
    if (tempWalls.containsKey(key)) return false;
    // 3) Los túneles laterales quedan libres para que siempre exista una vía de
    // escape.
    if (tunnelRows.contains(row) &&
        (col < tunnelDepth || col >= maxCols - tunnelDepth)) {
      return false;
    }
    // 4) Distancia mínima al jugador: la pared nunca aparece encima de él.
    if (Vector2(col.toDouble(), row.toDouble()).distanceTo(pacTile) <
        AbilityConfig.builderMinPacDistance) {
      return false;
    }
    // 5) Nadie debe estar en la casilla (ni entrando a ella).
    if (isTileOccupied(col, row)) return false;

    // 6) Verificación de seguridad: se simula la pared y se cuenta a cuántas
    // casillas puede llegar el jugador. Si son pocas, quedaría "encerrado" y la
    // casilla se descarta.
    final startCol = max(0, min(maxCols - 1, pacTile.x.round()));
    final startRow = max(0, min(mazeGrid.length - 1, pacTile.y.round()));
    return _reachableCount(startCol, startRow, key) >=
        AbilityConfig.builderMinReachable;
  }

  /// Cuenta (hasta [limit]) las casillas alcanzables desde el punto inicial
  /// si [blockedKey] estuviera bloqueada. Usa búsqueda en anchura (BFS).
  int _reachableCount(int startCol, int startRow, int blockedKey,
      {int limit = 80}) {
    final startKey = tileKey(startCol, startRow);
    // visited = casillas ya exploradas; queue = cola de casillas pendientes.
    final visited = <int>{startKey};
    final queue = <int>[startKey];
    var head = 0;
    const dirs = [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1]
    ];

    // "head" recorre la cola sin borrar elementos (más eficiente que
    // removeAt(0)). Se detiene al llegar al límite: no hace falta contar de más.
    while (head < queue.length && visited.length < limit) {
      final key = queue[head++];
      // Inversa de tileKey(): key = fila * 100 + columna.
      final col = key % 100;
      final row = key ~/ 100;
      for (final d in dirs) {
        var nc = col + d[0];
        final nr = row + d[1];
        // Envoltura horizontal: el túnel lateral conecta ambos extremos del mapa.
        if (nc < 0) {
          nc = maxCols - 1;
        } else if (nc >= maxCols) {
          nc = 0;
        }
        if (!isWalkable(nc, nr)) continue;
        final nk = tileKey(nc, nr);
        // Se ignoran la casilla hipotética de la pared y las ya visitadas.
        if (nk == blockedKey || visited.contains(nk)) continue;
        visited.add(nk);
        queue.add(nk);
      }
    }
    return visited.length;
  }

  /// Color de fondo del juego (morado casi negro, a juego con el menú).
  @override
  Color backgroundColor() => levelData.bgBottom;

  // ---------------------------------------------------------------------------
  // ESCALADO RESPONSIVO
  // El juego se diseña en un lienzo "virtual" fijo y se escala para ajustarse
  // a cualquier pantalla, manteniendo la proporción y el centrado.
  // ---------------------------------------------------------------------------

  /// Ancho del lienzo virtual.
  static const double virtualWidth = 900.0;

  /// Alto del lienzo virtual: 24 (marcadores) + 16 * 24 (laberinto) +
  /// 24 de margen inferior.
  static const double virtualHeight = 432.0;

  // ---------------------------------------------------------------------------
  // CÁMARA
  // El juego se ve ampliado y la cámara sigue a Vance por el mapa. La interfaz
  // (marcadores, vidas, botón cryo, avisos) se dibuja sobre la pantalla con
  // [beginScreenSpace] / [endScreenSpace], sin moverse con la cámara.
  // ---------------------------------------------------------------------------

  /// Centro de la cámara en el mundo (coordenadas del laberinto).
  double camX = 0.0;
  double camY = 0.0;
  bool _camInit = false;

  /// Zoom: píxeles de pantalla por cada píxel del mundo. Se elige para que se
  /// vean [kCameraTilesTall] casillas de alto, así el mapa llena toda la
  /// pantalla (sin franjas).
  double get zoom => size.y / (kCameraTilesTall * tileSize);

  /// Factor de tamaño de la interfaz según el alto de la pantalla.
  double get hudScale => HudPanel.scaleFor(size);

  /// Mueve la cámara suavemente hacia Vance, sin salirse del laberinto. Si Vance
  /// se teletransporta (túnel o portal) la cámara salta de golpe.
  void _updateCamera(double dt) {
    if (!_ready || size.x <= 0 || size.y <= 0) return;
    final z = zoom;
    final viewW = size.x / z;
    final viewH = size.y / z;
    final left = mazeOffsetX;
    const top = 24.0;
    final right = left + maxCols * tileSize;
    final bottom = top + mazeGrid.length * tileSize;
    final tx = player.position.x + player.size.x / 2;
    final ty = player.position.y + player.size.y / 2;

    double clampAxis(double v, double lo, double hi, double view) {
      if (view >= hi - lo) return (lo + hi) / 2; // El mapa cabe: centrado.
      return v.clamp(lo + view / 2, hi - view / 2).toDouble();
    }

    final goalX = clampAxis(tx, left, right, viewW);
    final goalY = clampAxis(ty, top, bottom, viewH);
    if (!_camInit || (goalX - camX).abs() > 140 || (goalY - camY).abs() > 140) {
      camX = goalX;
      camY = goalY;
      _camInit = true;
    } else {
      final k = min(1.0, 9 * dt);
      camX += (goalX - camX) * k;
      camY += (goalY - camY) * k;
    }
  }

  /// Dibuja el mundo con la cámara: centrado en Vance y ampliado.
  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(zoom);
    canvas.translate(-camX, -camY);
    super.render(canvas);
    canvas.restore();
  }

  /// Empieza a dibujar sobre la PANTALLA (coordenadas en píxeles lógicos, con
  /// (0, 0) en la esquina superior izquierda). Hay que cerrar con
  /// [endScreenSpace].
  void beginScreenSpace(Canvas canvas) {
    canvas.save();
    canvas.translate(camX, camY);
    canvas.scale(1 / zoom);
    canvas.translate(-size.x / 2, -size.y / 2);
  }

  /// Termina el dibujo sobre la pantalla.
  void endScreenSpace(Canvas canvas) => canvas.restore();

  // ---------------------------------------------------------------------------
  // FINAL DEL JUEGO: PUERTA Y CORAZÓN DE CRISTAL (nivel 5)
  // ---------------------------------------------------------------------------

  /// Casilla donde aparece el corazón de cristal (en medio de la casa).
  static const int heartCol = 13;
  static const int heartRow = 7;

  /// `true` cuando la puerta de la casa de los guardianes está abierta (solo en
  /// el último nivel, al comer todas las rimoras y mydras). Entonces Vance puede
  /// entrar a la casa.
  bool houseOpen = false;

  /// `true` mientras el corazón de cristal final está esperando a Vance.
  bool finalHeartActive = false;

  /// Aviso de texto temporal que dibuja [HudPanel].
  String hintText = '';
  double hintLeft = 0.0;

  /// Muestra un aviso de texto durante [seconds] segundos.
  void showHint(String text, {double seconds = 4.0}) {
    hintText = text;
    hintLeft = seconds;
  }

  /// Abre la puerta de la casa y hace aparecer el corazón de cristal.
  void _openHouse() {
    houseOpen = true;
    finalHeartActive = true;
    add(FinalHeart());
    GameAudio.sfx('sfx_door.wav');
    showHint('¡La puerta se abrió! Toma el corazón de cristal');
  }

  /// Vance tomó el corazón de cristal: se termina el juego con victoria.
  void collectFinalHeart() {
    if (!finalHeartActive) return;
    finalHeartActive = false;
    children.whereType<FinalHeart>().toList().forEach((c) => c.removeFromParent());
    GameAudio.sfx('sfx_heart.wav');
    triggerGameWin();
  }

  /// Carga los recursos, crea los marcadores e inicia la primera partida.
  ///
  /// Cada imagen se carga por separado: si alguna falta, se registra el error
  /// en consola y el juego continúa con figuras de respaldo.
  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Sprites: se decodifican ya pequeños y en paralelo (ver [_loadSprite]).
    // (game_over, win y jova_logo se muestran con widgets de Flutter, no con
    // Flame, así que no se cargan aquí.)
    final jobs = <Future<void>>[
      _loadSprite('vance.png', 160),
      _loadSprite('rimora.png', 96),
      _loadSprite('mydra.png', 160),
      _loadSprite('mori.png', 160),
    ];
    for (final type in GhostType.values) {
      final personality = GhostPersonality.of(type);
      jobs.add(_loadSprite(personality.spriteAsset, 160));
      jobs.add(_loadSprite(personality.scaredSpriteAsset, 160));
    }
    await Future.wait(jobs);

    // Siluetas de Vance y de los guardianes, para medir cuánto se encima cada
    // personaje con otro (ver [coverage]).
    await _buildMask('vance.png');
    for (final type in GhostType.values) {
      await _buildMask(GhostPersonality.of(type).spriteAsset);
    }

    // El récord que se muestra es el del perfil guardado.
    highScore = currentProfile?.highScore ?? 0;
    highScoreText.text = 'HIGH SCORE: $highScore';
    // Laberinto (muros): se dibuja como una sola imagen, no como 150 piezas.
    mazeWalls = MazeWalls();
    add(mazeWalls);
    add(PortalTiles());
    add(GhostDoor());
    add(GateTiles());
    add(FogOfWar());
    add(HudPanel());
    // Texto "quién te mató" (solo se dibuja mientras Pac-Man parpadea).
    add(DeathMessage());
    // Corazones de vida (columna derecha) y cuenta regresiva: viven toda la
    // sesión y consultan el estado del juego al dibujarse.
    add(LivesDisplay());
    add(CountdownOverlay());
    if (kShowFps) add(FpsCounter());

    // Precarga de sonidos (ya hubo un toque del usuario: botón "Iniciar juego").
    // (El motor de audio ya empezó a cargar al abrir la app; aquí solo se espera.)
    await GameAudio.init().timeout(const Duration(seconds: 4), onTimeout: () {});

    try {
      // Se protege con try/catch para que un error al crear la partida no impida
      // abrir la pantalla.
      startGame();
    } catch (e, st) {
      debugPrint('Error en startGame: $e\n$st');
    }
    _ready = true;
  }

  /// Avanza el ciclo global de modos de los fantasmas mientras la partida
  /// está en curso.
  @override
  void update(double dt) {
    fxClock += dt;
    if (hintLeft > 0) hintLeft -= dt;
    // El imán se recalcula ANTES de actualizar a los componentes, para que el
    // jugador use el valor de este mismo frame.
    if (_ready && !isFrozen) {
      _updateMagnet();
    }

    // Animación de muerte: al cumplirse los 3 s se reinicia la ronda o termina
    // la partida.
    if (isDying) {
      deathElapsed += dt;
      if (deathElapsed >= deathBlinkSeconds) _finishDeath();
    }
    // Cuenta regresiva: mientras corre, todo está congelado.
    if (countdownLeft > 0) {
      countdownLeft = max(0.0, countdownLeft - dt);
      _updateCountdownAudio();
    }

    // Actualiza a todos los componentes hijos (jugador, fantasmas, láser...).
    super.update(dt);
    _updateCamera(dt);
    if (!isFrozen) {
      // El reloj de modos (Scatter/Chase/Frightened) solo corre mientras se juega.
      modeController.update(dt);

      // Compuertas de energía (niveles 3 y 5).
      if (levelData.gatePeriod > 0) _updateGates(dt);

      // Hielo de Vance: cuenta atrás hasta que los guardianes se descongelan.
      if (freezeLeft > 0) {
        freezeLeft -= dt;
        if (freezeLeft <= 0) {
          freezeLeft = 0.0;
          GameAudio.sfx('sfx_thaw.wav');
        }
      }

      // La música cambia a la versión de pánico mientras dura Frightened.
      final frightened = modeController.isFrightened;
      if (frightened != _wasFrightened) {
        _wasFrightened = frightened;
        if (_musicOn) GameAudio.playMusic(_currentMusicName());
      }
    }

    // Autoguardado del récord cada 5 segundos (solo escribe si cambió).
    _autosave += dt;
    if (_autosave >= 5.0) {
      _autosave = 0.0;
      saveProgress();
    }

    // Cada 2 s se comprueba que la música siga sonando (y se reinicia si no).
    if (_musicOn) {
      _musicCheck += dt;
      if (_musicCheck >= 2.0) {
        _musicCheck = 0.0;
        GameAudio.ensureMusic();
      }
    }
  }

  /// Nombre del archivo de música que corresponde al estado actual.
  String _currentMusicName() =>
      modeController.isFrightened ? 'music_panic.wav' : 'music_game.wav';

  /// Suena un pitido por cada número de la cuenta regresiva (3, 2, 1), un
  /// sonido distinto en el 0 y, al terminar, arranca la música.
  void _updateCountdownAudio() {
    final elapsed = countdownSeconds - countdownLeft;
    final step = min(3, (elapsed / (countdownSeconds / 4)).floor());
    if (step != _lastCountStep) {
      _lastCountStep = step;
      GameAudio.sfx(step < 3 ? 'sfx_countdown.wav' : 'sfx_go.wav');
    }
    if (countdownLeft <= 0) {
      _musicOn = true;
      _wasFrightened = modeController.isFrightened;
      GameAudio.playMusic(_currentMusicName());
    }
  }

  /// Inicia o reinicia una partida desde cero: puntuación en 0, 3 vidas, la
  /// habilidad sin carga y el primer nivel de la partida ([startLevel]).
  void startGame() {
    score = 0;
    isGameOver = false;
    isGameWon = false;
    levelComplete = false;
    lives = maxLives;
    isDying = false;
    deathElapsed = 0.0;
    countdownLeft = countdownSeconds;
    newRecord = false;
    _lastCountStep = -1;
    _musicOn = false;
    _autosave = 0.0;
    abilityCharge = 0.0;
    showLevelBanner = true;
    saveProgress(); // Guarda el récord de la partida anterior.
    GameAudio.stopMusic();
    deathCause = null;
    scoreText.text = 'SCORE: $score';
    // Cierra cualquier menú que haya quedado abierto de la partida anterior.
    overlays.remove('GameOverMenu');
    overlays.remove('GameWinMenu');
    overlays.remove('LevelCompleteMenu');
    overlays.remove('PauseMenu');
    resumeEngine(); // Un reinicio siempre quita la pausa.

    level = max(1, min(startLevel, kLevels.length));
    _setupLevel();
    GameAudio.sfx('sfx_level_start.wav');
  }

  /// Pasa al siguiente nivel (desde el menú de "nivel completado"). Se conservan
  /// la puntuación, las vidas y la carga de la habilidad.
  void nextLevel() {
    if (!levelComplete) return;
    overlays.remove('LevelCompleteMenu');
    levelComplete = false;
    level = min(level + 1, kLevels.length);
    countdownLeft = countdownSeconds;
    _lastCountStep = -1;
    _musicOn = false;
    showLevelBanner = true;
    _setupLevel();
    saveProgress();
    GameAudio.sfx('sfx_level_start.wav');
  }

  /// Arma el nivel actual: lee el mapa, configura la dificultad, redibuja los
  /// muros y coloca las rimoras, a Vance y a los guardianes.
  void _setupLevel() {
    _loadLevelGrid();
    modeController.schedule = levelData.schedule;
    modeController.frightenedDuration = levelData.frightenedSeconds;
    modeController.reset();
    // Se cuentan las casillas con rimora (0) y con mydra (3).
    totalRimoras = mazeGrid
        .expand((r) => r)
        .where((c) => c == TileCode.rimora || c == TileCode.mydra)
        .length;
    rimorasRemaining = totalRimoras;
    ghosts.clear();
    solidWalls.clear();
    tempWalls.clear();
    pacTrail.clear();
    magnetStrength = 0.0;
    freezeLeft = 0.0;
    gateAOpen = true;
    gateWarning = false;
    _gateTimer = 0.0;
    houseOpen = false;
    finalHeartActive = false;
    hintLeft = 0.0;

    // Limpieza: se eliminan las entidades del nivel anterior antes de
    // reconstruirlas. Los marcadores de texto y el panel se conservan.
    children
        .where((c) =>
            c is PlayerPacman ||
            c is Ghost ||
            c is RimoraField ||
            c is FinalHeart ||
            c is TempWall ||
            c is LaserLink)
        .toList()
        .forEach((c) => c.removeFromParent());

    mazeWalls.rebuild(); // Muros con los colores del nivel.
    _buildGridMaze();
    _spawnEntities();
  }

  /// Lee el mapa del nivel y calcula los túneles, los portales y las compuertas.
  void _loadLevelGrid() {
    mazeGrid = levelData.buildGrid();
    tunnelRows = {
      for (int r = 0; r < mazeGrid.length; r++)
        if (mazeGrid[r].first != TileCode.wall ||
            mazeGrid[r].last != TileCode.wall)
          r
    };
    portalLinks.clear();
    gateKeysA.clear();
    gateKeysB.clear();
    final firstOf = <int, int>{};
    for (int r = 0; r < mazeGrid.length; r++) {
      for (int c = 0; c < mazeGrid[r].length; c++) {
        final code = mazeGrid[r][c];
        if (code >= TileCode.portalA1 && code <= TileCode.portalB2) {
          firstOf[code] = tileKey(c, r);
        } else if (code == TileCode.gateA) {
          gateKeysA.add(tileKey(c, r));
        } else if (code == TileCode.gateB) {
          gateKeysB.add(tileKey(c, r));
        }
      }
    }
    const partner = {
      TileCode.portalA1: TileCode.portalA2,
      TileCode.portalA2: TileCode.portalA1,
      TileCode.portalB1: TileCode.portalB2,
      TileCode.portalB2: TileCode.portalB1,
    };
    partner.forEach((code, other) {
      final from = firstOf[code];
      final to = firstOf[other];
      if (from != null && to != null) portalLinks[from] = to;
    });
  }

  /// `true` si la compuerta con código [cell] está abierta en la fase actual.
  bool isGateOpen(int cell) =>
      cell == TileCode.gateA ? gateAOpen : !gateAOpen;

  /// Cambia la fase de las compuertas cada `LevelData.gatePeriod` segundos. Si
  /// alguien está dentro de una compuerta que se va a cerrar, espera.
  void _updateGates(double dt) {
    final period = levelData.gatePeriod;
    _gateTimer += dt;
    gateWarning = _gateTimer >= period - 1.0;
    if (_gateTimer < period) return;
    final closing = gateAOpen ? gateKeysA : gateKeysB;
    for (final key in closing) {
      if (isTileOccupied(key % 100, key ~/ 100)) {
        _gateTimer = period - 0.3; // Reintenta en 0.3 s.
        return;
      }
    }
    gateAOpen = !gateAOpen;
    _gateTimer = 0.0;
    gateWarning = false;
    GameAudio.sfx('sfx_gate.wav');
  }

  /// Usa la habilidad de hielo: congela a los guardianes `LevelData.freezeSeconds`.
  /// Solo si está cargada. No se restan puntos: la barra se vacía y se vuelve a
  /// llenar con los puntos que se ganen.
  void useAbility() {
    if (isFrozen || paused) return;
    if (!abilityReady || isFreezeActive) {
      if (!abilityReady) GameAudio.sfx('sfx_no_power.wav');
      return;
    }
    abilityCharge = 0.0;
    freezeLeft = levelData.freezeSeconds;
    GameAudio.sfx('sfx_freeze.wav');
  }

  /// Crea al jugador, a los cuatro fantasmas y el láser en su posición inicial.
  void _spawnEntities() {
    _camInit = false; // La cámara salta a Vance al empezar.
    // Casilla inicial del jugador: columna 13, fila 12 (parte baja, centrada).
    player = PlayerPacman(Vector2(13, 12));
    add(player);
    recordPacTile(player.gridPos);

    // Cada fantasma tiene su personalidad y sale de la base en un momento
    // distinto (releaseDelay, en segundos), que depende del nivel.
    final delays = levelData.releaseDelays;
    add(Ghost(Vector2(13, 7), GhostType.shardox, releaseDelay: delays[0]));
    add(Ghost(Vector2(14, 7), GhostType.vespakron, releaseDelay: delays[1]));
    add(Ghost(Vector2(13, 8), GhostType.kyros, releaseDelay: delays[2]));
    add(Ghost(Vector2(14, 8), GhostType.pyros, releaseDelay: delays[3]));

    // Láser que une a Kyros y Pyros.
    add(LaserLink());
  }

  /// Quita al jugador, los fantasmas, el láser y las paredes temporales, y
  /// limpia sus registros. NO toca las rimoras, la puntuación ni las vidas.
  void _removeEntities() {
    children
        .where((c) =>
            c is PlayerPacman ||
            c is Ghost ||
            c is TempWall ||
            c is LaserLink)
        .toList()
        .forEach((c) => c.removeFromParent());
    ghosts.clear();
    solidWalls.clear();
    tempWalls.clear();
    pacTrail.clear();
    magnetStrength = 0.0;
    freezeLeft = 0.0;
    gateAOpen = true;
    gateWarning = false;
    _gateTimer = 0.0;
    modeController.reset();
  }

  /// El jugador fue atrapado (por un fantasma o por el láser): pierde una vida
  /// y empieza la animación de parpadeo de [deathBlinkSeconds].
  ///
  /// [title] dice quién fue y [detail] cómo; se muestran en pantalla (sin
  /// cuadro) mientras Pac-Man parpadea, con el [color] del culpable.
  void playerDied({
    required String title,
    required String detail,
    Color color = Colors.redAccent,
  }) {
    if (isDying || isGameOver || isGameWon || isCountingDown || levelComplete) {
      return;
    }
    lives = max(0, lives - 1);
    isDying = true;
    deathElapsed = 0.0;
    deathTitle = title;
    deathDetail = detail;
    deathColor = color;
    deathCause = '$title. $detail'; // Texto para la pantalla de Game Over.
    _musicOn = false;
    GameAudio.stopMusic();
    GameAudio.sfx('sfx_death.wav');
  }

  /// Termina la animación de muerte. Sin vidas: Game Over. Con vidas: se
  /// reubican los personajes (los puntos y la puntuación se conservan) y
  /// arranca la cuenta regresiva.
  void _finishDeath() {
    isDying = false;
    if (lives <= 0) {
      triggerGameOver(cause: deathCause);
      return;
    }
    _removeEntities();
    _spawnEntities();
    countdownLeft = countdownSeconds;
    _lastCountStep = -1;
    _musicOn = false;
    showLevelBanner = false;
  }

  /// Guarda en el perfil la mayor puntuación y el nivel alcanzado, pero SOLO si
  /// superan lo que ya estaba guardado (no es progresivo).
  void saveProgress() {
    final profile = currentProfile;
    if (profile == null) return;
    var changed = false;
    if (highScore > profile.highScore) {
      profile.highScore = highScore;
      changed = true;
    }
    // Nivel alcanzado: al completar un nivel se desbloquea el siguiente.
    final reached =
        levelComplete ? min(level + 1, kLevels.length) : level;
    if (reached > profile.level) {
      profile.level = reached;
      changed = true;
    }
    if (changed) unawaited(ProfileStore.save(profile));
  }

  /// Suma [points] a la puntuación, actualiza el récord y verifica la victoria.
  ///
  /// La partida se gana cuando ya no queda ninguna rimora en el laberinto.
  void addScore(int points) {
    score += points;
    // La habilidad de hielo se carga con los puntos ganados.
    final wasReady = abilityReady;
    abilityCharge = min(kAbilityCostPoints, abilityCharge + points);
    if (!wasReady && abilityReady) GameAudio.sfx('sfx_ready.wav');
    scoreText.text = 'SCORE: $score';

    // El récord se actualiza en vivo; por eso "score >= highScore" al terminar
    // indica que se igualó o superó el récord.
    if (score > highScore) {
      highScore = score;
      highScoreText.text = 'HIGH SCORE: $highScore';
      newRecord = true; // Superó el récord guardado en el perfil.
    }

    // rimorasRemaining lo decrementa el jugador al comer; al llegar a 0 se gana.
    if (rimorasRemaining <= 0) {
      triggerLevelClear();
    }
  }

  /// Recorre [mazeGrid] y coloca las rimoras (0) y mydras (3) en un único
  /// componente [RimoraField]. Los muros los dibuja [MazeWalls].
  void _buildGridMaze() {
    final field = RimoraField();
    for (int row = 0; row < mazeGrid.length; row++) {
      for (int col = 0; col < mazeGrid[row].length; col++) {
        final cell = mazeGrid[row][col];
        if (cell == 0) {
          field.addCell(col, row, false);
        } else if (cell == 3) {
          field.addCell(col, row, true);
        }
      }
    }
    rimoraField = field;
    add(field);
  }

  /// Indica si la casilla ([col], [row]) puede ser transitada.
  ///
  /// - Fuera del rango vertical: no transitable.
  /// - Fuera del rango horizontal: transitable (túnel lateral).
  /// - Muros: no transitables.
  /// - Casa de fantasmas: solo transitable si [isGhost] es verdadero.
  bool isWalkable(int col, int row, {bool isGhost = false}) {
    if (row < 0 || row >= mazeGrid.length) return false;
    if (col < 0 || col >= maxCols) return true;
    int cell = mazeGrid[row][col];
    if (cell == 1) return false;
    if (cell == 2 && !isGhost && !houseOpen) return false;
    // Compuertas de energía: cerradas bloquean el paso (a todos).
    if ((cell == TileCode.gateA || cell == TileCode.gateB) &&
        !isGateOpen(cell)) {
      return false;
    }
    if (solidWalls.contains(tileKey(col, row))) return false; // Pared temporal
    return true;
  }

  /// Determina si un fantasma ve al jugador.
  ///
  /// Hay línea de visión solo si ambos comparten fila o columna y no existe
  /// ningún muro entre ellos.
  ///
  /// Nota: por ahora ninguna mecánica lo utiliza; se conserva como utilidad
  /// para futuras ideas (por ejemplo, fantasmas que solo persigan si ven al
  /// jugador).
  bool hasLineOfSight(Vector2 ghostGrid, Vector2 playerGrid) {
    if (ghostGrid.y == playerGrid.y) {
      int startX = ghostGrid.x.toInt();
      int startY = ghostGrid.y.toInt();
      int targetX = playerGrid.x.toInt();
      int step = targetX > startX ? 1 : -1;
      for (int x = startX + step; x != targetX; x += step) {
        if (x >= 0 && x < maxCols && mazeGrid[startY][x] == 1) return false;
      }
      return true;
    } else if (ghostGrid.x == playerGrid.x) {
      int startX = ghostGrid.x.toInt();
      int startY = ghostGrid.y.toInt();
      int targetY = playerGrid.y.toInt();
      int step = targetY > startY ? 1 : -1;
      for (int y = startY + step; y != targetY; y += step) {
        if (startX >= 0 && startX < maxCols && mazeGrid[y][startX] == 1) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  /// Indica si el juego está en pausa.
  bool get isPaused => paused;

  /// Pausa o reanuda la partida (tecla ESC o botón "Continuar").
  ///
  /// `pauseEngine()` congela todo, incluidos los temporizadores de modos,
  /// el láser y las paredes del Constructor.
  void togglePause() {
    if (isGameOver || isGameWon) return;
    // "paused" es una propiedad de Flame: vale true cuando el motor está pausado.
    if (paused) {
      resumeEngine();
      overlays.remove('PauseMenu');
      GameAudio.resumeMusic();
    } else {
      pauseEngine();
      overlays.add('PauseMenu');
      GameAudio.pauseMusic();
      saveProgress();
    }
  }

  /// Pausa el juego si se sale de la app (o de la pestaña) y todavía no está
  /// pausado ni terminado.
  void autoPause() {
    if (_ready && !isGameOver && !isGameWon && !paused) togglePause();
  }

  /// Termina la partida por derrota y muestra el menú de Game Over.
  void triggerGameOver({String? cause}) {
    if (isGameOver || isGameWon) return;
    isGameOver = true;
    deathCause = cause;
    overlays.add('GameOverMenu');
    _musicOn = false;
    GameAudio.stopMusic();
    GameAudio.sfx('sfx_game_over.wav');
    saveProgress();
  }

  /// Se comieron todas las rimoras: si quedan niveles, muestra "nivel completado";
  /// si era el último, la victoria final.
  void triggerLevelClear() {
    if (isGameOver || isGameWon || levelComplete) return;
    if (level >= kLevels.length) {
      // Último nivel: se abre la puerta de la casa y aparece el corazón de
      // cristal; al tomarlo se gana (ver [collectFinalHeart]).
      if (!houseOpen) _openHouse();
      return;
    }
    levelComplete = true;
    freezeLeft = 0.0;
    overlays.add('LevelCompleteMenu');
    _musicOn = false;
    GameAudio.stopMusic();
    GameAudio.sfx('sfx_level_up.wav');
    saveProgress();
  }

  /// Termina la partida por victoria y muestra el menú de Victoria.
  void triggerGameWin() {
    if (isGameOver || isGameWon) return;
    isGameWon = true;
    overlays.add('GameWinMenu');
    _musicOn = false;
    GameAudio.stopMusic();
    GameAudio.sfx('sfx_win.wav');
    saveProgress();
  }

  /// Gestiona la entrada por teclado (flechas direccionales y ESC).
  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // Con la partida terminada se ignora el teclado.
    if (isGameOver || isGameWon) return KeyEventResult.ignored;

    // ESC se procesa antes que cualquier otra tecla y solo al presionarla
    // (no al mantenerla).
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      togglePause();
      return KeyEventResult.handled;
    }
    // Barra espaciadora: habilidad de hielo.
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.space) {
      useAbility();
      return KeyEventResult.handled;
    }
    // En pausa se "consumen" las teclas para que no muevan al jugador.
    if (paused) return KeyEventResult.handled;
    // Mientras Pac-Man parpadea no se aceptan direcciones.
    if (isDying) return KeyEventResult.handled;

    // KeyRepeatEvent: al mantener una tecla pulsada se sigue registrando la
    // dirección.
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
        player.changeDirection(Vector2(-1, 0));
      } else if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
        player.changeDirection(Vector2(1, 0));
      } else if (keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
        player.changeDirection(Vector2(0, -1));
      } else if (keysPressed.contains(LogicalKeyboardKey.arrowDown)) {
        player.changeDirection(Vector2(0, 1));
      }
    }
    return KeyEventResult.handled;
  }
}
