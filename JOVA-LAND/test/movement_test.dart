import 'package:flutter_test/flutter_test.dart';
import 'package:pacman_juego/game/core/grid.dart';
import 'package:pacman_juego/game/entities/grid_mover.dart';
import 'package:pacman_juego/game/input/input_controller.dart';
import 'package:pacman_juego/game/maze/maze.dart';
import 'package:pacman_juego/game/maze/maze_layouts.dart';

void main() {
  final maze = Maze.fromLayout(classicLayout);

  GridMover moverAt(Cell cell) => GridMover(maze, cell);

  Dir keep(Cell _, Dir current) => current;

  test('stops at walls instead of passing through them', () {
    final mover = moverAt(const Cell(1, 3))..dir = Dir.left;
    mover.advance(3, decide: keep, canEnter: maze.canPlayerEnter);
    expect(mover.cell, const Cell(1, 3));
    expect(mover.blocked, isTrue);
    expect(mover.progress, 0);
  });

  test('reversing mid-tile keeps the exact position', () {
    final mover = moverAt(const Cell(2, 3))..dir = Dir.right;
    mover.advance(0.3, decide: keep, canEnter: maze.canPlayerEnter);
    final x = mover.x;
    mover.reverse();
    expect(mover.x, closeTo(x, 1e-9));
    expect(mover.dir, Dir.left);
    expect(mover.cell, const Cell(3, 3));
    expect(mover.progress, closeTo(0.7, 1e-9));
  });

  test('reversing never lands inside a wall', () {
    final mover = moverAt(const Cell(1, 3))..dir = Dir.right;
    mover.advance(0.5, decide: keep, canEnter: maze.canPlayerEnter);
    mover
      ..reverse()
      ..advance(5, decide: keep, canEnter: maze.canPlayerEnter);
    expect(maze.canPlayerEnter(mover.cell), isTrue);
    expect(mover.cell, const Cell(1, 3));
  });

  test('crosses several cells in one large step without skipping turns', () {
    final reached = <Cell>[];
    final mover = moverAt(const Cell(1, 3))..dir = Dir.right;
    mover.advance(3, decide: keep, canEnter: maze.canPlayerEnter, onCellReached: reached.add);
    expect(reached, const [Cell(2, 3), Cell(3, 3), Cell(4, 3)]);
  });

  test('wraps through the side tunnel', () {
    final mover = moverAt(const Cell(0, 7))..dir = Dir.left;
    mover.advance(1, decide: keep, canEnter: maze.canPlayerEnter);
    expect(mover.cell, const Cell(18, 7));
  });

  group('InputController', () {
    test('most recent held key wins and release falls back', () {
      final input = InputController()
        ..press(Dir.left)
        ..press(Dir.up);
      expect(input.desired, Dir.up);
      input.release(Dir.up);
      expect(input.desired, Dir.left);
    });

    test('a tapped key stays buffered briefly, then expires', () {
      final input = InputController()
        ..press(Dir.down)
        ..release(Dir.down);
      expect(input.desired, Dir.down);
      input.update(InputController.keyBuffer + 0.01);
      expect(input.desired, Dir.none);
    });

    test('consuming a buffered turn clears it', () {
      final input = InputController()..swipe(Dir.right);
      input.consume(Dir.right);
      expect(input.desired, Dir.none);
    });
  });
}
