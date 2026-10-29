// =============================================================================
// ui/screens/game_screen.dart
//
// Contenedor del juego: gestos táctiles y pausa automática.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:pacman_juego/game/components/hud_panel.dart';
import 'package:pacman_juego/game/pacman_game.dart';
import 'package:pacman_juego/ui/overlays/game_overlays.dart';

/// Contenedor del juego y gestor de los gestos táctiles.
///
/// Ocupa toda la pantalla disponible; el escalado y centrado del laberinto
/// lo resuelve [PacManGame] internamente. Convierte los deslizamientos del
/// dedo en cambios de dirección de Pac-Man.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.startLevel = 1});

  /// Nivel con el que empieza la partida (el elegido en el menú).
  final int startLevel;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

/// Estado de la pantalla de juego: crea UNA sola instancia de [PacManGame] y
/// el nodo de foco del teclado.
class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  /// Instancia única del juego, creada una sola vez para toda la pantalla.
  late final PacManGame gameInstance =
      PacManGame(startLevel: widget.startLevel);

  /// Foco del teclado del juego (se devuelve al juego al salir de la pausa).
  final FocusNode _gameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Si la app pasa a segundo plano (o cambias de pestaña), el juego se pausa
  /// solo y la música se detiene.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) gameInstance.autoPause();
  }

  /// Al salir de la pantalla de juego: guarda el récord y libera el foco. (La
  /// música se detiene en _goToMainMenu.)
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    gameInstance.saveProgress();
    _gameFocus.dispose();
    super.dispose();
  }

  /// Si el toque cae sobre el botón cryo (a la derecha), usa la habilidad.
  void _onTap(Offset position) {
    final size = gameInstance.size;
    if (size.x <= 0 || size.y <= 0) return;
    final center = HudPanel.buttonCenter(size);
    final r = HudPanel.hitRadius(size);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    if (dx * dx + dy * dy <= r * r) {
      gameInstance.useAbility();
    }
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
            // Un toque sobre el botón de hielo (columna derecha) usa la habilidad.
            onTapUp: (details) => _onTap(details.localPosition),
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
                  'LevelCompleteMenu': (context, game) =>
                      LevelCompleteOverlay(game),
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
