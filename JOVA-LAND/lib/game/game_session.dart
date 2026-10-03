import 'package:flutter/foundation.dart';

enum GamePhase {
  loading,
  ready,
  playing,
  paused,
  dying,
  levelClear,
  gameOver,
  victory,
}

/// Short-lived message shown by the HUD (extra life, bonus, ...).
class HudToast {
  const HudToast(this.id, this.text);

  final int id;
  final String text;
}

class LevelSummary {
  const LevelSummary({required this.level, required this.perfectBonus});

  final int level;

  /// 0 when a life was lost during the level.
  final int perfectBonus;
}

/// Score, lives and progression state shared between the game and the UI.
/// Everything the Flutter layer displays is exposed as a [ValueListenable].
class GameSession {
  GameSession({int highScore = 0}) : highScore = ValueNotifier(highScore);

  static const int startingLives = 3;
  static const int extraLifeEvery = 10000;
  static const List<int> ghostChainPoints = [200, 400, 800, 1600];

  final ValueNotifier<int> score = ValueNotifier(0);
  final ValueNotifier<int> highScore;
  final ValueNotifier<int> lives = ValueNotifier(startingLives);
  final ValueNotifier<int> level = ValueNotifier(1);
  final ValueNotifier<double> levelProgress = ValueNotifier(0);
  final ValueNotifier<GamePhase> phase = ValueNotifier(GamePhase.loading);
  final ValueNotifier<HudToast?> toast = ValueNotifier(null);
  final ValueNotifier<LevelSummary?> lastLevel = ValueNotifier(null);

  int _startingHighScore = 0;
  int _nextExtraLife = extraLifeEvery;
  int _toastId = 0;

  bool get isNewHighScore => score.value > _startingHighScore;

  void reset() {
    _startingHighScore = highScore.value;
    score.value = 0;
    lives.value = startingLives;
    level.value = 1;
    levelProgress.value = 0;
    lastLevel.value = null;
    toast.value = null;
    _nextExtraLife = extraLifeEvery;
  }

  /// Adds points and returns true when an extra life was awarded.
  bool addPoints(int points) {
    score.value += points;
    if (score.value > highScore.value) highScore.value = score.value;
    if (score.value >= _nextExtraLife) {
      _nextExtraLife += extraLifeEvery;
      lives.value += 1;
      return true;
    }
    return false;
  }

  /// Points for the [index]-th ghost eaten during one power-up (0-based).
  static int ghostPoints(int index) =>
      ghostChainPoints[index.clamp(0, ghostChainPoints.length - 1)];

  void showToast(String text) => toast.value = HudToast(++_toastId, text);

  void dispose() {
    for (final n in <ChangeNotifier>[
      score, highScore, lives, level, levelProgress, phase, toast, lastLevel,
    ]) {
      n.dispose();
    }
  }
}
