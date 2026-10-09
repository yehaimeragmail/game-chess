/// Grand Chess Heritage — main menu.
/// Brass plaques on walnut: Play vs Computer, Two Players, Settings.
library;

import 'package:flutter/material.dart';
import '../theme.dart';
import '../audio.dart';
import '../settings.dart';
import '../widgets/brass.dart';
import '../widgets/piece.dart';
import 'game.dart';
import 'settings.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  GameSettings settings = GameSettings();
  (int, int, int) score = (0, 0, 0);

  @override
  void initState() {
    super.initState();
    _load();
    AudioService.I.init().then((_) => AudioService.I.menuMusic());
  }

  Future<void> _load() async {
    final s = await GameSettings.load();
    final sc = await GameStore.loadScore();
    final saved = await GameStore.load();
    if (mounted) {
      setState(() {
        settings = s;
        score = sc;
      });
      if (saved != null) {
        _offerResume(saved);
      }
    }
  }

  void _offerResume(Map<String, dynamic> saved) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: ChessMaterials.walnutPanel(radius: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Resume game?',
                  style: ChessType.display(context).copyWith(fontSize: 24)),
              const SizedBox(height: 8),
              const Text('You have an unfinished game.',
                  style: ChessType.bodyDim),
              const SizedBox(height: 18),
              BrassButton(
                label: 'Resume',
                onTap: () {
                  Navigator.pop(context);
                  _openGame(resume: saved);
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  GameStore.clear();
                  Navigator.pop(context);
                },
                child: const Text('Discard',
                    style: TextStyle(color: ChessPalette.brass)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openGame({Map<String, dynamic>? resume}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(settings: settings),
      ),
    ).then((_) {
      AudioService.I.menuMusic();
      GameStore.loadScore().then((sc) {
        if (mounted) setState(() => score = sc);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final (w, l, d) = score;
    return Scaffold(
      backgroundColor: ChessPalette.walnutDeep,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // hero: crossed kings motif
                SizedBox(
                  height: 120,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Transform.translate(
                        offset: const Offset(-26, 0),
                        child: Transform.rotate(
                          angle: -0.18,
                          child: const CarvedPiece(piece: 6, size: 88),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(26, 0),
                        child: Transform.rotate(
                          angle: 0.18,
                          child: const CarvedPiece(piece: -6, size: 88),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text('CHESS', style: ChessType.display(context)),
                const SizedBox(height: 4),
                const Text(
                  'The royal game, in marble & brass',
                  style: ChessType.bodyDim,
                ),
                const SizedBox(height: 8),
                // lifetime score plaque
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: ChessPalette.walnutDark,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: ChessPalette.walnutLine, width: 1),
                  ),
                  child: Text(
                    'Club record  $w W · $l L · $d D',
                    style: ChessType.moveNotation
                        .copyWith(color: ChessPalette.brass, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 28),
                BrassButton(
                  label: 'Play vs Computer',
                  icon: Icons.computer,
                  onTap: () {
                    settings.mode = GameMode.vsBot;
                    settings.save();
                    _openGame();
                  },
                ),
                const SizedBox(height: 12),
                BrassButton(
                  label: 'Two Players',
                  icon: Icons.people,
                  onTap: () {
                    settings.mode = GameMode.twoPlayer;
                    settings.save();
                    _openGame();
                  },
                ),
                const SizedBox(height: 12),
                BrassButton(
                  label: 'Settings',
                  icon: Icons.settings,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    );
                    _load();
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'v1.0 · 100% free · by Wajiha',
                  style: ChessType.bodyDim.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
