// ==========================================
// PROYECTO: PAC-MAN PERSONALIZADO (FLUTTER & FLAME)
// Autor: Gabriel Jovanny Osuna Martínez
// Descripción: Motor de juego arcade desarrollado en Flutter 
// utilizando el motor Flame, con soporte para movimiento ortogonal,
// colisiones estrictas, IA de fantasmas y modo pánico.
// ==========================================

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import 'dart:math';

/// Punto de entrada principal de la aplicación.
void main() {
  runApp(const MyApp());
}

/// [MyApp] Configura el tema visual general de la aplicación y el contenedor raíz.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pac-Man Personalizado - PC',
      theme: ThemeData.dark(),
      home: const Scaffold(
        body: GameWidget.controlled(gameFactory: PacManGame.new),
      ),
    );
  }
}

/// [PacManGame] Núcleo principal del juego que administra el ciclo de vida,
/// la carga de recursos gráficos, el estado global y los eventos de teclado.
class PacManGame extends FlameGame with KeyboardEvents {
  late PlayerPacman player;
  int score = 0;
  bool isGameOver = false;

  @override
  Color backgroundColor() => const Color(0xFF000000); // Fondo clásico negro estilo arcade

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Precarga obligatoria de todos los assets gráficos para evitar retrasos en web
    await images.loadAll(['pacman.png', 'ghost.png', 'dot.png', 'niga.png']);
    
    // Inicialización del juego y mapa
    startGame();
  }

  /// Reinicia o inicializa los componentes del juego a su estado por defecto.
  void startGame() {
    score = 0;
    isGameOver = false;
    removeAll(children);

    // 1. Construcción del laberinto extendido
    _buildExpandedMaze();

    // 2. Generación de puntos coleccionables en los pasillos
    _generateCleanDots();

    // 3. Creación del personaje principal
    player = PlayerPacman();
    add(player);

    // 4. Creación de los 4 fantasmas dentro de la caja central de respawn
    add(Ghost(Vector2(570, 360)));
    add(Ghost(Vector2(610, 360)));
    add(Ghost(Vector2(650, 360)));
    add(Ghost(Vector2(690, 360)));
  }

  /// Dibuja las paredes físicas que conforman la estructura del laberinto.
  void _buildExpandedMaze() {
    final walls = [
      // Bordes exteriores del área de juego
      Wall(Vector2(80, 40), Vector2(1120, 20)), // Superior
      Wall(Vector2(80, 40), Vector2(20, 720)),  // Izquierdo
      Wall(Vector2(1180, 40), Vector2(20, 740)), // Derecho
      Wall(Vector2(80, 740), Vector2(1120, 20)), // Inferior

      // Obstáculos y bloques internos simétricos
      Wall(Vector2(160, 100), Vector2(120, 70)),
      Wall(Vector2(320, 100), Vector2(180, 70)),
      Wall(Vector2(540, 100), Vector2(180, 70)),
      Wall(Vector2(760, 100), Vector2(180, 70)),
      Wall(Vector2(980, 100), Vector2(120, 70)),

      Wall(Vector2(160, 210), Vector2(120, 90)),
      Wall(Vector2(320, 210), Vector2(70, 200)),
      Wall(Vector2(430, 210), Vector2(90, 70)),
      Wall(Vector2(740, 210), Vector2(90, 70)),
      Wall(Vector2(870, 210), Vector2(70, 200)),
      Wall(Vector2(980, 210), Vector2(120, 90)),

      // Caja central de respawn para los fantasmas (con apertura superior)
      Wall(Vector2(480, 320), Vector2(100, 20)), 
      Wall(Vector2(680, 320), Vector2(100, 20)), 
      Wall(Vector2(480, 450), Vector2(300, 20)), 
      Wall(Vector2(480, 320), Vector2(20, 140)), 
      Wall(Vector2(760, 320), Vector2(20, 140)), 

      // Obstáculos de la zona inferior
      Wall(Vector2(160, 340), Vector2(120, 80)),
      Wall(Vector2(320, 450), Vector2(70, 110)),
      Wall(Vector2(430, 500), Vector2(90, 60)),
      Wall(Vector2(740, 500), Vector2(90, 60)),
      Wall(Vector2(870, 450), Vector2(70, 110)),
      Wall(Vector2(980, 340), Vector2(120, 80)),

      Wall(Vector2(160, 460), Vector2(120, 70)),
      Wall(Vector2(980, 460), Vector2(120, 70)),

      Wall(Vector2(160, 570), Vector2(220, 50)),
      Wall(Vector2(420, 600), Vector2(420, 50)),
      Wall(Vector2(880, 570), Vector2(220, 50)),
    ];

    for (var w in walls) {
      add(w);
    }
  }

  /// Distribuye los puntos coleccionables evitando colocarlos sobre las paredes.
  void _generateCleanDots() {
    final powerUpCoords = [
      Vector2(120, 75),
      Vector2(1140, 75),
      Vector2(120, 690),
      Vector2(1140, 690),
      Vector2(630, 180),
      Vector2(250, 650),
      Vector2(1010, 650),
    ];

    for (double x = 115; x < 1170; x += 55) {
      for (double y = 75; y < 710; y += 55) {
        if (!_isHittingWall(x, y)) {
          bool isPower = powerUpCoords.any((p) => (p.x - x).abs() < 20 && (p.y - y).abs() < 20);
          add(Dot(Vector2(x, y), isPowerUp: isPower));
        }
      }
    }
  }

  /// Verifica si una coordenada interseca con alguna pared o la zona de respawn.
  bool _isHittingWall(double x, double y) {
    if (x >= 480 && x <= 780 && y >= 320 && y <= 470) return true;
    for (var w in children.whereType<Wall>()) {
      final rect = w.size.toRect().shift(Offset(w.position.x, w.position.y));
      if (rect.inflate(10).contains(Offset(x, y))) return true;
    }
    return false;
  }

  /// Activa el estado de fin de partida y muestra el menú interactivo.
  void triggerGameOver() {
    if (isGameOver) return;
    isGameOver = true;
    overlays.add('GameOverMenu');
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (isGameOver) return KeyEventResult.ignored;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
        player.nextDirection = Vector2(-1, 0);
      } else if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
        player.nextDirection = Vector2(1, 0);
      } else if (keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
        player.nextDirection = Vector2(0, -1);
      } else if (keysPressed.contains(LogicalKeyboardKey.arrowDown)) {
        player.nextDirection = Vector2(0, 1);
      }
    }
    return KeyEventResult.handled;
  }
}

/// [GameOverOverlay] Interfaz gráfica superpuesta al perder la partida.
class GameOverOverlay extends StatelessWidget {
  final PacManGame game;
  const GameOverOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: Colors.blue.shade900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.yellow, width: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('¡GAME OVER!', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.yellow)),
              const SizedBox(height: 16),
              Text('Puntuación: ${game.score}', style: const TextStyle(fontSize: 24, color: Colors.white)),
              const SizedBox(height: 28),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black),
                onPressed: () {
                  game.overlays.remove('GameOverMenu');
                  game.startGame();
                },
                child: const Text('Reiniciar Juego', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [PlayerPacman] Representa al personaje controlado por el usuario con movimiento ortogonal estricto.
class PlayerPacman extends SpriteComponent with HasGameRef<PacManGame> {
  Vector2 moveDirection = Vector2.zero();
  Vector2 nextDirection = Vector2.zero();
  final double speed = 200.0;

  PlayerPacman() {
    size = Vector2(40, 40);
    position = Vector2(630, 520);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    sprite = Sprite(gameRef.images.fromCache('pacman.png'));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.isGameOver) return;

    // Validación estricta para impedir movimientos en diagonal
    if (nextDirection != Vector2.zero()) {
      if (nextDirection.x != 0) nextDirection.y = 0;
      else if (nextDirection.y != 0) nextDirection.x = 0;

      position += nextDirection * speed * dt;
      if (_checkWallCollision()) {
        position -= nextDirection * speed * dt;
      } else {
        moveDirection = nextDirection;
      }
    }

    if (moveDirection.x != 0) moveDirection.y = 0;
    else if (moveDirection.y != 0) moveDirection.x = 0;

    position += moveDirection * speed * dt;
    if (_checkWallCollision()) {
      position -= moveDirection * speed * dt;
      moveDirection = Vector2.zero();
    }

    // Lógica de colisión con los coleccionables (Dots y Power-Ups)
    gameRef.children.whereType<Dot>().toList().forEach((dot) {
      if (toRect().overlaps(dot.toRect())) {
        dot.removeFromParent();
        gameRef.score += dot.isPowerUp ? 100 : 10;
        if (dot.isPowerUp) {
          gameRef.children.whereType<Ghost>().forEach((g) => g.triggerPanic());
        }
      }
    });
  }

  /// Comprueba si la posición actual intersecta con algún objeto de tipo [Wall].
  bool _checkWallCollision() {
    for (var wall in gameRef.children.whereType<Wall>()) {
      if (toRect().overlaps(wall.toRect())) return true;
    }
    return false;
  }
}

/// [Dot] Puntos o superpuntos repartidos en el escenario.
class Dot extends SpriteComponent with HasGameRef<PacManGame> {
  bool isPowerUp;
  Dot(Vector2 pos, {this.isPowerUp = false}) {
    position = pos;
    size = isPowerUp ? Vector2(24, 24) : Vector2(10, 10);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    sprite = Sprite(gameRef.images.fromCache('dot.png'));
  }
}

/// [Ghost] Entidad enemiga con inteligencia artificial ortogonal, modo pánico y retorno como punto blanco.
class Ghost extends SpriteComponent with HasGameRef<PacManGame> {
  Vector2 velocity = Vector2(70, 0);
  final Vector2 spawnPosition = Vector2(630, 390);
  bool isScared = false;
  bool isDead = false; 
  double scaredTimer = 0.0;
  Random random = Random();

  Ghost(Vector2 startPos) {
    position = startPos;
    size = Vector2(44, 44);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    sprite = Sprite(gameRef.images.fromCache('ghost.png'));
  }

  /// Activa el estado de pánico, cambiando la textura a 'niga.png' y reduciendo velocidad.
  void triggerPanic() {
    if (!isDead) {
      isScared = true;
      scaredTimer = 8.0;
      sprite = Sprite(gameRef.images.fromCache('niga.png'));
      velocity *= 0.5;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (gameRef.isGameOver) return;

    // Si el fantasma fue derrotado, regresa a la base convertido en un punto blanco visual
    if (isDead) {
      position = position + (spawnPosition - position).normalized() * 300 * dt;
      if (position.distanceTo(spawnPosition) < 12) {
        isDead = false;
        isScared = false;
        sprite = Sprite(gameRef.images.fromCache('ghost.png'));
        velocity = Vector2(70, 0);
      }
      return;
    }

    if (isScared) {
      scaredTimer -= dt;
      if (scaredTimer <= 0) {
        isScared = false;
        sprite = Sprite(gameRef.images.fromCache('ghost.png'));
        velocity *= 2.0;
      }
    }

    final player = gameRef.player;
    double distanceToPlayer = position.distanceTo(player.position);

    // Inteligencia artificial con vectores estrictamente ortogonales
    if (!isScared && distanceToPlayer < 250) {
      if ((player.position.x - position.x).abs() > (player.position.y - position.y).abs()) {
        velocity = Vector2((player.position.x > position.x) ? 90 : -90, 0);
      } else {
        velocity = Vector2(0, (player.position.y > position.y) ? 90 : -90);
      }
    } else if (isScared && distanceToPlayer < 200) {
      if ((player.position.x - position.x).abs() > (player.position.y - position.y).abs()) {
        velocity = Vector2((player.position.x > position.x) ? -70 : 70, 0);
      } else {
        velocity = Vector2(0, (player.position.y > position.y) ? -70 : 70);
      }
    } else {
      if (random.nextDouble() < 0.03) {
        List<Vector2> dirs = [
          Vector2(70, 0),
          Vector2(-70, 0),
          Vector2(0, 70),
          Vector2(0, -70)
        ];
        velocity = dirs[random.nextInt(dirs.length)];
      }
    }

    if (velocity.x != 0) velocity.y = 0;
    else if (velocity.y != 0) velocity.x = 0;

    position += velocity * dt;

    // Colisión contra paredes del laberinto
    for (var wall in gameRef.children.whereType<Wall>()) {
      if (toRect().overlaps(wall.toRect())) {
        position -= velocity * dt;
        velocity = -velocity;
        if (velocity.x != 0) velocity.y = 0;
        else if (velocity.y != 0) velocity.x = 0;
        break;
      }
    }

    // Colisión directa con el jugador
    if (toRect().overlaps(player.toRect())) {
      if (isScared) {
        isDead = true;
        sprite = Sprite(gameRef.images.fromCache('dot.png'));
        gameRef.score += 500;
      } else {
        gameRef.triggerGameOver();
      }
    }
  }
}

/// [Wall] Componente estático que define los límites físicos de las paredes.
class Wall extends PositionComponent {
  Wall(Vector2 pos, Vector2 sz) {
    position = pos;
    size = sz;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()..color = const Color(0xFF1E1EEB); // Estilo de color azul clásico arcade
    canvas.drawRect(size.toRect(), paint);
  }
}