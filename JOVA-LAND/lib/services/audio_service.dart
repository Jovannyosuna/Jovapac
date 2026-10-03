import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

enum Sfx {
  chompA('chomp_a.wav', 0.35, 3),
  chompB('chomp_b.wav', 0.35, 3),
  power('power.wav', 0.6, 1),
  eatGhost('eat_ghost.wav', 0.7, 2),
  death('death.wav', 0.7, 1),
  levelClear('level_clear.wav', 0.7, 1),
  gameOver('game_over.wav', 0.7, 1),
  victory('victory.wav', 0.7, 1),
  extraLife('extra_life.wav', 0.6, 1),
  bonus('bonus.wav', 0.6, 1),
  start('start.wav', 0.6, 1),
  select('select.wav', 0.45, 2);

  const Sfx(this.file, this.volume, this.voices);

  final String file;
  final double volume;

  /// Maximum simultaneous instances, so rapid triggers never pile up.
  final int voices;
}

abstract class GameAudio {
  ValueListenable<bool> get muted;
  void play(Sfx sfx);
  void startMusic();
  void stopMusic();
  void pauseMusic();
  void resumeMusic();
}

/// Pooled sound effects plus a single looping music track.
class AudioService implements GameAudio {
  AudioService({required bool muted, this.enabled = true})
      : muted = ValueNotifier(muted);

  /// When false nothing touches the platform audio plugins (tests).
  final bool enabled;

  static const _music = 'music_loop.wav';
  static const _musicVolume = 0.28;

  @override
  final ValueNotifier<bool> muted;

  final Map<Sfx, AudioPool> _pools = {};
  bool _musicPlaying = false;
  bool _musicStarted = false;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || !enabled) return;
    _initialized = true;
    try {
      FlameAudio.bgm.initialize();
      await FlameAudio.audioCache.loadAll([
        _music,
        for (final s in Sfx.values) s.file,
      ]);
      for (final sfx in Sfx.values) {
        _pools[sfx] = await FlameAudio.createPool(
          sfx.file,
          maxPlayers: sfx.voices,
        );
      }
    } catch (error) {
      debugPrint('Audio disabled: $error');
    }
  }

  void setMuted(bool value) {
    muted.value = value;
    if (value) {
      _guard(() => FlameAudio.bgm.pause());
    } else if (_musicPlaying) {
      _musicStarted ? resumeMusic() : startMusic();
    }
  }

  @override
  void play(Sfx sfx) {
    if (muted.value) return;
    final pool = _pools[sfx];
    if (pool == null) return;
    _guard(() => pool.start(volume: sfx.volume));
  }

  @override
  void startMusic() {
    _musicPlaying = true;
    if (muted.value) return;
    _musicStarted = true;
    _guard(() => FlameAudio.bgm.play(_music, volume: _musicVolume));
  }

  @override
  void stopMusic() {
    _musicPlaying = false;
    _musicStarted = false;
    _guard(() => FlameAudio.bgm.stop());
  }

  @override
  void pauseMusic() => _guard(() => FlameAudio.bgm.pause());

  @override
  void resumeMusic() {
    if (!_musicPlaying || muted.value) return;
    if (!_musicStarted) return startMusic();
    _guard(() => FlameAudio.bgm.resume());
  }

  void _guard(Future<void> Function() action) {
    if (!enabled) return;
    try {
      action().then<void>(
        (_) {},
        onError: (Object error) => debugPrint('Audio error: $error'),
      );
    } catch (error) {
      debugPrint('Audio error: $error');
    }
  }
}
