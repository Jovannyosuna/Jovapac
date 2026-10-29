// =============================================================================
// game/components/lives_display.dart
//
// Corazones de cristal de las vidas (y su animación de rotura).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:pacman_juego/game/components/hud_panel.dart';
import 'package:pacman_juego/game/pacman_game.dart';

/// Una faceta (triángulo) del corazón de cristal.
class _Facet {
  _Facet(this.a, this.b, this.c) : centroid = (a + b + c) / 3.0;

  final Offset a;
  final Offset b;
  final Offset c;

  /// Centro del triángulo: sirve para sombrearlo y para dispersarlo al romperse.
  final Offset centroid;

  /// Contorno del triángulo.
  late final Path path = Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(c.dx, c.dy)
    ..close();
}

/// Geometría de un corazón de cristal tallado: el contorno de un corazón
/// dividido en facetas triangulares que salen de un punto central, cada una
/// con su propio tono según hacia dónde "mira" (luz desde arriba a la
/// izquierda). Se calcula una sola vez y se reutiliza en los 3 corazones.
class _CrystalHeart {
  _CrystalHeart(double s) {
    const segs = 6; // Segmentos por mitad del corazón.
    final tip = Offset(0, s * 0.5); // Punta inferior.
    final dip = Offset(0, -s * 0.15); // Hendidura superior.

    // Contorno: lado izquierdo (punta -> hendidura) y derecho (hendidura ->
    // punta), muestreando dos curvas de Bézier.
    final pts = <Offset>[];
    for (int i = 0; i <= segs; i++) {
      pts.add(_cubic(tip, Offset(-s * 0.75, -s * 0.05),
          Offset(-s * 0.45, -s * 0.6), dip, i / segs));
    }
    for (int i = 1; i <= segs; i++) {
      pts.add(_cubic(dip, Offset(s * 0.45, -s * 0.6),
          Offset(s * 0.75, -s * 0.05), tip, i / segs));
    }
    // El último punto coincide con el primero (la punta), por eso se omite al
    // cerrar el polígono.
    outline = Path()..addPolygon(pts.sublist(0, pts.length - 1), true);

    final center = Offset(0, s * 0.05);
    for (int i = 0; i < pts.length - 1; i++) {
      final f = _Facet(center, pts[i], pts[i + 1]);
      facets.add(f);
      // Brillo (0 a 1): alto si la faceta mira hacia la luz (arriba-izquierda).
      final dir = f.centroid - center;
      final len = dir.distance;
      final n = len == 0 ? const Offset(0, -1) : dir / len;
      var b = 0.5 + 0.5 * (n.dx * -0.707 + n.dy * -0.707);
      b += i.isEven ? 0.07 : -0.07; // Variación para que parezca tallado.
      shade.add(b.clamp(0.0, 1.0).toDouble());
    }
  }

  /// Silueta completa del corazón (para brillo, recorte y contorno).
  late final Path outline;

  /// Facetas triangulares.
  final List<_Facet> facets = [];

  /// Brillo de cada faceta (0 = oscura, 1 = clara).
  final List<double> shade = [];

  /// Color de cada faceta, calculado una sola vez.
  late final List<Color> colors = [
    for (int i = 0; i < facets.length; i++) colorOf(i)
  ];

  static const Color _violet = Color(0xFF7A2CF0);
  static const Color _pink = Color(0xFFFF4DA6);
  static const Color _ice = Color(0xFFFFE6F7);

  /// Color de la faceta [i]: de violeta (sombra) a rosa y casi blanco (luz).
  Color colorOf(int i) {
    final b = shade[i];
    return b < 0.5
        ? Color.lerp(_violet, _pink, b / 0.5)!
        : Color.lerp(_pink, _ice, (b - 0.5) / 0.5)!;
  }

  /// Punto de una curva de Bézier cúbica en el instante [t] (0 a 1).
  static Offset _cubic(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final u = 1 - t;
    return p0 * (u * u * u) +
        p1 * (3 * u * u * t) +
        p2 * (3 * u * t * t) +
        p3 * (t * t * t);
  }
}

/// Muestra las vidas como corazones de cristal apilados de arriba hacia abajo
/// en la columna derecha, fuera del laberinto (x = 774 a 900 del lienzo
/// virtual).
///
/// Optimización: el corazón (facetas, aristas, borde y resplandor) se dibuja
/// UNA vez en una imagen; en cada frame solo se estampa esa imagen (con su
/// latido) y, de vez en cuando, el destello y la chispa. Los pinceles se
/// reutilizan para no crear objetos en cada frame.
///
/// Animaciones (todas suaves, sin parpadeos):
/// - Corazón lleno: late levemente, un destello de luz lo recorre de vez en
///   cuando y una chispa en el lóbulo izquierdo brilla y se atenúa.
/// - Vida perdida: el cristal se rompe en facetas que salen disparadas, giran
///   y se desvanecen; queda el contorno vacío.
/// - Partida nueva: los corazones reaparecen uno tras otro con rebote.
class LivesDisplay extends PositionComponent with HasGameReference<PacManGame> {
  LivesDisplay() {
    priority = 145;
  }

  /// Tamaño del corazón (px).
  static const double _heartSize = 30.0;
  /// Duración de la animación de rotura (s).
  static const double _loseSeconds = 0.9;
  /// Duración de la animación de aparición (s).
  static const double _popSeconds = 0.5;

  /// Geometría compartida del corazón de cristal.
  static final _CrystalHeart _crystal = _CrystalHeart(_heartSize);

  // --- Imagen "horneada" del corazón ----------------------------------------
  /// Resolución de la imagen respecto al lienzo virtual.
  static const double _bakeScale = 3.0;
  /// Mitad del lado (en unidades virtuales) del área horneada, con margen para
  /// el resplandor.
  static const double _bakeHalf = 24.0;
  static ui.Image? _baked;
  static bool _bakeTried = false;
  static final Rect _bakedSrc = Rect.fromLTWH(
      0, 0, _bakeHalf * 2 * _bakeScale, _bakeHalf * 2 * _bakeScale);
  static final Rect _bakedDst =
      Rect.fromLTWH(-_bakeHalf, -_bakeHalf, _bakeHalf * 2, _bakeHalf * 2);

  // --- Pinceles reutilizables ----------------------------------------------
  static final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;
  static final Paint _slotPaint = Paint()
    ..color = Colors.white24
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..strokeJoin = StrokeJoin.round;
  static final Paint _fillPaint = Paint();
  static final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _flashPaint = Paint();
  static final Paint _sweepPaint = Paint()..color = const Color(0x6EFFFFFF);
  static final Paint _glintPaint = Paint()
    ..strokeWidth = 1.2
    ..strokeCap = StrokeCap.round;

  /// Estado anterior de cada corazón (lleno / vacío), para detectar cambios.
  final List<bool> _full = List.filled(PacManGame.maxLives, true);
  /// Segundos desde el último cambio de cada corazón (99 = sin animación).
  final List<double> _t = List.filled(PacManGame.maxLives, 99.0);
  /// Reloj general que mueve latido, destello y chispa.
  double _clock = 0.0;

  @override
  void update(double dt) {
    super.update(dt);
    _clock += dt;
    for (int i = 0; i < _full.length; i++) {
      final full = i < game.lives; // El de más abajo se pierde primero.
      if (full != _full[i]) {
        _full[i] = full;
        _t[i] = 0.0; // Arranca la animación de rotura o de aparición.
      } else {
        _t[i] += dt;
      }
    }
  }

  /// Dibuja el corazón completo (resplandor, facetas, aristas y borde). Solo se
  /// usa para hornear la imagen (con [blur]) o como respaldo (sin [blur]).
  static void _paintCrystal(Canvas canvas, {required bool blur}) {
    final glow1 = Paint()
      ..color = Colors.pinkAccent.withAlpha(40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeJoin = StrokeJoin.round;
    final glow2 = Paint()
      ..color = Colors.pinkAccent.withAlpha(77)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeJoin = StrokeJoin.round;
    if (blur) {
      glow1.maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      glow2.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    }
    canvas.drawPath(_crystal.outline, glow1);
    canvas.drawPath(_crystal.outline, glow2);

    final fill = Paint();
    for (int i = 0; i < _crystal.facets.length; i++) {
      fill.color = _crystal.colors[i].withAlpha(217);
      canvas.drawPath(_crystal.facets[i].path, fill);
    }
    final edge = Paint()
      ..color = Colors.white.withAlpha(71)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final f in _crystal.facets) {
      canvas.drawPath(f.path, edge);
    }
    canvas.drawPath(
      _crystal.outline,
      Paint()
        ..color = Colors.white.withAlpha(217)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Dibuja el corazón una vez en una imagen (con el resplandor desenfocado).
  static void _bake() {
    _bakeTried = true;
    try {
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      c.scale(_bakeScale);
      c.translate(_bakeHalf, _bakeHalf);
      _paintCrystal(c, blur: true);
      final picture = recorder.endRecording();
      final side = (_bakeHalf * 2 * _bakeScale).round();
      _baked = picture.toImageSync(side, side);
      picture.dispose();
    } catch (_) {
      _baked = null; // Se usará el dibujo directo (sin desenfoque).
    }
  }

  /// Estampa un corazón de cristal. [a255]: opacidad (0 a 255). [sweep]: avance
  /// (0 a 1) del destello, o negativo si no hay. [twinkle]: brillo (0 a 1) de la
  /// chispa.
  void _drawCrystal(
      Canvas canvas, double scale, int a255, double sweep, double twinkle) {
    if (!_bakeTried) _bake();
    canvas.save();
    canvas.scale(scale);

    final baked = _baked;
    if (baked != null) {
      _imagePaint.color = Color.fromARGB(a255, 255, 255, 255);
      canvas.drawImageRect(baked, _bakedSrc, _bakedDst, _imagePaint);
    } else {
      _paintCrystal(canvas, blur: false);
    }

    // Destello de luz que cruza el cristal en diagonal (solo mientras pasa).
    if (sweep >= 0) {
      canvas.save();
      canvas.clipPath(_crystal.outline);
      canvas.rotate(0.5);
      final x = -_heartSize * 0.9 + sweep * _heartSize * 1.8;
      canvas.drawRect(
        Rect.fromLTWH(x, -_heartSize, _heartSize * 0.22, _heartSize * 2),
        _sweepPaint,
      );
      canvas.restore();
    }

    // Chispa (estrella de cuatro puntas) en el lóbulo izquierdo.
    _glintPaint.color =
        Colors.white.withAlpha((a255 * (0.35 + 0.65 * twinkle)).round());
    const gx = -_heartSize * 0.22;
    const gy = -_heartSize * 0.2;
    final len = 2.5 + 3.0 * twinkle;
    canvas.drawLine(Offset(gx - len, gy), Offset(gx + len, gy), _glintPaint);
    canvas.drawLine(Offset(gx, gy - len), Offset(gx, gy + len), _glintPaint);

    canvas.restore();
  }

  /// Rotura del cristal: un destello inicial y luego cada faceta sale
  /// disparada desde el centro, gira y se desvanece. [p] va de 0 a 1.
  void _drawShatter(Canvas canvas, double p) {
    final a255 = ((1 - p).clamp(0.0, 1.0) * 255).round();
    final ease = Curves.easeOut.transform(p);

    // Destello blanco del impacto (primer 12 % de la animación).
    if (p < 0.12) {
      _flashPaint.color = Colors.white.withAlpha(((1 - p / 0.12) * 200).round());
      canvas.drawPath(_crystal.outline, _flashPaint);
    }

    for (int i = 0; i < _crystal.facets.length; i++) {
      final f = _crystal.facets[i];
      final len = f.centroid.distance;
      final ux = len == 0 ? 0.0 : f.centroid.dx / len;
      final uy = len == 0 ? -1.0 : f.centroid.dy / len;

      canvas.save();
      // Sale hacia afuera y cae un poco, como un fragmento de vidrio.
      canvas.translate(ux * 26 * ease, uy * 26 * ease + 12 * p * p);
      canvas.translate(f.centroid.dx, f.centroid.dy);
      canvas.rotate((i.isEven ? 1 : -1) * 2.2 * p);
      canvas.translate(-f.centroid.dx, -f.centroid.dy);
      _fillPaint.color = _crystal.colors[i].withAlpha((a255 * 0.85).round());
      canvas.drawPath(f.path, _fillPaint);
      _strokePaint
        ..color = Colors.white.withAlpha((a255 * 0.8).round())
        ..strokeWidth = 1;
      canvas.drawPath(f.path, _strokePaint);
      canvas.restore();
    }
  }

  /// Dibuja un corazón de cristal (el mismo de las vidas) centrado en (0, 0) con
  /// la [scale] indicada y opacidad [a255] (0 a 255). Lo usa también el corazón
  /// final del nivel 5.
  static void drawBakedHeart(Canvas canvas, double scale, int a255) {
    if (!_bakeTried) _bake();
    canvas.save();
    canvas.scale(scale);
    final baked = _baked;
    if (baked != null) {
      _imagePaint.color = Color.fromARGB(a255, 255, 255, 255);
      canvas.drawImageRect(baked, _bakedSrc, _bakedDst, _imagePaint);
    } else {
      _paintCrystal(canvas, blur: false);
    }
    canvas.restore();
  }

  /// Dibuja los corazones en la esquina derecha de la PANTALLA (más pequeños y
  /// sin letrero), uno bajo otro.
  @override
  void render(Canvas canvas) {
    final size = game.size;
    if (size.x <= 0 || size.y <= 0) return;
    final u = HudPanel.scaleFor(size);
    game.beginScreenSpace(canvas);

    for (int i = 0; i < _full.length; i++) {
      canvas.save();
      canvas.translate(size.x - 18 * u, size.y * 0.165 + i * size.y * 0.082);
      canvas.scale(0.85 * u);

      // Hueco vacío (siempre visible debajo).
      canvas.drawPath(_crystal.outline, _slotPaint);

      if (_full[i]) {
        // Aparición escalonada (0.12 s entre corazones) y luego latido suave.
        final tt = _t[i] - i * 0.12;
        if (tt >= 0) {
          final scale = tt < _popSeconds
              ? Curves.easeOutBack.transform(tt / _popSeconds)
              : 1.0 + 0.05 * sin(_clock * 4 - i * 0.8);
          // El destello recorre el cristal durante el 30 % de un ciclo de ~3 s,
          // desfasado en cada corazón.
          final phase = (_clock * 0.35 + i * 0.3) % 1.0;
          final sweep = phase < 0.3 ? phase / 0.3 : -1.0;
          final twinkle = 0.5 + 0.5 * sin(_clock * 3 + i * 1.7);
          _drawCrystal(canvas, scale, 255, sweep, twinkle);
        }
      } else if (_t[i] < _loseSeconds) {
        _drawShatter(canvas, _t[i] / _loseSeconds);
      }
      canvas.restore();
    }
    game.endScreenSpace(canvas);
  }
}
