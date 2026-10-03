import 'dart:math';
import 'dart:typed_data';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../app/theme.dart';

/// Fixed-capacity particle pool stored as flat arrays: emitting never
/// allocates, and dead slots are recycled.
class ParticleField extends Component {
  ParticleField() : super(priority: 6);

  static const int capacity = 220;

  final Float32List _x = Float32List(capacity);
  final Float32List _y = Float32List(capacity);
  final Float32List _vx = Float32List(capacity);
  final Float32List _vy = Float32List(capacity);
  final Float32List _life = Float32List(capacity);
  final Float32List _maxLife = Float32List(capacity);
  final Float32List _size = Float32List(capacity);
  final Int32List _color = Int32List(capacity);
  final Random _random = Random(7);
  final Paint _paint = Paint();
  int _cursor = 0;

  void burst(
    double x,
    double y, {
    required Color color,
    int count = 10,
    double speed = 60,
    double size = 2,
    double life = 0.45,
  }) {
    for (var n = 0; n < count; n++) {
      final i = _cursor;
      _cursor = (_cursor + 1) % capacity;
      final angle = _random.nextDouble() * pi * 2;
      final v = speed * (0.4 + _random.nextDouble() * 0.6);
      _x[i] = x;
      _y[i] = y;
      _vx[i] = cos(angle) * v;
      _vy[i] = sin(angle) * v;
      _maxLife[i] = life * (0.6 + _random.nextDouble() * 0.4);
      _life[i] = _maxLife[i];
      _size[i] = size * (0.6 + _random.nextDouble() * 0.6);
      _color[i] = color.toARGB32();
    }
  }

  void clear() => _life.fillRange(0, capacity, 0);

  @override
  void update(double dt) {
    final drag = pow(0.04, dt).toDouble();
    for (var i = 0; i < capacity; i++) {
      if (_life[i] <= 0) continue;
      _life[i] -= dt;
      _x[i] += _vx[i] * dt;
      _y[i] += _vy[i] * dt;
      _vx[i] *= drag;
      _vy[i] *= drag;
    }
  }

  @override
  void render(Canvas canvas) {
    for (var i = 0; i < capacity; i++) {
      final life = _life[i];
      if (life <= 0) continue;
      final t = life / _maxLife[i];
      _paint.color = Color(_color[i]).withValues(alpha: t);
      canvas.drawCircle(Offset(_x[i], _y[i]), _size[i] * (0.4 + 0.6 * t), _paint);
    }
  }
}

/// Floating score labels ("200", "+1000"). Text layouts are cached per string.
class PopupLayer extends Component {
  PopupLayer() : super(priority: 8);

  static const int capacity = 8;
  static const double duration = 0.9;

  final List<_Popup> _items = List.generate(capacity, (_) => _Popup());
  final Map<String, TextPainter> _cache = {};
  final Paint _layer = Paint();
  int _cursor = 0;

  void show(String text, double x, double y, {Color color = Palette.text, double size = 9}) {
    final item = _items[_cursor];
    _cursor = (_cursor + 1) % capacity;
    item
      ..painter = _painter(text, color, size)
      ..x = x
      ..y = y
      ..age = 0;
  }

  void clear() {
    for (final item in _items) {
      item.age = duration;
    }
  }

  TextPainter _painter(String text, Color color, double size) {
    final key = '$text|${color.toARGB32()}|$size';
    return _cache.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: Fonts.display,
            fontSize: size,
            color: color,
            shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  @override
  void update(double dt) {
    for (final item in _items) {
      if (item.age < duration) item.age += dt;
    }
  }

  @override
  void render(Canvas canvas) {
    for (final item in _items) {
      final painter = item.painter;
      if (painter == null || item.age >= duration) continue;
      final t = item.age / duration;
      final rise = 14 * (1 - pow(1 - t, 3));
      final pop = t < 0.15 ? 0.7 + 2 * t : 1.0;
      final alpha = t > 0.7 ? (1 - t) / 0.3 : 1.0;
      canvas
        ..save()
        ..translate(item.x, item.y - rise)
        ..scale(pop);
      canvas.saveLayer(null, _layer..color = Color.fromRGBO(0, 0, 0, alpha));
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      canvas
        ..restore()
        ..restore();
    }
  }
}

class _Popup {
  TextPainter? painter;
  double x = 0;
  double y = 0;
  double age = PopupLayer.duration;
}

/// Slow drifting motes over the maze floor for a bit of life and depth.
class AmbientMotes extends Component {
  AmbientMotes(this.width, this.height) : super(priority: 1);

  final double width;
  final double height;
  static const int count = 26;

  final Random _random = Random(3);
  late final Float32List _x = Float32List.fromList(
      List.generate(count, (_) => _random.nextDouble() * width));
  late final Float32List _y = Float32List.fromList(
      List.generate(count, (_) => _random.nextDouble() * height));
  late final Float32List _phase = Float32List.fromList(
      List.generate(count, (_) => _random.nextDouble() * pi * 2));
  final Paint _paint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
  Color tint = Palette.lime;
  double _time = 0;

  @override
  void update(double dt) {
    _time += dt;
    for (var i = 0; i < count; i++) {
      _y[i] -= dt * (3 + (i % 4));
      if (_y[i] < -4) {
        _y[i] = height + 4;
        _x[i] = _random.nextDouble() * width;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    for (var i = 0; i < count; i++) {
      final twinkle = 0.5 + 0.5 * sin(_time * 1.6 + _phase[i]);
      _paint.color = tint.withValues(alpha: 0.05 + 0.1 * twinkle);
      canvas.drawCircle(
        Offset(_x[i] + sin(_time * 0.7 + _phase[i]) * 4, _y[i]),
        1 + (i % 3) * 0.5,
        _paint,
      );
    }
  }
}

/// Full-maze color flash used sparingly for big moments.
class ScreenFlash extends PositionComponent {
  ScreenFlash() : super(priority: 9);

  final Paint _paint = Paint();
  Color _color = Palette.text;
  double _strength = 0;
  double _decay = 4;

  void trigger(Color color, {double strength = 0.25, double duration = 0.3}) {
    _color = color;
    _strength = strength;
    _decay = strength / duration;
  }

  void clear() => _strength = 0;

  @override
  void update(double dt) {
    if (_strength > 0) _strength = max(0, _strength - _decay * dt);
  }

  @override
  void render(Canvas canvas) {
    if (_strength <= 0) return;
    _paint.color = _color.withValues(alpha: _strength);
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(10)),
      _paint,
    );
  }
}

/// Fades actors out where the side tunnels leave the maze.
class TunnelShade extends PositionComponent {
  TunnelShade() : super(priority: 7);

  final List<Rect> _left = [];
  final List<Rect> _right = [];
  Paint _leftPaint = Paint();
  Paint _rightPaint = Paint();

  void configure(List<int> tunnelRows, double tile, double mazeWidth) {
    _left.clear();
    _right.clear();
    for (final r in tunnelRows) {
      _left.add(Rect.fromLTWH(0, r * tile, tile * 1.4, tile));
      _right.add(Rect.fromLTWH(mazeWidth - tile * 1.4, r * tile, tile * 1.4, tile));
    }
    _leftPaint = Paint()
      ..shader = LinearGradient(
        colors: [Palette.floor, Palette.floor.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(0, 0, tile * 1.4, 1));
    _rightPaint = Paint()
      ..shader = LinearGradient(
        colors: [Palette.floor.withValues(alpha: 0), Palette.floor],
      ).createShader(Rect.fromLTWH(mazeWidth - tile * 1.4, 0, tile * 1.4, 1));
  }

  @override
  void render(Canvas canvas) {
    for (final rect in _left) {
      canvas.drawRect(rect, _leftPaint);
    }
    for (final rect in _right) {
      canvas.drawRect(rect, _rightPaint);
    }
  }
}
