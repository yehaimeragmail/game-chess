/// Pure chess rules engine — UI-free, deterministic, unit-testable.
/// Pieces: 0 empty; white positive, black negative.
/// 1 pawn, 2 knight, 3 bishop, 4 rook, 5 queen, 6 king.
/// Authoritative rules: stitch-batch1/chess/RULES.md
library;

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
    // Insufficient material
    final pieces = board.where((p) => p != 0 && p.abs() != 6).toList();
    if (pieces.isEmpty) return 'Bare kings — draw';
    if (pieces.length == 1 && (pieces.first.abs() == 3 || pieces.first.abs() == 2)) {
      return 'Insufficient material — draw';
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
