/// Grand Chess Heritage — game board screen.
/// Marble board in a walnut frame, carved pieces, brass controls.
library;

import 'dart:math';
import 'package:flutter/material.dart';
import '../engine.dart';
import '../theme.dart';
import '../audio.dart';
import '../settings.dart';
import '../widgets/brass.dart';
import '../widgets/piece.dart';
import 'settings.dart';

class GameScreen extends StatefulWidget {
  final GameSettings settings;
  const GameScreen({super.key, required this.settings});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final _rand = Random();
  final eng = ChessEngine();

  int sel = -1;
  List<ChessMove> selMoves = [];
  List<ChessMove> allLegal = [];
  List<ChessMove> history = [];
  int lastFrom = -1, lastTo = -1;
  bool over = false;
  bool paused = false;
  bool checkNow = false;
  String? resultHeadline;
  String? resultSubline;
  bool humanWon = false;

  List<int> capturedByWhite = []; // black pieces
  List<int> capturedByBlack = []; // white pieces

  bool get vsBot => widget.settings.mode == GameMode.vsBot;
  bool get humanIsWhite => !widget.settings.botPlaysWhite;
  bool _botThinking = false;

  bool get _botTurn {
    if (!vsBot || over || paused) return false;
    return eng.whiteTurn != humanIsWhite;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _newGame();
    AudioService.I.gameMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !over) _persist();
  }

  Future<void> _persist() async {
    await GameStore.save({
      'engine': eng.toJson(),
      'history': history.map((m) => [m.from, m.to, m.promo, m.ep ? 1 : 0]).toList(),
      'capturedByWhite': capturedByWhite,
      'capturedByBlack': capturedByBlack,
      'lastFrom': lastFrom,
      'lastTo': lastTo,
      'difficulty': widget.settings.difficulty.index,
      'mode': widget.settings.mode.index,
      'botPlaysWhite': widget.settings.botPlaysWhite,
    });
  }

  void _newGame() {
    eng.reset();
    sel = -1;
    selMoves = [];
    history = [];
    lastFrom = lastTo = -1;
    over = false;
    paused = false;
    resultHeadline = null;
    capturedByWhite = [];
    capturedByBlack = [];
    _refreshLegal();
    GameStore.clear();
    AudioService.I.gameStart();
    _maybeBot();
  }

  void _refreshLegal() {
    allLegal = eng.legalMoves();
    checkNow = eng.inCheck;
  }

  void _tapSq(int s) {
    if (over || paused || _botTurn) return;
    final p = eng.board[s];
    final humanWhite = !vsBot || humanIsWhite;
    final humanBlack = !vsBot || !humanIsWhite;
    final myPiece = p != 0 &&
        ((p > 0 && eng.whiteTurn && (humanWhite || !vsBot)) ||
            (p < 0 && !eng.whiteTurn && (humanBlack || !vsBot)));
    // In 2P mode both sides are human; in vsBot only human's side taps.
    final canControl = !vsBot ||
        (eng.whiteTurn == humanIsWhite);

    if (sel != -1 && selMoves.any((m) => m.to == s)) {
      final cands = selMoves.where((m) => m.to == s).toList();
      if (cands.any((m) => m.promo != 0)) {
        _promoDialog(cands);
      } else {
        _doMove(cands.first);
      }
      return;
    }
    if (!canControl) return;
    if (myPiece) {
      setState(() {
        sel = s;
        selMoves = allLegal.where((m) => m.from == s).toList();
      });
      AudioService.I.click();
    } else if (sel != -1) {
      // tapped an illegal square — gentle feedback
      AudioService.I.invalid();
      setState(() {
        sel = -1;
        selMoves = [];
      });
    }
  }

  void _promoDialog(List<ChessMove> cands) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: ChessMaterials.walnutPanel(radius: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Promote pawn to…',
                  style: ChessType.display(context).copyWith(fontSize: 22)),
              const SizedBox(height: 6),
              const Text('Choose your piece',
                  style: ChessType.bodyDim),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [5, 4, 3, 2].map((pr) {
                  final mv = cands.firstWhere((m) => m.promo == pr);
                  final white = eng.whiteTurn;
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _doMove(mv);
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: ChessMaterials.brassPlaque(radius: 12),
                      alignment: Alignment.center,
                      child: CarvedPiece(
                          piece: white ? pr : -pr, size: 44),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _doMove(ChessMove m) {
    final white = eng.whiteTurn;
    final captured = m.ep ? eng.board[m.to + (white ? 8 : -8)] : eng.board[m.to];
    final isCastle = eng.board[m.from].abs() == 6 && (m.to - m.from).abs() == 2;
    if (captured != 0) {
      if (white) {
        capturedByWhite.add(captured.abs());
      } else {
        capturedByBlack.add(captured.abs());
      }
    }
    setState(() {
      eng.doMove(m);
      history.add(m);
      lastFrom = m.from;
      lastTo = m.to;
      sel = -1;
      selMoves = [];
    });
    if (m.promo != 0) {
      AudioService.I.promote();
    } else if (isCastle) {
      AudioService.I.castle();
    } else if (captured != 0) {
      AudioService.I.capture();
    } else {
      AudioService.I.move();
    }
    _refreshLegal();
    _persist();
    if (allLegal.isEmpty) {
      if (checkNow) {
        final whiteWon = !eng.whiteTurn;
        _finish(
          headline: whiteWon ? 'Checkmate — White wins' : 'Checkmate — Black wins',
          subline: _resultSubline(whiteWon),
          humanWon: !vsBot ? true : (whiteWon == humanIsWhite),
        );
      } else {
        _finish(
            headline: 'Stalemate',
            subline: 'No legal moves — a draw.',
            humanWon: false,
            draw: true);
      }
      return;
    }
    final drawReason = eng.drawReason();
    if (drawReason != null) {
      _finish(
          headline: 'Draw', subline: drawReason, humanWon: false, draw: true);
      return;
    }
    if (checkNow) AudioService.I.check();
    setState(() {});
    _maybeBot();
  }

  String _resultSubline(bool whiteWon) {
    if (!vsBot) return 'A hard-fought battle on the marble.';
    final humanWon = whiteWon == humanIsWhite;
    return humanWon
        ? 'Brilliant — the club applauds. 👏'
        : 'The engine prevails this time. Rematch?';
  }

  Future<void> _finish({
    required String headline,
    required String subline,
    required bool humanWon,
    bool draw = false,
  }) async {
    if (over) return;
    setState(() {
      over = true;
      resultHeadline = headline;
      resultSubline = subline;
      this.humanWon = humanWon;
    });
    await GameStore.clear();
    if (draw) {
      AudioService.I.draw();
    } else if (!vsBot || humanWon) {
      AudioService.I.win();
    } else {
      AudioService.I.lose();
    }
    // score tally (vs bot only)
    if (vsBot) {
      final (w, l, d) = await GameStore.loadScore();
      if (draw) {
        await GameStore.saveScore(w, l, d + 1);
      } else if (humanWon) {
        await GameStore.saveScore(w + 1, l, d);
      } else {
        await GameStore.saveScore(w, l + 1, d);
      }
    }
    if (mounted) _showGameOver();
  }

  void _showGameOver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: ChessMaterials.walnutPanel(radius: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // cinematic fallen-king motif: large king piece, tilted
              Transform.rotate(
                angle: 1.35,
                child: CarvedPiece(
                  piece: eng.whiteTurn ? 6 : -6,
                  size: 74,
                ),
              ),
              const SizedBox(height: 14),
              Text(resultHeadline ?? '',
                  textAlign: TextAlign.center,
                  style: ChessType.display(context).copyWith(fontSize: 26)),
              const SizedBox(height: 8),
              Text(resultSubline ?? '',
                  textAlign: TextAlign.center, style: ChessType.bodyDim),
              const SizedBox(height: 20),
              BrassButton(
                  label: 'Rematch',
                  onTap: () {
                    Navigator.pop(context);
                    setState(_newGame);
                  }),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Back to menu',
                    style: TextStyle(color: ChessPalette.brass)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- bot ----------
  void _maybeBot() {
    if (!_botTurn || _botThinking) return;
    _botThinking = true;
    final delay =
        widget.settings.difficulty == Difficulty.hard ? 900 : 700;
    Future.delayed(Duration(milliseconds: delay), () {
      _botThinking = false;
      if (!mounted || over || paused || !_botTurn) return;
      final pick = _chooseBotMove();
      if (pick != null) _doMove(pick);
    });
  }

  ChessMove? _chooseBotMove() {
    final moves = List<ChessMove>.from(allLegal);
    if (moves.isEmpty) return null;
    final white = eng.whiteTurn;
    switch (widget.settings.difficulty) {
      case Difficulty.easy:
        // 1-ply + heavy jitter, occasional blunder
        if (_rand.nextDouble() < 0.3) {
          return moves[_rand.nextInt(moves.length)];
        }
        return _bestOf(moves, white, 1, 120);
      case Difficulty.medium:
        return _bestOf(moves, white, 2, 40);
      case Difficulty.hard:
        return _bestOf(moves, white, 3, 15);
    }
  }

  ChessMove _bestOf(
      List<ChessMove> moves, bool white, int depth, int jitter) {
    // order: captures & promotions first
    moves.sort((a, b) {
      int sa = (eng.board[a.to] != 0 ? 1000 : 0) + (a.promo == 5 ? 900 : 0);
      int sb = (eng.board[b.to] != 0 ? 1000 : 0) + (b.promo == 5 ? 900 : 0);
      return sb.compareTo(sa);
    });
    int best = -1 << 30;
    ChessMove pick = moves.first;
    for (final m in moves) {
      final c = List<int>.from(eng.board);
      final epSave = eng.ep;
      applyBd(c, m, white);
      int score = -_search(c, !white, depth - 1, -1 << 28, 1 << 28, epSave);
      if (m.promo == 5) score += 50;
      score += _rand.nextInt(jitter * 2 + 1) - jitter;
      if (score > best) {
        best = score;
        pick = m;
      }
    }
    return pick;
  }

  int _search(List<int> bd, bool white, int depth, int alpha, int beta, int epSq) {
    if (depth <= 0) return _evaluate(bd, white);
    final moves = legalMovesWithEp(bd, white, epSq);
    if (moves.isEmpty) {
      return inCheckBd(bd, white) ? -100000 - depth : 0;
    }
    // simple ordering: captures first
    moves.sort((a, b) =>
        (bd[b.to] != 0 ? 1 : 0).compareTo(bd[a.to] != 0 ? 1 : 0));
    int best = -1 << 30;
    for (final m in moves.take(24)) {
      final c = List<int>.from(bd);
      applyBd(c, m, white);
      final s = -_search(c, !white, depth - 1, -beta, -alpha, -1);
      if (s > best) best = s;
      if (best > alpha) alpha = best;
      if (alpha >= beta) break;
    }
    return best;
  }

  int _evaluate(List<int> bd, bool white) {
    int s = ChessEngine.material(bd, white) - ChessEngine.material(bd, !white);
    // mobility sprinkle
    s += legalMovesFor(bd, white).length * 2;
    s -= legalMovesFor(bd, !white).length * 2;
    return s;
  }

  // ---------- pause ----------
  void _togglePause() {
    setState(() => paused = !paused);
    if (paused) {
      AudioService.I.stopMusic();
    } else {
      AudioService.I.gameMusic();
      _maybeBot();
    }
  }

  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final turnLabel = eng.whiteTurn ? 'White to move' : 'Black to move';
    final modeLabel = vsBot
        ? (humanIsWhite ? 'You (White) vs Computer' : 'You (Black) vs Computer')
        : 'Two players';
    return Scaffold(
      backgroundColor: ChessPalette.walnutDeep,
      appBar: AppBar(
        backgroundColor: ChessPalette.walnutDark,
        foregroundColor: ChessPalette.ivory,
        title: Text('Chess', style: ChessType.display(context).copyWith(fontSize: 22)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ChessPalette.brass),
          onPressed: () {
            AudioService.I.click();
            Navigator.pop(context);
          },
        ),
        actions: [
          BrassIconButton(
            icon: paused ? Icons.play_arrow : Icons.pause,
            tooltip: paused ? 'Resume' : 'Pause',
            onTap: _togglePause,
          ),
          const SizedBox(width: 8),
          BrassIconButton(
            icon: Icons.refresh,
            tooltip: 'New game',
            onTap: () => setState(_newGame),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: paused ? _pauseOverlay() : _boardView(turnLabel, modeLabel),
      ),
    );
  }

  Widget _boardView(String turnLabel, String modeLabel) {
    final topWhite = !vsBot || !humanIsWhite; // who sits at top
    return Column(
      children: [
        // top player panel
        _playerPanel(
          name: vsBot
              ? (humanIsWhite ? 'Computer (Black)' : 'You (Black)')
              : 'Black',
          isWhite: false,
          active: !eng.whiteTurn && !over,
          captured: topWhite ? capturedByBlack : capturedByWhite,
          whiteCaps: topWhite,
        ),
        // turn + mode strip
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (checkNow && !over)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ChessPalette.checkRed,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('CHECK',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              Text(over ? (resultHeadline ?? '') : turnLabel,
                  style: ChessType.bodyDim.copyWith(fontSize: 13)),
            ],
          ),
        ),
        // the marble board
        Expanded(
          child: Center(
            child: LayoutBuilder(
              builder: (ctx, c) {
                final side = min(c.maxWidth, c.maxHeight);
                return Container(
                  width: side,
                  height: side,
                  padding: EdgeInsets.all(side * 0.035),
                  decoration: ChessMaterials.boardFrame(),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 8),
                    itemCount: 64,
                    itemBuilder: (_, s) => _square(s),
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(modeLabel, style: ChessType.bodyDim.copyWith(fontSize: 11)),
        ),
        // bottom player panel
        _playerPanel(
          name: vsBot
              ? (humanIsWhite ? 'You (White)' : 'Computer (White)')
              : 'White',
          isWhite: true,
          active: eng.whiteTurn && !over,
          captured: topWhite ? capturedByWhite : capturedByBlack,
          whiteCaps: !topWhite,
        ),
        // move history strip
        _historyStrip(),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _playerPanel({
    required String name,
    required bool isWhite,
    required bool active,
    required List<int> captured,
    required bool whiteCaps,
  }) {
    final materialDiff = ChessEngine.material(eng.board, true) -
        ChessEngine.material(eng.board, false);
    final adv = isWhite ? materialDiff : -materialDiff;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? ChessPalette.walnutMid
            : ChessPalette.walnutDark.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? ChessPalette.brass : ChessPalette.walnutLine,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          CarvedPiece(piece: isWhite ? 6 : -6, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: ChessType.body.copyWith(
                        fontWeight:
                            active ? FontWeight.bold : FontWeight.normal)),
                if (adv > 0)
                  Text('+$adv',
                      style: const TextStyle(
                          color: ChessPalette.brass, fontSize: 11)),
              ],
            ),
          ),
          SizedBox(
            width: 150,
            child: CapturedTray(
                captured: captured, whiteCaptured: whiteCaps, pieceSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _historyStrip() {
    if (history.isEmpty) return const SizedBox(height: 26);
    final labels = <String>[];
    for (int i = 0; i < history.length; i += 2) {
      final w = history[i].label(_boardAt(i));
      final b = i + 1 < history.length ? history[i + 1].label(_boardAt(i + 1)) : '';
      labels.add('${i ~/ 2 + 1}. $w $b');
    }
    return Container(
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      child: ListView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        children: [
          for (final l in labels.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(l, style: ChessType.moveNotation),
            ),
        ],
      ),
    );
  }

  /// Reconstruct board state at move index (for notation labels).
  List<int> _boardAt(int moveIdx) {
    final e = ChessEngine()..reset();
    for (int i = 0; i < moveIdx && i < history.length; i++) {
      e.doMove(history[i]);
    }
    return e.board;
  }

  Widget _square(int s) {
    final light = (_r(s) + _c(s)) % 2 == 1;
    final isSel = s == sel;
    final isLast = s == lastFrom || s == lastTo;
    final mv = selMoves.where((m) => m.to == s).toList();
    final canMove = mv.isNotEmpty;
    final isCapture = canMove && (eng.board[s] != 0 || mv.first.ep);
    final kingSq = checkNow && eng.board[s] == (eng.whiteTurn ? 6 : -6);
    final p = eng.board[s];

    return GestureDetector(
      onTap: () => _tapSq(s),
      child: Container(
        decoration: (light
                ? ChessMaterials.marbleLight()
                : ChessMaterials.marbleDark())
            .copyWith(
          border: kingSq
              ? Border.all(color: ChessPalette.checkRed, width: 3)
              : null,
          color: isLast
              ? ChessPalette.lastMove.withValues(alpha: 0.45)
              : isSel
                  ? ChessPalette.selGold.withValues(alpha: 0.5)
                  : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (p != 0)
              TweenAnimationBuilder<double>(
                key: ValueKey('p$s$p'),
                tween: Tween(begin: 0.6, end: 1.0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.elasticOut,
                builder: (_, sc, child) => Transform.scale(
                  scale: sc,
                  child: CarvedPiece(piece: p, size: 34),
                ),
              ),
            if (canMove && !isCapture)
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: ChessPalette.feltDark.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: ChessPalette.brass.withValues(alpha: 0.7), width: 1),
                ),
              ),
            if (canMove && isCapture)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ChessPalette.checkRed, width: 3),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pauseOverlay() {
    return Center(
      child: WalnutCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Paused', style: ChessType.display(context)),
            const SizedBox(height: 6),
            const Text('The clock is stopped.',
                style: ChessType.bodyDim),
            const SizedBox(height: 20),
            BrassButton(label: 'Resume', onTap: _togglePause),
            const SizedBox(height: 10),
            BrassButton(
                label: 'Settings',
                onTap: () {
                  _openSettings();
                }),
            const SizedBox(height: 10),
            BrassButton(
                label: 'Restart',
                onTap: () => setState(_newGame)),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Quit to menu',
                  style: TextStyle(color: ChessPalette.brass)),
            ),
          ],
        ),
      ),
    );
  }
}

int _r(int s) => s ~/ 8;
int _c(int s) => s % 8;
