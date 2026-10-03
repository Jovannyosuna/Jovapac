import 'dart:ui';

import 'ai/ghost_brain.dart';
import 'maze/maze_layouts.dart';

/// Tuning for one level. Difficulty grows on several axes at once (ghost
/// count and personalities, release timing, chase pressure, fright duration,
/// maze) instead of only raising speed.
class LevelConfig {
  const LevelConfig({
    required this.number,
    required this.layout,
    required this.wallColor,
    required this.playerSpeed,
    required this.ghostSpeed,
    required this.frightSeconds,
    required this.modeSchedule,
    required this.ghosts,
    required this.releaseDelays,
    required this.bonusPoints,
    this.chaserRushes = false,
  });

  final int number;
  final MazeLayout layout;
  final Color wallColor;

  /// Speeds in tiles per second.
  final double playerSpeed;
  final double ghostSpeed;
  final double frightSeconds;

  /// Alternating scatter/chase durations in seconds, starting with scatter.
  /// After the last entry ghosts chase forever.
  final List<double> modeSchedule;
  final List<GhostPersonality> ghosts;
  final List<double> releaseDelays;
  final int bonusPoints;

  /// The chaser speeds up when few pellets remain.
  final bool chaserRushes;

  int get perfectBonus => 1000 * number;
}

const _fullSquad = [
  GhostPersonality.chaser,
  GhostPersonality.ambusher,
  GhostPersonality.flanker,
  GhostPersonality.shy,
];

const List<LevelConfig> campaign = [
  LevelConfig(
    number: 1,
    layout: classicLayout,
    wallColor: Color(0xFF7A6BFF),
    playerSpeed: 6.0,
    ghostSpeed: 4.6,
    frightSeconds: 7,
    modeSchedule: [7, 20, 7, 20, 5, 20, 5],
    ghosts: [GhostPersonality.chaser, GhostPersonality.ambusher, GhostPersonality.shy],
    releaseDelays: [0, 3, 7],
    bonusPoints: 300,
  ),
  LevelConfig(
    number: 2,
    layout: crossLayout,
    wallColor: Color(0xFF2FD3FF),
    playerSpeed: 6.2,
    ghostSpeed: 5.0,
    frightSeconds: 6,
    modeSchedule: [7, 20, 7, 22, 5, 22, 5],
    ghosts: _fullSquad,
    releaseDelays: [0, 2.5, 5.5, 9],
    bonusPoints: 500,
  ),
  LevelConfig(
    number: 3,
    layout: labyrinthLayout,
    wallColor: Color(0xFFFF4FD8),
    playerSpeed: 6.3,
    ghostSpeed: 5.3,
    frightSeconds: 5,
    modeSchedule: [6, 22, 6, 22, 5, 25, 4],
    ghosts: _fullSquad,
    releaseDelays: [0, 2, 4.5, 7.5],
    bonusPoints: 700,
    chaserRushes: true,
  ),
  LevelConfig(
    number: 4,
    layout: classicLayout,
    wallColor: Color(0xFF9DFF3C),
    playerSpeed: 6.4,
    ghostSpeed: 5.6,
    frightSeconds: 4,
    modeSchedule: [5, 24, 5, 24, 4, 28, 3],
    ghosts: _fullSquad,
    releaseDelays: [0, 1.8, 4, 6.5],
    bonusPoints: 1000,
    chaserRushes: true,
  ),
  LevelConfig(
    number: 5,
    layout: crossLayout,
    wallColor: Color(0xFFFF9A3C),
    playerSpeed: 6.5,
    ghostSpeed: 5.8,
    frightSeconds: 3.2,
    modeSchedule: [5, 26, 4, 26, 3, 30, 2],
    ghosts: _fullSquad,
    releaseDelays: [0, 1.5, 3.5, 5.5],
    bonusPoints: 1500,
    chaserRushes: true,
  ),
  LevelConfig(
    number: 6,
    layout: labyrinthLayout,
    wallColor: Color(0xFFFF4D5E),
    playerSpeed: 6.6,
    ghostSpeed: 6.0,
    frightSeconds: 2.5,
    modeSchedule: [4, 28, 4, 28, 3, 32, 2],
    ghosts: _fullSquad,
    releaseDelays: [0, 1.2, 3, 5],
    bonusPoints: 2000,
    chaserRushes: true,
  ),
];
