// =============================================================================
// game/levels/level_data.dart
//
// Los 5 niveles del juego: mapa, colores, dificultad y mecánicas especiales.
// =============================================================================

import 'package:flutter/material.dart';

/// Códigos de las casillas del laberinto (los números de `mazeGrid`).
class TileCode {
  TileCode._();

  /// Pasillo con rimora (punto normal).
  static const int rimora = 0;

  /// Muro.
  static const int wall = 1;

  /// Casa de los guardianes (solo la cruzan ellos).
  static const int house = 2;

  /// Pasillo con mydra (punto grande).
  static const int mydra = 3;

  /// Portales: el 4 lleva al 5 y el 6 lleva al 7 (y al revés).
  static const int portalA1 = 4;
  static const int portalA2 = 5;
  static const int portalB1 = 6;
  static const int portalB2 = 7;

  /// Compuerta de fase A (abierta cuando la fase es A) y de fase B (la contraria).
  static const int gateA = 8;
  static const int gateB = 10;

  /// Pasillo vacío (sin rimora).
  static const int empty = 9;
}

/// Datos de un nivel.
///
/// Cada nivel es más difícil que el anterior: los guardianes van más rápido, el
/// efecto de la mydra dura menos, el láser dura más y descansa menos, y las
/// paredes de cera aparecen más seguido. Además cada nivel agrega algo nuevo:
/// - Nivel 2: portales que te cruzan de un lado a otro.
/// - Nivel 3: compuertas de energía que se abren y se cierran por fases.
/// - Nivel 4: niebla: solo ves lo que tienes cerca.
/// - Nivel 5: todo junto y lo más rápido.
class LevelData {
  const LevelData({
    required this.number,
    required this.name,
    required this.subtitle,
    required this.rows,
    required this.wallFill,
    required this.wallBorder,
    required this.wallHalo,
    required this.bgTop,
    required this.bgBottom,
    required this.ghostPercent,
    required this.frightenedSeconds,
    required this.schedule,
    required this.laserActive,
    required this.laserCooldown,
    required this.builderFirstDelay,
    required this.builderCooldown,
    required this.releaseDelays,
    required this.freezeSeconds,
    this.gatePeriod = 0.0,
    this.fogTiles = 0.0,
  });

  /// Número del nivel (1 a 5).
  final int number;
  final String name;
  final String subtitle;

  /// El mapa: 16 filas de 27 caracteres.
  /// `#` muro, `.` rimora, `o` mydra, `H` casa de los guardianes, ` ` vacío,
  /// `a`/`b` y `c`/`d` portales (a<->b, c<->d), `g`/`G` compuertas (fase A / B).
  final List<String> rows;

  /// Colores del tema del nivel.
  final Color wallFill;
  final Color wallBorder;
  final Color wallHalo;
  final Color bgTop;
  final Color bgBottom;

  /// Velocidad normal de los guardianes (porcentaje de la velocidad base).
  final double ghostPercent;

  /// Segundos que dura el pánico tras comer una mydra.
  final double frightenedSeconds;

  /// Duración (s) de cada fase Scatter / Chase.
  final List<double> schedule;

  /// Duración del láser activo y de su enfriamiento (s).
  final double laserActive;
  final double laserCooldown;

  /// Tiempos de las paredes de cera de Vespakron (s).
  final double builderFirstDelay;
  final double builderCooldown;

  /// Segundos que espera cada guardián en la base antes de salir (Shardox,
  /// Vespakron, Kyros, Pyros).
  final List<double> releaseDelays;

  /// Segundos que dura el hielo de Vance.
  final double freezeSeconds;

  /// Cada cuántos segundos cambian las compuertas (0 = no hay compuertas).
  final double gatePeriod;

  /// Radio de visión (en casillas) en los niveles con niebla (0 = sin niebla).
  final double fogTiles;

  /// Convierte el mapa de texto en la matriz de códigos [TileCode].
  List<List<int>> buildGrid() {
    return [
      for (final row in rows)
        [for (int i = 0; i < row.length; i++) _codeOf(row[i])]
    ];
  }

  static int _codeOf(String ch) {
    switch (ch) {
      case '#':
        return TileCode.wall;
      case 'o':
        return TileCode.mydra;
      case 'H':
        return TileCode.house;
      case ' ':
        return TileCode.empty;
      case 'a':
        return TileCode.portalA1;
      case 'b':
        return TileCode.portalA2;
      case 'c':
        return TileCode.portalB1;
      case 'd':
        return TileCode.portalB2;
      case 'g':
        return TileCode.gateA;
      case 'G':
        return TileCode.gateB;
      default:
        return TileCode.rimora; // '.'
    }
  }
}

/// Los niveles del juego, en orden.
const List<LevelData> kLevels = [
    LevelData(
      number: 1,
      name: 'El Laberinto de Cristal',
      subtitle: 'Aquí empieza todo',
      wallFill: Color(0xFF120A3C),
      wallBorder: Color(0xFF8B5CFF),
      wallHalo: Color(0xFF8B5CFF),
      bgTop: Color(0xFF1A0B3D),
      bgBottom: Color(0xFF07051A),
      ghostPercent: 0.70,
      frightenedSeconds: 8.0,
      schedule: [7.0, 20.0, 7.0, 20.0, 5.0, 20.0, 5.0, double.infinity],
      laserActive: 8.0,
      laserCooldown: 15.0,
      builderFirstDelay: 6.0,
      builderCooldown: 8.0,
      releaseDelays: [0.0, 2.0, 6.0, 10.0],
      freezeSeconds: 5.0,
      gatePeriod: 0.0,
      fogTiles: 0.0,
      rows: [
        '###########################',
        '#o...........#...........o#',
        '#.###.##.###.#.###.##.###.#',
        '#.#.....o.........o.....#.#',
        '#.#.####.#.#####.#.####.#.#',
        '#........#.......#........#',
        '####.###.###HHH###.###.####',
        '.........#HHHHHHH#.........',
        '####.###.#HHHHHHH#.###.####',
        '#.....##.#########.##.....#',
        '#.###........#........###.#',
        '#...#.##.###.#.###.##.#...#',
        '#.#.#o.#...........#.o#.#.#',
        '#.#.##.#.#.#######.#.##.#.#',
        '#o.......................o#',
        '###########################',
      ],
    ),
    LevelData(
      number: 2,
      name: 'Cámara de Portales',
      subtitle: 'Los portales te cruzan al otro lado',
      wallFill: Color(0xFF062A22),
      wallBorder: Color(0xFF2EE6A6),
      wallHalo: Color(0xFF2EE6A6),
      bgTop: Color(0xFF0B3A2E),
      bgBottom: Color(0xFF031A16),
      ghostPercent: 0.74,
      frightenedSeconds: 7.0,
      schedule: [6.0, 20.0, 6.0, 22.0, 4.0, 25.0, 4.0, double.infinity],
      laserActive: 9.0,
      laserCooldown: 14.0,
      builderFirstDelay: 5.5,
      builderCooldown: 6.5,
      releaseDelays: [0.0, 2.0, 5.0, 8.0],
      freezeSeconds: 5.0,
      gatePeriod: 0.0,
      fogTiles: 0.0,
      rows: [
        '###########################',
        '#o.......................o#',
        '#.##.####.###.###.####.##.#',
        '#.##...................##.#',
        '#...###..#.#####.#..###...#',
        '#.#......#.......#......#.#',
        '#.#.#.##.###HHH###.##.#.#.#',
        '#a#.#....#HHHHHHH#....#.#d#',
        '#.#.#.####HHHHHHH####.#.#.#',
        '#........#########........#',
        '#c###.##...........##.###b#',
        '#.....##..###.###..##.....#',
        '#.##......#.....#......##.#',
        '#.##.####.###.###.####.##.#',
        '#o.......................o#',
        '###########################',
      ],
    ),
    LevelData(
      number: 3,
      name: 'Compuertas de Energía',
      subtitle: 'Las compuertas se abren y se cierran',
      wallFill: Color(0xFF2A0F06),
      wallBorder: Color(0xFFFF7A1A),
      wallHalo: Color(0xFFFF7A1A),
      bgTop: Color(0xFF3A1606),
      bgBottom: Color(0xFF1A0803),
      ghostPercent: 0.78,
      frightenedSeconds: 6.0,
      schedule: [5.0, 20.0, 5.0, 25.0, 3.0, 30.0, 3.0, double.infinity],
      laserActive: 10.0,
      laserCooldown: 12.0,
      builderFirstDelay: 5.0,
      builderCooldown: 5.5,
      releaseDelays: [0.0, 1.5, 4.0, 7.0],
      freezeSeconds: 4.5,
      gatePeriod: 4.0,
      fogTiles: 0.0,
      rows: [
        '###########################',
        '#o.......................o#',
        '####g####G###.###g####G####',
        '#.........................#',
        '#...#.##.#.#####.#.##.#...#',
        '#...G....#.......#....g...#',
        '#.#.#....###HHH###....#.#.#',
        '..#.#....#HHHHHHH#....#.#..',
        '#...g....#HHHHHHH#....G...#',
        '#...#.##.#########.##.#...#',
        '#.........................#',
        '####G####g###.###G####g####',
        '#.........................#',
        '######g####G#.#g####G######',
        '#o.......................o#',
        '###########################',
      ],
    ),
    LevelData(
      number: 4,
      name: 'Niebla de Cristal',
      subtitle: 'Solo ves lo que tienes cerca',
      wallFill: Color(0xFF0A1030),
      wallBorder: Color(0xFF4FC3F7),
      wallHalo: Color(0xFF4FC3F7),
      bgTop: Color(0xFF0D1B4A),
      bgBottom: Color(0xFF050A1F),
      ghostPercent: 0.82,
      frightenedSeconds: 5.0,
      schedule: [5.0, 25.0, 4.0, 25.0, 3.0, 30.0, 3.0, double.infinity],
      laserActive: 11.0,
      laserCooldown: 10.0,
      builderFirstDelay: 4.5,
      builderCooldown: 5.0,
      releaseDelays: [0.0, 1.0, 3.0, 5.0],
      freezeSeconds: 4.0,
      gatePeriod: 0.0,
      fogTiles: 5.5,
      rows: [
        '###########################',
        '#o.......................o#',
        '#.#####.#.###.###.#.#####.#',
        '........#.........#........',
        '#.#.###..#.#####.#..###.#.#',
        '#.#......#.......#......#.#',
        '#.#.#.##.###HHH###.##.#.#.#',
        '....#....#HHHHHHH#....#....',
        '#.#...#..#HHHHHHH#..#...#.#',
        '#.#####..#########..#####.#',
        '#.........................#',
        '#.#####.#.###.###.#.#####.#',
        '#.......#.........#.......#',
        '#.####..#.###.###.#..####.#',
        '#o.......................o#',
        '###########################',
      ],
    ),
    LevelData(
      number: 5,
      name: 'El Corazón del Laberinto',
      subtitle: 'Portales, compuertas y niebla',
      wallFill: Color(0xFF2A0620),
      wallBorder: Color(0xFFFFD54A),
      wallHalo: Color(0xFFFF2E9A),
      bgTop: Color(0xFF3A0A2E),
      bgBottom: Color(0xFF1A0314),
      ghostPercent: 0.86,
      frightenedSeconds: 4.0,
      schedule: [4.0, 30.0, 3.0, 30.0, 2.0, 35.0, 2.0, double.infinity],
      laserActive: 12.0,
      laserCooldown: 8.0,
      builderFirstDelay: 4.0,
      builderCooldown: 4.0,
      releaseDelays: [0.0, 1.0, 2.0, 4.0],
      freezeSeconds: 4.0,
      gatePeriod: 3.2,
      fogTiles: 7.0,
      rows: [
        '###########################',
        '#o.......................o#',
        '#.##.###..##...##..###.##.#',
        '#a...........o...........d#',
        '#.##.#.#.#.#####.#.#.#.##.#',
        '#.##...#g#.......#G#...##.#',
        '#........###HHH###........#',
        '....###..#HHHHHHH#..###....',
        '#.#....#.#HHHHHHH#.#....#.#',
        '#.#.##.#.#########.#.##.#.#',
        '#.......G.........g.......#',
        '#.###.##..##...##..##.###.#',
        '#c........##...##........b#',
        '#.##.###..##...##..###.##.#',
        '#o.......................o#',
        '###########################',
      ],
    ),
];
