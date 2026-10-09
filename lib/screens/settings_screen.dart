/// Grand Chess Heritage — settings screen.
/// Difficulty plaques, side choice, chess clock, renameable players,
/// board theme catalog, piece styles, audio, tip jar, how-to-play.
library;

import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../theme/chess_themes.dart';
import '../widgets/brass.dart';
import '../widgets/piece.dart';
import 'menu_screen.dart' show TipJarCard;

class SettingsScreen extends StatefulWidget {
  final ChessAudio audio;
  final ChessSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ChessThemeDef get t => ChessThemes.byId(widget.settings.themeId);

  void _click() => widget.audio.click();

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return ListenableBuilder(
      listenable: s,
      builder: (_, _) {
        final tt = t;
        return Scaffold(
          backgroundColor: tt.bg,
          appBar: AppBar(
            backgroundColor: tt.surface,
            foregroundColor: tt.ivory,
            title: Text('Settings',
                style: ChessType.display(tt, size: 22)),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: tt.accent),
              onPressed: () {
                _click();
                Navigator.pop(context);
              },
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                _sectionTitle(tt, 'Bot difficulty'),
                const SizedBox(height: 8),
                for (int d = 0; d < 3; d++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _difficultyPlaque(tt, d),
                  ),
                const SizedBox(height: 16),
                _sectionTitle(tt, 'Your side (vs computer)'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: _sidePlaque(
                            tt, 'Play White', true, !s.botPlaysWhite)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _sidePlaque(
                            tt, 'Play Black', false, s.botPlaysWhite)),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionTitle(tt, 'Chess clock'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0;
                        i < ChessSettings.clockOptions.length;
                        i++)
                      _clockChip(tt, i),
                  ],
                ),
                Text(
                  'Applies to the next game. Flag fall loses.',
                  style: ChessType.bodyDim(tt).copyWith(fontSize: 11),
                ),
                const SizedBox(height: 16),
                _sectionTitle(tt, 'Players'),
                const SizedBox(height: 8),
                _nameRow(tt, 'White', 0),
                const SizedBox(height: 8),
                _nameRow(tt, 'Black', 1),
                const SizedBox(height: 16),
                _sectionTitle(tt, 'Board theme'),
                const SizedBox(height: 8),
                _themeGrid(tt),
                const SizedBox(height: 16),
                _sectionTitle(tt, 'Piece style'),
                const SizedBox(height: 8),
                for (int i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _pieceStylePlaque(tt, i),
                  ),
                const SizedBox(height: 16),
                _sectionTitle(tt, 'Audio'),
                const SizedBox(height: 8),
                WalnutCard(
                  theme: tt,
                  child: Column(
                    children: [
                      _toggleRow(tt, 'Music', 'Menu & game ambience',
                          s.musicOn, (v) async {
                        await s.setMusic(v);
                        widget.audio.configure(
                            musicOn: v,
                            sfxOn: s.sfxOn,
                            volume: s.volume);
                        if (v) {
                          widget.audio.startMenuMusic();
                        } else {
                          widget.audio.stopMusic();
                        }
                      }),
                      Divider(color: tt.line, height: 24),
                      _toggleRow(tt, 'Sound effects',
                          'Moves, captures, alerts', s.sfxOn, (v) async {
                        await s.setSfx(v);
                        widget.audio.configure(
                            musicOn: s.musicOn,
                            sfxOn: v,
                            volume: s.volume);
                      }),
                      Divider(color: tt.line, height: 24),
                      Row(
                        children: [
                          Icon(Icons.volume_up,
                              color: tt.accent, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Slider(
                              value: s.volume,
                              onChanged: (v) {
                                s.setVolume(v);
                                widget.audio.configure(
                                    musicOn: s.musicOn,
                                    sfxOn: s.sfxOn,
                                    volume: v);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle(tt, 'Support the club'),
                const SizedBox(height: 8),
                WalnutCard(
                  theme: tt,
                  child: TipJarCard(
                    audio: widget.audio,
                    theme: tt,
                    onClose: () {},
                  ),
                ),
                const SizedBox(height: 16),
                _sectionTitle(tt, 'How to play'),
                const SizedBox(height: 8),
                WalnutCard(
                  theme: tt,
                  child: Text(
                    'Tap one of your pieces, then tap a highlighted square to move. '
                    'Castle by moving the king two squares. Promote pawns on the last rank. '
                    'Checkmate the enemy king to win — stalemate is a draw. '
                    'Tap a player name to rename them.',
                    style: ChessType.bodyDim(tt),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(ChessThemeDef tt, String t) => Text(
        t.toUpperCase(),
        style: TextStyle(
          color: tt.accent,
          fontSize: 12,
          letterSpacing: 2.2,
          fontWeight: FontWeight.bold,
        ),
      );

  Widget _difficultyPlaque(ChessThemeDef tt, int d) {
    final s = widget.settings;
    final selected = s.difficulty == d;
    return GestureDetector(
      onTap: () {
        _click();
        s.setDifficulty(d);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: selected
            ? ChessMaterials.brassPlaque(tt, radius: 10)
            : ChessMaterials.walnutPanel(tt, radius: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ChessSettings.difficultyLabels[d],
                    style: selected
                        ? ChessType.plaqueTitle(tt, size: 16)
                        : ChessType.body(tt)
                            .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ChessSettings.difficultyBlurbs[d],
                    style: selected
                        ? TextStyle(color: tt.onAccent, fontSize: 12)
                        : ChessType.bodyDim(tt),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: tt.onAccent, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _sidePlaque(
      ChessThemeDef tt, String label, bool white, bool selected) {
    final s = widget.settings;
    return GestureDetector(
      onTap: () {
        _click();
        s.setBotPlaysWhite(!white);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: selected
            ? ChessMaterials.brassPlaque(tt, radius: 10)
            : ChessMaterials.walnutPanel(tt, radius: 10),
        alignment: Alignment.center,
        child: Text(
          label,
          style: selected
              ? ChessType.plaqueTitle(tt, size: 14)
              : ChessType.body(tt),
        ),
      ),
    );
  }

  Widget _clockChip(ChessThemeDef tt, int i) {
    final s = widget.settings;
    final secs = ChessSettings.clockOptions[i];
    final selected = s.clockSeconds == secs;
    return GestureDetector(
      onTap: () {
        _click();
        s.setClockSeconds(secs);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: selected
            ? ChessMaterials.brassPlaque(tt, radius: 20)
            : BoxDecoration(
                color: tt.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tt.line),
              ),
        child: Text(
          ChessSettings.clockLabels[i],
          style: selected
              ? ChessType.plaqueTitle(tt, size: 13)
              : ChessType.bodyDim(tt),
        ),
      ),
    );
  }

  Widget _nameRow(ChessThemeDef tt, String side, int slot) {
    return _NameField(
      theme: tt,
      side: side,
      slot: slot,
      settings: widget.settings,
      audio: widget.audio,
    );
  }

  /// Wide theme picker: live 4x4 board thumbnails for all 12 themes.
  Widget _themeGrid(ChessThemeDef tt) {
    final s = widget.settings;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.92,
      ),
      itemCount: ChessThemes.all.length,
      itemBuilder: (_, i) {
        final th = ChessThemes.all[i];
        final selected = s.themeId == th.id;
        return GestureDetector(
          onTap: () {
            _click();
            s.setTheme(th.id);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? th.accent : th.line,
                width: selected ? 2.5 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: th.accent.withValues(alpha: 0.4),
                        blurRadius: 8,
                      )
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4),
                    itemCount: 16,
                    itemBuilder: (_, q) {
                      final light = (q ~/ 4 + q % 4) % 2 == 1;
                      return Container(
                        color: light ? th.sqLight : th.sqDark,
                      );
                    },
                  ),
                ),
                Container(
                  width: double.infinity,
                  color: th.surface,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(
                    th.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? th.accent : th.ivoryDim,
                      fontSize: 10,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pieceStylePlaque(ChessThemeDef tt, int i) {
    final s = widget.settings;
    final selected = s.pieceStyle == i;
    return GestureDetector(
      onTap: () {
        _click();
        s.setPieceStyle(i);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: selected
            ? ChessMaterials.brassPlaque(tt, radius: 10)
            : ChessMaterials.walnutPanel(tt, radius: 10),
        child: Row(
          children: [
            CarvedPiece(
                piece: 6, size: 40, theme: tt, style: i),
            const SizedBox(width: 6),
            CarvedPiece(
                piece: -6, size: 40, theme: tt, style: i),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    PieceStyles.names[i],
                    style: selected
                        ? ChessType.plaqueTitle(tt, size: 15)
                        : ChessType.body(tt)
                            .copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    PieceStyles.descriptions[i],
                    style: selected
                        ? TextStyle(color: tt.onAccent, fontSize: 12)
                        : ChessType.bodyDim(tt),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: tt.onAccent, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _toggleRow(ChessThemeDef tt, String title, String sub, bool value,
      ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: ChessType.body(tt)),
              Text(sub,
                  style: ChessType.bodyDim(tt).copyWith(fontSize: 12)),
            ],
          ),
        ),
        BrassToggle(
            value: value,
            onChanged: (v) {
              _click();
              onChanged(v);
            },
            theme: tt),
      ],
    );
  }
}
/// Renameable player name field: owns its controller so typing never
/// loses cursor position on rebuilds; persists on submit / focus loss.
class _NameField extends StatefulWidget {
  final ChessThemeDef theme;
  final String side;
  final int slot;
  final ChessSettings settings;
  final ChessAudio audio;
  const _NameField({
    required this.theme,
    required this.side,
    required this.slot,
    required this.settings,
    required this.audio,
  });

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.settings.playerNames[widget.slot]);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _save();
    });
  }

  void _save() {
    widget.audio.click();
    widget.settings.setPlayerName(widget.slot, _ctrl.text);
  }

  @override
  void dispose() {
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = widget.theme;
    return WalnutCard(
      theme: tt,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          CarvedPiece(
              piece: widget.slot == 0 ? 6 : -6,
              size: 30,
              theme: tt,
              style: widget.settings.pieceStyle),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              maxLength: 18,
              style: ChessType.body(tt),
              decoration: InputDecoration(
                counterText: '',
                labelText: widget.side,
                labelStyle: ChessType.bodyDim(tt),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _save(),
            ),
          ),
          Icon(Icons.edit, size: 14, color: tt.ivoryDim),
        ],
      ),
    );
  }
}
