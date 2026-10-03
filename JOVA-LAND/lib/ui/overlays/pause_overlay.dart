import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../widgets/arcade_button.dart';
import '../widgets/panel.dart';

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.muted,
    required this.onResume,
    required this.onRestart,
    required this.onToggleMute,
    required this.onMenu,
  });

  final ValueListenable<bool> muted;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onToggleMute;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final grid = size.height < 560 && size.width >= 640;
    final buttonWidth = grid ? 236.0 : 280.0;

    final resume = ArcadeButton(
      label: 'CONTINUAR',
      icon: Icons.play_arrow_rounded,
      autofocus: true,
      width: buttonWidth,
      onPressed: onResume,
    );
    final restart = ArcadeButton(
      label: 'REINICIAR',
      icon: Icons.refresh_rounded,
      primary: false,
      width: buttonWidth,
      onPressed: onRestart,
    );
    final sound = ValueListenableBuilder<bool>(
      valueListenable: muted,
      builder: (_, isMuted, _) => ArcadeButton(
        label: isMuted ? 'SONIDO: NO' : 'SONIDO: SÍ',
        icon: isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
        primary: false,
        width: buttonWidth,
        onPressed: onToggleMute,
      ),
    );
    final menu = ArcadeButton(
      label: 'MENÚ PRINCIPAL',
      icon: Icons.home_rounded,
      primary: false,
      width: buttonWidth,
      onPressed: onMenu,
    );

    const gap = SizedBox(width: 12, height: 12);
    return Scrim(
      child: EnterTransition(
        child: Panel(
          maxWidth: grid ? 560 : 380,
          padding: grid
              ? const EdgeInsets.fromLTRB(28, 22, 28, 24)
              : const EdgeInsets.fromLTRB(32, 28, 32, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('PAUSA', style: AppText.display(22, color: Palette.lime)),
              const SizedBox(height: 8),
              Text('Esc o P para continuar', style: AppText.body(size: 14, color: Palette.textDim)),
              SizedBox(height: grid ? 20 : 26),
              if (grid) ...[
                Row(mainAxisSize: MainAxisSize.min, children: [resume, gap, restart]),
                gap,
                Row(mainAxisSize: MainAxisSize.min, children: [sound, gap, menu]),
              ] else ...[
                resume,
                gap,
                restart,
                gap,
                sound,
                gap,
                menu,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
