import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../hud/hud_bar.dart';
import '../widgets/arcade_button.dart';
import '../widgets/backdrop.dart';
import '../widgets/panel.dart';
import 'game_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  Future<void> _play() async {
    await Navigator.of(context).push(fadeRoute(const GameScreen()));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      body: Backdrop(
        animated: true,
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final landscapeShort =
                constraints.maxHeight < 560 && constraints.maxWidth > constraints.maxHeight;
            final logoWidth = min(460.0, constraints.maxWidth * (landscapeShort ? 0.42 : 0.82));

            final brand = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EnterTransition(child: _FloatingLogo(width: logoWidth)),
                const SizedBox(height: 6),
                EnterTransition(
                  delay: const Duration(milliseconds: 120),
                  child: Text('ARCADE  ·  6 NIVELES  ·  3 LABERINTOS',
                      textAlign: TextAlign.center, style: AppText.label(size: 12)),
                ),
                const SizedBox(height: 18),
                EnterTransition(
                  delay: const Duration(milliseconds: 200),
                  child: _RecordChip(score: scope.save.highScore),
                ),
              ],
            );

            final actions = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                EnterTransition(
                  delay: const Duration(milliseconds: 260),
                  child: ArcadeButton(
                    label: 'JUGAR',
                    icon: Icons.play_arrow_rounded,
                    autofocus: true,
                    onPressed: _play,
                  ),
                ),
                const SizedBox(height: 12),
                EnterTransition(
                  delay: const Duration(milliseconds: 320),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: scope.audio.muted,
                    builder: (_, muted, _) => ArcadeButton(
                      label: muted ? 'SONIDO: NO' : 'SONIDO: SÍ',
                      icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      primary: false,
                      onPressed: scope.toggleMute,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const EnterTransition(
                  delay: Duration(milliseconds: 400),
                  child: _HowToPlay(),
                ),
              ],
            );

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: landscapeShort
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(child: brand),
                          const SizedBox(width: 36),
                          actions,
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [brand, const SizedBox(height: 30), actions],
                      ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _FloatingLogo extends StatefulWidget {
  const _FloatingLogo({required this.width});

  final double width;

  @override
  State<_FloatingLogo> createState() => _FloatingLogoState();
}

class _FloatingLogoState extends State<_FloatingLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _float,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_float.value);
        return Transform.translate(
          offset: Offset(0, -6 * t),
          child: Transform.rotate(angle: (t - 0.5) * 0.02, child: child),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scaleX: 2.2,
            child: SizedBox.square(
              dimension: widget.width * 0.5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [
                    Palette.lime.withValues(alpha: 0.16),
                    Palette.lime.withValues(alpha: 0.05),
                    Palette.lime.withValues(alpha: 0),
                  ], stops: const [0, 0.45, 1]),
                ),
              ),
            ),
          ),
          Semantics(
            label: 'LA SANVI',
            image: true,
            child: Image.asset(
              'assets/images/logo.png',
              width: widget.width,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Text('JOVA-LAND', style: AppText.display(28, color: Palette.lime)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordChip extends StatelessWidget {
  const _RecordChip({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.night.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Palette.panelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events_rounded, size: 18, color: Palette.gold),
          const SizedBox(width: 10),
          Text('RÉCORD', style: AppText.label(size: 12)),
          const SizedBox(width: 12),
          Text(formatScore(score), style: AppText.display(13, color: Palette.lime)),
        ],
      ),
    );
  }
}

class _HowToPlay extends StatelessWidget {
  const _HowToPlay();

  @override
  Widget build(BuildContext context) {
    return Panel(
      maxWidth: 360,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('CÓMO JUGAR', style: AppText.label(size: 11)),
          const SizedBox(height: 10),
          const _Legend(
            image: 'assets/images/player.png',
            ring: Palette.lime,
            text: 'Come todos los puntos del laberinto.',
          ),
          const _Legend(
            image: 'assets/images/burger.png',
            ring: Palette.orange,
            text: 'Hamburguesa: los fantasmas huyen y puedes cazarlos.',
          ),
          const _Legend(
            image: 'assets/images/ghost_face.png',
            ring: Palette.danger,
            text: 'Esquiva a los fantasmas: cada uno caza a su manera.',
          ),
          const SizedBox(height: 6),
          Text('Flechas / WASD · Esc pausa · M sonido',
              style: AppText.body(size: 13, color: Palette.textFaint)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.image, required this.ring, required this.text});

  final String image;
  final Color ring;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 1.6),
              image: DecorationImage(image: AssetImage(image), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppText.body(size: 14))),
        ],
      ),
    );
  }
}
