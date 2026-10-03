import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../../app/theme.dart';
import '../core/grid.dart';
import '../core/units.dart';
import '../maze/maze.dart';
import 'grid_mover.dart';
import 'portrait.dart';

class Player extends PositionComponent {
  Player(this._portrait, Maze maze)
      : mover = GridMover(maze, maze.playerStart),
        super(priority: 5, anchor: Anchor.center);

  /// Turns requested this close past a cell centre are still honoured by
  /// snapping back, so slightly late inputs feel responsive.
  static const double lateTurnWindow = 0.22;
  static const double radius = 11;

  final ui.Image _portrait;
  final GridMover mover;
  final PortraitRenderer _renderer = PortraitRenderer();

  double _time = 0;
  double _chew = 0;
  double _bump = 0;
  double _deathTime = -1;
  bool _facingLeft = false;
  final Vector2 _visual = Vector2.zero();

  bool get isDying => _deathTime >= 0;

  void reset(Maze maze) {
    mover
      ..maze = maze
      ..place(maze.playerStart);
    _deathTime = -1;
    _bump = 0;
    _facingLeft = true;
    _syncPosition(snap: true);
  }

  /// Applies input that can act between cell centres: instant reversal and
  /// forgiving late turns.
  bool steer(Dir desired) {
    if (desired == Dir.none || mover.isCentered) return false;
    if (desired == mover.dir.opposite) {
      mover.reverse();
      return true;
    }
    if (desired.isPerpendicularTo(mover.dir) &&
        mover.progress <= lateTurnWindow &&
        mover.maze.canPlayerEnter(mover.maze.wrap(mover.cell.step(desired)))) {
      mover
        ..progress = 0
        ..dir = desired;
      return true;
    }
    return false;
  }

  void move(double distance, Dir desired, {void Function(Dir)? onTurn}) {
    final maze = mover.maze;
    mover.advance(
      distance,
      canEnter: maze.canPlayerEnter,
      decide: (at, current) {
        if (desired != Dir.none &&
            desired != current &&
            maze.canPlayerEnter(maze.wrap(at.step(desired)))) {
          onTurn?.call(desired);
          return desired;
        }
        return current;
      },
    );
    if (!mover.blocked) _chew += distance;
    _syncPosition();
  }

  /// Small squash when something is eaten.
  void bump([double strength = 1]) => _bump = max(_bump, strength);

  void startDeath() => _deathTime = 0;

  @override
  void update(double dt) {
    _time += dt;
    if (_bump > 0) _bump = max(0, _bump - dt * 6);
    if (_deathTime >= 0) _deathTime += dt;
    if (mover.dir == Dir.left) _facingLeft = true;
    if (mover.dir == Dir.right) _facingLeft = false;
  }

  void _syncPosition({bool snap = false}) {
    final tx = mover.x * kTile, ty = mover.y * kTile;
    if (snap || (_visual.x - tx).abs() > kTile * 1.5 || (_visual.y - ty).abs() > kTile * 1.5) {
      _visual.setValues(tx, ty);
    } else {
      // Ease out the small snap of a late turn instead of popping.
      _visual.x += (tx - _visual.x) * 0.55;
      _visual.y += (ty - _visual.y) * 0.55;
    }
    position.setFrom(_visual);
  }

  @override
  void render(Canvas canvas) {
    var scale = 1.0;
    var rotation = 0.0;
    var opacity = 1.0;
    if (_deathTime >= 0) {
      final t = (_deathTime / 1.1).clamp(0.0, 1.0);
      scale = 1 - Curves.easeInBack.transform(t);
      rotation = t * pi * 3;
      opacity = 1 - t * 0.6;
      if (scale <= 0.01) return;
    }

    final moving = !mover.blocked && mover.dir != Dir.none && _deathTime < 0;
    final chew = moving ? sin(_chew * pi * 2) : 0.0;
    final sx = scale * (1 + 0.07 * chew + 0.12 * _bump);
    final sy = scale * (1 - 0.06 * chew - 0.08 * _bump);
    final tilt = switch (mover.dir) {
      Dir.up => -0.12,
      Dir.down => 0.12,
      _ => 0.0,
    } * (_facingLeft ? -1 : 1);
    final idleBob = moving ? 0.0 : sin(_time * 3) * 0.8;

    canvas
      ..save()
      ..translate(0, idleBob)
      ..rotate(rotation + tilt)
      ..scale(sx, sy);
    _renderer.draw(
      canvas,
      image: _portrait,
      radius: radius,
      ring: Palette.lime,
      glow: 0.45,
      opacity: opacity,
      flip: _facingLeft,
    );
    canvas.restore();
  }
}
