import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const ChessApp());

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.comicBurst,
      title: 'Chess',
      tagline: 'The ultimate brain battle! Trap queens, dodge checks, and shout checkmate! 👑',
      emoji: '♟️',
      slug: 'chess',
      howToPlay:
          '• Tap one of your pieces, then tap a glowing square to move.\n• Full rules: castling, en passant and promotion (pick your piece! 👑).\n• Checkmate the enemy king to win. No legal moves + no check = stalemate draw.\n• Solo vs the bot, or pass-and-play with a friend!',
      playerOptions: const [1, 2],
      supportsBots: true,
      gameBuilder: (ctx, players, cb) => ChessScreen(players: players, callbacks: cb),
    );
  }
}
