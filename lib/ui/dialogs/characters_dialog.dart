// =============================================================================
// ui/dialogs/characters_dialog.dart
//
// Ventana "Personajes": galería con imagen y descripción de cada personaje.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:pacman_juego/core/constants.dart';
import 'package:pacman_juego/game/ai/ghost_personality.dart';
import 'package:pacman_juego/ui/dialogs/info_dialog.dart';

/// Muestra la ventana con todos los personajes (foto y nombre).
Future<void> showCharacters(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const InfoDialog(
      title: 'PERSONAJES',
      accent: Colors.pinkAccent,
      child: _CharactersContent(),
    ),
  );
}

/// Datos de una tarjeta de la galería de personajes.
class _CharInfo {
  const _CharInfo({
    required this.name,
    required this.images,
    required this.color,
    required this.description,
    this.tag,
  });

  /// Nombre que se muestra (vacío = sin nombre).
  final String name;
  /// Rutas completas de las imágenes (una o varias, por ejemplo Pyros y Kyros).
  final List<String> images;
  /// Color del borde y del nombre.
  final Color color;
  /// Descripción bajo la imagen.
  final String description;
  /// Línea corta bajo el nombre (tipo o apodo), opcional.
  final String? tag;
}

/// Ruta completa de la imagen normal de un fantasma.
String _ghostImage(GhostType type) =>
    'assets/images/${GhostPersonality.of(type).spriteAsset}';

/// Ruta completa de la imagen asustada ("niga") de un fantasma.
String _scaredImage(GhostType type) =>
    'assets/images/${GhostPersonality.of(type).scaredSpriteAsset}';

/// Título de una sección de la galería, con subtítulo opcional.
class _GalleryTitle extends StatelessWidget {
  const _GalleryTitle(this.text, this.color, {this.subtitle});

  final String text;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.5,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: Colors.white54),
            ),
          ],
        ],
      ),
    );
  }
}

/// Galería de personajes: Vance, los Guardianes de Cristal, los objetos
/// coleccionables y el estado de pánico de los guardianes.
class _CharactersContent extends StatelessWidget {
  const _CharactersContent();

  @override
  Widget build(BuildContext context) {
    final gap = const SizedBox(height: 12);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _GalleryTitle('PERSONAJE PRINCIPAL', Colors.yellowAccent),
        const _CharacterCard(
          info: _CharInfo(
            name: 'Vance',
            images: ['assets/images/vance.png'],
            color: Colors.yellowAccent,
            description:
                'El protagonista indiscutible de esta aventura. A diferencia de '
                'los habitantes de este extraño lugar, Vance carece de un pasado '
                'registrado aquí: no pertenece a este planeta. Atrapado en un '
                'mundo que no comprende, su única vía de escape depende de '
                'adaptarse a las reglas mortales del laberinto.',
          ),
        ),
        const _GalleryTitle(
          'LOS GUARDIANES DE CRISTAL',
          Colors.pinkAccent,
          subtitle:
              '(Las amenazas principales que acechan en cada rincón del laberinto)',
        ),
        _CharacterCard(
          info: _CharInfo(
            name: 'Shardox',
            images: [_ghostImage(GhostType.shardox)],
            color: GhostPersonality.of(GhostType.shardox).color,
            tag: 'Tipo: Robot de Cristal',
            description:
                'Un implacable acechador mecánico. Shardox posee una conciencia '
                'total del laberinto; sin importar en qué rincón del mapa te '
                'encuentres, siempre sabrá tu ubicación exacta y te dará caza '
                'sin descanso. Como si fuera poco, cuenta con un campo '
                'gravitacional que te atrae hacia él si te demoras demasiado '
                'cerca de su radio de acción. ¡Mantén la distancia!',
          ),
        ),
        gap,
        _CharacterCard(
          info: _CharInfo(
            name: 'Vespakron',
            images: [_ghostImage(GhostType.vespakron)],
            color: GhostPersonality.of(GhostType.vespakron).color,
            tag: 'Tipo: Bestia / Abeja de Cristal (Rey de las Abejas)',
            description:
                'El monarca alado del enjambre cristalino. Vespakron es un '
                'maestro de las emboscadas dinámicas, diseñado para aparecer de '
                'la nada justo frente a tu camino cuando menos lo esperas. '
                'Además de su letalidad, manipula el terreno sellando rutas con '
                'muros de cera temporales, obligándote a pensar rápido antes de '
                'quedar encajonado.',
          ),
        ),
        gap,
        _CharacterCard(
          info: _CharInfo(
            name: 'Pyros y Kyros',
            images: [_ghostImage(GhostType.pyros), _ghostImage(GhostType.kyros)],
            color: GhostPersonality.of(GhostType.pyros).color,
            tag: 'Tipo: Cristales Gemelos Centinelas',
            description:
                'Dos hermanos cristalinos que patrullan los callejones más '
                'oscuros del laberinto. Aunque por separado ya son peligrosos, '
                'su verdadera fuerza radica en su conexión: ambos pueden '
                'proyectar un láser cruzado capaz de atravesar paredes para '
                'desintegrar a cualquier intruso. Curiosamente, su energía es '
                'tan pura que respeta la estructura del laberinto, dañándote '
                'únicamente a ti.',
          ),
        ),
        const _GalleryTitle('OBJETOS Y COLECCIONABLES', neonLime),
        const _CharacterCard(
          info: _CharInfo(
            name: 'Rimora',
            images: ['assets/images/rimora.png'],
            color: Colors.cyanAccent,
            tag: 'El Cristal Preciado',
            description:
                'Gema de alto valor y la razón principal por la cual Vance se '
                'arriesga en este nuevo mundo. Abundan por todas partes, pero '
                'conseguirlas implica adentrarse en las zonas más peligrosas '
                'del laberinto. Son el motor de tu travesía.',
          ),
        ),
        gap,
        const _CharacterCard(
          info: _CharInfo(
            name: 'Talismán Mydra',
            images: ['assets/images/mydra.png'],
            color: neonLime,
            description:
                'Una reliquia mística de gran poder. Al consumirlo, desatas una '
                'energía que aterroriza a los Guardianes, provocando que entren '
                'en pánico y huyan despavoridos en busca de salidas aleatorias, '
                'dándote un respiro vital para planear tu siguiente movimiento.',
          ),
        ),
        const _GalleryTitle('GUARDIANES EN PÁNICO', Colors.lightBlueAccent),
        _CharacterCard(
          info: _CharInfo(
            name: '',
            images: [
              _scaredImage(GhostType.shardox),
              _scaredImage(GhostType.vespakron),
              _scaredImage(GhostType.kyros),
              _scaredImage(GhostType.pyros),
            ],
            color: Colors.lightBlueAccent,
            description:
                'Cuando Vance consume un Talismán Mydra, la jerarquía del '
                'laberinto se invierte por completo: los implacables cazadores '
                'se convierten en presas. En este estado, la confianza y el '
                'control absoluto de los Guardianes se desvanecen; sus patrones '
                'de ataque y rastreo se rompen, provocando que entren en pánico '
                'total y huyan a ciegas por los callejones en busca de cualquier '
                'salida desesperada, dándote el respiro perfecto para tomar la '
                'iniciativa.',
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de un personaje: imagen(es) arriba y nombre, tipo y descripción
/// debajo.
class _CharacterCard extends StatelessWidget {
  const _CharacterCard({required this.info});

  final _CharInfo info;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: info.color.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: info.color.withAlpha(180), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 14,
            runSpacing: 8,
            children: [
              for (final path in info.images)
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Image.asset(
                    path,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                    cacheWidth: 192, // Decodifica pequeño: ahorra memoria.
                    // Si falta la imagen se muestra un cuadro del color del
                    // personaje.
                    errorBuilder: (context, error, stackTrace) => DecoratedBox(
                      decoration: BoxDecoration(
                        color: info.color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (info.name.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              info.name.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: info.color,
              ),
            ),
          ],
          if (info.tag != null) ...[
            const SizedBox(height: 3),
            Text(
              info.tag!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontStyle: FontStyle.italic,
                color: info.color.withAlpha(220),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            info.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, height: 1.35, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
