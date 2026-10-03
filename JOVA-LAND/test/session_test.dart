import 'package:flutter_test/flutter_test.dart';
import 'package:pacman_juego/game/game_session.dart';

void main() {
  test('awards an extra life every 10 000 points exactly once', () {
    final session = GameSession()..reset();
    expect(session.addPoints(9990), isFalse);
    expect(session.addPoints(10), isTrue);
    expect(session.lives.value, GameSession.startingLives + 1);
    expect(session.addPoints(500), isFalse);
    expect(session.addPoints(9500), isTrue);
  });

  test('high score follows the score and new records are detected', () {
    final session = GameSession(highScore: 500)..reset();
    session.addPoints(300);
    expect(session.highScore.value, 500);
    expect(session.isNewHighScore, isFalse);
    session.addPoints(300);
    expect(session.highScore.value, 600);
    expect(session.isNewHighScore, isTrue);
  });

  test('ghost chain doubles and caps', () {
    expect([for (var i = 0; i < 6; i++) GameSession.ghostPoints(i)],
        [200, 400, 800, 1600, 1600, 1600]);
  });

  test('reset leaves no residual state', () {
    final session = GameSession()..reset();
    session
      ..addPoints(12000)
      ..level.value = 4
      ..levelProgress.value = 0.5
      ..lives.value = 1
      ..showToast('x');
    session.reset();
    expect(session.score.value, 0);
    expect(session.level.value, 1);
    expect(session.levelProgress.value, 0);
    expect(session.lives.value, GameSession.startingLives);
    expect(session.toast.value, isNull);
    expect(session.highScore.value, 12000);
    expect(session.addPoints(9999), isFalse);
  });
}
