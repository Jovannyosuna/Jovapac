// ==============================================================================
// PROYECTO: JOVA-LAND (ARCADE PACMAN-STYLE)
// ARCHIVO: lib/main.dart
// AUTOR: Gabriel Jovanny Osuna Martínez
// DESCRIPCIÓN TÉCNICA: 
// Implementación de un videojuego arcade 2D desarrollado con Flutter y el motor 
// Flame. Utiliza una arquitectura basada en componentes (Component-based game 
// engine), un sistema de movimiento basado en rejilla estrictamente alineada 
// (grid-based movement), control táctil por gestos (PanUpdate), gestión de 
// estados del juego y renderizado vectorizado de un laberinto personalizado 
// definido mediante una matriz bidimensional exacta.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import 'dart:math';

/// Punto de entrada principal de la aplicación.
/// Configura la orientación horizontal forzada para plataformas móviles 
/// y activa el modo de pantalla completa inmersiva (Immersive Sticky).
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

/// Widget raíz de la aplicación utilizando MaterialApp en tema oscuro.
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

// ==========================================
// PANTALLA DE INICIO (MENÚ PRINCIPAL)
// ==========================================
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
            // Logotipo principal con respaldo de texto en caso de error de asset
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
            // Botón de inicio que realiza reemplazo de ruta hacia la pantalla de juego
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

// ==========================================
// CONTENEDOR DE JUEGO Y GESTIÓN TÁCTIL
// ==========================================
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final PacManGame _game = PacManGame();
    return Scaffold(
      backgroundColor: Colors.black,
      // GestureDetector implementa control de gestos de deslizamiento (Swipe/Pan)
      // para interpretar la dirección del jugador en pantallas táctiles.
      body: GestureDetector(
        onPanUpdate: (details) {
          if (!_game.isGameOver && !_game.isGameWon) {
            if (details.delta.dx.abs() > details.delta.dy.abs()) {
              if (details.delta.dx > 1.5) {
                _game.player.changeDirection(Vector2(1, 0)); // Derecha
              } else if (details.delta.dx < -1.5) {
                _game.player.changeDirection(Vector2(-1, 0)); // Izquierda
              }
            } else {
              if (details.delta.dy > 1.5) {
                _game.player.changeDirection(Vector2(0, 1)); // Abajo
              } else if (details.delta.dy < -1.5) {
                _game.player.changeDirection(Vector2(0, -1)); // Arriba
              }
            }
          }
        },
        child: Center(
          child: SizedBox(
            width: 900,
            height: 450,
            child: Stack(
              children: [
                // Instancia del contenedor de Flame Game con soporte de Overlays UI
                GameWidget<PacManGame>.controlled(
                  gameFactory: () => _game,
                  overlayBuilderMap: {
                    'GameOverMenu': (context, game) => GameOverOverlay(game),
                    'GameWinMenu': (context, game) => GameWinOverlay(game),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// NÚCLEO DE LA LÓGICA DE JUEGO (FLAME GAME)
// ==========================================
class PacManGame extends FlameGame with KeyboardEvents {
  late PlayerPacman player;
  int score = 0;
  int highScore = 0;
  bool isGameOver = false;
  bool isGameWon = false;

  /// Matriz bidimensional oficial del laberinto (27 columnas x 16 filas).
  /// Convenciones de celdas:
  /// - 1: Muro estructural (Infranqueable).
  /// - 0: Pasillo con punto estándar de puntuación.
  /// - 2: Zona interior de la casa de los fantasmas (restringida para el jugador).
  /// - 3: SuperPunto (Power-Up / Energizante).
  final List<List<int>> mazeGrid = [
    [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    [1,3,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,3,1],
    [1,0,1,1,1,0,1,1,0,1,1,1,0,1,0,1,1,1,0,1,1,0,1,1,1,0,1],
    [1,0,1,0,0,0,0,0,3,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,1,0,1],
    [1,0,1,0,1,1,1,1,0,1,0,1,1,1,1,1,0,1,0,1,1,1,1,0,1,0,1],
    [1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1],
    [1,1,1,1,0,1,1,1,0,1,1,1,2,2,2,1,1,1,0,1,1,1,0,1,1,1,1],
    [0,0,0,0,0,0,0,0,0,1,2,2,2,2,2,2,2,1,0,0,0,0,0,0,0,0,0],
    [1,1,1,1,0,1,1,1,0,1,2,2,2,2,2,2,2,1,0,1,1,1,0,1,1,1,1],
    [1,0,0,0,0,0,1,1,0,1,1,1,1,1,1,1,1,1,0,1,1,0,0,0,0,0,1],
    [1,0,1,1,1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1,1,1,0,1],
    [1,0,0,0,1,0,1,1,0,1,1,1,0,1,0,1,1,1,0,1,1,0,1,0,0,0,1],
    [1,0,1,0,1,3,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,3,1,0,1,0,1],
    [1,0,1,0,1,1,0,1,0,1,0,1,1,1,1,1,1,1,0,1,0,1,1,0,1,0,1],
    [1,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,1],
    [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
  ];

  final double tileSize = 24.0;
  final double mazeOffsetX = 126.0; // Offset para centrado simétrico horizontal automático
  final int maxCols = 27;
  
  late TextComponent scoreText;
  late TextComponent highScoreText;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // Precarga centralizada de recursos gráficos (sprites e imágenes de interfaz)
    try {
      await images.loadAll(['pacman.png', 'ghost.png', 'dot.png', 'niga.png', 'game_over.png', 'jova_logo.png']);
    } catch (e) {
      debugPrint("Error al cargar imágenes: $e");
    }

    // Inicialización de componentes de texto para el marcador HUD
    scoreText = TextComponent(
      text: 'SCORE: 0',
      position: Vector2(126, 4),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );

    highScoreText = TextComponent(
      text: 'HIGH SCORE: 0',
      position: Vector2(670, 4),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.yellow, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );

    add(scoreText);
    add(highScoreText);

    startGame();
  }

  /// Inicializa o reinicia las variables de estado, puntuación y entidades del juego.
  void startGame() {
    score = 0;
    isGameOver = false;
    isGameWon = false;
    scoreText.text = 'SCORE: $score';
    overlays.remove('GameOverMenu');
    overlays.remove('GameWinMenu');

    // Limpieza de entidades previas en el árbol de componentes del juego
    children.where((c) => c is PlayerPacman || c is Ghost || c is Dot || c is Wall).toList().forEach((c) => c.removeFromParent());

    _buildGridMaze();

    // Spawning del jugador en posición de rejilla inicial
    player = PlayerPacman(Vector2(13, 12));
    add(player);

    // Spawning de los 4 fantasmas dentro de la casa central
    add(Ghost(Vector2(13, 7)));
    add(Ghost(Vector2(14, 7)));
    add(Ghost(Vector2(13, 8)));
    add(Ghost(Vector2(14, 8)));
  }

  /// Incrementa la puntuación y evalúa condiciones de victoria.
  void addScore(int points) {
    score += points;
    scoreText.text = 'SCORE: $score';

    if (score > highScore) {
      highScore = score;
      highScoreText.text = 'HIGH SCORE: $highScore';
    }

    // Si ya no quedan nodos de tipo Dot, se activa la condición de victoria
    if (children.whereType<Dot>().isEmpty) {
      triggerGameWin();
    }
  }

  /// Construye dinámicamente los componentes estáticos (Muros y Puntos) basándose en la matriz.
  void _buildGridMaze() {
    for (int row = 0; row < mazeGrid.length; row++) {
      for (int col = 0; col < mazeGrid[row].length; col++) {
        int cell = mazeGrid[row][col];
        Vector2 pos = Vector2(mazeOffsetX + (col * tileSize), 24 + (row * tileSize));

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

  /// Valida si una coordenada en la rejilla es transitable para entidades o jugadores.
  bool isWalkable(int col, int row, {bool isGhost = false}) {
    if (row < 0 || row >= mazeGrid.length) return false;
    if (col < 0 || col >= maxCols) return true; // Soporte para túneles laterales de teletransporte
    int cell = mazeGrid[row][col];
    if (cell == 1) return false; // Muros estrictamente bloqueados
    if (cell == 2 && !isGhost) return false; // Zona de casa de fantasmas restringida a Pacman
    return true;
  }

  /// Algoritmo de visión directa (Line of Sight) para la inteligencia artificial de los fantasmas.
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
        if (startX >= 0 && startX < maxCols && mazeGrid[y][startX] == 1) return false;
      }
      return true;
    }
    return false;
  }

  void triggerGameOver() {
    if (isGameOver || isGameWon) return;
    isGameOver = true;
    overlays.add('GameOverMenu');
  }

  void triggerGameWin() {
    if (isGameOver || isGameWon) return;
    isGameWon = true;
    overlays.add('GameWinMenu');
  }

  /// Manejo opcional de eventos de teclado (Flechas direccionales) para testing en desktop/web.
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

// ==========================================
// MENÚS SUPERPUESTOS (UI OVERLAYS)
// ==========================================
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

// ==========================================
// ENTIDAD: PACMAN (JUGADOR)
// ==========================================
class PlayerPacman extends SpriteComponent with HasGameReference<PacManGame> {
  Vector2 gridPos;
  Vector2 moveDir = Vector2.zero();
  Vector2 nextDir = Vector2.zero();
  double moveProgress = 0.0;
  final double speed = 4.0;

  PlayerPacman(this.gridPos);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      sprite = Sprite(game.images.fromCache('pacman.png'));
    } catch (_) {}
    size = Vector2(16, 16);
    updatePixelPosition();
  }

  /// Calcula la posición absoluta en pixeles en base a las coordenadas de la rejilla.
  void updatePixelPosition() {
    position = Vector2(
      game.mazeOffsetX + gridPos.x * game.tileSize + 4,
      24 + gridPos.y * game.tileSize + 4,
    );
  }

  /// Almacena el siguiente cambio de dirección deseado por el usuario (Buffer de entrada).
  void changeDirection(Vector2 newDir) {
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

    // Gestión de transición de celdas y validación de giros en intersecciones
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

    // Interpolación suave de movimiento celda por celda (Grid-locked interpolation)
    if (moveDir != Vector2.zero()) {
      moveProgress += speed * dt;

      double startX = game.mazeOffsetX + gridPos.x * game.tileSize + 4;
      double startY = 24 + gridPos.y * game.tileSize + 4;
      double endX = game.mazeOffsetX + (gridPos.x + moveDir.x) * game.tileSize + 4;
      double endY = 24 + (gridPos.y + moveDir.y) * game.tileSize + 4;

      position.x = startX + (endX - startX) * min(moveProgress, 1.0);
      position.y = startY + (endY - startY) * min(moveProgress, 1.0);

      if (moveProgress >= 1.0) {
        gridPos.add(moveDir);
        moveProgress = 0.0;

        // Lógica de túneles laterales (Wrapping)
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

    // Detección de colisiones con los puntos (Dots / Power-Ups)
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

// ==========================================
// ENTIDAD: PUNTO / POWER-UP (DOT)
// ==========================================
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
    size = isPowerUp ? Vector2(8, 8) : Vector2(4, 4);
    position = Vector2(
      game.mazeOffsetX + gridPos.x * game.tileSize + (game.tileSize - size.x) / 2,
      24 + gridPos.y * game.tileSize + (game.tileSize - size.y) / 2,
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

// ==========================================
// ENTIDAD: FANTASMA (ENEMIGO CON IA BÁSICA)
// ==========================================
class Ghost extends SpriteComponent with HasGameReference<PacManGame> {
  Vector2 gridPos;
  final Vector2 spawnGridPos = Vector2(13, 7);
  Vector2 moveDir = Vector2(0, -1);
  double moveProgress = 0.0;
  final double speed = 3.5;
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
    size = Vector2(16, 16);
    updatePixelPosition();
  }

  void updatePixelPosition() {
    position = Vector2(
      game.mazeOffsetX + gridPos.x * game.tileSize + 4,
      24 + gridPos.y * game.tileSize + 4,
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

  /// Activa el estado de pánico (Power-Up consumido por Pacman).
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

    // Estado de "Muerto": Retorno automático al punto de respawn central
    if (isDead) {
      Vector2 targetSpawnPx = Vector2(game.mazeOffsetX + spawnGridPos.x * game.tileSize + 4, 24 + spawnGridPos.y * game.tileSize + 4);
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

    // Estado inicial: Salida automatizada desde la casa de los fantasmas
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
      double startX = game.mazeOffsetX + gridPos.x * game.tileSize + 4;
      double startY = 24 + gridPos.y * game.tileSize + 4;
      double endX = game.mazeOffsetX + (gridPos.x + moveDir.x) * game.tileSize + 4;
      double endY = 24 + (gridPos.y + moveDir.y) * game.tileSize + 4;

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

    // Inteligencia artificial de persecución basada en visibilidad directa o elecciones aleatorias
    if (moveProgress == 0.0 && game.player.isMounted) {
      final player = game.player;
      bool hasVision = game.hasLineOfSight(gridPos, player.gridPos);

      if (hasVision) {
        Vector2 targetDir = Vector2(
          player.gridPos.x > gridPos.x ? 1.0 : (player.gridPos.x < gridPos.x ? -1.0 : 0.0),
          player.gridPos.y > gridPos.y ? 1.0 : (player.gridPos.y < gridPos.y ? -1.0 : 0.0),
        );

        if (isScared) {
          Vector2 fleeDir = -targetDir;
          int fleeX = (gridPos.x + fleeDir.x).toInt();
          int fleeY = (gridPos.y + fleeDir.y).toInt();
          if (fleeDir != Vector2.zero() && game.isWalkable(fleeX, fleeY, isGhost: true)) {
            moveDir = fleeDir;
          } else {
            _pickRandomValidDir();
          }
        } else {
          int nextX = (gridPos.x + targetDir.x).toInt();
          int nextY = (gridPos.y + targetDir.y).toInt();
          if (targetDir != Vector2.zero() && game.isWalkable(nextX, nextY, isGhost: true)) {
            moveDir = targetDir;
          } else {
            _pickRandomValidDir();
          }
        }
      } else {
        _pickRandomValidDir();
      }
    }

    moveProgress += speed * dt;
    double startX = game.mazeOffsetX + gridPos.x * game.tileSize + 4;
    double startY = 24 + gridPos.y * game.tileSize + 4;
    double endX = game.mazeOffsetX + (gridPos.x + moveDir.x) * game.tileSize + 4;
    double endY = 24 + (gridPos.y + moveDir.y) * game.tileSize + 4;

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

    // Colisión entre Fantasma y Pacman
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

  /// Selecciona una dirección aleatoria válida en intersecciones cuando no hay línea de visión directa.
  void _pickRandomValidDir() {
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

// ==========================================
// COMPONENTE: MURO ESTRUCTURAL (WALL)
// ==========================================
class Wall extends PositionComponent {
  Wall(Vector2 pos, Vector2 sz) {
    position = pos;
    size = sz;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()..color = const Color(0xFF1E1EEB); // Azul clásico estilo arcade
    canvas.drawRect(size.toRect(), paint);
  }
}