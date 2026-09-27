import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pac-Man Personalizado',
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: PacManGame(),
      ),
    );
  }
}

class PacManGame extends FlameGame with KeyboardEvents {
  late PlayerPacman player;
  int score = 0;

  @override
  Color backgroundColor() {
    return const Color(0xFF111111);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Añadimos al jugador
    player = PlayerPacman();
    add(player);

    // Generamos ítems en el mapa
    for (int i = 1; i <= 5; i++) {
      add(Dot(Vector2(100.0 + (i * 80), 200.0)));
      add(Dot(Vector2(100.0 + (i * 80), 350.0)));
    }

    // Añadimos fantasmas
    add(Ghost(Vector2(200, 150)));
    add(Ghost(Vector2(400, 300)));
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    final isKeyDown = event is KeyDownEvent || event is KeyRepeatEvent;

    if (isKeyDown) {
      if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
        player.moveDirection = Vector2(-1, 0);
      } else if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
        player.moveDirection = Vector2(1, 0);
      } else if (keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
        player.moveDirection = Vector2(0, -1);
      } else if (keysPressed.contains(LogicalKeyboardKey.arrowDown)) {
        player.moveDirection = Vector2(0, 1);
      }
    }
    return KeyEventResult.handled;
  }
}

// Jugador con carga segura de imagen o respaldo geométrico
class PlayerPacman extends PositionComponent with HasGameRef<PacManGame> {
  Vector2 moveDirection = Vector2.zero();
  final double speed = 200.0;
  Sprite? customSprite;

  PlayerPacman() {
    size = Vector2(40, 40);
    position = Vector2(100, 100);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      customSprite = await gameRef.loadSprite('pacman.png');
    } catch (e) {
      debugPrint("No se encontró 'pacman.png', usando diseño por defecto.");
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += moveDirection * speed * dt;

    // Colisión con puntos
    gameRef.children.whereType<Dot>().toList().forEach((dot) {
      if (toRect().overlaps(dot.toRect())) {
        dot.removeFromParent();
        gameRef.score += 10;
        debugPrint("Puntuación actual: ${gameRef.score}");
      }
    });
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (customSprite != null) {
      customSprite!.render(canvas, size: size);
    } else {
      // Respaldo visual si la imagen no carga
      final paint = Paint()..color = Colors.yellow;
      canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, paint);
      final eyePaint = Paint()..color = Colors.black;
      canvas.drawCircle(Offset(size.x / 2 + 5, size.y / 2 - 8), 4, eyePaint);
    }
  }
}

// Ítems con carga segura
class Dot extends PositionComponent with HasGameRef<PacManGame> {
  Sprite? customSprite;

  Dot(Vector2 position) {
    this.position = position;
    size = Vector2(16, 16);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      customSprite = await gameRef.loadSprite('dot.png');
    } catch (_) {}
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (customSprite != null) {
      customSprite!.render(canvas, size: size);
    } else {
      final paint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, paint);
    }
  }
}

// Fantasmas con carga segura
class Ghost extends PositionComponent with HasGameRef<PacManGame> {
  Vector2 velocity = Vector2(80, 60);
  Sprite? customSprite;

  Ghost(Vector2 startPosition) {
    position = startPosition;
    size = Vector2(40, 40);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      customSprite = await gameRef.loadSprite('ghost.png');
    } catch (_) {}
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;

    if (position.x <= 50 || position.x >= 600) {
      velocity.x = -velocity.x;
    }
    if (position.y <= 50 || position.y >= 400) {
      velocity.y = -velocity.y;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (customSprite != null) {
      customSprite!.render(canvas, size: size);
    } else {
      final paint = Paint()..color = Colors.red;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.x, size.y),
          const Radius.circular(20),
        ),
        paint,
      );
    }
  }
}