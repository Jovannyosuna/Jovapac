import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../game/core/grid.dart';
import '../../game/input/input_controller.dart';

/// Optional on-screen cross for touch devices. Each arm is a 52px target and
/// reports press/release so holding a direction behaves like a held key.
class TouchDpad extends StatelessWidget {
  const TouchDpad({super.key, required this.input, this.size = 156});

  final InputController input;
  final double size;

  @override
  Widget build(BuildContext context) {
    final arm = size / 3;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Center(
            child: Container(
              width: size * 0.92,
              height: size * 0.92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Palette.night.withValues(alpha: 0.35),
                border: Border.all(color: Palette.panelBorder.withValues(alpha: 0.6)),
              ),
            ),
          ),
          Positioned(left: arm, top: 0, child: _Arm(input, Dir.up, arm, Icons.keyboard_arrow_up_rounded)),
          Positioned(left: arm, bottom: 0, child: _Arm(input, Dir.down, arm, Icons.keyboard_arrow_down_rounded)),
          Positioned(left: 0, top: arm, child: _Arm(input, Dir.left, arm, Icons.keyboard_arrow_left_rounded)),
          Positioned(right: 0, top: arm, child: _Arm(input, Dir.right, arm, Icons.keyboard_arrow_right_rounded)),
        ],
      ),
    );
  }
}

class _Arm extends StatefulWidget {
  const _Arm(this.input, this.dir, this.size, this.icon);

  final InputController input;
  final Dir dir;
  final double size;
  final IconData icon;

  @override
  State<_Arm> createState() => _ArmState();
}

class _ArmState extends State<_Arm> {
  bool _down = false;

  void _set(bool down) {
    if (_down == down) return;
    setState(() => _down = down);
    down ? widget.input.press(widget.dir) : widget.input.release(widget.dir);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: _down
              ? Palette.lime.withValues(alpha: 0.3)
              : Palette.panel.withValues(alpha: 0.65),
          border: Border.all(
            color: _down ? Palette.lime : Palette.panelBorder,
            width: 1.5,
          ),
        ),
        child: Icon(widget.icon,
            size: 30, color: _down ? Palette.lime : Palette.textDim),
      ),
    );
  }
}
