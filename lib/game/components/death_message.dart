// =============================================================================
// game/components/death_message.dart
//
// Texto "quién te mató y cómo" al perder una vida (dibujado una vez por muerte).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:pacman_juego/game/components/hud_panel.dart';
import 'package:pacman_juego/game/pacman_game.dart';

/// Texto SIN cuadro que aparece en el centro del laberinto mientras Pac-Man
/// parpadea tras perder una vida: arriba quién fue y abajo cómo. Entra con un
/// fundido suave y sale antes de que empiece la cuenta regresiva. Un contorno
/// negro lo mantiene legible sobre el laberinto.
///
/// Optimización: cada texto (con su contorno y brillo) se dibuja UNA vez en una
/// imagen cuando ocurre la muerte; durante los 3 segundos solo se estampa la
/// imagen con transparencia.
class DeathMessage extends PositionComponent with HasGameReference<PacManGame> {
  DeathMessage() {
    priority = 90; // Por encima del laberinto y las entidades.
  }

  /// Resolución de las imágenes (2 = nítidas en pantallas de alta densidad).
  static const double _bake = 2.0;

  /// Margen alrededor del texto para que quepa el brillo.
  static const double _pad = 24.0;

  /// Texto de la muerte para el que están hechas las imágenes.
  String _key = '';
  ui.Image? _titleImage;
  ui.Image? _detailImage;

  final Paint _paint = Paint()..filterQuality = FilterQuality.medium;

  /// Dibuja [text] (contorno negro + relleno de color con brillo) en una imagen.
  ui.Image? _bakeText(String text, double fontSize, Color color, double maxWidth) {
    try {
      TextPainter make(TextStyle style) => TextPainter(
            text: TextSpan(text: text, style: style),
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: maxWidth);

      final outline = make(TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = fontSize * 0.18 + 1
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.black,
      ));
      final fill = make(TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        color: color,
        shadows: [Shadow(color: color.withAlpha(180), blurRadius: 16)],
      ));
      final w = fill.width + _pad * 2;
      final h = fill.height + _pad * 2;
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      c.scale(_bake);
      outline.paint(c, const Offset(_pad, _pad));
      fill.paint(c, const Offset(_pad, _pad));
      final picture = recorder.endRecording();
      final image = picture.toImageSync((w * _bake).ceil(), (h * _bake).ceil());
      picture.dispose();
      outline.dispose();
      fill.dispose();
      return image;
    } catch (_) {
      return null;
    }
  }

  void _drawImage(Canvas canvas, ui.Image? image, double x, double y) {
    if (image == null) return;
    final w = image.width / _bake;
    final h = image.height / _bake;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(x - w / 2, y - h / 2, w, h),
      _paint,
    );
  }

  @override
  void render(Canvas canvas) {
    if (!game.isDying) return;
    final size = game.size;
    if (size.x <= 0 || size.y <= 0) return;

    // Si es otra muerte, se rehacen las imágenes (y se liberan las anteriores).
    final key = '${game.deathTitle}|${game.deathDetail}';
    if (key != _key) {
      _key = key;
      _titleImage?.dispose();
      _detailImage?.dispose();
      _titleImage = _bakeText(game.deathTitle.toUpperCase(), 30, game.deathColor, 600);
      _detailImage = _bakeText(game.deathDetail, 16, Colors.white, 560);
    }

    final t = game.deathElapsed;
    final fadeIn = (t / 0.25).clamp(0.0, 1.0).toDouble();
    final fadeOut =
        ((PacManGame.deathBlinkSeconds - t) / 0.4).clamp(0.0, 1.0).toDouble();
    final alpha = (min(fadeIn, fadeOut) * 255).round();
    final rise = (1 - fadeIn) * 10; // Sube suavemente al aparecer.
    _paint.color = Color.fromARGB(alpha, 255, 255, 255);

    // Se dibuja en el centro de la pantalla (no sigue a la cámara).
    final u = HudPanel.scaleFor(size);
    game.beginScreenSpace(canvas);
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(u);
    _drawImage(canvas, _titleImage, 0, -14 + rise);
    _drawImage(canvas, _detailImage, 0, 26 + rise);
    game.endScreenSpace(canvas);
  }
}
