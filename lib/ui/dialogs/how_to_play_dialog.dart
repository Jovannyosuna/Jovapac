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
            'En el nivel 5, al comer todo, la puerta de la casa de los guardianes se abre y aparece un corazón de cristal: tómalo para ganar.',
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
          title: 'HABILIDAD CRYO',
          color: Colors.lightBlueAccent,
          lines: [
            'Cada 2000 puntos que ganes se carga tu habilidad. La barrita bajo Vance va de verde a naranja y se pone roja cuando está lista.',
            'Úsala con la barra espaciadora (PC) o tocando el botón cryo a la derecha (celular). Los guardianes se congelan unos segundos: no se mueven ni te dañan.',
            'Al usarla no pierdes puntos; la barra se vacía y vuelves a cargarla desde cero.',
          ],
        ),
        InfoSection(
          title: 'PUNTOS',
          color: neonLime,
          lines: [
            'Rimora: 100 puntos. Mydra: 500. Guardián asustado: 750.',
          ],
        ),
        InfoSection(
          title: 'NIVELES',
          color: Colors.orangeAccent,
          lines: [
            'Hay 5 niveles. Cada uno tiene su propio mapa y es más difícil que el anterior.',
            'Nivel 2: portales que te cruzan de un lado a otro. Nivel 3: compuertas de energía que se abren y se cierran. Nivel 4: niebla, solo ves lo que tienes cerca. Nivel 5: todo junto.',
            'Al completar un nivel se desbloquea el siguiente en tu perfil.',
          ],
        ),
        InfoSection(
          title: 'CONSEJOS',
          color: Colors.yellowAccent,
          lines: [
            'Las mydras (puntos grandes) asustan a los fantasmas: ¡puedes comerlos por más puntos!',
            'Cuidado con el láser entre Kyros y Pyros, las paredes de cera de abeja de Vespakron y la atracción de Shardox.',
            'Cuando pierdes una vida, la partida sigue con las rimoras que ya comiste.',
          ],
        ),
      ],
    );
  }
}
