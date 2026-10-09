/// Grand Chess Heritage — game board screen.
///
/// Renders the engine-owned [ChessMatch]: per-side player panels with their
/// own captured trays and renameable names, visible animated moves with
/// narration, promotion / draw-offer overlays, clocks, history, pause.
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../engine.dart';
import '../game_controller.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../theme/chess_themes.dart';
import '../widgets/brass.dart';
import '../widgets/piece.dart';
import 'settings_screen.dart';

class GameScreen extends StatefulWidget {
  final ChessAudio audio;
  final ChessSettings settings;
  final Map<String, dynamic>? resume;
  const GameScreen(
      {super.key, required this.audio, required this.settings, this.resume});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final ChessMatch match;
  Timer? _frameTimer;
  bool _gameOverShown = false;
  bool _pausedBySystem = false;

  ChessThemeDef get t => ChessThemes.byId(widget.settings.themeId);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final s = widget.settings;
    final config = widget.resume != null && widget.resume!['config'] != null
        ? MatchConfig.fromJson(
            Map<String, dynamic>.from(widget.resume!['config']))
        : MatchConfig(
            mode: s.mode,
            difficulty: s.difficulty,
            humanIsWhite: !s.botPlaysWhite,
            clockSeconds: s.clockSeconds,
            whiteName: s.playerNames[0],
            blackName: s.playerNames[1],
          );
    match = ChessMatch(config: config);
    match.onEvent = _onMatchEvent;
    match.addListener(_matchListener);
    if (widget.resume != null) {
      match.restore(widget.resume!);
    } else {
      match.newGame();
    }
    // A resumed snapshot carries the names from when it was saved; point the
    // match at the latest persisted names so narration never goes stale.
    match.refreshNames(
      white: s.playerNames[0],
      black: s.playerNames[1],
    );
    widget.audio.startGameMusic();
  }

  void _onMatchEvent(MatchEvent e) {
    final a = widget.audio;
    switch (e) {
      case MatchEvent.select:
        a.select();
      case MatchEvent.move:
        a.move();
      case MatchEvent.capture:
        a.capture();
      case MatchEvent.check:
        a.check();
      case MatchEvent.castle:
        a.castle();
      case MatchEvent.promote:
        a.promote();
      case MatchEvent.invalid:
        a.invalid();
      case MatchEvent.gameStart:
        a.gameStart();
      case MatchEvent.humanWon:
        a.win();
      case MatchEvent.botWon:
        a.lose();
      case MatchEvent.draw:
        a.draw();
      case MatchEvent.botThinking:
        break; // silent; narration covers it
      case MatchEvent.flag:
        a.lose();
    }
  }

  void _matchListener() {
    // Drive the 30fps animation ticker while moves are in flight.
    if (match.anims.isNotEmpty && _frameTimer == null) {
      _frameTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
        if (!mounted || match.anims.isEmpty) {
          _frameTimer?.cancel();
          _frameTimer = null;
          return;
        }
        setState(() {});
      });
    }
    if (match.over && !_gameOverShown) {
      _gameOverShown = true;
      // Let the final animation settle before the dialog.
      Future.delayed(const Duration(milliseconds: 650), () {
        if (mounted) _showGameOver();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _frameTimer?.cancel();
    match.removeListener(_matchListener);
    match.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedBySystem = !match.paused;
      GameStore.save(match.snapshot());
      widget.audio.onAppPaused();
      match.setPaused(true);
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
      if (_pausedBySystem) {
        _pausedBySystem = false;
        match.setPaused(false);
      }
    }
  }

  // ------------------------------------------------------------- game over
  Future<void> _showGameOver() async {
    if (match.config.vsBot) {
      await widget.settings.recordGame(
          humanWon: match.humanWon, draw: match.isDraw);
    }
    await GameStore.clear();
    if (!mounted) return;
    final tt = t;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: ChessMaterials.walnutPanel(tt, radius: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // cinematic fallen-king motif
              Transform.rotate(
                angle: 1.35,
                child: CarvedPiece(
                  piece: match.eng.whiteTurn ? 6 : -6,
                  size: 74,
                  theme: tt,
                  style: widget.settings.pieceStyle,
                ),
              ),
              const SizedBox(height: 14),
              Text(match.resultHeadline,
                  textAlign: TextAlign.center,
                  style: ChessType.display(tt, size: 26)),
              const SizedBox(height: 8),
              Text(match.resultSubline,
                  textAlign: TextAlign.center,
                  style: ChessType.bodyDim(tt)),
              const SizedBox(height: 20),
              BrassButton(
                theme: tt,
                label: 'Rematch',
                onTap: () {
                  widget.audio.click();
                  Navigator.pop(context);
                  setState(() => _gameOverShown = false);
                  match.newGame();
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  widget.audio.click();
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child:
                    Text('Back to menu', style: TextStyle(color: tt.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- actions
  void _togglePause() {
    widget.audio.click();
    match.setPaused(!match.paused);
  }

  void _confirmRestart() {
    widget.audio.click();
    final tt = t;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: ChessMaterials.walnutPanel(tt, radius: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Start over?',
                  style: ChessType.display(tt, size: 22)),
              const SizedBox(height: 8),
              Text('The current game will be discarded.',
                  style: ChessType.bodyDim(tt)),
              const SizedBox(height: 18),
              BrassButton(
                theme: tt,
                label: 'Restart',
                onTap: () {
                  widget.audio.click();
                  Navigator.pop(context);
                  GameStore.clear();
                  setState(() => _gameOverShown = false);
                  match.newGame();
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  widget.audio.click();
                  Navigator.pop(context);
                },
                child: Text('Cancel', style: TextStyle(color: tt.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmResign() {
    if (match.over || match.paused) return;
    widget.audio.click();
    final tt = t;
    final side = match.eng.whiteTurn ? 'White' : 'Black';
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: ChessMaterials.walnutPanel(tt, radius: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$side resigns?',
                  style: ChessType.display(tt, size: 22)),
              const SizedBox(height: 8),
              Text('This ends the game immediately.',
                  style: ChessType.bodyDim(tt)),
              const SizedBox(height: 18),
              BrassButton(
                theme: tt,
                label: 'Resign',
                onTap: () {
                  widget.audio.click();
                  Navigator.pop(context);
                  match.resign();
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  widget.audio.click();
                  Navigator.pop(context);
                },
                child: Text('Keep playing',
                    style: TextStyle(color: tt.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _renamePlayer(bool white) {
    widget.audio.click();
    final tt = t;
    final slot = white ? 0 : 1;
    final ctrl =
        TextEditingController(text: widget.settings.playerNames[slot]);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: ChessMaterials.walnutPanel(tt, radius: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(white ? 'Name White' : 'Name Black',
                  style: ChessType.display(tt, size: 22)),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLength: 18,
                style: ChessType.body(tt),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: tt.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: tt.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: tt.accent, width: 2),
                  ),
                ),
                onSubmitted: (_) {
                  widget.settings
                      .setPlayerName(slot, ctrl.text)
                      .then((_) => _afterRename());
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 14),
              BrassButton(
                theme: tt,
                label: 'Save',
                onTap: () {
                  widget.audio.click();
                  widget.settings
                      .setPlayerName(slot, ctrl.text)
                      .then((_) => _afterRename());
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Called after an in-game rename: persist, refresh the match's live
  /// names (narration/banners/results), and repaint the side panels.
  void _afterRename() {
    final s = widget.settings;
    match.refreshNames(
      white: s.playerNames[0],
      black: s.playerNames[1],
    );
    if (mounted) setState(() {});
  }

  void _showHistory() {
    widget.audio.click();
    final tt = t;
    final labels = <String>[];
    final re = ChessEngine()..reset();
    for (int i = 0; i < match.history.length; i += 2) {
      final w = match.history[i].label(re.board);
      re.doMove(match.history[i]);
      final b = i + 1 < match.history.length
          ? match.history[i + 1].label(re.board)
          : '';
      if (i + 1 < match.history.length) re.doMove(match.history[i + 1]);
      labels.add('${i ~/ 2 + 1}. $w  $b');
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: ChessMaterials.walnutPanel(tt, radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Moves', style: ChessType.display(tt, size: 22)),
            const SizedBox(height: 12),
            Flexible(
              child: labels.isEmpty
                  ? Text('No moves yet.',
                      style: ChessType.bodyDim(tt))
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final l in labels)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(l,
                                style: ChessType.moveNotation(tt)),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            BrassButton(
              theme: tt,
              label: 'Close',
              width: 180,
              fontSize: 15,
              onTap: () {
                widget.audio.click();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: match,
      builder: (_, _) {
        final tt = t;
        return Scaffold(
          backgroundColor: tt.bg,
          appBar: AppBar(
            backgroundColor: tt.surface,
            foregroundColor: tt.ivory,
            title: Text('Chess',
                style: ChessType.display(tt, size: 22)),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: tt.accent),
              onPressed: () {
                widget.audio.click();
                GameStore.save(match.snapshot());
                Navigator.pop(context);
              },
            ),
            actions: [
              BrassIconButton(
                theme: tt,
                icon: match.paused ? Icons.play_arrow : Icons.pause,
                tooltip: match.paused ? 'Resume' : 'Pause',
                onTap: _togglePause,
              ),
              const SizedBox(width: 8),
              BrassIconButton(
                theme: tt,
                icon: Icons.refresh,
                tooltip: 'New game',
                onTap: _confirmRestart,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: match.paused ? _pauseOverlay() : _boardView(),
          ),
        );
      },
    );
  }

  Widget _boardView() {
    return Stack(
      children: [
        Column(
          children: [
            _sidePanel(white: false), // Black on top
            _turnStrip(),
            _actionRow(),
            Expanded(child: Center(child: _board())),
            _sidePanel(white: true), // White at bottom
            _historyStrip(),
            const SizedBox(height: 6),
          ],
        ),
        if (match.phase == MatchPhase.promoChoice) _promoOverlay(),
        if (match.phase == MatchPhase.drawOffer) _drawOfferOverlay(),
      ],
    );
  }

  /// Per-side player panel: OWN name (renameable), captured tray, clock.
  /// The active side highlights.
  Widget _sidePanel({required bool white}) {
    final tt = t;
    final s = widget.settings;
    final active =
        !match.over && match.eng.whiteTurn == white;
    final isBot = match.vsBot && white == s.botPlaysWhite;
    final name = s.playerNames[white ? 0 : 1];
    final thinking =
        active && match.phase == MatchPhase.thinking;
    final captured =
        white ? match.capturedByWhite : match.capturedByBlack;
    final materialDiff =
        ChessEngine.material(match.eng.board, true) -
            ChessEngine.material(match.eng.board, false);
    final adv = (white ? materialDiff : -materialDiff) ~/ 100;
    final clockMs = white ? match.whiteMs : match.blackMs;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? tt.surfaceRaised : tt.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? tt.accent : tt.line,
          width: active ? 1.8 : 1,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: tt.accent.withValues(alpha: 0.25),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          CarvedPiece(
            piece: white ? 6 : -6,
            size: 30,
            theme: tt,
            style: s.pieceStyle,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _renamePlayer(white),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: ChessType.body(tt).copyWith(
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                        ),
                      ),
                      if (isBot)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text('BOT',
                              style: TextStyle(
                                  color: tt.accent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                        ),
                      Icon(Icons.edit,
                          size: 12, color: tt.ivoryDim.withValues(alpha: 0.6)),
                    ],
                  ),
                  Row(
                    children: [
                      if (adv > 0)
                        Text('+$adv  ',
                            style: TextStyle(
                                color: tt.accent, fontSize: 11)),
                      if (thinking)
                        _ThinkingDots(theme: tt)
                      else if (active && !match.over)
                        Text('to move',
                            style: ChessType.bodyDim(tt)
                                .copyWith(fontSize: 11)),
                      if (match.clocksOn) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tt.bg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: active && clockMs < 20000
                                  ? tt.checkRed
                                  : tt.line,
                            ),
                          ),
                          child: Text(
                            ChessMatch.clockLabel(clockMs),
                            style: ChessType.moveNotation(tt).copyWith(
                              fontSize: 13,
                              color: active && clockMs < 20000
                                  ? tt.checkRed
                                  : tt.ivory,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: CapturedTray(
              captured: captured,
              whiteCaptured: white,
              pieceSize: 18,
              theme: tt,
              style: s.pieceStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _turnStrip() {
    final tt = t;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (match.checkNow && !match.over)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tt.checkRed,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('CHECK',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          Flexible(
            child: Text(
              match.banner,
              overflow: TextOverflow.ellipsis,
              style: ChessType.bodyDim(tt).copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  /// Per-side controls live here too: undo, draw offer, resign.
  Widget _actionRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _miniAction(
            icon: Icons.undo,
            label: 'Undo',
            enabled: match.canUndo,
            onTap: () {
              widget.audio.click();
              match.undo();
            },
          ),
          const SizedBox(width: 10),
          _miniAction(
            icon: Icons.handshake,
            label: 'Draw',
            enabled: !match.over &&
                !match.paused &&
                match.phase == MatchPhase.awaitingInput,
            onTap: () {
              widget.audio.click();
              match.offerDraw();
            },
          ),
          const SizedBox(width: 10),
          _miniAction(
            icon: Icons.flag,
            label: 'Resign',
            enabled: !match.over && !match.paused,
            onTap: _confirmResign,
          ),
          const SizedBox(width: 10),
          _miniAction(
            icon: Icons.list,
            label: 'Moves',
            enabled: true,
            onTap: _showHistory,
          ),
        ],
      ),
    );
  }

  Widget _miniAction(
      {required IconData icon,
      required String label,
      required bool enabled,
      required VoidCallback onTap}) {
    final tt = t;
    return Opacity(
      opacity: enabled ? 1.0 : 0.35,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: tt.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: tt.line),
          ),
          child: Row(
            children: [
              Icon(icon, size: 15, color: tt.accent),
              const SizedBox(width: 6),
              Text(label,
                  style: ChessType.bodyDim(tt).copyWith(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- board
  Widget _board() {
    final tt = t;
    return LayoutBuilder(
      builder: (ctx, c) {
        final side = min(c.maxWidth, c.maxHeight);
        final cell = side / 8;
        return Container(
          width: side,
          height: side,
          padding: EdgeInsets.all(side * 0.035),
          decoration: ChessMaterials.boardFrame(tt),
          child: Stack(
            children: [
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8),
                itemCount: 64,
                itemBuilder: (_, s) => _square(s, cell),
              ),
              // visible move animations overlay
              ...match.anims.map((a) => _animOverlay(a, cell)),
            ],
          ),
        );
      },
    );
  }

  bool _hiddenByAnim(int s) {
    for (final a in match.anims) {
      if (s == a.from || s == a.to) return true;
      if (a.isCastle && (s == a.rookFrom || s == a.rookTo)) return true;
    }
    return false;
  }

  Widget _square(int s, double cell) {
    final tt = t;
    final light = (s ~/ 8 + s % 8) % 2 == 1;
    final isSel = s == match.sel;
    final isLast = s == match.lastFrom || s == match.lastTo;
    final mv = match.selMoves.where((m) => m.to == s).toList();
    final canMove = mv.isNotEmpty;
    final isCapture =
        canMove && (match.eng.board[s] != 0 || mv.first.ep);
    final kingSq = match.checkNow &&
        match.eng.board[s] == (match.eng.whiteTurn ? 6 : -6);
    final p = _hiddenByAnim(s) ? 0 : match.eng.board[s];

    return GestureDetector(
      onTap: () => match.tapSquare(s),
      child: Container(
        // NOTE: the highlight is an overlay below (not BoxDecoration.color),
        // because a decoration color paints UNDER the square gradient and
        // would be invisible.
        decoration: (light
                ? ChessMaterials.squareLight(tt)
                : ChessMaterials.squareDark(tt))
            .copyWith(
          border: kingSq
              ? Border.all(color: tt.checkRed, width: 3)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isLast || isSel)
              Positioned.fill(
                child: Container(
                  color: (isLast ? tt.lastMove : tt.selGold)
                      .withValues(alpha: isLast ? 0.45 : 0.5),
                ),
              ),
            if (p != 0)
              CarvedPiece(
                piece: p,
                size: cell * 0.8,
                theme: tt,
                style: widget.settings.pieceStyle,
              ),
            if (canMove && !isCapture)
              Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: tt.felt.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: tt.accent.withValues(alpha: 0.7), width: 1),
                ),
              ),
            if (canMove && isCapture)
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tt.checkRed, width: 3),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _animOverlay(MoveAnim a, double cell) {
    final tt = t;
    final p = a.progress;
    // easeInOut
    final e = p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2;
    Offset center(int sq) => Offset(
        (sq % 8 + 0.5) * cell, (sq ~/ 8 + 0.5) * cell);
    final from = center(a.from);
    final to = center(a.to);
    final pos = Offset(
      from.dx + (to.dx - from.dx) * e,
      from.dy + (to.dy - from.dy) * e,
    );
    final size = cell * 0.8 * (1 + 0.18 * sin(pi * p));

    return Stack(
      children: [
        // captured piece falls & fades
        if (a.capturedPiece != null && p < 0.7)
          Positioned(
            left: center(a.captureSq).dx - cell * 0.4,
            top: center(a.captureSq).dy -
                cell * 0.4 +
                p * cell * 0.45,
            child: Opacity(
              opacity: (1 - p * 1.6).clamp(0.0, 1.0),
              child: CarvedPiece(
                piece: a.piece > 0 ? -a.capturedPiece! : a.capturedPiece!,
                size: cell * 0.8,
                theme: tt,
                style: widget.settings.pieceStyle,
              ),
            ),
          ),
        // castling rook slides too
        if (a.isCastle)
          Builder(builder: (_) {
            final rf = center(a.rookFrom);
            final rt = center(a.rookTo);
            final rp = Offset(
              rf.dx + (rt.dx - rf.dx) * e,
              rf.dy + (rt.dy - rf.dy) * e,
            );
            final rookPiece =
                match.eng.board[a.rookTo]; // rook already on target
            return Positioned(
              left: rp.dx - cell * 0.4,
              top: rp.dy - cell * 0.4,
              child: CarvedPiece(
                piece: rookPiece != 0
                    ? rookPiece
                    : (a.piece > 0 ? 4 : -4),
                size: cell * 0.8,
                theme: tt,
                style: widget.settings.pieceStyle,
              ),
            );
          }),
        // the moving piece glides
        if (p < 1)
          Positioned(
            left: pos.dx - size / 2,
            top: pos.dy - size / 2,
            child: CarvedPiece(
              piece: a.piece,
              size: size,
              theme: tt,
              style: widget.settings.pieceStyle,
            ),
          ),
      ],
    );
  }

  // --------------------------------------------------------------- overlays
  /// Promotion choice blocks all input until resolved (RULES.md §12).
  Widget _promoOverlay() {
    final tt = t;
    final white = match.eng.whiteTurn;
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: ChessMaterials.walnutPanel(tt, radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Promote pawn to…',
                style: ChessType.display(tt, size: 22)),
            const SizedBox(height: 6),
            Text('Choose your piece',
                style: ChessType.bodyDim(tt)),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final pr in [5, 4, 3, 2])
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: () {
                        widget.audio.click();
                        match.choosePromotion(pr);
                      },
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration:
                            ChessMaterials.brassPlaque(tt, radius: 12),
                        alignment: Alignment.center,
                        child: CarvedPiece(
                          piece: white ? pr : -pr,
                          size: 44,
                          theme: tt,
                          style: widget.settings.pieceStyle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                widget.audio.click();
                match.cancelPromotion();
              },
              child:
                  Text('Cancel', style: TextStyle(color: tt.accent)),
            ),
          ],
        ),
      ),
    );
  }

  /// Two-player draw offer: the opponent answers explicitly (RULES.md §12).
  Widget _drawOfferOverlay() {
    final tt = t;
    final offerer = match.eng.whiteTurn ? 'White' : 'Black';
    final answerer = match.eng.whiteTurn ? 'Black' : 'White';
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: ChessMaterials.walnutPanel(tt, radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$offerer offers a draw',
                style: ChessType.display(tt, size: 22)),
            const SizedBox(height: 8),
            Text('$answerer — accept the draw?',
                style: ChessType.bodyDim(tt)),
            const SizedBox(height: 18),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrassButton(
                  theme: tt,
                  label: 'Accept',
                  width: 130,
                  fontSize: 15,
                  onTap: () {
                    widget.audio.click();
                    match.answerDraw(true);
                  },
                ),
                const SizedBox(width: 10),
                BrassButton(
                  theme: tt,
                  label: 'Decline',
                  width: 130,
                  fontSize: 15,
                  onTap: () {
                    widget.audio.click();
                    match.answerDraw(false);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyStrip() {
    final tt = t;
    if (match.history.isEmpty) return const SizedBox(height: 26);
    final re = ChessEngine()..reset();
    final labels = <String>[];
    for (int i = 0; i < match.history.length; i += 2) {
      final w = match.history[i].label(re.board);
      re.doMove(match.history[i]);
      final b = i + 1 < match.history.length
          ? match.history[i + 1].label(re.board)
          : '';
      if (i + 1 < match.history.length) re.doMove(match.history[i + 1]);
      labels.add('${i ~/ 2 + 1}. $w $b');
    }
    return GestureDetector(
      onTap: _showHistory,
      child: Container(
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        child: ListView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          children: [
            for (final l in labels.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(l,
                    style: ChessType.moveNotation(tt)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pauseOverlay() {
    final tt = t;
    return Center(
      child: SingleChildScrollView(
        child: WalnutCard(
          theme: tt,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: ChessType.display(tt, size: 30)),
              const SizedBox(height: 6),
              Text(
                  match.clocksOn
                      ? 'The clocks are stopped.'
                      : 'Take your time.',
                  style: ChessType.bodyDim(tt)),
              const SizedBox(height: 20),
              BrassButton(
                  theme: tt, label: 'Resume', onTap: _togglePause),
              const SizedBox(height: 10),
              BrassButton(
                theme: tt,
                label: 'Settings',
                onTap: () async {
                  widget.audio.click();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                        audio: widget.audio,
                        settings: widget.settings,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              BrassButton(
                  theme: tt,
                  label: 'Restart',
                  onTap: () {
                    widget.audio.click();
                    setState(() => _gameOverShown = false);
                    match.newGame();
                  }),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  widget.audio.click();
                  GameStore.save(match.snapshot());
                  Navigator.pop(context);
                },
                child: Text('Quit to menu',
                    style: TextStyle(color: tt.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated "thinking…" dots for the bot's panel.
class _ThinkingDots extends StatefulWidget {
  final ChessThemeDef theme;
  const _ThinkingDots({required this.theme});

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots> {
  Timer? _t;
  int _n = 0;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) setState(() => _n = (_n + 1) % 4);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('thinking${'.' * _n}',
        style: ChessType.bodyDim(widget.theme).copyWith(fontSize: 11));
  }
}
