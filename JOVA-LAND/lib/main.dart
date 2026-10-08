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
//   Los fantasmas son Shardox, Vespakron, Kyros y Pyros. Al comer una mydra
//   (punto grande) todos se asustan (cada uno cambia a su propia versión
//   "niga") y pueden ser comidos. Un fantasma comido se convierte en "mori" y
//   regresa a su base, donde vuelve a ser un fantasma normal.
//
//   - Se GANA al comer todas las rimoras (puntos) y mydras (pantalla win.png).
//   - El jugador tiene 3 VIDAS (3 corazones a la derecha del laberinto). Si un
//     fantasma normal lo toca o lo alcanza el láser, pierde una vida: Pac-Man
//     parpadea 3 s y la partida continúa con los puntos ya comidos.
//   - Se PIERDE al quedarse sin las 3 vidas (pantalla game_over.png); al
//     reiniciar, todo empieza desde cero.
//   - Cada vez que empieza o se reanuda una partida aparece una cuenta
//     regresiva de 3 a 0 antes de poder moverse.
//   - Al abrir la app se pide un nombre (máx. 12 caracteres) que aparece sobre
//     el Pac-Man durante la partida.
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
//   Rimora          Punto normal del laberinto (imagen rimora.png).
//   Mydra           Punto grande (power-up) que asusta a los fantasmas
//                   (imagen mydra.png).
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
//                                       (hijos: PlayerPacman, Ghost, Rimora, Wall,
//                                        TempWall, LaserLink, LivesDisplay,
//                                        CountdownOverlay)
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
//   5. Entidades: PlayerPacman, Rimora, LivesDisplay, CountdownOverlay, Ghost y Wall
//   6. IA de fantasmas: modos globales, personalidades y toma de decisiones
//   7. Velocidades: tabla relativa, túneles, modo asustado y Cruise Elroy
//   8. Habilidades especiales: Imán (Shardox), Constructor (Vespakron) y
//      Láser (Kyros y Pyros)
//
// -----------------------------------------------------------------------------
// DISEÑO VISUAL
// -----------------------------------------------------------------------------
//   Estética synthwave: fondo morado profundo (0xFF07051A / 0xFF2A0F5C) con
//   acentos rosa y cian, muros con borde neón violeta y estrellas fijas en el
//   menú. Ningún elemento decorativo parpadea. Las vidas son corazones de
//   cristal facetados que se rompen en pedazos al perderse.
//
// -----------------------------------------------------------------------------
// RECURSOS REQUERIDOS (carpeta assets/images/, declarada en pubspec.yaml)
// -----------------------------------------------------------------------------
//   Jugador (Vance):      vance.png
//   Pantallas:            jova_logo.png, game_over.png, win.png
//   Rimora y mydra:       rimora.png, mydra.png
//   Fantasma comido:      mori.png
//   Fantasmas (normales): shardox.png, vespakron.png, kyros.png, pyros.png
//   Fantasmas (asustados): shardoxniga.png, vespakronniga.png,
//                         kyrosniga.png, pyrosniga.png
//   Icono de la app:      icon.png
//   Todos deben estar declarados en la sección assets de pubspec.yaml, y los
//   nombres deben coincidir exactamente (en minúsculas).
//   Los nombres de archivo de los fantasmas se definen en un solo lugar: las
//   clases ShardoxPersonality, VespakronPersonality, KyrosPersonality y
//   PyrosPersonality (propiedades spriteAsset y scaredSpriteAsset).
//   Si alguna imagen no está disponible, el juego usa figuras de respaldo
//   (círculos y cuadros de color) y continúa funcionando.
// =============================================================================

// Dependencias:
//  - material.dart:        widgets de Flutter (botones, textos, temas) y Canvas.
//  - foundation.dart:      utilidades de plataforma (kIsWeb, debugPrint).
//  - flame/game.dart:      FlameGame, el motor base del juego.
//  - flame/components.dart: PositionComponent, Sprite, Vector2 y TextComponent.
//  - flame/events.dart:    KeyboardEvents, para leer el teclado.
//  - services.dart:        control del sistema (orientación, teclas lógicas,
//                          rootBundle para comprobar si existe una imagen).
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

/// Nombre del jugador. Se pide al abrir la app y se muestra sobre el Pac-Man.
/// Vive mientras la app está abierta (también al volver al menú principal).
String playerName = '';

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

/// Cuadro de diálogo "Por favor escriba un nombre".
///
/// Acepta letras, números y espacios, con un límite de 12 caracteres. Devuelve
/// el nombre (sin espacios sobrantes) al aceptar. Si [canCancel] es `false`
/// no se puede cerrar sin escribir un nombre.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial, required this.canCancel});

  /// Texto con el que arranca el campo (el nombre actual, si ya hay uno).
  final String initial;
  /// Si es `true` se muestra el botón Cancelar y se permite cerrar con "atrás".
  final bool canCancel;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Acepta el nombre solo si no está vacío.
  void _submit() {
    final name = _c.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.canCancel,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A0F5C), Color(0xFF07051A)],
              ),
              border: Border.all(color: Colors.cyanAccent, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.cyanAccent.withAlpha(90),
                    blurRadius: 26,
                    spreadRadius: 1),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'POR FAVOR ESCRIBA UN NOMBRE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: _neonLime,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Aparecerá sobre tu Pac-Man (máximo 12 letras)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _c,
                  autofocus: true,
                  maxLength: 12,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[\p{L}\p{N} ]', unicode: true)),
                  ],
                  cursorColor: Colors.pinkAccent,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: 'TU NOMBRE',
                    hintStyle: const TextStyle(
                        color: Colors.white24, letterSpacing: 3),
                    counterStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Colors.pinkAccent, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Colors.cyanAccent, width: 2),
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                // El botón se atenúa mientras el campo esté vacío.
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _c,
                  builder: (context, value, _) {
                    final empty = value.text.trim().isEmpty;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.canCancel) ...[
                          _NeonButton(
                            label: 'CANCELAR',
                            s: 1.4,
                            filled: false,
                            color: Colors.white,
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Opacity(
                          opacity: empty ? 0.4 : 1.0,
                          child: _NeonButton(
                              label: 'ACEPTAR', s: 1.4, onPressed: _submit),
                        ),
                      ],
                    );
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

/// Muestra la ventana "¿Cómo se juega?" (PC y móvil).
Future<void> _showHowToPlay(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _InfoDialog(
      title: '¿CÓMO SE JUEGA?',
      accent: Colors.cyanAccent,
      child: _HowToPlayContent(),
    ),
  );
}

/// Muestra la ventana con todos los personajes (foto y nombre).
Future<void> _showCharacters(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _InfoDialog(
      title: 'PERSONAJES',
      accent: Colors.pinkAccent,
      child: _CharactersContent(),
    ),
  );
}

/// Marco neón reutilizable para las ventanas informativas del menú: título,
/// contenido desplazable y botón Cerrar.
class _InfoDialog extends StatelessWidget {
  const _InfoDialog({
    required this.title,
    required this.accent,
    required this.child,
  });

  /// Título de la ventana.
  final String title;
  /// Color del borde, del resplandor y del título.
  final Color accent;
  /// Contenido (se desplaza si no cabe en pantalla).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A0F5C), Color(0xFF07051A)],
            ),
            border: Border.all(color: accent, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: accent.withAlpha(90), blurRadius: 26, spreadRadius: 1),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: accent,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(child: SingleChildScrollView(child: child)),
              const SizedBox(height: 12),
              _NeonButton(
                label: 'CERRAR',
                s: 1.2,
                filled: false,
                color: accent,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bloque de texto con título de color y una lista de líneas con viñeta.
class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    required this.color,
    required this.lines,
  });

  final String title;
  final Color color;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '•  $line',
                style: const TextStyle(
                    fontSize: 13, height: 1.3, color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }
}

/// Contenido de "¿Cómo se juega?": objetivo, controles de PC y de móvil, y
/// algunos consejos.
class _HowToPlayContent extends StatelessWidget {
  const _HowToPlayContent();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoSection(
          title: 'OBJETIVO',
          color: _neonLime,
          lines: [
            'Come todas las rimoras del laberinto sin que los fantasmas te atrapen.',
            'Tienes 3 vidas (corazones de cristal). Si pierdes las 3, la partida termina.',
          ],
        ),
        _InfoSection(
          title: 'EN COMPUTADORA',
          color: Colors.cyanAccent,
          lines: [
            'Flechas del teclado: mueve a tu personaje.',
            'ESC: pausa o reanuda el juego.',
          ],
        ),
        _InfoSection(
          title: 'EN CELULAR O TABLET',
          color: Colors.pinkAccent,
          lines: [
            'Desliza el dedo en la dirección a la que quieres ir.',
            'Toca la esquina superior izquierda de la pantalla para pausar o reanudar.',
          ],
        ),
        _InfoSection(
          title: 'CONSEJOS',
          color: Colors.yellowAccent,
          lines: [
            'Las mydras (puntos grandes) asustan a los fantasmas: ¡puedes comerlos por más puntos!',
            'Cuidado con el láser entre Kyros y Pyros, las paredes de Vespakron y la atracción de Shardox.',
            'Cuando pierdes una vida, la partida sigue con las rimoras que ya comiste.',
          ],
        ),
      ],
    );
  }
}

/// Datos de un personaje para la galería.
class _CharInfo {
  const _CharInfo(this.name, this.asset, this.color, [this.description]);

  /// Nombre que se muestra.
  final String name;
  /// Ruta completa de la imagen.
  final String asset;
  /// Color del borde y del nombre.
  final Color color;
  /// Descripción que se muestra bajo el nombre (opcional).
  final String? description;
}

/// Datos de galería de un fantasma, tomados de su personalidad.
_CharInfo _ghostInfo(GhostType type) {
  final p = GhostPersonality.of(type);
  return _CharInfo(
      p.displayName, 'assets/images/${p.spriteAsset}', p.color, p.description);
}

/// Galería de personajes: foto y nombre de Shardox, Vespakron, Kyros, Pyros,
/// Rimora y Mydra.
class _CharactersContent extends StatelessWidget {
  const _CharactersContent();

  @override
  Widget build(BuildContext context) {
    // Los fantasmas toman nombre, imagen, color y descripción de su
    // personalidad, así la galería siempre coincide con lo que se ve en la
    // partida. Pyros va antes que Kyros porque Kyros es "hermano de Pyros".
    final items = <_CharInfo>[
      for (final type in const [
        GhostType.shardox,
        GhostType.vespakron,
        GhostType.pyros,
        GhostType.kyros,
      ])
        _ghostInfo(type),
      const _CharInfo('Rimora', 'assets/images/rimora.png', Colors.white),
      const _CharInfo('Mydra', 'assets/images/mydra.png', _neonLime),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [for (final c in items) _CharacterCard(info: c)],
    );
  }
}

/// Tarjeta de un personaje: imagen arriba y nombre abajo.
class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.info});

  final _CharInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Las tarjetas con descripción son más anchas (caben 2 por fila).
      width: info.description != null ? 250 : 112,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      decoration: BoxDecoration(
        color: info.color.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: info.color.withAlpha(180), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Image.asset(
              info.asset,
              fit: BoxFit.contain,
              gaplessPlayback: true,
              // Si falta la imagen se muestra un cuadro del color del personaje.
              errorBuilder: (context, error, stackTrace) => DecoratedBox(
                decoration: BoxDecoration(
                  color: info.color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            info.name.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: info.color,
            ),
          ),
          if (info.description != null) ...[
            const SizedBox(height: 6),
            Text(
              info.description!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11.5, height: 1.3, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}

/// Estrellas fijas del fondo (posiciones repetibles con semilla; no parpadean).
class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(7); // Semilla fija = siempre las mismas estrellas.
    final paint = Paint();
    for (int i = 0; i < 70; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = 0.4 + rnd.nextDouble() * 1.2;
      paint.color = (i.isEven ? Colors.cyanAccent : Colors.pinkAccent)
          .withAlpha(60 + rnd.nextInt(120));
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

  /// Al abrir el menú, si todavía no hay nombre, se pide uno.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && playerName.isEmpty) _askName();
    });
  }

  /// Muestra el cuadro "Por favor escriba un nombre". La primera vez no se
  /// puede cerrar sin escribir uno; al cambiarlo después sí se puede cancelar.
  Future<void> _askName({bool canCancel = false}) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NameDialog(initial: playerName, canCancel: canCancel),
    );
    if (result != null && mounted) {
      setState(() => playerName = result);
    }
  }

  /// Libera el controlador de animación al salir de la pantalla (evita fugas
  /// de memoria).
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Construye el menú en capas (de abajo hacia arriba): fondo, estrellas,
  /// línea de neón, tira animada de personajes y contenido principal.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07051A),
      body: Stack(
        children: [
          // Fondo synthwave: degradado + estrellas fijas.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF07051A),
                    Color(0xFF2A0F5C),
                    Color(0xFF07051A)
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          const Positioned.fill(child: CustomPaint(painter: _StarsPainter())),
          // Línea de neón sobre la tira animada.
          Positioned(
            left: 0,
            right: 0,
            bottom: 52,
            height: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  Colors.transparent,
                  Colors.pinkAccent,
                  Colors.cyanAccent,
                  Colors.transparent,
                ]),
                boxShadow: [
                  BoxShadow(
                      color: Colors.pinkAccent.withAlpha(120), blurRadius: 10),
                ],
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
                            gaplessPlayback: true,
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
                      // Botones informativos: cómo se juega y galería de personajes.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _NeonButton(
                            label: '¿CÓMO SE JUEGA?',
                            s: s * 0.85,
                            filled: false,
                            color: Colors.cyanAccent,
                            onPressed: () => _showHowToPlay(context),
                          ),
                          SizedBox(width: 12 * s),
                          _NeonButton(
                            label: 'PERSONAJES',
                            s: s * 0.85,
                            filled: false,
                            color: Colors.pinkAccent,
                            onPressed: () => _showCharacters(context),
                          ),
                        ],
                      ),
                      SizedBox(height: 6 * s),
                      // Nombre actual; al tocarlo se puede cambiar.
                      if (playerName.isNotEmpty) ...[
                        GestureDetector(
                          onTap: () => _askName(canCancel: true),
                          child: Text(
                            'JUGADOR: ${playerName.toUpperCase()}   ·   TOCA PARA CAMBIAR',
                            style: TextStyle(
                              fontSize: 6.5 * s,
                              letterSpacing: 1.4,
                              color: Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(height: 3 * s),
                      ],
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
/// El jugador (`vance.png`) recorre la pantalla comiéndose las rimoras
/// (`rimora.png`) mientras Shardox, Vespakron, Kyros y Pyros lo persiguen. Cada
/// uno usa SU propio sprite (el mismo que dentro de la partida); ya no hay un
/// sprite genérico de fantasma. Si falta una imagen se dibuja una figura de
/// respaldo del color del personaje. [animation] va de 0.0 a 1.0 y se repite.
///
/// Para evitar parpadeos, al iniciar se comprueba UNA sola vez qué imágenes
/// existen, se precargan y los sprites se construyen una única vez; en cada
/// frame solo se cambia su posición.
class _SpriteChase extends StatefulWidget {
  const _SpriteChase({required this.animation});

  /// Animación de 0.0 a 1.0 que se repite; dirige todo el movimiento.
  final Animation<double> animation;

  @override
  State<_SpriteChase> createState() => _SpriteChaseState();
}

/// Estado de la tira animada: guarda los sprites ya construidos.
class _SpriteChaseState extends State<_SpriteChase> {
  /// Tamaño (px) de cada personaje.
  static const double _size = 34;
  /// Separación horizontal entre puntos (px).
  static const double _dotSpacing = 34;
  /// Distancia horizontal entre fantasmas consecutivos (px).
  static const double _ghostGap = 46;

  // Los personajes se recorren en el orden de [GhostType.values], del más
  // cercano a Pac-Man al más lejano: Shardox, Vespakron, Kyros y Pyros. Sus
  // imágenes y colores salen de [GhostPersonality].

  // Widgets construidos UNA sola vez (así Flutter no los reconstruye por frame).
  Widget? _player;
  Widget? _dot;
  List<Widget> _ghosts = const [];
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // precacheImage necesita el contexto, por eso se inicia aquí y solo una vez.
    if (!_started) {
      _started = true;
      _prepare();
    }
  }

  /// Devuelve la primera ruta que exista en los assets (o null).
  Future<String?> _firstExisting(List<String> paths) async {
    for (final p in paths) {
      try {
        await rootBundle.load(p);
        return p;
      } catch (_) {}
    }
    return null;
  }

  /// Crea un sprite estable: sin parpadeo al recargar y con respaldo fijo.
  Widget _sprite(String? path, Widget fallback, double size) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: path == null
            ? fallback
            : Image.asset(
                path,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) => fallback,
              ),
      ),
    );
  }

  /// Comprueba qué imágenes existen, las precarga y construye los widgets.
  Future<void> _prepare() async {
    final playerPath = await _firstExisting(['assets/images/vance.png']);
    final dotPath = await _firstExisting(['assets/images/rimora.png']);
    final ghostPaths = <String?>[];
    for (final type in GhostType.values) {
      final file = GhostPersonality.of(type).spriteAsset;
      ghostPaths.add(await _firstExisting(['assets/images/$file']));
    }
    if (!mounted) return;

    // Precarga: la imagen ya está lista cuando se dibuja por primera vez.
    for (final p in [playerPath, dotPath, ...ghostPaths]) {
      if (p != null) await precacheImage(AssetImage(p), context);
      if (!mounted) return;
    }

    setState(() {
      _player = _sprite(
        playerPath,
        const DecoratedBox(
          decoration: BoxDecoration(color: Colors.yellow, shape: BoxShape.circle),
        ),
        _size,
      );
      _dot = _sprite(
        dotPath,
        const DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
        8,
      );
      _ghosts = [
        for (int i = 0; i < ghostPaths.length; i++)
          _sprite(
            ghostPaths[i],
            DecoratedBox(
              decoration: BoxDecoration(
                color: GhostPersonality.of(GhostType.values[i]).color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            _size,
          ),
      ];
    });
  }

  /// Dibuja un fotograma de la animación: puntos, fantasmas y jugador.
  @override
  Widget build(BuildContext context) {
    // Hasta que todo esté listo no se dibuja nada (evita el "salto" inicial).
    if (_player == null || _dot == null || _ghosts.isEmpty) {
      return const SizedBox.shrink();
    }
    return ClipRect(
      child: LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final h = c.maxHeight;
        return AnimatedBuilder(
          animation: widget.animation,
          builder: (context, _) {
            final t = widget.animation.value;
            // El jugador entra por la izquierda (fuera de pantalla) y sale por la derecha.
            // El margen extra permite que los fantasmas también salgan completos.
            final pacX = -230 + t * (w + 460);
            // Altura que centra verticalmente a los personajes en la tira.
            final top = h / 2 - _size / 2;
            // Saltito suave para que los personajes se sientan vivos.
            double bob(double phase) => 3 * sin(t * 2 * pi * 30 + phase);

            final items = <Widget>[];

            // Puntos con clave fija: Flutter reutiliza el mismo widget y solo
            // deja de dibujar los que el jugador ya se comió.
            int n = 0;
            for (double x = _dotSpacing / 2; x < w; x += _dotSpacing, n++) {
              if (x > pacX + _size / 2) {
                items.add(Positioned(
                  key: ValueKey('dot$n'),
                  left: x - 4,
                  top: h / 2 - 4,
                  child: _dot!,
                ));
              }
            }
            // Fantasmas detrás (el más lejano primero).
            for (int i = _ghosts.length - 1; i >= 0; i--) {
              items.add(Positioned(
                key: ValueKey('ghost$i'),
                left: pacX - (i + 1) * _ghostGap,
                top: top + bob(i * 1.3),
                child: _ghosts[i],
              ));
            }
            // Jugador al frente.
            items.add(Positioned(
              key: const ValueKey('player'),
              left: pacX,
              top: top + bob(0),
              child: _player!,
            ));

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
      backgroundColor: const Color(0xFF07051A),
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
                  !gameInstance.isDying &&
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

  // ---------------------------------------------------------------------------
  // VIDAS, MUERTE Y CUENTA REGRESIVA
  // ---------------------------------------------------------------------------

  /// Vidas con las que empieza cada partida.
  static const int maxLives = 3;

  /// Segundos que parpadea Pac-Man al perder una vida.
  static const double deathBlinkSeconds = 3.0;

  /// Duración de la cuenta regresiva (3, 2, 1, 0) al empezar o reanudar.
  static const double countdownSeconds = 3.0;

  /// Vidas que le quedan al jugador.
  int lives = maxLives;

  /// `true` mientras Pac-Man parpadea tras perder una vida.
  bool isDying = false;

  /// Segundos transcurridos desde que murió (los usa el parpadeo).
  double deathElapsed = 0.0;

  /// Segundos que faltan de la cuenta regresiva (0 = no hay cuenta).
  double countdownLeft = 0.0;

  /// `true` mientras se muestra la cuenta regresiva.
  bool get isCountingDown => countdownLeft > 0;

  /// `true` cuando las entidades deben quedarse quietas: partida terminada,
  /// animación de muerte o cuenta regresiva.
  bool get isFrozen => isGameOver || isGameWon || isDying || isCountingDown;

  /// Matriz del laberinto (16 filas x 27 columnas).
  ///
  /// Leyenda:
  /// - `0`: pasillo con rimora (punto normal)
  /// - `1`: muro
  /// - `2`: casa de los fantasmas (solo transitable por fantasmas)
  /// - `3`: pasillo con mydra (punto grande / power-up)
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
  int totalRimoras = 0;

  /// Puntos que todavía quedan en el laberinto.
  int rimorasRemaining = 0;

  /// Filas que tienen salida a los extremos del mapa (túneles laterales).
  late final Set<int> tunnelRows = {
    for (int r = 0; r < mazeGrid.length; r++)
      if (mazeGrid[r].first != 1 || mazeGrid[r].last != 1) r
  };

  /// Cuántas columnas desde cada extremo cuentan como zona de túnel.
  final int tunnelDepth = 6;

  /// Nivel de Cruise Elroy de Shardox según los puntos restantes:
  /// 0 = normal, 1 = Elroy 1, 2 = Elroy 2.
  int get elroyLevel {
    // Primero se evalúa el nivel 2 (más estricto); si no se cumple, el nivel 1.
    if (rimorasRemaining <= (totalRimoras * GameSpeeds.elroy2DotsFraction).round()) {
      return 2;
    }
    if (rimorasRemaining <= (totalRimoras * GameSpeeds.elroy1DotsFraction).round()) {
      return 1;
    }
    return 0;
  }

  /// Indica si una entidad que está en [gridPos], avanzando hacia [dir] con
  /// [progress] (0.0 a 1.0), se encuentra dentro de un túnel lateral.
  ///
  /// Nota: con `GameSpeeds.tunnelFactor = 1.0` el túnel ya no modifica la
  /// velocidad; la función se conserva por si se quiere volver a ajustar.
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

  /// Se llama cuando Pac-Man come una mydra: activa el modo Frightened y
  /// asusta a TODOS los fantasmas a la vez.
  void onMydraEaten() {
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

  /// Calcula la atracción del Fantasma Imán (Shardox) sobre Pac-Man.
  void _updateMagnet() {
    magnetStrength = 0.0;
    final shardox = ghosts[GhostType.shardox];
    if (shardox == null || !shardox.isMounted || !player.isMounted) return;
    if (shardox.isDead || shardox.isLeavingSpawn || shardox.isScared) return;

    // Vector que apunta desde el jugador hacia Shardox (en casillas).
    final toShardox = tilePosOf(shardox) - tilePosOf(player);
    final dist = toShardox.length;
    // Fuera del radio de acción (o superpuestos: evita dividir entre casi cero).
    if (dist > AbilityConfig.magnetRadiusTiles || dist < 0.001) return;

    // Intensidad lineal: 0 en el borde del radio y 1 pegado a Shardox.
    magnetStrength = 1.0 - dist / AbilityConfig.magnetRadiusTiles;
    // Dirección normalizada (longitud 1). El jugador la usa para saber si avanza
    // hacia Shardox o se aleja de él.
    magnetDir = toShardox / dist;
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

  /// Color de fondo del juego (morado casi negro, a juego con el menú).
  @override
  Color backgroundColor() => const Color(0xFF07051A);

  // ---------------------------------------------------------------------------
  // ESCALADO RESPONSIVO
  // El juego se diseña en un lienzo "virtual" fijo y se escala para ajustarse
  // a cualquier pantalla, manteniendo la proporción y el centrado.
  // ---------------------------------------------------------------------------

  /// Ancho del lienzo virtual.
  static const double virtualWidth = 900.0;

  /// Alto del lienzo virtual: 24 (marcadores) + 16 * 24 (laberinto) +
  /// 24 de margen inferior.
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
    // (quedan franjas oscuras en el lado sobrante).
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
    // Los sprites de los fantasmas (normal y asustado) salen de cada
    // personalidad, así que agregar o renombrar uno se hace en un solo lugar.
    final assets = <String>[
      'vance.png',
      'rimora.png',
      'mydra.png',
      'mori.png',
      'game_over.png',
      'win.png',
      'jova_logo.png',
    ];
    for (final type in GhostType.values) {
      final personality = GhostPersonality.of(type);
      assets.add(personality.spriteAsset);
      assets.add(personality.scaredSpriteAsset);
    }
    for (final name in assets) {
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
          color: Colors.cyanAccent,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );

    highScoreText = TextComponent(
      text: 'HIGH SCORE: 0',
      position: Vector2(670, 4),
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.pinkAccent,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );

    // add() inserta el componente en el árbol del juego; desde ese momento se
    // actualiza y se dibuja automáticamente.
    add(scoreText);
    add(highScoreText);
    // Corazones de vida (columna derecha) y cuenta regresiva: viven toda la
    // sesión y consultan el estado del juego al dibujarse.
    add(LivesDisplay());
    add(CountdownOverlay());

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
    if (_ready && !isFrozen) {
      _updateMagnet();
    }

    // Animación de muerte: al cumplirse los 3 s se reinicia la ronda o termina
    // la partida.
    if (isDying) {
      deathElapsed += dt;
      if (deathElapsed >= deathBlinkSeconds) _finishDeath();
    }
    // Cuenta regresiva: mientras corre, todo está congelado.
    if (countdownLeft > 0) {
      countdownLeft = max(0.0, countdownLeft - dt);
    }

    // Actualiza a todos los componentes hijos (jugador, fantasmas, láser...).
    super.update(dt);
    if (!isFrozen) {
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
    // Partida nueva desde cero: vidas completas y cuenta regresiva.
    lives = maxLives;
    isDying = false;
    deathElapsed = 0.0;
    countdownLeft = countdownSeconds;
    modeController.reset();
    // expand() aplana la matriz en una sola lista; se cuentan los pasillos con
    // punto (0) y los power-ups (3).
    totalRimoras = mazeGrid.expand((r) => r).where((c) => c == 0 || c == 3).length;
    rimorasRemaining = totalRimoras;
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
            c is Rimora ||
            c is Wall ||
            c is TempWall ||
            c is LaserLink)
        .toList()
        .forEach((c) => c.removeFromParent());

    // Reconstruye muros y puntos a partir de mazeGrid.
    _buildGridMaze();

    // Jugador, fantasmas y láser en sus posiciones iniciales.
    _spawnEntities();
  }

  /// Crea al jugador, a los cuatro fantasmas y el láser en su posición inicial.
  void _spawnEntities() {
    // Casilla inicial del jugador: columna 13, fila 12 (parte baja, centrada).
    player = PlayerPacman(Vector2(13, 12));
    add(player);
    recordPacTile(player.gridPos);

    // Cada fantasma tiene su personalidad y sale de la base en un momento
    // distinto (releaseDelay, en segundos).
    add(Ghost(Vector2(13, 7), GhostType.shardox, releaseDelay: 0));
    add(Ghost(Vector2(14, 7), GhostType.vespakron, releaseDelay: 2));
    add(Ghost(Vector2(13, 8), GhostType.kyros, releaseDelay: 6));
    add(Ghost(Vector2(14, 8), GhostType.pyros, releaseDelay: 10));

    // Láser que une a Kyros y Pyros.
    add(LaserLink());
  }

  /// Quita al jugador, los fantasmas, el láser y las paredes temporales, y
  /// limpia sus registros. NO toca los puntos, la puntuación ni las vidas.
  void _removeEntities() {
    children
        .where((c) =>
            c is PlayerPacman ||
            c is Ghost ||
            c is TempWall ||
            c is LaserLink)
        .toList()
        .forEach((c) => c.removeFromParent());
    ghosts.clear();
    solidWalls.clear();
    tempWalls.clear();
    pacTrail.clear();
    magnetStrength = 0.0;
    _ghostCombo = 0;
    modeController.reset();
  }

  /// El jugador fue atrapado (por un fantasma o por el láser): pierde una vida
  /// y empieza la animación de parpadeo de [deathBlinkSeconds].
  void playerDied({String? cause}) {
    if (isDying || isGameOver || isGameWon || isCountingDown) return;
    lives = max(0, lives - 1);
    isDying = true;
    deathElapsed = 0.0;
    deathCause = cause;
  }

  /// Termina la animación de muerte. Sin vidas: Game Over. Con vidas: se
  /// reubican los personajes (los puntos y la puntuación se conservan) y
  /// arranca la cuenta regresiva.
  void _finishDeath() {
    isDying = false;
    if (lives <= 0) {
      triggerGameOver(cause: deathCause);
      return;
    }
    _removeEntities();
    _spawnEntities();
    countdownLeft = countdownSeconds;
  }

  /// Suma [points] a la puntuación, actualiza el récord y verifica la victoria.
  ///
  /// La partida se gana cuando ya no queda ningún [Rimora] en el laberinto.
  void addScore(int points) {
    score += points;
    scoreText.text = 'SCORE: $score';

    // El récord se actualiza en vivo; por eso "score >= highScore" al terminar
    // indica que se igualó o superó el récord.
    if (score > highScore) {
      highScore = score;
      highScoreText.text = 'HIGH SCORE: $highScore';
    }

    // rimorasRemaining lo decrementa el jugador al comer; al llegar a 0 se gana.
    if (rimorasRemaining <= 0) {
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
          add(Rimora(Vector2(col.toDouble(), row.toDouble()), isMydra: false));
        } else if (cell == 3) {
          add(Rimora(Vector2(col.toDouble(), row.toDouble()), isMydra: true));
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
    // Mientras Pac-Man parpadea no se aceptan direcciones.
    if (isDying) return KeyEventResult.handled;

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
                  colors: [Color(0xFF2A0F5C), Color(0xFF07051A)],
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
      subtitle: '¡Comiste todas las rimoras y mydras!',
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
                    colors: [Color(0xFF2A0F5C), Color(0xFF07051A)],
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
/// Usa un contorno negro para que se lea sobre los muros y el fondo.
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

  /// Última dirección en la que se movió (la usan Vespakron e Kyros para apuntar).
  /// Se conserva aunque Pac-Man esté detenido.
  Vector2 facing = Vector2(-1, 0);

  /// Avance hacia la siguiente casilla (0.0 a 1.0).
  double moveProgress = 0.0;

  /// Velocidad actual en casillas por segundo.
  ///
  /// Sube durante el modo Frightened. En los túneles se aplica
  /// [GameSpeeds.tunnelFactor], que ahora vale 1.0 (velocidad normal).
  double get speed {
    final percent = game.modeController.isFrightened
        ? GameSpeeds.pacmanFrightened
        : GameSpeeds.pacman;
    var tiles = GameSpeeds.tiles(percent);
    if (game.isInTunnel(gridPos, moveDir, moveProgress)) {
      tiles *= GameSpeeds.tunnelFactor;
    }

    // Fantasma Imán: Shardox acelera a Pac-Man si avanza hacia él y lo frena
    // si se aleja. Moverse de lado (perpendicular) no cambia la velocidad.
    if (game.magnetStrength > 0 && moveDir != Vector2.zero()) {
      final pull = moveDir.dot(game.magnetDir); // +1 hacia Shardox, -1 alejándose
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
      sprite = Sprite(game.images.fromCache('vance.png'));
    } catch (_) {}
    // El sprite mide 20 px dentro de una casilla de 24 px (2 px de margen por
    // lado, más el +4 de updatePixelPosition que lo deja casi centrado).
    size = Vector2(20, 20);
    updatePixelPosition();
  }

  /// Convierte la posición de cuadrícula a píxeles y la aplica al componente.
  void updatePixelPosition() {
    position = Vector2(
      // El +4 centra el sprite dentro de la casilla de 24 px.
      game.mazeOffsetX + gridPos.x * game.tileSize + 4,
      24 + gridPos.y * game.tileSize + 4,
    );
  }

  /// Registra la próxima dirección deseada por el jugador.
  void changeDirection(Vector2 newDir) {
    nextDir = newDir.clone();
  }

  /// Dibuja el sprite (o un círculo amarillo) y el nombre del jugador encima.
  @override
  void render(Canvas canvas) {
    // Al perder una vida parpadea (8 cambios por segundo) durante 3 s.
    if (game.isDying && (game.deathElapsed * 8).floor().isOdd) return;

    if (sprite != null) {
      sprite!.render(canvas, size: size);
    } else {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x / 2,
        Paint()..color = Colors.yellow,
      );
    }
    // Etiqueta con el nombre que escribió el jugador.
    drawEntityLabel(
      canvas,
      playerName.isEmpty ? 'JUGADOR' : playerName.toUpperCase(),
      size,
      Colors.yellow,
      fontSize: 7,
    );
  }

  /// Lógica de cada frame: decide la dirección, avanza y recoge puntos.
  @override
  void update(double dt) {
    super.update(dt);
    // Con la partida terminada, el jugador queda congelado.
    if (game.isFrozen) return;

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

    // "facing" conserva la última dirección aunque el jugador se detenga; Vespakron e
    // Kyros la usan para anticiparse.
    if (moveDir != Vector2.zero()) facing = moveDir.clone();

    // Recolección: rimora = 10 pts, mydra = 100 pts + pánico en los fantasmas.
    // toList() crea una copia: permite eliminar componentes del árbol mientras
    // se recorre la lista.
    game.children.whereType<Rimora>().toList().forEach((rimora) {
      // "eaten" evita contar dos veces la misma rimora.
      if (!rimora.eaten && rimora.gridPos == gridPos) {
        rimora.eaten = true;
        rimora.removeFromParent();
        game.rimorasRemaining--;
        game.addScore(rimora.isMydra ? 100 : 10);
        if (rimora.isMydra) {
          game.onMydraEaten(); // Asusta a todos los fantasmas a la vez
        }
      }
    });
  }
}

// -----------------------------------------------------------------------------
// RIMORA Y MYDRA: PUNTOS COLECCIONABLES
// -----------------------------------------------------------------------------

/// Coleccionable del laberinto. Hay dos tipos, cada uno con su propia imagen:
/// - **Rimora** (`rimora.png`): el punto normal. Mide [rimoraSize] y otorga 10
///   puntos.
/// - **Mydra** (`mydra.png`): el punto grande (power-up). Mide [mydraSize]
///   (casi toda la casilla, para que su imagen se distinga bien), otorga 100
///   puntos y asusta a los fantasmas. Si `mydra.png` no existe, usa `rimora.png`.
class Rimora extends PositionComponent with HasGameReference<PacManGame> {
  /// Sprite de la rimora (`rimora.png`) o de la mydra (`mydra.png`). Si es nulo se
  /// dibuja un círculo blanco.
  Sprite? sprite;

  /// Posición en coordenadas de la cuadrícula (columna, fila).
  Vector2 gridPos;

  /// Indica si es una mydra (punto grande / power-up).
  bool isMydra;

  /// Marca la rimora o mydra como ya comida (evita contarla dos veces).
  bool eaten = false;

  /// Tamaño (px) de una rimora. Se ve en una casilla de 24 px.
  static const double rimoraSize = 12.0;

  /// Tamaño (px) de una mydra. La casilla mide 24 px, así que 20 px la deja
  /// casi a ancho completo con 2 px de margen por lado. No conviene pasar de
  /// 24, porque invadiría las casillas vecinas.
  static const double mydraSize = 20.0;

  Rimora(this.gridPos, {this.isMydra = false});

  /// Carga el sprite y calcula tamaño y posición. Las mydras son más grandes.
  @override
  Future<void> onLoad() async {
    super.onLoad();
    // Cada tipo tiene su imagen. Si mydra.png no existe, la mydra usa rimora.png
    // (ya agrandada) para no quedar invisible. fromCache lanza una
    // excepción si la imagen no se cargó; se ignora y se prueba la siguiente.
    final candidates = isMydra ? ['mydra.png', 'rimora.png'] : ['rimora.png'];
    for (final name in candidates) {
      try {
        sprite = Sprite(game.images.fromCache(name));
        break;
      } catch (_) {}
    }
    size = Vector2.all(isMydra ? mydraSize : rimoraSize);
    // Se centra el punto dentro de su casilla.
    position = Vector2(
      game.mazeOffsetX + gridPos.x * game.tileSize + (game.tileSize - size.x) / 2,
      24 + gridPos.y * game.tileSize + (game.tileSize - size.y) / 2,
    );
  }

  /// Dibuja la rimora o mydra (círculo blanco si falta la imagen).
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
// LIVESDISPLAY: CORAZONES DE CRISTAL
// -----------------------------------------------------------------------------

/// Una faceta (triángulo) del corazón de cristal.
class _Facet {
  _Facet(this.a, this.b, this.c) : centroid = (a + b + c) / 3.0;

  final Offset a;
  final Offset b;
  final Offset c;

  /// Centro del triángulo: sirve para sombrearlo y para dispersarlo al romperse.
  final Offset centroid;

  /// Contorno del triángulo.
  late final Path path = Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(c.dx, c.dy)
    ..close();
}

/// Geometría de un corazón de cristal tallado: el contorno de un corazón
/// dividido en facetas triangulares que salen de un punto central, cada una
/// con su propio tono según hacia dónde "mira" (luz desde arriba a la
/// izquierda). Se calcula una sola vez y se reutiliza en los 3 corazones.
class _CrystalHeart {
  _CrystalHeart(double s) {
    const segs = 6; // Segmentos por mitad del corazón.
    final tip = Offset(0, s * 0.5); // Punta inferior.
    final dip = Offset(0, -s * 0.15); // Hendidura superior.

    // Contorno: lado izquierdo (punta -> hendidura) y derecho (hendidura ->
    // punta), muestreando dos curvas de Bézier.
    final pts = <Offset>[];
    for (int i = 0; i <= segs; i++) {
      pts.add(_cubic(tip, Offset(-s * 0.75, -s * 0.05),
          Offset(-s * 0.45, -s * 0.6), dip, i / segs));
    }
    for (int i = 1; i <= segs; i++) {
      pts.add(_cubic(dip, Offset(s * 0.45, -s * 0.6),
          Offset(s * 0.75, -s * 0.05), tip, i / segs));
    }
    // El último punto coincide con el primero (la punta), por eso se omite al
    // cerrar el polígono.
    outline = Path()..addPolygon(pts.sublist(0, pts.length - 1), true);

    final center = Offset(0, s * 0.05);
    for (int i = 0; i < pts.length - 1; i++) {
      final f = _Facet(center, pts[i], pts[i + 1]);
      facets.add(f);
      // Brillo (0 a 1): alto si la faceta mira hacia la luz (arriba-izquierda).
      final dir = f.centroid - center;
      final len = dir.distance;
      final n = len == 0 ? const Offset(0, -1) : dir / len;
      var b = 0.5 + 0.5 * (n.dx * -0.707 + n.dy * -0.707);
      b += i.isEven ? 0.07 : -0.07; // Variación para que parezca tallado.
      shade.add(b.clamp(0.0, 1.0).toDouble());
    }
  }

  /// Silueta completa del corazón (para brillo, recorte y contorno).
  late final Path outline;

  /// Facetas triangulares.
  final List<_Facet> facets = [];

  /// Brillo de cada faceta (0 = oscura, 1 = clara).
  final List<double> shade = [];

  static const Color _violet = Color(0xFF7A2CF0);
  static const Color _pink = Color(0xFFFF4DA6);
  static const Color _ice = Color(0xFFFFE6F7);

  /// Color de la faceta [i]: de violeta (sombra) a rosa y casi blanco (luz).
  Color colorOf(int i) {
    final b = shade[i];
    return b < 0.5
        ? Color.lerp(_violet, _pink, b / 0.5)!
        : Color.lerp(_pink, _ice, (b - 0.5) / 0.5)!;
  }

  /// Punto de una curva de Bézier cúbica en el instante [t] (0 a 1).
  static Offset _cubic(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final u = 1 - t;
    return p0 * (u * u * u) +
        p1 * (3 * u * u * t) +
        p2 * (3 * u * t * t) +
        p3 * (t * t * t);
  }
}

/// Muestra las vidas como corazones de cristal apilados de arriba hacia abajo
/// en la columna derecha, fuera del laberinto (x = 774 a 900 del lienzo
/// virtual).
///
/// Animaciones (todas suaves, sin parpadeos):
/// - Corazón lleno: late levemente, un destello de luz lo recorre de vez en
///   cuando y una chispa en el lóbulo izquierdo brilla y se atenúa.
/// - Vida perdida: el cristal se rompe en facetas que salen disparadas, giran
///   y se desvanecen; queda el contorno vacío.
/// - Partida nueva: los corazones reaparecen uno tras otro con rebote.
class LivesDisplay extends PositionComponent with HasGameReference<PacManGame> {
  LivesDisplay() {
    priority = 45;
  }

  /// Centro horizontal de la columna derecha (entre 774 y 900).
  static const double _cx = 837.0;
  /// Altura del centro del primer corazón.
  static const double _firstY = 62.0;
  /// Separación vertical entre corazones.
  static const double _gap = 44.0;
  /// Tamaño del corazón (px).
  static const double _heartSize = 30.0;
  /// Duración de la animación de rotura (s).
  static const double _loseSeconds = 0.9;
  /// Duración de la animación de aparición (s).
  static const double _popSeconds = 0.5;

  /// Geometría compartida del corazón de cristal.
  static final _CrystalHeart _crystal = _CrystalHeart(_heartSize);

  /// Estado anterior de cada corazón (lleno / vacío), para detectar cambios.
  final List<bool> _full = List.filled(PacManGame.maxLives, true);
  /// Segundos desde el último cambio de cada corazón (99 = sin animación).
  final List<double> _t = List.filled(PacManGame.maxLives, 99.0);
  /// Reloj general que mueve latido, destello y chispa.
  double _clock = 0.0;

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    for (int i = 0; i < _full.length; i++) {
      final full = i < game.lives; // El de más abajo se pierde primero.
      if (full != _full[i]) {
        _full[i] = full;
        _t[i] = 0.0; // Arranca la animación de rotura o de aparición.
      } else {
        _t[i] += dt;
      }
    }
  }

  /// Dibuja un corazón de cristal completo.
  ///
  /// [alpha]: opacidad (0 a 1). [sweep]: avance (0 a 1) del destello de luz, o
  /// negativo si no hay destello. [twinkle]: intensidad (0 a 1) de la chispa.
  void _drawCrystal(Canvas canvas, double scale, double alpha, double sweep,
      double twinkle) {
    final a255 = (alpha * 255).round();
    canvas.save();
    canvas.scale(scale);

    // Resplandor rosa detrás del cristal.
    canvas.drawPath(
      _crystal.outline,
      Paint()
        ..color = Colors.pinkAccent.withAlpha((a255 * 0.55).round())
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Facetas (cristal semitransparente).
    for (int i = 0; i < _crystal.facets.length; i++) {
      canvas.drawPath(
        _crystal.facets[i].path,
        Paint()..color = _crystal.colorOf(i).withAlpha((a255 * 0.85).round()),
      );
    }
    // Aristas internas.
    final edge = Paint()
      ..color = Colors.white.withAlpha((a255 * 0.28).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final f in _crystal.facets) {
      canvas.drawPath(f.path, edge);
    }
    // Borde exterior.
    canvas.drawPath(
      _crystal.outline,
      Paint()
        ..color = Colors.white.withAlpha((a255 * 0.85).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );

    // Destello de luz que cruza el cristal en diagonal.
    if (sweep >= 0 && alpha > 0.99) {
      canvas.save();
      canvas.clipPath(_crystal.outline);
      canvas.rotate(0.5);
      final x = -_heartSize * 0.9 + sweep * _heartSize * 1.8;
      canvas.drawRect(
        Rect.fromLTWH(x, -_heartSize, _heartSize * 0.22, _heartSize * 2),
        Paint()..color = Colors.white.withAlpha(110),
      );
      canvas.restore();
    }

    // Chispa (estrella de cuatro puntas) en el lóbulo izquierdo.
    final glint = Paint()
      ..color = Colors.white.withAlpha((a255 * (0.35 + 0.65 * twinkle)).round())
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final gc = Offset(-_heartSize * 0.22, -_heartSize * 0.2);
    final len = 2.5 + 3.0 * twinkle;
    canvas.drawLine(gc + Offset(-len, 0), gc + Offset(len, 0), glint);
    canvas.drawLine(gc + Offset(0, -len), gc + Offset(0, len), glint);

    canvas.restore();
  }

  /// Rotura del cristal: un destello inicial y luego cada faceta sale
  /// disparada desde el centro, gira y se desvanece. [p] va de 0 a 1.
  void _drawShatter(Canvas canvas, double p) {
    final alpha = (1 - p).clamp(0.0, 1.0).toDouble();
    final a255 = (alpha * 255).round();
    final ease = Curves.easeOut.transform(p);

    // Destello blanco del impacto (primer 12 % de la animación).
    if (p < 0.12) {
      canvas.drawPath(
        _crystal.outline,
        Paint()..color = Colors.white.withAlpha(((1 - p / 0.12) * 200).round()),
      );
    }

    for (int i = 0; i < _crystal.facets.length; i++) {
      final f = _crystal.facets[i];
      final len = f.centroid.distance;
      final unit = len == 0 ? const Offset(0, -1) : f.centroid / len;
      final offset = unit * (26 * ease);

      canvas.save();
      // Sale hacia afuera y cae un poco, como un fragmento de vidrio.
      canvas.translate(offset.dx, offset.dy + 12 * p * p);
      canvas.translate(f.centroid.dx, f.centroid.dy);
      canvas.rotate((i.isEven ? 1 : -1) * 2.2 * p);
      canvas.translate(-f.centroid.dx, -f.centroid.dy);
      canvas.drawPath(
        f.path,
        Paint()..color = _crystal.colorOf(i).withAlpha((a255 * 0.85).round()),
      );
      canvas.drawPath(
        f.path,
        Paint()
          ..color = Colors.white.withAlpha((a255 * 0.8).round())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.restore();
    }
  }

  @override
  void render(Canvas canvas) {
    TextPaint(
      style: const TextStyle(
        color: Colors.pinkAccent,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    ).render(canvas, 'VIDAS', Vector2(_cx, 30), anchor: Anchor.topCenter);

    for (int i = 0; i < _full.length; i++) {
      canvas.save();
      canvas.translate(_cx, _firstY + i * _gap);

      // Hueco vacío (siempre visible debajo).
      canvas.drawPath(
        _crystal.outline,
        Paint()
          ..color = Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round,
      );

      if (_full[i]) {
        // Aparición escalonada (0.12 s entre corazones) y luego latido suave.
        final tt = _t[i] - i * 0.12;
        if (tt >= 0) {
          final scale = tt < _popSeconds
              ? Curves.easeOutBack.transform(tt / _popSeconds)
              : 1.0 + 0.05 * sin(_clock * 4 - i * 0.8);
          // El destello recorre el cristal durante el 30 % de un ciclo de ~3 s,
          // desfasado en cada corazón.
          final phase = (_clock * 0.35 + i * 0.3) % 1.0;
          final sweep = phase < 0.3 ? phase / 0.3 : -1.0;
          final twinkle = 0.5 + 0.5 * sin(_clock * 3 + i * 1.7);
          _drawCrystal(canvas, scale, 1.0, sweep, twinkle);
        }
      } else if (_t[i] < _loseSeconds) {
        _drawShatter(canvas, _t[i] / _loseSeconds);
      }
      canvas.restore();
    }
  }
}

// -----------------------------------------------------------------------------
// COUNTDOWNOVERLAY: CUENTA REGRESIVA 3-2-1-0
// -----------------------------------------------------------------------------

/// Cuenta regresiva de [PacManGame.countdownSeconds] segundos (3, 2, 1, 0) que
/// aparece al empezar una partida o al reanudarla tras perder una vida.
///
/// Cada número entra con un rebote desde más grande, brilla con su propio
/// color, lanza un anillo que se expande y se desvanece al final. Mientras se
/// muestra, el juego permanece congelado. Solo dibuja; el tiempo lo lleva
/// [PacManGame.countdownLeft].
class CountdownOverlay extends PositionComponent
    with HasGameReference<PacManGame> {
  CountdownOverlay() {
    priority = 100; // Por encima de todo lo demás.
  }

  /// Cada número (3, 2, 1, 0) dura la cuarta parte de la cuenta.
  static const double _stepSeconds = PacManGame.countdownSeconds / 4;

  /// Color de cada paso (3, 2, 1, 0).
  static const List<Color> _colors = [
    Colors.cyanAccent,
    Colors.pinkAccent,
    Colors.yellowAccent,
    _neonLime,
  ];

  @override
  void render(Canvas canvas) {
    final left = game.countdownLeft;
    if (left <= 0) return;

    final elapsed = PacManGame.countdownSeconds - left;
    final step = min(3, (elapsed / _stepSeconds).floor()); // 0..3
    final number = 3 - step;
    // Progreso (0 a 1) dentro del número actual.
    final p = ((elapsed - step * _stepSeconds) / _stepSeconds)
        .clamp(0.0, 1.0)
        .toDouble();
    final color = _colors[step];

    final mazeW = game.maxCols * game.tileSize;
    final mazeH = game.mazeGrid.length * game.tileSize;
    final cx = game.mazeOffsetX + mazeW / 2;
    final cy = 24 + mazeH / 2;

    // Velo oscuro sobre el laberinto para que el número destaque.
    canvas.drawRect(
      Rect.fromLTWH(game.mazeOffsetX, 24, mazeW, mazeH),
      Paint()..color = Colors.black.withAlpha(120),
    );

    // Anillo de energía que se expande y se desvanece.
    canvas.drawCircle(
      Offset(cx, cy),
      40 + 130 * Curves.easeOut.transform(p),
      Paint()
        ..color = color.withAlpha(((1 - p) * 200).round())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 + 6 * (1 - p),
    );

    // Número: entra con rebote (de 2x a 1x) y se desvanece en el último 25 %.
    final enter = Curves.easeOutBack.transform((p / 0.4).clamp(0.0, 1.0));
    final scale = 2.0 - enter;
    final alpha = p < 0.75 ? 255 : ((1 - (p - 0.75) / 0.25) * 255).round();

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(scale);
    TextPaint(
      style: TextStyle(
        fontSize: 120,
        fontWeight: FontWeight.w900,
        color: color.withAlpha(alpha),
        shadows: [
          Shadow(color: color.withAlpha((alpha * 0.9).round()), blurRadius: 24),
          Shadow(color: color.withAlpha((alpha * 0.6).round()), blurRadius: 48),
        ],
      ),
    ).render(canvas, '$number', Vector2.zero(), anchor: Anchor.center);
    canvas.restore();

    // Mensaje inferior.
    TextPaint(
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w900,
        letterSpacing: 4,
        color: Colors.white.withAlpha(220),
      ),
    ).render(
      canvas,
      step < 3 ? '¡PREPÁRATE!' : '¡A JUGAR!',
      Vector2(cx, cy + 95),
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

  // --- Fantasma Imán (Shardox) ---------------------------------------------
  /// Radio de atracción, en casillas.
  static const double magnetRadiusTiles = 3.0;

  /// Variación máxima de la velocidad de Pac-Man (0.30 = +-30 %).
  static const double magnetMaxPull = 0.30;

  // --- Fantasma Constructor (Vespakron) ----------------------------------------
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

  // --- Láser Kyros-Pyros -----------------------------------------------------
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

/// Pared temporal colocada por Vespakron.
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
    if (game.isFrozen) return;

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

/// Rayo láser que une permanentemente a Kyros y Pyros.
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
    if (game.isFrozen) return;

    // El ciclo se pausa mientras los fantasmas están asustados.
    if (!game.modeController.isFrightened) {
      _t += dt;
      if (_t >= _cycle) _t -= _cycle;
    }
    _pulse += dt;

    final pac = game.player.isMounted ? _centerOf(game.player) : null;
    final kyros = game.ghosts[GhostType.kyros];
    final pyros = game.ghosts[GhostType.pyros];

    if (pac != null && _isActive && _operational(kyros) && _operational(pyros)) {
      final a = _centerOf(kyros!);
      final b = _centerOf(pyros!);

      // Caso 1: el jugador está (casi) sobre la línea en este frame.
      final onBeam =
          _distPointToSegment(pac, a, b) <= AbilityConfig.laserHitRadius;
      // Caso 2: entre el frame anterior y este, el jugador atravesó el rayo
      // (ocurre con movimientos rápidos).
      final crossed =
          _prevPac != null && _segmentsIntersect(_prevPac!, pac, a, b);

      if (onBeam || crossed) {
        game.playerDied(
            cause: 'Te alcanzó el láser de Kyros y Pyros');
      }
    }
    // Se guarda la posición actual para compararla en el siguiente frame.
    _prevPac = pac;
  }

  /// Dibuja el contador del láser y, si corresponde, el rayo o su aviso.
  @override
  void render(Canvas canvas) {
    _renderHud(canvas);

    final kyros = game.ghosts[GhostType.kyros];
    final pyros = game.ghosts[GhostType.pyros];
    if (!_operational(kyros) || !_operational(pyros)) return;

    final a = _centerOf(kyros!);
    final b = _centerOf(pyros!);

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
      text = 'LÁSER: EN PAUSA';
      color = Colors.grey;
    } else if (_isActive) {
      final left = AbilityConfig.laserActiveSeconds - _t;
      text = 'LÁSER: ACTIVO ${left.toStringAsFixed(1)}s';
      color = Colors.redAccent;
    } else if (_isWarning) {
      text = 'LÁSER: ¡CARGANDO!';
      color = Colors.orangeAccent;
    } else {
      final left = _cycle - _t;
      text = 'LÁSER: LISTO EN ${left.toStringAsFixed(0)}s';
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

  /// Shardox en Cruise Elroy 1 (igual de rápido que Pac-Man).
  static const double elroy1 = 0.80;

  /// Shardox en Cruise Elroy 2 (más rápido que Pac-Man).
  static const double elroy2 = 0.88;

  /// Multiplicador dentro de los túneles laterales. 1.0 = velocidad normal
  /// (sin cambio). Afecta igual a Pac-Man y a los fantasmas.
  static const double tunnelFactor = 1.0;

  /// Cruise Elroy 1 se activa cuando queda este porcentaje de puntos.
  static const double elroy1DotsFraction = 0.15;

  /// Cruise Elroy 2 se activa cuando queda este porcentaje de puntos.
  static const double elroy2DotsFraction = 0.07;

  /// Convierte un porcentaje de [base] a casillas por segundo.
  static double tiles(double percent) => base * percent;
}

/// Si es `true`, Shardox en Cruise Elroy ignora el modo Scatter y sigue
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
/// - [shardox]: perseguidor directo.
/// - [vespakron]: emboscador.
/// - [kyros]: estratega (flanqueo).
/// - [pyros]: tímido / errante.
enum GhostType { shardox, vespakron, kyros, pyros }

/// Si es `true`, Vespakron e Kyros replican el error de desbordamiento del
/// Pac-Man original: cuando Pac-Man mira hacia arriba, el objetivo también se
/// desplaza a la izquierda. Por defecto está desactivado.
const bool kEmulateOriginalOverflowBug = false;

/// Datos que necesita una personalidad para calcular su objetivo.
class GhostContext {
  const GhostContext({
    required this.ghostTile,
    required this.pacTile,
    required this.pacDir,
    required this.shardoxTile,
  });

  /// Casilla del fantasma que calcula.
  final Vector2 ghostTile;

  /// Casilla actual de Pac-Man.
  final Vector2 pacTile;

  /// Última dirección en la que se movió Pac-Man.
  final Vector2 pacDir;

  /// Casilla de Shardox (la usa Kyros para su vector de flanqueo).
  final Vector2 shardoxTile;
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

  /// Nombre del personaje (galería del menú y mensajes de derrota).
  String get displayName;

  /// Descripción que se muestra en la galería de personajes del menú.
  String get description;

  /// Sprite normal del fantasma (archivo dentro de assets/images/).
  String get spriteAsset;

  /// Sprite del fantasma asustado ("niga"), propio de cada personaje.
  String get scaredSpriteAsset;

  /// Esquina a la que se dirige en modo Scatter (puede estar fuera del mapa,
  /// como en el original, para que rodee la esquina).
  Vector2 get scatterTarget;

  /// Casilla objetivo en modo Chase.
  Vector2 chaseTarget(GhostContext c);

  /// Devuelve la personalidad correspondiente a [type].
  static GhostPersonality of(GhostType type) {
    switch (type) {
      case GhostType.shardox:
        return const ShardoxPersonality();
      case GhostType.vespakron:
        return const VespakronPersonality();
      case GhostType.kyros:
        return const KyrosPersonality();
      case GhostType.pyros:
        return const PyrosPersonality();
    }
  }
}

/// Shardox: su objetivo es siempre la casilla actual de Pac-Man.
class ShardoxPersonality extends GhostPersonality {
  const ShardoxPersonality();

  @override
  Color get color => Colors.red;

  @override
  String get displayName => 'Shardox';

  @override
  String get description =>
      'Él es Shardox, uno de los 4 guardianes del laberinto de cristal. '
      'Shardox siempre sabrá en todo momento dónde estás, así que no importa '
      'del lado del mapa que estés, siempre estará siguiéndote. También tiene '
      'la peculiaridad de atraerte hacia él cuando está cerca de ti. '
      '(Es un robot de cristal)';

  @override
  String get spriteAsset => 'shardox.png';

  @override
  String get scaredSpriteAsset => 'shardoxniga.png';

  @override
  Vector2 get scatterTarget => Vector2(25, -2); // Arriba a la derecha

  @override
  Vector2 chaseTarget(GhostContext c) => c.pacTile.clone();
}

/// Vespakron: apunta 4 casillas por delante de la dirección de Pac-Man.
class VespakronPersonality extends GhostPersonality {
  const VespakronPersonality();

  @override
  Color get color => Colors.pinkAccent;

  @override
  String get displayName => 'Vespakron';

  @override
  String get description =>
      'Él es Vespakron, el rey de las abejas y uno de los 4 guardianes del '
      'laberinto de cristal. Este monstruo siempre intentará emboscarte '
      'saliendo justo enfrente de tu camino durante el laberinto, y también '
      'te sellará salidas con sus paredes de cera temporales que te impedirán '
      'avanzar en ciertas zonas. (Es una abeja de cristal)';

  @override
  String get spriteAsset => 'vespakron.png';

  @override
  String get scaredSpriteAsset => 'vespakronniga.png';

  @override
  Vector2 get scatterTarget => Vector2(1, -2); // Arriba a la izquierda

  @override
  Vector2 chaseTarget(GhostContext c) => _tilesAhead(c.pacTile, c.pacDir, 4);
}

/// Kyros: usa a Pac-Man y a Shardox para formar un vector de flanqueo.
///
/// 1. Toma el punto "pivote": 2 casillas por delante de Pac-Man.
/// 2. Traza el vector desde Shardox hasta el pivote.
/// 3. Duplica ese vector: el objetivo es `pivote + (pivote - shardox)`.
class KyrosPersonality extends GhostPersonality {
  const KyrosPersonality();

  @override
  Color get color => Colors.cyanAccent;

  @override
  String get displayName => 'Kyros';

  @override
  String get description =>
      'Él es Kyros, hermano de Pyros, y cumple la misma función.';

  @override
  String get spriteAsset => 'kyros.png';

  @override
  String get scaredSpriteAsset => 'kyrosniga.png';

  @override
  Vector2 get scatterTarget => Vector2(26, 17); // Abajo a la derecha

  @override
  Vector2 chaseTarget(GhostContext c) {
    // Paso 1: punto pivote, 2 casillas por delante del jugador.
    final pivot = _tilesAhead(c.pacTile, c.pacDir, 2);
    // Pasos 2 y 3: pivote + (pivote - Shardox) = 2 x pivote - Shardox, es decir, el
    // punto simétrico de Shardox respecto al pivote.
    return pivot * 2.0 - c.shardoxTile;
  }
}

/// Pyros: persigue a Pac-Man si está a más de 8 casillas; si está a 8 o
/// menos, se retira hacia su esquina.
class PyrosPersonality extends GhostPersonality {
  const PyrosPersonality();

  @override
  Color get color => Colors.orange;

  @override
  String get displayName => 'Pyros';

  @override
  String get description =>
      'Pyros es un cristal mágico que ronda por los callejones del laberinto. '
      'La peculiaridad de Pyros es que tiene un hermano con el cual ambos '
      'pueden reflejar un láser que atraviesa paredes y daña a cualquier '
      'intruso que no sea parte del laberinto de cristal, pero no daña nada '
      'del laberinto.';

  @override
  String get spriteAsset => 'pyros.png';

  @override
  String get scaredSpriteAsset => 'pyrosniga.png';

  @override
  Vector2 get scatterTarget => Vector2(0, 17); // Abajo a la izquierda

  @override
  Vector2 chaseTarget(GhostContext c) {
    // Distancia en casillas entre Pyros y el jugador.
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
  /// - Shardox: sube con Cruise Elroy 1 y 2.
  /// - Dentro de un túnel lateral: se aplica [GameSpeeds.tunnelFactor]
  ///   (1.0 = sin cambio).
  double _currentSpeed() {
    double percent;
    if (isScared) {
      percent = GameSpeeds.ghostFrightened;
    } else if (type == GhostType.shardox) {
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
  /// Cuenta regresiva para la próxima pared (solo Vespakron la usa).
  double _builderTimer = AbilityConfig.builderFirstDelay;
  /// Último valor de reversalTick que este fantasma ya atendió.
  int _seenReversalTick = 0;
  /// `true` cuando debe dar la vuelta en cuanto sea posible.
  bool _pendingReverse = false;

  /// Generador de azar para el modo asustado.
  final Random random = Random();

  /// Sprite en estado normal.
  Sprite? ghostSprite;
  /// Sprite en estado asustado (la versión "niga" propia de este personaje).
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
    // Cada personaje usa SUS propios sprites. Si alguno falta, se dibuja un
    // cuadro de color al renderizar (no se reutiliza el sprite de otro).
    ghostSprite = _tryLoad(personality.spriteAsset);
    scaredSprite = _tryLoad(personality.scaredSpriteAsset);
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

  /// Dibuja el campo del imán (solo Shardox) y el cuerpo. Los fantasmas no
  /// muestran nombre ni número durante la partida.
  @override
  void render(Canvas canvas) {
    if (type == GhostType.shardox && game.magnetStrength > 0) {
      _renderMagnetField(canvas);
    }
    _renderBody(canvas);
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
    if (game.isFrozen) return;

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

  /// Habilidad del Fantasma Constructor (solo Vespakron): cada cierto tiempo, y
  /// solo en modo Chase, pide colocar una pared temporal detrás de Pac-Man.
  void _updateBuilder(double dt) {
    if (type != GhostType.vespakron) return;
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
        game.playerDied(cause: 'Te atrapó ${personality.displayName}');
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

    // Cruise Elroy: Shardox ignora el modo Scatter y sigue persiguiendo.
    final elroyHunting = kElroyIgnoresScatter &&
        type == GhostType.shardox &&
        game.elroyLevel > 0;

    if (game.modeController.baseMode == GhostMode.scatter && !elroyHunting) {
      return personality.scatterTarget;
    }
    return personality.chaseTarget(_buildContext());
  }

  /// Reúne los datos que necesitan las personalidades.
  GhostContext _buildContext() {
    // Valor por defecto por si Shardox aún no existe; se reemplaza al encontrarlo.
    Vector2 shardoxTile = gridPos;
    for (final g in game.children.whereType<Ghost>()) {
      if (g.type == GhostType.shardox) {
        shardoxTile = g.gridPos;
        break;
      }
    }
    return GhostContext(
      ghostTile: gridPos,
      pacTile: game.player.gridPos,
      pacDir: game.player.facing,
      shardoxTile: shardoxTile,
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

/// Muro del laberinto, dibujado como un bloque neón violeta con esquinas
/// redondeadas.
class Wall extends PositionComponent {
  Wall(Vector2 pos, Vector2 sz) {
    position = pos;
    size = sz;
  }

  /// Dibuja el muro: relleno oscuro, halo suave y borde neón nítido.
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rrect = RRect.fromRectAndRadius(
        size.toRect().deflate(1.5), const Radius.circular(6));
    // Relleno oscuro.
    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF120A3C));
    // Halo exterior suave.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF8B5CFF).withAlpha(70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    // Borde neón nítido.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFF8B5CFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }
}