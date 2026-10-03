import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';

import '../app/theme.dart';
import '../services/audio_service.dart';
import 'ai/ghost_brain.dart';
import 'core/grid.dart';
import 'core/units.dart';
import 'effects/effects.dart';
import 'entities/bonus_item.dart';
import 'entities/ghost.dart';
import 'entities/pellet_layer.dart';
import 'entities/player.dart';
import 'game_session.dart';
import 'input/input_controller.dart';
import 'levels.dart';
import 'maze/maze.dart';
import 'maze/maze_component.dart';
import 'maze/maze_layouts.dart';

/// Owns the simulation and the phase machine:
///
///   ready -> playing -> (dying -> ready | gameOver)
///                    -> levelClear -> (ready | victory)
///   playing/ready <-> paused
///
/// Entities only animate themselves; all rules run from [_simulate] so the
/// order of movement, eating and collisions is deterministic.
class JovaGame extends FlameGame {
  JovaGame({
    required this.session,
    required this.audio,
    required this.onHighScore,
  }) : super(
          camera: CameraComponent.withFixedResolution(
            width: viewWidth,
            height: viewHeight,
          ),
        );

  static const int mazeCols = 19;
  static const int mazeRows = 16;
  static const double mazeWidth = mazeCols * kTile;
  static const double mazeHeight = mazeRows * kTile;
  static const double viewWidth = mazeWidth + kViewMargin * 2;
  static const double viewHeight = mazeHeight + kViewMargin * 2;

  static const double _collisionRadius = 0.62;
  static const double _frightWarning = 2;
  static const List<int> _bonusAtPellets = [70, 150];

  final GameSession session;
  final GameAudio audio;
  final void Function(int score) onHighScore;
  final InputController input = InputController();

  /// Disables screen shake for players who prefer reduced motion.
  bool reduceMotion = false;

  final GhostContext _ctx = GhostContext();
  final Map<MazeLayout, Maze> _mazes = {};

  late Maze maze;
  late LevelConfig level;
  late ModeSchedule _modes;
  late Random _random;

  late final MazeComponent _mazeView;
  late final PelletLayer _pellets;
  late final Player player;
  late final List<Ghost> _ghosts;
  late final BonusItem _bonus;
  late final ParticleField _particles;
  late final PopupLayer _popups;
  late final ScreenFlash _flash;
  late final TunnelShade _tunnels;
  late final AmbientMotes _motes;

  GamePhase _resumePhase = GamePhase.playing;
  double _phaseTime = 0;
  int _stage = 0;
  double _readyDuration = 2;
  double _hitStop = 0;
  Ghost? _hitStopGhost;
  double _frightLeft = 0;
  int _ghostChain = 0;
  int _pelletsEaten = 0;
  bool _lostLife = false;
  bool _chompToggle = false;
  double _shakeLeft = 0;
  double _shakeDuration = 1;
  double _shakeStrength = 0;
  final Random _shakeRandom = Random(11);

  GamePhase get phase => session.phase.value;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await images.loadAll(
        ['player.png', 'ghost_face.png', 'ghost_scared.png', 'burger.png']);

    camera.viewfinder
      ..anchor = Anchor.center
      ..position = Vector2(mazeWidth / 2, mazeHeight / 2);

    final firstMaze = _mazeFor(campaign.first.layout);
    _mazeView = MazeComponent();
    _motes = AmbientMotes(mazeWidth, mazeHeight);
    _pellets = PelletLayer(images.fromCache('burger.png'));
    _bonus = BonusItem();
    player = Player(images.fromCache('player.png'), firstMaze);
    _ghosts = List.generate(
      4,
      (i) => Ghost(
        images.fromCache('ghost_face.png'),
        images.fromCache('ghost_scared.png'),
        firstMaze,
        i,
      ),
    );
    _particles = ParticleField();
    _tunnels = TunnelShade();
    _popups = PopupLayer();
    _flash = ScreenFlash()..size = Vector2(mazeWidth, mazeHeight);

    await world.addAll([
      _mazeView,
      ClipComponent.rectangle(
        size: Vector2(mazeWidth, mazeHeight),
        priority: 1,
        children: [
          _motes,
          _pellets,
          _bonus,
          ..._ghosts,
          player,
          _particles,
          _tunnels,
        ],
      ),
      _popups,
      _flash,
    ]);

    startNewGame();
  }

  Maze _mazeFor(MazeLayout layout) =>
      _mazes.putIfAbsent(layout, () => Maze.fromLayout(layout));

  // ---------------------------------------------------------------------------
  // Public controls
  // ---------------------------------------------------------------------------

  void startNewGame() {
    audio.stopMusic();
    session.reset();
    _loadLevel(1, readyDuration: 2.3);
    audio.play(Sfx.start);
  }

  void togglePause() => phase == GamePhase.paused ? resume() : pause();

  void pause() {
    if (phase != GamePhase.playing && phase != GamePhase.ready) return;
    _resumePhase = phase;
    session.phase.value = GamePhase.paused;
    input.clear();
    audio.pauseMusic();
  }

  void resume() {
    if (phase != GamePhase.paused) return;
    session.phase.value = _resumePhase;
    audio.resumeMusic();
  }

  // ---------------------------------------------------------------------------
  // Level & phase management
  // ---------------------------------------------------------------------------

  void _loadLevel(int number, {required double readyDuration}) {
    level = campaign[number - 1];
    maze = _mazeFor(level.layout);
    session.level.value = number;
    session.lastLevel.value = null;

    _mazeView.build(maze, level.wallColor);
    _motes.tint = level.wallColor;
    _pellets.reset(maze);
    _tunnels.configure(
      [for (var r = 0; r < maze.rows; r++) if (maze.isTunnel(Cell(0, r))) r],
      kTile,
      mazeWidth,
    );
    _random = Random(number * 7919);
    _pelletsEaten = 0;
    _lostLife = false;
    _bonus.hide();
    _updateProgress();
    _resetActors();
    _readyDuration = readyDuration;
    _enterPhase(GamePhase.ready);
  }

  void _resetActors() {
    player.reset(maze);
    for (var i = 0; i < _ghosts.length; i++) {
      if (i < level.ghosts.length) {
        _ghosts[i].spawn(
          maze: maze,
          personality: level.ghosts[i],
          releaseDelay: level.releaseDelays[i],
        );
      } else {
        _ghosts[i].deactivate();
      }
    }
    _modes = ModeSchedule(level.modeSchedule);
    _frightLeft = 0;
    _ghostChain = 0;
    _hitStop = 0;
    _hitStopGhost = null;
    input.clear();
    _particles.clear();
    _popups.clear();
    _flash.clear();
    _mazeView.stopFlash();
  }

  void _enterPhase(GamePhase next) {
    session.phase.value = next;
    _phaseTime = 0;
    _stage = 0;
  }

  @override
  void update(double dt) {
    if (phase == GamePhase.paused) return;
    final step = min(dt, 1 / 30);
    super.update(step);
    _updateShake(step);

    if (_hitStop > 0) {
      _hitStop -= step;
      if (_hitStop <= 0) {
        _hitStopGhost?.hidden = false;
        _hitStopGhost = null;
      }
      return;
    }

    _phaseTime += step;
    switch (phase) {
      case GamePhase.ready:
        if (_phaseTime >= _readyDuration) {
          _enterPhase(GamePhase.playing);
          audio.startMusic();
        }
      case GamePhase.playing:
        _simulate(step);
      case GamePhase.dying:
        _updateDying();
      case GamePhase.levelClear:
        _updateLevelClear();
      case GamePhase.loading:
      case GamePhase.paused:
      case GamePhase.gameOver:
      case GamePhase.victory:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Simulation
  // ---------------------------------------------------------------------------

  void _simulate(double dt) {
    input.update(dt);
    final desired = input.desired;
    if (player.steer(desired)) input.consume(desired);
    final speed = level.playerSpeed * (_frightLeft > 0 ? 1.06 : 1);
    player.move(speed * dt, desired, onTurn: input.consume);

    _collect(player.mover.nearestCell);
    if (phase != GamePhase.playing) return;

    if (_frightLeft > 0) {
      _frightLeft -= dt;
      if (_frightLeft <= 0) {
        for (final g in _ghosts) {
          g.calm();
        }
      }
    } else if (_modes.update(dt)) {
      for (final g in _ghosts) {
        g.onModeChanged(_modes.mode);
      }
    }

    _prepareGhostContext();
    for (final g in _ghosts) {
      g.step(dt, _ctx);
    }

    _bonus.tick(dt);
    _checkBonus();
    _checkGhostCollisions();
  }

  void _prepareGhostContext() {
    Cell? chaser;
    for (final g in _ghosts) {
      if (g.active && g.personality == GhostPersonality.chaser) {
        chaser = g.mover.cell;
      }
    }
    _ctx
      ..maze = maze
      ..playerCell = player.mover.nearestCell
      ..playerDir = player.mover.dir
      ..chaserCell = chaser
      ..mode = _modes.mode
      ..baseSpeed = level.ghostSpeed
      ..chaserRush = level.chaserRushes && _pellets.remaining <= 25
      ..frightEnding = _frightLeft > 0 && _frightLeft < _frightWarning
      ..random = _random;
  }

  void _collect(Cell cell) {
    final pellet = _pellets.eat(cell);
    if (pellet == Pellet.none) return;
    _pelletsEaten++;
    final x = (cell.col + 0.5) * kTile, y = (cell.row + 0.5) * kTile;

    if (pellet == Pellet.normal) {
      _award(10);
      audio.play(_chompToggle ? Sfx.chompA : Sfx.chompB);
      _chompToggle = !_chompToggle;
      player.bump(0.45);
      _particles.burst(x, y,
          color: Palette.pellet, count: 3, speed: 34, size: 1.3, life: 0.22);
    } else {
      _award(50);
      audio.play(Sfx.power);
      player.bump();
      _particles.burst(x, y,
          color: Palette.orange, count: 18, speed: 95, size: 2.2, life: 0.6);
      _flash.trigger(Palette.fright, strength: 0.14, duration: 0.4);
      _frightLeft = level.frightSeconds;
      _ghostChain = 0;
      for (final g in _ghosts) {
        g.frighten();
      }
    }
    _updateProgress();

    if (_bonusAtPellets.contains(_pelletsEaten)) {
      _bonus.show(maze.playerStart, level.bonusPoints);
      session.showToast('¡MONEDA BONUS!');
    }
    if (_pellets.remaining == 0) _beginLevelClear();
  }

  void _checkBonus() {
    final cell = _bonus.cell;
    if (cell == null || player.mover.nearestCell != cell) return;
    final points = _bonus.points;
    _bonus.hide();
    _award(points);
    audio.play(Sfx.bonus);
    player.bump();
    final x = (cell.col + 0.5) * kTile, y = (cell.row + 0.5) * kTile;
    _particles.burst(x, y, color: Palette.gold, count: 16, speed: 80, life: 0.6);
    _popups.show('$points', x, y - 6, color: Palette.gold);
  }

  void _checkGhostCollisions() {
    final px = player.mover.x, py = player.mover.y;
    for (final g in _ghosts) {
      if (!g.active || g.hidden) continue;
      var dx = (g.mover.x - px).abs();
      if (dx > maze.cols / 2) dx = maze.cols - dx;
      final dy = g.mover.y - py;
      if (dx * dx + dy * dy > _collisionRadius * _collisionRadius) continue;
      if (g.isEdible) {
        _eatGhost(g);
      } else if (g.isDangerous) {
        _playerCaught();
        return;
      }
    }
  }

  void _eatGhost(Ghost ghost) {
    final points = GameSession.ghostPoints(_ghostChain++);
    _award(points);
    ghost.markEaten();
    audio.play(Sfx.eatGhost);
    _particles.burst(ghost.position.x, ghost.position.y,
        color: ghost.personality.color, count: 20, speed: 110, size: 2.4, life: 0.55);
    _popups.show('$points', ghost.position.x, ghost.position.y,
        color: const Color(0xFF9FD4FF), size: 10);
    _shake(2, 0.18);
    _hitStop = 0.42;
    _hitStopGhost = ghost..hidden = true;
  }

  void _award(int points) {
    if (!session.addPoints(points)) return;
    audio.play(Sfx.extraLife);
    session.showToast('¡VIDA EXTRA!');
    _flash.trigger(Palette.lime, strength: 0.12, duration: 0.5);
  }

  void _updateProgress() {
    final total = _pellets.total;
    session.levelProgress.value =
        total == 0 ? 1 : 1 - _pellets.remaining / total;
  }

  // ---------------------------------------------------------------------------
  // Death, level clear and end states
  // ---------------------------------------------------------------------------

  void _playerCaught() {
    _lostLife = true;
    input.clear();
    audio.stopMusic();
    _enterPhase(GamePhase.dying);
  }

  void _updateDying() {
    if (_stage == 0 && _phaseTime >= 0.6) {
      _stage = 1;
      for (final g in _ghosts) {
        g.hidden = true;
      }
      _bonus.hide();
      player.startDeath();
      audio.play(Sfx.death);
      _particles.burst(player.position.x, player.position.y,
          color: Palette.lime, count: 28, speed: 120, size: 2.4, life: 0.8);
      _flash.trigger(Palette.danger, strength: 0.18, duration: 0.45);
      _shake(4, 0.35);
      session.lives.value -= 1;
    }
    if (_stage == 1 && _phaseTime >= 2.5) {
      if (session.lives.value > 0) {
        _resetActors();
        _readyDuration = 1.5;
        _enterPhase(GamePhase.ready);
      } else {
        _finish(GamePhase.gameOver, Sfx.gameOver);
      }
    }
  }

  void _beginLevelClear() {
    _frightLeft = 0;
    for (final g in _ghosts) {
      g.calm();
    }
    _bonus.hide();
    audio.stopMusic();
    _enterPhase(GamePhase.levelClear);
  }

  void _updateLevelClear() {
    if (_stage == 0 && _phaseTime >= 0.5) {
      _stage = 1;
      for (final g in _ghosts) {
        g.hidden = true;
      }
      _mazeView.startFlash();
      audio.play(Sfx.levelClear);
    }
    if (_stage == 1 && _phaseTime >= 1.9) {
      _stage = 2;
      _mazeView.stopFlash();
      final bonus = _lostLife ? 0 : level.perfectBonus;
      if (bonus > 0) _award(bonus);
      session.lastLevel.value =
          LevelSummary(level: level.number, perfectBonus: bonus);
    }
    if (_stage == 2 && _phaseTime >= 4.4) {
      if (level.number >= campaign.length) {
        _finish(GamePhase.victory, Sfx.victory);
      } else {
        _loadLevel(level.number + 1, readyDuration: 1.8);
      }
    }
  }

  void _finish(GamePhase result, Sfx sound) {
    audio.stopMusic();
    audio.play(sound);
    onHighScore(session.score.value);
    _enterPhase(result);
  }

  // ---------------------------------------------------------------------------
  // Camera feedback
  // ---------------------------------------------------------------------------

  void _shake(double strength, double duration) {
    if (reduceMotion) return;
    _shakeStrength = strength;
    _shakeDuration = duration;
    _shakeLeft = duration;
  }

  void _updateShake(double dt) {
    var ox = 0.0, oy = 0.0;
    if (_shakeLeft > 0) {
      _shakeLeft -= dt;
      final falloff = max(0.0, _shakeLeft / _shakeDuration);
      final magnitude = _shakeStrength * falloff * falloff;
      ox = (_shakeRandom.nextDouble() * 2 - 1) * magnitude;
      oy = (_shakeRandom.nextDouble() * 2 - 1) * magnitude;
    }
    camera.viewfinder.position.setValues(mazeWidth / 2 + ox, mazeHeight / 2 + oy);
  }
}
