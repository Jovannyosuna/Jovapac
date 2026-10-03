import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Shared night-sky background with a soft vignette and faint CRT lines.
/// Static, so it is cached in its own layer.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child, this.animated = false});

  final Widget child;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(child: CustomPaint(painter: _SkyPainter())),
        if (animated) const RepaintBoundary(child: _FloatingPellets()),
        child,
        const IgnorePointer(
          child: RepaintBoundary(child: CustomPaint(painter: _ScanlinePainter())),
        ),
      ],
    );
  }
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.35),
          radius: 1.1,
          colors: [Color(0xFF1A1236), Palette.deep, Palette.night],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.9, 1.1),
          radius: 0.9,
          colors: [Palette.orange.withValues(alpha: 0.07), Colors.transparent],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) => false;
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x08000000);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter oldDelegate) => false;
}

class _FloatingPellets extends StatefulWidget {
  const _FloatingPellets();

  @override
  State<_FloatingPellets> createState() => _FloatingPelletsState();
}

class _FloatingPelletsState extends State<_FloatingPellets>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PelletFieldPainter(_clock));
}

class _PelletFieldPainter extends CustomPainter {
  _PelletFieldPainter(this.clock) : super(repaint: clock);

  final Animation<double> clock;
  static final List<(double, double, double, double)> _seeds = () {
    final random = Random(5);
    return List.generate(
      34,
      (_) => (
        random.nextDouble(),
        random.nextDouble(),
        0.4 + random.nextDouble(),
        random.nextDouble() * pi * 2,
      ),
    );
  }();
  final Paint _paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * 40;
    for (final (x, y, speed, phase) in _seeds) {
      final py = (y - t * 0.012 * speed) % 1.0;
      final px = x + sin(t * 0.2 + phase) * 0.01;
      final twinkle = 0.5 + 0.5 * sin(t * 1.3 + phase);
      _paint.color = (speed > 1.1 ? Palette.orange : Palette.lime)
          .withValues(alpha: 0.06 + 0.12 * twinkle);
      canvas.drawCircle(
          Offset(px * size.width, py * size.height), 1.5 + speed * 1.5, _paint);
    }
  }

  @override
  bool shouldRepaint(_PelletFieldPainter oldDelegate) => false;
}
