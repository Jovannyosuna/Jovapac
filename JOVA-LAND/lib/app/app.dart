import 'package:flutter/material.dart';

import '../services/audio_service.dart';
import '../services/save_data.dart';
import '../ui/screens/main_menu_screen.dart';
import 'app_scope.dart';
import 'theme.dart';

class JovaApp extends StatelessWidget {
  const JovaApp({super.key, required this.save, required this.audio});

  final SaveData save;
  final AudioService audio;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      save: save,
      audio: audio,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'JOVA-LAND',
        theme: buildTheme(),
        home: const MainMenuScreen(),
      ),
    );
  }
}
