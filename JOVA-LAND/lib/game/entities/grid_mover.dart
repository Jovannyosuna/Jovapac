import '../core/grid.dart';
import '../maze/maze.dart';

/// Tile-to-tile movement shared by the player and ghosts.
///
/// The mover is always "leaving" [cell] in [dir], [progress] tiles of the way
/// to the next cell. Decisions are only taken on cell centres (progress 0),
/// which keeps every actor perfectly aligned with corridors.
class GridMover {
  GridMover(this.maze, this.cell);

  Maze maze;
  Cell cell;
  Dir dir = Dir.none;
  double progress = 0;
  bool blocked = false;

  void place(Cell at, {Dir facing = Dir.none}) {
    cell = at;
    dir = facing;
    progress = 0;
    blocked = false;
  }

  /// Position of the actor's centre in tile units.
  double get x => cell.col + 0.5 + dir.dx * progress;
  double get y => cell.row + 0.5 + dir.dy * progress;

  bool get isCentered => progress == 0;

  /// The cell the actor overlaps the most.
  Cell get nearestCell =>
      progress >= 0.5 ? maze.wrap(cell.step(dir)) : cell;

  /// Flips direction mid-corridor without losing position.
  void reverse() {
    if (dir == Dir.none) return;
    if (progress > 0) {
      cell = maze.wrap(cell.step(dir));
      progress = 1 - progress;
    }
    dir = dir.opposite;
  }

  /// Moves [distance] tiles. [decide] is consulted on every cell centre and
  /// returns the direction to take from there; [onCellReached] fires each time
  /// a new cell centre is reached.
  void advance(
    double distance, {
    required Dir Function(Cell at, Dir current) decide,
    required bool Function(Cell cell) canEnter,
    void Function(Cell cell)? onCellReached,
  }) {
    var remaining = distance;
    var guard = 0;
    while (remaining > 1e-9 && guard++ < 8) {
      if (progress == 0) {
        dir = decide(cell, dir);
        if (dir == Dir.none || !canEnter(maze.wrap(cell.step(dir)))) {
          blocked = true;
          return;
        }
      }
      blocked = false;
      final step = remaining < 1 - progress ? remaining : 1 - progress;
      progress += step;
      remaining -= step;
      if (progress >= 1 - 1e-9) {
        cell = maze.wrap(cell.step(dir));
        progress = 0;
        onCellReached?.call(cell);
      }
    }
  }
}
