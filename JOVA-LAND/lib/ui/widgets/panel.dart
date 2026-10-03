import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Frosted dark card used by every modal state.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.accent = Palette.lime,
    this.padding = const EdgeInsets.fromLTRB(32, 28, 32, 28),
    this.maxWidth = 440,
  });

  final Widget child;
  final Color accent;
  final EdgeInsets padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(Palette.panel, accent, 0.06)!.withValues(alpha: 0.94),
                  Palette.deep.withValues(alpha: 0.94),
                ],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Dimmed full-area scrim that fades in behind modal panels.
class Scrim extends StatelessWidget {
  const Scrim({super.key, required this.child, this.opacity = 0.72});

  final Widget child;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.night.withValues(alpha: opacity),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Fade + rise entrance shared by panels and banners.
class EnterTransition extends StatelessWidget {
  const EnterTransition({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 18,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final total = const Duration(milliseconds: 420) + delay;
    final start = delay.inMilliseconds / total.inMilliseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, offset * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
