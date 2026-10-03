import '../core/grid.dart';

/// Turns raw key/touch events into the direction the player wants to take.
///
/// Held keys win (the most recent one), and a released key or a swipe stays
/// buffered for a short window so turns pressed slightly early still land at
/// the next intersection.
class InputController {
  static const double keyBuffer = 0.28;
  static const double swipeBuffer = 1.2;

  final List<Dir> _held = [];
  Dir _buffered = Dir.none;
  double _bufferLeft = 0;

  Dir get desired {
    if (_held.isNotEmpty) return _held.last;
    return _bufferLeft > 0 ? _buffered : Dir.none;
  }

  void press(Dir dir) {
    _held
      ..remove(dir)
      ..add(dir);
    _buffer(dir, keyBuffer);
  }

  void release(Dir dir) => _held.remove(dir);

  void swipe(Dir dir) => _buffer(dir, swipeBuffer);

  /// Called once the player actually turned toward [dir].
  void consume(Dir dir) {
    if (_buffered == dir) _bufferLeft = 0;
  }

  void update(double dt) {
    if (_bufferLeft > 0) _bufferLeft -= dt;
  }

  void clear() {
    _held.clear();
    _bufferLeft = 0;
    _buffered = Dir.none;
  }

  void _buffer(Dir dir, double seconds) {
    _buffered = dir;
    _bufferLeft = seconds;
  }
}
