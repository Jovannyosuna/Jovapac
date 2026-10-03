// ==============================================================================
// PROYECTO: LA-SANVI (Motor Arcade Híbrido Multiplataforma)
// AUTOR: Gabriel Jovanny Osuna Martínez
// DESCRIPCIÓN TÉCNICA: Videojuego arcade 2D desarrollado con Flutter y el motor 
// Flame. Implementa arquitectura basada en componentes, gestión de estados reactivos,
// menús superpuestos nativos (Overlays), optimización gráfica para escritorio y 
// dispositivos móviles, y un sistema de movimiento absoluto en rejilla con búfer 
// de comandos para garantizar cero latencia, transiciones fluidas y colisiones 
// estrictas sin excepciones.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import 'dart:math';

/// Punto de entrada principal de la aplicación.
/// Inicializa los enlaces de Flutter y configura las restricciones nativas de 
/// orientación horizontal y modo inmersivo en plataformas móviles.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }
  
  runApp(const MyApp());
}

/// Widget raíz de la aplicación. Configura el tema visual oscuro global y
/// establece el flujo de navegación inicial hacia el menú principal.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JOVA-LAND',
      theme: ThemeData.dark(),
      home: const MainMenuScreen(),
    );
  }
}

/// ==============================================================================
/// MÓDULO DE INTERFAZ: PANTALLA DE INICIO (MENÚ PRINCIPAL)
/// ==============================================================================
class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Renderizado del logotipo corporativo con respaldo textual de seguridad
            Image.asset(
              'assets/images/jova_logo.png',
              width: 420,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  'JOVA-LAND',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.yellow),
                );
              },
            ),
            const SizedBox(height: 35),
            // Botón interactivo de arranque de sesión de juego
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 45, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.yellow, width: 2),
                ),
                elevation: 6,
              ),
              onPressed: () {
                // Transición limpia reemplazando la ruta actual por el contenedor del juego
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const GameScreen()),
                );
              },
              child: const Text(
                'Iniciar juego',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ==============================================================================
/// MÓDULO CONTENEDOR: ENTORNO DE EJECUCIÓN DEL MOTOR FLAME
/// ==============================================================================
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PacManGame _game = PacManGame();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SizedBox(
          width: 900,
          height: 450,
          // Arquitectura de capas en Stack: integra el canvas de Flame y la botonera móvil
          child: Stack(
            children: [
              GameWidget<PacManGame>.controlled(
                gameFactory: () => _game,
                overlayBuilderMap: {
                  'GameOverMenu': (context, game) => GameOverOverlay(game),
                  'GameWinMenu': (context, game) => GameWinOverlay(game),
                },
              ),
              if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS))
                MobileControlsWidget(game: _game),
            ],
          ),
        ),
      ),
    );
  }
}

/// ==============================================================================
/// NÚCLEO LÓGICO DEL VIDEOJUEGO ([FlameGame])
/// ==============================================================================
class PacManGame extends FlameGame with KeyboardEvents {
  late PlayerPacman player;
  int score = 0;
  int highScore = 0;
  bool isGameOver = false;
  bool isGameWon = false;

  // Notificador reactivo para visibilidad de controles táctiles según el estado de la partida
  final ValueNotifier<bool> showControls = ValueNotifier<bool>(true);

  // Matriz bidimensional del laberinto (1: Muro, 0: Punto, 3: Power-up, 2: Zona restringida de spawn)
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
  final double mazeOffsetX = 230.0;
  final int maxCols = 19;
  
  late TextComponent scoreText;
  late TextComponent highScoreText;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // Carga centralizada de assets gráficos
    try {
      await images.loadAll(['pacman.png', 'ghost.png', 'dot.png', 'niga.png', 'game_over.png', 'jova_logo.png']);
    } catch (e) {
      debugPrint("Error crítico al cargar recursos multimedia: $e");
    }

    // Inicialización del Head-Up Display (HUD) de puntajes
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

  /// Restablece el estado global de la partida para un nuevo ciclo de juego.
  void startGame() {
    score = 0;
    isGameOver = false;
    isGameWon = false;
    showControls.value = true;
    scoreText.text = 'SCORE: $score';
    overlays.remove('GameOverMenu');
    overlays.remove('GameWinMenu');

    children.where((c) => c is PlayerPacman || c is Ghost || c is Dot || c is Wall).toList().forEach((c) => c.removeFromParent());

    _buildGridMaze();

    player = PlayerPacman(Vector2(9, 14));
    add(player);

    add(Ghost(Vector2(9, 7)));
    add(Ghost(Vector2(10, 7)));
    add(Ghost(Vector2(9, 8)));
    add(Ghost(Vector2(10, 8)));
  }

  /// Actualiza la puntuación acumulada y evalúa condiciones de victoria/récord.
  void addScore(int points) {
    score += points;
    scoreText.text = 'SCORE: $score';

    if (score > highScore) {
      highScore = score;
      highScoreText.text = 'HIGH SCORE: $highScore';
    }

    if (children.whereType<Dot>().isEmpty) {
      triggerGameWin();
    }
  }

  /// Construye geométricamente los muros y coleccionables del laberinto.
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

  /// Valida la transitabilidad de una celda específica del laberinto.
  /// [isGhost] determina si se aplican restricciones adicionales de spawn.
  bool isWalkable(int col, int row, {bool isGhost = false}) {
    if (row < 0 || row >= mazeGrid.length) return false;
    if (col < 0 || col >= maxCols) return true; // Soporte para túneles laterales
    int cell = mazeGrid[row][col];
    if (cell == 1) return false; // Muros infranqueables estrictos
    if (cell == 2 && !isGhost) return false;
    return true;
  }

  /// Algoritmo de línea de visión (*Line of Sight*) para la IA de persecución.
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

/// ==============================================================================
/// CAPA DE CONTROLES TÁCTILES NATIVOS PARA DISPOSITIVOS MÓVILES
/// ==============================================================================
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

/// ==============================================================================
/// MENÚ SUPERPUESTO: PANTALLA DE DERROTA (GAME OVER)
/// ==============================================================================
class GameOverOverlay extends StatelessWidget {
  final PacManGame game;
  const GameOverOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Imagen de Game Over personalizada en pantalla completa
            Image.asset(
              'assets/images/game_over.png',
              height: 250,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  'GAME OVER',
                  style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.redAccent),
                );
              },
            ),
            const SizedBox(height: 15),
            Text('Puntuación: ${game.score}', style: const TextStyle(fontSize: 18, color: Colors.white)),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.yellow, width: 2),
                ),
              ),
              onPressed: () => game.startGame(),
              child: const Text('Reiniciar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

/// ==============================================================================
/// MENÚ SUPERPUESTO: PANTALLA DE VICTORIA
/// ==============================================================================
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

/// ==============================================================================
/// ENTIDAD DE JUEGO: JUGADOR (PACMAN)
/// Implementa búfer de comandos y alineación estricta en rejilla para prevenir saltos.
/// ==============================================================================
class PlayerPacman extends SpriteComponent with HasGameReference<PacManGame> {
  Vector2 gridPos;
  Vector2 moveDir = Vector2.zero();
  Vector2 nextDir = Vector2.zero();
  double moveProgress = 0.0;
  final double speed = 5.0;

  PlayerPacman(this.gridPos);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      sprite = Sprite(game.images.fromCache('pacman.png'));
    } catch (_) {}
    size = Vector2(18, 18);
    updatePixelPosition();
  }

  /// Sincroniza la posición absoluta en píxeles basada en la rejilla lógica.
  void updatePixelPosition() {
    position = Vector2(
      game.mazeOffsetX + gridPos.x * game.tileSize + 3,
      gridPos.y * game.tileSize + 3,
    );
  }

  /// Gestiona el cambio de dirección mediante búfer, permitiendo inversión instantánea en U.
  void changeDirection(Vector2 newDir) {
    if (newDir == -moveDir) {
      moveDir = newDir.clone();
      nextDir.setZero();
      moveProgress = 1.0 - moveProgress;
      gridPos.add(moveDir);
      return;
    }
    nextDir = newDir.clone();
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

    // Validación al inicio de cada celda
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

    // Interpolación de movimiento continuo
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

        if (gridPos.x < 0) {
          gridPos.x = (game.maxCols - 1).toDouble();
        } else if (gridPos.x >= game.maxCols) {
          gridPos.x = 0;
        }
        updatePixelPosition();

        if (nextDir != Vector2.zero()) {
          int nextX = (gridPos.x + nextDir.x).toInt();
          int nextY = (gridPos.y + nextDir.y).toInt();
          if (game.isWalkable(nextX, nextY, isGhost: false)) {
            moveDir = nextDir.clone();
            nextDir.setZero();
          }
        }
      }
    }

    // Colisiones con coleccionables
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

/// ==============================================================================
/// ENTIDAD COLECCIONABLE: PUNTOS ESTÁNDAR Y ENERGIZANTES (POWER-UPS)
/// ==============================================================================
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

/// ==============================================================================
/// ENTIDAD INTELIGENTE: FANTASMAS ([Ghost])
/// Implementa IA de patrullaje, persecución por línea de visión y estados de pánico.
/// ==============================================================================
class Ghost extends SpriteComponent with HasGameReference<PacManGame> {
  Vector2 gridPos;
  final Vector2 spawnGridPos = Vector2(9, 7);
  Vector2 moveDir = Vector2(0, -1);
  double moveProgress = 0.0;
  final double speed = 3.8;
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
    updatePixelPosition();
  }

  void updatePixelPosition() {
    position = Vector2(
      game.mazeOffsetX + gridPos.x * game.tileSize + 3,
      gridPos.y * game.tileSize + 3,
    );
  }

  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      super.render(canvas);
    } else {
      canvas.drawRect(size.toRect(), Paint()..color = Colors.red);
    }
  }

  /// Activa el estado de vulnerabilidad tras consumir un Power-Up.
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
        updatePixelPosition();
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
        updatePixelPosition();
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

    // Selección de ruta con validación estricta obligatoria para evitar traspasar muros
    if (moveProgress == 0.0 && game.player.isMounted) {
      final player = game.player;
      bool hasVision = game.hasLineOfSight(gridPos, player.gridPos);

      if (hasVision && !isScared) {
        Vector2 idealDir = Vector2(player.gridPos.x > gridPos.x ? 1 : (player.gridPos.x < gridPos.x ? -1 : 0), 
                                   player.gridPos.y > gridPos.y ? 1 : (player.gridPos.y < gridPos.y ? -1 : 0));
        int nextX = (gridPos.x + idealDir.x).toInt();
        int nextY = (gridPos.y + idealDir.y).toInt();
        if (idealDir != Vector2.zero() && game.isWalkable(nextX, nextY, isGhost: true)) {
          moveDir = idealDir;
        }
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
          if (game.isWalkable((gridPos.x - moveDir.x).toInt(), (gridPos.y - moveDir.y).toInt(), isGhost: true)) {
            moveDir = -moveDir;
          }
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
      } else if (gridPos.x >= game.maxCols) {
        gridPos.x = 0;
      }
      updatePixelPosition();
    }

    // Detección de colisiones contra el jugador
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

/// ==============================================================================
/// COMPONENTE ESTÁTICO: MUROS DEL LABERINTO
/// ==============================================================================
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