// =============================================================================
// ui/dialogs/how_to_play_dialog.dart
//
// Ventana "¿Cómo se juega?" (controles de PC y móvil).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:pacman_juego/core/constants.dart';
import 'package:pacman_juego/ui/dialogs/info_dialog.dart';

/// Muestra la ventana "¿Cómo se juega?" (PC y móvil).
Future<void> showHowToPlay(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const InfoDialog(
      title: '¿CÓMO SE JUEGA?',
      accent: Colors.cyanAccent,
      child: _HowToPlayContent(),
    ),
  );
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
        InfoSection(
          title: 'OBJETIVO',
          color: neonLime,
          lines: [
            'Come todas las rimoras del laberinto sin que los fantasmas te atrapen.',
            'Tienes 3 vidas (corazones de cristal). Si pierdes las 3, la partida termina.',
          ],
        ),
        InfoSection(
          title: 'EN COMPUTADORA',
          color: Colors.cyanAccent,
          lines: [
            'Flechas del teclado: mueve a tu personaje.',
            'ESC: pausa o reanuda el juego.',
          ],
        ),
        InfoSection(
          title: 'EN CELULAR O TABLET',
          color: Colors.pinkAccent,
          lines: [
            'Desliza el dedo en la dirección a la que quieres ir.',
            'Toca la esquina superior izquierda de la pantalla para pausar o reanudar.',
          ],
        ),
        InfoSection(
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
