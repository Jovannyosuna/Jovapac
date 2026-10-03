import 'dart:math';
import 'dart:ui';

import '../core/grid.dart';
import '../maze/maze.dart';

enum GhostPersonality {
  /// Heads straight for the player.
  chaser(Color(0xFFFF4D5E)),

  /// Aims four tiles ahead of the player to cut them off.
  ambusher(Color(0xFFFF7BD5)),

  /// Mirrors the chaser around a point ahead of the player, closing pincers.
  flanker(Color(0xFF3EE6FF)),

  /// Chases from afar but retreats to its corner when close.
  shy(Color(0xFFFFA23A));

  const GhostPersonality(this.color);

  final Color color;
}

/// Behaviour states. Frightened is an overlay on scatter/chase and is tracked
/// separately on the ghost so it can return to the current global mode.
enum GhostState { home, leaving, scatter, chase, eaten }

enum GhostMode { scatter, chase }

/// Global scatter/chase timeline shared by all ghosts in a level.
class ModeSchedule {
  ModeSchedule(this._durations);

  final List<double> _durations;
  int _index = 0;
  double _elapsed = 0;

  GhostMode get mode => _index < _durations.length && _index.isEven
      ? GhostMode.scatter
      : GhostMode.chase;

  /// Advances the timeline. Returns true when the mode just flipped.
  bool update(double dt) {
    if (_index >= _durations.length) return false;
    _elapsed += dt;
    if (_elapsed < _durations[_index]) return false;
    final before = mode;
    _elapsed = 0;
    _index++;
    return mode != before;
  }
}

Cell scatterCorner(GhostPersonality personality, Maze maze) =>
    switch (personality) {
      GhostPersonality.chaser => Cell(maze.cols - 2, -2),
      GhostPersonality.ambusher => const Cell(1, -2),
      GhostPersonality.flanker => Cell(maze.cols - 1, maze.rows + 1),
      GhostPersonality.shy => Cell(0, maze.rows + 1),
    };

/// Target tile while chasing, following each personality's rule.
Cell chaseTarget({
  required GhostPersonality personality,
  required Maze maze,
  required Cell self,
  required Cell player,
  required Dir playerDir,
  required Cell? chaser,
}) {
  switch (personality) {
    case GhostPersonality.chaser:
      return player;
    case GhostPersonality.ambusher:
      return player.step(playerDir, 4);
    case GhostPersonality.flanker:
      final pivot = player.step(playerDir, 2);
      final anchor = chaser ?? player;
      return Cell(
        pivot.col * 2 - anchor.col,
        pivot.row * 2 - anchor.row,
      );
    case GhostPersonality.shy:
      return self.distanceSquaredTo(player) > 64
          ? player
          : scatterCorner(personality, maze);
  }
}

/// Picks the move at an intersection: never reverse unless trapped, then the
/// option closest to [target] (or a random one when [random] is given).
Dir chooseDirection({
  required Maze maze,
  required Cell at,
  required Dir current,
  required bool Function(Cell) canEnter,
  Cell? target,
  Random? random,
}) {
  final options = <Dir>[];
  for (final dir in Dir.moves) {
    if (dir == current.opposite && current != Dir.none) continue;
    if (canEnter(maze.wrap(at.step(dir)))) options.add(dir);
  }
  if (options.isEmpty) {
    return canEnter(maze.wrap(at.step(current.opposite)))
        ? current.opposite
        : Dir.none;
  }
  if (random != null || target == null) {
    return options[(random ?? Random()).nextInt(options.length)];
  }
  var best = options.first;
  var bestDistance = at.step(best).distanceSquaredTo(target);
  for (final dir in options.skip(1)) {
    final d = at.step(dir).distanceSquaredTo(target);
    if (d < bestDistance) {
      best = dir;
      bestDistance = d;
    }
  }
  return best;
}
