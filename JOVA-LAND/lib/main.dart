// ==========================================
// PROYECTO: JOVA-LAND (MODO HORIZONTAL / LANDSCAPE)
// Autor: Gabriel Jovanny Osuna Martínez
// ==========================================

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Forzar orientación horizontal para una experiencia limpia tipo arcade
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JOVA-LAND Landscape',
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 850,
            height: 480,
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
  int highScore = 0;
  bool isGameOver = false;
  bool isGameWon = false;

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

  final double tileSize = 28.0; // Tamaño reducido para adaptarse perfectamente en horizontal
  final int maxCols = 19;
  
  late TextComponent scoreText;
  late TextComponent highScoreText;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      await images.loadAll(['pacman.png', 'ghost.png', 'dot.png', 'niga.png']);
    } catch (e) {
      debugPrint("Error al cargar imágenes: $e");
    }

    // Textos de puntuación ubicados en la parte superior derecha
    scoreText = TextComponent(
      text: 'SCORE: 0',
      position: Vector2(560, 20),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );

    highScoreText = TextComponent(
      text: 'HIGH SCORE: 0',
      position: Vector2(560, 55),
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.yellow, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );

    add(scoreText);
    add(highScoreText);

    // Controles táctiles organizados ergonómicamente en el lado derecho de la pantalla horizontal
    add(MobileButton(Vector2(680, 230), Vector2(65, 55), '←', Vector2(-1, 0)));
    add(MobileButton(Vector2(750, 160), Vector2(65, 55), '↑', Vector2(0, -1)));
    add(MobileButton(Vector2(750, 300), Vector2(65, 55), '↓', Vector2(0, 1)));
    add(MobileButton(Vector2(820, 230), Vector2(65, 55), '→', Vector2(1, 0)));
    
    // Botón de Reiniciar en la parte superior derecha
    add(MobileButton(Vector2(720, 400), Vector2(130, 45), 'REINICIAR', Vector2(0, 0), isReset: true));

    startGame();
  }

  void startGame() {
    score = 0;
    isGameOver = false;
    isGameWon = false;
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

class MobileButton extends PositionComponent with TapCallbacks, HasGameReference<PacManGame> {
  final Vector2 buttonSize;
  final String label;
  final Vector2 direction;
  final bool isReset;

  MobileButton(Vector2 pos, this.buttonSize, this.label, this.direction, {this.isReset = false}) {
    position = pos;
    size = buttonSize;
  }

  @override
  void onTapDown(TapDownEvent event) {
    super.onTapDown(event);
    if (isReset) {
      game.startGame();
    } else {
      game.player.nextDir = direction;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()..color = Colors.blue.shade800;
    final borderPaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rect = size.toRect();
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), borderPaint);

    final textSpan = TextSpan(
      text: label,
      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.x - textPainter.width) / 2, (size.y - textPainter.height) / 2),
    );
  }
}

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
              const Text('GAME OVER', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.redAccent)),
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
              const Text('¡VICTORIA!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.yellow)),
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
    size = Vector2(22, 22);
    position = Vector2(gridPos.x * game.tileSize + 3, gridPos.y * game.tileSize + 3);
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

      double startX = gridPos.x * game.tileSize + 3;
      double startY = gridPos.y * game.tileSize + 3;
      double endX = (gridPos.x + moveDir.x) * game.tileSize + 3;
      double endY = (gridPos.y + moveDir.y) * game.tileSize + 3;

      position.x = startX + (endX - startX) * min(moveProgress, 1.0);
      position.y = startY + (endY - startY) * min(moveProgress, 1.0);

      if (moveProgress >= 1.0) {
        gridPos.add(moveDir);
        moveProgress = 0.0;

        if (gridPos.x < 0) {
          gridPos.x = (game.maxCols - 1).toDouble();
          position.x = gridPos.x * game.tileSize + 3;
        } else if (gridPos.x >= game.maxCols) {
          gridPos.x = 0;
          position.x = gridPos.x * game.tileSize + 3;
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
    try {
      sprite = Sprite(game.images.fromCache('dot.png'));
    } catch (_) {}
    size = isPowerUp ? Vector2(14, 14) : Vector2(6, 6);
    position = Vector2(
      gridPos.x * game.tileSize + (game.tileSize - size.x) / 2,
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
    size = Vector2(22, 22);
    position = Vector2(gridPos.x * game.tileSize + 3, gridPos.y * game.tileSize + 3);
  }

  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      super.render(canvas);
    } else {
      canvas.drawRect(size.toRect(), Paint()..color = Colors.red);
    }
  }

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
      Vector2 targetSpawnPx = Vector2(spawnGridPos.x * game.tileSize + 3, spawnGridPos.y * game.tileSize + 3);
      position = position + (targetSpawnPx - position).normalized() * 260 * dt;
      if (position.distanceTo(targetSpawnPx) < 8) {
        isDead = false;
        isScared = false;
        isLeavingSpawn = true;
        gridPos = spawnGridPos.clone();
        position = Vector2(gridPos.x * game.tileSize + 3, gridPos.y * game.tileSize + 3);
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
      double startX = gridPos.x * game.tileSize + 3;
      double startY = gridPos.y * game.tileSize + 3;
      double endX = (gridPos.x + moveDir.x) * game.tileSize + 3;
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
    double startX = gridPos.x * game.tileSize + 3;
    double startY = gridPos.y * game.tileSize + 3;
    double endX = (gridPos.x + moveDir.x) * game.tileSize + 3;
    double endY = (gridPos.y + moveDir.y) * game.tileSize + 3;

    position.x = startX + (endX - startX) * min(moveProgress, 1.0);
    position.y = startY + (endY - startY) * min(moveProgress, 1.0);

    if (moveProgress >= 1.0) {
      gridPos.add(moveDir);
      moveProgress = 0.0;

      if (gridPos.x < 0) {
        gridPos.x = (game.maxCols - 1).toDouble();
        position.x = gridPos.x * game.tileSize + 3;
      } else if (gridPos.x >= game.maxCols) {
        gridPos.x = 0;
        position.x = gridPos.x * game.tileSize + 3;
      }
    }

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