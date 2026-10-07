// =============================================================================
// JOVA-LAND
// Videojuego de laberinto desarrollado con Flutter y el motor de juegos Flame.
//
// Autor:        Gabriel Jovanny Osuna Martínez
// Plataformas:  Web, Android, iOS (orientación horizontal en móviles)
//
// -----------------------------------------------------------------------------
// DESCRIPCIÓN
// -----------------------------------------------------------------------------
//   El jugador recorre un laberinto comiendo puntos mientras huye de cuatro
//   fantasmas, cada uno con su propia personalidad y una habilidad especial.
//   Al comer un punto grande (power-up) los fantasmas se asustan (sprite
//   "niga") y pueden ser comidos. Un fantasma comido se convierte en "mori" y
//   regresa a su base, donde vuelve a ser un fantasma normal.
//
//   - Se GANA al comer todos los puntos (pantalla win.png).
//   - Se PIERDE si un fantasma normal toca al jugador o si lo alcanza el láser
//     (pantalla game_over.png).
//   - Una barra de progreso bajo el laberinto indica cuánto falta para ganar.
//
// -----------------------------------------------------------------------------
// CONTROLES
// -----------------------------------------------------------------------------
//   - Teclado: flechas direccionales. ESC pausa / reanuda.
//   - Táctil:  deslizar el dedo en la dirección deseada. Tocar la esquina
//              superior izquierda (zona invisible) pausa / reanuda.
//
// -----------------------------------------------------------------------------
// GLOSARIO (para quien no esté familiarizado con el desarrollo de videojuegos)
// -----------------------------------------------------------------------------
//   Casilla (tile)  Cada cuadro de la cuadrícula del laberinto. Todo el juego
//                   se mueve de casilla en casilla.
//   Cuadrícula      Coordenadas (columna, fila) de una casilla. La esquina
//   (grid)          superior izquierda es (0, 0). Se distingue de los
//                   "píxeles", que son las coordenadas reales de dibujo.
//   Frame           Cada imagen que se dibuja en pantalla. El juego se
//                   actualiza decenas de veces por segundo.
//   dt              "Delta time": segundos transcurridos desde el frame
//                   anterior. Se multiplica por la velocidad para que el
//                   juego vaya igual de rápido en cualquier dispositivo.
//   Sprite          Imagen que representa a un personaje u objeto.
//   Componente      Pieza del juego que se actualiza y se dibuja sola
//                   (jugador, fantasma, punto, muro...). En Flame se agrega
//                   al juego con add().
//   Overlay         Menú de Flutter (Game Over, Victoria, Pausa) dibujado
//                   encima del juego.
//   Lienzo virtual  Área fija de 900 x 432 en la que se diseña el juego. Se
//                   escala para ajustarse a cualquier pantalla.
//   Power-up        Punto grande que asusta a los fantasmas.
//
// -----------------------------------------------------------------------------
// ARQUITECTURA GENERAL
// -----------------------------------------------------------------------------
//   Flutter se encarga de la interfaz (menú, botones, overlays) y Flame de la
//   partida (laberinto, movimiento, colisiones). Se comunican así:
//
//     MainMenuScreen --(botón)--> GameScreen --contiene--> GameWidget
//                                                              |
//                                                          PacManGame
//                                       (hijos: PlayerPacman, Ghost, Dot, Wall,
//                                        TempWall, LaserLink, ProgressBar)
//
//   PacManGame es el "director": guarda el estado (puntos, victoria, derrota),
//   y los componentes consultan ese estado a través de `game`. Los overlays
//   leen el estado del juego y le piden acciones (reiniciar, pausar).
//
//   Qué ocurre en cada frame:
//     1. PacManGame.update() recalcula el imán y avanza el reloj de modos.
//     2. Cada componente ejecuta su update(dt): el jugador se mueve y recoge
//        puntos; los fantasmas deciden y se mueven; el láser y las paredes
//        temporales avanzan sus temporizadores.
//     3. PacManGame.render() aplica el escalado y Flame dibuja los componentes
//        ordenados por prioridad.
//
// -----------------------------------------------------------------------------
// ESTRUCTURA DEL ARCHIVO
// -----------------------------------------------------------------------------
//   1. Punto de entrada y configuración de la app
//   2. Pantallas de Flutter (componentes visuales compartidos, menú principal
//      y contenedor del juego)
//   3. Núcleo del juego (PacManGame)
//   4. Menús superpuestos (Game Over, Victoria y Pausa)
//   5. Entidades: PlayerPacman, Dot, ProgressBar, Ghost y Wall
//   6. IA de fantasmas: modos globales, personalidades y toma de decisiones
//   7. Velocidades: tabla relativa, túneles, modo asustado y Cruise Elroy
//   8. Habilidades especiales: Imán (Blinky), Constructor (Pinky) y
//      Láser (Inky y Clyde)
//
// -----------------------------------------------------------------------------
// RECURSOS REQUERIDOS (carpeta assets/images/, declarada en pubspec.yaml)
// -----------------------------------------------------------------------------
//   pacman.png, ghost.png, dot.png, power.png, niga.png, mori.png,
//   game_over.png, win.png, jova_logo.png
//   Opcionales: ghost_pinky.png, ghost_inky.png, ghost_clyde.png (para verlos
//   dentro de la partida hay que agregarlos a la lista de precarga de
//   PacManGame.onLoad; en el menú se muestran sin ese paso).
//   Si alguna imagen no está disponible, el juego usa figuras de respaldo
//   (círculos y cuadros de color) y continúa funcionando.
// =============================================================================

// Dependencias:
//  - material.dart:        widgets de Flutter (botones, textos, temas) y Canvas.
//  - foundation.dart:      utilidades de plataforma (kIsWeb, debugPrint).
//  - flame/game.dart:      FlameGame, el motor base del juego.
//  - flame/components.dart: PositionComponent, Sprite, Vector2 y TextComponent.
//  - flame/events.dart:    KeyboardEvents, para leer el teclado.
//  - services.dart:        control del sistema (orientación, teclas lógicas).
//  - dart:math:            min, max, sin, pi y Random.
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
  // Obligatorio antes de usar servicios de la plataforma (como la orientación)
  // cuando main() es asíncrono.
  WidgetsFlutterBinding.ensureInitialized();

  // Solo en Android e iOS: en web y escritorio no se modifica la orientación.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Pantalla completa: las barras del sistema se ocultan y reaparecen
    // temporalmente al deslizar desde el borde (modo "sticky").
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  runApp(const MyApp());
}

/// Widget raíz de la aplicación. Define el tema oscuro y la pantalla inicial.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Construye la app: sin banner de depuración, tema oscuro y el menú
  /// principal como pantalla inicial.
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
/// Alto del laberinto en el lienzo virtual (16 filas x 24 px = 384).
const double _mazeVirtualH = 16 * 24.0;

/// Colores de la identidad visual (los del texto de mis imágenes).
const Color _neonLime = Color(0xFFC8FF00);
/// Naranja de la identidad visual (relleno de las letras de mis imágenes).
const Color _neonOrange = Color(0xFFFF6A00);

/// Reserva exactamente el área que ocupa el laberinto en pantalla.
///
/// Usa la misma escala que [PacManGame], así las pantallas se estiran
/// "de lado a lado" del mapa en cualquier teléfono o ventana. [builder]
/// recibe la escala para dimensionar textos y botones proporcionalmente.
class MazeFrame extends StatelessWidget {
  const MazeFrame({super.key, required this.builder});

  /// Función que construye el contenido. Recibe la escala actual para que
  /// textos y separaciones crezcan o se reduzcan junto con la pantalla.
  final Widget Function(BuildContext context, double scale) builder;

  /// Calcula la escala del lienzo virtual y centra una caja del tamaño exacto
  /// del laberinto.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      // Misma fórmula que PacManGame.onGameResize: se usa el factor MENOR para que
      // el lienzo de 900 x 432 quepa completo sin deformarse.
      final scale = min(c.maxWidth / PacManGame.virtualWidth,
          c.maxHeight / PacManGame.virtualHeight);
      // Se centra una caja del tamaño del laberinto ya escalado.
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

  /// Texto del botón.
  final String label;
  /// Acción que se ejecuta al tocar el botón.
  final VoidCallback onPressed;
  /// Escala de pantalla (ver [MazeFrame]); dimensiona fuente y márgenes.
  final double s;
  /// Color principal del botón (relleno o contorno según [filled]).
  final Color color;
  /// `true` = botón con relleno (acción principal); `false` = solo contorno
  /// (acción secundaria).
  final bool filled;

  /// Construye el botón. La apariencia depende de [filled].
  @override
  Widget build(BuildContext context) {
    // Forma de píldora (esquinas muy redondeadas) compartida por ambas variantes.
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

    // Variante rellena: color sólido con un resplandor (sombra) del mismo color.
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
    // Variante hueca: solo contorno, para acciones secundarias.
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
/// - Debajo, una tira animada con los sprites de mi juego: el jugador se come
///   los puntos perseguido por los 4 fantasmas.
/// Si el logotipo no se encuentra, se muestra el título como texto.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

/// Estado del menú principal.
///
/// Usa [SingleTickerProviderStateMixin] para poder crear un
/// [AnimationController], que es el "reloj" que mueve todas las animaciones.
class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  /// Reloj de 8 s que mueve todas las animaciones del menú.
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat();

  /// Libera el controlador de animación al salir de la pantalla (evita fugas
  /// de memoria).
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Construye el menú en capas (de abajo hacia arriba): fondo, tira animada
  /// de personajes y contenido principal.
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
          // Tira animada con los personajes de mi juego.
          Positioned(
            left: 0,
            right: 0,
            bottom: 6,
            height: 46,
            child: _SpriteChase(animation: _ctrl),
          ),
          // Contenido principal dentro del área segura (evita notch y bordes).
          SafeArea(
            child: LayoutBuilder(builder: (context, c) {
              // "s" es la escala del lienzo virtual: hace que textos y separaciones se
              // adapten al tamaño real de la pantalla.
              final s = min(c.maxWidth / PacManGame.virtualWidth,
                  c.maxHeight / PacManGame.virtualHeight);
              return Center(
                child: SizedBox(
                  // La columna mide lo mismo que el laberinto, para que el menú y la partida
                  // se vean coherentes.
                  width: _mazeVirtualW * s,
                  child: Column(
                    children: [
                      SizedBox(height: 8 * s),
                      // Logotipo flotando.
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _ctrl,
                          builder: (context, child) => Transform.translate(
                            // Movimiento senoidal: 4 oscilaciones completas en cada ciclo de 8 s.
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
                          // Pulso de +-4 % de tamaño, 8 veces por ciclo (aprox. una vez por segundo).
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

/// Tira animada del menú hecha con los sprites de mi juego.
///
/// El jugador (`pacman.png`) recorre la pantalla comiéndose los puntos
/// (`dot.png`) mientras los 4 fantasmas lo persiguen. Cada fantasma usa su
/// sprite propio (`ghost_pinky.png`, ...) y, si no existe, `ghost.png`, igual
/// que dentro del juego. Si falta cualquier imagen se dibuja una figura de
/// respaldo. [animation] va de 0.0 a 1.0 y se repite.
class _SpriteChase extends StatelessWidget {
  const _SpriteChase({required this.animation});

  /// Animación de 0.0 a 1.0 que se repite; dirige todo el movimiento.
  final Animation<double> animation;

  /// Tamaño (px) de cada personaje.
  static const double _size = 34;
  /// Separación horizontal entre puntos (px).
  static const double _dotSpacing = 34;
  /// Distancia horizontal entre fantasmas consecutivos (px).
  static const double _ghostGap = 46;

  /// Del más cercano a Pac-Man al más lejano: Blinky, Pinky, Inky y Clyde.
  static const List<String> _ghostAssets = [
    'assets/images/ghost.png',
    'assets/images/ghost_pinky.png',
    'assets/images/ghost_inky.png',
    'assets/images/ghost_clyde.png',
  ];
  /// Colores de respaldo si falta la imagen de un fantasma (mismo orden que
  /// [_ghostAssets]).
  static const List<Color> _ghostColors = [
    Colors.red,
    Colors.pinkAccent,
    Colors.cyanAccent,
    Colors.orange,
  ];

  /// Sprite del jugador (círculo amarillo si falta la imagen).
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

  /// Sprite del fantasma número [i]. Respaldo en cadena: imagen propia ->
  /// `ghost.png` -> cuadro de color.
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

  /// Punto comestible (círculo blanco si falta `dot.png`).
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

  /// Dibuja un fotograma de la animación: puntos, fantasmas y jugador.
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
            // El jugador entra por la izquierda (fuera de pantalla) y sale por la derecha.
            // El margen extra permite que los fantasmas también salgan completos.
            final pacX = -230 + t * (w + 460);
            // Altura que centra verticalmente a los personajes en la tira.
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

/// Estado de la pantalla de juego: crea UNA sola instancia de [PacManGame] y
/// el nodo de foco del teclado.
class _GameScreenState extends State<GameScreen> {
  /// Instancia única del juego, creada una sola vez para toda la pantalla.
  final PacManGame gameInstance = PacManGame();

  /// Foco del teclado del juego (se devuelve al juego al salir de la pausa).
  final FocusNode _gameFocus = FocusNode();

  /// Libera el nodo de foco al salir de la pantalla.
  @override
  void dispose() {
    _gameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // Capas (de abajo hacia arriba): 1) el juego con los gestos de deslizamiento
      // y 2) la zona invisible de pausa.
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
            // Foco compartido: permite devolverle el teclado al juego al cerrar la pausa.
            focusNode: _gameFocus,
            // Registro de menús superpuestos. PacManGame los muestra u oculta por nombre,
            // por ejemplo con overlays.add('PauseMenu').
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
    // Primero se evalúa el nivel 2 (más estricto); si no se cumple, el nivel 1.
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

  /// Fantasmas comidos en el power-up actual; define los puntos 200/400/800/1600.
  int _ghostCombo = 0;
  /// Pasa a `true` al terminar onLoad(). Evita usar objetos `late` (como
  /// [player]) antes de que existan.
  bool _ready = false;

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

  /// Se llama cuando Pac-Man come un power-up: activa el modo Frightened y
  /// asusta a TODOS los fantasmas a la vez.
  void onPowerUpEaten() {
    modeController.startFrightened();
    // Cada power-up reinicia la cadena de puntos por fantasmas comidos.
    _ghostCombo = 0;
    // "children" contiene todos los componentes; se filtran solo los fantasmas.
    for (final g in children.whereType<Ghost>()) {
      g.triggerPanic();
    }
  }

  /// Puntos por comer un fantasma: 200, 400, 800 y 1600 con cada fantasma
  /// consecutivo durante el mismo power-up.
  int nextGhostEatScore() {
    // 1 << n equivale a 2 elevado a n: 200, 400, 800 y 1600 (tope en n = 3).
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

    // Vector que apunta desde el jugador hacia Blinky (en casillas).
    final toBlinky = tilePosOf(blinky) - tilePosOf(player);
    final dist = toBlinky.length;
    // Fuera del radio de acción (o superpuestos: evita dividir entre casi cero).
    if (dist > AbilityConfig.magnetRadiusTiles || dist < 0.001) return;

    // Intensidad lineal: 0 en el borde del radio y 1 pegado a Blinky.
    magnetStrength = 1.0 - dist / AbilityConfig.magnetRadiusTiles;
    // Dirección normalizada (longitud 1). El jugador la usa para saber si avanza
    // hacia Blinky o se aleja de él.
    magnetDir = toBlinky / dist;
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
    for (final g in children.whereType<Ghost>()) {
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
    if (cell == 1 || cell == 2) return false;

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

  /// Color de fondo del juego (negro).
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

  /// Factor de escala del lienzo virtual a la pantalla real.
  double _scale = 1.0;
  /// Margen (en píxeles reales) que centra el lienzo ya escalado.
  Vector2 _offset = Vector2.zero();

  /// Recalcula la escala y el desplazamiento cada vez que cambia el tamaño
  /// de la ventana o de la pantalla.
  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Se elige el factor MENOR para que el lienzo quepa completo sin deformarse
    // (quedan franjas negras en el lado sobrante).
    _scale = min(size.x / virtualWidth, size.y / virtualHeight);
    // El espacio sobrante se reparte por igual a ambos lados para centrar.
    _offset = Vector2(
      (size.x - virtualWidth * _scale) / 2,
      (size.y - virtualHeight * _scale) / 2,
    );
  }

  /// Aplica la traslación y escala calculadas antes de dibujar los componentes.
  @override
  void render(Canvas canvas) {
    // save/restore: la traslación y la escala solo afectan a este dibujado.
    // El orden importa: primero se traslada y después se escala.
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

    // Precarga de imágenes en la caché. Luego los componentes las leen con
    // images.fromCache(); si alguna falta, se registra el error y se continúa.
    for (final name in [
      'pacman.png',
      'ghost.png',
      'dot.png',
      'power.png',
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

    // Marcadores superiores. Sus posiciones están en coordenadas del lienzo
    // virtual.
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

    // add() inserta el componente en el árbol del juego; desde ese momento se
    // actualiza y se dibuja automáticamente.
    add(scoreText);
    add(highScoreText);

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
    // El imán se recalcula ANTES de actualizar a los componentes, para que el
    // jugador use el valor de este mismo frame.
    if (_ready && !isGameOver && !isGameWon) {
      _updateMagnet();
    }
    // Actualiza a todos los componentes hijos (jugador, fantasmas, láser...).
    super.update(dt);
    if (!isGameOver && !isGameWon) {
      // El reloj de modos (Scatter/Chase/Frightened) solo corre mientras se juega.
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
    // expand() aplana la matriz en una sola lista; se cuentan los pasillos con
    // punto (0) y los power-ups (3).
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
    // Cierra cualquier menú que haya quedado abierto de la partida anterior.
    overlays.remove('GameOverMenu');
    overlays.remove('GameWinMenu');
    overlays.remove('PauseMenu');
    resumeEngine(); // Un reinicio siempre quita la pausa.

    // Limpieza: se eliminan las entidades de la partida anterior antes de
    // reconstruirlas. Los marcadores de texto se conservan.
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

    // Reconstruye muros y puntos a partir de mazeGrid.
    _buildGridMaze();

    // Casilla inicial del jugador: columna 13, fila 12 (parte baja, centrada).
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

    // El récord se actualiza en vivo; por eso "score >= highScore" al terminar
    // indica que se igualó o superó el récord.
    if (score > highScore) {
      highScore = score;
      highScoreText.text = 'HIGH SCORE: $highScore';
    }

    // dotsRemaining lo decrementa el jugador al comer; al llegar a 0 se gana.
    if (dotsRemaining <= 0) {
      triggerGameWin();
    }
  }

  /// Recorre [mazeGrid] y crea los muros y puntos correspondientes.
  void _buildGridMaze() {
    for (int row = 0; row < mazeGrid.length; row++) {
      for (int col = 0; col < mazeGrid[row].length; col++) {
        int cell = mazeGrid[row][col];
        // Esquina superior izquierda de la casilla en píxeles virtuales:
        // desplazamiento del laberinto + columna * tamaño de casilla. Los 24 px
        // iniciales en Y dejan espacio para los marcadores.
        Vector2 pos =
            Vector2(mazeOffsetX + (col * tileSize), 24 + (row * tileSize));

        // Según el código de la casilla se crea un muro, un punto o un power-up.
        // Las casillas 2 (casa de fantasmas) no generan componentes.
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
    // Con la partida terminada se ignora el teclado.
    if (isGameOver || isGameWon) return KeyEventResult.ignored;

    // ESC se procesa antes que cualquier otra tecla y solo al presionarla
    // (no al mantenerla).
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      togglePause();
      return KeyEventResult.handled;
    }
    // En pausa se "consumen" las teclas para que no muevan al jugador.
    if (paused) return KeyEventResult.handled;

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

// =============================================================================
// 4. MENÚS SUPERPUESTOS (OVERLAYS)
// =============================================================================

/// Ficha de estadística (etiqueta pequeña + valor grande).
class _StatChip extends StatelessWidget {
  const _StatChip(this.label, this.value, this.color, this.s);

  /// Etiqueta pequeña (por ejemplo "PUNTUACIÓN").
  final String label;
  /// Valor destacado (por ejemplo "3390").
  final String value;
  /// Color del valor y del borde de la ficha.
  final Color color;
  /// Escala de pantalla (ver [MazeFrame]).
  final double s;

  /// Dibuja la ficha: etiqueta arriba y valor grande abajo.
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
  /// Color de [subtitle].
  final Color subtitleColor;

  /// Arma la tarjeta: velo oscuro -> marco del tamaño del laberinto ->
  /// animación de entrada -> contenido (imagen, estadísticas y botones).
  @override
  Widget build(BuildContext context) {
    return Material(
      // Velo semitransparente que oscurece el juego de fondo.
      color: Colors.black.withAlpha(175),
      child: MazeFrame(
        builder: (context, s) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 550),
            curve: Curves.easeOutBack,
            // Entrada animada: aparece con fundido y crece del 80 % al 100 % de su tamaño.
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

  /// Configura una [ResultCard] con los textos y botones de la derrota.
  @override
  Widget build(BuildContext context) {
    // Hay récord nuevo si se tiene puntuación y esta iguala al récord guardado
    // (highScore se actualiza en vivo durante la partida).
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

  /// Configura una [ResultCard] con los textos y botones de la victoria.
  @override
  Widget build(BuildContext context) {
    // Misma regla de récord que en la pantalla de Game Over.
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
  /// Juego al que se le pide pausar, reanudar o reiniciar.
  final PacManGame game;
  /// Nodo de foco del juego; se le devuelve el teclado al salir de la pausa.
  final FocusNode gameFocus;
  const PauseOverlay(this.game, this.gameFocus, {super.key});

  @override
  State<PauseOverlay> createState() => _PauseOverlayState();
}

/// Estado del menú de pausa. Tiene su propio [FocusNode] para poder recibir la
/// tecla ESC mientras el menú está abierto.
class _PauseOverlayState extends State<PauseOverlay> {
  /// Foco propio del overlay (el juego pierde el foco al abrirse este menú).
  final FocusNode _focus = FocusNode();

  /// Libera el nodo de foco.
  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Reanuda la partida y devuelve el teclado al juego.
  void _resume() {
    widget.game.togglePause();
    widget.gameFocus.requestFocus(); // Devuelve el teclado al juego.
  }

  /// Dibuja el panel de pausa y escucha la tecla ESC para reanudar.
  @override
  Widget build(BuildContext context) {
    // KeyboardListener captura ESC dentro del overlay: mientras está abierto, el
    // teclado ya no llega al juego.
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
  // Punto de anclaje: centro horizontal de la entidad y 1 px por encima de su
  // borde superior.
  final anchorPoint = Vector2(entitySize.x / 2, -1);

  // Truco de legibilidad: el texto se dibuja dos veces. Primero el contorno
  // negro (trazo) y encima el relleno de color.
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

  /// Crea al jugador en la casilla [gridPos] (columna, fila).
  PlayerPacman(this.gridPos);

  /// Carga el sprite desde la caché y fija el tamaño del jugador.
  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      // fromCache lanza una excepción si la imagen no se cargó. Se ignora a
      // propósito: el jugador se dibujará con la figura de respaldo.
      sprite = Sprite(game.images.fromCache('pacman.png'));
    } catch (_) {}
    // El sprite mide 16 px dentro de una casilla de 24 px (4 px de margen por
    // lado).
    size = Vector2(20, 20);
    updatePixelPosition();
  }

  /// Convierte la posición de cuadrícula a píxeles y la aplica al componente.
  void updatePixelPosition() {
    position = Vector2(
      // El +4 centra el sprite de 16 px dentro de la casilla de 24 px.
      game.mazeOffsetX + gridPos.x * game.tileSize + 4,
      24 + gridPos.y * game.tileSize + 4,
    );
  }

  /// Registra la próxima dirección deseada por el jugador.
  void changeDirection(Vector2 newDir) {
    nextDir = newDir.clone();
  }

  /// Dibuja el sprite (o un círculo amarillo) y la etiqueta "JUGADOR" encima.
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

  /// Lógica de cada frame: decide la dirección, avanza y recoge puntos.
  @override
  void update(double dt) {
    super.update(dt);
    // Con la partida terminada, el jugador queda congelado.
    if (game.isGameOver || game.isGameWon) return;

    // Solo se decide una nueva dirección cuando está exactamente en una casilla.
    if (moveProgress == 0.0) {
      if (nextDir != Vector2.zero()) {
        // Casilla a la que apunta el giro solicitado.
        int nextX = (gridPos.x + nextDir.x).toInt();
        int nextY = (gridPos.y + nextDir.y).toInt();
        // Si no hay muro, el giro se ejecuta. Si lo hay, el pedido se conserva en
        // nextDir hasta que sea posible (permite anticipar giros).
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
      // casillas/segundo x segundos = fracción de casilla recorrida. Así la
      // velocidad no depende de los cuadros por segundo del dispositivo.
      moveProgress += speed * dt;

      double startX = game.mazeOffsetX + gridPos.x * game.tileSize + 4;
      double startY = 24 + gridPos.y * game.tileSize + 4;
      double endX = game.mazeOffsetX + (gridPos.x + moveDir.x) * game.tileSize + 4;
      double endY = 24 + (gridPos.y + moveDir.y) * game.tileSize + 4;

      // Interpolación lineal entre el origen y el destino. min(..., 1.0) evita
      // pasarse de la casilla destino.
      position.x = startX + (endX - startX) * min(moveProgress, 1.0);
      position.y = startY + (endY - startY) * min(moveProgress, 1.0);

      // Llegó a la nueva casilla: se confirma la posición de cuadrícula y se
      // reinicia el avance.
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
        // Se anota la casilla visitada: el Fantasma Constructor usa este rastro.
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

    // "facing" conserva la última dirección aunque el jugador se detenga; Pinky e
    // Inky la usan para anticiparse.
    if (moveDir != Vector2.zero()) facing = moveDir.clone();

    // Recolección de puntos: normal = 10 pts, power-up = 100 pts + pánico.
    // toList() crea una copia: permite eliminar puntos del árbol mientras se
    // recorre la lista.
    game.children.whereType<Dot>().toList().forEach((dot) {
      // "eaten" evita contar dos veces el mismo punto.
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
/// Hay dos tipos, cada uno con su propia imagen:
/// - Punto normal (`dot.png`): mide [dotSize] y otorga 10 puntos.
/// - Power-up (`power.png`): mide [powerSize] (casi toda la casilla, para que
///   su imagen se distinga bien), otorga 100 puntos y asusta a los fantasmas.
///   Si `power.png` no existe, usa `dot.png`.
class Dot extends PositionComponent with HasGameReference<PacManGame> {
  /// Sprite del punto (`dot.png` o `power.png`). Si es nulo se dibuja un
  /// círculo blanco.
  Sprite? sprite;

  /// Posición en coordenadas de la cuadrícula (columna, fila).
  Vector2 gridPos;

  /// Indica si es un punto grande (power-up).
  bool isPowerUp;

  /// Marca el punto como ya comido (evita contarlo dos veces).
  bool eaten = false;

  /// Tamaño (px) de un punto normal. Se ve en una casilla de 24 px.
  static const double dotSize = 12.0;

  /// Tamaño (px) de un power-up. La casilla mide 24 px, así que 20 px lo deja
  /// casi a ancho completo con 2 px de margen por lado. No conviene pasar de
  /// 24, porque invadiría las casillas vecinas.
  static const double powerSize = 20.0;

  Dot(this.gridPos, {this.isPowerUp = false});

  /// Carga el sprite y calcula tamaño y posición. Los power-ups miden el doble.
  @override
  Future<void> onLoad() async {
    super.onLoad();
    // Cada tipo de punto tiene su imagen. Si power.png no existe, el power-up
    // usa dot.png (ya agrandado) para no quedar invisible. fromCache lanza una
    // excepción si la imagen no se cargó; se ignora y se prueba la siguiente.
    final candidates = isPowerUp ? ['power.png', 'dot.png'] : ['dot.png'];
    for (final name in candidates) {
      try {
        sprite = Sprite(game.images.fromCache(name));
        break;
      } catch (_) {}
    }
    size = Vector2.all(isPowerUp ? powerSize : dotSize);
    // Se centra el punto dentro de su casilla.
    position = Vector2(
      game.mazeOffsetX + gridPos.x * game.tileSize + (game.tileSize - size.x) / 2,
      24 + gridPos.y * game.tileSize + (game.tileSize - size.y) / 2,
    );
  }

  /// Dibuja el punto (círculo blanco si falta la imagen).
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
  /// Prioridad 40: se dibuja por encima del laberinto y por debajo del láser (50).
  ProgressBar() {
    priority = 40;
  }

  @override
  void render(Canvas canvas) {
    final total = game.totalDots;
    // Fracción completada (0.0 a 1.0). Se protege el caso total == 0 para no
    // dividir entre cero.
    final progress = total == 0
        ? 0.0
        : ((total - game.dotsRemaining) / total).clamp(0.0, 1.0).toDouble();

    final x = game.mazeOffsetX;
    // 414 = justo debajo del laberinto (24 + 16 x 24 = 408) más un pequeño margen.
    const y = 414.0;
    final width = game.maxCols * game.tileSize; // Mismo ancho que el laberinto
    const height = 12.0;

    // Fondo (riel) de la barra con esquinas redondeadas.
    final bg = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, height), const Radius.circular(6));
    canvas.drawRRect(bg, Paint()..color = const Color(0xFF222222));

    // Relleno: su ancho es proporcional al progreso y su color pasa de amarillo
    // a verde mientras se llena.
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

    // Texto con el porcentaje, centrado sobre la barra.
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

/// Producto cruzado 2D de (a - o) x (b - o). Su signo indica de qué lado de
/// la recta o->a queda el punto b; es la base de la prueba de intersección.
double _cross(Vector2 o, Vector2 a, Vector2 b) =>
    (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

/// Distancia de un punto [p] al segmento [a]-[b].
double _distPointToSegment(Vector2 p, Vector2 a, Vector2 b) {
  final ab = b - a;
  final len2 = ab.length2;
  // Segmento degenerado (a == b): la distancia es simplemente a ese punto.
  if (len2 == 0) return p.distanceTo(a);
  // Proyección de p sobre la recta, limitada a [0, 1] para quedarse dentro del
  // segmento: t = 0 es el extremo a y t = 1 el extremo b.
  final t = ((p - a).dot(ab) / len2).clamp(0.0, 1.0).toDouble();
  return p.distanceTo(a + ab * t);
}

/// Indica si los segmentos [p1]-[p2] y [q1]-[q2] se cruzan.
bool _segmentsIntersect(Vector2 p1, Vector2 p2, Vector2 q1, Vector2 q2) {
  // Dos segmentos se cruzan si los extremos de cada uno quedan en lados
  // opuestos del otro (signos distintos -> producto negativo).
  final d1 = _cross(q1, q2, p1);
  final d2 = _cross(q1, q2, p2);
  final d3 = _cross(p1, p2, q1);
  final d4 = _cross(p1, p2, q2);
  return (d1 * d2 < 0) && (d3 * d4 < 0);
}

/// Centro en píxeles de un componente (su `position` es la esquina superior
/// izquierda).
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

  /// Columna de la casilla que ocupa la pared.
  final int col;
  /// Fila de la casilla que ocupa la pared.
  final int row;

  /// `false` durante el aviso; `true` cuando ya bloquea el paso.
  bool _solid = false;
  /// Segundos transcurridos en la fase de aviso.
  double _warnTimer = 0.0;
  /// Segundos transcurridos en la fase sólida.
  double _solidTimer = 0.0;

  /// Fija el tamaño (una casilla) y la posición en píxeles.
  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(game.tileSize, game.tileSize);
    position = Vector2(
      game.mazeOffsetX + col * game.tileSize,
      24 + row * game.tileSize,
    );
  }

  /// Avanza el ciclo de vida: aviso -> sólida -> desaparece.
  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isGameWon) return;

    if (!_solid) {
      // Fase 1: aviso. Todavía no bloquea el paso.
      _warnTimer += dt;
      if (_warnTimer >= AbilityConfig.builderWarningSeconds) {
        // Si alguien está en la casilla, se retrasa 0.3 s para no atrapar a nadie
        // dentro de la pared.
        if (game.isTileOccupied(col, row)) {
          _warnTimer = AbilityConfig.builderWarningSeconds - 0.3; // Espera
        } else {
          // Fase 2: se registra en solidWalls, lo que hace que isWalkable() devuelva
          // false para esta casilla.
          _solid = true;
          game.solidWalls.add(tileKey(col, row));
        }
      }
    } else {
      // Fase 3: pasado el tiempo de duración, la pared se elimina.
      _solidTimer += dt;
      if (_solidTimer >= AbilityConfig.builderDurationSeconds) {
        removeFromParent();
      }
    }
  }

  /// Al eliminarse libera la casilla en los registros del juego (también ocurre
  /// al reiniciar la partida).
  @override
  void onRemove() {
    final key = tileKey(col, row);
    game.solidWalls.remove(key);
    if (game.tempWalls[key] == this) {
      game.tempWalls.remove(key);
    }
    super.onRemove();
  }

  /// Dibuja el aviso parpadeante o la pared sólida según la fase.
  @override
  void render(Canvas canvas) {
    final rect = size.toRect();

    if (!_solid) {
      // Parpadeo: alterna 6 veces por segundo entre dos niveles de opacidad.
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

  /// Duración total de un ciclo: activo + enfriamiento.
  static const double _cycle =
      AbilityConfig.laserActiveSeconds + AbilityConfig.laserCooldownSeconds;

  /// Tiempo dentro del ciclo. Empieza al inicio del enfriamiento para dar
  /// margen al jugador al comenzar la partida.
  double _t = AbilityConfig.laserActiveSeconds;

  /// Reloj que anima el brillo pulsante del rayo.
  double _pulse = 0.0;
  /// Centro del jugador en el frame anterior; permite detectar si cruzó el rayo
  /// entre dos frames.
  Vector2? _prevPac;

  /// `true` mientras el rayo está encendido y es mortal.
  bool get _isActive => _t < AbilityConfig.laserActiveSeconds;
  /// `true` durante el aviso de la línea punteada (inofensiva).
  bool get _isWarning =>
      !_isActive && _t >= _cycle - AbilityConfig.laserWarningSeconds;

  /// Un fantasma puede sostener el rayo solo si existe, está vivo, ya salió de
  /// la base y no está asustado.
  bool _operational(Ghost? g) =>
      g != null && g.isMounted && !g.isDead && !g.isLeavingSpawn && !g.isScared;

  /// Avanza el ciclo del láser y comprueba si alcanzó al jugador.
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

      // Caso 1: el jugador está (casi) sobre la línea en este frame.
      final onBeam =
          _distPointToSegment(pac, a, b) <= AbilityConfig.laserHitRadius;
      // Caso 2: entre el frame anterior y este, el jugador atravesó el rayo
      // (ocurre con movimientos rápidos).
      final crossed =
          _prevPac != null && _segmentsIntersect(_prevPac!, pac, a, b);

      if (onBeam || crossed) {
        game.triggerGameOver(
            cause: 'Te alcanzó el láser de Inky (3) y Clyde (4)');
      }
    }
    // Se guarda la posición actual para compararla en el siguiente frame.
    _prevPac = pac;
  }

  /// Dibuja el contador del láser y, si corresponde, el rayo o su aviso.
  @override
  void render(Canvas canvas) {
    _renderHud(canvas);

    final inky = game.ghosts[GhostType.inky];
    final clyde = game.ghosts[GhostType.clyde];
    if (!_operational(inky) || !_operational(clyde)) return;

    final a = _centerOf(inky!);
    final b = _centerOf(clyde!);

    if (_isActive) {
      // Valor que oscila entre 0 y 1 y modula la intensidad del halo rojo.
      final pulse = 0.5 + 0.5 * sin(_pulse * 14);
      // Rayo en dos capas: un halo rojo grueso y semitransparente, y encima un
      // núcleo blanco delgado que da el efecto de láser brillante.
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
      // Trazos de 5 px cada 10 px: forman la línea punteada.
      for (double d = 0; d < len; d += 10) {
        final p1 = a + unit * d;
        final p2 = a + unit * min(d + 5, len);
        canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), paint);
      }
    }
  }

  /// Contador del láser, centrado en la parte superior.
  void _renderHud(Canvas canvas) {
    // Se elige el mensaje y el color según el estado del ciclo: pausa, activo,
    // cargando o enfriamiento.
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

  /// Índice de la fase actual en [schedule] (par = Scatter, impar = Chase).
  int _phase = 0;
  /// Segundos acumulados en la fase actual.
  double _phaseTimer = 0.0;
  /// Segundos restantes de Frightened (0 = inactivo).
  double _frightenedTimer = 0.0;
  /// Contador que aumenta cada vez que los fantasmas deben dar la vuelta.
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
  // Punto desplazado "tiles" casillas en la dirección dada. Puede quedar fuera
  // del mapa: es solo un objetivo de cálculo, no una casilla a pisar.
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
    // Paso 1: punto pivote, 2 casillas por delante del jugador.
    final pivot = _tilesAhead(c.pacTile, c.pacDir, 2);
    // Pasos 2 y 3: pivote + (pivote - Blinky) = 2 x pivote - Blinky, es decir, el
    // punto simétrico de Blinky respecto al pivote.
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
    // Distancia en casillas entre Clyde y el jugador.
    final distance = c.ghostTile.distanceTo(c.pacTile);
    // Lejos: persigue. Cerca: huye a su esquina (por eso es "tímido").
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
  /// Crea un fantasma en [gridPos] del tipo [type]. [releaseDelay] son los
  /// segundos que espera dentro de la base antes de salir.
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

  /// Segundos que faltan para que el fantasma salga de la base.
  double _releaseTimer;
  /// Cuenta regresiva para la próxima pared (solo Pinky la usa).
  double _builderTimer = AbilityConfig.builderFirstDelay;
  /// Último valor de reversalTick que este fantasma ya atendió.
  int _seenReversalTick = 0;
  /// `true` cuando debe dar la vuelta en cuanto sea posible.
  bool _pendingReverse = false;

  /// Generador de azar para el modo asustado.
  final Random random = Random();

  /// Sprite en estado normal.
  Sprite? ghostSprite;
  /// Sprite en estado asustado (niga.png).
  Sprite? scaredSprite;
  /// Sprite del fantasma comido (mori.png).
  Sprite? moriSprite;

  /// Orden de desempate clásico cuando dos casillas están a igual distancia:
  /// arriba, izquierda, abajo, derecha.
  static final List<Vector2> _tieBreakOrder = [
    Vector2(0, -1),
    Vector2(-1, 0),
    Vector2(0, 1),
    Vector2(1, 0),
  ];

  /// Obtiene un sprite de la caché; devuelve null si no está disponible.
  Sprite? _tryLoad(String name) {
    try {
      return Sprite(game.images.fromCache(name));
    } catch (_) {
      return null;
    }
  }

  /// Carga los sprites, se registra en el juego y fija tamaño y posición.
  @override
  Future<void> onLoad() async {
    super.onLoad();
    // Respaldo en cadena: sprite propio -> ghost.png -> (si ambos faltan) cuadro
    // de color al dibujar.
    ghostSprite = _tryLoad(personality.spriteAsset) ?? _tryLoad('ghost.png');
    scaredSprite = _tryLoad('niga.png');
    moriSprite = _tryLoad('mori.png');

    // Se sincroniza para no dar la vuelta por cambios de modo ocurridos antes de
    // que este fantasma existiera.
    _seenReversalTick = game.modeController.reversalTick;
    // Se registra por tipo para que las habilidades (imán, láser) lo encuentren
    // rápido.
    game.ghosts[type] = this;
    size = Vector2(20, 20);
    updatePixelPosition();
  }

  /// Convierte la posición de cuadrícula a píxeles y la aplica al componente.
  void updatePixelPosition() {
    position = Vector2(
      game.mazeOffsetX + gridPos.x * game.tileSize + 4,
      24 + gridPos.y * game.tileSize + 4,
    );
  }

  /// Se da de baja del registro de fantasmas del juego.
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
    // 2) Prioridad de estados: muerto > saliendo de la base > normal/asustado.
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

  /// Máquina de estados de cada frame: muerto, saliendo de la base o
  /// recorriendo el laberinto (normal o asustado).
  @override
  void update(double dt) {
    super.update(dt);
    if (game.isGameOver || game.isGameWon) return;

    // 1) Se entera de si debe dar la vuelta.
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

    // 3) Comportamiento normal por el laberinto.
    _updateRoaming(dt);
    _updateBuilder(dt);
    // 4) Colisión con el jugador: comerlo o ser comido.
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
    // Vector hacia la base. El mori avanza en línea recta (ignora los muros).
    final toTarget = targetPx - position;
    final dist = toTarget.length;

    // Si llegaría en este frame, "aterriza" y revive como fantasma normal.
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
      // toTarget / dist = dirección unitaria; x (velocidad * dt) = paso de este
      // frame.
      position = position + toTarget / dist * (moriSpeed * dt);
    }
  }

  /// Espera su turno de salida y sube hasta salir de la casa (fila 5).
  void _updateLeavingSpawn(double dt) {
    // Todavía en espera dentro de la base.
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
    // La fila 5 es el pasillo justo fuera de la casa: al llegar ahí ya es un
    // fantasma normal.
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
      // A mitad de camino: la posición lógica pasa a la casilla destino y se
      // invierte la dirección. El avance se espeja (1 - p), por eso no hay saltos
      // visuales.
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
    // Colisión por rectángulos: basta con que se solapen.
    if (toRect().overlaps(game.player.toRect())) {
      if (isScared) {
        isDead = true;
        isScared = false;
        moveProgress = 0.0;
        // Comer un fantasma suma 200, 400, 800 o 1600 según la cadena.
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
      // Regla clásica: un fantasma no puede retroceder.
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
      // Distancia al cuadrado desde la casilla vecina hasta el objetivo. No se saca
      // raíz cuadrada: para comparar basta y es más rápido.
      final dx = (col + dir.x) - target.x;
      final dy = (row + dir.y) - target.y;
      final d = dx * dx + dy * dy;
      // "<" estricto: en un empate gana la primera dirección del orden de
      // desempate (arriba, izquierda, abajo, derecha).
      if (d < bestDist) {
        bestDist = d;
        best = dir;
      }
    }
    return best.clone();
  }

  /// Casilla objetivo según el modo global y la personalidad.
  Vector2 _currentTarget() {
    // Sin jugador en el árbol (por ejemplo, durante un reinicio) se usa la
    // esquina como valor seguro.
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
    // Valor por defecto por si Blinky aún no existe; se reemplaza al encontrarlo.
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
    // Igual que en el jugador: casillas/segundo x segundos = fracción de casilla.
    moveProgress += tilesPerSecond * dt;

    final startX = game.mazeOffsetX + gridPos.x * game.tileSize + 4;
    final startY = 24 + gridPos.y * game.tileSize + 4;
    final endX = game.mazeOffsetX + (gridPos.x + moveDir.x) * game.tileSize + 4;
    final endY = 24 + (gridPos.y + moveDir.y) * game.tileSize + 4;
    // Se limita a 1.0 para no pasar de la casilla destino en el último frame.
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

  /// Dibuja el muro como un cuadrado azul sólido.
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()..color = const Color(0xFF1E1EEB);
    canvas.drawRect(size.toRect(), paint);
  }
}