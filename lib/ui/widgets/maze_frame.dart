// =============================================================================
// ui/widgets/maze_frame.dart
//
// Reserva el área exacta que ocupa el laberinto en pantalla (escala del lienzo virtual).
// =============================================================================

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:pacman_juego/core/constants.dart';
import 'package:pacman_juego/game/pacman_game.dart';

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
          width: mazeVirtualW * scale,
          height: mazeVirtualH * scale,
          child: builder(context, scale),
        ),
      );
    });
  }
}
