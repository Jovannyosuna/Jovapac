import 'package:flutter/widgets.dart';

import '../services/audio_service.dart';
import '../services/save_data.dart';

/// App-wide services, created once at startup.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.save,
    required this.audio,
    required super.child,
  });

  final SaveData save;
  final AudioService audio;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above $context');
    return scope!;
  }

  /// Lookup without registering a dependency (safe in `initState`).
  static AppScope read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing above $context');
    return scope!;
  }

  void toggleMute() {
    final muted = !audio.muted.value;
    audio.setMuted(muted);
    save.saveMuted(muted);
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      save != oldWidget.save || audio != oldWidget.audio;
}
