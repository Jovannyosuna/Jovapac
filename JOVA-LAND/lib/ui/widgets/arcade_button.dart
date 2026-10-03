import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../services/audio_service.dart';

/// Primary interactive control: large hit area, visible keyboard focus,
/// hover glow and a tactile press scale.
class ArcadeButton extends StatefulWidget {
  const ArcadeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
    this.autofocus = false,
    this.icon,
    this.width = 280,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final bool autofocus;
  final IconData? icon;
  final double width;

  @override
  State<ArcadeButton> createState() => _ArcadeButtonState();
}

class _ArcadeButtonState extends State<ArcadeButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  void _activate() {
    AppScope.read(context).audio.play(Sfx.select);
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = _hovered || _focused;
    final primary = widget.primary;
    final foreground = primary ? const Color(0xFF15101F) : Palette.text;
    final border = primary
        ? Palette.lime
        : (highlighted ? Palette.lime : Palette.panelBorder);

    return FocusableActionDetector(
      autofocus: widget.autofocus,
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        label: widget.label,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: _activate,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : (highlighted ? 1.03 : 1),
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: widget.width,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: primary
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(Palette.lime, Colors.white, highlighted ? 0.25 : 0.12)!,
                          Palette.lime,
                        ],
                      )
                    : null,
                color: primary
                    ? null
                    : (highlighted
                        ? Palette.lime.withValues(alpha: 0.08)
                        : Palette.panel.withValues(alpha: 0.6)),
                border: Border.all(color: border, width: 2),
                boxShadow: [
                  if (highlighted || primary)
                    BoxShadow(
                      color: Palette.lime
                          .withValues(alpha: highlighted ? 0.45 : 0.18),
                      blurRadius: highlighted ? 22 : 14,
                    ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 18, color: foreground),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: AppText.button(16, color: foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Round icon button for HUD actions (pause, sound).
class HudIconButton extends StatefulWidget {
  const HudIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  State<HudIconButton> createState() => _HudIconButtonState();
}

class _HudIconButtonState extends State<HudIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hovered
                  ? Palette.lime.withValues(alpha: 0.12)
                  : Palette.panel.withValues(alpha: 0.7),
              border: Border.all(
                color: _hovered ? Palette.lime : Palette.panelBorder,
                width: 1.5,
              ),
            ),
            child: Icon(widget.icon,
                size: 20, color: _hovered ? Palette.lime : Palette.textDim),
          ),
        ),
      ),
    );
  }
}
