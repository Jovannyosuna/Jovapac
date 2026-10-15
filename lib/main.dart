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
//   - La primera vez que se abre la app se crea un PERFIL (solo un nombre de
//     máx. 12 caracteres). Cada perfil guarda su mayor puntuación y nivel
//     alcanzado. Se pueden crear VARIOS perfiles y abrir cualquiera desde el
//     botón PERFILES del menú; el último usado se carga solo. El nombre del
//     perfil activo aparece sobre Vance.
//   - Al perder una vida se muestra, sin cuadro, quién te mató y cómo.
//   - Hay música de fondo (cambia a una versión de pánico cuando los
//     fantasmas están asustados) y un efecto de sonido por cada acción.
//   - Los fantasmas asustados se rodean de un aura animada.
//   - Un choque solo cuenta cuando ya se encimó al menos 1/6 de la SILUETA
//     real del personaje (los píxeles dibujados, sin el fondo transparente del
//     PNG): Vance se come a un guardián asustado si lo cubre 1/6, y un guardián
//     atrapa a Vance si cubre 1/6 de él. Se ajusta con kEatOverlapFraction.
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
//                                       (hijos: PlayerPacman, Ghost, RimoraField, MazeWalls,
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
// ESTRUCTURA DE CARPETAS (lib/)
// -----------------------------------------------------------------------------
//   main.dart                      Arranque de la app (main) y MyApp.
//   core/constants.dart            Colores y tamaño del lienzo virtual.
//   config/game_config.dart        Velocidades, habilidades y reglas de choque.
//   data/player_profile.dart       Perfiles del jugador y su guardado.
//   audio/game_audio.dart          Música y efectos de sonido.
//   ui/widgets/                    Piezas visuales reutilizables (botón neón...).
//   ui/dialogs/                    Ventanas: nombre, cómo se juega, personajes,
//                                  perfiles.
//   ui/screens/                    Pantallas: menú principal y pantalla de juego.
//   ui/overlays/                   Menús sobre el juego: Game Over, Victoria, Pausa.
//   game/pacman_game.dart          El "director" del juego (PacManGame).
//   game/ai/                       IA de los fantasmas (modos y personalidades).
//   game/components/               Entidades: jugador, fantasma, rimoras, muros,
//                                  corazones, cuenta regresiva, láser...
//   game/utils/geometry.dart       Funciones de apoyo.
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
//   Audio (assets/audio/): music_menu.wav, music_game.wav, music_panic.wav,
//                         sfx_rimora.wav,
//                         sfx_mydra.wav, sfx_ghost_eaten.wav, sfx_death.wav,
//                         sfx_countdown.wav, sfx_go.wav, sfx_game_over.wav,
//                         sfx_win.wav, sfx_laser_warn.wav, sfx_laser_on.wav,
//                         sfx_wall.wav, sfx_click.wav, sfx_type.wav
//   Todos deben estar declarados en la sección assets de pubspec.yaml, y los
//   nombres deben coincidir exactamente (en minúsculas).
//   Los nombres de archivo de los fantasmas se definen en un solo lugar: las
//   clases ShardoxPersonality, VespakronPersonality, KyrosPersonality y
//   PyrosPersonality (propiedades spriteAsset y scaredSpriteAsset).
//   Si alguna imagen no está disponible, el juego usa figuras de respaldo
//   (círculos y cuadros de color) y continúa funcionando.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:pacman_juego/audio/game_audio.dart';
import 'package:pacman_juego/data/player_profile.dart';
import 'package:pacman_juego/ui/screens/main_menu_screen.dart';

/// Punto de entrada de la aplicación.
///
/// En dispositivos móviles fuerza la orientación horizontal y activa el modo
/// de pantalla completa inmersivo. En web y escritorio no modifica nada.
void main() async {
  // Obligatorio antes de usar servicios de la plataforma (como la orientación)
  // cuando main() es asíncrono.
  WidgetsFlutterBinding.ensureInitialized();

  // Carga el perfil guardado (si existe) y la preferencia de sonido.
  await ProfileStore.init();
  // El audio se precarga en segundo plano para no retrasar la pantalla inicial.
  unawaited(GameAudio.init());

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
      // Un toque en cualquier parte "desbloquea" el audio en los navegadores
      // (que no permiten reproducir sonido antes de la primera interacción).
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => GameAudio.unlock(),
        child: child,
      ),
      home: const MainMenuScreen(),
    );
  }
}
