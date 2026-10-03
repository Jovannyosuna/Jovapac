import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../app/theme.dart';
import '../core/grid.dart';
import '../core/units.dart';
import 'maze.dart';

/// Draws the maze floor and neon walls. The artwork is recorded once per
/// level into an image, so a frame costs a single `drawImageRect`.
class MazeComponent extends PositionComponent {
  MazeComponent() : super(priority: 0);

  static const double _rasterScale = 3;
  static const double _inset = 6;
  static const double _radius = 5;

  ui.Image? _image;
  Rect _srcRect = Rect.zero;
  Rect _dstRect = Rect.zero;
  double _flashTime = -1;
  final Paint _imagePaint = Paint()..filterQuality = FilterQuality.medium;
  final Paint _flashPaint = Paint()
    ..filterQuality = FilterQuality.medium
    ..colorFilter = const ColorFilter.mode(Color(0xFFFFFFFF), BlendMode.srcIn);

  void build(Maze maze, Color wallColor) {
    size = Vector2(maze.cols * kTile, maze.rows * kTile);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_rasterScale);
    _paintFloor(canvas, maze, wallColor);
    _paintWalls(canvas, maze, wallColor);
    _paintDoor(canvas, maze, wallColor);
    final picture = recorder.endRecording();
    _image?.dispose();
    _image = picture.toImageSync(
      (size.x * _rasterScale).ceil(),
      (size.y * _rasterScale).ceil(),
    );
    picture.dispose();
    _srcRect = Rect.fromLTWH(
      0, 0, _image!.width.toDouble(), _image!.height.toDouble());
    _dstRect = Rect.fromLTWH(0, 0, size.x, size.y);
    _flashTime = -1;
  }

  /// Blinks the walls for the level-clear sequence.
  void startFlash() => _flashTime = 0;

  void stopFlash() => _flashTime = -1;

  @override
  void update(double dt) {
    if (_flashTime >= 0) _flashTime += dt;
  }

  @override
  void render(Canvas canvas) {
    final image = _image;
    if (image == null) return;
    final flashing = _flashTime >= 0 && (_flashTime * 4).floor().isOdd;
    canvas.drawImageRect(
        image, _srcRect, _dstRect, flashing ? _flashPaint : _imagePaint);
  }

  @override
  void onRemove() {
    _image?.dispose();
    _image = null;
    super.onRemove();
  }

  void _paintFloor(Canvas canvas, Maze maze, Color wallColor) {
    final bounds = Offset.zero & Size(size.x, size.y);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds, const Radius.circular(10)),
      Paint()
        ..shader = ui.Gradient.radial(
          bounds.center,
          bounds.longestSide * 0.7,
          [Color.lerp(Palette.floor, wallColor, 0.07)!, Palette.floor],
        ),
    );

    final grid = Paint()..color = wallColor.withValues(alpha: 0.05);
    for (var r = 0; r < maze.rows; r++) {
      for (var c = 0; c < maze.cols; c++) {
        final cell = Cell(c, r);
        if (!maze.isWall(cell)) {
          canvas.drawCircle(
              Offset((c + 0.5) * kTile, (r + 0.5) * kTile), 0.8, grid);
        }
        if (maze.tileAt(cell) == Tile.house) {
          canvas.drawRect(
            Rect.fromLTWH(c * kTile, r * kTile, kTile, kTile),
            Paint()..color = wallColor.withValues(alpha: 0.05),
          );
        }
      }
    }
  }

  bool _wallForRender(Maze maze, int c, int r) {
    if (r < 0 || r >= maze.rows) return true;
    return maze.isWall(Cell(c.clamp(0, maze.cols - 1), r));
  }

  /// Traces the boundary between wall and open cells, inset into the wall,
  /// with rounded convex corners and mitred concave ones.
  void _paintWalls(Canvas canvas, Maze maze, Color wallColor) {
    final path = Path();
    const i = _inset;
    const rad = _radius;
    bool w(int c, int r) => _wallForRender(maze, c, r);

    for (var r = 0; r < maze.rows; r++) {
      for (var c = 0; c < maze.cols; c++) {
        if (!w(c, r)) continue;
        final l = c * kTile, t = r * kTile, rt = l + kTile, b = t + kTile;
        final upOpen = !w(c, r - 1), downOpen = !w(c, r + 1);
        final leftOpen = !w(c - 1, r), rightOpen = !w(c + 1, r);

        double hStart(int diagRow) => !w(c - 1, r)
            ? l + i + rad
            : (w(c - 1, diagRow) ? l - i : l);
        double hEnd(int diagRow) => !w(c + 1, r)
            ? rt - i - rad
            : (w(c + 1, diagRow) ? rt + i : rt);
        double vStart(int diagCol) => !w(c, r - 1)
            ? t + i + rad
            : (w(diagCol, r - 1) ? t - i : t);
        double vEnd(int diagCol) => !w(c, r + 1)
            ? b - i - rad
            : (w(diagCol, r + 1) ? b + i : b);

        if (upOpen) {
          final y = t + i;
          path
            ..moveTo(hStart(r - 1), y)
            ..lineTo(hEnd(r - 1), y);
          if (leftOpen) {
            path.addArc(
                Rect.fromLTWH(l + i, t + i, rad * 2, rad * 2), pi, pi / 2);
          }
          if (rightOpen) {
            path.addArc(Rect.fromLTWH(rt - i - rad * 2, t + i, rad * 2, rad * 2),
                -pi / 2, pi / 2);
          }
        }
        if (downOpen) {
          final y = b - i;
          path
            ..moveTo(hStart(r + 1), y)
            ..lineTo(hEnd(r + 1), y);
          if (leftOpen) {
            path.addArc(Rect.fromLTWH(l + i, b - i - rad * 2, rad * 2, rad * 2),
                pi / 2, pi / 2);
          }
          if (rightOpen) {
            path.addArc(
                Rect.fromLTWH(
                    rt - i - rad * 2, b - i - rad * 2, rad * 2, rad * 2),
                0,
                pi / 2);
          }
        }
        if (leftOpen) {
          final x = l + i;
          path
            ..moveTo(x, vStart(c - 1))
            ..lineTo(x, vEnd(c - 1));
        }
        if (rightOpen) {
          final x = rt - i;
          path
            ..moveTo(x, vStart(c + 1))
            ..lineTo(x, vEnd(c + 1));
        }
      }
    }

    _paintWallFill(canvas, maze, wallColor);
    canvas
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..color = wallColor.withValues(alpha: 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..color = wallColor,
      )
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(wallColor, const Color(0xFFFFFFFF), 0.65)!,
      );
  }

  /// Fills wall interiors exactly up to the outline. Each tile is split into
  /// quadrants so convex corners can be rounded and concave corners notched.
  void _paintWallFill(Canvas canvas, Maze maze, Color wallColor) {
    const i = _inset;
    const half = kTile / 2;
    final paint = Paint()..color = wallColor.withValues(alpha: 0.11);
    bool w(int c, int r) => _wallForRender(maze, c, r);

    for (var r = 0; r < maze.rows; r++) {
      for (var c = 0; c < maze.cols; c++) {
        if (!w(c, r)) continue;
        for (final (sx, sy) in const [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
          final horizontalOpen = !w(c + sx, r);
          final verticalOpen = !w(c, r + sy);
          final diagonalOpen = !w(c + sx, r + sy);
          final cx = (c + 0.5) * kTile, cy = (r + 0.5) * kTile;
          final outerX = cx + sx * (horizontalOpen ? half - i : half);
          final outerY = cy + sy * (verticalOpen ? half - i : half);
          final rect = Rect.fromPoints(Offset(cx, cy), Offset(outerX, outerY));

          if (horizontalOpen && verticalOpen) {
            final radius = const Radius.circular(_radius);
            canvas.drawRRect(
              RRect.fromRectAndCorners(
                rect,
                topLeft: sx < 0 && sy < 0 ? radius : Radius.zero,
                topRight: sx > 0 && sy < 0 ? radius : Radius.zero,
                bottomLeft: sx < 0 && sy > 0 ? radius : Radius.zero,
                bottomRight: sx > 0 && sy > 0 ? radius : Radius.zero,
              ),
              paint,
            );
          } else if (!horizontalOpen && !verticalOpen && diagonalOpen) {
            final notchX = outerX - sx * i, notchY = outerY - sy * i;
            canvas
              ..drawRect(
                  Rect.fromPoints(Offset(cx, cy), Offset(notchX, outerY)), paint)
              ..drawRect(
                  Rect.fromPoints(Offset(notchX, cy), Offset(outerX, notchY)),
                  paint);
          } else {
            canvas.drawRect(rect, paint);
          }
        }
      }
    }
  }

  void _paintDoor(Canvas canvas, Maze maze, Color wallColor) {
    final glow = Paint()
      ..color = Palette.orange.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final bar = Paint()..color = Palette.orange;
    for (var r = 0; r < maze.rows; r++) {
      for (var c = 0; c < maze.cols; c++) {
        if (maze.tileAt(Cell(c, r)) != Tile.door) continue;
        final rect = Rect.fromLTWH(c * kTile, (r + 0.5) * kTile - 1.5, kTile, 3);
        canvas
          ..drawRect(rect.inflate(1.5), glow)
          ..drawRect(rect, bar);
      }
    }
  }
}
