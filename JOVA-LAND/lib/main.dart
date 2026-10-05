// =============================================================================
// JOVA-LAND
// Videojuego estilo Pac-Man desarrollado con Flutter y el motor Flame.
//
// Autor:        Gabriel Jovanny Osuna Martínez
// Plataformas:  Web, Android, iOS (orientación horizontal en móviles)
//
// DESCRIPCIÓN
//   El jugador controla a Pac-Man dentro de un laberinto, recolectando puntos
//   mientras evita a los fantasmas. Al comer un punto grande (power-up), los
//   fantasmas se asustan (sprite "niga") y pueden ser comidos. Un fantasma
//   comido se convierte en "mori" y regresa a su base, donde vuelve a ser un
//   fantasma normal.
//
// CONTROLES
//   - Teclado: flechas direccionales.
//   - Táctil:  deslizar el dedo en la dirección deseada.
//
// ESTRUCTURA DEL ARCHIVO
//   1. Punto de entrada y configuración de la app
//   2. Pantallas de Flutter (menú principal y contenedor del juego)
//   3. Núcleo del juego (PacManGame)
//   4. Menús superpuestos (Game Over y Victoria)
//   5. Entidades: PlayerPacman, Dot, Ghost y Wall
//
// RECURSOS REQUERIDOS (carpeta assets/images/, declarada en pubspec.yaml)
//   pacman.png, ghost.png, dot.png, niga.png, mori.png,
//   game_over.png, jova_logo.png
//   Si alguna imagen no está disponible, el juego usa figuras de respaldo
//   (círculos y cuadros de color) y continúa funcionando.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import 'dart:math';

// =============================================================================
// 1. PUNTO DE ENTRADA Y CONFIGURACIÓN DE LA APLICACIÓN
// =============================================================================

/// Punto de entrada de la aplicación.
///
/// En dispositivos móviles fuerza la orientación horizontal y activa el modo
/// de pantalla completa inmersivo. En web y escritorio no modifica nada.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  runApp(const MyApp());
}

/// Widget raíz de la aplicación. Define el tema oscuro y la pantalla inicial.
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

// =============================================================================
// 2. PANTALLAS DE FLUTTER
// =============================================================================

/// Pantalla de inicio (menú principal).
///
/// Muestra el logotipo del juego y el botón "Iniciar juego". Si la imagen
/// `jova_logo.png` no se encuentra, se muestra el título como texto.
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
            Image.asset(
              'assets/images/jova_logo.png',
              width: 420,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  'JOVA-LAND',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.yellow,
                  ),
                );
              },
            ),
            const SizedBox(height: 35),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 45, vertical: 16),
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

/// Contenedor del juego y gestor de los gestos táctiles.
///
/// Ocupa toda la pantalla disponible; el escalado y centrado del laberinto
/// lo resuelve [PacManGame] internamente. Convierte los deslizamientos del
/// dedo en cambios de dirección de Pac-Man.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  /// Instancia única del juego, creada una sola vez para toda la pantalla.
  final PacManGame gameInstance = PacManGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Se usa la componente dominante del desplazamiento para decidir si
        // el gesto es horizontal o vertical. El umbral de 1.5 px evita que
        // movimientos mínimos del dedo se interpreten como un giro.
        onPanUpdate: (details) {
          if (!gameInstance.isGameOver && !gameInstance.isGameWon) {
            if (details.delta.dx.abs() > details.delta.dy.abs()) {
              if (details.delta.dx > 1.5) {
                gameInstance.player.changeDirection(Vector2(1, 0)); // Derecha
              } else if (details.delta.dx < -1.5) {
                gameInstance.player.changeDirection(Vector2(-1, 0)); // Izquierda
              }
            } else {
              if (details.delta.dy > 1.5) {
                gameInstance.player.changeDirection(Vector2(0, 1)); // Abajo
              } else if (details.delta.dy < -1.5) {
                gameInstance.player.changeDirection(Vector2(0, -1)); // Arriba
              }
            }
          }
        },
        child: SizedBox.expand(
          child: GameWidget<PacManGame>.controlled(
            gameFactory: () => gameInstance,
            overlayBuilderMap: {
              'GameOverMenu': (context, game) => GameOverOverlay(game),
              'GameWinMenu': (context, game) => GameWinOverlay(game),
            },
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 3. NÚCLEO DEL JUEGO (FLAME)
// =============================================================================

/// Motor principal del juego.
///
/// Administra el laberinto, la puntuación, el estado de la partida (en curso,
/// perdida o ganada), el escalado a cualquier tamaño de pantalla y la entrada
/// por teclado.
class PacManGame extends FlameGame with KeyboardEvents {
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

  /// Matriz del laberinto (16 filas x 27 columnas).
  ///
  /// Leyenda:
  /// - `0`: pasillo con punto normal
  /// - `1`: muro
  /// - `2`: casa de los fantasmas (solo transitable por fantasmas)
  /// - `3`: pasillo con punto grande (power-up)
  ///
  /// La fila 7 no tiene muros en los extremos y funciona como túnel lateral.
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

  /// Tamaño en píxeles (virtuales) de cada casilla del laberinto.
  final double tileSize = 24.0;

  /// Desplazamiento horizontal del laberinto para centrarlo en el área virtual.
  final double mazeOffsetX = 126.0;

  /// Número de columnas del laberinto.
  final int maxCols = 27;

  /// Texto del marcador de puntos.
  late TextComponent scoreText;

  /// Texto del marcador de récord.
  late TextComponent highScoreText;

  @override
  Color backgroundColor() => const Color(0xFF000000);

  // ---------------------------------------------------------------------------
  // ESCALADO RESPONSIVO
  // El juego se diseña en un lienzo "virtual" fijo y se escala para ajustarse
  // a cualquier pantalla, manteniendo la proporción y el centrado.
  // ---------------------------------------------------------------------------

  /// Ancho del lienzo virtual.
  static const double virtualWidth = 900.0;

  /// Alto del lienzo virtual: 24 (marcadores) + 16 * 24 (laberinto) + margen.
  static const double virtualHeight = 410.0;

  double _scale = 1.0;
  Vector2 _offset = Vector2.zero();

  /// Recalcula la escala y el desplazamiento cada vez que cambia el tamaño
  /// de la ventana o de la pantalla.
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _scale = min(size.x / virtualWidth, size.y / virtualHeight);
    _offset = Vector2(
      (size.x - virtualWidth * _scale) / 2,
      (size.y - virtualHeight * _scale) / 2,
    );
  }

  /// Aplica la traslación y escala calculadas antes de dibujar los componentes.
  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(_offset.x, _offset.y);
    canvas.scale(_scale);
    super.render(canvas);
    canvas.restore();
  }

  /// Carga los recursos, crea los marcadores e inicia la primera partida.
  ///
  /// Cada imagen se carga por separado: si alguna falta, se registra el error
  /// en consola y el juego continúa con figuras de respaldo.
  @override
  Future<void> onLoad() async {
    super.onLoad();

    for (final name in [
      'pacman.png',
      'ghost.png',
      'dot.png',
      'niga.png',
      'mori.png',
      'game_over.png',
      'jova_logo.png'
    ]) {
      try {
        await images.load(name);
      } catch (e) {
        debugPrint("No se pudo cargar $name: $e");
      }
    }

    scoreText = TextComponent(
      text: 'SCORE: 0',
      position: Vector2(126, 4),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    highScoreText = TextComponent(
      text: 'HIGH SCORE: 0',
      position: Vector2(670, 4),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

    add(scoreText);
    add(highScoreText);

    try {
      startGame();
    } catch (e, st) {
      debugPrint('Error en startGame: $e\n$st');
    }
  }

  /// Inicia o reinicia una partida.
  ///
  /// Reinicia la puntuación y los estados, elimina las entidades anteriores,
  /// reconstruye el laberinto y coloca al jugador y a los cuatro fantasmas.
  void startGame() {
    score = 0;
    isGameOver = false;
    isGameWon = false;
    scoreText.text = 'SCORE: $score';
    overlays.remove('GameOverMenu');
    overlays.remove('GameWinMenu');

    children
        .where((c) => c is PlayerPacman || c is Ghost || c is Dot || c is Wall)
        .toList()
        .forEach((c) => c.removeFromParent());

    _buildGridMaze();

    player = PlayerPacman(Vector2(13, 12));
    add(player);

    add(Ghost(Vector2(13, 7)));
    add(Ghost(Vector2(14, 7)));
    add(Ghost(Vector2(13, 8)));
    add(Ghost(Vector2(14, 8)));
  }

  /// Suma [points] a la puntuación, actualiza el récord y verifica la victoria.
  ///
  /// La partida se gana cuando ya no queda ningún [Dot] en el laberinto.
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

  /// Recorre [mazeGrid] y crea los muros y puntos correspondientes.
  void _buildGridMaze() {
    for (int row = 0; row < mazeGrid.length; row++) {
      for (int col = 0; col < mazeGrid[row].length; col++) {
        int cell = mazeGrid[row][col];
        Vector2 pos =
            Vector2(mazeOffsetX + (col * tileSize), 24 + (row * tileSize));

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
    if (cell == 2 && !isGhost) return false;
    return true;
  }

  /// Determina si un fantasma ve al jugador.
  ///
  /// Hay línea de visión solo si ambos comparten fila o columna y no existe
  /// ningún muro entre ellos.
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

  /// Termina la partida por derrota y muestra el menú de Game Over.
  void triggerGameOver() {
    if (isGameOver || isGameWon) return;
    isGameOver = true;
    overlays.add('GameOverMenu');
  }

  /// Termina la partida por victoria y muestra el menú de Victoria.
  void triggerGameWin() {
    if (isGameOver || isGameWon) return;
    isGameWon = true;
    overlays.add('GameWinMenu');
  }

  /// Gestiona la entrada por teclado (flechas direccionales).
  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
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

// =============================================================================
// 4. MENÚS SUPERPUESTOS (OVERLAYS)
// =============================================================================

/// Menú que aparece al perder la partida.
///
/// Muestra la imagen de Game Over (o un texto de respaldo), la puntuación
/// final y un botón para reiniciar.
class GameOverOverlay extends StatelessWidget {
  final PacManGame game;
  const GameOverOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/game_over.png',
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Text(
                  'GAME OVER',
                  style: TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                );
              },
            ),
            const SizedBox(height: 15),
            Text(
              'Puntuación: ${game.score}',
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.yellow, width: 2),
                ),
              ),
              onPressed: () => game.startGame(),
              child: const Text(
                'Reiniciar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Menú que aparece al ganar la partida (todos los puntos comidos).
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
              const Text(
                '¡VICTORIA!',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.yellow,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '¡Comiste todos los puntos!\nPuntuación: ${game.score}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
                  foregroundColor: Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                onPressed: () => game.startGame(),
                child: const Text(
                  'Reiniciar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 5. ENTIDADES DEL JUEGO
// =============================================================================

// -----------------------------------------------------------------------------
// PLAYERPACMAN: JUGADOR
// -----------------------------------------------------------------------------

/// Personaje controlado por el jugador.
///
/// Se mueve casilla por casilla: [moveProgress] va de 0.0 a 1.0 mientras
/// avanza hacia la siguiente casilla. La dirección solicitada ([nextDir]) se
/// guarda y se aplica en cuanto el camino queda libre, lo que permite
/// anticipar giros.
class PlayerPacman extends PositionComponent with HasGameReference<PacManGame> {
  /// Sprite del personaje. Si es nulo se dibuja un círculo amarillo.
  Sprite? sprite;

  /// Posición actual en coordenadas de la cuadrícula (columna, fila).
  Vector2 gridPos;

  /// Dirección de movimiento actual.
  Vector2 moveDir = Vector2.zero();

  /// Dirección solicitada por el jugador, pendiente de aplicarse.
  Vector2 nextDir = Vector2.zero();

  /// Avance hacia la siguiente casilla (0.0 a 1.0).
  double moveProgress = 0.0;

  /// Velocidad en casillas por segundo.
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

  /// Convierte la posición de cuadrícula a píxeles y la aplica al componente.
  void updatePixelPosition() {
    position = Vector2(
      game.mazeOffsetX + gridPos.x * game.tileSize + 4,
      24 + gridPos.y * game.tileSize + 4,
    );
  }

  /// Registra la próxima dirección deseada por el jugador.
  void changeDirection(Vector2 newDir) {
    nextDir = newDir.clone();
  }

  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      sprite!.render(canvas, size: size);
    } else {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x / 2,
        Paint()..color = Colors.yellow,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isGameWon) return;

    // Solo se decide una nueva dirección cuando está exactamente en una casilla.
    if (moveProgress == 0.0) {
      if (nextDir != Vector2.zero()) {
        int nextX = (gridPos.x + nextDir.x).toInt();
        int nextY = (gridPos.y + nextDir.y).toInt();
        if (game.isWalkable(nextX, nextY, isGhost: false)) {
          moveDir = nextDir.clone();
          nextDir.setZero();
        }
      }

      // Si hay un muro al frente, se detiene.
      int targetX = (gridPos.x + moveDir.x).toInt();
      int targetY = (gridPos.y + moveDir.y).toInt();
      if (!game.isWalkable(targetX, targetY, isGhost: false)) {
        moveDir.setZero();
      }
    }

    // Movimiento interpolado entre la casilla actual y la siguiente.
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

        // Túnel lateral: al salir por un extremo reaparece en el opuesto.
        if (gridPos.x < 0) {
          gridPos.x = (game.maxCols - 1).toDouble();
        } else if (gridPos.x >= game.maxCols) {
          gridPos.x = 0;
        }
        updatePixelPosition();

        // Aplica de inmediato el giro pendiente si ya es posible.
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

    // Recolección de puntos: normal = 10 pts, power-up = 100 pts + pánico.
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

// -----------------------------------------------------------------------------
// DOT: PUNTO Y POWER-UP
// -----------------------------------------------------------------------------

/// Punto coleccionable del laberinto.
///
/// Los puntos normales (4x4) otorgan 10 puntos. Los power-ups (8x8) otorgan
/// 100 puntos y asustan a los fantasmas.
class Dot extends PositionComponent with HasGameReference<PacManGame> {
  /// Sprite del punto. Si es nulo se dibuja un círculo blanco.
  Sprite? sprite;

  /// Posición en coordenadas de la cuadrícula (columna, fila).
  Vector2 gridPos;

  /// Indica si es un punto grande (power-up).
  bool isPowerUp;

  Dot(this.gridPos, {this.isPowerUp = false});

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      sprite = Sprite(game.images.fromCache('dot.png'));
    } catch (_) {}
    size = isPowerUp ? Vector2(8, 8) : Vector2(4, 4);
    // Se centra el punto dentro de su casilla.
    position = Vector2(
      game.mazeOffsetX + gridPos.x * game.tileSize + (game.tileSize - size.x) / 2,
      24 + gridPos.y * game.tileSize + (game.tileSize - size.y) / 2,
    );
  }

  @override
  void render(Canvas canvas) {
    if (sprite != null) {
      sprite!.render(canvas, size: size);
    } else {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x / 2,
        Paint()..color = Colors.white,
      );
    }
  }
}

// -----------------------------------------------------------------------------
// GHOST: FANTASMA
// -----------------------------------------------------------------------------

/// Enemigo del juego. Tiene cuatro estados visuales y de comportamiento:
///
/// 1. **Saliendo de la base** ([isLeavingSpawn]): sube hasta salir de la casa.
/// 2. **Normal**: persigue al jugador si lo ve; si no, deambula al azar.
/// 3. **Asustado** ([isScared], sprite "niga"): huye del jugador y puede ser
///    comido. Dura [scaredTimer] segundos (8 s).
/// 4. **Muerto** ([isDead], sprite "mori"): vuela en línea recta a la base y,
///    al llegar, vuelve a ser un fantasma normal.
class Ghost extends PositionComponent with HasGameReference<PacManGame> {
  /// Posición actual en coordenadas de la cuadrícula (columna, fila).
  Vector2 gridPos;

  /// Casilla de la base a la que regresan los fantasmas comidos.
  final Vector2 spawnGridPos = Vector2(13, 7);

  /// Dirección de movimiento actual.
  Vector2 moveDir = Vector2(0, -1);

  /// Avance hacia la siguiente casilla (0.0 a 1.0).
  double moveProgress = 0.0;

  /// Velocidad normal en casillas por segundo.
  final double speed = 3.5;

  /// Velocidad del mori al regresar a la base, en píxeles por segundo.
  final double moriSpeed = 140.0;

  /// Está asustado (el jugador comió un power-up).
  bool isScared = false;

  /// Fue comido y regresa a la base.
  bool isDead = false;

  /// Está saliendo de la casa de fantasmas.
  bool isLeavingSpawn = true;

  /// Tiempo restante de susto, en segundos.
  double scaredTimer = 0.0;

  final Random random = Random();

  Sprite? ghostSprite;
  Sprite? scaredSprite;
  Sprite? moriSprite;

  Ghost(this.gridPos);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    try { ghostSprite = Sprite(game.images.fromCache('ghost.png')); } catch (_) {}
    try { scaredSprite = Sprite(game.images.fromCache('niga.png')); } catch (_) {}
    try { moriSprite = Sprite(game.images.fromCache('mori.png')); } catch (_) {}

    size = Vector2(16, 16);
    updatePixelPosition();
  }

  /// Convierte la posición de cuadrícula a píxeles y la aplica al componente.
  void updatePixelPosition() {
    position = Vector2(
      game.mazeOffsetX + gridPos.x * game.tileSize + 4,
      24 + gridPos.y * game.tileSize + 4,
    );
  }

  /// Dibuja el sprite según el estado actual. Si falta la imagen se usa una
  /// figura de respaldo (gris para el mori, roja para el fantasma).
  @override
  void render(Canvas canvas) {
    if (isDead) {
      if (moriSprite != null) {
        moriSprite!.render(canvas, size: size);
      } else {
        canvas.drawRect(size.toRect(), Paint()..color = Colors.grey);
      }
      return;
    } else if (isScared) {
      if (scaredSprite != null) {
        scaredSprite!.render(canvas, size: size);
        return;
      }
    }

    if (ghostSprite != null) {
      ghostSprite!.render(canvas, size: size);
    } else {
      canvas.drawRect(size.toRect(), Paint()..color = Colors.red);
    }
  }

  /// Asusta al fantasma durante 8 segundos.
  ///
  /// No tiene efecto si ya fue comido o si todavía está saliendo de la base.
  void triggerPanic() {
    if (!isDead && !isLeavingSpawn) {
      isScared = true;
      scaredTimer = 8.0;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isGameWon) return;

    // --- Estado: MUERTO (mori) -------------------------------------------
    // Vuela en línea recta hacia la base; al llegar revive como fantasma.
    if (isDead) {
      Vector2 targetSpawnPx = Vector2(
        game.mazeOffsetX + spawnGridPos.x * game.tileSize + 4,
        24 + spawnGridPos.y * game.tileSize + 4,
      );

      final toTarget = targetSpawnPx - position;
      final dist = toTarget.length;

      if (dist <= moriSpeed * dt + 1) {
        isDead = false;
        isScared = false;
        isLeavingSpawn = true;
        moveProgress = 0.0;
        moveDir = Vector2(0, -1);
        gridPos = spawnGridPos.clone();
        updatePixelPosition();
      } else {
        position = position + toTarget / dist * (moriSpeed * dt);
      }
      return;
    }

    // --- Estado: SALIENDO DE LA BASE -------------------------------------
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

    // --- Temporizador del estado asustado --------------------------------
    if (isScared) {
      scaredTimer -= dt;
      if (scaredTimer <= 0) {
        isScared = false;
      }
    }

    // --- Decisión de dirección (solo al estar exactamente en una casilla) -
    if (moveProgress == 0.0 && game.player.isMounted) {
      final player = game.player;
      bool hasVision = game.hasLineOfSight(gridPos, player.gridPos);

      if (hasVision) {
        // Dirección hacia el jugador, limitada a -1, 0 o 1 en cada eje.
        Vector2 targetDir = Vector2(
          player.gridPos.x > gridPos.x ? 1.0 : (player.gridPos.x < gridPos.x ? -1.0 : 0.0),
          player.gridPos.y > gridPos.y ? 1.0 : (player.gridPos.y < gridPos.y ? -1.0 : 0.0),
        );

        if (isScared) {
          // Asustado: huye en sentido contrario al jugador.
          Vector2 fleeDir = -targetDir;
          int fleeX = (gridPos.x + fleeDir.x).toInt();
          int fleeY = (gridPos.y + fleeDir.y).toInt();
          if (fleeDir != Vector2.zero() &&
              game.isWalkable(fleeX, fleeY, isGhost: true)) {
            moveDir = fleeDir;
          } else {
            _pickRandomValidDir();
          }
        } else {
          // Normal: persigue al jugador.
          int nextX = (gridPos.x + targetDir.x).toInt();
          int nextY = (gridPos.y + targetDir.y).toInt();
          if (targetDir != Vector2.zero() &&
              game.isWalkable(nextX, nextY, isGhost: true)) {
            moveDir = targetDir;
          } else {
            _pickRandomValidDir();
          }
        }
      } else {
        // Sin visión del jugador: deambula al azar.
        _pickRandomValidDir();
      }
    }

    // --- Movimiento interpolado entre casillas ---------------------------
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

      // Túnel lateral.
      if (gridPos.x < 0) {
        gridPos.x = (game.maxCols - 1).toDouble();
      } else if (gridPos.x >= game.maxCols) {
        gridPos.x = 0;
      }
      updatePixelPosition();
    }

    // --- Colisión con el jugador -----------------------------------------
    // Asustado: el fantasma muere (+500 pts). Normal: fin de la partida.
    if (!isDead && toRect().overlaps(game.player.toRect())) {
      if (isScared) {
        isDead = true;
        isScared = false;
        moveProgress = 0.0;
        game.addScore(500);
      } else {
        game.triggerGameOver();
      }
    }
  }

  /// Elige al azar una dirección válida, evitando dar media vuelta.
  ///
  /// Si no hay ninguna opción (callejón sin salida), invierte el sentido.
  void _pickRandomValidDir() {
    List<Vector2> validDirs = [];
    for (var dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]) {
      if (dir != -moveDir &&
          game.isWalkable(
            (gridPos.x + dir.x).toInt(),
            (gridPos.y + dir.y).toInt(),
            isGhost: true,
          )) {
        validDirs.add(dir.clone());
      }
    }
    if (validDirs.isNotEmpty) {
      moveDir = validDirs[random.nextInt(validDirs.length)];
    } else {
      if (game.isWalkable(
        (gridPos.x - moveDir.x).toInt(),
        (gridPos.y - moveDir.y).toInt(),
        isGhost: true,
      )) {
        moveDir = -moveDir;
      }
    }
  }
}

// -----------------------------------------------------------------------------
// WALL: MURO
// -----------------------------------------------------------------------------

/// Muro del laberinto, dibujado como un cuadrado azul sólido.
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