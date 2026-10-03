import 'package:flutter/foundation.dart';

/// Cardinal movement directions on the maze grid.
enum Dir {
  none(0, 0),
  up(0, -1),
  left(-1, 0),
  down(0, 1),
  right(1, 0);

  const Dir(this.dx, this.dy);

  final int dx;
  final int dy;

  /// Classic arcade tie-break order used when two moves are equally good.
  static const List<Dir> moves = [up, left, down, right];

  Dir get opposite => switch (this) {
        up => down,
        down => up,
        left => right,
        right => left,
        none => none,
      };

  bool isPerpendicularTo(Dir other) =>
      this != none && other != none && (dx == 0) != (other.dx == 0);
}

@immutable
class Cell {
  const Cell(this.col, this.row);

  final int col;
  final int row;

  Cell step(Dir dir, [int times = 1]) =>
      Cell(col + dir.dx * times, row + dir.dy * times);

  int distanceSquaredTo(Cell other) {
    final dc = col - other.col;
    final dr = row - other.row;
    return dc * dc + dr * dr;
  }

  @override
  bool operator ==(Object other) =>
      other is Cell && other.col == col && other.row == row;

  @override
  int get hashCode => col * 1000 + row;

  @override
  String toString() => 'Cell($col, $row)';
}
