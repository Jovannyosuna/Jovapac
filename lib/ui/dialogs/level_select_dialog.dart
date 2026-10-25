// =============================================================================
// ui/dialogs/level_select_dialog.dart
//
// Ventana "Elige nivel": los niveles desbloqueados del perfil.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:pacman_juego/audio/game_audio.dart';
import 'package:pacman_juego/core/constants.dart';
import 'package:pacman_juego/game/levels/level_data.dart';
import 'package:pacman_juego/ui/dialogs/info_dialog.dart';

/// Ventana para elegir el nivel con el que empezar. Solo se pueden elegir los
/// niveles que el perfil ya alcanzó; los demás aparecen con candado. Devuelve el
/// número de nivel elegido.
class LevelSelectDialog extends StatelessWidget {
  const LevelSelectDialog({super.key, required this.unlocked});

  /// Nivel más alto que el perfil tiene desbloqueado.
  final int unlocked;

  Widget _tile(BuildContext context, LevelData level) {
    final open = level.number <= unlocked;
    final color = open ? level.wallBorder : Colors.white24;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(open ? 30 : 12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: open
            ? () {
                GameAudio.sfx('sfx_click.wav');
                Navigator.pop(context, level.number);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Text(
                  '${level.number}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      level.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: open ? Colors.white : Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      level.subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: open ? Colors.white60 : Colors.white24,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(open ? Icons.play_arrow : Icons.lock, color: color),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InfoDialog(
      title: 'ELIGE NIVEL',
      accent: neonLime,
      child: Column(children: [for (final level in kLevels) _tile(context, level)]),
    );
  }
}
