// =============================================================================
// game/components/entity_label.dart
//
// Etiqueta de texto sobre una entidad (nombre del jugador), maquetada una sola vez.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';


/// Etiquetas ya maquetadas (contorno + relleno), para no calcular el texto en
/// cada frame. La clave es texto + tamaño + color.
final Map<String, List<TextPainter>> _labelCache = {};

/// Dibuja una etiqueta de texto centrada justo encima de una entidad.
///
/// Usa un contorno negro para que se lea sobre los muros y el fondo. Debe
/// llamarse dentro de `render`, con el origen en la esquina superior izquierda
/// de la entidad. El texto se maqueta una sola vez y se reutiliza.
void drawEntityLabel(
  Canvas canvas,
  String text,
  Vector2 entitySize,
  Color color, {
  double fontSize = 8,
}) {
  final painters = _labelCache.putIfAbsent('$text|$fontSize|${color.hashCode}', () {
    TextPainter make(TextStyle style) => TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
        )..layout();
    return [
      // 1) Contorno negro (trazo).
      make(TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.black,
      )),
      // 2) Relleno de color encima.
      make(TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: color,
      )),
    ];
  });
  // Centrada en horizontal y 1 px por encima del borde superior.
  for (final tp in painters) {
    tp.paint(canvas, Offset(entitySize.x / 2 - tp.width / 2, -1 - tp.height));
  }
}
