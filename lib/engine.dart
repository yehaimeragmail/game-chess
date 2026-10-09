/// Pure chess rules engine — UI-free, deterministic, unit-testable.
/// Pieces: 0 empty; white positive, black negative.
/// 1 pawn, 2 knight, 3 bishop, 4 rook, 5 queen, 6 king.
/// Authoritative rules: stitch-batch1/chess/RULES.md
library;

import 'dart:math';

/// A chess move. `promo`: 0 or abs piece (2..5). `ep`: en-passant capture.
class ChessMove {
  final int from, to, promo;
  final bool ep;
  const ChessMove(this.from, this.to, {this.promo = 0, this.ep = false});

  /// Algebraic-ish notation for history display.
  String label(List<int> board) {
    const files = 'abcdefgh';
    String sq(int s) => '${files[s % 8]}${8 - s ~/ 8}';
    const glyph = ['', '', 'N', 'B', 'R', 'Q', 'K'];
    final p = board[from].abs();
    final piece = p == 1 ? '' : glyph[p];
    final cap = board[to] != 0 || ep ? 'x' : '';
    final pr = promo != 0 ? '=${glyph[promo]}' : '';
    if (p == 6 && (to - from).abs() == 2) {
      return to > from ? 'O-O' : 'O-O-O';
    }
    return '$piece${p == 1 && cap.isNotEmpty ? files[from % 8] : ''}$cap${sq(to)}$pr';
  }
}

class ChessEngine {
  List<int> board = List.filled(64, 0);
  bool whiteTurn = true;
  bool wk = true, wq = true, bk = true, bq = true;
  int ep = -1; // en-passant target square
  int halfmove = 0; // for fifty-move rule
  final List<String> positionHistory = [];

  static const values = {1: 100, 2: 320, 3: 330, 4: 500, 5: 900, 6: 0};

  void reset() {
    board = List.filled(64, 0);
    const back = [4, 2, 3, 5, 6, 3, 2, 4];
    for (int c = 0; c < 8; c++) {
      board[c] = -back[c];
      board[8 + c] = -1;
      board[48 + c] = 1;
      board[56 + c] = back[c];
    }
    whiteTurn = true;
    wk = wq = bk = bq = true;
    ep = -1;
    halfmove = 0;
    positionHistory
      ..clear()
      ..add(_posKey());
  }

  List<ChessMove> legalMoves() =>
      _legal(board, whiteTurn, ep, whiteTurn ? wk : bk, whiteTurn ? wq : bq);

  bool get inCheck => _inCheckBd(board, whiteTurn);

  /// Applies a legal move, updating castling rights, en-passant and turn.
  void doMove(ChessMove m) {
    final p = board[m.from];
    final captured = m.ep ? board[m.to + (whiteTurn ? 8 : -8)] : board[m.to];
    int newEp = -1;
    if (p.abs() == 1 && (m.to - m.from).abs() == 16) {
      newEp = (m.from + m.to) ~/ 2;
    }
    if (p.abs() == 6) {
      if (whiteTurn) {
        wk = false;
        wq = false;
      } else {
        bk = false;
        bq = false;
      }
    }
    for (final sq in [56, 63, 0, 7]) {
      if (m.from == sq || m.to == sq) {
        if (sq == 63) wk = false;
        if (sq == 56) wq = false;
        if (sq == 7) bk = false;
        if (sq == 0) bq = false;
      }
    }
    _applyBd(board, m, whiteTurn);
    // fifty-move clock
    halfmove = (p.abs() == 1 || captured != 0) ? 0 : halfmove + 1;
    ep = newEp;
    whiteTurn = !whiteTurn;
    positionHistory.add(_posKey());
  }

  String _posKey() {
    final sb = StringBuffer();
    for (final p in board) {
      sb.write(p.toString());
      sb.write(',');
    }
    sb.write(whiteTurn ? 'w' : 'b');
    sb.write(wk ? 'K' : '');
    sb.write(wq ? 'Q' : '');
    sb.write(bk ? 'k' : '');
    sb.write(bq ? 'q' : '');
    sb.write('e$ep');
    return sb.toString();
  }

  /// Draw detection per RULES.md: stalemate handled by caller (no legal moves).
  /// Returns a reason string, or null if no draw.
  String? drawReason() {
    // Insufficient material: no pawns/rooks/queens, and the remaining
    // minor pieces cannot force (or even deliver) checkmate.
    final minorSq = <int>[];
    var heavy = false;
    for (int i = 0; i < 64; i++) {
      final a = board[i].abs();
      if (a == 0 || a == 6) continue;
      if (a == 1 || a == 4 || a == 5) {
        heavy = true;
        break;
      }
      minorSq.add(i);
    }
    if (!heavy) {
      if (minorSq.isEmpty) return 'Bare kings — draw';
      if (minorSq.length == 1) {
        return 'Insufficient material — draw'; // K+B vs K, K+N vs K
      }
      // Bishops only, all on the same square color: no mate possible.
      if (minorSq.every((i) => board[i].abs() == 3) &&
          minorSq.map((i) => (_r(i) + _c(i)) % 2).toSet().length == 1) {
        return 'Insufficient material — draw';
      }
      // NOTE: K+N+N vs K is NOT an automatic draw (mate is possible
      // with cooperation), so it falls through deliberately.
    }
    // Fifty-move rule
    if (halfmove >= 100) return 'Fifty-move rule — draw';
    // Threefold repetition
    final key = positionHistory.last;
    if (positionHistory.where((k) => k == key).length >= 3) {
      return 'Threefold repetition — draw';
    }
    return null;
  }

  /// Serialize full state for persistence / undo.
  Map<String, dynamic> toJson() => {
        'board': List<int>.from(board),
        'whiteTurn': whiteTurn,
        'wk': wk,
        'wq': wq,
        'bk': bk,
        'bq': bq,
        'ep': ep,
        'halfmove': halfmove,
        'history': List<String>.from(positionHistory),
      };

  void fromJson(Map<String, dynamic> j) {
    board = List<int>.from(j['board']);
    whiteTurn = j['whiteTurn'];
    wk = j['wk'];
    wq = j['wq'];
    bk = j['bk'];
    bq = j['bq'];
    ep = j['ep'];
    halfmove = j['halfmove'] ?? 0;
    positionHistory
      ..clear()
      ..addAll(List<String>.from(j['history'] ?? [_posKey()]));
  }

  /// Install an arbitrary position (tests / setup). Rights default to none.
  void setPosition(List<int> newBoard, bool whiteToMove,
      {bool wk = false,
      bool wq = false,
      bool bk = false,
      bool bq = false,
      int ep = -1,
      int halfmove = 0}) {
    board = List<int>.from(newBoard);
    whiteTurn = whiteToMove;
    this.wk = wk;
    this.wq = wq;
    this.bk = bk;
    this.bq = bq;
    this.ep = ep;
    this.halfmove = halfmove;
    positionHistory
      ..clear()
      ..add(_posKey());
  }

  static int material(List<int> bd, bool white) {
    int s = 0;
    for (final p in bd) {
      if (p != 0 && (p > 0) == white) s += values[p.abs()]!;
    }
    return s;
  }
}

// ---------- pure helpers ----------
int _r(int s) => s ~/ 8;
int _c(int s) => s % 8;
bool _on(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

bool _attacked(List<int> bd, int sq, bool byWhite) {
  final r = _r(sq), c = _c(sq);
  final pr = byWhite ? r + 1 : r - 1;
  for (final dc in [-1, 1]) {
    if (_on(pr, c + dc)) {
      final p = bd[pr * 8 + c + dc];
      if (p != 0 && p.abs() == 1 && (p > 0) == byWhite) return true;
    }
  }
  const knd = [
    [-2, -1], [-2, 1], [-1, -2], [-1, 2],
    [1, -2], [1, 2], [2, -1], [2, 1]
  ];
  for (final d in knd) {
    final nr = r + d[0], nc = c + d[1];
    if (_on(nr, nc)) {
      final p = bd[nr * 8 + nc];
      if (p != 0 && p.abs() == 2 && (p > 0) == byWhite) return true;
    }
  }
  for (int dr = -1; dr <= 1; dr++) {
    for (int dc = -1; dc <= 1; dc++) {
      if (dr == 0 && dc == 0) continue;
      final nr = r + dr, nc = c + dc;
      if (_on(nr, nc)) {
        final p = bd[nr * 8 + nc];
        if (p != 0 && p.abs() == 6 && (p > 0) == byWhite) return true;
      }
    }
  }
  const dirs = [
    [-1, 0], [1, 0], [0, -1], [0, 1],
    [-1, -1], [-1, 1], [1, -1], [1, 1]
  ];
  for (int i = 0; i < 8; i++) {
    final diag = i >= 4;
    int nr = r + dirs[i][0], nc = c + dirs[i][1];
    while (_on(nr, nc)) {
      final p = bd[nr * 8 + nc];
      if (p != 0) {
        if ((p > 0) == byWhite) {
          final a = p.abs();
          if (a == 5 || (a == 4 && !diag) || (a == 3 && diag)) return true;
        }
        break;
      }
      nr += dirs[i][0];
      nc += dirs[i][1];
    }
  }
  return false;
}

int _kingSq(List<int> bd, bool white) {
  final k = white ? 6 : -6;
  for (int i = 0; i < 64; i++) {
    if (bd[i] == k) return i;
  }
  return -1;
}

bool _inCheckBd(List<int> bd, bool white) =>
    _attacked(bd, _kingSq(bd, white), !white);

void _applyBd(List<int> bd, ChessMove m, bool white) {
  final p = bd[m.from];
  if (m.ep) bd[m.to + (white ? 8 : -8)] = 0;
  bd[m.to] = m.promo != 0 ? (white ? m.promo : -m.promo) : p;
  bd[m.from] = 0;
  if (p.abs() == 6 && (m.to - m.from).abs() == 2) {
    if (m.to > m.from) {
      bd[m.to - 1] = bd[m.to + 1];
      bd[m.to + 1] = 0;
    } else {
      bd[m.to + 1] = bd[m.to - 2];
      bd[m.to - 2] = 0;
    }
  }
}

List<ChessMove> _pseudo(List<int> bd, bool white, int epSq, bool kK, bool kQ) {
  final ms = <ChessMove>[];
  final dir = white ? -1 : 1;
  final startRow = white ? 6 : 1;
  final promoRow = white ? 0 : 7;

  void steps(int s, List<List<int>> ds) {
    final r = _r(s), c = _c(s);
    for (final d in ds) {
      final nr = r + d[0], nc = c + d[1];
      if (!_on(nr, nc)) continue;
      final t = bd[nr * 8 + nc];
      if (t == 0 || (t > 0) != white) ms.add(ChessMove(s, nr * 8 + nc));
    }
  }

  void slides(int s, List<List<int>> ds) {
    final r = _r(s), c = _c(s);
    for (final d in ds) {
      int nr = r + d[0], nc = c + d[1];
      while (_on(nr, nc)) {
        final t = bd[nr * 8 + nc];
        if (t == 0) {
          ms.add(ChessMove(s, nr * 8 + nc));
        } else {
          if ((t > 0) != white) ms.add(ChessMove(s, nr * 8 + nc));
          break;
        }
        nr += d[0];
        nc += d[1];
      }
    }
  }

  const ortho = [
    [-1, 0], [1, 0], [0, -1], [0, 1]
  ];
  const diag = [
    [-1, -1], [-1, 1], [1, -1], [1, 1]
  ];
  const all8 = [
    [-1, 0], [1, 0], [0, -1], [0, 1],
    [-1, -1], [-1, 1], [1, -1], [1, 1]
  ];
  const kn = [
    [-2, -1], [-2, 1], [-1, -2], [-1, 2],
    [1, -2], [1, 2], [2, -1], [2, 1]
  ];

  for (int s = 0; s < 64; s++) {
    final p = bd[s];
    if (p == 0 || (p > 0) != white) continue;
    final r = _r(s), c = _c(s), a = p.abs();
    if (a == 1) {
      final one = (r + dir) * 8 + c;
      if (_on(r + dir, c) && bd[one] == 0) {
        if (r + dir == promoRow) {
          for (final pr in [5, 4, 3, 2]) {
            ms.add(ChessMove(s, one, promo: pr));
          }
        } else {
          ms.add(ChessMove(s, one));
          final two = (r + 2 * dir) * 8 + c;
          if (r == startRow && bd[two] == 0) ms.add(ChessMove(s, two));
        }
      }
      for (final dc in [-1, 1]) {
        final nr = r + dir, nc = c + dc;
        if (!_on(nr, nc)) continue;
        final t = bd[nr * 8 + nc];
        if (t != 0 && (t > 0) != white) {
          if (nr == promoRow) {
            for (final pr in [5, 4, 3, 2]) {
              ms.add(ChessMove(s, nr * 8 + nc, promo: pr));
            }
          } else {
            ms.add(ChessMove(s, nr * 8 + nc));
          }
        } else if (nr * 8 + nc == epSq) {
          ms.add(ChessMove(s, epSq, ep: true));
        }
      }
    } else if (a == 2) {
      steps(s, kn);
    } else if (a == 3) {
      slides(s, diag);
    } else if (a == 4) {
      slides(s, ortho);
    } else if (a == 5) {
      slides(s, all8);
    } else {
      steps(s, all8);
      final home = white ? 60 : 4;
      if (s == home && !_attacked(bd, home, !white)) {
        if (kK &&
            bd[home + 1] == 0 &&
            bd[home + 2] == 0 &&
            !_attacked(bd, home + 1, !white) &&
            !_attacked(bd, home + 2, !white)) {
          ms.add(ChessMove(home, home + 2));
        }
        if (kQ &&
            bd[home - 1] == 0 &&
            bd[home - 2] == 0 &&
            bd[home - 3] == 0 &&
            !_attacked(bd, home - 1, !white) &&
            !_attacked(bd, home - 2, !white)) {
          ms.add(ChessMove(home, home - 2));
        }
      }
    }
  }
  return ms;
}

/// Public legal-move generator for bot use (no castling-rights threading needed).
List<ChessMove> legalMovesFor(List<int> bd, bool white) {
  // Conservative: no castling info → callers pass current rights when known.
  return _legal(bd, white, -1, false, false);
}

/// Full legal-move generator with en-passant square (for search).
List<ChessMove> legalMovesWithEp(List<int> bd, bool white, int epSq) =>
    _legal(bd, white, epSq, false, false);

List<ChessMove> _legal(List<int> bd, bool white, int epSq, bool kK, bool kQ) {
  return _pseudo(bd, white, epSq, kK, kQ).where((m) {
    final c = List<int>.from(bd);
    _applyBd(c, m, white);
    return !_inCheckBd(c, white);
  }).toList();
}

bool inCheckBd(List<int> bd, bool white) => _inCheckBd(bd, white);
void applyBd(List<int> bd, ChessMove m, bool white) => _applyBd(bd, m, white);

// ---------------------------------------------------------------------------
// Bot search — RULES.md §11.
//
// Runs on a background isolate via compute(): everything here is pure Dart
// with no Flutter imports. [botSearchMove] is the top-level entry point.
//
// Difficulties: Easy = depth 1 + heavy randomness, Medium = depth 2 +
// quiescence, Hard = depth 4 + quiescence + move ordering.
// Evaluation: material + piece-square tables + mobility + king pawn-shield
// + pawn structure, per RULES.md §11.
// ---------------------------------------------------------------------------

/// Piece-square tables, white's perspective, a8-first index order
/// (matches our board indexing: index 0 = a8).
const _pstPawn = [
  0, 0, 0, 0, 0, 0, 0, 0,
  50, 50, 50, 50, 50, 50, 50, 50,
  10, 10, 20, 30, 30, 20, 10, 10,
  5, 5, 10, 25, 25, 10, 5, 5,
  0, 0, 0, 20, 20, 0, 0, 0,
  5, -5, -10, 0, 0, -10, -5, 5,
  5, 10, 10, -20, -20, 10, 10, 5,
  0, 0, 0, 0, 0, 0, 0, 0,
];
const _pstKnight = [
  -50, -40, -30, -30, -30, -30, -40, -50,
  -40, -20, 0, 0, 0, 0, -20, -40,
  -30, 0, 10, 15, 15, 10, 0, -30,
  -30, 5, 15, 20, 20, 15, 5, -30,
  -30, 0, 15, 20, 20, 15, 0, -30,
  -30, 5, 10, 15, 15, 10, 5, -30,
  -40, -20, 0, 5, 5, 0, -20, -40,
  -50, -40, -30, -30, -30, -30, -40, -50,
];
const _pstBishop = [
  -20, -10, -10, -10, -10, -10, -10, -20,
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 10, 10, 5, 0, -10,
  -10, 5, 5, 10, 10, 5, 5, -10,
  -10, 0, 10, 10, 10, 10, 0, -10,
  -10, 10, 10, 10, 10, 10, 10, -10,
  -10, 5, 0, 0, 0, 0, 5, -10,
  -20, -10, -10, -10, -10, -10, -10, -20,
];
const _pstRook = [
  0, 0, 0, 0, 0, 0, 0, 0,
  5, 10, 10, 10, 10, 10, 10, 5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  0, 0, 0, 5, 5, 0, 0, 0,
];
const _pstQueen = [
  -20, -10, -10, -5, -5, -10, -10, -20,
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 5, 5, 5, 0, -10,
  -5, 0, 5, 5, 5, 5, 0, -5,
  0, 0, 5, 5, 5, 5, 0, -5,
  -10, 5, 5, 5, 5, 5, 0, -10,
  -10, 0, 5, 0, 0, 0, 0, -10,
  -20, -10, -10, -5, -5, -10, -10, -20,
];
const _pstKing = [
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -20, -30, -30, -40, -40, -30, -30, -20,
  -10, -20, -20, -20, -20, -20, -20, -10,
  20, 20, 0, 0, 0, 0, 20, 20,
  20, 30, 10, 0, 0, 10, 30, 20,
];
const _psts = {
  1: _pstPawn,
  2: _pstKnight,
  3: _pstBishop,
  4: _pstRook,
  5: _pstQueen,
  6: _pstKing,
};

int _mirror(int s) => (7 - s ~/ 8) * 8 + (s % 8);

/// Cheap static eval: material + piece-square tables, from [white]'s view.
int _staticEval(List<int> bd, bool white) {
  var s = 0;
  for (var i = 0; i < 64; i++) {
    final p = bd[i];
    if (p == 0) continue;
    final a = p.abs();
    final w = p > 0;
    final v = ChessEngine.values[a]! + (w ? _psts[a]![i] : _psts[a]![_mirror(i)]);
    s += w ? v : -v;
  }
  return white ? s : -s;
}

/// King pawn-shield: friendly pawns directly in front of the king.
int _kingShield(List<int> bd, bool white) {
  final k = _kingSq(bd, white);
  if (k < 0) return 0;
  final r = _r(k), c = _c(k);
  final dir = white ? -1 : 1;
  final pawn = white ? 1 : -1;
  var s = 0;
  for (final dc in [-1, 0, 1]) {
    final nr = r + dir, nc = c + dc;
    if (_on(nr, nc) && bd[nr * 8 + nc] == pawn) s += 14;
  }
  return s;
}

/// Pawn structure: doubled / isolated pawn penalties, from [white]'s view.
int _pawnStructure(List<int> bd, bool white) {
  var s = 0;
  for (var side = 0; side < 2; side++) {
    final w = side == 0;
    final pawn = w ? 1 : -1;
    final files = List<int>.filled(8, 0);
    for (var i = 0; i < 64; i++) {
      if (bd[i] == pawn) files[i % 8]++;
    }
    var pen = 0;
    for (var f = 0; f < 8; f++) {
      if (files[f] > 1) pen += 12 * (files[f] - 1); // doubled
      if (files[f] > 0) {
        final left = f > 0 ? files[f - 1] : 0;
        final right = f < 7 ? files[f + 1] : 0;
        if (left == 0 && right == 0) pen += 9; // isolated
      }
    }
    s += (w == white ? -pen : pen);
  }
  return s;
}

/// Rich eval used at depth-0 nodes: static + mobility + king safety +
/// pawn structure, from [white]'s view.
int _richEval(List<int> bd, bool white, int ep) {
  var s = _staticEval(bd, white);
  s += _kingShield(bd, white) - _kingShield(bd, !white);
  s += _pawnStructure(bd, white);
  // Mobility sprinkle (cheap full move-gen at depth 0 only).
  s += _legal(bd, white, ep, false, false).length * 3;
  s -= _legal(bd, !white, ep, false, false).length * 3;
  return s;
}

/// En-passant square resulting from [m] played on [bd] (before the move).
int _newEp(List<int> bd, ChessMove m) {
  final p = bd[m.from];
  if (p.abs() == 1 && (m.to - m.from).abs() == 16) {
    return (m.from + m.to) ~/ 2;
  }
  return -1;
}

/// Castling rights [wk, wq, bk, bq] after [m] is played on [bd].
List<bool> _rightsAfter(List<int> bd, ChessMove m, bool white,
    bool wk, bool wq, bool bk, bool bq) {
  var nwk = wk, nwq = wq, nbk = bk, nbq = bq;
  if (bd[m.from].abs() == 6) {
    if (white) {
      nwk = false;
      nwq = false;
    } else {
      nbk = false;
      nbq = false;
    }
  }
  if (m.from == 63 || m.to == 63) nwk = false;
  if (m.from == 56 || m.to == 56) nwq = false;
  if (m.from == 7 || m.to == 7) nbk = false;
  if (m.from == 0 || m.to == 0) nbq = false;
  return [nwk, nwq, nbk, nbq];
}

/// MVV-LVA-ish ordering: captures and promotions first.
void _orderMoves(List<int> bd, List<ChessMove> moves) {
  int score(ChessMove m) {
    var s = 0;
    final victim = bd[m.to].abs();
    if (victim != 0) {
      s += 10000 + ChessEngine.values[victim]! - ChessEngine.values[bd[m.from].abs()]! ~/ 16;
    }
    if (m.ep) s += 10050;
    if (m.promo != 0) s += 9000 + ChessEngine.values[m.promo]!;
    final a = bd[m.from].abs();
    if (a == 6 && (m.to - m.from).abs() == 2) s += 500; // castle late
    return s;
  }

  moves.sort((a, b) => score(b).compareTo(score(a)));
}

/// Captures + promotions only (for quiescence), all fully legal.
List<ChessMove> _tacticalMoves(List<int> bd, bool white, int ep) {
  return _pseudo(bd, white, ep, false, false)
      .where((m) => bd[m.to] != 0 || m.promo != 0 || m.ep)
      .where((m) {
        final c = List<int>.from(bd);
        _applyBd(c, m, white);
        return !_inCheckBd(c, white);
      })
      .toList();
}

class _SearchCtx {
  int nodes = 0;
  int maxNodes = 250000;
}

const _mateScore = 100000;

int _quiesce(List<int> bd, bool white, int ep, int alpha, int beta, int ply,
    _SearchCtx ctx) {
  ctx.nodes++;
  if (ctx.nodes > ctx.maxNodes) return _staticEval(bd, white);
  if (_inCheckBd(bd, white)) {
    // In check: must consider all evasions, not just captures.
    final moves = _legal(bd, white, ep, false, false);
    if (moves.isEmpty) return -_mateScore + ply;
    _orderMoves(bd, moves);
    var best = -1 << 30;
    for (final m in moves) {
      final c = List<int>.from(bd);
      _applyBd(c, m, white);
      final s = -_quiesce(c, !white, _newEp(bd, m), -beta, -alpha, ply + 1, ctx);
      if (s > best) best = s;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }
  final stand = _staticEval(bd, white);
  if (stand >= beta) return beta;
  if (stand > alpha) alpha = stand;
  if (ply <= 0) return alpha;
  final moves = _tacticalMoves(bd, white, ep);
  _orderMoves(bd, moves);
  for (final m in moves.take(8)) {
    final c = List<int>.from(bd);
    _applyBd(c, m, white);
    final s = -_quiesce(c, !white, _newEp(bd, m), -beta, -alpha, ply - 1, ctx);
    if (s >= beta) return beta;
    if (s > alpha) alpha = s;
  }
  return alpha;
}

int _searchDeep(List<int> bd, bool white, int ep, bool wk, bool wq, bool bk,
    bool bq, int depth, int alpha, int beta, int ply, int qDepth,
    _SearchCtx ctx) {
  ctx.nodes++;
  if (ctx.nodes > ctx.maxNodes) return _staticEval(bd, white);
  if (depth <= 0) {
    return -_quiesceLeaf(bd, white, ep, qDepth, ctx, ply);
  }
  final inChk = _inCheckBd(bd, white);
  final moves = _legal(bd, white, ep, white ? wk : bk, white ? wq : bq);
  if (moves.isEmpty) return inChk ? -_mateScore + ply : 0;
  _orderMoves(bd, moves);
  var best = -1 << 30;
  final width = ply <= 1 ? moves.length : min(moves.length, 14);
  for (var i = 0; i < width; i++) {
    final m = moves[i];
    final c = List<int>.from(bd);
    _applyBd(c, m, white);
    final nr = _rightsAfter(bd, m, white, wk, wq, bk, bq);
    final s = -_searchDeep(c, !white, _newEp(bd, m), nr[0], nr[1], nr[2], nr[3],
        depth - 1, -beta, -alpha, ply + 1, qDepth, ctx);
    if (s > best) best = s;
    if (best > alpha) alpha = best;
    if (alpha >= beta) break;
  }
  return best;
}

/// Depth-0 leaf: rich eval + quiescence on top (negated back).
int _quiesceLeaf(List<int> bd, bool white, int ep, int qDepth, _SearchCtx ctx,
    int ply) {
  final stand = _richEval(bd, white, ep);
  final alpha = -1 << 28, beta = 1 << 28;
  // Quiescence works from the side-to-move's perspective; combine.
  final q = _quiesce(bd, white, ep, alpha, beta, qDepth, ctx);
  // Blend: quiescence refines tactics, rich eval grounds position.
  return (stand + q) ~/ 2;
}

/// Isolate-safe bot job: plain data only.
class BotJob {
  final List<int> board;
  final bool white;
  final int ep;
  final bool wk, wq, bk, bq;
  final int depth;
  final int jitter;
  final int seed;
  final bool randomPick; // easy mode: sometimes play fully random

  const BotJob({
    required this.board,
    required this.white,
    required this.ep,
    required this.wk,
    required this.wq,
    required this.bk,
    required this.bq,
    required this.depth,
    required this.jitter,
    required this.seed,
    this.randomPick = false,
  });
}

class BotResult {
  final int from, to, promo;
  final int score;
  const BotResult(this.from, this.to, this.promo, this.score);
}

/// Top-level entry point for compute(): never plays an illegal move —
/// every candidate comes from the legal move generator.
BotResult botSearchMove(BotJob job) {
  final rand = Random(job.seed);
  final bd = job.board;
  final kK = job.white ? job.wk : job.bk;
  final kQ = job.white ? job.wq : job.bq;
  final moves = _legal(bd, job.white, job.ep, kK, kQ);
  if (moves.isEmpty) {
    return const BotResult(-1, -1, 0, 0); // caller guarantees non-empty
  }
  if (moves.length == 1 || (job.randomPick && rand.nextDouble() < 0.35)) {
    final m = moves[rand.nextInt(moves.length)];
    return BotResult(m.from, m.to, m.promo, 0);
  }
  _orderMoves(bd, moves);
  final ctx = _SearchCtx();
  final qDepth = job.depth >= 3 ? 4 : 2;
  var best = -1 << 30;
  var pick = moves.first;
  for (final m in moves) {
    final c = List<int>.from(bd);
    _applyBd(c, m, job.white);
    final nep = _newEp(bd, m);
    final nr = _rightsAfter(bd, m, job.white, job.wk, job.wq, job.bk, job.bq);
    final s = -_searchDeep(c, !job.white, nep, nr[0], nr[1], nr[2], nr[3],
        job.depth - 1, -1 << 28, 1 << 28, 1, qDepth, ctx);
    var scored = s;
    if (m.promo == 5) scored += 30;
    scored += rand.nextInt(job.jitter * 2 + 1) - job.jitter;
    if (scored > best) {
      best = scored;
      pick = m;
    }
    if (ctx.nodes > ctx.maxNodes) break;
  }
  return BotResult(pick.from, pick.to, pick.promo, best);
}

/// Synchronous quick evaluation for draw-offer decisions (UI thread).
/// Positive = good for [white].
int quickEval(List<int> bd, bool white, int ep) => _richEval(bd, white, ep);
