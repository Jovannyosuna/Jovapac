// =============================================================================
// audio/game_audio.dart
//
// Música y efectos de sonido con el motor flutter_soloud (hilo de audio propio).
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart'
    show SoLoud, AudioSource, SoundHandle;
import 'dart:async';
import 'package:pacman_juego/data/player_profile.dart';

/// Música y efectos de sonido del juego, con el motor `flutter_soloud`.
///
/// Por qué este motor: está hecho para videojuegos. Mezcla todos los sonidos en
/// su propio hilo de audio (en C++), así que:
/// - Reproducir un efecto NO crea objetos ni reproductores nuevos: no hay
///   tirones ni basura que se acumule, por mucho que dure la partida.
/// - Muchos sonidos (incluso el mismo) pueden sonar a la vez sin cortarse.
/// - No usa el foco de audio de Android, así que nada pausa la música.
/// - El audio no depende de los cuadros por segundo: si el juego se ralentiza,
///   el sonido sigue en tiempo real.
///
/// Todos los sonidos se cargan en memoria una sola vez al iniciar. Todas las
/// llamadas están protegidas: si el audio falla, el juego sigue en silencio.
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

  /// Música que realmente está sonando y su "voz" en el motor.
  static String? _currentName;
  static SoundHandle? _musicHandle;

  /// Sonidos ya cargados en memoria, por nombre de archivo.
  static final Map<String, AudioSource> _sources = {};

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
    'sfx_wax.wav',
    'sfx_wax_set.wav',
    'sfx_wax_melt.wav',
    'sfx_freeze.wav',
    'sfx_thaw.wav',
    'sfx_ready.wav',
    'sfx_no_power.wav',
    'sfx_portal.wav',
    'sfx_gate.wav',
    'sfx_level_up.wav',
    'sfx_level_start.wav',
    'sfx_door.wav',
    'sfx_heart.wav',
    'sfx_click.wav',
    'sfx_type.wav',
  ];

  static const List<String> _musicFiles = [
    'music_menu.wav',
    'music_game.wav',
    'music_panic.wav',
  ];

  /// Inicia el motor y carga todos los sonidos (solo corre una vez, aunque se
  /// llame varias veces).
  static Future<void> init() => _initFuture ??= _init();

  static Future<void> _init() async {
    try {
      await SoLoud.instance.init();
    } catch (e) {
      debugPrint('No se pudo iniciar el motor de audio: $e');
      return; // Sin motor: el juego sigue en silencio.
    }
    for (final file in [..._sfxFiles, ..._musicFiles]) {
      try {
        _sources[file] = await SoLoud.instance.loadAsset('assets/audio/$file');
      } catch (e) {
        debugPrint('No se pudo cargar el sonido $file: $e');
      }
    }
    _ready = true;
    // Mensaje de diagnóstico: aparece en la consola de `flutter run`.
    debugPrint('Audio listo: ${_sources.length} de '
        '${_sfxFiles.length + _musicFiles.length} sonidos cargados.');
    // Si se pidió música mientras cargaba, arranca ahora.
    final wanted = _wanted;
    if (wanted != null) await playMusic(wanted);
  }

  /// Reproduce un efecto de sonido. [volume] va de 0.0 a 1.0.
  static void sfx(String name, {double volume = 1.0}) {
    if (!enabled || !_ready) return;
    final source = _sources[name];
    if (source == null) return;
    try {
      // play() devuelve la "voz" al instante (no es un Future): no se espera.
      SoLoud.instance.play(source, volume: _sfxVolume * volume);
    } catch (_) {}
  }

  /// Detiene la "voz" de la música que esté sonando.
  static Future<void> _stopMusicVoice() async {
    final handle = _musicHandle;
    _musicHandle = null;
    _currentName = null;
    if (handle != null) {
      try {
        await SoLoud.instance.stop(handle);
      } catch (_) {}
    }
  }

  /// Empieza (o cambia a) la música [name] en bucle.
  static Future<void> playMusic(String name) async {
    _wanted = name;
    if (!enabled || !_ready || _starting) return;
    if (_currentName == name && _musicHandle != null) return; // Ya suena.
    _starting = true;
    try {
      await _stopMusicVoice();
      final source = _sources[name];
      if (source == null) return;
      final handle =
          SoLoud.instance.play(source, volume: _musicVolume, looping: true);
      _musicHandle = handle;
      _currentName = name;
      // Si mientras arrancaba se pidió detener o cambiar la música, se corrige.
      if (_wanted != name) await _stopMusicVoice();
    } catch (e) {
      debugPrint('No se pudo reproducir la música: $e');
    } finally {
      _starting = false;
    }
    final wanted = _wanted;
    if (wanted != null && wanted != name && wanted != _currentName && enabled) {
      await playMusic(wanted);
    }
  }

  /// Detiene la música.
  static Future<void> stopMusic() async {
    _wanted = null;
    _pausedByGame = false;
    await _stopMusicVoice();
  }

  /// Pausa la música (al pausar el juego).
  static Future<void> pauseMusic() async {
    _pausedByGame = true;
    final handle = _musicHandle;
    if (handle == null) return;
    try {
      SoLoud.instance.setPause(handle, true);
    } catch (_) {}
  }

  /// Reanuda la música al salir de la pausa.
  static Future<void> resumeMusic() async {
    _pausedByGame = false;
    final wanted = _wanted;
    if (wanted == null || !enabled || !_ready) return;
    final handle = _musicHandle;
    if (_currentName == wanted && handle != null) {
      try {
        SoLoud.instance.setPause(handle, false);
        return;
      } catch (_) {}
    }
    _musicHandle = null;
    _currentName = null;
    await playMusic(wanted);
  }

  /// Vigilante: si la música debería estar sonando pero se detuvo (por una
  /// interrupción del sistema, por ejemplo), la reinicia. El juego lo llama
  /// cada pocos segundos.
  static void ensureMusic() {
    final wanted = _wanted;
    if (wanted == null || !enabled || !_ready || _starting || _pausedByGame) {
      return;
    }
    var healthy = false;
    try {
      final handle = _musicHandle;
      healthy = handle != null &&
          _currentName == wanted &&
          SoLoud.instance.getIsValidVoiceHandle(handle) &&
          !SoLoud.instance.getPause(handle);
    } catch (_) {}
    if (!healthy) {
      _musicHandle = null;
      _currentName = null;
      unawaited(playMusic(wanted));
    }
  }

  /// Activa o desactiva todo el sonido y guarda la preferencia.
  static Future<void> setEnabled(bool value) async {
    enabled = value;
    unawaited(ProfileStore.saveSound(value));
    if (!value) await _stopMusicVoice();
  }

  /// Se llama con el primer toque del usuario. Los navegadores bloquean el
  /// audio hasta entonces, así que se reinicia la música pedida.
  static void unlock() {
    if (_unlocked) return;
    _unlocked = true;
    if (!kIsWeb) return;
    final wanted = _wanted;
    if (wanted != null && enabled && _ready) {
      _musicHandle = null;
      _currentName = null;
      unawaited(playMusic(wanted));
    }
  }
}
