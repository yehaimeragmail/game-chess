/// Grand Chess Heritage design tokens.
/// Stitch visual source of truth — see stitch-batch1/chess/DESIGN.md
library;

import 'package:flutter/material.dart';

/// Palette from Stitch "Grand Chess Heritage" design system.
abstract class ChessPalette {
  // Surfaces — layered walnut depths
  static const walnutDeep = Color(0xFF1a120b); // background
  static const walnutDark = Color(0xFF140d06); // surface containers
  static const walnutMid = Color(0xFF3d332b); // raised surfaces
  static const walnutLine = Color(0xFF4e4639); // outlines

  // Text
  static const ivory = Color(0xFFf1dfd3); // on-surface
  static const ivoryDim = Color(0xFF9a8f80); // muted outlines/text

  // Brass — primary controls
  static const brass = Color(0xFFe9c176);
  static const brassAged = Color(0xFFc5a059); // primary container
  static const onBrass = Color(0xFF412d00);

  // Felt green — secondary accents
  static const felt = Color(0xFFb1cdb6);
  static const feltDark = Color(0xFF364f3d);

  // Stone — tertiary
  static const stone = Color(0xFFcbc6bd);

  // Board marble
  static const carrara = Color(0xFFefe9dc); // light squares
  static const carraraShade = Color(0xFFd9d2c2);
  static const marquina = Color(0xFF23211e); // dark squares
  static const marquinaHi = Color(0xFF35322c);

  // Pieces — carved wood
  static const boxwood = Color(0xFFd9a75f); // white pieces (creamy amber)
  static const boxwoodHi = Color(0xFFf2cd8e);
  static const ebony = Color(0xFF17130f); // black pieces
  static const ebonyHi = Color(0xFF3a322a);

  // Semantic
  static const checkRed = Color(0xFFb3402e);
  static const lastMove = Color(0xFF7a9b6d);
  static const selGold = Color(0xFFe9c176);
}

/// Typography: engraved serif for headings, humanist sans for body.
abstract class ChessType {
  static const serif = 'Georgia'; // engraved plaque feel (system serif)
  static const sans = 'sans-serif';

  static TextStyle display(BuildContext context) => TextStyle(
        fontFamily: serif,
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: ChessPalette.ivory,
        letterSpacing: 1.2,
        shadows: const [
          Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 2)),
        ],
      );

  static TextStyle plaqueTitle(BuildContext context) => TextStyle(
        fontFamily: serif,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: ChessPalette.onBrass,
        letterSpacing: 1.6,
      );

  static const body = TextStyle(
    fontSize: 15,
    color: ChessPalette.ivory,
    height: 1.45,
  );

  static const bodyDim = TextStyle(
    fontSize: 13,
    color: ChessPalette.ivoryDim,
    height: 1.4,
  );

  static const moveNotation = TextStyle(
    fontSize: 13,
    color: ChessPalette.ivory,
    letterSpacing: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Shared decoration helpers for the physical material language.
abstract class ChessMaterials {
  /// Walnut panel with deep shadow (cabinetry).
  static BoxDecoration walnutPanel({double radius = 14}) => BoxDecoration(
        color: ChessPalette.walnutDark,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: ChessPalette.walnutLine, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 18, offset: Offset(0, 8)),
          BoxShadow(
              color: Color(0x22e9c176), blurRadius: 2, offset: Offset(0, -1)),
        ],
      );

  /// Brushed-brass plaque button.
  static BoxDecoration brassPlaque({double radius = 12, bool pressed = false}) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pressed
              ? [ChessPalette.brassAged, ChessPalette.brass]
              : [ChessPalette.brass, ChessPalette.brassAged],
        ),
        border: Border.all(color: const Color(0xFF8a6d35), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: pressed ? 4 : 10,
              offset: Offset(0, pressed ? 2 : 5)),
          const BoxShadow(
              color: Color(0x66fff2cc), blurRadius: 1, offset: Offset(0, 1)),
        ],
      );

  /// Carrara marble light square.
  static BoxDecoration marbleLight({bool highlight = false}) => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFf4efe4), ChessPalette.carrara, ChessPalette.carraraShade],
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                    color: ChessPalette.selGold.withValues(alpha: 0.65),
                    blurRadius: 0,
                    spreadRadius: 2)
              ]
            : null,
      );

  /// Nero Marquina dark square.
  static BoxDecoration marbleDark({bool highlight = false}) => BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [ChessPalette.marquinaHi, ChessPalette.marquina, Color(0xFF100e0b)],
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                    color: ChessPalette.selGold.withValues(alpha: 0.65),
                    blurRadius: 0,
                    spreadRadius: 2)
              ]
            : null,
      );

  /// Walnut board frame with bevel.
  static BoxDecoration boardFrame() => BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4a3b2a), ChessPalette.walnutDeep, Color(0xFF0f0a05)],
        ),
        border: Border.all(color: ChessPalette.brassAged, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black87, blurRadius: 28, offset: Offset(0, 14)),
        ],
      );
}
