// =============================================================================
// ui/overlays/result_card.dart
//
// Tarjeta de resultado reutilizable (Game Over / Victoria) y ficha de estadística.
// =============================================================================

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:pacman_juego/core/constants.dart';
import 'package:pacman_juego/ui/widgets/maze_frame.dart';

/// Ficha de estadística (etiqueta pequeña + valor grande).
class StatChip extends StatelessWidget {
  const StatChip(this.label, this.value, this.color, this.s);

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
  final List<StatChip Function(double s)> stats;

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
                        color: neonLime,
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
