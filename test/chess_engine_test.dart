import 'package:flutter_test/flutter_test.dart';
import 'package:chess/game_screen.dart';

List<int> _empty() => List.filled(64, 0);

void main() {
  test('initial position: white has 20 legal moves', () {
    final e = ChessEngine()..reset();
    expect(e.legalMoves().length, 20);
  });

  test('after e2-e4 black still has 20', () {
    final e = ChessEngine()..reset();
    e.doMove(e.legalMoves().firstWhere((m) => m.from == 52 && m.to == 36));
    expect(e.whiteTurn, false);
    expect(e.legalMoves().length, 20);
  });

  test("fool's mate is checkmate", () {
    final e = ChessEngine()..reset();
    mv(e, 53, 45); // f2-f3
    mv(e, 12, 28); // e7-e5
    mv(e, 54, 38); // g2-g4
    mv(e, 3, 39); // Qd8-h4#
    expect(e.whiteTurn, true);
    expect(e.legalMoves(), isEmpty);
    expect(e.inCheck, true);
  });

  test('kingside castling moves king and rook', () {
    final e = ChessEngine();
    e.board = _empty();
    e.board[60] = 6;
    e.board[63] = 4;
    e.board[4] = -6;
    e.whiteTurn = true;
    e.wk = true;
    final castle = e.legalMoves().where((m) => m.from == 60 && m.to == 62);
    expect(castle.isNotEmpty, true);
    e.doMove(castle.first);
    expect(e.board[62], 6);
    expect(e.board[61], 4);
    expect(e.wk, false);
  });

  test('castling blocked when passing through check', () {
    final e = ChessEngine();
    e.board = _empty();
    e.board[60] = 6;
    e.board[63] = 4;
    e.board[4] = -6;
    e.board[14] = -4; // black rook g7 attacks g1
    e.whiteTurn = true;
    e.wk = true;
    expect(e.legalMoves().where((m) => m.from == 60 && m.to == 62), isEmpty);
  });

  test('en passant capture works', () {
    final e = ChessEngine();
    e.board = _empty();
    e.board[60] = 6;
    e.board[4] = -6;
    e.board[26] = 1; // white pawn c5
    e.board[11] = -1; // black pawn c7
    e.whiteTurn = false;
    mv(e, 11, 27); // c7-c5 double push
    expect(e.ep, 19);
    final eps = e.legalMoves().where((m) => m.from == 26 && m.to == 19 && m.ep);
    expect(eps.isNotEmpty, true);
    e.doMove(eps.first);
    expect(e.board[19], 1);
    expect(e.board[27], 0); // captured pawn removed
  });

  test('promotion generates 4 options and applies', () {
    final e = ChessEngine();
    e.board = _empty();
    e.board[60] = 6;
    e.board[4] = -6;
    e.board[8] = 1; // white pawn a7
    e.whiteTurn = true;
    final promos = e.legalMoves().where((m) => m.from == 8 && m.to == 0).toList();
    expect(promos.map((m) => m.promo).toSet(), {2, 3, 4, 5});
    e.doMove(promos.firstWhere((m) => m.promo == 5));
    expect(e.board[0], 5);
  });

  test('stalemate: no moves, not in check', () {
    final e = ChessEngine();
    e.board = _empty();
    e.board[7] = -6; // black king h8
    e.board[13] = 6; // white king f7
    e.board[22] = 5; // white queen g6
    e.whiteTurn = false;
    expect(e.inCheck, false);
    expect(e.legalMoves(), isEmpty);
  });

  test('pinned piece cannot move', () {
    final e = ChessEngine();
    e.board = _empty();
    e.board[60] = 6; // white king e1
    e.board[52] = 3; // white bishop e2 (pinned)
    e.board[4] = -4; // black rook e8
    e.board[0] = -6;
    e.whiteTurn = true;
    // bishop is absolutely pinned; only king moves (and bishop has none)
    expect(e.legalMoves().where((m) => m.from == 52), isEmpty);
  });

  test('knight in center has 8 moves', () {
    final e = ChessEngine();
    e.board = _empty();
    e.board[60] = 6;
    e.board[4] = -6;
    e.board[35] = 2; // Nd4
    e.whiteTurn = true;
    expect(e.legalMoves().where((m) => m.from == 35).length, 8);
  });
}

void mv(ChessEngine e, int from, int to) {
  e.doMove(e.legalMoves().firstWhere((m) => m.from == from && m.to == to && m.promo == 0));
}
