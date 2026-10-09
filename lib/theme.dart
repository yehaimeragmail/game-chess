/// Grand Chess Heritage design system — theme-aware helpers.
/// Stitch visual source of truth: stitch-batch1/chess/DESIGN.md
library;

import 'package:flutter/material.dart';
import 'theme/chess_themes.dart';

/// Typography: engraved serif for headings, humanist sans for body.
abstract class ChessType {
  static const serif = 'Georgia';
  static const sans = 'sans-serif';

  static TextStyle display(ChessThemeDef t, {double size = 34}) => TextStyle(
        fontFamily: serif,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: t.ivory,
        letterSpacing: 1.2,
        shadows: const [
          Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2)),
        ],
      );

  static TextStyle plaqueTitle(ChessThemeDef t, {double size = 20}) => TextStyle(
        fontFamily: serif,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: t.onAccent,
        letterSpacing: 1.6,
      );

  static TextStyle body(ChessThemeDef t) => TextStyle(
        fontSize: 15,
        color: t.ivory,
        height: 1.45,
      );

  static TextStyle bodyDim(ChessThemeDef t) => TextStyle(
        fontSize: 13,
        color: t.ivoryDim,
        height: 1.4,
      );

  static TextStyle moveNotation(ChessThemeDef t) => TextStyle(
        fontSize: 13,
        color: t.ivory,
        letterSpacing: 1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// App-wide ThemeData for Material scaffolding (dialogs, sliders…).
  static ThemeData themeData(ChessThemeDef t) {
    final light = t.id == 'ivory_gold';
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: t.bg,
      colorScheme: ColorScheme(
        brightness: light ? Brightness.light : Brightness.dark,
        primary: t.accent,
        onPrimary: t.onAccent,
        secondary: t.accentLight,
        onSecondary: t.onAccent,
        surface: t.surface,
        onSurface: t.ivory,
        error: t.checkRed,
        onError: t.ivory,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.surface,
        foregroundColor: t.ivory,
        elevation: 0,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.accent,
        inactiveTrackColor: t.line,
        thumbColor: t.accent,
      ),
    );
  }
}

/// Shared decoration helpers for the physical material language.
abstract class ChessMaterials {
  /// Walnut panel with deep shadow (cabinetry).
  static BoxDecoration walnutPanel(ChessThemeDef t, {double radius = 14}) =>
      BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: t.line, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 18, offset: Offset(0, 8)),
        ],
      );

  /// Brushed-metal plaque button.
  static BoxDecoration brassPlaque(ChessThemeDef t,
          {double radius = 12, bool pressed = false}) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pressed
              ? [t.accentDark, t.accent]
              : [t.accentLight, t.accent, t.accentDark],
          stops: const [0.0, 0.55, 1.0],
        ),
        border: Border.all(color: t.accentDark, width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: pressed ? 4 : 10,
              offset: Offset(0, pressed ? 2 : 5)),
          BoxShadow(
              color: t.accentLight.withValues(alpha: 0.35),
              blurRadius: 1,
              offset: const Offset(0, 1)),
        ],
      );

  /// Light board square (marble / light wood).
  static BoxDecoration squareLight(ChessThemeDef t) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.sqLightHi, t.sqLight],
        ),
      );

  /// Dark board square (marquina / dark wood).
  static BoxDecoration squareDark(ChessThemeDef t) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.sqDarkHi, t.sqDark],
        ),
      );

  /// Board frame with bevel.
  static BoxDecoration boardFrame(ChessThemeDef t) => BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.frameTop, t.frameMid, t.frameBot],
        ),
        border: Border.all(color: t.accentDark, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 28, offset: Offset(0, 14)),
        ],
      );
}
