// ==============================================================================
// PROYECTO: JOVA-LAND (Motor Arcade Híbrido Multiplataforma)
// AUTOR: Gabriel Jovanny Osuna Martínez
// DESCRIPCIÓN: Videojuego arcade 2D desarrollado con Flutter y el motor Flame. 
// Cuenta con adaptabilidad multiplataforma (escritorio y dispositivos móviles),
// optimización de orientación y controles táctiles nativos desacoplados para 
// garantizar una respuesta de baja latencia.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import 'dart:math';

/// Punto de entrada principal de la aplicación.
/// Configura las restricciones de orientación y el modo inmersivo en plataformas móviles.
void main() async {
  // Asegura la correcta inicialización de los enlaces de Flutter antes de arrancar el motor.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configuración específica para plataformas móviles (Android / iOS)
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    // Forzar orientación horizontal para optimizar el campo de visión del arcade.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Activar modo inmersivo ocultando barras de sistema para una experiencia limpia.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  
  runApp(MyApp());
}

/// Widget raíz de la aplicación que inicializa el tema visual y el contenedor del juego.
class MyApp extends StatelessWidget {
  MyApp({super.key});
  
  // Instancia única del núcleo del juego para mantener el estado en memoria.
  final PacManGame _game = PacManGame();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JOVA-LAND',
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 900,
            height: 450,
            // Contenedor principal que integra el motor Flame y la capa de controles nativos mediante un Stack.
            child: Stack(
              children: [
                // Instancia del widget del motor de Flame.
                GameWidget<PacManGame>.controlled(
                  gameFactory: () => _game,
                  overlayBuilderMap: {
                    'GameOverMenu': (context, game) => GameOverOverlay(game),
                    'GameWinMenu': (context, game) => GameWinOverlay(game),
                  },
                ),
                // Capa de controles táctiles exclusivos para móviles (desacoplada del canvas para evitar latencia).
                if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS))
                  MobileControlsWidget(game: _game),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Núcleo lógico del juego. Extiende de [FlameGame] e implementa [KeyboardEvents] para soporte en PC.
class PacManGame extends FlameGame with KeyboardEvents {
  late PlayerPacman player;
  int score = 0;
  int highScore = 0;
  bool isGameOver = false;
  bool isGameWon = false;

  // Notificador de estado reactivo para mostrar u ocultar los controles táctiles en los menús.
  final ValueNotifier<bool> showControls = ValueNotifier<bool>(true);

  // Matriz de diseño del laberinto (1: Muro, 0: Punto estándar, 3: Power-up, 2: Zona de spawneo).
  final List<List<int>> mazeGrid = [
    [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    [1,3,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,3,1],
    [1,0,1,1,0,1,1,1,0,1,0,1,1,1,0,1,1,0,1],
    [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
    [1,0,1,1,0,1,0,1,1,1,1,1,0,1,0,1,1,0,1],
    [1,0,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,0,1],
    [1,1,1,1,0,1,1,1,2,2,2,1,1,1,0,1,1,1,1],
    [0,0,0,0,0,1,2,2,2,2,2,2,2,1,0,0,0,0,0],
    [1,1,1,1,0,1,2,2,2,2,2,2,2,1,0,1,1,1,1],
    [1,1,1,1,0,1,1,1,1,1,1,1,1,1,0,1,1,1,1],
    [1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1],
    [1,0,1,1,0,1,1,1,0,1,0,1,1,1,0,1,1,0,1],
    [1,3,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,3,1],
    [1,1,0,1,0,1,0,1,1,1,1,1,1,1,0,1,0,1,1],
    [1,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,1],
    [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
  ];

  final double tileSize = 24.0;
  final double mazeOffsetX = 230.0; // Desplazamiento horizontal para centrar el mapa y alojar el joystick.
  final int maxCols = 19;
  
  late TextComponent scoreText;
  late TextComponent highScoreText;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Precarga centralizada de recursos multimedia (sprites) con manejo de excepciones.
    try {
      await images.loadAll(['pacman.png', 'ghost.png', 'dot.png', 'niga.png']);
    } catch (e) {
      debugPrint("Error crítico al cargar assets de imagen: $e");
    }

    // Inicialización de componentes de texto para el HUD de puntuación.
    scoreText = TextComponent(
      text: 'SCORE: 0',
      position: Vector2(700, 30),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );

    highScoreText = TextComponent(
      text: 'HIGH SCORE: 0',
      position: Vector2(700, 70),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.yellow, fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );

    add(scoreText);
    add(highScoreText);

    startGame();
  }

  /// Método para inicializar o reiniciar el estado global de la partida.
  void startGame() {
    score = 0;
    isGameOver = false;
    isGameWon = false;
    showControls.value = true;
    scoreText.text = 'SCORE: $score';
    overlays.remove('GameOverMenu');
    overlays.remove('GameWinMenu');

    // Limpieza de entidades anteriores en el árbol de componentes.
    children.where((c) => c is PlayerPacman || c is Ghost || c is Dot || c is Wall).toList().forEach((c) => c.removeFromParent());

    _buildGridMaze();

    // Instanciación de entidades de juego en posiciones predeterminadas.
    player = PlayerPacman(Vector2(9, 14));
    add(player);

    add(Ghost(Vector2(9, 7)));
    add(Ghost(Vector2(10, 7)));
    add(Ghost(Vector2(9, 8)));
    add(Ghost(Vector2(10, 8)));
  }

  /// Gestiona el incremento de puntaje, actualización de récords y condición de victoria.
  void addScore(int points) {
    score += points;
    scoreText.text = 'SCORE: $score';

    if (score > highScore) {
      highScore = score;
      highScoreText.text = 'HIGH SCORE: $highScore';
    }

    // Condición de victoria: si no quedan puntos coleccionables en el mapa.
    if (children.whereType<Dot>().isEmpty) {
      triggerGameWin();
    }
  }

  /// Genera los componentes físicos del laberinto basándose en la matriz de datos.
  void _buildGridMaze() {
    for (int row = 0; row < mazeGrid.length; row++) {
      for (int col = 0; col < mazeGrid[row].length; col++) {
        int cell = mazeGrid[row][col];
        Vector2 pos = Vector2(mazeOffsetX + (col * tileSize), row * tileSize);

        if (cell == 1) {
          add(Wall(pos, Vector2(tileSize, tileSize)));
        } else if (cell == 0) {
          add(Dot(Vector2(col.toDouble(), row.toDouble()), isPowerUp: false));
        } else if (cell == 3) {
          add(Dot(Vector2(col.toDouble(), row.toDouble()), isPowerUp: true));
        }
      }
    }
  }

  /// Valida si una celda específica del laberinto permite el tránsito de entidades.
  bool isWalkable(int col, int row, {bool isGhost = false}) {
    if (row < 0 || row >= mazeGrid.length) return false;
    if (col < 0 || col >= maxCols) return true; // Soporte para túneles laterales de teletransporte.
    int cell = mazeGrid[row][col];
    if (cell == 1) return false;
    if (cell == 2 && !isGhost) return false; // Restricción de salida para fantasmas en zona de spawn.
    return true;
  }

  /// Algoritmo de línea de visión (*Line of Sight*) para la Inteligencia Artificial de los fantasmas.
  bool hasLineOfSight(Vector2 ghostGrid, Vector2 playerGrid) {
    if (ghostGrid.y != playerGrid.y) return false;
    int startX = ghostGrid.x.toInt();
    int startY = ghostGrid.y.toInt();
    int targetX = playerGrid.x.toInt();

    int step = targetX > startX ? 1 : -1;
    for (int x = startX + step; x != targetX; x += step) {
      if (x >= 0 && x < maxCols && mazeGrid[startY][x] == 1) return false;
    }
    return true;
  }

  void triggerGameOver() {
    if (isGameOver || isGameWon) return;
    isGameOver = true;
    showControls.value = false;
    overlays.add('GameOverMenu');
  }

  void triggerGameWin() {
    if (isGameOver || isGameWon) return;
    isGameWon = true;
    showControls.value = false;
    overlays.add('GameWinMenu');
  }

  /// Manejo de eventos de entrada por teclado físico (para versiones de escritorio/PC).
  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (isGameOver || isGameWon) return KeyEventResult.ignored;

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

/// Capa de controles táctiles desarrollada como un Widget nativo de Flutter superpuesto.
/// Garantiza una respuesta fluida e infinita, inmune a bloqueos del ciclo de vida de Flame.
class MobileControlsWidget extends StatelessWidget {
  final PacManGame game;
  const MobileControlsWidget({required this.game, super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: game.showControls,
      builder: (context, show, child) {
        if (!show) return const SizedBox.shrink();
        return Stack(
          children: [
            Positioned(left: 110, top: 190, child: _buildNavButton('↑', Vector2(0, -1))),
            Positioned(left: 110, top: 310, child: _buildNavButton('↓', Vector2(0, 1))),
            Positioned(left: 45, top: 250, child: _buildNavButton('←', Vector2(-1, 0))),
            Positioned(left: 175, top: 250, child: _buildNavButton('→', Vector2(1, 0))),
          ],
        );
      },
    );
  }

  Widget _buildNavButton(String label, Vector2 direction) {
    return Listener(
      onPointerDown: (_) {
        if (!game.isGameOver && !game.isGameWon) {
          game.player.changeDirection(direction);
        }
      },
      child: Container(
        width: 52,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.blue.shade800,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.yellow, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

/// Menú superpuesto para la pantalla de Derrota (Game Over).
class GameOverOverlay extends StatelessWidget {
  final PacManGame game;
  const GameOverOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue.shade900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('GAME OVER', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              const SizedBox(height: 8),
              Text('Puntuación: ${game.score}', style: const TextStyle(fontSize: 18, color: Colors.white)),
              Text('Récord Máximo: ${game.highScore}', style: const TextStyle(fontSize: 16, color: Colors.yellow)),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10)),
                onPressed: () => game.startGame(),
                child: const Text('Reiniciar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Menú superpuesto para la pantalla de Victoria.
class GameWinOverlay extends StatelessWidget {
  final PacManGame game;
  const GameWinOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue.shade900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.yellow, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¡VICTORIA!', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.yellow)),
              const SizedBox(height: 8),
              Text('¡Comiste todos los puntos!\nPuntuación: ${game.score}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.white)),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10)),
                onPressed: () => game.startGame(),
                child: const Text('Reiniciar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entidad del Jugador (Pacman). Maneja el movimiento basado en interpolación de rejilla.
class PlayerPacman extends SpriteComponent with HasGameReference<PacManGame> {
  Vector2 gridPos;
  Vector2 moveDir = Vector2.zero();
  Vector2 nextDir = Vector2.zero();
  double moveProgress = 0.0;
  final double speed = 6.0;

  PlayerPacman(this.gridPos);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      sprite = Sprite(game.images.fromCache('pacman.png'));
    } catch (_) {}
    size = Vector2(18, 18);
    position = Vector2(game.mazeOffsetX + gridPos.x * game.tileSize + 3, gridPos.y * game.tileSize + 3);
  }

  /// Método optimizado para enrutar cambios de dirección de forma inmediata o almacenarlos en búfer.
  void changeDirection(Vector2 newDir) {
    int targetX = (gridPos.x + newDir.x).toInt();
    int targetY = (gridPos.y + newDir.y).toInt();
    
    if (game.isWalkable(targetX, targetY, isGhost: false)) {
      moveDir = newDir.clone();
      nextDir.setZero();
    } else {
      nextDir = newDir.clone();
    }
  }

  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      super.render(canvas);
    } else {
      canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, Paint()..color = Colors.yellow);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isGameWon) return;

    if (moveProgress == 0.0) {
      if (nextDir != Vector2.zero()) {
        int nextX = (gridPos.x + nextDir.x).toInt();
        int nextY = (gridPos.y + nextDir.y).toInt();
        if (game.isWalkable(nextX, nextY, isGhost: false)) {
          moveDir = nextDir.clone();
          nextDir.setZero();
        }
      }

      int targetX = (gridPos.x + moveDir.x).toInt();
      int targetY = (gridPos.y + moveDir.y).toInt();
      if (!game.isWalkable(targetX, targetY, isGhost: false)) {
        moveDir.setZero();
      }
    }

    if (moveDir != Vector2.zero()) {
      moveProgress += speed * dt;

      double startX = game.mazeOffsetX + gridPos.x * game.tileSize + 3;
      double startY = gridPos.y * game.tileSize + 3;
      double endX = game.mazeOffsetX + (gridPos.x + moveDir.x) * game.tileSize + 3;
      double endY = (gridPos.y + moveDir.y) * game.tileSize + 3;

      position.x = startX + (endX - startX) * min(moveProgress, 1.0);
      position.y = startY + (endY - startY) * min(moveProgress, 1.0);

      if (moveProgress >= 1.0) {
        gridPos.add(moveDir);
        moveProgress = 0.0;

        // Lógica de teletransporte en los extremos horizontales del laberinto.
        if (gridPos.x < 0) {
          gridPos.x = (game.maxCols - 1).toDouble();
          position.x = game.mazeOffsetX + gridPos.x * game.tileSize + 3;
        } else if (gridPos.x >= game.maxCols) {
          gridPos.x = 0;
          position.x = game.mazeOffsetX + gridPos.x * game.tileSize + 3;
        }
      }
    }

    // Colisiones con coleccionables (puntos y power-ups).
    game.children.whereType<Dot>().toList().forEach((dot) {
      if (dot.gridPos == gridPos) {
        dot.removeFromParent();
        game.addScore(dot.isPowerUp ? 100 : 10);
        if (dot.isPowerUp) {
          game.children.whereType<Ghost>().forEach((g) => g.triggerPanic());
        }
      }
    });
  }
}

/// Componente coleccionable (Puntos estándar y energizantes).
class Dot extends SpriteComponent with HasGameReference<PacManGame> {
  Vector2 gridPos;
  bool isPowerUp;
  Dot(this.gridPos, {this.isPowerUp = false});

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      sprite = Sprite(game.images.fromCache('dot.png'));
    } catch (_) {}
    size = isPowerUp ? Vector2(10, 10) : Vector2(4, 4);
    position = Vector2(
      game.mazeOffsetX + gridPos.x * game.tileSize + (game.tileSize - size.x) / 2,
      gridPos.y * game.tileSize + (game.tileSize - size.y) / 2,
    );
  }

  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      super.render(canvas);
    } else {
      canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, Paint()..color = Colors.white);
    }
  }
}

/// Entidad Inteligente (Fantasmas). Implementa patrullaje, persecución por línea de visión y estados de pánico.
class Ghost extends SpriteComponent with HasGameReference<PacManGame> {
  Vector2 gridPos;
  final Vector2 spawnGridPos = Vector2(9, 7);
  Vector2 moveDir = Vector2(0, -1);
  double moveProgress = 0.0;
  final double speed = 4.5;
  bool isScared = false;
  bool isDead = false;
  bool isLeavingSpawn = true;
  double scaredTimer = 0.0;
  Random random = Random();

  Ghost(this.gridPos);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      sprite = Sprite(game.images.fromCache('ghost.png'));
    } catch (_) {}
    size = Vector2(18, 18);
    position = Vector2(game.mazeOffsetX + gridPos.x * game.tileSize + 3, gridPos.y * game.tileSize + 3);
  }

  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      super.render(canvas);
    } else {
      canvas.drawRect(size.toRect(), Paint()..color = Colors.red);
    }
  }

  /// Activa el estado de vulnerabilidad/pánico al consumir un Power-Up.
  void triggerPanic() {
    if (!isDead && !isLeavingSpawn) {
      isScared = true;
      scaredTimer = 8.0;
      try {
        sprite = Sprite(game.images.fromCache('niga.png'));
      } catch (_) {}
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isGameWon) return;

    if (isDead) {
      Vector2 targetSpawnPx = Vector2(game.mazeOffsetX + spawnGridPos.x * game.tileSize + 3, spawnGridPos.y * game.tileSize + 3);
      position = position + (targetSpawnPx - position).normalized() * 260 * dt;
      if (position.distanceTo(targetSpawnPx) < 8) {
        isDead = false;
        isScared = false;
        isLeavingSpawn = true;
        gridPos = spawnGridPos.clone();
        position = Vector2(game.mazeOffsetX + gridPos.x * game.tileSize + 3, gridPos.y * game.tileSize + 3);
        try {
          sprite = Sprite(game.images.fromCache('ghost.png'));
        } catch (_) {}
      }
      return;
    }

    if (isLeavingSpawn) {
      moveDir = Vector2(0, -1);
      if (moveProgress == 0.0) {
        int targetX = (gridPos.x + moveDir.x).toInt();
        int targetY = (gridPos.y + moveDir.y).toInt();
        if (!game.isWalkable(targetX, targetY, isGhost: true)) {
          moveDir = Vector2(0, 1);
        }
      }
      moveProgress += speed * dt;
      double startX = game.mazeOffsetX + gridPos.x * game.tileSize + 3;
      double startY = gridPos.y * game.tileSize + 3;
      double endX = game.mazeOffsetX + (gridPos.x + moveDir.x) * game.tileSize + 3;
      double endY = (gridPos.y + moveDir.y) * game.tileSize + 3;

      position.x = startX + (endX - startX) * min(moveProgress, 1.0);
      position.y = startY + (endY - startY) * min(moveProgress, 1.0);

      if (moveProgress >= 1.0) {
        gridPos.add(moveDir);
        moveProgress = 0.0;
        if (gridPos.y <= 6) {
          isLeavingSpawn = false;
        }
      }
      return;
    }

    if (isScared) {
      scaredTimer -= dt;
      if (scaredTimer <= 0) {
        isScared = false;
        try {
          sprite = Sprite(game.images.fromCache('ghost.png'));
        } catch (_) {}
      }
    }

    if (moveProgress == 0.0 && game.player.isMounted) {
      final player = game.player;
      bool hasVision = game.hasLineOfSight(gridPos, player.gridPos);

      if (hasVision && !isScared) {
        moveDir = Vector2(player.gridPos.x > gridPos.x ? 1 : -1, 0);
      } else if (hasVision && isScared) {
        moveDir = Vector2(player.gridPos.x > gridPos.x ? -1 : 1, 0);
      } else {
        List<Vector2> validDirs = [];
        for (var dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]) {
          if (dir != -moveDir && game.isWalkable((gridPos.x + dir.x).toInt(), (gridPos.y + dir.y).toInt(), isGhost: true)) {
            validDirs.add(dir);
          }
        }
        if (validDirs.isNotEmpty) {
          moveDir = validDirs[random.nextInt(validDirs.length)];
        } else {
          moveDir = -moveDir;
        }
      }
    }

    moveProgress += speed * dt;
    double startX = game.mazeOffsetX + gridPos.x * game.tileSize + 3;
    double startY = gridPos.y * game.tileSize + 3;
    double endX = game.mazeOffsetX + (gridPos.x + moveDir.x) * game.tileSize + 3;
    double endY = (gridPos.y + moveDir.y) * game.tileSize + 3;

    position.x = startX + (endX - startX) * min(moveProgress, 1.0);
    position.y = startY + (endY - startY) * min(moveProgress, 1.0);

    if (moveProgress >= 1.0) {
      gridPos.add(moveDir);
      moveProgress = 0.0;

      if (gridPos.x < 0) {
        gridPos.x = (game.maxCols - 1).toDouble();
        position.x = game.mazeOffsetX + gridPos.x * game.tileSize + 3;
      } else if (gridPos.x >= game.maxCols) {
        gridPos.x = 0;
        position.x = game.mazeOffsetX + gridPos.x * game.tileSize + 3;
      }
    }

    // Detección de colisión entre fantasma y jugador.
    if (toRect().overlaps(game.player.toRect())) {
      if (isScared) {
        isDead = true;
        try {
          sprite = Sprite(game.images.fromCache('dot.png'));
        } catch (_) {}
        game.addScore(500);
      } else {
        game.triggerGameOver();
      }
    }
  }
}

/// Componente estático que representa los muros del laberinto.
class Wall extends PositionComponent {
  Wall(Vector2 pos, Vector2 sz) {
    position = pos;
    size = sz;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()..color = const Color(0xFF1E1EEB);
    canvas.drawRect(size.toRect(), paint);
  }
}