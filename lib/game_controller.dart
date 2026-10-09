/// ChessMatch — engine-owned turn state machine for Chess.
///
/// The match (not UI timers) owns every turn phase and settles moves on its
/// own timers; a watchdog recovers any phase found without a live driver, so
/// stuck states are impossible by construction. Mirrors the Ludo exemplar.
///
/// Phases:
///   awaitingInput — a human must tap (selection / move / promotion choice).
///   thinking      — bot search running on a background isolate.
///   animating     — a move's visible piece animation is in flight.
///   promoChoice   — human promotion dialog is open (input blocked).
///   drawOffer     — 2P draw offer awaiting the opponent's answer.
///   over          — terminal; result fields are set.
///
/// Bot moves always play out visibly: the isolate result is applied through
/// the same animated path as human moves, with narration on the banner.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'engine.dart';

/// Turn phases owned entirely by the match. The UI only renders.
enum MatchPhase {
  awaitingInput,
  thinking,
  animating,
  promoChoice,
  drawOffer,
  over,
}

/// UI-level events for audio / haptics. Set by the screen.
enum MatchEvent {
  select,
  move,
  capture,
  check,
  castle,
  promote,
  invalid,
  gameStart,
  humanWon,
  botWon,
  draw,
  botThinking,
  flag,
}

/// Static per-match configuration (from ChessSettings at game start).
class MatchConfig {
  final int mode; // 0 = vs bot, 1 = two players
  final int difficulty; // 0 easy, 1 medium, 2 hard
  final bool humanIsWhite;
  final int clockSeconds; // 0 = off, else 60/180/300/600
  final String whiteName;
  final String blackName;

  const MatchConfig({
    required this.mode,
    required this.difficulty,
    required this.humanIsWhite,
    required this.clockSeconds,
    required this.whiteName,
    required this.blackName,
  });

  bool get vsBot => mode == 0;

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'difficulty': difficulty,
        'humanIsWhite': humanIsWhite,
        'clockSeconds': clockSeconds,
        'whiteName': whiteName,
        'blackName': blackName,
      };

  static MatchConfig fromJson(Map<String, dynamic> j) => MatchConfig(
        mode: j['mode'] ?? 0,
        difficulty: j['difficulty'] ?? 1,
        humanIsWhite: j['humanIsWhite'] ?? true,
        clockSeconds: j['clockSeconds'] ?? 0,
        whiteName: j['whiteName'] ?? 'White',
        blackName: j['blackName'] ?? 'Black',
      );
}

/// A piece move in flight (visual). The logical move is applied at once;
/// the UI interpolates the piece from [from] to [to].
class MoveAnim {
  final int from, to;
  final int piece; // signed piece moving
  final int? capturedPiece; // abs value of captured piece (fades out)
  final int captureSq; // square where the capture happened
  final bool isCastle;
  final int rookFrom, rookTo;
  final DateTime startedAt = DateTime.now();
  final int totalMs;

  MoveAnim({
    required this.from,
    required this.to,
    required this.piece,
    this.capturedPiece,
    required this.captureSq,
    this.isCastle = false,
    this.rookFrom = -1,
    this.rookTo = -1,
    required this.totalMs,
  });

  double get progress {
    final e = DateTime.now().difference(startedAt).inMilliseconds;
    return (e / totalMs).clamp(0.0, 1.0);
  }

  bool get expired => progress >= 1.0;
}

class ChessMatch extends ChangeNotifier {
  final MatchConfig config;
  final ChessEngine eng = ChessEngine();

  MatchPhase phase = MatchPhase.awaitingInput;
  List<ChessMove> legalCache = [];
  int sel = -1;
  List<ChessMove> selMoves = [];
  List<ChessMove> _promoCands = [];
  List<MoveAnim> anims = [];
  List<ChessMove> history = [];
  List<int> capturedByWhite = []; // black pieces, abs values
  List<int> capturedByBlack = []; // white pieces, abs values
  int lastFrom = -1, lastTo = -1;
  bool checkNow = false;
  String banner = '';
  String resultHeadline = '';
  String resultSubline = '';
  bool humanWon = false;
  bool isDraw = false;
  bool over = false;
  int fullmove = 1;

  // Clocks (ms remaining). Only used when config.clockSeconds > 0.
  int whiteMs = 0;
  int blackMs = 0;
  int _lastTickSecond = -1;

  final List<Map<String, dynamic>> _undoStack = [];
  Timer? _timer; // single phase-transition timer
  Timer? _watchdog; // stuck-state recovery
  Timer? _clockTimer; // 100ms clock ticker
  bool _disposed = false;
  bool paused = false;
  Future<BotResult>? _botFuture;
  BotResult? _pendingBot; // isolate finished while paused

  /// UI hook for sounds. Set by the screen.
  void Function(MatchEvent event)? onEvent;

  ChessMatch({required this.config});

  bool get vsBot => config.vsBot;
  bool get clocksOn => config.clockSeconds > 0;

  /// Live name overrides, refreshed from ChessSettings after renames.
  /// MatchConfig freezes names at game start; these keep narration, banners
  /// and result headlines showing the CURRENT names ("Aisha plays Nf3")
  /// even when the player renames mid-game or after a saved-game resume.
  String? _whiteNameLive;
  String? _blackNameLive;

  String nameOf(bool white) => white
      ? (_whiteNameLive ?? config.whiteName)
      : (_blackNameLive ?? config.blackName);

  /// Point the match at the latest persisted names. Safe to call any time;
  /// turn/thinking banners showing stale names are refreshed in place.
  void refreshNames({required String white, required String black}) {
    final staleTurn = _turnBanner();
    final staleThinking = '$_botName is thinking…';
    final staleUp = '$_botName is up…';
    _whiteNameLive = white;
    _blackNameLive = black;
    if (banner == staleTurn ||
        banner == staleThinking ||
        banner == staleUp) {
      banner = _turnBanner();
    }
    notifyListeners();
  }

  bool _botToMove() =>
      vsBot && !over && eng.whiteTurn != config.humanIsWhite;

  bool get _humanToMove => !over && !_botToMove();

  String get _moverName => nameOf(eng.whiteTurn);

  String get _botName => nameOf(!config.humanIsWhite);

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watchdog?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  void _arm(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Pause: freeze phase + clock timers. Resume re-arms via the watchdog.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      _timer?.cancel();
      _timer = null;
      _clockTimer?.cancel();
      _clockTimer = null;
    } else {
      if (_pendingBot != null) {
        final res = _pendingBot!;
        _pendingBot = null;
        _playBotMove(res);
      }
      _ensureClock();
      _recover();
    }
    notifyListeners();
  }

  /// Watchdog: recover any phase found without a live driver. Respects
  /// [paused]. Makes stuck states impossible by construction.
  void _recover() {
    if (_disposed || over || paused || _timer != null) return;
    if (phase == MatchPhase.thinking) {
      if (_botFuture == null && _pendingBot == null) _startBotThink();
    } else if (phase == MatchPhase.animating) {
      if (anims.isEmpty || anims.every((a) => a.expired)) _settleAnim();
    } else if (phase == MatchPhase.awaitingInput && _botToMove()) {
      _startBotThink();
    }
    _ensureClock();
  }

  // ------------------------------------------------------------ lifecycle
  void newGame() {
    _timer?.cancel();
    _clockTimer?.cancel();
    paused = false;
    eng.reset();
    phase = MatchPhase.awaitingInput;
    sel = -1;
    selMoves = [];
    _promoCands = [];
    anims = [];
    history = [];
    capturedByWhite = [];
    capturedByBlack = [];
    lastFrom = -1;
    lastTo = -1;
    checkNow = false;
    over = false;
    isDraw = false;
    humanWon = false;
    resultHeadline = '';
    resultSubline = '';
    fullmove = 1;
    _undoStack.clear();
    _botFuture = null;
    _pendingBot = null;
    if (clocksOn) {
      whiteMs = config.clockSeconds * 1000;
      blackMs = config.clockSeconds * 1000;
      _lastTickSecond = -1;
    }
    _refreshLegal();
    banner = _turnBanner();
    notifyListeners();
    onEvent?.call(MatchEvent.gameStart);
    _ensureClock();
    _afterPhase();
    _watchdog ??=
        Timer.periodic(const Duration(seconds: 3), (_) => _recover());
  }

  /// Restore a persisted game (backgrounding / resume from menu).
  void restore(Map<String, dynamic> saved) {
    try {
      eng.fromJson(Map<String, dynamic>.from(saved['eng']));
      history = (saved['hist'] as List)
          .map((e) => ChessMove(e[0], e[1], promo: e[2], ep: e[3] == 1))
          .toList();
      capturedByWhite = List<int>.from(saved['cbw'] ?? []);
      capturedByBlack = List<int>.from(saved['cbb'] ?? []);
      lastFrom = saved['lf'] ?? -1;
      lastTo = saved['lt'] ?? -1;
      whiteMs = saved['wms'] ?? 0;
      blackMs = saved['bms'] ?? 0;
      fullmove = (history.length ~/ 2) + 1;
    } catch (_) {
      newGame();
      return;
    }
    phase = MatchPhase.awaitingInput;
    sel = -1;
    selMoves = [];
    anims = [];
    over = false;
    isDraw = false;
    paused = false;
    _undoStack.clear();
    _refreshLegal();
    banner = _turnBanner();
    notifyListeners();
    _ensureClock();
    _afterPhase();
    _watchdog ??=
        Timer.periodic(const Duration(seconds: 3), (_) => _recover());
  }

  /// Full snapshot for persistence (backgrounding / app kill).
  Map<String, dynamic> snapshot() => {
        'eng': eng.toJson(),
        'hist': history
            .map((m) => [m.from, m.to, m.promo, m.ep ? 1 : 0])
            .toList(),
        'cbw': capturedByWhite,
        'cbb': capturedByBlack,
        'lf': lastFrom,
        'lt': lastTo,
        'wms': whiteMs,
        'bms': blackMs,
        'config': config.toJson(),
      };

  void _refreshLegal() {
    legalCache = eng.legalMoves();
    checkNow = eng.inCheck;
  }

  String _turnBanner() {
    if (_botToMove()) return '$_botName is up…';
    return '$_moverName to move';
  }

  /// Called whenever we enter awaitingInput: bots move themselves.
  void _afterPhase() {
    if (over || phase != MatchPhase.awaitingInput || paused) return;
    if (_botToMove()) _startBotThink();
  }

  // ------------------------------------------------------------------ input
  /// Human taps a square. Guarded: correct phase, human's turn.
  void tapSquare(int s) {
    if (over ||
        paused ||
        phase != MatchPhase.awaitingInput ||
        !_humanToMove) {
      return;
    }
    // A tapped legal destination of the selected piece → move.
    if (sel != -1) {
      final cands = selMoves.where((m) => m.to == s).toList();
      if (cands.isNotEmpty) {
        if (cands.any((m) => m.promo != 0)) {
          _promoCands = cands;
          phase = MatchPhase.promoChoice;
          onEvent?.call(MatchEvent.select);
          notifyListeners();
          return;
        }
        _applyMove(cands.first,
            moverLabel: '${nameOf(eng.whiteTurn)} plays');
        return;
      }
    }
    final p = eng.board[s];
    final mine = p != 0 && (p > 0) == eng.whiteTurn;
    if (mine) {
      sel = s;
      selMoves = legalCache.where((m) => m.from == s).toList();
      onEvent?.call(MatchEvent.select);
      notifyListeners();
    } else if (sel != -1) {
      sel = -1;
      selMoves = [];
      onEvent?.call(MatchEvent.invalid);
      notifyListeners();
    }
  }

  /// Human picked a promotion piece from the dialog.
  void choosePromotion(int promoPiece) {
    if (phase != MatchPhase.promoChoice) return;
    final cands = _promoCands.where((m) => m.promo == promoPiece).toList();
    _promoCands = [];
    if (cands.isEmpty) {
      phase = MatchPhase.awaitingInput;
      notifyListeners();
      return;
    }
    _applyMove(cands.first,
        moverLabel: '${nameOf(eng.whiteTurn)} plays');
  }

  void cancelPromotion() {
    if (phase != MatchPhase.promoChoice) return;
    _promoCands = [];
    sel = -1;
    selMoves = [];
    phase = MatchPhase.awaitingInput;
    notifyListeners();
  }

  // -------------------------------------------------------------- move flow
  void _applyMove(ChessMove m, {required String moverLabel}) {
    _pushUndo();
    final white = eng.whiteTurn;
    final captured =
        m.ep ? eng.board[m.to + (white ? 8 : -8)] : eng.board[m.to];
    final isCastle = eng.board[m.from].abs() == 6 && (m.to - m.from).abs() == 2;
    if (captured != 0) {
      if (white) {
        capturedByWhite.add(captured.abs());
      } else {
        capturedByBlack.add(captured.abs());
      }
    }
    final label = m.label(eng.board);
    final piece = eng.board[m.from];
    eng.doMove(m);
    if (!white) fullmove++;
    history.add(m);
    lastFrom = m.from;
    lastTo = m.to;
    sel = -1;
    selMoves = [];
    _promoCands = [];

    var rookFrom = -1, rookTo = -1;
    if (isCastle) {
      if (m.to > m.from) {
        rookFrom = m.to + 1;
        rookTo = m.to - 1;
      } else {
        rookFrom = m.to - 2;
        rookTo = m.to + 1;
      }
    }
    anims = [
      MoveAnim(
        from: m.from,
        to: m.to,
        piece: piece,
        capturedPiece: captured != 0 ? captured.abs() : null,
        captureSq: m.ep ? m.to + (white ? 8 : -8) : m.to,
        isCastle: isCastle,
        rookFrom: rookFrom,
        rookTo: rookTo,
        totalMs: isCastle ? 520 : 380,
      )
    ];
    phase = MatchPhase.animating;
    banner = '$moverLabel $label';
    if (m.promo != 0) {
      onEvent?.call(MatchEvent.promote);
    } else if (isCastle) {
      onEvent?.call(MatchEvent.castle);
    } else if (captured != 0) {
      onEvent?.call(MatchEvent.capture);
    } else {
      onEvent?.call(MatchEvent.move);
    }
    notifyListeners();
    _arm(Duration(milliseconds: anims.first.totalMs + 60), _settleAnim);
  }

  /// Engine-owned settle — the UI never calls this. No desync possible.
  void _settleAnim() {
    if (over || phase != MatchPhase.animating || _disposed) return;
    anims = [];
    _refreshLegal();
    if (legalCache.isEmpty) {
      if (checkNow) {
        _finishCheckmate(!eng.whiteTurn);
      } else {
        _finishDraw('Stalemate — no legal moves.');
      }
      return;
    }
    final dr = eng.drawReason();
    if (dr != null) {
      _finishDraw(dr);
      return;
    }
    phase = MatchPhase.awaitingInput;
    if (checkNow) {
      banner = 'Check! ${_turnBanner()}';
      onEvent?.call(MatchEvent.check);
    } else {
      banner = _turnBanner();
    }
    notifyListeners();
    _afterPhase();
  }

  void _finishCheckmate(bool whiteWon) {
    over = true;
    isDraw = false;
    phase = MatchPhase.over;
    anims = [];
    final winnerName = nameOf(whiteWon);
    resultHeadline = 'Checkmate — $winnerName wins';
    if (!vsBot) {
      resultSubline = 'A hard-fought battle on the marble.';
      humanWon = true; // a human won either way in 2P
    } else {
      humanWon = whiteWon == config.humanIsWhite;
      resultSubline = humanWon
          ? 'Brilliant — the club applauds.'
          : 'The engine prevails this time. Rematch?';
    }
    banner = resultHeadline;
    notifyListeners();
    onEvent?.call(
        !vsBot || humanWon ? MatchEvent.humanWon : MatchEvent.botWon);
  }

  void _finishDraw(String reason) {
    over = true;
    isDraw = true;
    humanWon = false;
    phase = MatchPhase.over;
    anims = [];
    resultHeadline = 'Draw';
    resultSubline = reason;
    banner = 'Draw — $reason';
    notifyListeners();
    onEvent?.call(MatchEvent.draw);
  }

  void _finishResign(bool whiteWon) {
    over = true;
    isDraw = false;
    phase = MatchPhase.over;
    anims = [];
    final winnerName = nameOf(whiteWon);
    final loserName = nameOf(!whiteWon);
    resultHeadline = '$loserName resigns — $winnerName wins';
    if (!vsBot) {
      humanWon = true;
      resultSubline = 'A graceful concession.';
    } else {
      humanWon = whiteWon == config.humanIsWhite;
      resultSubline =
          humanWon ? 'The engine tips its king.' : 'Better luck next time.';
    }
    banner = resultHeadline;
    notifyListeners();
    onEvent?.call(
        !vsBot || humanWon ? MatchEvent.humanWon : MatchEvent.botWon);
  }

  void _finishFlag(bool whiteWon) {
    over = true;
    isDraw = false;
    phase = MatchPhase.over;
    anims = [];
    _clockTimer?.cancel();
    _clockTimer = null;
    final winnerName = nameOf(whiteWon);
    resultHeadline = 'Time! $winnerName wins on the clock';
    if (!vsBot) {
      humanWon = true;
      resultSubline = 'The flag fell.';
    } else {
      humanWon = whiteWon == config.humanIsWhite;
      resultSubline = humanWon
          ? 'Cool under time pressure.'
          : 'The clock is a cruel opponent.';
    }
    banner = resultHeadline;
    notifyListeners();
    onEvent?.call(MatchEvent.flag);
    onEvent?.call(
        !vsBot || humanWon ? MatchEvent.humanWon : MatchEvent.botWon);
  }

  // ------------------------------------------------------------------- bot
  void _startBotThink() {
    if (_disposed ||
        over ||
        paused ||
        phase != MatchPhase.awaitingInput ||
        !_botToMove()) {
      return;
    }
    phase = MatchPhase.thinking;
    banner = '$_botName is thinking…';
    onEvent?.call(MatchEvent.botThinking);
    notifyListeners();
    if (legalCache.length == 1) {
      final m = legalCache.first;
      _playBotMove(BotResult(m.from, m.to, m.promo, 0));
      return;
    }
    final d = config.difficulty;
    final job = BotJob(
      board: List<int>.from(eng.board),
      white: eng.whiteTurn,
      ep: eng.ep,
      wk: eng.wk,
      wq: eng.wq,
      bk: eng.bk,
      bq: eng.bq,
      depth: d == 0 ? 1 : (d == 1 ? 2 : 4),
      jitter: d == 0 ? 220 : (d == 1 ? 60 : 12),
      seed: DateTime.now().microsecondsSinceEpoch,
      randomPick: d == 0,
    );
    _botFuture = compute(botSearchMove, job);
    _botFuture!.then((res) {
      _botFuture = null;
      if (_disposed || over) return;
      if (paused || phase != MatchPhase.thinking) {
        // Paused mid-think (or phase moved on): hold the result.
        _pendingBot = res;
        return;
      }
      _playBotMove(res);
    });
  }

  void _playBotMove(BotResult res) {
    if (_disposed || over) return;
    // Match the isolate result against current legal moves (never trust it
    // blindly — the position cannot change under us, but be safe anyway).
    final cands = legalCache
        .where((m) =>
            m.from == res.from && m.to == res.to && m.promo == res.promo)
        .toList();
    final pick = cands.isNotEmpty
        ? cands.first
        : legalCache
            .where((m) => m.from == res.from && m.to == res.to)
            .firstOrNull;
    if (pick == null || legalCache.isEmpty) {
      // Should never happen; watchdog will recover.
      phase = MatchPhase.awaitingInput;
      notifyListeners();
      return;
    }
    _applyMove(pick, moverLabel: '$_botName plays');
  }

  // ----------------------------------------------------------- draw / undo
  /// Explicit draw offer (RULES.md §12: draws only via explicit UI actions).
  void offerDraw() {
    if (over ||
        paused ||
        phase != MatchPhase.awaitingInput ||
        !_humanToMove) {
      return;
    }
    if (vsBot) {
      // The bot accepts only when clearly worse.
      final evalForBot = quickEval(eng.board, !config.humanIsWhite, eng.ep);
      if (evalForBot < -120 || (eng.halfmove > 80 && evalForBot < 40)) {
        _finishDraw('Draw agreed — $_botName accepts.');
      } else {
        banner = '$_botName declines the draw.';
        onEvent?.call(MatchEvent.invalid);
        notifyListeners();
      }
    } else {
      phase = MatchPhase.drawOffer;
      banner = '$_moverName offers a draw…';
      onEvent?.call(MatchEvent.select);
      notifyListeners();
    }
  }

  void answerDraw(bool accept) {
    if (phase != MatchPhase.drawOffer || over) return;
    if (accept) {
      _finishDraw('Draw by mutual agreement.');
    } else {
      phase = MatchPhase.awaitingInput;
      banner = 'Draw declined — play on. ${_turnBanner()}';
      notifyListeners();
    }
  }

  /// Side to move resigns (RULES.md §9). The bot never resigns on its own.
  void resign() {
    if (over || paused) return;
    _finishResign(!eng.whiteTurn);
  }

  bool get canUndo =>
      _undoStack.isNotEmpty &&
      !over &&
      !paused &&
      (phase == MatchPhase.awaitingInput);

  void _pushUndo() {
    _undoStack.add(snapshot());
    if (_undoStack.length > 240) _undoStack.removeAt(0);
  }

  /// Undo restores the FULL state: board, castling rights, en-passant,
  /// half-move clock, history, captured trays, clocks (RULES.md §12).
  void undo() {
    if (!canUndo) return;
    if (vsBot) {
      // Undo the full round: keep popping until it's the human's turn.
      do {
        _restoreSnap(_undoStack.removeLast());
      } while (_undoStack.isNotEmpty && _botToMove());
    } else {
      _restoreSnap(_undoStack.removeLast());
    }
    banner = _turnBanner();
    notifyListeners();
    _afterPhase();
  }

  void _restoreSnap(Map<String, dynamic> snap) {
    eng.fromJson(Map<String, dynamic>.from(snap['eng']));
    history = (snap['hist'] as List)
        .map((e) => ChessMove(e[0], e[1], promo: e[2], ep: e[3] == 1))
        .toList();
    capturedByWhite = List<int>.from(snap['cbw'] ?? []);
    capturedByBlack = List<int>.from(snap['cbb'] ?? []);
    lastFrom = snap['lf'] ?? -1;
    lastTo = snap['lt'] ?? -1;
    whiteMs = snap['wms'] ?? whiteMs;
    blackMs = snap['bms'] ?? blackMs;
    fullmove = (history.length ~/ 2) + 1;
    sel = -1;
    selMoves = [];
    _promoCands = [];
    anims = [];
    over = false;
    isDraw = false;
    phase = MatchPhase.awaitingInput;
    _refreshLegal();
  }

  // ---------------------------------------------------------------- clocks
  void _ensureClock() {
    if (!clocksOn || _clockTimer != null || _disposed) return;
    _clockTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_disposed || paused || over) return;
      switch (phase) {
        case MatchPhase.awaitingInput:
        case MatchPhase.thinking:
        case MatchPhase.animating:
        case MatchPhase.promoChoice:
        case MatchPhase.drawOffer:
          break;
        case MatchPhase.over:
          return;
      }
      if (eng.whiteTurn) {
        whiteMs -= 100;
        if (whiteMs <= 0) {
          whiteMs = 0;
          _finishFlag(false);
          return;
        }
      } else {
        blackMs -= 100;
        if (blackMs <= 0) {
          blackMs = 0;
          _finishFlag(true);
          return;
        }
      }
      final sec = (eng.whiteTurn ? whiteMs : blackMs) ~/ 1000;
      if (sec != _lastTickSecond) {
        _lastTickSecond = sec;
        notifyListeners();
      }
    });
  }

  static String clockLabel(int ms) {
    final total = (ms / 1000).ceil();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Test hook: install an arbitrary position and refresh derived state.
  @visibleForTesting
  void debugSetPosition(List<int> board, bool whiteTurn) {    eng.setPosition(board, whiteTurn);
    sel = -1;
    selMoves = [];
    _promoCands = [];
    anims = [];
    history = [];
    capturedByWhite = [];
    capturedByBlack = [];
    lastFrom = -1;
    lastTo = -1;
    phase = MatchPhase.awaitingInput;
    over = false;
    isDraw = false;
    _refreshLegal();
    banner = _turnBanner();
    notifyListeners();
  }

  /// Test hook: synchronously settle a pending move animation.
  @visibleForTesting
  void debugSettleForTest() {
    _timer?.cancel();
    _timer = null;
    if (phase == MatchPhase.animating) _settleAnim();
  }
}
