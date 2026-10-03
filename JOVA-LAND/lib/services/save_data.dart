import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent player data (high score and preferences).
class SaveData {
  SaveData._(this._prefs);

  static const _highScoreKey = 'high_score';
  static const _mutedKey = 'muted';

  final SharedPreferences? _prefs;

  static Future<SaveData> load() async {
    try {
      return SaveData._(await SharedPreferences.getInstance());
    } catch (error) {
      debugPrint('Persistent storage unavailable, using memory only: $error');
      return SaveData._(null);
    }
  }

  /// In-memory instance for tests.
  factory SaveData.memory() => SaveData._(null);

  int _memoryHighScore = 0;
  bool _memoryMuted = false;

  int get highScore => _prefs?.getInt(_highScoreKey) ?? _memoryHighScore;

  bool get muted => _prefs?.getBool(_mutedKey) ?? _memoryMuted;

  void saveHighScore(int value) {
    if (value <= highScore) return;
    _memoryHighScore = value;
    _prefs?.setInt(_highScoreKey, value);
  }

  void saveMuted(bool value) {
    _memoryMuted = value;
    _prefs?.setBool(_mutedKey, value);
  }
}
