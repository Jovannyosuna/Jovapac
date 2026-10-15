// ==========================================
// PROYECTO: PAC-MAN ARCADE DEFINITIVO (MARCADOR INFERIOR Y HIGH SCORE)
// Autor: Gabriel Jovanny Osuna Martínez
// ==========================================

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JOVA-LAND',
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 800,
            height: 680, // Ligeramente más alto para dar espacio al panel inferior
            child: GameWidget<PacManGame>.controlled(
              gameFactory: PacManGame.new,
              overlayBuilderMap: {
                'GameOverMenu': (context, game) => GameOverOverlay(game),
                'GameWinMenu': (context, game) => GameWinOverlay(game),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class PacManGame extends FlameGame with KeyboardEvents {
  late PlayerPacman player;
  int score = 0;
  int highScore = 0; // Almacena la mayor puntuación de la sesión
  bool isGameOver = false;
  bool isGameWon = false;

  // Matriz de laberinto simétrica perfecta (19 columnas x 16 filas)
  final List<List<int>> mazeGrid = [
    [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    [1,3,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,3,1],
    [1,0,1,1,0,1,1,1,0,1,0,1,1,1,0,1,1,0,1],
    [1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],
    [1,0,1,1,0,1,0,1,1,1,1,1,0,1,0,1,1,0,1],
    [1,0,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0,0,1],
    [1,1,1,1,0,1,1,1,2,2,2,1,1,1,0,1,1,1,1],
    [0,0,0,0,0,1,2,2,2,2,2,2,2,1,0,0,0,0,0], // Túneles abiertos
    [1,1,1,1,0,1,2,2,2,2,2,2,2,1,0,1,1,1,1],
    [1,1,1,1,0,1,1,1,1,1,1,1,1,1,0,1,1,1,1],
    [1,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,1],
    [1,0,1,1,0,1,1,1,0,1,0,1,1,1,0,1,1,0,1],
    [1,3,0,1,0,0,0,0,0,0,0,0,0,0,0,1,0,3,1],
    [1,1,0,1,0,1,0,1,1,1,1,1,1,1,0,1,0,1,1],
    [1,0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,1], // Zona inferior despejada
    [1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
  ];

  final double tileSize = 36.0;
  final int maxCols = 19;
  
  // Componentes de texto para la parte inferior
  late TextComponent scoreText;
  late TextComponent highScoreText;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    await images.loadAll(['pacman.png', 'ghost.png', 'dot.png', 'niga.png']);

    // Panel de marcadores ubicado en la parte inferior (fuera del laberinto)
    double bottomUIPosition = mazeGrid.length * tileSize + 15;

    scoreText = TextComponent(
      text: 'SCORE: 0',
      position: Vector2(100, bottomUIPosition),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );

    highScoreText = TextComponent(
      text: 'HIGH SCORE: 0',
      position: Vector2(450, bottomUIPosition),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.yellow, fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );

    add(scoreText);
    add(highScoreText);

    startGame();
  }

  void startGame() {
    score = 0;
    isGameOver = false;
    isGameWon = false;
    scoreText.text = 'SCORE: $score';
    overlays.remove('GameOverMenu');
    overlays.remove('GameWinMenu');

    // Limpiar entidades anteriores del juego
    children.where((c) => c is PlayerPacman || c is Ghost || c is Dot || c is Wall).toList().forEach((c) => c.removeFromParent());

    _buildGridMaze();

    // Spawn exacto: Penúltimo nivel inferior (fila 14), justo al centro (columna 9)
    player = PlayerPacman(Vector2(9, 14));
    add(player);

    add(Ghost(Vector2(9, 7)));
    add(Ghost(Vector2(10, 7)));
    add(Ghost(Vector2(9, 8)));
    add(Ghost(Vector2(10, 8)));
  }

  void addScore(int points) {
    score += points;
    scoreText.text = 'SCORE: $score';

    // Actualizar el récord máximo en tiempo real si se supera
    if (score > highScore) {
      highScore = score;
      highScoreText.text = 'HIGH SCORE: $highScore';
    }

    if (children.whereType<Dot>().isEmpty) {
      triggerGameWin();
    }
  }

  void _buildGridMaze() {
    for (int row = 0; row < mazeGrid.length; row++) {
      for (int col = 0; col < mazeGrid[row].length; col++) {
        int cell = mazeGrid[row][col];
        Vector2 pos = Vector2(col * tileSize, row * tileSize);

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

  bool isWalkable(int col, int row, {bool isGhost = false}) {
    if (row < 0 || row >= mazeGrid.length) return false;
    if (col < 0 || col >= maxCols) return true;
    int cell = mazeGrid[row][col];
    if (cell == 1) return false;
    if (cell == 2 && !isGhost) return false;
    return true;
  }

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
    overlays.add('GameOverMenu');
  }

  void triggerGameWin() {
    if (isGameOver || isGameWon) return;
    isGameWon = true;
    overlays.add('GameWinMenu');
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (isGameOver || isGameWon) return KeyEventResult.ignored;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
        player.nextDir = Vector2(-1, 0);
      } else if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
        player.nextDir = Vector2(1, 0);
      } else if (keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
        player.nextDir = Vector2(0, -1);
      } else if (keysPressed.contains(LogicalKeyboardKey.arrowDown)) {
        player.nextDir = Vector2(0, 1);
      }
    }
    return KeyEventResult.handled;
  }
}

// Interfaz de Game Over centrada con botón de reinicio
class GameOverOverlay extends StatelessWidget {
  final PacManGame game;
  const GameOverOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.blue.shade900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('GAME OVER', style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              const SizedBox(height: 12),
              Text('Puntuación: ${game.score}', style: const TextStyle(fontSize: 20, color: Colors.white)),
              Text('Récord Máximo: ${game.highScore}', style: const TextStyle(fontSize: 18, color: Colors.yellow)),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
                onPressed: () => game.startGame(),
                child: const Text('Reiniciar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Interfaz de Victoria centrada con botón de reinicio
class GameWinOverlay extends StatelessWidget {
  final PacManGame game;
  const GameWinOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.blue.shade900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.yellow, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¡VICTORIA!', style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: Colors.yellow)),
              const SizedBox(height: 12),
              Text('¡Comiste todos los puntos!\nPuntuación: ${game.score}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, color: Colors.white)),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12)),
                onPressed: () => game.startGame(),
                child: const Text('Reiniciar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Jugador Pac-Man con Snap-to-Grid
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
    sprite = Sprite(game.images.fromCache('pacman.png'));
    size = Vector2(28, 28);
    position = Vector2(gridPos.x * game.tileSize + 4, gridPos.y * game.tileSize + 4);
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

      double startX = gridPos.x * game.tileSize + 4;
      double startY = gridPos.y * game.tileSize + 4;
      double endX = (gridPos.x + moveDir.x) * game.tileSize + 4;
      double endY = (gridPos.y + moveDir.y) * game.tileSize + 4;

      position.x = startX + (endX - startX) * min(moveProgress, 1.0);
      position.y = startY + (endY - startY) * min(moveProgress, 1.0);

      if (moveProgress >= 1.0) {
        gridPos.add(moveDir);
        moveProgress = 0.0;

        if (gridPos.x < 0) {
          gridPos.x = (game.maxCols - 1).toDouble();
          position.x = gridPos.x * game.tileSize + 4;
        } else if (gridPos.x >= game.maxCols) {
          gridPos.x = 0;
          position.x = gridPos.x * game.tileSize + 4;
        }
      }
    }

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

class Dot extends SpriteComponent with HasGameReference<PacManGame> {
  Vector2 gridPos;
  bool isPowerUp;
  Dot(this.gridPos, {this.isPowerUp = false});

  @override
  Future<void> onLoad() async {
    super.onLoad();
    sprite = Sprite(game.images.fromCache('dot.png'));
    size = isPowerUp ? Vector2(16, 16) : Vector2(7, 7);
    position = Vector2(
      gridPos.x * game.tileSize + (game.tileSize - size.x) / 2,
      gridPos.y * game.tileSize + (game.tileSize - size.y) / 2,
    );
  }
}

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
    sprite = Sprite(game.images.fromCache('ghost.png'));
    size = Vector2(28, 28);
    position = Vector2(gridPos.x * game.tileSize + 4, gridPos.y * game.tileSize + 4);
  }

  void triggerPanic() {
    if (!isDead && !isLeavingSpawn) {
      isScared = true;
      scaredTimer = 8.0;
      sprite = Sprite(game.images.fromCache('niga.png'));
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isGameWon) return;

    if (isDead) {
      Vector2 targetSpawnPx = Vector2(spawnGridPos.x * game.tileSize + 4, spawnGridPos.y * game.tileSize + 4);
      position = position + (targetSpawnPx - position).normalized() * 260 * dt;
      if (position.distanceTo(targetSpawnPx) < 8) {
        isDead = false;
        isScared = false;
        isLeavingSpawn = true;
        gridPos = spawnGridPos.clone();
        position = Vector2(gridPos.x * game.tileSize + 4, gridPos.y * game.tileSize + 4);
        sprite = Sprite(game.images.fromCache('ghost.png'));
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
      double startX = gridPos.x * game.tileSize + 4;
      double startY = gridPos.y * game.tileSize + 4;
      double endX = (gridPos.x + moveDir.x) * game.tileSize + 4;
      double endY = (gridPos.y + moveDir.y) * game.tileSize + 4;

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
        sprite = Sprite(game.images.fromCache('ghost.png'));
      }
    }

    if (moveProgress == 0.0) {
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
    double startX = gridPos.x * game.tileSize + 4;
    double startY = gridPos.y * game.tileSize + 4;
    double endX = (gridPos.x + moveDir.x) * game.tileSize + 4;
    double endY = (gridPos.y + moveDir.y) * game.tileSize + 4;

    position.x = startX + (endX - startX) * min(moveProgress, 1.0);
    position.y = startY + (endY - startY) * min(moveProgress, 1.0);

    if (moveProgress >= 1.0) {
      gridPos.add(moveDir);
      moveProgress = 0.0;

      if (gridPos.x < 0) {
        gridPos.x = (game.maxCols - 1).toDouble();
        position.x = gridPos.x * game.tileSize + 4;
      } else if (gridPos.x >= game.maxCols) {
        gridPos.x = 0;
        position.x = gridPos.x * game.tileSize + 4;
      }
    }

    if (toRect().overlaps(game.player.toRect())) {
      if (isScared) {
        isDead = true;
        sprite = Sprite(game.images.fromCache('dot.png'));
        game.addScore(500);
      } else {
        game.triggerGameOver();
      }
    }
  }
}

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