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
//   Al comer todos los puntos se muestra la pantalla de victoria (win.png).
//   Una barra de progreso bajo el laberinto indica cuánto falta para ganar.
//
// CONTROLES
//   - Teclado: flechas direccionales.  ESC = pausa / continuar.
//   - Táctil:  deslizar el dedo; tocar la esquina superior izquierda pausa.
//
// PANTALLAS
//   Menú, Game Over, Victoria y Pausa se estiran al ancho del laberinto
//   (ver MazeFrame) y usan una paleta neón a juego con tus imágenes.
//
// ESTRUCTURA DEL ARCHIVO
//   1. Punto de entrada y configuración de la app
//   2. Pantallas de Flutter (menú principal y contenedor del juego)
//   3. Núcleo del juego (PacManGame)
//   4. Menús superpuestos (Game Over, Victoria y Pausa)
//   5. Entidades: PlayerPacman, Dot, Ghost, Wall y ProgressBar
//   6. IA de fantasmas: modos globales, personalidades y toma de decisiones
//   7. Velocidades: tabla relativa, túneles, modo asustado y Cruise Elroy
//   8. Habilidades especiales: Imán (Blinky), Constructor (Pinky) y
//      Láser (Inky y Clyde)
//
// RECURSOS REQUERIDOS (carpeta assets/images/, declarada en pubspec.yaml)
//   pacman.png, ghost.png, dot.png, niga.png, mori.png,
//   game_over.png, win.png, jova_logo.png
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

// -----------------------------------------------------------------------------
// COMPONENTES VISUALES COMPARTIDOS
// -----------------------------------------------------------------------------

/// Tamaño del laberinto en el lienzo virtual (27 x 16 casillas de 24 px).
const double _mazeVirtualW = 27 * 24.0;
const double _mazeVirtualH = 16 * 24.0;

/// Colores de la identidad visual (los del texto de tus imágenes).
const Color _neonLime = Color(0xFFC8FF00);
const Color _neonOrange = Color(0xFFFF6A00);

/// Reserva exactamente el área que ocupa el laberinto en pantalla.
///
/// Usa la misma escala que [PacManGame], así las pantallas se estiran
/// "de lado a lado" del mapa en cualquier teléfono o ventana. [builder]
/// recibe la escala para dimensionar textos y botones proporcionalmente.
class MazeFrame extends StatelessWidget {
  const MazeFrame({super.key, required this.builder});

  final Widget Function(BuildContext context, double scale) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final scale = min(c.maxWidth / PacManGame.virtualWidth,
          c.maxHeight / PacManGame.virtualHeight);
      return Center(
        child: SizedBox(
          width: _mazeVirtualW * scale,
          height: _mazeVirtualH * scale,
          child: builder(context, scale),
        ),
      );
    });
  }
}

/// Botón con estilo neón. [filled] = relleno de color; si no, solo contorno.
class _NeonButton extends StatelessWidget {
  const _NeonButton({
    required this.label,
    required this.onPressed,
    required this.s,
    this.color = _neonLime,
    this.filled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final double s;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(30));
    final pad = EdgeInsets.symmetric(horizontal: 22 * s, vertical: 8 * s);
    final text = Text(
      label,
      style: TextStyle(
        fontSize: 9.5 * s,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
      ),
    );

    if (filled) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: color.withAlpha(140), blurRadius: 18, spreadRadius: 1),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.black,
            padding: pad,
            shape: shape,
            elevation: 0,
          ),
          onPressed: onPressed,
          child: text,
        ),
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color, width: 2),
        padding: pad,
        shape: shape,
      ),
      onPressed: onPressed,
      child: text,
    );
  }
}

/// Pantalla de inicio (menú principal).
///
/// - El logotipo `jova_logo.png` se estira al ancho del laberinto y flota
///   suavemente.
/// - El botón "Iniciar juego" pulsa para llamar la atención.
/// - Debajo, una tira animada con los sprites de tu juego: el jugador se come
///   los puntos perseguido por los 4 fantasmas.
/// Si el logotipo no se encuentra, se muestra el título como texto.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  /// Reloj de 8 s que mueve todas las animaciones del menú.
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fondo con resplandor azul.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3),
                  radius: 1.1,
                  colors: [Color(0xFF14146B), Colors.black],
                ),
              ),
            ),
          ),
          // Tira animada con los personajes de tu juego.
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            height: 46,
            child: _SpriteChase(animation: _ctrl),
          ),
          SafeArea(
            child: LayoutBuilder(builder: (context, c) {
              final s = min(c.maxWidth / PacManGame.virtualWidth,
                  c.maxHeight / PacManGame.virtualHeight);
              return Center(
                child: SizedBox(
                  width: _mazeVirtualW * s,
                  child: Column(
                    children: [
                      SizedBox(height: 8 * s),
                      // Logotipo flotando.
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _ctrl,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(0, 5 * s * sin(_ctrl.value * 2 * pi * 4)),
                            child: child,
                          ),
                          child: Image.asset(
                            'assets/images/jova_logo.png',
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  'JOVA-LAND',
                                  style: TextStyle(
                                    fontSize: 40 * s,
                                    fontWeight: FontWeight.w900,
                                    color: _neonLime,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 8 * s),
                      // Botón pulsante.
                      AnimatedBuilder(
                        animation: _ctrl,
                        builder: (context, child) => Transform.scale(
                          scale: 1 + 0.04 * sin(_ctrl.value * 2 * pi * 8),
                          child: child,
                        ),
                        child: _NeonButton(
                          label: 'INICIAR JUEGO',
                          s: s * 1.15,
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const GameScreen()),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 8 * s),
                      Text(
                        'FLECHAS O DESLIZA PARA MOVERTE   ·   ESC O ESQUINA SUPERIOR IZQUIERDA = PAUSA',
                        style: TextStyle(
                          fontSize: 6.5 * s,
                          letterSpacing: 1.4,
                          color: Colors.white60,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 3 * s),
                      Text(
                        'Hecho por Gabriel Jovanny Osuna Martínez',
                        style: TextStyle(fontSize: 6 * s, color: Colors.white30),
                      ),
                      // Espacio para la tira de Pac-Man del fondo.
                      const SizedBox(height: 52),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Tira animada del menú hecha con los sprites de TU juego.
///
/// El jugador (`pacman.png`) recorre la pantalla comiéndose los puntos
/// (`dot.png`) mientras los 4 fantasmas lo persiguen. Cada fantasma usa su
/// sprite propio (`ghost_pinky.png`, ...) y, si no existe, `ghost.png`, igual
/// que dentro del juego. Si falta cualquier imagen se dibuja una figura de
/// respaldo. [animation] va de 0.0 a 1.0 y se repite.
class _SpriteChase extends StatelessWidget {
  const _SpriteChase({required this.animation});

  final Animation<double> animation;

  static const double _size = 34;
  static const double _dotSpacing = 34;
  static const double _ghostGap = 46;

  /// Del más cercano a Pac-Man al más lejano: Blinky, Pinky, Inky y Clyde.
  static const List<String> _ghostAssets = [
    'assets/images/ghost.png',
    'assets/images/ghost_pinky.png',
    'assets/images/ghost_inky.png',
    'assets/images/ghost_clyde.png',
  ];
  static const List<Color> _ghostColors = [
    Colors.red,
    Colors.pinkAccent,
    Colors.cyanAccent,
    Colors.orange,
  ];

  Widget _player() {
    return SizedBox(
      width: _size,
      height: _size,
      child: Image.asset(
        'assets/images/pacman.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const DecoratedBox(
          decoration: BoxDecoration(color: Colors.yellow, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _ghost(int i) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Image.asset(
        _ghostAssets[i],
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/images/ghost.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => DecoratedBox(
            decoration: BoxDecoration(
              color: _ghostColors[i],
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot() {
    return SizedBox(
      width: 8,
      height: 8,
      child: Image.asset(
        'assets/images/dot.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value;
            final pacX = -230 + t * (w + 460);
            final top = h / 2 - _size / 2;
            // Saltito suave para que los personajes se sientan vivos.
            double bob(double phase) => 3 * sin(t * 2 * pi * 30 + phase);

            final items = <Widget>[];

            // Puntos: desaparecen al pasar el jugador.
            for (double x = _dotSpacing / 2; x < w; x += _dotSpacing) {
              if (x > pacX + _size / 2) {
                items.add(Positioned(left: x - 4, top: h / 2 - 4, child: _dot()));
              }
            }
            // Fantasmas detrás (el más lejano primero).
            for (int i = _ghostAssets.length - 1; i >= 0; i--) {
              items.add(Positioned(
                left: pacX - (i + 1) * _ghostGap,
                top: top + bob(i * 1.3),
                child: _ghost(i),
              ));
            }
            // Jugador al frente.
            items.add(Positioned(left: pacX, top: top + bob(0), child: _player()));

            return Stack(children: items);
          },
        );
      }),
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

  /// Foco del teclado del juego (se devuelve al juego al salir de la pausa).
  final FocusNode _gameFocus = FocusNode();

  @override
  void dispose() {
    _gameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
      GestureDetector(
        // Se usa la componente dominante del desplazamiento para decidir si
        // el gesto es horizontal o vertical. El umbral de 1.5 px evita que
        // movimientos mínimos del dedo se interpreten como un giro.
        onPanUpdate: (details) {
          if (!gameInstance.isGameOver &&
              !gameInstance.isGameWon &&
              !gameInstance.isPaused) {
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
            focusNode: _gameFocus,
            overlayBuilderMap: {
              'GameOverMenu': (context, game) => GameOverOverlay(game),
              'GameWinMenu': (context, game) => GameWinOverlay(game),
              'PauseMenu': (context, game) => PauseOverlay(game, _gameFocus),
            },
          ),
        ),
      ),
      // Zona táctil INVISIBLE de pausa: esquina superior izquierda.
      // Un toque pausa la partida y otro la reanuda.
      Positioned(
        top: 0,
        left: 0,
        width: 96,
        height: 72,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            gameInstance.togglePause();
            _gameFocus.requestFocus();
          },
          child: const SizedBox.expand(),
        ),
      ),
        ],
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

  /// Controlador global de modos de los fantasmas (Scatter / Chase / Frightened).
  final GhostModeController modeController = GhostModeController();

  /// Total de puntos al iniciar la partida.
  int totalDots = 0;

  /// Puntos que todavía quedan en el laberinto.
  int dotsRemaining = 0;

  /// Filas que tienen salida a los extremos del mapa (túneles laterales).
  late final Set<int> tunnelRows = {
    for (int r = 0; r < mazeGrid.length; r++)
      if (mazeGrid[r].first != 1 || mazeGrid[r].last != 1) r
  };

  /// Cuántas columnas desde cada extremo cuentan como zona de túnel.
  final int tunnelDepth = 6;

  /// Nivel de Cruise Elroy de Blinky según los puntos restantes:
  /// 0 = normal, 1 = Elroy 1, 2 = Elroy 2.
  int get elroyLevel {
    if (dotsRemaining <= (totalDots * GameSpeeds.elroy2DotsFraction).round()) {
      return 2;
    }
    if (dotsRemaining <= (totalDots * GameSpeeds.elroy1DotsFraction).round()) {
      return 1;
    }
    return 0;
  }

  /// Indica si una entidad que está en [gridPos], avanzando hacia [dir] con
  /// [progress] (0.0 a 1.0), se encuentra dentro de un túnel lateral.
  bool isInTunnel(Vector2 gridPos, Vector2 dir, double progress) {
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

  int _ghostCombo = 0;
  bool _ready = false;

  /// Posición fraccionaria en la cuadrícula del centro de [c].
  /// Un valor entero corresponde al centro exacto de una casilla.
  Vector2 tilePosOf(PositionComponent c) => Vector2(
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
    if (pacTrail.length > 24) pacTrail.removeAt(0);
  }

  /// Se llama cuando Pac-Man come un power-up: activa el modo Frightened y
  /// asusta a TODOS los fantasmas a la vez.
  void onPowerUpEaten() {
    modeController.startFrightened();
    _ghostCombo = 0;
    for (final g in children.whereType<Ghost>()) {
      g.triggerPanic();
    }
  }

  /// Puntos por comer un fantasma: 200, 400, 800 y 1600 con cada fantasma
  /// consecutivo durante el mismo power-up.
  int nextGhostEatScore() {
    final points = 200 * (1 << min(_ghostCombo, 3));
    _ghostCombo++;
    return points;
  }

  /// Calcula la atracción del Fantasma Imán (Blinky) sobre Pac-Man.
  void _updateMagnet() {
    magnetStrength = 0.0;
    final blinky = ghosts[GhostType.blinky];
    if (blinky == null || !blinky.isMounted || !player.isMounted) return;
    if (blinky.isDead || blinky.isLeavingSpawn || blinky.isScared) return;

    final toBlinky = tilePosOf(blinky) - tilePosOf(player);
    final dist = toBlinky.length;
    if (dist > AbilityConfig.magnetRadiusTiles || dist < 0.001) return;

    magnetStrength = 1.0 - dist / AbilityConfig.magnetRadiusTiles;
    magnetDir = toBlinky / dist;
  }

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
    for (final g in children.whereType<Ghost>()) {
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
    for (final back in const [4, 5, 3, 6, 7]) {
      final index = pacTrail.length - 1 - back;
      if (index < 0) continue;
      final col = pacTrail[index].x.toInt();
      final row = pacTrail[index].y.toInt();
      if (!_isValidBuilderTile(col, row, pacTile)) continue;

      final wall = TempWall(col, row);
      tempWalls[tileKey(col, row)] = wall;
      add(wall);
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
    if (cell == 1 || cell == 2) return false;

    final key = tileKey(col, row);
    if (tempWalls.containsKey(key)) return false;
    if (tunnelRows.contains(row) &&
        (col < tunnelDepth || col >= maxCols - tunnelDepth)) {
      return false;
    }
    if (Vector2(col.toDouble(), row.toDouble()).distanceTo(pacTile) <
        AbilityConfig.builderMinPacDistance) {
      return false;
    }
    if (isTileOccupied(col, row)) return false;

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
    final visited = <int>{startKey};
    final queue = <int>[startKey];
    var head = 0;
    const dirs = [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1]
    ];

    while (head < queue.length && visited.length < limit) {
      final key = queue[head++];
      final col = key % 100;
      final row = key ~/ 100;
      for (final d in dirs) {
        var nc = col + d[0];
        final nr = row + d[1];
        if (nc < 0) {
          nc = maxCols - 1;
        } else if (nc >= maxCols) {
          nc = 0;
        }
        if (!isWalkable(nc, nr)) continue;
        final nk = tileKey(nc, nr);
        if (nk == blockedKey || visited.contains(nk)) continue;
        visited.add(nk);
        queue.add(nk);
      }
    }
    return visited.length;
  }

  @override
  Color backgroundColor() => const Color(0xFF000000);

  // ---------------------------------------------------------------------------
  // ESCALADO RESPONSIVO
  // El juego se diseña en un lienzo "virtual" fijo y se escala para ajustarse
  // a cualquier pantalla, manteniendo la proporción y el centrado.
  // ---------------------------------------------------------------------------

  /// Ancho del lienzo virtual.
  static const double virtualWidth = 900.0;

  /// Alto del lienzo virtual: 24 (marcadores) + 16 * 24 (laberinto) +
  /// espacio para la barra de progreso.
  static const double virtualHeight = 432.0;

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
      'win.png',
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
    _ready = true;
  }

  /// Avanza el ciclo global de modos de los fantasmas mientras la partida
  /// está en curso.
  @override
  void update(double dt) {
    if (_ready && !isGameOver && !isGameWon) {
      _updateMagnet();
    }
    super.update(dt);
    if (!isGameOver && !isGameWon) {
      modeController.update(dt);
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
    modeController.reset();
    totalDots = mazeGrid.expand((r) => r).where((c) => c == 0 || c == 3).length;
    dotsRemaining = totalDots;
    ghosts.clear();
    solidWalls.clear();
    tempWalls.clear();
    pacTrail.clear();
    magnetStrength = 0.0;
    deathCause = null;
    _ghostCombo = 0;
    scoreText.text = 'SCORE: $score';
    overlays.remove('GameOverMenu');
    overlays.remove('GameWinMenu');
    overlays.remove('PauseMenu');
    resumeEngine(); // Un reinicio siempre quita la pausa.

    children
        .where((c) =>
            c is PlayerPacman ||
            c is Ghost ||
            c is Dot ||
            c is Wall ||
            c is TempWall ||
            c is LaserLink ||
            c is ProgressBar)
        .toList()
        .forEach((c) => c.removeFromParent());

    _buildGridMaze();

    player = PlayerPacman(Vector2(13, 12));
    add(player);
    recordPacTile(player.gridPos);

    // Cada fantasma tiene su personalidad y sale de la base en un momento
    // distinto (releaseDelay, en segundos).
    add(Ghost(Vector2(13, 7), GhostType.blinky, releaseDelay: 0));
    add(Ghost(Vector2(14, 7), GhostType.pinky, releaseDelay: 2));
    add(Ghost(Vector2(13, 8), GhostType.inky, releaseDelay: 6));
    add(Ghost(Vector2(14, 8), GhostType.clyde, releaseDelay: 10));

    // Láser que une a Inky (3) y Clyde (4).
    add(LaserLink());

    // Barra de progreso del nivel.
    add(ProgressBar());
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

    if (dotsRemaining <= 0) {
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
    if (solidWalls.contains(tileKey(col, row))) return false; // Pared temporal
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

  /// Indica si el juego está en pausa.
  bool get isPaused => paused;

  /// Pausa o reanuda la partida (tecla ESC o botón "Continuar").
  ///
  /// `pauseEngine()` congela todo, incluidos los temporizadores de modos,
  /// el láser y las paredes del Constructor.
  void togglePause() {
    if (isGameOver || isGameWon) return;
    if (paused) {
      resumeEngine();
      overlays.remove('PauseMenu');
    } else {
      pauseEngine();
      overlays.add('PauseMenu');
    }
  }

  /// Termina la partida por derrota y muestra el menú de Game Over.
  void triggerGameOver({String? cause}) {
    if (isGameOver || isGameWon) return;
    isGameOver = true;
    deathCause = cause;
    overlays.add('GameOverMenu');
  }

  /// Termina la partida por victoria y muestra el menú de Victoria.
  void triggerGameWin() {
    if (isGameOver || isGameWon) return;
    isGameWon = true;
    overlays.add('GameWinMenu');
  }

  /// Gestiona la entrada por teclado (flechas direccionales y ESC).
  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (isGameOver || isGameWon) return KeyEventResult.ignored;

    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      togglePause();
      return KeyEventResult.handled;
    }
    if (paused) return KeyEventResult.handled;

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

/// Ficha de estadística (etiqueta pequeña + valor grande).
class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.value, this.color, this.s);

  final String label;
  final String value;
  final Color color;
  final double s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 4 * s),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10 * s),
        border: Border.all(color: color.withAlpha(170), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 6.5 * s,
              letterSpacing: 1.4,
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13 * s,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de resultado (Game Over / Victoria).
///
/// Ocupa exactamente el área del laberinto. La imagen se agranda al máximo
/// dentro de la tarjeta (de lado a lado) y debajo van las estadísticas y los
/// botones. Aparece con una animación de rebote.
class ResultCard extends StatelessWidget {
  const ResultCard({
    super.key,
    required this.asset,
    required this.fallback,
    required this.accent,
    required this.stats,
    required this.actions,
    this.badge,
    this.subtitle,
    this.subtitleColor = Colors.white70,
  });

  /// Ruta de la imagen principal.
  final String asset;

  /// Texto que se muestra si la imagen no existe.
  final String fallback;

  /// Color del borde y del resplandor.
  final Color accent;

  /// Fichas de estadísticas (puntuación, récord...).
  final List<_StatChip Function(double s)> stats;

  /// Botones inferiores.
  final List<Widget Function(double s)> actions;

  /// Etiqueta destacada (por ejemplo "¡NUEVO RÉCORD!").
  final String? badge;

  /// Línea de texto bajo las estadísticas.
  final String? subtitle;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(175),
      child: MazeFrame(
        builder: (context, s) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutBack,
            builder: (context, v, child) => Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform.scale(scale: 0.8 + 0.2 * v, child: child),
            ),
            child: Container(
              padding: EdgeInsets.fromLTRB(12 * s, 8 * s, 12 * s, 10 * s),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18 * s),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0E0E3A), Color(0xFF050514)],
                ),
                border: Border.all(color: accent, width: 3 * s),
                boxShadow: [
                  BoxShadow(
                    color: accent.withAlpha(120),
                    blurRadius: 30 * s,
                    spreadRadius: 2 * s,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Imagen estirada al máximo disponible.
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: Image.asset(
                        asset,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              fallback,
                              style: TextStyle(
                                fontSize: 30 * s,
                                fontWeight: FontWeight.w900,
                                color: accent,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 6 * s),
                  if (badge != null) ...[
                    Text(
                      badge!,
                      style: TextStyle(
                        fontSize: 9 * s,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: _neonLime,
                      ),
                    ),
                    SizedBox(height: 4 * s),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < stats.length; i++) ...[
                        if (i > 0) SizedBox(width: 10 * s),
                        stats[i](s),
                      ],
                    ],
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 5 * s),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 8 * s, color: subtitleColor),
                    ),
                  ],
                  SizedBox(height: 8 * s),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < actions.length; i++) ...[
                        if (i > 0) SizedBox(width: 12 * s),
                        actions[i](s),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Vuelve al menú principal.
void _goToMainMenu(BuildContext context) {
  Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (context) => const MainMenuScreen()),
  );
}

/// Menú que aparece al perder la partida.
///
/// Muestra `game_over.png` estirada al ancho del laberinto, la puntuación, el
/// récord, el motivo de la derrota y los botones Reiniciar / Menú.
class GameOverOverlay extends StatelessWidget {
  final PacManGame game;
  const GameOverOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final isRecord = game.score > 0 && game.score >= game.highScore;
    return ResultCard(
      asset: 'assets/images/game_over.png',
      fallback: 'GAME OVER',
      accent: _neonOrange,
      badge: isRecord ? '¡NUEVO RÉCORD!' : null,
      stats: [
        (s) => _StatChip('PUNTUACIÓN', '${game.score}', Colors.white, s),
        (s) => _StatChip('RÉCORD', '${game.highScore}', _neonLime, s),
      ],
      subtitle: game.deathCause,
      subtitleColor: Colors.redAccent,
      actions: [
        (s) => _NeonButton(
            label: 'REINICIAR', s: s, onPressed: () => game.startGame()),
        (s) => _NeonButton(
            label: 'MENÚ',
            s: s,
            filled: false,
            color: Colors.white,
            onPressed: () => _goToMainMenu(context)),
      ],
    );
  }
}

/// Menú que aparece al ganar la partida (todos los puntos comidos).
///
/// Muestra `win.png` estirada al ancho del laberinto, la puntuación, el
/// récord y los botones Jugar de nuevo / Menú.
class GameWinOverlay extends StatelessWidget {
  final PacManGame game;
  const GameWinOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final isRecord = game.score > 0 && game.score >= game.highScore;
    return ResultCard(
      asset: 'assets/images/win.png',
      fallback: '¡GANASTE!',
      accent: _neonLime,
      badge: isRecord ? '¡NUEVO RÉCORD!' : null,
      stats: [
        (s) => _StatChip('PUNTUACIÓN', '${game.score}', Colors.white, s),
        (s) => _StatChip('RÉCORD', '${game.highScore}', _neonLime, s),
      ],
      subtitle: '¡Comiste todos los puntos!',
      actions: [
        (s) => _NeonButton(
            label: 'JUGAR DE NUEVO', s: s, onPressed: () => game.startGame()),
        (s) => _NeonButton(
            label: 'MENÚ',
            s: s,
            filled: false,
            color: Colors.white,
            onPressed: () => _goToMainMenu(context)),
      ],
    );
  }
}

/// Menú de pausa. ESC o el botón "Continuar" reanudan la partida.
class PauseOverlay extends StatefulWidget {
  final PacManGame game;
  final FocusNode gameFocus;
  const PauseOverlay(this.game, this.gameFocus, {super.key});

  @override
  State<PauseOverlay> createState() => _PauseOverlayState();
}

class _PauseOverlayState extends State<PauseOverlay> {
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _resume() {
    widget.game.togglePause();
    widget.gameFocus.requestFocus(); // Devuelve el teclado al juego.
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _resume();
        }
      },
      child: Material(
        color: Colors.black.withAlpha(175),
        child: MazeFrame(
          builder: (context, s) {
            return Center(
              child: Container(
                width: 260 * s,
                padding: EdgeInsets.symmetric(horizontal: 20 * s, vertical: 16 * s),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18 * s),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0E0E3A), Color(0xFF050514)],
                  ),
                  border: Border.all(color: _neonLime, width: 3 * s),
                  boxShadow: [
                    BoxShadow(
                      color: _neonLime.withAlpha(100),
                      blurRadius: 28 * s,
                      spreadRadius: 2 * s,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PAUSA',
                      style: TextStyle(
                        fontSize: 30 * s,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: _neonLime,
                      ),
                    ),
                    SizedBox(height: 3 * s),
                    Text(
                      'ESC o toca la esquina superior izquierda',
                      style: TextStyle(fontSize: 8 * s, color: Colors.white60),
                    ),
                    SizedBox(height: 14 * s),
                    _NeonButton(label: 'CONTINUAR', s: s, onPressed: _resume),
                    SizedBox(height: 8 * s),
                    _NeonButton(
                      label: 'REINICIAR',
                      s: s,
                      filled: false,
                      onPressed: () {
                        widget.game.startGame();
                        widget.gameFocus.requestFocus();
                      },
                    ),
                    SizedBox(height: 8 * s),
                    _NeonButton(
                      label: 'MENÚ PRINCIPAL',
                      s: s,
                      filled: false,
                      color: Colors.white,
                      onPressed: () => _goToMainMenu(context),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// 5. ENTIDADES DEL JUEGO
// =============================================================================

// -----------------------------------------------------------------------------
// ETIQUETAS SOBRE LAS ENTIDADES
// -----------------------------------------------------------------------------

/// Dibuja una etiqueta de texto centrada justo encima de una entidad.
///
/// Usa un contorno negro para que se lea sobre los muros azules y el fondo.
/// Debe llamarse dentro de `render`, con el origen en la esquina superior
/// izquierda de la entidad.
void drawEntityLabel(
  Canvas canvas,
  String text,
  Vector2 entitySize,
  Color color, {
  double fontSize = 8,
}) {
  final anchorPoint = Vector2(entitySize.x / 2, -1);

  final outline = TextPaint(
    style: TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black,
    ),
  );
  final fill = TextPaint(
    style: TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: color,
    ),
  );

  outline.render(canvas, text, anchorPoint, anchor: Anchor.bottomCenter);
  fill.render(canvas, text, anchorPoint, anchor: Anchor.bottomCenter);
}

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

  /// Última dirección en la que se movió (la usan Pinky e Inky para apuntar).
  /// Se conserva aunque Pac-Man esté detenido.
  Vector2 facing = Vector2(-1, 0);

  /// Avance hacia la siguiente casilla (0.0 a 1.0).
  double moveProgress = 0.0;

  /// Velocidad actual en casillas por segundo.
  ///
  /// Sube durante el modo Frightened y se reduce al 50 % dentro de los túneles.
  double get speed {
    final percent = game.modeController.isFrightened
        ? GameSpeeds.pacmanFrightened
        : GameSpeeds.pacman;
    var tiles = GameSpeeds.tiles(percent);
    if (game.isInTunnel(gridPos, moveDir, moveProgress)) {
      tiles *= GameSpeeds.tunnelFactor;
    }

    // Fantasma Imán: Blinky acelera a Pac-Man si avanza hacia él y lo frena
    // si se aleja. Moverse de lado (perpendicular) no cambia la velocidad.
    if (game.magnetStrength > 0 && moveDir != Vector2.zero()) {
      final pull = moveDir.dot(game.magnetDir); // +1 hacia Blinky, -1 alejándose
      tiles *= 1.0 + AbilityConfig.magnetMaxPull * game.magnetStrength * pull;
    }
    return tiles;
  }

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
    drawEntityLabel(canvas, 'JUGADOR', size, Colors.yellow, fontSize: 7);
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
        game.recordPacTile(gridPos);

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

    if (moveDir != Vector2.zero()) facing = moveDir.clone();

    // Recolección de puntos: normal = 10 pts, power-up = 100 pts + pánico.
    game.children.whereType<Dot>().toList().forEach((dot) {
      if (!dot.eaten && dot.gridPos == gridPos) {
        dot.eaten = true;
        dot.removeFromParent();
        game.dotsRemaining--;
        game.addScore(dot.isPowerUp ? 100 : 10);
        if (dot.isPowerUp) {
          game.onPowerUpEaten(); // Asusta a todos los fantasmas a la vez
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

  /// Marca el punto como ya comido (evita contarlo dos veces).
  bool eaten = false;

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
// PROGRESSBAR: BARRA DE PROGRESO DEL NIVEL
// -----------------------------------------------------------------------------

/// Barra de progreso del nivel, debajo del laberinto.
///
/// Se llena conforme Pac-Man se come los puntos y pasa de amarillo a verde.
/// Al llegar al 100 % se dispara la victoria.
class ProgressBar extends PositionComponent with HasGameReference<PacManGame> {
  ProgressBar() {
    priority = 40;
  }

  @override
  void render(Canvas canvas) {
    final total = game.totalDots;
    final progress = total == 0
        ? 0.0
        : ((total - game.dotsRemaining) / total).clamp(0.0, 1.0).toDouble();

    final x = game.mazeOffsetX;
    const y = 414.0;
    final width = game.maxCols * game.tileSize; // Mismo ancho que el laberinto
    const height = 12.0;

    final bg = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, height), const Radius.circular(6));
    canvas.drawRRect(bg, Paint()..color = const Color(0xFF222222));

    if (progress > 0) {
      final fill = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, width * progress, height),
          const Radius.circular(6));
      canvas.drawRRect(
        fill,
        Paint()..color = Color.lerp(Colors.yellow, Colors.greenAccent, progress)!,
      );
    }

    canvas.drawRRect(
      bg,
      Paint()
        ..color = Colors.white54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    TextPaint(
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.bold,
      ),
    ).render(
      canvas,
      'PROGRESO ${(progress * 100).round()}%',
      Vector2(x + width / 2, y + height / 2),
      anchor: Anchor.center,
    );
  }
}

// -----------------------------------------------------------------------------
// HABILIDADES ESPECIALES
// -----------------------------------------------------------------------------

/// Parámetros de las habilidades especiales. Ajusta aquí la dificultad.
class AbilityConfig {
  AbilityConfig._();

  // --- Fantasma Imán (Blinky) ---------------------------------------------
  /// Radio de atracción, en casillas.
  static const double magnetRadiusTiles = 3.0;

  /// Variación máxima de la velocidad de Pac-Man (0.30 = +-30 %).
  static const double magnetMaxPull = 0.30;

  // --- Fantasma Constructor (Pinky) ----------------------------------------
  /// Espera inicial antes de la primera pared (s).
  static const double builderFirstDelay = 6.0;

  /// Tiempo entre una pared y la siguiente (s).
  static const double builderCooldown = 8.0;

  /// Aviso parpadeante antes de que la pared se vuelva sólida (s).
  static const double builderWarningSeconds = 1.0;

  /// Tiempo que la pared permanece sólida (s).
  static const double builderDurationSeconds = 6.0;

  /// Máximo de paredes temporales simultáneas.
  static const int builderMaxWalls = 2;

  /// Distancia mínima (casillas) entre Pac-Man y una pared nueva.
  static const double builderMinPacDistance = 3.0;

  /// Casillas que Pac-Man debe poder alcanzar tras colocar la pared, para
  /// garantizar que nunca quede encerrado.
  static const int builderMinReachable = 60;

  // --- Láser Inky-Clyde -----------------------------------------------------
  /// Duración del láser activo (s).
  static const double laserActiveSeconds = 8.0;

  /// Duración del enfriamiento (s).
  static const double laserCooldownSeconds = 15.0;

  /// Aviso (línea punteada, sin peligro) al final del enfriamiento (s).
  static const double laserWarningSeconds = 1.5;

  /// Distancia (px) a la que el rayo alcanza a Pac-Man.
  static const double laserHitRadius = 6.0;
}

/// Clave única de una casilla: `fila * 100 + columna`.
int tileKey(int col, int row) => row * 100 + col;

double _cross(Vector2 o, Vector2 a, Vector2 b) =>
    (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

/// Distancia de un punto [p] al segmento [a]-[b].
double _distPointToSegment(Vector2 p, Vector2 a, Vector2 b) {
  final ab = b - a;
  final len2 = ab.length2;
  if (len2 == 0) return p.distanceTo(a);
  final t = ((p - a).dot(ab) / len2).clamp(0.0, 1.0).toDouble();
  return p.distanceTo(a + ab * t);
}

/// Indica si los segmentos [p1]-[p2] y [q1]-[q2] se cruzan.
bool _segmentsIntersect(Vector2 p1, Vector2 p2, Vector2 q1, Vector2 q2) {
  final d1 = _cross(q1, q2, p1);
  final d2 = _cross(q1, q2, p2);
  final d3 = _cross(p1, p2, q1);
  final d4 = _cross(p1, p2, q2);
  return (d1 * d2 < 0) && (d3 * d4 < 0);
}

Vector2 _centerOf(PositionComponent c) =>
    Vector2(c.position.x + c.size.x / 2, c.position.y + c.size.y / 2);

// -----------------------------------------------------------------------------
// FANTASMA CONSTRUCTOR: PARED TEMPORAL
// -----------------------------------------------------------------------------

/// Pared temporal colocada por Pinky.
///
/// Ciclo de vida:
/// 1. **Aviso** ([AbilityConfig.builderWarningSeconds]): contorno naranja
///    parpadeante. Todavía se puede cruzar.
/// 2. **Sólida** ([AbilityConfig.builderDurationSeconds]): bloquea a Pac-Man y
///    a los fantasmas. Parpadea durante el último segundo.
/// 3. Desaparece.
///
/// Si alguien está sobre la casilla (o entrando) cuando termina el aviso, la
/// pared espera un momento para no atrapar a nadie dentro.
class TempWall extends PositionComponent with HasGameReference<PacManGame> {
  TempWall(this.col, this.row);

  final int col;
  final int row;

  bool _solid = false;
  double _warnTimer = 0.0;
  double _solidTimer = 0.0;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(game.tileSize, game.tileSize);
    position = Vector2(
      game.mazeOffsetX + col * game.tileSize,
      24 + row * game.tileSize,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isGameWon) return;

    if (!_solid) {
      _warnTimer += dt;
      if (_warnTimer >= AbilityConfig.builderWarningSeconds) {
        if (game.isTileOccupied(col, row)) {
          _warnTimer = AbilityConfig.builderWarningSeconds - 0.3; // Espera
        } else {
          _solid = true;
          game.solidWalls.add(tileKey(col, row));
        }
      }
    } else {
      _solidTimer += dt;
      if (_solidTimer >= AbilityConfig.builderDurationSeconds) {
        removeFromParent();
      }
    }
  }

  @override
  void onRemove() {
    final key = tileKey(col, row);
    game.solidWalls.remove(key);
    if (game.tempWalls[key] == this) {
      game.tempWalls.remove(key);
    }
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();

    if (!_solid) {
      final blink = (_warnTimer * 6).floor().isEven;
      canvas.drawRect(
        rect.deflate(2),
        Paint()
          ..color = Colors.orangeAccent.withAlpha(blink ? 220 : 70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      return;
    }

    final left = AbilityConfig.builderDurationSeconds - _solidTimer;
    if (left < 1.0 && (left * 8).floor().isEven) return; // Parpadeo final

    canvas.drawRect(rect, Paint()..color = const Color(0xFF8A0F5E));
    canvas.drawRect(
      rect.deflate(3),
      Paint()
        ..color = Colors.pinkAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

// -----------------------------------------------------------------------------
// ENLACE LÁSER INKY-CLYDE
// -----------------------------------------------------------------------------

/// Rayo láser que une permanentemente a Inky (3) y Clyde (4).
///
/// Ciclo de [AbilityConfig.laserActiveSeconds] activo +
/// [AbilityConfig.laserCooldownSeconds] de enfriamiento. Durante los últimos
/// [AbilityConfig.laserWarningSeconds] del enfriamiento se muestra una línea
/// punteada de aviso (sin peligro).
///
/// Mientras está ACTIVO, Pac-Man muere al instante si queda sobre la línea o
/// si la atraviesa entre dos frames (se revisa el recorrido completo de Pac-Man
/// en cada frame, así no se puede "saltar" el rayo por moverse rápido).
///
/// El rayo solo existe cuando ambos fantasmas están operativos (vivos, fuera
/// de la base y sin estar asustados). El ciclo se pausa durante Frightened.
class LaserLink extends PositionComponent with HasGameReference<PacManGame> {
  LaserLink() {
    priority = 50; // Se dibuja por encima de las demás entidades.
  }

  static const double _cycle =
      AbilityConfig.laserActiveSeconds + AbilityConfig.laserCooldownSeconds;

  /// Tiempo dentro del ciclo. Empieza al inicio del enfriamiento para dar
  /// margen al jugador al comenzar la partida.
  double _t = AbilityConfig.laserActiveSeconds;

  double _pulse = 0.0;
  Vector2? _prevPac;

  bool get _isActive => _t < AbilityConfig.laserActiveSeconds;
  bool get _isWarning =>
      !_isActive && _t >= _cycle - AbilityConfig.laserWarningSeconds;

  bool _operational(Ghost? g) =>
      g != null && g.isMounted && !g.isDead && !g.isLeavingSpawn && !g.isScared;

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isGameWon) return;

    // El ciclo se pausa mientras los fantasmas están asustados.
    if (!game.modeController.isFrightened) {
      _t += dt;
      if (_t >= _cycle) _t -= _cycle;
    }
    _pulse += dt;

    final pac = game.player.isMounted ? _centerOf(game.player) : null;
    final inky = game.ghosts[GhostType.inky];
    final clyde = game.ghosts[GhostType.clyde];

    if (pac != null && _isActive && _operational(inky) && _operational(clyde)) {
      final a = _centerOf(inky!);
      final b = _centerOf(clyde!);

      final onBeam =
          _distPointToSegment(pac, a, b) <= AbilityConfig.laserHitRadius;
      final crossed =
          _prevPac != null && _segmentsIntersect(_prevPac!, pac, a, b);

      if (onBeam || crossed) {
        game.triggerGameOver(
            cause: 'Te alcanzó el láser de Inky (3) y Clyde (4)');
      }
    }
    _prevPac = pac;
  }

  @override
  void render(Canvas canvas) {
    _renderHud(canvas);

    final inky = game.ghosts[GhostType.inky];
    final clyde = game.ghosts[GhostType.clyde];
    if (!_operational(inky) || !_operational(clyde)) return;

    final a = _centerOf(inky!);
    final b = _centerOf(clyde!);

    if (_isActive) {
      final pulse = 0.5 + 0.5 * sin(_pulse * 14);
      canvas.drawLine(
        Offset(a.x, a.y),
        Offset(b.x, b.y),
        Paint()
          ..color = Colors.redAccent.withAlpha((80 + 90 * pulse).round())
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(a.x, a.y),
        Offset(b.x, b.y),
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
    } else if (_isWarning) {
      // Línea punteada de aviso (inofensiva).
      final dir = b - a;
      final len = dir.length;
      if (len < 1) return;
      final unit = dir / len;
      final paint = Paint()
        ..color = Colors.redAccent.withAlpha(150)
        ..strokeWidth = 1.5;
      for (double d = 0; d < len; d += 10) {
        final p1 = a + unit * d;
        final p2 = a + unit * min(d + 5, len);
        canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), paint);
      }
    }
  }

  /// Contador del láser, centrado en la parte superior.
  void _renderHud(Canvas canvas) {
    String text;
    Color color;
    if (game.modeController.isFrightened) {
      text = 'LÁSER 3-4: EN PAUSA';
      color = Colors.grey;
    } else if (_isActive) {
      final left = AbilityConfig.laserActiveSeconds - _t;
      text = 'LÁSER 3-4: ACTIVO ${left.toStringAsFixed(1)}s';
      color = Colors.redAccent;
    } else if (_isWarning) {
      text = 'LÁSER 3-4: ¡CARGANDO!';
      color = Colors.orangeAccent;
    } else {
      final left = _cycle - _t;
      text = 'LÁSER 3-4: LISTO EN ${left.toStringAsFixed(0)}s';
      color = Colors.cyanAccent;
    }

    TextPaint(
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ).render(
      canvas,
      text,
      Vector2(PacManGame.virtualWidth / 2, 4),
      anchor: Anchor.topCenter,
    );
  }
}

// -----------------------------------------------------------------------------
// VELOCIDADES
// -----------------------------------------------------------------------------

/// Tabla central de velocidades del juego.
///
/// Todas las velocidades se expresan como un porcentaje de [base]
/// (casillas por segundo al 100 %). Para ajustar la dificultad basta con
/// cambiar estos valores.
class GameSpeeds {
  GameSpeeds._();

  /// Casillas por segundo al 100 %.
  static const double base = 5.0;

  /// Pac-Man en condiciones normales.
  static const double pacman = 0.80;

  /// Pac-Man mientras los fantasmas están asustados (corre un poco más).
  static const double pacmanFrightened = 0.90;

  /// Fantasma en condiciones normales.
  static const double ghost = 0.70;

  /// Fantasma asustado: cae drásticamente.
  static const double ghostFrightened = 0.40;

  /// Blinky en Cruise Elroy 1 (igual de rápido que Pac-Man).
  static const double elroy1 = 0.80;

  /// Blinky en Cruise Elroy 2 (más rápido que Pac-Man).
  static const double elroy2 = 0.88;

  /// Multiplicador dentro de los túneles laterales (50 %), para Pac-Man y
  /// para los fantasmas.
  static const double tunnelFactor = 0.50;

  /// Cruise Elroy 1 se activa cuando queda este porcentaje de puntos.
  static const double elroy1DotsFraction = 0.15;

  /// Cruise Elroy 2 se activa cuando queda este porcentaje de puntos.
  static const double elroy2DotsFraction = 0.07;

  /// Convierte un porcentaje de [base] a casillas por segundo.
  static double tiles(double percent) => base * percent;
}

/// Si es `true`, Blinky en Cruise Elroy ignora el modo Scatter y sigue
/// persiguiendo a Pac-Man, como en el original.
const bool kElroyIgnoresScatter = true;

// -----------------------------------------------------------------------------
// IA DE FANTASMAS (1/3): MODOS GLOBALES (MÁQUINA DE ESTADOS)
// -----------------------------------------------------------------------------

/// Modos globales de comportamiento de los fantasmas.
///
/// - [scatter]: cada fantasma se dirige a su esquina asignada.
/// - [chase]: cada fantasma persigue según su propia personalidad.
/// - [frightened]: los fantasmas huyen al azar y pueden ser comidos.
enum GhostMode { scatter, chase, frightened }

/// Controla el ciclo global de modos.
///
/// El ciclo base alterna Scatter y Chase según [schedule] (en segundos). El
/// modo Frightened se superpone al ciclo: mientras dura, el reloj del ciclo
/// base se pausa, igual que en el Pac-Man original.
///
/// Cada vez que debe ocurrir una inversión de dirección (cambio entre Scatter
/// y Chase, o inicio de Frightened) se incrementa [reversalTick]. Cada
/// fantasma compara ese contador con el último que vio y, si cambió, da la
/// vuelta en la siguiente casilla.
class GhostModeController {
  GhostModeController({
    this.schedule = const [7, 20, 7, 20, 5, 20, 5, double.infinity],
    this.frightenedDuration = 8.0,
  });

  /// Duración (s) de cada fase: Scatter, Chase, Scatter, Chase, ...
  /// La última fase es infinita (Chase permanente).
  final List<double> schedule;

  /// Duración (s) del modo Frightened.
  final double frightenedDuration;

  int _phase = 0;
  double _phaseTimer = 0.0;
  double _frightenedTimer = 0.0;
  int _reversalTick = 0;

  /// Modo del ciclo base (sin considerar Frightened).
  GhostMode get baseMode =>
      _phase.isEven ? GhostMode.scatter : GhostMode.chase;

  /// Indica si el modo Frightened está activo.
  bool get isFrightened => _frightenedTimer > 0;

  /// Modo efectivo actual.
  GhostMode get mode => isFrightened ? GhostMode.frightened : baseMode;

  /// Contador de inversiones de dirección pendientes (ver descripción de clase).
  int get reversalTick => _reversalTick;

  /// Segundos que le quedan al modo Frightened (0 si no está activo).
  double get frightenedTimeLeft => _frightenedTimer;

  /// Reinicia el ciclo (nueva partida).
  void reset() {
    _phase = 0;
    _phaseTimer = 0.0;
    _frightenedTimer = 0.0;
    _reversalTick = 0;
  }

  /// Avanza los temporizadores. Llamar una vez por frame.
  void update(double dt) {
    if (isFrightened) {
      _frightenedTimer = max(0.0, _frightenedTimer - dt);
      return; // El ciclo Scatter/Chase queda pausado.
    }
    if (_phase >= schedule.length - 1) return; // Última fase (infinita).

    _phaseTimer += dt;
    if (_phaseTimer >= schedule[_phase]) {
      _phaseTimer = 0.0;
      _phase++;
      _reversalTick++; // Scatter <-> Chase obliga a dar la vuelta.
    }
  }

  /// Activa el modo Frightened (al comer un power-up).
  void startFrightened() {
    _frightenedTimer = frightenedDuration;
    _reversalTick++; // Los fantasmas dan la vuelta al asustarse.
  }
}

// -----------------------------------------------------------------------------
// IA DE FANTASMAS (2/3): PERSONALIDADES Y CÁLCULO DE CASILLA OBJETIVO
// -----------------------------------------------------------------------------

/// Los cuatro fantasmas, identificados por su personalidad clásica.
///
/// - [blinky]: perseguidor directo.
/// - [pinky]: emboscador.
/// - [inky]: estratega (flanqueo).
/// - [clyde]: tímido / errante.
enum GhostType { blinky, pinky, inky, clyde }

/// Si es `true`, Pinky e Inky replican el error de desbordamiento del
/// Pac-Man original: cuando Pac-Man mira hacia arriba, el objetivo también se
/// desplaza a la izquierda. Por defecto está desactivado.
const bool kEmulateOriginalOverflowBug = false;

/// Datos que necesita una personalidad para calcular su objetivo.
class GhostContext {
  const GhostContext({
    required this.ghostTile,
    required this.pacTile,
    required this.pacDir,
    required this.blinkyTile,
  });

  /// Casilla del fantasma que calcula.
  final Vector2 ghostTile;

  /// Casilla actual de Pac-Man.
  final Vector2 pacTile;

  /// Última dirección en la que se movió Pac-Man.
  final Vector2 pacDir;

  /// Casilla de Blinky (la usa Inky para su vector de flanqueo).
  final Vector2 blinkyTile;
}

/// Casilla que está [tiles] casillas delante de [origin] en dirección [dir].
Vector2 _tilesAhead(Vector2 origin, Vector2 dir, int tiles) {
  final t = origin + dir * tiles.toDouble();
  if (kEmulateOriginalOverflowBug && dir.y < 0) {
    t.x -= tiles;
  }
  return t;
}

/// Estrategia de objetivo de un fantasma.
abstract class GhostPersonality {
  const GhostPersonality();

  /// Color de respaldo si no hay sprite disponible.
  Color get color;

  /// Sprite propio del fantasma. Si no existe, se usa `ghost.png`.
  String get spriteAsset;

  /// Esquina a la que se dirige en modo Scatter (puede estar fuera del mapa,
  /// como en el original, para que rodee la esquina).
  Vector2 get scatterTarget;

  /// Casilla objetivo en modo Chase.
  Vector2 chaseTarget(GhostContext c);

  /// Devuelve la personalidad correspondiente a [type].
  static GhostPersonality of(GhostType type) {
    switch (type) {
      case GhostType.blinky:
        return const BlinkyPersonality();
      case GhostType.pinky:
        return const PinkyPersonality();
      case GhostType.inky:
        return const InkyPersonality();
      case GhostType.clyde:
        return const ClydePersonality();
    }
  }
}

/// Blinky: su objetivo es siempre la casilla actual de Pac-Man.
class BlinkyPersonality extends GhostPersonality {
  const BlinkyPersonality();

  @override
  Color get color => Colors.red;

  @override
  String get spriteAsset => 'ghost.png';

  @override
  Vector2 get scatterTarget => Vector2(25, -2); // Arriba a la derecha

  @override
  Vector2 chaseTarget(GhostContext c) => c.pacTile.clone();
}

/// Pinky: apunta 4 casillas por delante de la dirección de Pac-Man.
class PinkyPersonality extends GhostPersonality {
  const PinkyPersonality();

  @override
  Color get color => Colors.pinkAccent;

  @override
  String get spriteAsset => 'ghost_pinky.png';

  @override
  Vector2 get scatterTarget => Vector2(1, -2); // Arriba a la izquierda

  @override
  Vector2 chaseTarget(GhostContext c) => _tilesAhead(c.pacTile, c.pacDir, 4);
}

/// Inky: usa a Pac-Man y a Blinky para formar un vector de flanqueo.
///
/// 1. Toma el punto "pivote": 2 casillas por delante de Pac-Man.
/// 2. Traza el vector desde Blinky hasta el pivote.
/// 3. Duplica ese vector: el objetivo es `pivote + (pivote - blinky)`.
class InkyPersonality extends GhostPersonality {
  const InkyPersonality();

  @override
  Color get color => Colors.cyanAccent;

  @override
  String get spriteAsset => 'ghost_inky.png';

  @override
  Vector2 get scatterTarget => Vector2(26, 17); // Abajo a la derecha

  @override
  Vector2 chaseTarget(GhostContext c) {
    final pivot = _tilesAhead(c.pacTile, c.pacDir, 2);
    return pivot * 2.0 - c.blinkyTile;
  }
}

/// Clyde: persigue a Pac-Man si está a más de 8 casillas; si está a 8 o
/// menos, se retira hacia su esquina.
class ClydePersonality extends GhostPersonality {
  const ClydePersonality();

  @override
  Color get color => Colors.orange;

  @override
  String get spriteAsset => 'ghost_clyde.png';

  @override
  Vector2 get scatterTarget => Vector2(0, 17); // Abajo a la izquierda

  @override
  Vector2 chaseTarget(GhostContext c) {
    final distance = c.ghostTile.distanceTo(c.pacTile);
    return distance > 8 ? c.pacTile.clone() : scatterTarget;
  }
}

// -----------------------------------------------------------------------------
// IA DE FANTASMAS (3/3): ENTIDAD FANTASMA
// -----------------------------------------------------------------------------

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
  Ghost(this.gridPos, this.type, {double releaseDelay = 0.0})
      : personality = GhostPersonality.of(type),
        _releaseTimer = releaseDelay;

  /// Personalidad de este fantasma.
  final GhostType type;

  /// Estrategia de objetivo asociada a [type].
  final GhostPersonality personality;

  /// Número visible del fantasma: 1 = Blinky, 2 = Pinky, 3 = Inky, 4 = Clyde.
  int get number => type.index + 1;

  /// Posición actual en coordenadas de la cuadrícula (columna, fila).
  Vector2 gridPos;

  /// Casilla de la base a la que regresan los fantasmas comidos.
  final Vector2 spawnGridPos = Vector2(13, 7);

  /// Dirección de movimiento actual.
  Vector2 moveDir = Vector2(0, -1);

  /// Avance hacia la siguiente casilla (0.0 a 1.0).
  double moveProgress = 0.0;

  /// Velocidad normal de un fantasma, en casillas por segundo.
  double get speed => GameSpeeds.tiles(GameSpeeds.ghost);

  /// Velocidad actual en casillas por segundo, según el estado:
  /// - Asustado: velocidad muy reducida.
  /// - Blinky: sube con Cruise Elroy 1 y 2.
  /// - Dentro de un túnel lateral: se reduce al 50 %.
  double _currentSpeed() {
    double percent;
    if (isScared) {
      percent = GameSpeeds.ghostFrightened;
    } else if (type == GhostType.blinky) {
      switch (game.elroyLevel) {
        case 2:
          percent = GameSpeeds.elroy2;
          break;
        case 1:
          percent = GameSpeeds.elroy1;
          break;
        default:
          percent = GameSpeeds.ghost;
      }
    } else {
      percent = GameSpeeds.ghost;
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

  double _releaseTimer;
  double _builderTimer = AbilityConfig.builderFirstDelay;
  int _seenReversalTick = 0;
  bool _pendingReverse = false;

  final Random random = Random();

  Sprite? ghostSprite;
  Sprite? scaredSprite;
  Sprite? moriSprite;

  /// Orden de desempate clásico cuando dos casillas están a igual distancia:
  /// arriba, izquierda, abajo, derecha.
  static final List<Vector2> _tieBreakOrder = [
    Vector2(0, -1),
    Vector2(-1, 0),
    Vector2(0, 1),
    Vector2(1, 0),
  ];

  Sprite? _tryLoad(String name) {
    try {
      return Sprite(game.images.fromCache(name));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    ghostSprite = _tryLoad(personality.spriteAsset) ?? _tryLoad('ghost.png');
    scaredSprite = _tryLoad('niga.png');
    moriSprite = _tryLoad('mori.png');

    _seenReversalTick = game.modeController.reversalTick;
    game.ghosts[type] = this;
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

  @override
  void onRemove() {
    if (game.ghosts[type] == this) {
      game.ghosts.remove(type);
    }
    super.onRemove();
  }

  /// Dibuja el campo del imán (solo Blinky), el cuerpo y el número.
  @override
  void render(Canvas canvas) {
    if (type == GhostType.blinky && game.magnetStrength > 0) {
      _renderMagnetField(canvas);
    }
    _renderBody(canvas);
    drawEntityLabel(canvas, '$number', size, personality.color);
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

  /// Dibuja el cuerpo del fantasma según su estado actual.
  void _renderBody(Canvas canvas) {
    if (isDead) {
      if (moriSprite != null) {
        moriSprite!.render(canvas, size: size);
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
          scaredSprite!.render(canvas, size: size);
        } else {
          canvas.drawRect(size.toRect(), Paint()..color = Colors.blue);
        }
        return;
      }
    }

    if (ghostSprite != null) {
      ghostSprite!.render(canvas, size: size);
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

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isGameWon) return;

    _syncReversal();
    if (isScared && !game.modeController.isFrightened) {
      isScared = false; // Terminó el modo Frightened.
    }

    if (isDead) {
      _pendingReverse = false;
      _updateDead(dt);
      return;
    }

    if (isLeavingSpawn) {
      _pendingReverse = false;
      _updateLeavingSpawn(dt);
      return;
    }

    _updateRoaming(dt);
    _updateBuilder(dt);
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
    final toTarget = targetPx - position;
    final dist = toTarget.length;

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
      position = position + toTarget / dist * (moriSpeed * dt);
    }
  }

  /// Espera su turno de salida y sube hasta salir de la casa (fila 5).
  void _updateLeavingSpawn(double dt) {
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

  /// Habilidad del Fantasma Constructor (solo Pinky): cada cierto tiempo, y
  /// solo en modo Chase, pide colocar una pared temporal detrás de Pac-Man.
  void _updateBuilder(double dt) {
    if (type != GhostType.pinky) return;
    if (isScared || game.modeController.mode != GhostMode.chase) return;

    _builderTimer -= dt;
    if (_builderTimer > 0) return;

    // Si no hay una casilla válida, reintenta en un segundo.
    _builderTimer =
        game.tryPlaceBuilderWall() ? AbilityConfig.builderCooldown : 1.0;
  }

  /// Colisión con Pac-Man: asustado = muere (200/400/800/1600 pts); normal =
  /// fin de partida.
  void _checkPlayerCollision() {
    if (!game.player.isMounted) return;
    if (toRect().overlaps(game.player.toRect())) {
      if (isScared) {
        isDead = true;
        isScared = false;
        moveProgress = 0.0;
        game.addScore(game.nextGhostEatScore());
      } else {
        game.triggerGameOver(cause: 'Te atrapó el fantasma $number');
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
      final dx = (col + dir.x) - target.x;
      final dy = (row + dir.y) - target.y;
      final d = dx * dx + dy * dy;
      if (d < bestDist) {
        bestDist = d;
        best = dir;
      }
    }
    return best.clone();
  }

  /// Casilla objetivo según el modo global y la personalidad.
  Vector2 _currentTarget() {
    if (!game.player.isMounted) return personality.scatterTarget;

    // Cruise Elroy: Blinky ignora el modo Scatter y sigue persiguiendo.
    final elroyHunting = kElroyIgnoresScatter &&
        type == GhostType.blinky &&
        game.elroyLevel > 0;

    if (game.modeController.baseMode == GhostMode.scatter && !elroyHunting) {
      return personality.scatterTarget;
    }
    return personality.chaseTarget(_buildContext());
  }

  /// Reúne los datos que necesitan las personalidades.
  GhostContext _buildContext() {
    Vector2 blinkyTile = gridPos;
    for (final g in game.children.whereType<Ghost>()) {
      if (g.type == GhostType.blinky) {
        blinkyTile = g.gridPos;
        break;
      }
    }
    return GhostContext(
      ghostTile: gridPos,
      pacTile: game.player.gridPos,
      pacDir: game.player.facing,
      blinkyTile: blinkyTile,
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
    moveProgress += tilesPerSecond * dt;

    final startX = game.mazeOffsetX + gridPos.x * game.tileSize + 4;
    final startY = 24 + gridPos.y * game.tileSize + 4;
    final endX = game.mazeOffsetX + (gridPos.x + moveDir.x) * game.tileSize + 4;
    final endY = 24 + (gridPos.y + moveDir.y) * game.tileSize + 4;
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
      updatePixelPosition();
      return true;
    }
    return false;
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