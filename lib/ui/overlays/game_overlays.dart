// =============================================================================
// ui/overlays/game_overlays.dart
//
// Menús superpuestos del juego: Game Over, Victoria y Pausa.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:pacman_juego/audio/game_audio.dart';
import 'package:pacman_juego/core/constants.dart';
import 'package:pacman_juego/game/pacman_game.dart';
import 'package:pacman_juego/ui/overlays/result_card.dart';
import 'package:pacman_juego/ui/screens/main_menu_screen.dart';
import 'package:pacman_juego/ui/widgets/maze_frame.dart';
import 'package:pacman_juego/ui/widgets/neon_button.dart';

/// Vuelve al menú principal.
void _goToMainMenu(BuildContext context) {
  GameAudio.stopMusic(); // El menú arranca su propia música.
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
    // Hay récord nuevo si en esta partida se superó el récord del perfil.
    final isRecord = game.newRecord;
    return ResultCard(
      asset: 'assets/images/game_over.png',
      fallback: 'GAME OVER',
      accent: neonOrange,
      badge: isRecord ? '¡NUEVO RÉCORD!' : null,
      stats: [
        (s) => StatChip('PUNTUACIÓN', '${game.score}', Colors.white, s),
        (s) => StatChip('RÉCORD', '${game.highScore}', neonLime, s),
      ],
      subtitle: game.deathCause,
      subtitleColor: Colors.redAccent,
      actions: [
        (s) => NeonButton(
            label: 'REINICIAR', s: s, onPressed: () => game.startGame()),
        (s) => NeonButton(
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
    final isRecord = game.newRecord;
    return ResultCard(
      asset: 'assets/images/win.png',
      fallback: '¡GANASTE!',
      accent: neonLime,
      badge: isRecord ? '¡NUEVO RÉCORD!' : null,
      stats: [
        (s) => StatChip('PUNTUACIÓN', '${game.score}', Colors.white, s),
        (s) => StatChip('RÉCORD', '${game.highScore}', neonLime, s),
      ],
      subtitle: '¡Comiste todas las rimoras y mydras!',
      actions: [
        (s) => NeonButton(
            label: 'JUGAR DE NUEVO', s: s, onPressed: () => game.startGame()),
        (s) => NeonButton(
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
                  border: Border.all(color: neonLime, width: 3 * s),
                  boxShadow: [
                    BoxShadow(
                      color: neonLime.withAlpha(100),
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
                        color: neonLime,
                      ),
                    ),
                    SizedBox(height: 3 * s),
                    Text(
                      'ESC o toca la esquina superior izquierda',
                      style: TextStyle(fontSize: 8 * s, color: Colors.white60),
                    ),
                    SizedBox(height: 14 * s),
                    NeonButton(label: 'CONTINUAR', s: s, onPressed: _resume),
                    SizedBox(height: 8 * s),
                    NeonButton(
                      label: 'REINICIAR',
                      s: s,
                      filled: false,
                      onPressed: () {
                        widget.game.startGame();
                        widget.gameFocus.requestFocus();
                      },
                    ),
                    SizedBox(height: 8 * s),
                    NeonButton(
                      label: GameAudio.enabled ? 'SONIDO: SÍ' : 'SONIDO: NO',
                      s: s,
                      filled: false,
                      color: Colors.cyanAccent,
                      onPressed: () async {
                        await GameAudio.setEnabled(!GameAudio.enabled);
                        if (mounted) setState(() {});
                      },
                    ),
                    SizedBox(height: 8 * s),
                    NeonButton(
                      label: 'MENÚ PRINCIPAL',
                      s: s,
                      filled: false,
                      color: Colors.white,
                      onPressed: () {
                        widget.game.saveProgress();
                        _goToMainMenu(context);
                      },
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
