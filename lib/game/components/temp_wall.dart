// =============================================================================
// game/components/temp_wall.dart
//
// Pared temporal de cera colocada por Vespakron.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:pacman_juego/config/game_config.dart';
import 'package:pacman_juego/game/pacman_game.dart';
import 'package:pacman_juego/game/utils/geometry.dart';

/// Pared temporal colocada por Vespakron.
///
/// Ciclo de vida:
/// 1. **Aviso** ([AbilityConfig.builderWarningSeconds]): contorno naranja
///    parpadeante. Todavía se puede cruzar.
/// 2. **Sólida** ([AbilityConfig.builderDurationSeconds]): bloquea a Pac-Man y
///    a los fantasmas. Parpadea durante el último segundo.
/// 3. Desaparece.
///
/// Si alguien está sobre la casilla (o entrando) cuando termina el aviso, la
/// pared espera un momento para no atrapar a nadie dentro.
class TempWall extends PositionComponent with HasGameReference<PacManGame> {
  TempWall(this.col, this.row);

  /// Columna de la casilla que ocupa la pared.
  final int col;
  /// Fila de la casilla que ocupa la pared.
  final int row;

  /// `false` durante el aviso; `true` cuando ya bloquea el paso.
  bool _solid = false;
  /// Segundos transcurridos en la fase de aviso.
  double _warnTimer = 0.0;
  /// Segundos transcurridos en la fase sólida.
  double _solidTimer = 0.0;

  /// Fija el tamaño (una casilla) y la posición en píxeles.
  @override
  Future<void> onLoad() async {
    super.onLoad();
    size = Vector2(game.tileSize, game.tileSize);
    position = Vector2(
      game.mazeOffsetX + col * game.tileSize,
      24 + row * game.tileSize,
    );
  }

  /// Avanza el ciclo de vida: aviso -> sólida -> desaparece.
  @override
  void update(double dt) {
    super.update(dt);
    if (game.isFrozen) return;

    if (!_solid) {
      // Fase 1: aviso. Todavía no bloquea el paso.
      _warnTimer += dt;
      if (_warnTimer >= AbilityConfig.builderWarningSeconds) {
        // Si alguien está en la casilla, se retrasa 0.3 s para no atrapar a nadie
        // dentro de la pared.
        if (game.isTileOccupied(col, row)) {
          _warnTimer = AbilityConfig.builderWarningSeconds - 0.3; // Espera
        } else {
          // Fase 2: se registra en solidWalls, lo que hace que isWalkable() devuelva
          // false para esta casilla.
          _solid = true;
          game.solidWalls.add(tileKey(col, row));
        }
      }
    } else {
      // Fase 3: pasado el tiempo de duración, la pared se elimina.
      _solidTimer += dt;
      if (_solidTimer >= AbilityConfig.builderDurationSeconds) {
        removeFromParent();
      }
    }
  }

  /// Al eliminarse libera la casilla en los registros del juego (también ocurre
  /// al reiniciar la partida).
  @override
  void onRemove() {
    final key = tileKey(col, row);
    game.solidWalls.remove(key);
    if (game.tempWalls[key] == this) {
      game.tempWalls.remove(key);
    }
    super.onRemove();
  }

  /// Dibuja el aviso parpadeante o la pared sólida según la fase.
  @override
  void render(Canvas canvas) {
    final rect = size.toRect();

    if (!_solid) {
      // Parpadeo: alterna 6 veces por segundo entre dos niveles de opacidad.
      final blink = (_warnTimer * 6).floor().isEven;
      canvas.drawRect(
        rect.deflate(2),
        Paint()
          ..color = Colors.orangeAccent.withAlpha(blink ? 220 : 70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      return;
    }

    final left = AbilityConfig.builderDurationSeconds - _solidTimer;
    if (left < 1.0 && (left * 8).floor().isEven) return; // Parpadeo final

    canvas.drawRect(rect, Paint()..color = const Color(0xFF8A0F5E));
    canvas.drawRect(
      rect.deflate(3),
      Paint()
        ..color = Colors.pinkAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}
