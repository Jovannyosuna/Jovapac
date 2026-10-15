// =============================================================================
// ui/dialogs/profiles_dialog.dart
//
// Ventana "Perfiles": lista, abre, borra y crea perfiles.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:pacman_juego/audio/game_audio.dart';
import 'package:pacman_juego/core/constants.dart';
import 'package:pacman_juego/data/player_profile.dart';
import 'package:pacman_juego/ui/dialogs/info_dialog.dart';
import 'package:pacman_juego/ui/widgets/neon_button.dart';

/// Ventana de perfiles: lista todos los perfiles creados (con su récord y
/// nivel), permite abrir cualquiera tocándolo, borrarlo, o crear uno nuevo.
///
/// Se cierra devolviendo `true` si el jugador pidió crear un perfil nuevo.
class ProfilesDialog extends StatefulWidget {
  const ProfilesDialog();

  @override
  State<ProfilesDialog> createState() => _ProfilesDialogState();
}

class _ProfilesDialogState extends State<ProfilesDialog> {
  /// Abre el perfil tocado y cierra la ventana.
  Future<void> _select(PlayerProfile profile) async {
    GameAudio.sfx('sfx_click.wav');
    await ProfileStore.selectProfile(profile);
    if (mounted) Navigator.pop(context, false);
  }

  /// Pide confirmación y borra el perfil.
  Future<void> _delete(PlayerProfile profile) async {
    GameAudio.sfx('sfx_click.wav');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0B3D),
        title: const Text('¿Borrar perfil?'),
        content: Text(
            'Se borrará el perfil "${profile.name}" con su récord y su nivel. No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('BORRAR', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ProfileStore.deleteProfile(profile);
      if (mounted) setState(() {});
    }
  }

  /// Fila de un perfil: nombre, récord y nivel, con botón de borrar.
  Widget _tile(PlayerProfile profile) {
    final active = identical(profile, currentProfile);
    final accent = active ? neonLime : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: accent.withAlpha(active ? 30 : 12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: active ? neonLime : Colors.white24, width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _select(profile),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Récord: ${profile.highScore}   ·   Nivel: ${profile.level}'
                      '${active ? '   ·   ACTIVO' : ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Borrar perfil',
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _delete(profile),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InfoDialog(
      title: 'PERFILES',
      accent: neonLime,
      actions: [
        NeonButton(
          label: 'NUEVO PERFIL',
          s: 1.1,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
      child: allProfiles.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Todavía no hay perfiles.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
            )
          : Column(children: [for (final p in allProfiles) _tile(p)]),
    );
  }
}
