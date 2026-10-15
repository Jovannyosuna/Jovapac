// =============================================================================
// game/ai/ghost_mode.dart
//
// IA global de los fantasmas: modos Scatter / Chase / Frightened.
// =============================================================================

import 'dart:math';


/// Modos globales de comportamiento de los fantasmas.
///
/// - [scatter]: cada fantasma se dirige a su esquina asignada.
/// - [chase]: cada fantasma persigue según su propia personalidad.
/// - [frightened]: los fantasmas huyen al azar y pueden ser comidos.
enum GhostMode { scatter, chase, frightened }

/// Controla el ciclo global de modos.
///
/// El ciclo base alterna Scatter y Chase según [schedule] (en segundos). El
/// modo Frightened se superpone al ciclo: mientras dura, el reloj del ciclo
/// base se pausa, igual que en el Pac-Man original.
///
/// Cada vez que debe ocurrir una inversión de dirección (cambio entre Scatter
/// y Chase, o inicio de Frightened) se incrementa [reversalTick]. Cada
/// fantasma compara ese contador con el último que vio y, si cambió, da la
/// vuelta en la siguiente casilla.
class GhostModeController {
  GhostModeController({
    this.schedule = const [7, 20, 7, 20, 5, 20, 5, double.infinity],
    this.frightenedDuration = 8.0,
  });

  /// Duración (s) de cada fase: Scatter, Chase, Scatter, Chase, ...
  /// La última fase es infinita (Chase permanente).
  final List<double> schedule;

  /// Duración (s) del modo Frightened.
  final double frightenedDuration;

  /// Índice de la fase actual en [schedule] (par = Scatter, impar = Chase).
  int _phase = 0;
  /// Segundos acumulados en la fase actual.
  double _phaseTimer = 0.0;
  /// Segundos restantes de Frightened (0 = inactivo).
  double _frightenedTimer = 0.0;
  /// Contador que aumenta cada vez que los fantasmas deben dar la vuelta.
  int _reversalTick = 0;

  /// Modo del ciclo base (sin considerar Frightened).
  GhostMode get baseMode =>
      _phase.isEven ? GhostMode.scatter : GhostMode.chase;

  /// Indica si el modo Frightened está activo.
  bool get isFrightened => _frightenedTimer > 0;

  /// Modo efectivo actual.
  GhostMode get mode => isFrightened ? GhostMode.frightened : baseMode;

  /// Contador de inversiones de dirección pendientes (ver descripción de clase).
  int get reversalTick => _reversalTick;

  /// Segundos que le quedan al modo Frightened (0 si no está activo).
  double get frightenedTimeLeft => _frightenedTimer;

  /// Reinicia el ciclo (nueva partida).
  void reset() {
    _phase = 0;
    _phaseTimer = 0.0;
    _frightenedTimer = 0.0;
    _reversalTick = 0;
  }

  /// Avanza los temporizadores. Llamar una vez por frame.
  void update(double dt) {
    if (isFrightened) {
      _frightenedTimer = max(0.0, _frightenedTimer - dt);
      return; // El ciclo Scatter/Chase queda pausado.
    }
    if (_phase >= schedule.length - 1) return; // Última fase (infinita).

    _phaseTimer += dt;
    if (_phaseTimer >= schedule[_phase]) {
      _phaseTimer = 0.0;
      _phase++;
      _reversalTick++; // Scatter <-> Chase obliga a dar la vuelta.
    }
  }

  /// Activa el modo Frightened (al comer un power-up).
  void startFrightened() {
    _frightenedTimer = frightenedDuration;
    _reversalTick++; // Los fantasmas dan la vuelta al asustarse.
  }
}
