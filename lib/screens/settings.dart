/// Grand Chess Heritage — settings screen.
/// Difficulty plaques, music/SFX brass toggles, volume, side choice.
library;

import 'package:flutter/material.dart';
import '../theme.dart';
import '../audio.dart';
import '../settings.dart';
import '../widgets/brass.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  GameSettings settings = GameSettings();
  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await GameSettings.load();
    await AudioService.I.init();
    if (mounted) {
      setState(() {
        settings = s;
        musicOn = AudioService.I.musicOn;
        sfxOn = AudioService.I.sfxOn;
        volume = AudioService.I.volume;
      });
    }
  }

  Future<void> _save() => settings.save();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChessPalette.walnutDeep,
      appBar: AppBar(
        backgroundColor: ChessPalette.walnutDark,
        foregroundColor: ChessPalette.ivory,
        title: Text('Settings',
            style: ChessType.display(context).copyWith(fontSize: 22)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ChessPalette.brass),
          onPressed: () {
            AudioService.I.click();
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _sectionTitle('Bot difficulty'),
            const SizedBox(height: 8),
            for (final d in Difficulty.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _difficultyPlaque(d),
              ),
            const SizedBox(height: 16),
            _sectionTitle('Your side (vs computer)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _sidePlaque(
                        'Play White', true, !settings.botPlaysWhite)),
                const SizedBox(width: 10),
                Expanded(
                    child: _sidePlaque(
                        'Play Black', false, settings.botPlaysWhite)),
              ],
            ),
            const SizedBox(height: 16),
            _sectionTitle('Audio'),
            const SizedBox(height: 8),
            WalnutCard(
              child: Column(
                children: [
                  _toggleRow('Music', 'Menu & game ambience', musicOn,
                      (v) async {
                    await AudioService.I.setMusic(v);
                    setState(() => musicOn = v);
                    if (v) AudioService.I.menuMusic();
                  }),
                  const Divider(color: ChessPalette.walnutLine, height: 24),
                  _toggleRow('Sound effects', 'Moves, captures, alerts', sfxOn,
                      (v) async {
                    await AudioService.I.setSfx(v);
                    setState(() => sfxOn = v);
                  }),
                  const Divider(color: ChessPalette.walnutLine, height: 24),
                  Row(
                    children: [
                      const Icon(Icons.volume_up,
                          color: ChessPalette.brass, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: ChessPalette.brass,
                            inactiveTrackColor: ChessPalette.walnutLine,
                            thumbColor: ChessPalette.brass,
                          ),
                          child: Slider(
                            value: volume,
                            onChanged: (v) {
                              setState(() => volume = v);
                              AudioService.I.setVolume(v);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionTitle('How to play'),
            const SizedBox(height: 8),
            const WalnutCard(
              child: Text(
                'Tap one of your pieces, then tap a highlighted square to move. '
                'Castle by moving the king two squares. Promote pawns on the last rank. '
                'Checkmate the enemy king to win — stalemate is a draw.',
                style: ChessType.bodyDim,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
        t.toUpperCase(),
        style: const TextStyle(
          color: ChessPalette.brass,
          fontSize: 12,
          letterSpacing: 2.2,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _difficultyPlaque(Difficulty d) {
    final selected = settings.difficulty == d;
    return GestureDetector(
      onTap: () {
        AudioService.I.click();
        setState(() => settings.difficulty = d);
        _save();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: selected
            ? ChessMaterials.brassPlaque(radius: 10)
            : ChessMaterials.walnutPanel(radius: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.label,
                    style: selected
                        ? ChessType.plaqueTitle(context)
                            .copyWith(fontSize: 16)
                        : ChessType.body.copyWith(
                            fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.blurb,
                    style: selected
                        ? const TextStyle(
                            color: ChessPalette.onBrass, fontSize: 12)
                        : ChessType.bodyDim,
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: ChessPalette.onBrass, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _sidePlaque(String label, bool white, bool selected) {
    return GestureDetector(
      onTap: () {
        AudioService.I.click();
        setState(() => settings.botPlaysWhite = !white);
        _save();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: selected
            ? ChessMaterials.brassPlaque(radius: 10)
            : ChessMaterials.walnutPanel(radius: 10),
        alignment: Alignment.center,
        child: Text(
          label,
          style: selected
              ? ChessType.plaqueTitle(context).copyWith(fontSize: 14)
              : ChessType.body,
        ),
      ),
    );
  }

  Widget _toggleRow(String title, String sub, bool value,
      ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ChessType.body),
              Text(sub, style: ChessType.bodyDim.copyWith(fontSize: 12)),
            ],
          ),
        ),
        BrassToggle(value: value, onChanged: onChanged),
      ],
    );
  }
}
