import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacman_juego/app/app.dart';
import 'package:pacman_juego/services/audio_service.dart';
import 'package:pacman_juego/services/save_data.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(JovaApp(
      save: SaveData.memory(),
      audio: AudioService(muted: true, enabled: false),
    ));
    await tester.pump(const Duration(seconds: 1));
  }

  /// The game clamps each frame to 1/30 s, so advance with real 60 fps frames.
  Future<void> play(WidgetTester tester, double seconds) async {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      await tester.pump(const Duration(microseconds: 16667));
    }
  }

  testWidgets('main menu explains the game and offers play', (tester) async {
    await pumpApp(tester);
    expect(find.text('JUGAR'), findsOneWidget);
    expect(find.text('CÓMO JUGAR'), findsOneWidget);
    expect(find.text('SONIDO: NO'), findsOneWidget);
  });

  testWidgets('a full session: ready, eat, pause, restart, back to menu',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('JUGAR'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('PUNTOS'), findsOneWidget);
    expect(find.text('NIVEL 1'), findsOneWidget);
    expect(find.text('¡LISTO!'), findsOneWidget);

    await play(tester, 2.5);
    expect(find.text('¡LISTO!'), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await play(tester, 0.6);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    expect(find.text('30'), findsWidgets, reason: 'three pellets eaten');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await play(tester, 0.5);
    expect(find.text('PAUSA'), findsOneWidget);

    await tester.tap(find.text('REINICIAR'));
    await play(tester, 0.5);
    expect(find.text('PAUSA'), findsNothing);
    expect(find.text('¡LISTO!'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
    await play(tester, 0.5);
    await tester.tap(find.text('MENÚ PRINCIPAL'));
    await play(tester, 0.6);
    expect(find.text('JUGAR'), findsOneWidget);
  });
}
