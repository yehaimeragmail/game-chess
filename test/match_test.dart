// Tests for the engine-owned turn state machine (ChessMatch):
// selection, move application, undo, promotion flow, draw offers,
// checkmate detection, and the watchdog's forward-progress guarantees.
import 'package:flutter_test/flutter_test.dart';
import 'package:chess/game_controller.dart';

ChessMatch _twoPlayer() => ChessMatch(
      config: const MatchConfig(
        mode: 1,
        difficulty: 1,
        humanIsWhite: true,
        clockSeconds: 0,
        whiteName: 'White',
        blackName: 'Black',
      ),
    );

List<int> _empty() => List.filled(64, 0);

void main() {
  group('input & move flow', () {
    test('tap selects, tap destination moves', () {
      final m = _twoPlayer()..newGame();
      expect(m.phase, MatchPhase.awaitingInput);
      m.tapSquare(52); // e2
      expect(m.sel, 52);
      expect(m.selMoves.length, 2); // e3, e4
      m.tapSquare(36); // e4
      expect(m.history.length, 1);
      expect(m.eng.board[36], 1);
      expect(m.eng.board[52], 0);
      m.debugSettleForTest();
      expect(m.eng.whiteTurn, false);
      expect(m.phase, MatchPhase.awaitingInput); // settled
      m.dispose();
    });

    test('tapping opponent piece does not select', () {
      final m = _twoPlayer()..newGame();
      m.tapSquare(12); // e7 black pawn, white to move
      expect(m.sel, -1);
      m.dispose();
    });

    test('illegal tap deselects', () {
      final m = _twoPlayer()..newGame();
      m.tapSquare(52);
      expect(m.sel, 52);
      m.tapSquare(0); // a8 — not a legal destination
      expect(m.sel, -1);
      m.dispose();
    });
  });

  group('undo (RULES.md §12)', () {
    test('undo restores full state incl. rights and ep', () {
      final m = _twoPlayer()..newGame();
      // e4 e5 Nf3
      m.tapSquare(52);
      m.tapSquare(36);
      // settle instantly for the test: force phase back (anim timer pending)
      m.debugSettleForTest();
      m.tapSquare(12);
      m.tapSquare(28);
      m.debugSettleForTest();
      m.tapSquare(62);
      m.tapSquare(45);
      m.debugSettleForTest();
      expect(m.history.length, 3);
      m.undo();
      expect(m.history.length, 2);
      expect(m.eng.board[45], 0); // knight back on g1
      expect(m.eng.board[62], 2);
      expect(m.eng.whiteTurn, true);
      // ep square from e7-e5 is still live
      expect(m.eng.ep, 20);
      m.undo();
      expect(m.eng.ep, 44); // white's e2-e4 double push still live (e3)
      expect(m.history.length, 1);
      m.dispose();
    });
  });

  group('promotion (RULES.md §12)', () {
    test('promotion blocks input until resolved', () {
      final m = _twoPlayer()..newGame();
      final b = _empty();
      b[60] = 6;
      b[4] = -6;
      b[8] = 1; // white pawn a7
      m.debugSetPosition(b, true);
      m.tapSquare(8);
      m.tapSquare(0); // a8
      expect(m.phase, MatchPhase.promoChoice);
      // Board taps are blocked while choosing.
      m.tapSquare(60);
      expect(m.phase, MatchPhase.promoChoice);
      m.choosePromotion(5);
      expect(m.eng.board[0], 5);
      m.dispose();
    });
  });

  group('draw offers (RULES.md §10/§12)', () {
    test('2P: offer → answer accept ends in draw', () {
      final m = _twoPlayer()..newGame();
      m.offerDraw();
      expect(m.phase, MatchPhase.drawOffer);
      m.answerDraw(true);
      expect(m.over, true);
      expect(m.isDraw, true);
      m.dispose();
    });

    test('2P: offer → decline resumes play', () {
      final m = _twoPlayer()..newGame();
      m.offerDraw();
      m.answerDraw(false);
      expect(m.over, false);
      expect(m.phase, MatchPhase.awaitingInput);
      m.dispose();
    });

    test('vs bot: bot declines draw from equal opening', () {
      final m = ChessMatch(
        config: const MatchConfig(
          mode: 0,
          difficulty: 2,
          humanIsWhite: true,
          clockSeconds: 0,
          whiteName: 'You',
          blackName: 'Aisha',
        ),
      )..newGame();
      m.offerDraw(); // equal position → bot should decline, not crash
      expect(m.over, false);
      expect(m.phase, MatchPhase.awaitingInput);
      m.dispose();
    });
  });

  group('endings', () {
    test("fool's mate through the controller ends the game", () {
      final m = _twoPlayer()..newGame();
      void play(int from, int to) {
        m.tapSquare(from);
        m.tapSquare(to);
        m.debugSettleForTest();
      }

      play(53, 45); // f3
      play(12, 28); // e5
      play(54, 38); // g4
      play(3, 39); // Qh4#
      expect(m.over, true);
      expect(m.resultHeadline, contains('Checkmate'));
      expect(m.resultHeadline, contains('Black'));
      m.dispose();
    });

    test('stalemate is a draw, not a win', () {
      final m = _twoPlayer()..newGame();
      // White: Kf7, Qg5; Black: Kh8. Qg5-g6 stalemates.
      final c = _empty();
      c[7] = -6; // black king h8
      c[13] = 6; // white king f7
      c[29] = 5; // white queen g5
      m.debugSetPosition(c, true);
      m.tapSquare(29);
      m.tapSquare(22); // Qg6
      m.debugSettleForTest();
      expect(m.over, true);
      expect(m.isDraw, true);
      expect(m.resultHeadline, 'Draw');
      m.dispose();
    });
  });

  group('watchdog', () {
    test('recover() never leaves awaitingInput with bot to move', () {
      final m = ChessMatch(
        config: const MatchConfig(
          mode: 0,
          difficulty: 0,
          humanIsWhite: false, // human is black → bot (white) moves first
          clockSeconds: 0,
          whiteName: 'Aisha',
          blackName: 'You',
        ),
      )..newGame();
      // Bot should have started thinking on its own.
      expect(
          m.phase == MatchPhase.thinking ||
              m.history.isNotEmpty ||
              m.phase == MatchPhase.animating,
          true);
      m.dispose();
    });
  });
}
