import 'dart:collection';

import '../core/grid.dart';
import 'maze_layouts.dart';

enum Tile { wall, floor, tunnel, door, house }

enum Pellet { none, normal, power }

/// Immutable grid model of a maze: walkability, tunnels and the precomputed
/// distance fields ghosts use to leave and return to their house.
class Maze {
  Maze._(
    this._tiles, {
    required this.name,
    required this.cols,
    required this.rows,
    required List<Pellet> pellets,
    required this.playerStart,
    required this.houseSlots,
    required this.houseExit,
  }) : initialPellets = List.unmodifiable(pellets) {
    _exitField = _distanceField(houseExit);
    _homeField = _distanceField(houseSlots.first);
  }

  factory Maze.fromLayout(MazeLayout layout) {
    final rows = layout.rows.length;
    final cols = layout.rows.first.length;
    final tiles = List<Tile>.filled(cols * rows, Tile.wall);
    final pellets = List<Pellet>.filled(cols * rows, Pellet.none);
    Cell? start;
    final doors = <Cell>[];
    final house = <Cell>[];

    for (var r = 0; r < rows; r++) {
      final line = layout.rows[r];
      if (line.length != cols) {
        throw FormatException('Row $r of "${layout.name}" has ${line.length} '
            'columns, expected $cols.');
      }
      for (var c = 0; c < cols; c++) {
        final i = r * cols + c;
        switch (line[c]) {
          case '#':
            tiles[i] = Tile.wall;
          case '.':
            tiles[i] = Tile.floor;
            pellets[i] = Pellet.normal;
          case 'o':
            tiles[i] = Tile.floor;
            pellets[i] = Pellet.power;
          case ' ':
            tiles[i] = Tile.floor;
          case 't':
            tiles[i] = Tile.tunnel;
          case '-':
            tiles[i] = Tile.door;
            doors.add(Cell(c, r));
          case 'H':
            tiles[i] = Tile.house;
            house.add(Cell(c, r));
          case 'P':
            tiles[i] = Tile.floor;
            start = Cell(c, r);
          default:
            throw FormatException('Unknown tile "${line[c]}" in ${layout.name}.');
        }
      }
    }
    if (start == null || doors.isEmpty || house.isEmpty) {
      throw FormatException('"${layout.name}" needs P, a door and a house.');
    }

    final doorCol = (doors.map((d) => d.col).reduce((a, b) => a + b) /
            doors.length)
        .round();
    final doorRow = doors.first.row;
    final houseTop = house.map((h) => h.row).reduce((a, b) => a < b ? a : b);
    final houseBottom =
        house.map((h) => h.row).reduce((a, b) => a > b ? a : b);
    final slots = [
      Cell(doorCol, houseTop),
      Cell(doorCol - 2, houseBottom),
      Cell(doorCol, houseBottom),
      Cell(doorCol + 2, houseBottom),
    ];

    Cell? exit;
    for (final door in doors) {
      final above = Cell(door.col, doorRow - 1);
      if (tiles[above.row * cols + above.col] != Tile.wall &&
          (exit == null ||
              (above.col - doorCol).abs() < (exit.col - doorCol).abs())) {
        exit = above;
      }
    }
    if (exit == null) {
      throw FormatException('"${layout.name}" ghost door has no exit.');
    }

    return Maze._(
      tiles,
      name: layout.name,
      cols: cols,
      rows: rows,
      pellets: pellets,
      playerStart: start,
      houseSlots: slots,
      houseExit: exit,
    );
  }

  final String name;
  final int cols;
  final int rows;
  final List<Tile> _tiles;
  final List<Pellet> initialPellets;
  final Cell playerStart;
  final List<Cell> houseSlots;
  final Cell houseExit;

  late final List<int> _exitField;
  late final List<int> _homeField;

  int indexOf(Cell cell) => cell.row * cols + cell.col;

  /// Wraps horizontally so the side tunnels connect.
  Cell wrap(Cell cell) {
    if (cell.col >= 0 && cell.col < cols) return cell;
    return Cell(cell.col % cols, cell.row);
  }

  Tile tileAt(Cell cell) {
    if (cell.row < 0 || cell.row >= rows) return Tile.wall;
    return _tiles[indexOf(wrap(cell))];
  }

  bool isWall(Cell cell) => tileAt(cell) == Tile.wall;

  bool isTunnel(Cell cell) => tileAt(cell) == Tile.tunnel;

  bool isHouseOrDoor(Cell cell) {
    final t = tileAt(cell);
    return t == Tile.house || t == Tile.door;
  }

  bool canPlayerEnter(Cell cell) {
    final t = tileAt(cell);
    return t == Tile.floor || t == Tile.tunnel;
  }

  bool canGhostEnter(Cell cell, {required bool throughDoor}) {
    final t = tileAt(cell);
    if (t == Tile.wall) return false;
    if (t == Tile.door || t == Tile.house) return throughDoor;
    return true;
  }

  /// Best first step from [from] toward the house exit (ghosts leaving).
  Dir stepTowardExit(Cell from) => _descend(_exitField, from);

  /// Best first step from [from] toward the house (eaten ghosts returning).
  Dir stepTowardHome(Cell from) => _descend(_homeField, from);

  int distanceToHome(Cell from) => _homeField[indexOf(wrap(from))];

  Dir _descend(List<int> field, Cell from) {
    var best = Dir.none;
    var bestDistance = field[indexOf(wrap(from))];
    for (final dir in Dir.moves) {
      final next = wrap(from.step(dir));
      if (next.row < 0 || next.row >= rows) continue;
      final d = field[indexOf(next)];
      if (d >= 0 && (bestDistance < 0 || d < bestDistance)) {
        bestDistance = d;
        best = dir;
      }
    }
    return best;
  }

  List<int> _distanceField(Cell target) {
    final field = List<int>.filled(cols * rows, -1);
    final queue = Queue<Cell>()..add(target);
    field[indexOf(target)] = 0;
    while (queue.isNotEmpty) {
      final cell = queue.removeFirst();
      final d = field[indexOf(cell)];
      for (final dir in Dir.moves) {
        final next = wrap(cell.step(dir));
        if (!canGhostEnter(next, throughDoor: true)) continue;
        final i = indexOf(next);
        if (field[i] != -1) continue;
        field[i] = d + 1;
        queue.add(next);
      }
    }
    return field;
  }

  /// Cells reachable by the player from its start position.
  Set<Cell> reachableFromStart() {
    final seen = <Cell>{playerStart};
    final queue = Queue<Cell>()..add(playerStart);
    while (queue.isNotEmpty) {
      final cell = queue.removeFirst();
      for (final dir in Dir.moves) {
        final next = wrap(cell.step(dir));
        if (canPlayerEnter(next) && seen.add(next)) queue.add(next);
      }
    }
    return seen;
  }
}
