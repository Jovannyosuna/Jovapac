import 'package:flutter_test/flutter_test.dart';
import 'package:pacman_juego/game/core/grid.dart';
import 'package:pacman_juego/game/levels.dart';
import 'package:pacman_juego/game/maze/maze.dart';
import 'package:pacman_juego/game/maze/maze_layouts.dart';

void main() {
  final layouts = {for (final level in campaign) level.layout};

  for (final layout in layouts) {
    group('Maze "${layout.name}"', () {
      final maze = Maze.fromLayout(layout);

      test('has the shared 19x16 footprint', () {
        expect(maze.cols, 19);
        expect(maze.rows, 16);
      });

      test('every collectible is reachable by the player', () {
        final reachable = maze.reachableFromStart();
        for (var i = 0; i < maze.initialPellets.length; i++) {
          if (maze.initialPellets[i] == Pellet.none) continue;
          final cell = Cell(i % maze.cols, i ~/ maze.cols);
          expect(reachable, contains(cell), reason: '$cell unreachable');
        }
      });

      test('has no dead ends for the player', () {
        for (final cell in maze.reachableFromStart()) {
          final exits = Dir.moves
              .where((d) => maze.canPlayerEnter(maze.wrap(cell.step(d))))
              .length;
          expect(exits, greaterThanOrEqualTo(2), reason: '$cell is a dead end');
        }
      });

      test('ghosts can leave from every house slot and return home', () {
        for (final slot in maze.houseSlots) {
          expect(maze.isHouseOrDoor(slot), isTrue);
          var cell = slot;
          for (var i = 0; i < 20 && cell != maze.houseExit; i++) {
            cell = maze.wrap(cell.step(maze.stepTowardExit(cell)));
          }
          expect(cell, maze.houseExit);
        }
        var cell = maze.playerStart;
        for (var i = 0; i < 80 && cell != maze.houseSlots.first; i++) {
          cell = maze.wrap(cell.step(maze.stepTowardHome(cell)));
        }
        expect(cell, maze.houseSlots.first);
      });

      test('the player cannot enter the ghost house', () {
        for (final slot in maze.houseSlots) {
          expect(maze.canPlayerEnter(slot), isFalse);
        }
      });
    });
  }

  test('side tunnels wrap around', () {
    final maze = Maze.fromLayout(classicLayout);
    expect(maze.wrap(const Cell(-1, 7)), const Cell(18, 7));
    expect(maze.wrap(const Cell(19, 7)), const Cell(0, 7));
    expect(maze.canPlayerEnter(const Cell(-1, 7)), isTrue);
    expect(maze.isTunnel(const Cell(0, 7)), isTrue);
  });

  test('malformed layouts fail loudly', () {
    expect(
      () => Maze.fromLayout(const MazeLayout('bad', ['###', '#.', '###'])),
      throwsFormatException,
    );
  });
}
