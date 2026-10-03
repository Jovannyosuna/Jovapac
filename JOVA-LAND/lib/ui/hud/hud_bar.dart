import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../game/game_session.dart';
import '../widgets/arcade_button.dart';

/// Compact top bar: score and record on the edges, level and pellet progress
/// in the middle, lives and actions on the right.
class HudBar extends StatelessWidget {
  const HudBar({
    super.key,
    required this.session,
    required this.muted,
    required this.onPause,
    required this.onToggleMute,
  });

  final GameSession session;
  final ValueListenable<bool> muted;
  final VoidCallback onPause;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 480;
      final compact = constraints.maxWidth < 620;
      final valueSize = compact ? 13.0 : 17.0;

      final score = ValueListenableBuilder<int>(
        valueListenable: session.score,
        builder: (_, score, _) =>
            _Stat(label: 'PUNTOS', value: score, valueSize: valueSize),
      );
      final record = ValueListenableBuilder<int>(
        valueListenable: session.highScore,
        builder: (_, high, _) => _Stat(
          label: session.isNewHighScore && high > 0 ? '¡RÉCORD!' : 'RÉCORD',
          value: high,
          valueSize: valueSize,
          color: Palette.lime,
          alignEnd: true,
        ),
      );
      final lives = ValueListenableBuilder<int>(
        valueListenable: session.lives,
        builder: (_, lives, _) => _Lives(lives: lives, compact: compact),
      );
      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: muted,
            builder: (_, isMuted, _) => HudIconButton(
              icon: isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              tooltip: isMuted ? 'Activar sonido (M)' : 'Silenciar (M)',
              onPressed: onToggleMute,
            ),
          ),
          const SizedBox(width: 8),
          HudIconButton(
            icon: Icons.pause_rounded,
            tooltip: 'Pausa (Esc)',
            onPressed: onPause,
          ),
        ],
      );

      final stats = Row(
        children: [
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: score),
          ),
          _LevelProgress(session: session, compact: compact),
          Expanded(
            child: narrow
                ? Align(alignment: Alignment.centerRight, child: record)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(child: record),
                      SizedBox(width: compact ? 10 : 18),
                      lives,
                      SizedBox(width: compact ? 8 : 14),
                      actions,
                    ],
                  ),
          ),
        ],
      );

      return Container(
        padding: EdgeInsets.fromLTRB(
            compact ? 12 : 20, narrow ? 6 : 0, compact ? 12 : 20, narrow ? 4 : 0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Palette.night, Palette.night.withValues(alpha: 0)],
          ),
        ),
        child: narrow
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 48, child: stats),
                  Row(children: [lives, const Spacer(), actions]),
                ],
              )
            : SizedBox(height: compact ? 56 : 64, child: stats),
      );
    });
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.valueSize,
    this.color = Palette.text,
    this.alignEnd = false,
  });

  final String label;
  final int value;
  final double valueSize;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label(size: 11)),
          const SizedBox(height: 4),
          _PulseOnChange(
            value: value,
            child: Text(
              formatScore(value),
              style: AppText.display(valueSize, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

String formatScore(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

class _LevelProgress extends StatelessWidget {
  const _LevelProgress({required this.session, required this.compact});

  final GameSession session;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 104 : 168,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ValueListenableBuilder<int>(
            valueListenable: session.level,
            builder: (_, level, _) => Text(
              'NIVEL $level',
              style: AppText.display(compact ? 9 : 11, color: Palette.text),
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<double>(
            valueListenable: session.levelProgress,
            builder: (_, progress, _) => ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                children: [
                  Container(height: 6, color: Palette.panelBorder),
                  AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 200),
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Palette.orange, Palette.lime],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Lives extends StatelessWidget {
  const _Lives({required this.lives, required this.compact});

  final int lives;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final shown = lives.clamp(0, 5);
    final size = compact ? 16.0 : 20.0;
    return Semantics(
      label: '$lives vidas',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < shown; i++)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: TweenAnimationBuilder<double>(
                key: ValueKey('life-$i'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                builder: (_, t, child) => Transform.scale(scale: t, child: child),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Palette.lime, width: 1.5),
                    image: const DecorationImage(
                      image: AssetImage('assets/images/player.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          if (lives > shown)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('+${lives - shown}', style: AppText.label(color: Palette.lime)),
            ),
        ],
      ),
    );
  }
}

/// Briefly scales its child up whenever [value] changes.
class _PulseOnChange extends StatefulWidget {
  const _PulseOnChange({required this.value, required this.child});

  final int value;
  final Widget child;

  @override
  State<_PulseOnChange> createState() => _PulseOnChangeState();
}

class _PulseOnChangeState extends State<_PulseOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
    value: 1,
  );

  @override
  void didUpdateWidget(_PulseOnChange old) {
    super.didUpdateWidget(old);
    if (widget.value > old.value) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => Transform.scale(
        scale: 1 + 0.1 * (1 - Curves.easeOut.transform(_controller.value)),
        alignment: Alignment.centerLeft,
        child: child,
      ),
      child: widget.child,
    );
  }
}
