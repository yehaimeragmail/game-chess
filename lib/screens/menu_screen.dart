/// Grand Chess Heritage — main menu.
/// Brass plaques on walnut: Play vs Computer, Two Players, Settings, Support.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:share_plus/share_plus.dart';
import 'package:in_app_review/in_app_review.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../theme/chess_themes.dart';
import '../widgets/brass.dart';
import 'game_screen.dart';
import 'pro_screen.dart';
import 'settings_screen.dart';

class MenuScreen extends StatefulWidget {
  final ChessAudio audio;
  final ChessSettings settings;
  const MenuScreen({super.key, required this.audio, required this.settings});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  Map<String, dynamic>? _savedGame;

  @override
  void initState() {
    super.initState();
    widget.audio.startMenuMusic();
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final saved = await GameStore.load();
    if (saved != null && mounted) {
      setState(() => _savedGame = saved);
      _offerResume();
    }
  }

  void _offerResume() {
    final t = ChessThemes.byId(widget.settings.themeId);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: ChessMaterials.walnutPanel(t, radius: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Resume game?',
                  style: ChessType.display(t, size: 24)),
              const SizedBox(height: 8),
              Text('You have an unfinished game.',
                  style: ChessType.bodyDim(t)),
              const SizedBox(height: 18),
              BrassButton(
                theme: t,
                label: 'Resume',
                onTap: () {
                  widget.audio.click();
                  Navigator.pop(context);
                  _openGame(resume: _savedGame);
                  setState(() => _savedGame = null);
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  widget.audio.click();
                  GameStore.clear();
                  setState(() => _savedGame = null);
                  Navigator.pop(context);
                },
                child: Text('Discard', style: TextStyle(color: t.accent)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openGame({Map<String, dynamic>? resume}) {
    widget.audio.click();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GameScreen(
          audio: widget.audio,
          settings: widget.settings,
          resume: resume,
        ),
      ),
    ).then((_) {
      widget.audio.startMenuMusic();
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final clockLabel = settings.clockSeconds == 0
        ? 'no clock'
        : ChessSettings.clockLabels[
            ChessSettings.clockOptions.indexOf(settings.clockSeconds)];
    return ListenableBuilder(
      listenable: settings,
      builder: (_, _) {
        final tt = ChessThemes.byId(settings.themeId);
        return Scaffold(
          backgroundColor: tt.bg,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // hero: the club emblem
                    Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: tt.accent, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            offset: const Offset(0, 8),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset('assets/chess_logo.png',
                          fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 14),
                    Text('CHESS', style: ChessType.display(tt, size: 44)),
                    const SizedBox(height: 4),
                    Text(
                      'The royal game, in marble & brass',
                      style: ChessType.bodyDim(tt),
                    ),
                    const SizedBox(height: 10),
                    // lifetime score plaque
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: tt.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: tt.line, width: 1),
                      ),
                      child: Text(
                        'Club record  ${settings.wins} W · ${settings.losses} L · ${settings.draws} D',
                        style: ChessType.moveNotation(tt).copyWith(
                            color: tt.accent, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 26),
                    BrassButton(
                      theme: tt,
                      label: 'Play vs Computer',
                      icon: Icons.computer,
                      onTap: () {
                        settings.setMode(0);
                        _openGame();
                      },
                    ),
                    const SizedBox(height: 12),
                    BrassButton(
                      theme: tt,
                      label: 'Two Players',
                      icon: Icons.people,
                      onTap: () {
                        settings.setMode(1);
                        _openGame();
                      },
                    ),
                    const SizedBox(height: 12),
                    BrassButton(
                      theme: tt,
                      label: 'Settings',
                      icon: Icons.settings,
                      onTap: () async {
                        widget.audio.click();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SettingsScreen(
                              audio: widget.audio,
                              settings: settings,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    BrassButton(
                      theme: tt,
                      label: settings.isPro ? 'Chess PRO ✓' : 'Chess PRO',
                      icon: Icons.workspace_premium,
                      onTap: () {
                        widget.audio.click();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProScreen(
                              audio: widget.audio,
                              settings: settings,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    // mode summary chips
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(tt,
                            '${ChessSettings.difficultyLabels[settings.difficulty]} bot'),
                        _chip(tt,
                            settings.botPlaysWhite ? 'You play Black' : 'You play White'),
                        _chip(tt, clockLabel),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // share + rate row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _menuMiniButton(
                          tt,
                          icon: Icons.share,
                          label: 'Share',
                          onTap: _shareGame,
                        ),
                        const SizedBox(width: 12),
                        _menuMiniButton(
                          tt,
                          icon: Icons.star,
                          label: 'Rate',
                          onTap: _rateGame,
                        ),
                      ],
                    ),
                    // Tips are Android-only: hidden on iOS (App Store).
                    if (defaultTargetPlatform != TargetPlatform.iOS) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () {
                          widget.audio.click();
                          _supportDialog(tt);
                        },
                        icon: Icon(Icons.coffee,
                            color: tt.accent, size: 18),
                        label: Text(
                          'Support the club',
                          style: TextStyle(color: tt.accent, fontSize: 14),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      settings.isPro
                          ? '✦ PRO · by Wajiha'
                          : 'Free forever · by Wajiha',
                      style: ChessType.bodyDim(tt).copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _chip(ChessThemeDef t, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.line),
        ),
        child: Text(label,
            style: ChessType.bodyDim(t).copyWith(fontSize: 11)),
      );

  Widget _menuMiniButton(
    ChessThemeDef t, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.line, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: t.accent, size: 16),
            const SizedBox(width: 8),
            Text(label,
                style: ChessType.bodyDim(t).copyWith(fontSize: 13)),
          ],
        ),
      ),
    );
  }

  /// Real share sheet: invite a friend to play Chess.
  Future<void> _shareGame() async {
    widget.audio.click();
    await Share.share(
        'Play Chess with me! https://play.google.com/store/apps/details?id=com.gameswajiha.chess');
  }

  /// Real in-app review flow, with a store-listing fallback when the
  /// review dialog is unavailable on this device.
  Future<void> _rateGame() async {
    widget.audio.click();
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing(appStoreId: null);
      }
    } catch (_) {
      // Last resort: open the Play Store listing directly.
      try {
        await review.openStoreListing(appStoreId: null);
      } catch (_) {}
    }
  }

  void _supportDialog(ChessThemeDef t) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: ChessMaterials.walnutPanel(t, radius: 16),
          child: TipJarCard(
            audio: widget.audio,
            theme: t,
            onClose: () => Navigator.pop(ctx),
          ),
        ),
      ),
    );
  }
}

/// Tasteful tip-jar card: coffee / chocolate products, or a graceful
/// "not configured yet" note when Play Console products are missing.
/// Owns its StoreService instance.
class TipJarCard extends StatefulWidget {
  final ChessAudio audio;
  final ChessThemeDef theme;
  final VoidCallback onClose;
  const TipJarCard({
    super.key,
    required this.audio,
    required this.theme,
    required this.onClose,
  });

  @override
  State<TipJarCard> createState() => _TipJarCardState();
}

class _TipJarCardState extends State<TipJarCard> {
  late final StoreService _store = StoreService();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _store.init().then((_) {
      if (mounted) setState(() => _loading = false);
    });
    _store.lastThanks.addListener(_thanks);
  }

  void _thanks() {
    final msg = _store.lastThanks.value;
    if (msg != null && mounted) {
      _store.lastThanks.value = null;
      widget.audio.win();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_thanks);
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final tips = [
      _store.coffeeProduct,
      _store.chocolateProduct,
    ].whereType<ProductDetails>().toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Support the club',
            style: ChessType.display(t, size: 24)),
        const SizedBox(height: 8),
        Text(
          'Chess is free forever. If the club has given you good games, '
          'a coffee keeps the lamps lit.',
          style: ChessType.bodyDim(t),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else if (!_store.storeReady)
          Text(
            _store.error ?? 'Tip jar coming soon.',
            style: ChessType.bodyDim(t),
            textAlign: TextAlign.center,
          )
        else
          for (final p in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: BrassButton(
                theme: t,
                width: 240,
                fontSize: 15,
                icon: p.id == StoreService.chocolateId
                    ? Icons.cookie
                    : Icons.coffee,
                label: '${p.title} · ${p.price}',
                onTap: () {
                  widget.audio.click();
                  _store.buyTip(p);
                },
              ),
            ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            widget.audio.click();
            widget.onClose();
          },
          child: Text('Close', style: TextStyle(color: t.accent)),
        ),
      ],
    );
  }
}
