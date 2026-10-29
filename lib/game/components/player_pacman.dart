// =============================================================================
// game/components/player_pacman.dart
//
// Entidad jugador (Vance): movimiento, giros anticipados y recolección.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'dart:math';
import 'package:pacman_juego/audio/game_audio.dart';
import 'package:pacman_juego/config/game_config.dart';
import 'package:pacman_juego/data/player_profile.dart';
import 'package:pacman_juego/game/components/entity_label.dart';
import 'package:pacman_juego/game/pacman_game.dart';
import 'package:pacman_juego/game/utils/game_sprite.dart';
import 'package:pacman_juego/game/utils/geometry.dart';

/// Personaje controlado por el jugador.
///
/// Se mueve casilla por casilla: [moveProgress] va de 0.0 a 1.0 mientras
/// avanza hacia la siguiente casilla. La dirección solicitada ([nextDir]) se
/// guarda y se aplica en cuanto el camino queda libre, lo que permite
/// anticipar giros.
class PlayerPacman extends PositionComponent with HasGameReference<PacManGame> {
  /// Sprite del personaje. Si es nulo se dibuja un círculo amarillo.
  GameSprite? sprite;

  /// Posición actual en coordenadas de la cuadrícula (columna, fila).
  Vector2 gridPos;

  /// Dirección de movimiento actual.
  Vector2 moveDir = Vector2.zero();

  /// Dirección solicitada por el jugador, pendiente de aplicarse.
  Vector2 nextDir = Vector2.zero();

  /// Última dirección en la que se movió (la usan Vespakron e Kyros para apuntar).
  /// Se conserva aunque Pac-Man esté detenido.
  Vector2 facing = Vector2(-1, 0);

  /// Avance hacia la siguiente casilla (0.0 a 1.0).
  double moveProgress = 0.0;

  /// Velocidad actual en casillas por segundo.
  ///
  /// Sube durante el modo Frightened. En los túneles se aplica
  /// [GameSpeeds.tunnelFactor], que ahora vale 1.0 (velocidad normal).
  double get speed {
    final percent = game.modeController.isFrightened
        ? GameSpeeds.pacmanFrightened
        : GameSpeeds.pacman;
    var tiles = GameSpeeds.tiles(percent);
    if (game.isInTunnel(gridPos, moveDir, moveProgress)) {
      tiles *= GameSpeeds.tunnelFactor;
    }

    // Fantasma Imán: Shardox acelera a Pac-Man si avanza hacia él y lo frena
    // si se aleja. Moverse de lado (perpendicular) no cambia la velocidad.
    if (game.magnetStrength > 0 && (moveDir.x != 0 || moveDir.y != 0)) {
      final pull = moveDir.dot(game.magnetDir); // +1 hacia Shardox, -1 alejándose
      tiles *= 1.0 + AbilityConfig.magnetMaxPull * game.magnetStrength * pull;
    }
    return tiles;
  }

  /// Crea al jugador en la casilla [gridPos] (columna, fila).
  PlayerPacman(this.gridPos);

  /// Carga el sprite desde la caché y fija el tamaño del jugador.
  @override
  Future<void> onLoad() async {
    super.onLoad();
    try {
      // fromCache lanza una excepción si la imagen no se cargó. Se ignora a
      // propósito: el jugador se dibujará con la figura de respaldo.
      sprite = GameSprite(game.gameImage('vance.png'));
    } catch (_) {}
    // El sprite mide 20 px dentro de una casilla de 24 px (2 px de margen por
    // lado, más el +4 de updatePixelPosition que lo deja casi centrado).
    size = Vector2(20, 20);
    updatePixelPosition();
  }

  /// Convierte la posición de cuadrícula a píxeles y la aplica al componente.
  void updatePixelPosition() {
    position = Vector2(
      // El +4 centra el sprite dentro de la casilla de 24 px.
      game.mazeOffsetX + gridPos.x * game.tileSize + 4,
      24 + gridPos.y * game.tileSize + 4,
    );
  }

  /// Registra la próxima dirección deseada por el jugador.
  void changeDirection(Vector2 newDir) {
    nextDir = newDir.clone();
  }

  /// Dibuja el sprite (o un círculo amarillo) y el nombre del jugador encima.
  @override
  void render(Canvas canvas) {
    // Al perder una vida parpadea (8 cambios por segundo) durante 3 s.
    if (game.isDying && (game.deathElapsed * 8).floor().isOdd) return;

    if (sprite != null) {
      sprite!.drawBody(canvas);
    } else {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x / 2,
        Paint()..color = Colors.yellow,
      );
    }
    // Etiqueta con el nombre que escribió el jugador.
    drawEntityLabel(
      canvas,
      playerName.isEmpty ? 'JUGADOR' : playerName.toUpperCase(),
      size,
      Colors.yellow,
      fontSize: 7,
    );
  }

  /// Lógica de cada frame: decide la dirección, avanza y recoge puntos.
  @override
  void update(double dt) {
    super.update(dt);
    // Con la partida terminada, el jugador queda congelado.
    if (game.isFrozen) return;

    // Solo se decide una nueva dirección cuando está exactamente en una casilla.
    if (moveProgress == 0.0) {
      if ((nextDir.x != 0 || nextDir.y != 0)) {
        // Casilla a la que apunta el giro solicitado.
        int nextX = (gridPos.x + nextDir.x).toInt();
        int nextY = (gridPos.y + nextDir.y).toInt();
        // Si no hay muro, el giro se ejecuta. Si lo hay, el pedido se conserva en
        // nextDir hasta que sea posible (permite anticipar giros).
        if (game.isWalkable(nextX, nextY, isGhost: false)) {
          moveDir = nextDir.clone();
          nextDir.setZero();
        }
      }

      // Si hay un muro al frente, se detiene.
      int targetX = (gridPos.x + moveDir.x).toInt();
      int targetY = (gridPos.y + moveDir.y).toInt();
      if (!game.isWalkable(targetX, targetY, isGhost: false)) {
        moveDir.setZero();
      }
    }

    // Movimiento interpolado entre la casilla actual y la siguiente.
    if ((moveDir.x != 0 || moveDir.y != 0)) {
      // casillas/segundo x segundos = fracción de casilla recorrida. Así la
      // velocidad no depende de los cuadros por segundo del dispositivo.
      moveProgress += speed * dt;

      double startX = game.mazeOffsetX + gridPos.x * game.tileSize + 4;
      double startY = 24 + gridPos.y * game.tileSize + 4;
      double endX = game.mazeOffsetX + (gridPos.x + moveDir.x) * game.tileSize + 4;
      double endY = 24 + (gridPos.y + moveDir.y) * game.tileSize + 4;

      // Interpolación lineal entre el origen y el destino. min(..., 1.0) evita
      // pasarse de la casilla destino.
      position.x = startX + (endX - startX) * min(moveProgress, 1.0);
      position.y = startY + (endY - startY) * min(moveProgress, 1.0);

      // Llegó a la nueva casilla: se confirma la posición de cuadrícula y se
      // reinicia el avance.
      if (moveProgress >= 1.0) {
        gridPos.add(moveDir);
        moveProgress = 0.0;

        // Túnel lateral: al salir por un extremo reaparece en el opuesto.
        if (gridPos.x < 0) {
          gridPos.x = (game.maxCols - 1).toDouble();
        } else if (gridPos.x >= game.maxCols) {
          gridPos.x = 0;
        }
        // Portal: si la casilla donde llegó es un portal, aparece en su pareja.
        final portalDest =
            game.portalLinks[tileKey(gridPos.x.toInt(), gridPos.y.toInt())];
        if (portalDest != null) {
          gridPos.x = (portalDest % 100).toDouble();
          gridPos.y = (portalDest ~/ 100).toDouble();
          GameAudio.sfx('sfx_portal.wav');
        }
        updatePixelPosition();
        // Se anota la casilla visitada: el Fantasma Constructor usa este rastro.
        game.recordPacTile(gridPos);

        // Aplica de inmediato el giro pendiente si ya es posible.
        if ((nextDir.x != 0 || nextDir.y != 0)) {
          int nextX = (gridPos.x + nextDir.x).toInt();
          int nextY = (gridPos.y + nextDir.y).toInt();
          if (game.isWalkable(nextX, nextY, isGhost: false)) {
            moveDir = nextDir.clone();
            nextDir.setZero();
          }
        }
      }
    }

    // "facing" conserva la última dirección aunque el jugador se detenga; Vespakron e
    // Kyros la usan para anticiparse.
    if ((moveDir.x != 0 || moveDir.y != 0)) facing.setFrom(moveDir);

    // Recolección: rimora = 10 pts, mydra = 100 pts + pánico en los fantasmas.
    // Es una consulta directa por casilla (no recorre todos los componentes).
    final eaten = game.rimoraField.eatAt(gridPos.x.toInt(), gridPos.y.toInt());
    if (eaten != null) {
      game.rimorasRemaining--;
      game.addScore(eaten ? kMydraPoints : kRimoraPoints);
      if (eaten) {
        game.onMydraEaten(); // Asusta a todos los fantasmas a la vez
      } else {
        GameAudio.sfx('sfx_rimora.wav', volume: 0.6);
      }
    }

    // Corazón de cristal final (nivel 5): al tomarlo se gana la partida.
    if (game.finalHeartActive &&
        gridPos.x == PacManGame.heartCol &&
        gridPos.y == PacManGame.heartRow) {
      game.collectFinalHeart();
    }
  }
}
