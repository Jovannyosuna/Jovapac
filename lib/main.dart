// =============================================================================
// JOVA-LAND
// Videojuego de laberinto desarrollado con Flutter y el motor de juegos Flame.
//
// Autor:        Gabriel Jovanny Osuna Martínez
// Plataformas:  Web, Android, iOS (orientación horizontal en móviles)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:pacman_juego/audio/game_audio.dart';
import 'package:pacman_juego/data/player_profile.dart';
import 'package:pacman_juego/ui/screens/main_menu_screen.dart';

/// Punto de entrada de la aplicación.
///
/// En dispositivos móviles fuerza la orientación horizontal y activa el modo
/// de pantalla completa inmersivo. En web y escritorio no modifica nada.
void main() async {
  // Obligatorio antes de usar servicios de la plataforma (como la orientación)
  // cuando main() es asíncrono.
  WidgetsFlutterBinding.ensureInitialized();

  // Carga el perfil guardado (si existe) y la preferencia de sonido.
  await ProfileStore.init();
  // El audio se precarga en segundo plano para no retrasar la pantalla inicial.
  unawaited(GameAudio.init());

  // Solo en Android e iOS: en web y escritorio no se modifica la orientación.
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Pantalla completa: las barras del sistema se ocultan y reaparecen
    // temporalmente al deslizar desde el borde (modo "sticky").
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  runApp(const MyApp());
}

/// Widget raíz de la aplicación. Define el tema oscuro y la pantalla inicial.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Construye la app: sin banner de depuración, tema oscuro y el menú
  /// principal como pantalla inicial.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JOVA-LAND',
      theme: ThemeData.dark(),
      // Un toque en cualquier parte "desbloquea" el audio en los navegadores
      // (que no permiten reproducir sonido antes de la primera interacción).
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => GameAudio.unlock(),
        child: child,
      ),
      home: const MainMenuScreen(),
    );
  }
}
