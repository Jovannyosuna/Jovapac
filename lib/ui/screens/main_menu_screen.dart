// =============================================================================
// ui/screens/main_menu_screen.dart
//
// Pantalla de inicio: logotipo animado, botones y tira de personajes.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:pacman_juego/audio/game_audio.dart';
import 'package:pacman_juego/core/constants.dart';
import 'package:pacman_juego/data/player_profile.dart';
import 'package:pacman_juego/game/ai/ghost_personality.dart';
import 'package:pacman_juego/game/pacman_game.dart';
import 'package:pacman_juego/ui/dialogs/characters_dialog.dart';
import 'package:pacman_juego/ui/dialogs/how_to_play_dialog.dart';
import 'package:pacman_juego/ui/dialogs/name_dialog.dart';
import 'package:pacman_juego/ui/dialogs/profiles_dialog.dart';
import 'package:pacman_juego/ui/screens/game_screen.dart';
import 'package:pacman_juego/ui/widgets/neon_button.dart';

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
    // Música del menú (en navegadores empieza con el primer toque).
    GameAudio.playMusic('music_menu.wav');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && currentProfile == null) _askName();
    });
  }

  /// Muestra el cuadro para crear un perfil. La primera vez no se puede cerrar
  /// sin crear uno; después se puede cancelar. Un nombre nuevo crea un perfil
  /// con todo en 0; si el nombre ya existe, se abre ese perfil con sus datos.
  Future<void> _askName({bool canCancel = false}) async {
    final hasProfile = currentProfile != null;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => NameDialog(
        initial: '',
        canCancel: canCancel,
        title: hasProfile ? 'NUEVO PERFIL' : 'CREAR PERFIL',
        subtitle: hasProfile
            ? 'Escribe el nombre del nuevo perfil (empieza con puntuación y nivel en 0). Si ya existe uno con ese nombre, se abrirá ese perfil.'
            : 'Escribe tu nombre (máximo 12 letras). En tu perfil se guardarán tu mejor puntuación y tu nivel.',
        confirmLabel: 'CREAR',
      ),
    );
    if (result == null || !mounted) return;
    await ProfileStore.createProfile(result);
    if (mounted) setState(() {});
  }

  /// Abre la ventana de perfiles. Si se pidió un perfil nuevo (o ya no queda
  /// ninguno), abre el cuadro para crearlo.
  Future<void> _openProfiles() async {
    final wantsNew = await showDialog<bool>(
      context: context,
      builder: (_) => const ProfilesDialog(),
    );
    if (!mounted) return;
    setState(() {});
    if (currentProfile == null) {
      _askName();
    } else if (wantsNew == true) {
      _askName(canCancel: true);
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
                  width: mazeVirtualW * s,
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
                                    color: neonLime,
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
                        child: NeonButton(
                          label: 'INICIAR JUEGO',
                          s: s * 1.15,
                          onPressed: () {
                            GameAudio.stopMusic(); // Termina la música del menú.
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const GameScreen()),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 8 * s),
                      // Botones: cómo se juega, galería de personajes y perfiles.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          NeonButton(
                            label: '¿CÓMO SE JUEGA?',
                            s: s * 0.85,
                            filled: false,
                            color: Colors.cyanAccent,
                            onPressed: () => showHowToPlay(context),
                          ),
                          SizedBox(width: 12 * s),
                          NeonButton(
                            label: 'PERSONAJES',
                            s: s * 0.85,
                            filled: false,
                            color: Colors.pinkAccent,
                            onPressed: () => showCharacters(context),
                          ),
                          SizedBox(width: 12 * s),
                          NeonButton(
                            label: 'PERFILES',
                            s: s * 0.85,
                            filled: false,
                            color: neonLime,
                            onPressed: _openProfiles,
                          ),
                        ],
                      ),
                      SizedBox(height: 6 * s),
                      // Perfil actual; al tocarlo se puede crear otro.
                      if (playerName.isNotEmpty) ...[
                        GestureDetector(
                          onTap: _openProfiles,
                          child: Text(
                            'JUGADOR: ${playerName.toUpperCase()}   ·   RÉCORD: ${currentProfile?.highScore ?? 0}   ·   NIVEL: ${currentProfile?.level ?? 1}   ·   TOCA PARA CAMBIAR',
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
                cacheWidth: 128, // Decodifica pequeño: ahorra memoria.
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
