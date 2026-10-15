// =============================================================================
// ui/widgets/neon_button.dart
//
// Botón con estilo neón (con sonido de clic).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:pacman_juego/audio/game_audio.dart';
import 'package:pacman_juego/core/constants.dart';

/// Botón con estilo neón. [filled] = relleno de color; si no, solo contorno.
class NeonButton extends StatelessWidget {
  const NeonButton({
    required this.label,
    required this.onPressed,
    required this.s,
    this.color = neonLime,
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

    // Todos los botones suenan al tocarlos.
    void handler() {
      GameAudio.sfx('sfx_click.wav');
      onPressed();
    }

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
          onPressed: handler,
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
      onPressed: handler,
      child: text,
    );
  }
}
