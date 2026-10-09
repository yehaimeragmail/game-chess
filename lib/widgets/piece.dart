/// Pseudo-3D chess pieces in three atelier styles.
/// Classic Carved: hand-carved Staunton with deep relief shading.
/// Modern Minimal: clean silhouette, quiet shadow.
/// Ornate Royal: gold-inlaid ring, embossed tournament royal.
/// No flat glyphs — every style keeps physical depth.
library;

import 'package:flutter/material.dart';
import '../theme/chess_themes.dart';

const _glyph = ['', '♟', '♞', '♝', '♜', '♛', '♚'];

/// A single chess piece rendered as a physical object.
class CarvedPiece extends StatelessWidget {
  /// abs piece 1..6, sign: positive = white, negative = black
  final int piece;
  final double size;
  final ChessThemeDef theme;
  final int style; // 0 classic, 1 modern, 2 ornate

  const CarvedPiece({
    super.key,
    required this.piece,
    required this.theme,
    this.size = 34,
    this.style = 0,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final white = piece > 0;
    final a = piece.abs();
    final body = white ? t.pieceWhite : t.pieceBlack;
    final hi = white ? t.pieceWhiteHi : t.pieceBlackHi;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // felt base shadow (ambient occlusion under the piece)
          Positioned(
            bottom: size * 0.06,
            child: Container(
              width: size * 0.72,
              height: size * 0.18,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(size * 0.09),
              ),
            ),
          ),
          // ornate: gold-inlaid ring behind the piece
          if (style == 2)
            Container(
              width: size * 0.96,
              height: size * 0.96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: t.accent.withValues(alpha: 0.85),
                    width: size * 0.045),
                boxShadow: [
                  BoxShadow(
                    color: t.accent.withValues(alpha: 0.25),
                    blurRadius: size * 0.08,
                  ),
                ],
              ),
            ),
          // the carved body
          Text(
            _glyph[a],
            style: TextStyle(
              fontSize: size * (style == 2 ? 0.78 : 0.92),
              height: 1.0,
              foreground: Paint()
                ..style = PaintingStyle.fill
                ..color = body,
              shadows: style == 1
                  ? [
                      // modern: one quiet drop shadow
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: size * 0.05,
                        offset: Offset(size * 0.03, size * 0.045),
                      ),
                    ]
                  : [
                      // deep carve shadow
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.75),
                        blurRadius: size * 0.06,
                        offset: Offset(size * 0.045, size * 0.06),
                      ),
                      // warm top-light highlight
                      Shadow(
                        color: hi.withValues(alpha: 0.55),
                        blurRadius: size * 0.03,
                        offset: Offset(-size * 0.02, -size * 0.025),
                      ),
                      if (style == 2)
                        // ornate: gold emboss edge
                        Shadow(
                          color: t.accent.withValues(alpha: 0.5),
                          blurRadius: size * 0.02,
                          offset: Offset(size * 0.015, size * 0.015),
                        ),
                    ],
            ),
          ),
          // glossy top-left sheen (polished wood catching lamplight)
          if (style != 1)
            Positioned(
              top: size * 0.14,
              left: size * 0.22,
              child: Container(
                width: size * 0.16,
                height: size * 0.10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size * 0.08),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: white ? 0.5 : 0.22),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Captured-piece tray: a felt-lined strip, one per side.
class CapturedTray extends StatelessWidget {
  final List<int> captured; // abs piece values
  final bool whiteCaptured; // true = white's captures (black pieces)
  final double pieceSize;
  final ChessThemeDef theme;
  final int style;

  const CapturedTray({
    super.key,
    required this.captured,
    required this.whiteCaptured,
    required this.theme,
    this.pieceSize = 20,
    this.style = 0,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final sorted = List<int>.from(captured)..sort((a, b) => b.compareTo(a));
    return Container(
      height: pieceSize + 14,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: t.felt.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.line, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: sorted.isEmpty
          ? Center(
              child: Text(
                '—',
                style: TextStyle(
                    color: t.ivoryDim.withValues(alpha: 0.5), fontSize: 14),
              ),
            )
          : ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              children: [
                for (final a in sorted)
                  CarvedPiece(
                    piece: whiteCaptured ? -a : a,
                    size: pieceSize,
                    theme: t,
                    style: style,
                  ),
              ],
            ),
    );
  }
}
