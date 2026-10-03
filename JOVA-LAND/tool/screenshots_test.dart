// Visual check: renders key screens at several viewport sizes into
// build/screenshots/. Run with: flutter test tool/screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pacman_juego/app/app.dart';
import 'package:pacman_juego/services/audio_service.dart';
import 'package:pacman_juego/services/save_data.dart';

const _sizes = {
  'desktop': Size(1280, 800),
  'phone_landscape': Size(844, 390),
  'phone_portrait': Size(390, 844),
  'ultrawide': Size(2000, 820),
};

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final file in files) {
      loader.addFont(Future.value(
          ByteData.sublistView(File(file).readAsBytesSync())));
    }
    await loader.load();
  }

  await family('PressStart2P', ['assets/fonts/PressStart2P-Regular.ttf']);
  await family('ChakraPetch', [
    'assets/fonts/ChakraPetch-Medium.ttf',
    'assets/fonts/ChakraPetch-SemiBold.ttf',
    'assets/fonts/ChakraPetch-Bold.ttf',
  ]);
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? r'C:\src\flutter';
  await family('MaterialIcons', [
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
}

void main() {
  setUpAll(_loadFonts);
  final boundary = GlobalKey();

  Future<void> capture(WidgetTester tester, String name) async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await render.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    final file = File('build/screenshots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!);
    debugPrint('wrote ${file.path}');
  }

  Future<void> frames(WidgetTester tester, double seconds) async {
    for (var i = 0; i < (seconds * 60).round(); i++) {
      await tester.pump(const Duration(microseconds: 16667));
    }
  }

  Future<void> settleAssets(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  for (final MapEntry(key: label, value: size) in _sizes.entries) {
    testWidgets('screens at $label', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: JovaApp(
          save: SaveData.memory(),
          audio: AudioService(muted: false, enabled: false),
        ),
      ));
      await settleAssets(tester);
      await frames(tester, 1);
      await capture(tester, '${label}_1_menu');

      await tester.tap(find.text('JUGAR'));
      await settleAssets(tester);
      await frames(tester, 0.8);
      await capture(tester, '${label}_2_ready');

      await frames(tester, 2);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await frames(tester, 0.4);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowUp);
      await frames(tester, 2.2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowUp);
      await capture(tester, '${label}_3_play');

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(tester, 0.6);
      await capture(tester, '${label}_4_pause');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(tester, 0.3);

      for (var i = 0; i < 240 && find.text('JUGAR DE NUEVO').evaluate().isEmpty; i++) {
        await frames(tester, 0.5);
      }
      await frames(tester, 1.2);
      await capture(tester, '${label}_5_game_over');
    }, timeout: const Timeout(Duration(minutes: 4)));
  }
}
