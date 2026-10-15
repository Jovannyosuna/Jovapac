// =============================================================================
// ui/dialogs/name_dialog.dart
//
// Cuadro para crear un perfil escribiendo el nombre (máx. 12 caracteres).
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:pacman_juego/audio/game_audio.dart';
import 'package:pacman_juego/core/constants.dart';
import 'package:pacman_juego/ui/widgets/neon_button.dart';

/// Cuadro de diálogo para crear un perfil (pide solo el nombre).
///
/// Acepta letras, números y espacios, con un límite de 12 caracteres. Devuelve
/// el nombre (sin espacios sobrantes) al aceptar. Si [canCancel] es `false`
/// no se puede cerrar sin escribir un nombre.
class NameDialog extends StatefulWidget {
  const NameDialog({
    required this.initial,
    required this.canCancel,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
  });

  /// Texto con el que arranca el campo.
  final String initial;
  /// Si es `true` se muestra el botón Cancelar y se permite cerrar con "atrás".
  final bool canCancel;
  /// Título del cuadro (por ejemplo "CREAR PERFIL").
  final String title;
  /// Texto de ayuda bajo el título.
  final String subtitle;
  /// Texto del botón de confirmar.
  final String confirmLabel;

  @override
  State<NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<NameDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Acepta el nombre solo si no está vacío.
  void _submit() {
    final name = _c.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.canCancel,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A0F5C), Color(0xFF07051A)],
              ),
              border: Border.all(color: Colors.cyanAccent, width: 2.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.cyanAccent.withAlpha(90),
                    blurRadius: 26,
                    spreadRadius: 1),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: neonLime,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _c,
                  autofocus: true,
                  maxLength: 12,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[\p{L}\p{N} ]', unicode: true)),
                  ],
                  cursorColor: Colors.pinkAccent,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: 'TU NOMBRE',
                    hintStyle: const TextStyle(
                        color: Colors.white24, letterSpacing: 3),
                    counterStyle: const TextStyle(color: Colors.white54),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Colors.pinkAccent, width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: Colors.cyanAccent, width: 2),
                    ),
                  ),
                  // Sonido al escribir cada letra.
                  onChanged: (_) => GameAudio.sfx('sfx_type.wav', volume: 0.7),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                // El botón se atenúa mientras el campo esté vacío.
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _c,
                  builder: (context, value, _) {
                    final empty = value.text.trim().isEmpty;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.canCancel) ...[
                          NeonButton(
                            label: 'CANCELAR',
                            s: 1.4,
                            filled: false,
                            color: Colors.white,
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Opacity(
                          opacity: empty ? 0.4 : 1.0,
                          child: NeonButton(
                              label: widget.confirmLabel,
                              s: 1.4,
                              onPressed: _submit),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
