import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../game/game_session.dart';
import '../hud/hud_bar.dart';
import '../widgets/panel.dart';

/// "Get ready" card shown over the maze before play starts.
class ReadyBanner extends StatelessWidget {
  const ReadyBanner({
    super.key,
    required this.level,
    required this.mazeName,
    this.hint,
  });

  final int level;
  final String mazeName;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: EnterTransition(
          offset: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            decoration: BoxDecoration(
              color: Palette.night.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Palette.lime.withValues(alpha: 0.4)),
              boxShadow: [
                BoxShadow(color: Palette.lime.withValues(alpha: 0.15), blurRadius: 24),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('NIVEL $level · ${mazeName.toUpperCase()}',
                    style: AppText.label(size: 12)),
                const SizedBox(height: 10),
                Text('¡LISTO!', style: AppText.display(20, color: Palette.lime)),
                if (hint != null) ...[
                  const SizedBox(height: 12),
                  Text(hint!,
                      textAlign: TextAlign.center,
                      style: AppText.body(size: 14, color: Palette.textDim)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Result card between levels.
class LevelClearBanner extends StatelessWidget {
  const LevelClearBanner({super.key, required this.summary});

  final LevelSummary summary;

  @override
  Widget build(BuildContext context) {
    final perfect = summary.perfectBonus > 0;
    return IgnorePointer(
      child: Center(
        child: EnterTransition(
          child: Panel(
            maxWidth: 360,
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('NIVEL ${summary.level}', style: AppText.label(size: 12)),
                const SizedBox(height: 10),
                Text('¡SUPERADO!', style: AppText.display(18, color: Palette.lime)),
                const SizedBox(height: 16),
                EnterTransition(
                  delay: const Duration(milliseconds: 250),
                  child: perfect
                      ? Text(
                          'SIN FALLOS  +${formatScore(summary.perfectBonus)}',
                          style: AppText.display(10, color: Palette.gold),
                        )
                      : Text('Sigue así. El siguiente es más duro.',
                          style: AppText.body(size: 14, color: Palette.textDim)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Transient message pill (extra life, bonus coin...).
class ToastLayer extends StatelessWidget {
  const ToastLayer({super.key, required this.toast});

  final ValueListenable<HudToast?> toast;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ValueListenableBuilder<HudToast?>(
          valueListenable: toast,
          builder: (_, value, _) {
            if (value == null) return const SizedBox.shrink();
            return _ToastPill(key: ValueKey(value.id), text: value.text);
          },
        ),
      ),
    );
  }
}

class _ToastPill extends StatefulWidget {
  const _ToastPill({super.key, required this.text});

  final String text;

  @override
  State<_ToastPill> createState() => _ToastPillState();
}

class _ToastPillState extends State<_ToastPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final t = _controller.value;
        final inT = Curves.easeOutBack.transform((t / 0.15).clamp(0.0, 1.0));
        final out = t > 0.8 ? (1 - t) / 0.2 : 1.0;
        return Opacity(
          opacity: out.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -12 * (1 - inT)),
            child: Transform.scale(scale: 0.85 + 0.15 * inT, child: child),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Palette.night.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Palette.gold.withValues(alpha: 0.7)),
          boxShadow: [BoxShadow(color: Palette.gold.withValues(alpha: 0.25), blurRadius: 18)],
        ),
        child: Text(widget.text, style: AppText.display(10, color: Palette.gold)),
      ),
    );
  }
}
