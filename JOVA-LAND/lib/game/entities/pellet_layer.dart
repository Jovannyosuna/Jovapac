import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../app/theme.dart';
import '../core/grid.dart';
import '../core/units.dart';
import '../maze/maze.dart';

/// All collectibles of a level in one component, backed by a flat grid so
/// eating is O(1). Regular pellets are re-recorded only when one is eaten.
class PelletLayer extends PositionComponent {
  PelletLayer(this._burger) : super(priority: 2);

  final ui.Image _burger;

  late Maze _maze;
  late List<Pellet> _grid;
  final List<Cell> _powerCells = [];
  int remaining = 0;
  int total = 0;

  ui.Picture? _cache;
  bool _dirty = true;
  double _time = 0;
  bool hidden = false;

  final Paint _pelletPaint = Paint()..color = Palette.pellet;
  final Paint _pelletGlow = Paint()
    ..color = Palette.pellet.withValues(alpha: 0.18)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
  final Paint _powerGlow = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  final Paint _spritePaint = Paint()..filterQuality = FilterQuality.medium;

  void reset(Maze maze) {
    _maze = maze;
    _grid = List.of(maze.initialPellets);
    _powerCells
      ..clear()
      ..addAll([
        for (var i = 0; i < _grid.length; i++)
          if (_grid[i] == Pellet.power) Cell(i % maze.cols, i ~/ maze.cols),
      ]);
    total = _grid.where((p) => p != Pellet.none).length;
    remaining = total;
    _dirty = true;
    hidden = false;
  }

  /// Removes and returns the collectible at [cell], if any.
  Pellet eat(Cell cell) {
    final index = _maze.indexOf(cell);
    final pellet = _grid[index];
    if (pellet == Pellet.none) return pellet;
    _grid[index] = Pellet.none;
    remaining--;
    if (pellet == Pellet.normal) {
      _dirty = true;
    } else {
      _powerCells.remove(cell);
    }
    return pellet;
  }

  @override
  void update(double dt) => _time += dt;

  @override
  void render(Canvas canvas) {
    if (hidden) return;
    if (_dirty) _record();
    canvas.drawPicture(_cache!);

    final pulse = 0.5 + 0.5 * sin(_time * 5);
    for (final cell in _powerCells) {
      final center = Offset((cell.col + 0.5) * kTile, (cell.row + 0.5) * kTile);
      _powerGlow.color = Palette.orange.withValues(alpha: 0.25 + 0.25 * pulse);
      canvas.drawCircle(center, 9 + 2 * pulse, _powerGlow);
      final half = 8.5 + 1.2 * pulse;
      canvas.drawImageRect(
        _burger,
        Rect.fromLTWH(0, 0, _burger.width.toDouble(), _burger.height.toDouble()),
        Rect.fromCircle(center: center, radius: half),
        _spritePaint,
      );
    }
  }

  void _record() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 0; i < _grid.length; i++) {
      if (_grid[i] != Pellet.normal) continue;
      final center = Offset(
        (i % _maze.cols + 0.5) * kTile,
        (i ~/ _maze.cols + 0.5) * kTile,
      );
      canvas
        ..drawCircle(center, 4, _pelletGlow)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCircle(center: center, radius: 2.4),
            const Radius.circular(1.2),
          ),
          _pelletPaint,
        );
    }
    _cache?.dispose();
    _cache = recorder.endRecording();
    _dirty = false;
  }

  @override
  void onRemove() {
    _cache?.dispose();
    _cache = null;
    super.onRemove();
  }
}
