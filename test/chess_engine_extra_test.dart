import 'package:flutter_test/flutter_test.dart';
import 'package:chess/engine.dart';

List<int> _empty() => List.filled(64, 0);

void main() {
  group('insufficient material (RULES.md §10)', () {
    test('bare kings are an immediate draw', () {
      final e = ChessEngine();
      e.setPosition([6, ..._empty().sublist(1)]..[4] = -6, true);
      expect(e.drawReason(), contains('Bare kings'));
    });

    test('king + bishop vs king is a draw', () {
      final b = _empty();
      b[60] = 6;
      b[4] = -6;
      b[20] = 3; // bishop
      final e = ChessEngine()..setPosition(b, true);
      expect(e.drawReason(), contains('Insufficient material'));
    });

    test('king + knight vs king is a draw', () {
      final b = _empty();
      b[60] = 6;
      b[4] = -6;
      b[20] = 2; // knight
      final e = ChessEngine()..setPosition(b, true);
      expect(e.drawReason(), contains('Insufficient material'));
    });

    test('same-colored bishops cannot mate — draw', () {
      final b = _empty();
      b[60] = 6;
      b[4] = -6;
      b[26] = 3; // c6: (3+2)%2 = 1 → dark
      b[44] = -3; // e3: (5+4)%2 = 1 → dark
      final e = ChessEngine()..setPosition(b, true);
      expect(e.drawReason(), contains('Insufficient material'));
    });

    test('opposite-colored bishops can mate — not a draw', () {
      final b = _empty();
      b[60] = 6;
      b[4] = -6;
      b[26] = 3; // c6 dark
      b[43] = -3; // d3: (5+3)%2 = 0 → light
      final e = ChessEngine()..setPosition(b, true);
      expect(e.drawReason(), isNull);
    });

    test('K+N+N vs K is NOT an automatic draw', () {
      final b = _empty();
      b[60] = 6;
      b[4] = -6;
      b[20] = 2;
      b[21] = 2;
      final e = ChessEngine()..setPosition(b, true);
      expect(e.drawReason(), isNull);
    });
  });

  group('draw rules', () {
    test('fifty-move rule triggers at 100 halfmoves', () {
      final e = ChessEngine()..reset();
      e.halfmove = 100;
      expect(e.drawReason(), contains('Fifty-move'));
    });

    test('threefold repetition triggers', () {
      final e = ChessEngine()..reset();
      // Bounce knights: Ng1-f3, Ng8-f6, Nf3-g1, Nf6-g8 ×2 → same position 3×
      for (int k = 0; k < 2; k++) {
        mv(e, 62, 45);
        mv(e, 6, 21);
        mv(e, 45, 62);
        mv(e, 21, 6);
      }
      expect(e.drawReason(), contains('Threefold'));
    });

    test('en passant expires after one move', () {
      final e = ChessEngine();
      final b = _empty();
      b[60] = 6;
      b[4] = -6;
      b[28] = 1; // white pawn e5
      b[11] = -1; // black pawn c7
      e.setPosition(b, false);
      mv(e, 11, 27); // c7-c5 double push → ep square 19
      expect(e.ep, 19);
      // White wastes the reply with another move instead of capturing.
      mv(e, 28, 20); // e5-e6
      expect(e.ep, -1); // ep expired
      // No en-passant capture is available anymore.
      expect(e.legalMoves().where((m) => m.ep), isEmpty);
    });
  });

  group('persistence roundtrip', () {
    test('toJson/fromJson preserves rights, ep, halfmove', () {
      final e = ChessEngine()..reset();
      mv(e, 52, 36); // e2-e4
      mv(e, 12, 28); // e7-e5
      mv(e, 62, 45); // Ng1-f3
      final snap = e.toJson();
      final e2 = ChessEngine()..fromJson(Map<String, dynamic>.from(snap));
      expect(e2.board, e.board);
      expect(e2.whiteTurn, e.whiteTurn);
      expect(e2.wk, e.wk);
      expect(e2.ep, e.ep);
      expect(e2.halfmove, e.halfmove);
      expect(e2.positionHistory, e.positionHistory);
      expect(e2.legalMoves().length, e.legalMoves().length);
    });
  });

  group('bot search (RULES.md §11)', () {
    BotJob job(ChessEngine e, int depth) => BotJob(
          board: List<int>.from(e.board),
          white: e.whiteTurn,
          ep: e.ep,
          wk: e.wk,
          wq: e.wq,
          bk: e.bk,
          bq: e.bq,
          depth: depth,
          jitter: 0,
          seed: 42,
        );

    bool isLegal(ChessEngine e, BotResult r) => e
        .legalMoves()
        .any((m) => m.from == r.from && m.to == r.to && m.promo == r.promo);

    test('opening position: hard bot returns a legal move', () {
      final e = ChessEngine()..reset();
      final r = botSearchMove(job(e, 3));
      expect(isLegal(e, r), true);
    });

    test('middlegame: hard bot returns a legal move', () {
      final e = ChessEngine()..reset();
      mv(e, 52, 36); // e4
      mv(e, 12, 28); // e5
      mv(e, 62, 45); // Nf3
      mv(e, 1, 18); // Nc6
      final r = botSearchMove(job(e, 3));
      expect(isLegal(e, r), true);
    });

    test('bot finds mate in one', () {
      // White queen g6, white king f6, black king h8 → Qg7#.
      final c = _empty();
      c[22] = 5; // white queen g6
      c[21] = 6; // white king f6
      c[7] = -6; // black king h8
      final e = ChessEngine()..setPosition(c, true);
      final r = botSearchMove(job(e, 3));
      expect(isLegal(e, r), true);
      e.doMove(e.legalMoves().firstWhere(
          (m) => m.from == r.from && m.to == r.to && m.promo == r.promo));
      expect(e.legalMoves(), isEmpty);
      expect(e.inCheck, true);
    });

    test('50 random playouts: bot never plays an illegal move', () {
      for (int g = 0; g < 50; g++) {
        final e = ChessEngine()..reset();
        var plies = 0;
        while (plies < 24) {
          final moves = e.legalMoves();
          if (moves.isEmpty) break;
          final r = botSearchMove(BotJob(
            board: List<int>.from(e.board),
            white: e.whiteTurn,
            ep: e.ep,
            wk: e.wk,
            wq: e.wq,
            bk: e.bk,
            bq: e.bq,
            depth: 2,
            jitter: 40,
            seed: 1000 + g * 100 + plies,
          ));
          final pick = moves.firstWhere(
            (m) => m.from == r.from && m.to == r.to && m.promo == r.promo,
            orElse: () => moves.first,
          );
          // The bot must always return a move from the legal set.
          expect(
              moves.any((m) =>
                  m.from == r.from && m.to == r.to && m.promo == r.promo),
              true,
              reason: 'game $g ply $plies: illegal bot move');
          e.doMove(pick);
          if (e.drawReason() != null) break;
          plies++;
        }
      }
    });
  });
}

void mv(ChessEngine e, int from, int to) {
  e.doMove(e
      .legalMoves()
      .firstWhere((m) => m.from == from && m.to == to && m.promo == 0));
}
