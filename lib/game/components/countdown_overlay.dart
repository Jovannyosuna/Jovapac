// =============================================================================
// game/components/countdown_overlay.dart
//
// Cuenta regresiva 3-2-1-0 (los números se dibujan una sola vez en imágenes).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:pacman_juego/core/constants.dart';
import 'package:pacman_juego/game/levels/level_data.dart';
import 'package:pacman_juego/game/pacman_game.dart';

/// Cuenta regresiva de [PacManGame.countdownSeconds] segundos (3, 2, 1, 0) que
/// aparece al empezar una partida o al reanudarla tras perder una vida.
///
/// Cada número entra con un rebote desde más grande, brilla con su propio
/// color, lanza un anillo que se expande y se desvanece al final. Mientras se
/// muestra, el juego permanece congelado. Solo dibuja; el tiempo lo lleva
/// [PacManGame.countdownLeft].
///
/// Optimización: el brillo de los números (sombras muy desenfocadas) es de lo
/// más caro de dibujar. Por eso cada número, con su brillo, se dibuja UNA vez
/// en una imagen al cargar, y durante la cuenta solo se estampa esa imagen
/// escalada y con transparencia.
class CountdownOverlay extends PositionComponent
    with HasGameReference<PacManGame> {
  CountdownOverlay() {
    priority = 100; // Por encima de todo lo demás.
  }

  /// Cada número (3, 2, 1, 0) dura la cuarta parte de la cuenta.
  static const double _stepSeconds = PacManGame.countdownSeconds / 4;

  /// Color de cada paso (3, 2, 1, 0).
  static const List<Color> _colors = [
    Colors.cyanAccent,
    Colors.pinkAccent,
    Colors.yellowAccent,
    neonLime,
  ];

  /// Resolución de las imágenes (2 = nítidas aun al tamaño máximo, que es 2x).
  static const double _bake = 2.0;

  /// Margen alrededor del número para que quepa el brillo.
  static const double _pad = 70.0;

  /// Números ya dibujados en imagen (clave = 3, 2, 1, 0).
  final Map<int, ui.Image> _numbers = {};

  /// Mensajes inferiores ya maquetados.
  final Map<String, TextPainter> _captions = {};

  /// Letreros de nivel ya maquetados (título, nombre y subtítulo).
  final Map<int, List<TextPainter>> _banners = {};

  List<TextPainter> _bannerFor(LevelData data) {
    return _banners.putIfAbsent(data.number, () {
      TextPainter make(String text, TextStyle style) => TextPainter(
            text: TextSpan(text: text, style: style),
            textDirection: TextDirection.ltr,
          )..layout();
      return [
        make(
          'NIVEL ${data.number}',
          TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            color: data.wallBorder,
            shadows: [Shadow(color: data.wallBorder.withAlpha(160), blurRadius: 10)],
          ),
        ),
        make(
          data.name.toUpperCase(),
          const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: Colors.white),
        ),
        make(
          data.subtitle,
          const TextStyle(
              fontSize: 12, fontStyle: FontStyle.italic, color: Colors.white70),
        ),
      ];
    });
  }

  final Paint _veil = Paint()..color = const Color(0x78000000);
  final Paint _ring = Paint()..style = PaintingStyle.stroke;
  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    for (int i = 0; i < 4; i++) {
      _bakeNumber(3 - i, _colors[i]);
    }
  }

  /// Dibuja el número [number] con su brillo en una imagen.
  void _bakeNumber(int number, Color color) {
    try {
      final tp = TextPainter(
        text: TextSpan(
          text: '$number',
          style: TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.w900,
            color: color,
            shadows: [
              Shadow(color: color.withAlpha(230), blurRadius: 24),
              Shadow(color: color.withAlpha(150), blurRadius: 48),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = tp.width + _pad * 2;
      final h = tp.height + _pad * 2;
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      c.scale(_bake);
      tp.paint(c, const Offset(_pad, _pad));
      final picture = recorder.endRecording();
      _numbers[number] =
          picture.toImageSync((w * _bake).ceil(), (h * _bake).ceil());
      picture.dispose();
      tp.dispose();
    } catch (_) {}
  }

  TextPainter _captionPainter(String text) {
    return _captions.putIfAbsent(
      text,
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
            color: Colors.white.withAlpha(220),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  @override
  void render(Canvas canvas) {
    final left = game.countdownLeft;
    if (left <= 0) return;

    final elapsed = PacManGame.countdownSeconds - left;
    final step = min(3, (elapsed / _stepSeconds).floor()); // 0..3
    final number = 3 - step;
    // Progreso (0 a 1) dentro del número actual.
    final p = ((elapsed - step * _stepSeconds) / _stepSeconds)
        .clamp(0.0, 1.0)
        .toDouble();
    final color = _colors[step];

    final mazeW = game.maxCols * game.tileSize;
    final mazeH = game.mazeGrid.length * game.tileSize;
    final cx = game.mazeOffsetX + mazeW / 2;
    final cy = 24 + mazeH / 2;

    // Velo oscuro sobre el laberinto para que el número destaque.
    canvas.drawRect(Rect.fromLTWH(game.mazeOffsetX, 24, mazeW, mazeH), _veil);

    // Anillo de energía que se expande y se desvanece.
    _ring
      ..color = color.withAlpha(((1 - p) * 200).round())
      ..strokeWidth = 1 + 6 * (1 - p);
    canvas.drawCircle(
        Offset(cx, cy), 40 + 130 * Curves.easeOut.transform(p), _ring);

    // Número: entra con rebote (de 2x a 1x) y se desvanece en el último 25 %.
    final enter = Curves.easeOut.transform((p / 0.4).clamp(0.0, 1.0));
    final bounce = Curves.easeOutBack.transform((p / 0.4).clamp(0.0, 1.0));
    final scale = 2.0 - (enter * 0.4 + bounce * 0.6);
    final alpha = p < 0.75 ? 255 : ((1 - (p - 0.75) / 0.25) * 255).round();

    final image = _numbers[number];
    if (image != null) {
      _imagePaint.color = Color.fromARGB(alpha, 255, 255, 255);
      final w = image.width.toDouble();
      final h = image.height.toDouble();
      canvas.save();
      canvas.translate(cx, cy);
      canvas.scale(scale / _bake);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, w, h),
        Rect.fromLTWH(-w / 2, -h / 2, w, h),
        _imagePaint,
      );
      canvas.restore();
    }

    // Letrero del nivel (solo al empezar un nivel, no al reaparecer).
    if (game.showLevelBanner) {
      final banner = _bannerFor(game.levelData);
      banner[0].paint(canvas, Offset(cx - banner[0].width / 2, cy - 150));
      banner[1].paint(canvas, Offset(cx - banner[1].width / 2, cy - 112));
      banner[2].paint(canvas, Offset(cx - banner[2].width / 2, cy - 92));
    }

    // Mensaje inferior.
    final caption = _captionPainter(step < 3 ? '¡PREPÁRATE!' : '¡A JUGAR!');
    caption.paint(
        canvas, Offset(cx - caption.width / 2, cy + 95 - caption.height / 2));
  }
}
