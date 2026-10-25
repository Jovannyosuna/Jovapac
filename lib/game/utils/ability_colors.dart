// =============================================================================
// game/utils/ability_colors.dart
//
// Color de la barra de carga de la habilidad: verde, naranja y rojo.
// =============================================================================

import 'package:flutter/material.dart';

/// Color de la barra de carga según el avance [p] (0.0 a 1.0): verde al
/// empezar, naranja a la mitad y rojo cuando la habilidad está lista.
Color chargeColor(double p) {
  const green = Color(0xFF2ECC71);
  const orange = Color(0xFFFF9800);
  const red = Color(0xFFF44336);
  final v = p.clamp(0.0, 1.0).toDouble();
  return v < 0.5
      ? Color.lerp(green, orange, v / 0.5)!
      : Color.lerp(orange, red, (v - 0.5) / 0.5)!;
}
