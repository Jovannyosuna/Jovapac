// =============================================================================
// data/player_profile.dart
//
// Perfiles del jugador (nombre, récord, nivel) y su guardado en el dispositivo.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:pacman_juego/audio/game_audio.dart';

/// Perfil del jugador: nombre, mayor puntuación y nivel alcanzado.
///
/// Solo se guarda un número nuevo cuando rompe el anterior (no es progresivo).
/// Por ahora existe un solo nivel, así que [level] siempre vale 1.
class PlayerProfile {
  PlayerProfile({required this.name, this.highScore = 0, this.level = 1});

  /// Nombre del jugador (máx. 12 caracteres).
  String name;

  /// Mayor puntuación lograda.
  int highScore;

  /// Nivel más alto alcanzado.
  int level;

  Map<String, dynamic> toJson() =>
      {'name': name, 'highScore': highScore, 'level': level};

  /// Reconstruye un perfil desde JSON (null si los datos no son válidos).
  static PlayerProfile? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final score = json['highScore'];
    final level = json['level'];
    return PlayerProfile(
      name: name,
      highScore: score is int ? score : 0,
      level: level is int ? level : 1,
    );
  }
}

/// Perfil activo. Es `null` solo mientras no exista ningún perfil.
PlayerProfile? currentProfile;

/// Todos los perfiles creados en este dispositivo.
final List<PlayerProfile> allProfiles = [];

/// Nombre del jugador activo (vacío si todavía no hay perfil).
String get playerName => currentProfile?.name ?? '';

/// Lee y guarda los perfiles (y la preferencia de sonido) en el dispositivo
/// con `shared_preferences`, que funciona en Android, iOS y web.
class ProfileStore {
  ProfileStore._();

  static const String _kProfiles = 'profiles_json';
  static const String _kActive = 'active_profile';
  static const String _kSound = 'sound_enabled';
  // Claves de la versión anterior (un solo perfil); solo se usan para migrar.
  static const String _kOldName = 'profile_name';
  static const String _kOldScore = 'profile_high_score';
  static const String _kOldLevel = 'profile_level';

  /// Busca un perfil por nombre (sin distinguir mayúsculas).
  static PlayerProfile? find(String? name) {
    if (name == null) return null;
    final wanted = name.trim().toLowerCase();
    for (final p in allProfiles) {
      if (p.name.toLowerCase() == wanted) return p;
    }
    return null;
  }

  /// Carga todos los perfiles, el perfil activo y la preferencia de sonido. Se
  /// llama una vez en main(), antes de abrir la app.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      allProfiles.clear();
      final raw = prefs.getString(_kProfiles);
      if (raw != null) {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final item in list) {
            final profile = PlayerProfile.fromJson(item);
            if (profile != null) allProfiles.add(profile);
          }
        }
      }
      // Migración: el perfil único de la versión anterior pasa a la lista.
      final oldName = prefs.getString(_kOldName);
      if (allProfiles.isEmpty && oldName != null && oldName.trim().isNotEmpty) {
        allProfiles.add(PlayerProfile(
          name: oldName,
          highScore: prefs.getInt(_kOldScore) ?? 0,
          level: prefs.getInt(_kOldLevel) ?? 1,
        ));
      }
      currentProfile = find(prefs.getString(_kActive) ?? oldName) ??
          (allProfiles.isNotEmpty ? allProfiles.first : null);
      GameAudio.enabled = prefs.getBool(_kSound) ?? true;
      if (allProfiles.isNotEmpty) await _persistAll();
    } catch (e) {
      debugPrint('No se pudieron leer los perfiles: $e');
    }
  }

  /// Crea un perfil nuevo (todo en 0) y lo deja activo. Si ya existe uno con
  /// ese nombre, se abre ese perfil con sus datos (no se reinicia nada).
  static Future<PlayerProfile> createProfile(String name) async {
    var profile = find(name);
    if (profile == null) {
      profile = PlayerProfile(name: name.trim());
      allProfiles.add(profile);
    }
    currentProfile = profile;
    await _persistAll();
    return profile;
  }

  /// Cambia el perfil activo.
  static Future<void> selectProfile(PlayerProfile profile) async {
    currentProfile = profile;
    await _persistAll();
  }

  /// Borra un perfil. Si era el activo, pasa a ser el primero que quede.
  static Future<void> deleteProfile(PlayerProfile profile) async {
    allProfiles.remove(profile);
    if (identical(currentProfile, profile)) {
      currentProfile = allProfiles.isNotEmpty ? allProfiles.first : null;
    }
    await _persistAll();
  }

  /// Guarda los cambios de un perfil (récord, nivel).
  static Future<void> save(PlayerProfile profile) => _persistAll();

  static Future<void> _persistAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kProfiles, jsonEncode([for (final p in allProfiles) p.toJson()]));
      final active = currentProfile?.name;
      if (active != null) {
        await prefs.setString(_kActive, active);
      } else {
        await prefs.remove(_kActive);
      }
    } catch (e) {
      debugPrint('No se pudieron guardar los perfiles: $e');
    }
  }

  /// Guarda si el sonido está activado.
  static Future<void> saveSound(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSound, enabled);
    } catch (e) {
      debugPrint('No se pudo guardar la preferencia de sonido: $e');
    }
  }
}
