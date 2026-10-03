import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pacman_juego/game/ai/ghost_brain.dart';
import 'package:pacman_juego/game/core/grid.dart';
import 'package:pacman_juego/game/levels.dart';
import 'package:pacman_juego/game/maze/maze.dart';
import 'package:pacman_juego/game/maze/maze_layouts.dart';

void main() {
  final maze = Maze.fromLayout(classicLayout);
  bool open(Cell c) => maze.canGhostEnter(c, throughDoor: false);

  test('never reverses at an intersection when other moves exist', () {
    final dir = chooseDirection(
      maze: maze,
      at: const Cell(4, 3),
      current: Dir.right,
      canEnter: open,
      target: const Cell(0, 3),
    );
    expect(dir, isNot(Dir.left));
  });

  test('picks the move that gets closest to the target', () {
    final dir = chooseDirection(
      maze: maze,
      at: const Cell(4, 3),
      current: Dir.right,
      canEnter: open,
      target: const Cell(4, 15),
    );
    expect(dir, Dir.down);
  });

  test('frightened choice is random but always legal', () {
    final random = Random(1);
    for (var i = 0; i < 50; i++) {
      final dir = chooseDirection(
        maze: maze,
        at: const Cell(4, 3),
        current: Dir.right,
        canEnter: open,
        random: random,
      );
      expect(open(maze.wrap(const Cell(4, 3).step(dir))), isTrue);
      expect(dir, isNot(Dir.left));
    }
  });

  test('personalities aim at different tiles', () {
    const player = Cell(9, 14);
    Cell target(GhostPersonality p, {Cell self = const Cell(1, 1)}) => chaseTarget(
          personality: p,
          maze: maze,
          self: self,
          player: player,
          playerDir: Dir.left,
          chaser: const Cell(12, 10),
        );
    expect(target(GhostPersonality.chaser), player);
    expect(target(GhostPersonality.ambusher), const Cell(5, 14));
    expect(target(GhostPersonality.flanker), const Cell(2, 18));
    expect(target(GhostPersonality.shy, self: const Cell(1, 1)), player);
    expect(target(GhostPersonality.shy, self: const Cell(9, 12)),
        scatterCorner(GhostPersonality.shy, maze));
  });

  test('mode schedule alternates scatter and chase, then chases forever', () {
    final schedule = ModeSchedule([2, 3, 1]);
    expect(schedule.mode, GhostMode.scatter);
    expect(schedule.update(1), isFalse);
    expect(schedule.update(1.01), isTrue);
    expect(schedule.mode, GhostMode.chase);
    expect(schedule.update(3.01), isTrue);
    expect(schedule.mode, GhostMode.scatter);
    expect(schedule.update(1.01), isTrue);
    expect(schedule.mode, GhostMode.chase);
    expect(schedule.update(100), isFalse);
    expect(schedule.mode, GhostMode.chase);

    final evenLength = ModeSchedule([1, 1]);
    evenLength
      ..update(1.01)
      ..update(1.01);
    expect(evenLength.mode, GhostMode.chase);
  });

  test('difficulty ramps on several axes, not only speed', () {
    for (var i = 1; i < campaign.length; i++) {
      final prev = campaign[i - 1], next = campaign[i];
      expect(next.ghostSpeed, greaterThan(prev.ghostSpeed));
      expect(next.frightSeconds, lessThan(prev.frightSeconds));
      expect(next.ghostSpeed / next.playerSpeed, lessThan(1));
      expect(next.releaseDelays.length, next.ghosts.length);
    }
    expect(campaign.first.ghosts.length, lessThan(campaign.last.ghosts.length));
  });
}
