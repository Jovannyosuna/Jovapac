import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../hud/hud_bar.dart';
import '../widgets/arcade_button.dart';
import '../widgets/panel.dart';

/// Closing screen for both defeat and victory.
class EndOverlay extends StatelessWidget {
  const EndOverlay({
    super.key,
    required this.victory,
    required this.score,
    required this.highScore,
    required this.level,
    required this.newRecord,
    required this.onPlayAgain,
    required this.onMenu,
  });

  final bool victory;
  final int score;
  final int highScore;
  final int level;
  final bool newRecord;
  final VoidCallback onPlayAgain;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final accent = victory ? Palette.lime : Palette.danger;
    final size = MediaQuery.sizeOf(context);
    final shortScreen = size.height < 560;
    final sideBySide = shortScreen && size.width >= 640;

    final summary = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (victory)
          Text('¡VICTORIA!', style: AppText.display(24, color: Palette.lime))
        else
          Image.asset(
            'assets/images/game_over.png',
            height: shortScreen ? 104 : 170,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) =>
                Text('GAME OVER', style: AppText.display(24, color: Palette.danger)),
          ),
        const SizedBox(height: 8),
        Text(
          victory
              ? 'Superaste los 6 niveles de JOVA-LAND.'
              : 'Llegaste al nivel $level.',
          textAlign: TextAlign.center,
          style: AppText.body(size: 15, color: Palette.textDim),
        ),
        SizedBox(height: shortScreen ? 16 : 22),
        _ResultRow(label: 'PUNTUACIÓN', value: score, animate: true),
        const SizedBox(height: 12),
        _ResultRow(label: 'RÉCORD', value: highScore, color: Palette.lime),
      ],
    );

    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (newRecord) ...[
          const EnterTransition(
            delay: Duration(milliseconds: 700),
            child: _RecordBadge(),
          ),
          SizedBox(height: sideBySide ? 22 : 26),
        ],
        ArcadeButton(
          label: 'JUGAR DE NUEVO',
          icon: Icons.replay_rounded,
          autofocus: true,
          width: sideBySide ? 250 : 280,
          onPressed: onPlayAgain,
        ),
        const SizedBox(height: 12),
        ArcadeButton(
          label: 'MENÚ PRINCIPAL',
          icon: Icons.home_rounded,
          primary: false,
          width: sideBySide ? 250 : 280,
          onPressed: onMenu,
        ),
      ],
    );

    return Scrim(
      opacity: 0.8,
      child: EnterTransition(
        child: Panel(
          accent: accent,
          maxWidth: sideBySide ? 700 : 420,
          padding: sideBySide
              ? const EdgeInsets.fromLTRB(28, 20, 28, 20)
              : const EdgeInsets.fromLTRB(32, 28, 32, 28),
          child: sideBySide
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: summary),
                    const SizedBox(width: 28),
                    actions,
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    summary,
                    SizedBox(height: newRecord ? 14 : 26),
                    actions,
                  ],
                ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    this.color = Palette.text,
    this.animate = false,
  });

  final String label;
  final int value;
  final Color color;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Palette.night.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.panelBorder),
      ),
      child: Row(
        children: [
          Text(label, style: AppText.label(size: 12)),
          const Spacer(),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: animate ? 0 : value.toDouble(), end: value.toDouble()),
            duration: Duration(milliseconds: animate ? 900 : 1),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(
              formatScore(v.round()),
              style: AppText.display(16, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordBadge extends StatefulWidget {
  const _RecordBadge();

  @override
  State<_RecordBadge> createState() => _RecordBadgeState();
}

class _RecordBadgeState extends State<_RecordBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glow,
      builder: (_, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Palette.gold.withValues(alpha: 0.12),
          border: Border.all(color: Palette.gold),
          boxShadow: [
            BoxShadow(
              color: Palette.gold.withValues(alpha: 0.15 + 0.25 * _glow.value),
              blurRadius: 18,
            ),
          ],
        ),
        child: child,
      ),
      child: Text('¡NUEVO RÉCORD!', style: AppText.button(14, color: Palette.gold)),
    );
  }
}
