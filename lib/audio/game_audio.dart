// =============================================================================
// audio/game_audio.dart
//
// Música y efectos de sonido (reproductores reutilizables y vigilante de música).
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart'
    show
        AudioPlayer,
        AudioCache,
        AssetSource,
        PlayerState,
        ReleaseMode,
        AudioContext,
        AudioContextAndroid,
        AudioContextIOS,
        AndroidAudioFocus,
        AVAudioSessionOptions;
import 'dart:async';
import 'package:pacman_juego/data/player_profile.dart';

/// Grupo de reproductores para efectos de sonido, usados en rotación.
///
/// Cada efecto se lanza con `play()` en el siguiente reproductor del grupo, así
/// varios sonidos (incluso el mismo) pueden sonar a la vez sin cortarse. Se usa
/// el modo normal de reproducción (MediaPlayer en Android), que es el más
/// estable: el modo "baja latencia" (SoundPool) dejaba de sonar tras muchas
/// repeticiones en el APK. Si un reproductor falla, se reemplaza por uno nuevo y
/// se reintenta, para que el sonido nunca se quede "muerto".
class _VoicePool {
  _VoicePool(int size) {
    for (int i = 0; i < size; i++) {
      _players.add(AudioPlayer());
    }
  }

  final List<AudioPlayer> _players = [];
  int _next = 0;

  /// Reproduce [path] en el siguiente reproductor en rotación.
  void play(String path, double volume) {
    final index = _next;
    _next = (_next + 1) % _players.length;
    unawaited(_playOn(index, path, volume));
  }

  Future<void> _playOn(int index, String path, double volume) async {
    try {
      await _players[index]
          .play(AssetSource(path), volume: volume)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // El reproductor se atascó o falló: se cambia por uno nuevo y se reintenta.
      try {
        await _players[index].dispose();
      } catch (_) {}
      final fresh = AudioPlayer();
      _players[index] = fresh;
      try {
        await fresh.play(AssetSource(path), volume: volume);
      } catch (_) {}
    }
  }
}

/// Música y efectos de sonido del juego (paquete `audioplayers`).
///
/// - La música usa un reproductor propio por pista, en bucle, y un "vigilante"
///   ([ensureMusic]) que la reinicia si se detiene sin motivo.
/// - Los efectos usan [_VoicePool] (varios reproductores en rotación):
///   uno para las rimoras, uno para los sonidos de interfaz (clic y tecleo) y
///   uno para todos los demás.
/// - El contexto de audio de Android se configura SIN "foco de audio", para que
///   un efecto de sonido nunca pause ni corte la música.
///
/// Los archivos están en `assets/audio/`. Todas las llamadas están protegidas:
/// si el audio falla, el juego sigue funcionando.
class GameAudio {
  GameAudio._();

  /// `false` = todo en silencio (se cambia desde el menú de pausa).
  static bool enabled = true;

  static bool _ready = false;
  static Future<void>? _initFuture;
  static bool _starting = false;
  static bool _unlocked = false;

  /// `true` mientras el juego está en pausa (la música está pausada a propósito).
  static bool _pausedByGame = false;

  /// Música que DEBERÍA sonar ahora (null = ninguna).
  static String? _wanted;

  /// Música que realmente está sonando.
  static String? _current;

  static _VoicePool? _rimoraPool;
  static _VoicePool? _uiPool;
  static _VoicePool? _fxPool;
  static final Map<String, AudioPlayer> _music = {};

  static const double _musicVolume = 0.40;
  static const double _sfxVolume = 0.85;

  static const List<String> _sfxFiles = [
    'sfx_rimora.wav',
    'sfx_mydra.wav',
    'sfx_ghost_eaten.wav',
    'sfx_death.wav',
    'sfx_countdown.wav',
    'sfx_go.wav',
    'sfx_game_over.wav',
    'sfx_win.wav',
    'sfx_laser_warn.wav',
    'sfx_laser_on.wav',
    'sfx_wall.wav',
    'sfx_click.wav',
    'sfx_type.wav',
  ];

  static const List<String> _musicFiles = [
    'music_menu.wav',
    'music_game.wav',
    'music_panic.wav',
  ];

  /// Prepara todo el audio (solo corre una vez, aunque se llame varias).
  static Future<void> init() => _initFuture ??= _init();

  static Future<void> _init() async {
    try {
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
        iOS: AudioContextIOS(options: const {AVAudioSessionOptions.mixWithOthers}),
      ));
    } catch (e) {
      debugPrint('No se pudo configurar el contexto de audio: $e');
    }
    // Precarga los archivos en la caché para que el primer sonido sea inmediato.
    for (final file in [..._sfxFiles, ..._musicFiles]) {
      try {
        await AudioCache.instance.load('audio/$file');
      } catch (e) {
        debugPrint('No se pudo precargar $file: $e');
      }
    }
    _rimoraPool = _VoicePool(2);
    _uiPool = _VoicePool(3);
    _fxPool = _VoicePool(5);
    for (final file in _musicFiles) {
      try {
        final player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.loop);
        _music[file] = player;
      } catch (e) {
        debugPrint('No se pudo crear el reproductor de $file: $e');
      }
    }
    _ready = true;
    // Si se pidió música mientras cargaba, arranca ahora.
    final wanted = _wanted;
    if (wanted != null) await playMusic(wanted);
  }

  /// Reproduce un efecto de sonido. [volume] va de 0.0 a 1.0.
  static void sfx(String name, {double volume = 1.0}) {
    if (!enabled || !_ready) return;
    final _VoicePool? pool;
    if (name == 'sfx_rimora.wav') {
      pool = _rimoraPool;
    } else if (name == 'sfx_click.wav' || name == 'sfx_type.wav') {
      pool = _uiPool;
    } else {
      pool = _fxPool;
    }
    pool?.play('audio/$name', _sfxVolume * volume);
  }

  /// Empieza (o cambia a) la música [name] en bucle.
  static Future<void> playMusic(String name) async {
    _wanted = name;
    if (!enabled || !_ready || _starting) return;
    if (_current == name) return; // Ya está sonando.
    _starting = true;
    try {
      final previous = _current;
      if (previous != null) await _music[previous]?.stop();
      final player = _music[name];
      if (player == null) return;
      await player
          .play(AssetSource('audio/$name'), volume: _musicVolume)
          .timeout(const Duration(seconds: 3));
      _current = name;
      // Si mientras arrancaba se pidió detener o cambiar la música, se corrige.
      if (_wanted != name) {
        _current = null;
        await player.stop();
      }
    } catch (e) {
      debugPrint('No se pudo reproducir la música: $e');
    } finally {
      _starting = false;
    }
    final wanted = _wanted;
    if (wanted != null && wanted != name && wanted != _current && enabled) {
      await playMusic(wanted);
    }
  }

  /// Detiene la música que esté sonando.
  static Future<void> stopMusic() async {
    final playing = _current;
    _wanted = null;
    _current = null;
    _pausedByGame = false;
    if (playing != null) {
      try {
        await _music[playing]?.stop();
      } catch (_) {}
    }
  }

  /// Pausa la música (al pausar el juego).
  static Future<void> pauseMusic() async {
    _pausedByGame = true;
    final playing = _current;
    if (playing == null) return;
    try {
      await _music[playing]?.pause();
    } catch (_) {}
  }

  /// Reanuda la música al salir de la pausa.
  static Future<void> resumeMusic() async {
    _pausedByGame = false;
    final wanted = _wanted;
    if (wanted == null || !enabled || !_ready) return;
    if (_current == wanted) {
      try {
        await _music[wanted]?.resume();
      } catch (_) {
        _current = null;
        await playMusic(wanted);
      }
    } else {
      await playMusic(wanted);
    }
  }

  /// Vigilante: si la música debería estar sonando pero se detuvo (por una
  /// interrupción del sistema, por ejemplo), la reinicia. El juego lo llama
  /// cada pocos segundos.
  static void ensureMusic() {
    final wanted = _wanted;
    if (wanted == null || !enabled || !_ready || _starting || _pausedByGame) {
      return;
    }
    final player = _music[wanted];
    if (player == null) return;
    if (_current != wanted || player.state != PlayerState.playing) {
      _current = null;
      unawaited(playMusic(wanted));
    }
  }

  /// Activa o desactiva todo el sonido y guarda la preferencia.
  static Future<void> setEnabled(bool value) async {
    enabled = value;
    unawaited(ProfileStore.saveSound(value));
    if (!value) {
      final playing = _current;
      _current = null;
      if (playing != null) {
        try {
          await _music[playing]?.stop();
        } catch (_) {}
      }
    }
  }

  /// Se llama con el primer toque del usuario. Los navegadores bloquean el
  /// audio hasta entonces, así que se reinicia la música pedida.
  static void unlock() {
    if (_unlocked) return;
    _unlocked = true;
    if (!kIsWeb) return;
    final wanted = _wanted;
    if (wanted != null && enabled && _ready) {
      _current = null;
      unawaited(playMusic(wanted));
    }
  }
}
