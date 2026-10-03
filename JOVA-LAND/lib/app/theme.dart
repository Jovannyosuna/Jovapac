import 'package:flutter/material.dart';

/// Visual language: deep violet night, neon lime and orange taken from the
/// LA SANVI logo, and cool accents for walls and frightened ghosts.
abstract final class Palette {
  static const night = Color(0xFF07060F);
  static const deep = Color(0xFF0E0B1F);
  static const floor = Color(0xFF0B0919);
  static const panel = Color(0xFF151129);
  static const panelBorder = Color(0xFF2C2654);
  static const text = Color(0xFFF4F1FF);
  static const textDim = Color(0xFFA6A1C9);
  static const textFaint = Color(0xFF6D6893);
  static const lime = Color(0xFFC8FF2E);
  static const orange = Color(0xFFFF7A1A);
  static const danger = Color(0xFFFF4D5E);
  static const fright = Color(0xFF4D7CFF);
  static const pellet = Color(0xFFFFE6B5);
  static const gold = Color(0xFFFFD34D);
}

abstract final class Fonts {
  static const display = 'PressStart2P';
  static const body = 'ChakraPetch';
}

/// The pixel display face has no accented glyphs, so it is reserved for
/// numbers and unaccented titles; anything with tildes uses [button]/[label].
abstract final class AppText {
  static TextStyle button(double size, {Color color = Palette.text}) =>
      TextStyle(
        fontFamily: Fonts.body,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.4,
        color: color,
      );

  static TextStyle display(double size, {Color color = Palette.text}) =>
      TextStyle(
        fontFamily: Fonts.display,
        fontSize: size,
        color: color,
        height: 1.25,
        letterSpacing: 0.5,
      );

  static TextStyle label({Color color = Palette.textDim, double size = 12}) =>
      TextStyle(
        fontFamily: Fonts.body,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 2.2,
        color: color,
      );

  static TextStyle body({Color color = Palette.text, double size = 16}) =>
      TextStyle(
        fontFamily: Fonts.body,
        fontSize: size,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: color,
      );
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Palette.night,
    colorScheme: base.colorScheme.copyWith(
      primary: Palette.lime,
      secondary: Palette.orange,
      surface: Palette.panel,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: Fonts.body,
      bodyColor: Palette.text,
      displayColor: Palette.text,
    ),
    focusColor: Palette.lime.withValues(alpha: 0.25),
  );
}
