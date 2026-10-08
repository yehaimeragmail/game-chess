import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Full chess rules engine (pure logic, UI-free so it can be unit tested).
/// Pieces: 0 empty; white positive, black negative.
/// 1 pawn, 2 knight, 3 bishop, 4 rook, 5 queen, 6 king.
class ChessMove {
  final int from, to, promo; // promo: 0 or abs piece (2..5)
  final bool ep;
  const ChessMove(this.from, this.to, {this.promo = 0, this.ep = false});
}

class ChessEngine {
  List<int> board = List.filled(64, 0);
  bool whiteTurn = true;
  bool wk = true, wq = true, bk = true, bq = true;
  int ep = -1; // en-passant target square

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
  }

  List<ChessMove> legalMoves() =>
      _legal(board, whiteTurn, ep, whiteTurn ? wk : bk, whiteTurn ? wq : bq);

  bool get inCheck => _inCheckBd(board, whiteTurn);

  /// Applies a legal move, updating castling rights, en-passant and turn.
  void doMove(ChessMove m) {
    final p = board[m.from];
    int newEp = -1;
    if (p.abs() == 1 && (m.to - m.from).abs() == 16) newEp = (m.from + m.to) ~/ 2;
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
    ep = newEp;
    whiteTurn = !whiteTurn;
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
  for (final d in [
    [-2, -1], [-2, 1], [-1, -2], [-1, 2],
    [1, -2], [1, 2], [2, -1], [2, 1]
  ]) {
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

bool _inCheckBd(List<int> bd, bool white) => _attacked(bd, _kingSq(bd, white), !white);

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

List<ChessMove> _legal(List<int> bd, bool white, int epSq, bool kK, bool kQ) {
  return _pseudo(bd, white, epSq, kK, kQ).where((m) {
    final c = List<int>.from(bd);
    _applyBd(c, m, white);
    return !_inCheckBd(c, white);
  }).toList();
}

// ---------- UI ----------
class ChessScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const ChessScreen({super.key, required this.players, required this.callbacks});

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  final _rand = Random();
  final eng = ChessEngine();
  int sel = -1;
  List<ChessMove> selMoves = [];
  List<ChessMove> allLegal = [];
  int lastFrom = -1, lastTo = -1;
  bool over = false;
  bool checkNow = false;
  List<int> capturedW = []; // black pieces white captured
  List<int> capturedB = [];

  static const _glyph = ['', '♟', '♞', '♝', '♜', '♛', '♚'];

  @override
  void initState() {
    super.initState();
    _reset();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBot());
  }

  void _reset() {
    eng.reset();
    sel = -1;
    selMoves = [];
    lastFrom = lastTo = -1;
    over = false;
    capturedW = [];
    capturedB = [];
    _refreshLegal();
    widget.callbacks.setActivePlayer(0);
  }

  void _refreshLegal() {
    allLegal = eng.legalMoves();
    checkNow = eng.inCheck;
  }

  bool get _botTurn => widget.players[eng.whiteTurn ? 0 : 1].isBot;

  void _tapSq(int s) {
    if (over || _botTurn) return;
    final p = eng.board[s];
    if (sel != -1 && selMoves.any((m) => m.to == s)) {
      final cands = selMoves.where((m) => m.to == s).toList();
      if (cands.any((m) => m.promo != 0)) {
        _promoDialog(cands);
      } else {
        _doMove(cands.first);
      }
      return;
    }
    if (p != 0 && (p > 0) == eng.whiteTurn) {
      setState(() {
        sel = s;
        selMoves = allLegal.where((m) => m.from == s).toList();
      });
      Sfx.click();
    } else {
      setState(() {
        sel = -1;
        selMoves = [];
      });
    }
  }

  void _promoDialog(List<ChessMove> cands) {
    final t = ThemeController.of(context).theme;
    final pc = widget.players[eng.whiteTurn ? 0 : 1].color;
    showDialog(
      context: context,
      builder: (_) => WajihaDialog(
        title: 'Promote to… 👑',
        emoji: '♟️',
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [5, 4, 3, 2].map((pr) {
              final mv = cands.firstWhere((m) => m.promo == pr);
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _doMove(mv);
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: t.background, borderRadius: t.radius),
                  alignment: Alignment.center,
                  child: Text(_glyph[pr], style: TextStyle(fontSize: 38, color: pc)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _doMove(ChessMove m) {
    final white = eng.whiteTurn;
    final captured = m.ep ? eng.board[m.to + (white ? 8 : -8)] : eng.board[m.to];
    if (captured != 0) {
      if (white) {
        capturedW.add(captured.abs());
      } else {
        capturedB.add(captured.abs());
      }
    }
    final moverIdx = white ? 0 : 1;
    setState(() {
      eng.doMove(m);
      lastFrom = m.from;
      lastTo = m.to;
      sel = -1;
      selMoves = [];
    });
    Sfx.move();
    _refreshLegal();
    final mover = widget.players[moverIdx];
    if (allLegal.isEmpty) {
      if (checkNow) {
        mover.score += 1;
        widget.callbacks.refreshHud();
        _finish(winner: mover, headline: 'Checkmate! ${mover.name} rules the board! 👑');
      } else {
        _finish(headline: "Stalemate! Nobody blinks. 🤝", subline: 'A draw — rematch?');
      }
      return;
    }
    setState(() {});
    widget.callbacks.setActivePlayer(eng.whiteTurn ? 0 : 1);
    _maybeBot();
  }

  void _finish({Player? winner, required String headline, String? subline}) {
    if (over) return;
    setState(() => over = true);
    if (winner != null) {
      Sfx.win();
    } else {
      Sfx.lose();
    }
    widget.callbacks.finish(winner: winner, headline: headline, subline: subline);
  }

  // ---------- bot: 1-ply, piece values + jitter, occasional blunder ----------
  void _maybeBot() {
    if (over || !_botTurn) return;
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted || over) return;
      final moves = List<ChessMove>.from(allLegal);
      if (moves.isEmpty) return;
      final white = eng.whiteTurn;
      ChessMove pick;
      if (_rand.nextDouble() < 0.25) {
        pick = moves[_rand.nextInt(moves.length)]; // bold blunder mode 😅
      } else {
        int best = -1 << 30;
        pick = moves.first;
        for (final m in moves) {
          final c = List<int>.from(eng.board);
          _applyBd(c, m, white);
          int score = ChessEngine.material(c, white) - ChessEngine.material(c, !white);
          final replies = _legal(c, !white, -1, false, false);
          if (replies.isEmpty && _inCheckBd(c, !white)) score += 100000; // mate!
          if (m.promo == 5) score += 800;
          score += _rand.nextInt(60) - 30; // positional jitter
          if (score > best) {
            best = score;
            pick = m;
          }
        }
      }
      _doMove(pick);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final cur = widget.players[eng.whiteTurn ? 0 : 1];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          if (!over)
            TurnBanner(
                player: cur,
                action: checkNow
                    ? ' is in CHECK! 😱'
                    : (cur.isBot ? ' is thinking… 🤖' : ', your move! ♟️')),
          const SizedBox(height: 8),
          _capturedRow(capturedB, widget.players[1], t),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: t.radius,
                    boxShadow: [
                      BoxShadow(
                          color: t.primary.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 10))
                    ],
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                    itemCount: 64,
                    itemBuilder: (_, s) => _square(s, t),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _capturedRow(capturedW, widget.players[0], t),
          const SizedBox(height: 8),
          Text('Tap a piece, then tap a glowing square ✨',
              style: TextStyle(color: t.muted, fontSize: 12)),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _capturedRow(List<int> caps, Player p, GameTheme t) {
    return SizedBox(
      height: 22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('${p.emoji} ', style: const TextStyle(fontSize: 14)),
          ...caps.map((a) =>
              Text(_glyph[a], style: TextStyle(fontSize: 18, color: p.color.withValues(alpha: 0.75)))),
          if (caps.isEmpty)
            Text('no captures yet', style: TextStyle(color: t.muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _square(int s, GameTheme t) {
    final light = (_r(s) + _c(s)) % 2 == 1;
    final isSel = s == sel;
    final isLast = s == lastFrom || s == lastTo;
    final mv = selMoves.where((m) => m.to == s).toList();
    final canMove = mv.isNotEmpty;
    final isCapture = canMove && (eng.board[s] != 0 || mv.first.ep);
    final kingInCheckSq = checkNow && eng.board[s] == (eng.whiteTurn ? 6 : -6);
    final p = eng.board[s];
    Color bg = light ? t.surface : t.primary.withValues(alpha: 0.35);
    if (isLast) bg = t.secondary.withValues(alpha: light ? 0.35 : 0.55);
    if (isSel) bg = t.accent.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: () => _tapSq(s),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          border: kingInCheckSq ? Border.all(color: Colors.red, width: 3) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (p != 0)
              TweenAnimationBuilder<double>(
                key: ValueKey('p$s$p'),
                tween: Tween(begin: 0.5, end: 1.0),
                duration: const Duration(milliseconds: 180),
                curve: Curves.elasticOut,
                builder: (_, sc, child) => Transform.scale(
                  scale: sc,
                  child: Text(
                    _glyph[p.abs()],
                    style: TextStyle(
                      fontSize: 30,
                      color: (p > 0 ? widget.players[0] : widget.players[1]).color,
                      shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
                    ),
                  ),
                ),
              ),
            if (canMove && !isCapture)
              Container(
                width: 12,
                height: 12,
                decoration:
                    BoxDecoration(color: t.accent.withValues(alpha: 0.85), shape: BoxShape.circle),
              ),
            if (canMove && isCapture)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: t.accent, width: 3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
