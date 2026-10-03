import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../game/core/grid.dart';
import '../../game/game_session.dart';
import '../../game/jova_game.dart';
import '../hud/hud_bar.dart';
import '../overlays/banners.dart';
import '../overlays/end_overlay.dart';
import '../overlays/pause_overlay.dart';
import '../widgets/backdrop.dart';
import '../widgets/touch_dpad.dart';
import 'main_menu_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const double _swipeThreshold = 18;

  late final AppScope _scope = AppScope.read(context);
  late final GameSession _session =
      GameSession(highScore: _scope.save.highScore);
  late final JovaGame _game = JovaGame(
    session: _session,
    audio: _scope.audio,
    onHighScore: _scope.save.saveHighScore,
  );
  final FocusNode _focus = FocusNode(debugLabel: 'game');
  late final AppLifecycleListener _lifecycle;
  bool _touchMode = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  Offset _swipeAccum = Offset.zero;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onInactive: _game.pause,
      onHide: _game.pause,
    );
    _session.phase.addListener(_onPhaseChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game.reduceMotion = MediaQuery.disableAnimationsOf(context);
    precacheImage(const AssetImage('assets/images/game_over.png'), context);
  }

  @override
  void dispose() {
    _session.phase.removeListener(_onPhaseChanged);
    _lifecycle.dispose();
    _scope.save.saveHighScore(_session.highScore.value);
    _scope.audio.stopMusic();
    _focus.dispose();
    _session.dispose();
    super.dispose();
  }

  void _onPhaseChanged() {
    final phase = _session.phase.value;
    if (phase == GamePhase.playing || phase == GamePhase.ready) {
      _focus.requestFocus();
    }
  }

  bool get _modalOpen {
    final phase = _session.phase.value;
    return phase == GamePhase.paused ||
        phase == GamePhase.gameOver ||
        phase == GamePhase.victory;
  }

  static Dir? _dirForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) return Dir.up;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) return Dir.down;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) return Dir.left;
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) return Dir.right;
    return null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    final dir = _dirForKey(key);
    if (dir != null) {
      if (event is KeyUpEvent) {
        _game.input.release(dir);
        return _modalOpen ? KeyEventResult.ignored : KeyEventResult.handled;
      }
      if (_modalOpen) return KeyEventResult.ignored;
      if (event is KeyDownEvent) _game.input.press(dir);
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP) {
      _game.togglePause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyM) {
      _scope.toggleMute();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.touch && !_touchMode) {
      setState(() => _touchMode = true);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _swipeAccum += details.delta;
    if (_swipeAccum.distance < _swipeThreshold) return;
    final d = _swipeAccum;
    _game.input.swipe(d.dx.abs() > d.dy.abs()
        ? (d.dx > 0 ? Dir.right : Dir.left)
        : (d.dy > 0 ? Dir.down : Dir.up));
    _swipeAccum = Offset.zero;
  }

  void _restart() => _game.startNewGame();

  void _toMenu() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(fadeRoute(const MainMenuScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Listener(
          onPointerDown: _onPointerDown,
          child: Backdrop(
            child: Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      HudBar(
                        session: _session,
                        muted: _scope.audio.muted,
                        onPause: _game.pause,
                        onToggleMute: _scope.toggleMute,
                      ),
                      Expanded(child: _buildPlayfield()),
                    ],
                  ),
                ),
                Positioned.fill(child: _buildModal()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayfield() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (_) => _swipeAccum = Offset.zero,
              onPanUpdate: _onPanUpdate,
              child: GameWidget<JovaGame>(
                game: _game,
                autofocus: false,
                loadingBuilder: (_) => const Center(
                  child: CircularProgressIndicator(color: Palette.lime),
                ),
                errorBuilder: (_, error) => Center(
                  child: Text('No se pudo cargar el juego.\n$error',
                      textAlign: TextAlign.center, style: AppText.body()),
                ),
              ),
            ),
          ),
          Positioned.fill(child: ToastLayer(toast: _session.toast)),
          Positioned.fill(
            child: ValueListenableBuilder<GamePhase>(
              valueListenable: _session.phase,
              builder: (_, phase, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildBanner(phase),
              ),
            ),
          ),
          if (_touchMode)
            Positioned(
              left: 4,
              bottom: 4,
              child: Opacity(opacity: 0.85, child: TouchDpad(input: _game.input)),
            ),
        ],
      ),
    );
  }

  Widget _buildBanner(GamePhase phase) {
    if (phase == GamePhase.ready) {
      final level = _session.level.value;
      final firstLevel = level == 1 && _session.score.value == 0;
      return ReadyBanner(
        key: ValueKey('ready-$level-${_session.lives.value}'),
        level: level,
        mazeName: _game.level.layout.name,
        hint: firstLevel
            ? (_touchMode
                ? 'Desliza o usa la cruceta para moverte'
                : 'Flechas o WASD para moverte · Esc para pausar')
            : null,
      );
    }
    if (phase == GamePhase.levelClear) {
      return ValueListenableBuilder<LevelSummary?>(
        valueListenable: _session.lastLevel,
        builder: (_, summary, _) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: summary == null
              ? const SizedBox.shrink()
              : LevelClearBanner(key: ValueKey(summary.level), summary: summary),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildModal() {
    return ValueListenableBuilder<GamePhase>(
      valueListenable: _session.phase,
      builder: (_, phase, _) {
        final Widget child = switch (phase) {
          GamePhase.paused => PauseOverlay(
              key: const ValueKey('pause'),
              muted: _scope.audio.muted,
              onResume: _game.resume,
              onRestart: _restart,
              onToggleMute: _scope.toggleMute,
              onMenu: _toMenu,
            ),
          GamePhase.gameOver || GamePhase.victory => EndOverlay(
              key: ValueKey(phase),
              victory: phase == GamePhase.victory,
              score: _session.score.value,
              highScore: _session.highScore.value,
              level: _session.level.value,
              newRecord: _session.isNewHighScore,
              onPlayAgain: _restart,
              onMenu: _toMenu,
            ),
          _ => const SizedBox.shrink(key: ValueKey('none')),
        };
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: child,
        );
      },
    );
  }
}

PageRouteBuilder<void> fadeRoute(Widget page) => PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (_, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
