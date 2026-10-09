// Regression tests for the player-name fix round (2026-10-09).
//
// BUG: names were persisted with SharedPreferences.setStringList, which on
// Android is backed by an UNORDERED StringSet — White/Black names came back
// scrambled across slots after a restart. Names are now persisted as an
// order-preserving JSON string, and ChessMatch picks up renames live via
// refreshNames() so narration/banners/results never go stale.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess/game_controller.dart';
import 'package:chess/services/settings_service.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('player name persistence (order-preserving JSON)', () {
    test('names survive a simulated restart in the right slots', () async {
      SharedPreferences.setMockInitialValues({});
      final s = ChessSettings();
      await s.load();
      await s.setPlayerName(0, 'Aisha');
      await s.setPlayerName(1, 'Rookmaster');

      // Simulate an app restart: a brand-new settings instance.
      final restarted = ChessSettings();
      await restarted.load();
      expect(restarted.playerNames[0], 'Aisha');
      expect(restarted.playerNames[1], 'Rookmaster');
    });

    test('white and black names never swap slots across restarts', () async {
      SharedPreferences.setMockInitialValues({});
      final s = ChessSettings();
      await s.load();
      // Deliberately asymmetric names — any slot swap is caught.
      await s.setPlayerName(0, 'WhiteZed');
      await s.setPlayerName(1, 'BlackAlfa');
      for (int i = 0; i < 3; i++) {
        final restarted = ChessSettings();
        await restarted.load();
        expect(restarted.playerNames, ['WhiteZed', 'BlackAlfa']);
      }
    });

    test('empty rename falls back to the slot default', () async {
      SharedPreferences.setMockInitialValues({});
      final s = ChessSettings();
      await s.load();
      await s.setPlayerName(0, '   ');
      final restarted = ChessSettings();
      await restarted.load();
      expect(restarted.playerNames[0], 'White');
    });
  });

  group('live names in the match (refreshNames)', () {
    test('rename updates turn banner immediately', () {
      final m = _twoPlayer()..newGame();
      expect(m.banner, 'White to move');
      m.refreshNames(white: 'Aisha', black: 'Rookmaster');
      expect(m.nameOf(true), 'Aisha');
      expect(m.nameOf(false), 'Rookmaster');
      expect(m.banner, 'Aisha to move');
      m.dispose();
    });

    test('move narration uses the renamed player', () {
      final m = _twoPlayer()..newGame();
      m.refreshNames(white: 'Aisha', black: 'Rookmaster');
      m.tapSquare(52); // e2
      m.tapSquare(36); // e4
      expect(m.banner, startsWith('Aisha plays'));
      m.dispose();
    });

    test('result headlines use the renamed winner', () {
      final m = _twoPlayer()..newGame();
      m.refreshNames(white: 'Aisha', black: 'Rookmaster');
      // Fool's mate: f3 e5 g4 Qh4#
      for (final sq in [53, 45, 12, 28, 54, 38, 3, 39]) {
        m.tapSquare(sq);
        m.debugSettleForTest();
      }
      expect(m.over, true);
      expect(m.resultHeadline, contains('Rookmaster'));
      m.dispose();
    });
  });
}
