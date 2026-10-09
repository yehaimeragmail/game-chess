/// Pseudo-3D carved-wood chess pieces.
/// Boxwood (creamy amber) vs ebony (deep grain), felt-base shadows,
/// layered highlights for carved depth. No flat glyphs.
library;

import 'package:flutter/material.dart';
import '../theme.dart';

const _glyph = ['', '♟', '♞', '♝', '♜', '♛', '♚'];

/// A single chess piece rendered as a carved physical object.
class CarvedPiece extends StatelessWidget {
  /// abs piece 1..6, sign: positive = white (boxwood), negative = black (ebony)
  final int piece;
  final double size;

  const CarvedPiece({super.key, required this.piece, this.size = 34});

  @override
  Widget build(BuildContext context) {
    final white = piece > 0;
    final a = piece.abs();
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
          // carved body: layered glyph for depth
          Text(
            _glyph[a],
            style: TextStyle(
              fontSize: size * 0.92,
              height: 1.0,
              foreground: Paint()
                ..style = PaintingStyle.fill
                ..color = white ? ChessPalette.boxwood : ChessPalette.ebony,
              shadows: [
                // deep carve shadow
                Shadow(
                  color: Colors.black.withValues(alpha: 0.75),
                  blurRadius: size * 0.06,
                  offset: Offset(size * 0.045, size * 0.06),
                ),
                // warm top-light highlight
                Shadow(
                  color: (white ? Colors.white : ChessPalette.ebonyHi)
                      .withValues(alpha: 0.55),
                  blurRadius: size * 0.03,
                  offset: Offset(-size * 0.02, -size * 0.025),
                ),
              ],
            ),
          ),
          // glossy top-left sheen (polished wood catching lamplight)
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

/// Captured-piece tray: a felt-lined walnut strip.
class CapturedTray extends StatelessWidget {
  final List<int> captured; // abs piece values
  final bool whiteCaptured; // true = white's captures (black pieces)
  final double pieceSize;

  const CapturedTray({
    super.key,
    required this.captured,
    required this.whiteCaptured,
    this.pieceSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<int>.from(captured)
      ..sort((a, b) => b.compareTo(a));
    return Container(
      height: pieceSize + 14,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: ChessPalette.feltDark.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ChessPalette.walnutLine, width: 1),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: sorted.isEmpty
          ? Center(
              child: Text(
                '—',
                style: TextStyle(
                    color: ChessPalette.ivoryDim.withValues(alpha: 0.5),
                    fontSize: 14),
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
                  ),
              ],
            ),
    );
  }
}
