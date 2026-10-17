// =============================================================================
// ui/dialogs/info_dialog.dart
//
// Marco neón reutilizable para las ventanas informativas del menú.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:pacman_juego/ui/widgets/neon_button.dart';

/// Marco neón reutilizable para las ventanas informativas del menú: título,
/// contenido desplazable y botón Cerrar.
class InfoDialog extends StatelessWidget {
  const InfoDialog({
    super.key,
    required this.title,
    required this.accent,
    required this.child,
    this.actions = const [],
  });

  /// Título de la ventana.
  final String title;
  /// Color del borde, del resplandor y del título.
  final Color accent;
  /// Contenido (se desplaza si no cabe en pantalla).
  final Widget child;
  /// Botones extra sobre el botón Cerrar (opcional).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxHeight),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A0F5C), Color(0xFF07051A)],
            ),
            border: Border.all(color: accent, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: accent.withAlpha(90), blurRadius: 26, spreadRadius: 1),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  color: accent,
                ),
              ),
              const SizedBox(height: 10),
              Flexible(child: SingleChildScrollView(child: child)),
              const SizedBox(height: 12),
              if (actions.isNotEmpty) ...[
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: actions,
                ),
                const SizedBox(height: 8),
              ],
              NeonButton(
                label: 'CERRAR',
                s: 1.2,
                filled: false,
                color: accent,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bloque de texto con título de color y una lista de líneas con viñeta.
class InfoSection extends StatelessWidget {
  const InfoSection({
    super.key,
    required this.title,
    required this.color,
    required this.lines,
  });

  final String title;
  final Color color;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '•  $line',
                style: const TextStyle(
                    fontSize: 13, height: 1.3, color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }
}
