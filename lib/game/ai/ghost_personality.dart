// =============================================================================
// game/ai/ghost_personality.dart
//
// Tipos de fantasma y la personalidad (objetivo, sprites, nombre) de cada uno.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import 'package:pacman_juego/config/game_config.dart';
import 'package:pacman_juego/game/pacman_game.dart';

/// Los cuatro fantasmas, identificados por su personalidad clásica.
///
/// - [shardox]: perseguidor directo.
/// - [vespakron]: emboscador.
/// - [kyros]: estratega (flanqueo).
/// - [pyros]: tímido / errante.
enum GhostType { shardox, vespakron, kyros, pyros }

/// Datos que necesita una personalidad para calcular su objetivo.
class GhostContext {
  const GhostContext({
    required this.ghostTile,
    required this.pacTile,
    required this.pacDir,
    required this.shardoxTile,
  });

  /// Casilla del fantasma que calcula.
  final Vector2 ghostTile;

  /// Casilla actual de Pac-Man.
  final Vector2 pacTile;

  /// Última dirección en la que se movió Pac-Man.
  final Vector2 pacDir;

  /// Casilla de Shardox (la usa Kyros para su vector de flanqueo).
  final Vector2 shardoxTile;
}

/// Casilla que está [tiles] casillas delante de [origin] en dirección [dir].
Vector2 _tilesAhead(Vector2 origin, Vector2 dir, int tiles) {
  // Punto desplazado "tiles" casillas en la dirección dada. Puede quedar fuera
  // del mapa: es solo un objetivo de cálculo, no una casilla a pisar.
  final t = origin + dir * tiles.toDouble();
  if (kEmulateOriginalOverflowBug && dir.y < 0) {
    t.x -= tiles;
  }
  return t;
}

/// Estrategia de objetivo de un fantasma.
abstract class GhostPersonality {
  const GhostPersonality();

  /// Color de respaldo si no hay sprite disponible.
  Color get color;

  /// Nombre del personaje (galería del menú y mensajes de derrota).
  String get displayName;

  /// Texto que explica CÓMO mató este fantasma al jugador (se muestra en
  /// pantalla al perder una vida). Puede depender del estado del juego.
  String deathDetail(PacManGame game);

  /// Sprite normal del fantasma (archivo dentro de assets/images/).
  String get spriteAsset;

  /// Sprite del fantasma asustado ("niga"), propio de cada personaje.
  String get scaredSpriteAsset;

  /// Esquina a la que se dirige en modo Scatter (puede estar fuera del mapa,
  /// como en el original, para que rodee la esquina).
  Vector2 get scatterTarget;

  /// Casilla objetivo en modo Chase.
  Vector2 chaseTarget(GhostContext c);

  /// Devuelve la personalidad correspondiente a [type].
  static GhostPersonality of(GhostType type) {
    switch (type) {
      case GhostType.shardox:
        return const ShardoxPersonality();
      case GhostType.vespakron:
        return const VespakronPersonality();
      case GhostType.kyros:
        return const KyrosPersonality();
      case GhostType.pyros:
        return const PyrosPersonality();
    }
  }
}

/// Shardox: su objetivo es siempre la casilla actual de Pac-Man.
class ShardoxPersonality extends GhostPersonality {
  const ShardoxPersonality();

  @override
  Color get color => Colors.red;

  @override
  String get displayName => 'Shardox';

  @override
  String get spriteAsset => 'shardox.png';

  @override
  String get scaredSpriteAsset => 'shardoxniga.png';

  @override
  String deathDetail(PacManGame game) => game.magnetStrength > 0
      ? 'Te atrajo con su campo gravitacional y te dio caza.'
      : 'Te dio caza sin descanso: siempre supo dónde estabas.';

  @override
  Vector2 get scatterTarget => Vector2(25, -2); // Arriba a la derecha

  @override
  Vector2 chaseTarget(GhostContext c) => c.pacTile.clone();
}

/// Vespakron: apunta 4 casillas por delante de la dirección de Pac-Man.
class VespakronPersonality extends GhostPersonality {
  const VespakronPersonality();

  @override
  Color get color => Colors.pinkAccent;

  @override
  String get displayName => 'Vespakron';

  @override
  String get spriteAsset => 'vespakron.png';

  @override
  String get scaredSpriteAsset => 'vespakronniga.png';

  @override
  String deathDetail(PacManGame game) => game.tempWalls.isNotEmpty
      ? 'Te acorraló con sus muros de cera y te emboscó.'
      : 'Te emboscó justo en medio de tu camino.';

  @override
  Vector2 get scatterTarget => Vector2(1, -2); // Arriba a la izquierda

  @override
  Vector2 chaseTarget(GhostContext c) => _tilesAhead(c.pacTile, c.pacDir, 4);
}

/// Kyros: usa a Pac-Man y a Shardox para formar un vector de flanqueo.
///
/// 1. Toma el punto "pivote": 2 casillas por delante de Pac-Man.
/// 2. Traza el vector desde Shardox hasta el pivote.
/// 3. Duplica ese vector: el objetivo es `pivote + (pivote - shardox)`.
class KyrosPersonality extends GhostPersonality {
  const KyrosPersonality();

  @override
  Color get color => Colors.cyanAccent;

  @override
  String get displayName => 'Kyros';

  @override
  String get spriteAsset => 'kyros.png';

  @override
  String get scaredSpriteAsset => 'kyrosniga.png';

  @override
  String deathDetail(PacManGame game) =>
      'Te atrapó en los callejones del laberinto.';

  @override
  Vector2 get scatterTarget => Vector2(26, 17); // Abajo a la derecha

  @override
  Vector2 chaseTarget(GhostContext c) {
    // Paso 1: punto pivote, 2 casillas por delante del jugador.
    final pivot = _tilesAhead(c.pacTile, c.pacDir, 2);
    // Pasos 2 y 3: pivote + (pivote - Shardox) = 2 x pivote - Shardox, es decir, el
    // punto simétrico de Shardox respecto al pivote.
    return pivot * 2.0 - c.shardoxTile;
  }
}

/// Pyros: persigue a Pac-Man si está a más de 8 casillas; si está a 8 o
/// menos, se retira hacia su esquina.
class PyrosPersonality extends GhostPersonality {
  const PyrosPersonality();

  @override
  Color get color => Colors.orange;

  @override
  String get displayName => 'Pyros';

  @override
  String get spriteAsset => 'pyros.png';

  @override
  String get scaredSpriteAsset => 'pyrosniga.png';

  @override
  String deathDetail(PacManGame game) =>
      'Te alcanzó en los callejones del laberinto.';

  @override
  Vector2 get scatterTarget => Vector2(0, 17); // Abajo a la izquierda

  @override
  Vector2 chaseTarget(GhostContext c) {
    // Distancia en casillas entre Pyros y el jugador.
    final distance = c.ghostTile.distanceTo(c.pacTile);
    // Lejos: persigue. Cerca: huye a su esquina (por eso es "tímido").
    return distance > 8 ? c.pacTile.clone() : scatterTarget;
  }
}
