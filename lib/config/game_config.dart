// =============================================================================
// config/game_config.dart
//
// Parámetros del juego: velocidades, habilidades especiales y reglas de choque. Aquí se ajusta la dificultad.
// =============================================================================



/// Parámetros de las habilidades especiales. Ajusta aquí la dificultad.
class AbilityConfig {
  AbilityConfig._();

  // --- Fantasma Imán (Shardox) ---------------------------------------------
  /// Radio de atracción, en casillas.
  static const double magnetRadiusTiles = 3.0;

  /// Variación máxima de la velocidad de Pac-Man (0.30 = +-30 %).
  static const double magnetMaxPull = 0.30;

  // --- Fantasma Constructor (Vespakron) ----------------------------------------
  /// Espera inicial antes de la primera pared (s).
  static const double builderFirstDelay = 6.0;

  /// Tiempo entre una pared y la siguiente (s).
  static const double builderCooldown = 8.0;

  /// Aviso parpadeante antes de que la pared se vuelva sólida (s).
  static const double builderWarningSeconds = 1.0;

  /// Tiempo que la pared permanece sólida (s).
  static const double builderDurationSeconds = 6.0;

  /// Máximo de paredes temporales simultáneas.
  static const int builderMaxWalls = 2;

  /// Distancia mínima (casillas) entre Pac-Man y una pared nueva.
  static const double builderMinPacDistance = 3.0;

  /// Casillas que Pac-Man debe poder alcanzar tras colocar la pared, para
  /// garantizar que nunca quede encerrado.
  static const int builderMinReachable = 60;

  // --- Láser Kyros-Pyros -----------------------------------------------------
  /// Duración del láser activo (s).
  static const double laserActiveSeconds = 8.0;

  /// Duración del enfriamiento (s).
  static const double laserCooldownSeconds = 15.0;

  /// Aviso (línea punteada, sin peligro) al final del enfriamiento (s).
  static const double laserWarningSeconds = 1.5;

  /// Distancia (px) a la que el rayo alcanza a Pac-Man.
  static const double laserHitRadius = 6.0;
}

/// Fracción de la SILUETA de un personaje que debe quedar cubierta por el otro
/// para que cuente un choque: 1/4. Así nadie muere ni es comido por rozarse los
/// bordes del PNG; tienen que encimarse de verdad. Súbelo (por ejemplo 1 / 3)
/// para exigir que se encimen más, o bájalo (1 / 6) para lo contrario.
const double kEatOverlapFraction = 1 / 4;

/// Si es `true` se muestra un contador de FPS (cuadros por segundo) abajo a la
/// izquierda del laberinto, para medir el rendimiento. Déjalo en `false` para
/// jugar normal.
const bool kShowFps = false;

/// Tabla central de velocidades del juego.
///
/// Todas las velocidades se expresan como un porcentaje de [base]
/// (casillas por segundo al 100 %). Para ajustar la dificultad basta con
/// cambiar estos valores.
class GameSpeeds {
  GameSpeeds._();

  /// Casillas por segundo al 100 %.
  static const double base = 5.0;

  /// Pac-Man en condiciones normales.
  static const double pacman = 0.80;

  /// Pac-Man mientras los fantasmas están asustados (corre un poco más).
  static const double pacmanFrightened = 0.90;

  /// Fantasma en condiciones normales.
  static const double ghost = 0.70;

  /// Fantasma asustado: cae drásticamente.
  static const double ghostFrightened = 0.40;

  /// Shardox en Cruise Elroy 1 (igual de rápido que Pac-Man).
  static const double elroy1 = 0.80;

  /// Shardox en Cruise Elroy 2 (más rápido que Pac-Man).
  static const double elroy2 = 0.88;

  /// Multiplicador dentro de los túneles laterales. 1.0 = velocidad normal
  /// (sin cambio). Afecta igual a Pac-Man y a los fantasmas.
  static const double tunnelFactor = 1.0;

  /// Cruise Elroy 1 se activa cuando queda este porcentaje de puntos.
  static const double elroy1DotsFraction = 0.15;

  /// Cruise Elroy 2 se activa cuando queda este porcentaje de puntos.
  static const double elroy2DotsFraction = 0.07;

  /// Convierte un porcentaje de [base] a casillas por segundo.
  static double tiles(double percent) => base * percent;
}

/// Si es `true`, Shardox en Cruise Elroy ignora el modo Scatter y sigue
/// persiguiendo a Pac-Man, como en el original.
const bool kElroyIgnoresScatter = true;

/// Si es `true`, Vespakron e Kyros replican el error de desbordamiento del
/// Pac-Man original: cuando Pac-Man mira hacia arriba, el objetivo también se
/// desplaza a la izquierda. Por defecto está desactivado.
const bool kEmulateOriginalOverflowBug = false;

// -----------------------------------------------------------------------------
// PUNTUACIÓN Y HABILIDAD DE HIELO
// -----------------------------------------------------------------------------

/// Puntos por comer una rimora.
const int kRimoraPoints = 100;

/// Puntos por comer una mydra.
const int kMydraPoints = 500;

/// Puntos por comer un guardián asustado.
const int kGhostPoints = 750;

/// Puntos que hay que ganar para recargar la habilidad de hielo. Al usarla NO se
/// restan puntos del marcador: solo se vacía la barra y se vuelve a llenar.
const double kAbilityCostPoints = 1500.0;

/// Si es `true`, el selector de niveles deja elegir cualquier nivel (útil para
/// probar los niveles 2 a 5 sin tener que ganar los anteriores). Déjalo en
/// `false` para jugar normal.
const bool kUnlockAllLevels = false;
