import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../../app/theme.dart';
import '../ai/ghost_brain.dart';
import '../core/grid.dart';
import '../core/units.dart';
import '../maze/maze.dart';
import 'grid_mover.dart';
import 'portrait.dart';

/// Per-frame world facts the ghosts reason about. One instance is reused.
class GhostContext {
  late Maze maze;
  late Cell playerCell;
  Dir playerDir = Dir.none;
  Cell? chaserCell;
  GhostMode mode = GhostMode.scatter;
  double baseSpeed = 5;
  bool chaserRush = false;
  bool frightEnding = false;
  late Random random;
}

class Ghost extends PositionComponent {
  Ghost(this._face, this._scared, Maze maze, this.slotIndex)
      : mover = GridMover(maze, maze.houseSlots[slotIndex]),
        super(priority: 4, anchor: Anchor.center);

  static const double radius = 11;
  static const double eatenSpeed = 13;

  final ui.Image _face;
  final ui.Image _scared;
  final int slotIndex;
  final GridMover mover;
  final PortraitRenderer _renderer = PortraitRenderer();
  final Paint _eyeWhite = Paint()..color = const Color(0xFFF4F1FF);
  final Paint _pupil = Paint()..color = const Color(0xFF1B1640);
  final Paint _eyeRing = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;

  GhostPersonality personality = GhostPersonality.chaser;
  GhostState state = GhostState.home;
  bool frightened = false;
  bool active = false;
  bool hidden = false;
  double _releaseIn = 0;
  double _time = 0;
  double _appear = 0;
  bool _frightEnding = false;

  bool get isDangerous =>
      active && !frightened && state != GhostState.eaten && !hidden;

  bool get isEdible => active && frightened && state != GhostState.eaten;

  void spawn({
    required Maze maze,
    required GhostPersonality personality,
    required double releaseDelay,
  }) {
    this.personality = personality;
    active = true;
    hidden = false;
    frightened = false;
    state = GhostState.home;
    _releaseIn = releaseDelay;
    _appear = 0;
    _time = slotIndex * 0.7;
    mover
      ..maze = maze
      ..place(maze.houseSlots[slotIndex]);
    _sync();
  }

  void deactivate() {
    active = false;
    hidden = true;
  }

  void frighten() {
    if (!active || state == GhostState.eaten) return;
    final wasActiveMode =
        state == GhostState.scatter || state == GhostState.chase;
    if (wasActiveMode && !frightened) mover.reverse();
    frightened = true;
  }

  void calm() => frightened = false;

  void markEaten() {
    frightened = false;
    state = GhostState.eaten;
  }

  void onModeChanged(GhostMode mode) {
    if (state != GhostState.scatter && state != GhostState.chase) return;
    state = mode == GhostMode.scatter ? GhostState.scatter : GhostState.chase;
    if (!frightened) mover.reverse();
  }

  void step(double dt, GhostContext ctx) {
    if (!active) return;
    _frightEnding = ctx.frightEnding;
    if (state == GhostState.home) {
      _releaseIn -= dt;
      if (_releaseIn <= 0) state = GhostState.leaving;
      return;
    }
    final maze = ctx.maze;
    mover.advance(
      _speed(ctx) * dt,
      canEnter: (cell) => maze.canGhostEnter(
        cell,
        throughDoor: state == GhostState.leaving || state == GhostState.eaten,
      ),
      decide: (at, current) => _decide(at, current, ctx),
      onCellReached: (cell) {
        if (state == GhostState.leaving && cell == maze.houseExit) {
          state = ctx.mode == GhostMode.scatter
              ? GhostState.scatter
              : GhostState.chase;
        } else if (state == GhostState.eaten && cell == maze.houseSlots.first) {
          state = GhostState.leaving;
        }
      },
    );
    _sync();
  }

  double _speed(GhostContext ctx) {
    if (state == GhostState.eaten) return eatenSpeed;
    var speed = ctx.baseSpeed;
    if (state == GhostState.leaving) {
      speed *= 0.6;
    } else if (frightened) {
      speed *= 0.6;
    } else if (ctx.chaserRush && personality == GhostPersonality.chaser) {
      speed *= 1.08;
    }
    if (ctx.maze.isTunnel(mover.cell)) speed *= 0.5;
    return speed;
  }

  Dir _decide(Cell at, Dir current, GhostContext ctx) {
    final maze = ctx.maze;
    switch (state) {
      case GhostState.home:
        return Dir.none;
      case GhostState.leaving:
        return maze.stepTowardExit(at);
      case GhostState.eaten:
        return maze.stepTowardHome(at);
      case GhostState.scatter:
      case GhostState.chase:
        bool canEnter(Cell c) => maze.canGhostEnter(c, throughDoor: false);
        if (frightened) {
          return chooseDirection(
            maze: maze,
            at: at,
            current: current,
            canEnter: canEnter,
            random: ctx.random,
          );
        }
        final target = state == GhostState.scatter
            ? scatterCorner(personality, maze)
            : chaseTarget(
                personality: personality,
                maze: maze,
                self: at,
                player: ctx.playerCell,
                playerDir: ctx.playerDir,
                chaser: ctx.chaserCell,
              );
        return chooseDirection(
          maze: maze,
          at: at,
          current: current,
          canEnter: canEnter,
          target: target,
        );
    }
  }

  void _sync() => position.setValues(mover.x * kTile, mover.y * kTile);

  @override
  void update(double dt) {
    _time += dt;
    if (_appear < 1) _appear = min(1, _appear + dt * 3);
  }

  @override
  void render(Canvas canvas) {
    if (!active || hidden) return;
    if (state == GhostState.eaten) {
      _renderEyes(canvas);
      return;
    }
    final appear = Curves.easeOutBack.transform(_appear);
    final bob = sin(_time * (state == GhostState.home ? 4 : 6)) *
        (state == GhostState.home ? 2.2 : 1.0);

    canvas
      ..save()
      ..translate(0, bob)
      ..scale(appear);
    if (frightened) {
      final flashWhite = _frightEnding && (_time * 6).floor().isEven;
      canvas.rotate(sin(_time * 16) * 0.09);
      _renderer.draw(
        canvas,
        image: _scared,
        radius: radius,
        ring: flashWhite ? Palette.text : Palette.fright,
        glow: 0.55,
        tint: (flashWhite ? Palette.text : Palette.fright)
            .withValues(alpha: 0.22),
      );
    } else {
      _renderer.draw(
        canvas,
        image: _face,
        radius: radius,
        ring: personality.color,
        glow: 0.4,
        opacity: state == GhostState.home ? 0.85 : 1,
      );
    }
    canvas.restore();
  }

  void _renderEyes(Canvas canvas) {
    final look = Offset(mover.dir.dx * 1.6, mover.dir.dy * 1.6);
    _eyeRing.color = personality.color.withValues(alpha: 0.6);
    for (final side in const [-1.0, 1.0]) {
      final center = Offset(side * 4.2, -1);
      canvas
        ..drawOval(Rect.fromCenter(center: center, width: 6.5, height: 8), _eyeWhite)
        ..drawOval(Rect.fromCenter(center: center, width: 6.5, height: 8), _eyeRing)
        ..drawCircle(center + look, 1.9, _pupil);
    }
  }
}
