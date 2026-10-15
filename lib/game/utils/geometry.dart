// =============================================================================
// game/utils/geometry.dart
//
// Funciones de apoyo: clave de casilla y geometría de segmentos (láser).
// =============================================================================

import 'package:flame/components.dart';


/// Clave única de una casilla: `fila * 100 + columna`.
int tileKey(int col, int row) => row * 100 + col;

/// Producto cruzado 2D de (a - o) x (b - o). Su signo indica de qué lado de
/// la recta o->a queda el punto b; es la base de la prueba de intersección.
double _cross(Vector2 o, Vector2 a, Vector2 b) =>
    (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x);

/// Distancia de un punto [p] al segmento [a]-[b].
double distPointToSegment(Vector2 p, Vector2 a, Vector2 b) {
  final ab = b - a;
  final len2 = ab.length2;
  // Segmento degenerado (a == b): la distancia es simplemente a ese punto.
  if (len2 == 0) return p.distanceTo(a);
  // Proyección de p sobre la recta, limitada a [0, 1] para quedarse dentro del
  // segmento: t = 0 es el extremo a y t = 1 el extremo b.
  final t = ((p - a).dot(ab) / len2).clamp(0.0, 1.0).toDouble();
  return p.distanceTo(a + ab * t);
}

/// Indica si los segmentos [p1]-[p2] y [q1]-[q2] se cruzan.
bool segmentsIntersect(Vector2 p1, Vector2 p2, Vector2 q1, Vector2 q2) {
  // Dos segmentos se cruzan si los extremos de cada uno quedan en lados
  // opuestos del otro (signos distintos -> producto negativo).
  final d1 = _cross(q1, q2, p1);
  final d2 = _cross(q1, q2, p2);
  final d3 = _cross(p1, p2, q1);
  final d4 = _cross(p1, p2, q2);
  return (d1 * d2 < 0) && (d3 * d4 < 0);
}

/// Centro en píxeles de un componente (su `position` es la esquina superior
/// izquierda).
Vector2 centerOf(PositionComponent c) =>
    Vector2(c.position.x + c.size.x / 2, c.position.y + c.size.y / 2);
