/// Chess PRO: Free-vs-Pro comparison, real purchase, restore, and tip jar.
/// All prices come from the store — never hardcoded, never placeholders.
///
/// Product IDs (created in Play Console):
/// - `chesspro` — one-time non-consumable PRO unlock.
/// - `chesscoffee`, `chesschocolate` — consumable tips.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../theme/chess_themes.dart';
import '../widgets/brass.dart';

class ProScreen extends StatefulWidget {
  final ChessAudio audio;
  final ChessSettings settings;

  const ProScreen({
    super.key,
    required this.audio,
    required this.settings,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  ChessThemeDef get _t => ChessThemes.byId(widget.settings.themeId);
  late final StoreService _store = StoreService();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _store.init().then((_) {
      if (mounted) setState(() => _loading = false);
    });
    // Hardening: never spin the loading state forever if the store
    // sheet/query stalls (seen on iOS as a stuck blank StoreKit sheet).
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && _loading) setState(() => _loading = false);
    });
    _store.proPurchased.addListener(_onPro);
    _store.lastThanks.addListener(_onThanks);
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      widget.audio.win();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PRO unlocked — enjoy everything!',
              style: ChessType.body(_t)),
          backgroundColor: _t.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _store.proPurchased.value = false;
      setState(() {});
    }
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: ChessType.body(_t)),
        backgroundColor: _t.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  @override
  void dispose() {
    _store.proPurchased.removeListener(_onPro);
    _store.lastThanks.removeListener(_onThanks);
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.surface,
        foregroundColor: t.ivory,
        title: Text('Chess PRO', style: ChessType.display(t, size: 22)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: t.accent),
          onPressed: () {
            widget.audio.click();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s,
          builder: (_, _) => SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Column(
              children: [
                _ComparisonCard(theme: t, isPro: s.isPro),
                const SizedBox(height: 16),
                _BuyCard(
                  theme: t,
                  settings: s,
                  store: _store,
                  loading: _loading,
                  audio: widget.audio,
                ),
                // Tips are Android-only: hidden on iOS (App Store).
                if (defaultTargetPlatform != TargetPlatform.iOS) ...[
                  const SizedBox(height: 16),
                  _TipsCard(
                    theme: t,
                    store: _store,
                    loading: _loading,
                    audio: widget.audio,
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Free vs Pro comparison table — buyers see the big difference.
class _ComparisonCard extends StatelessWidget {
  final ChessThemeDef theme;
  final bool isPro;
  const _ComparisonCard({required this.theme, required this.isPro});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Complete Chess game', true, true),
      ('All official rules', true, true),
      ('Casual & Club Player bots', true, true),
      ('Two-player pass-and-play', true, true),
      ('Renameable players', true, true),
      ('Chess clock', true, true),
      ('Music & sound effects', true, true),
      ('Board themes', '4', '12'),
      ('Piece styles', '1', '3'),
      ('Grandmaster bot', false, true),
    ];
    final t = theme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: ChessMaterials.walnutPanel(t, radius: 14),
      child: Column(
        children: [
          Text('Free vs PRO', style: ChessType.display(t, size: 20)),
          const SizedBox(height: 4),
          Text(
            'One purchase. Yours forever.',
            style: ChessType.bodyDim(t),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(flex: 5, child: SizedBox()),
              Expanded(
                  flex: 2,
                  child: Text('FREE',
                      style: ChessType.bodyDim(t).copyWith(
                          fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      textAlign: TextAlign.center)),
              Expanded(
                  flex: 2,
                  child: Text('PRO',
                      style: TextStyle(
                          color: t.accent,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontSize: 13),
                      textAlign: TextAlign.center)),
            ],
          ),
          Divider(color: t.line, height: 14),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child:
                        Text(r.$1, style: ChessType.body(t).copyWith(fontSize: 13)),
                  ),
                  Expanded(flex: 2, child: _Cell(value: r.$2, theme: t)),
                  Expanded(flex: 2, child: _Cell(value: r.$3, theme: t)),
                ],
              ),
            ),
          if (isPro)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: t.accent.withValues(alpha: 0.25),
                  border: Border.all(color: t.accentLight),
                ),
                child: Text('✦ PRO ACTIVE ✦',
                    style: TextStyle(
                        color: t.accent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final Object value; // bool | String
  final ChessThemeDef theme;
  const _Cell({required this.value, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    if (value is bool) {
      final v = value as bool;
      return Text(
        v ? '✓' : '—',
        style: TextStyle(
            fontSize: 15,
            color: v ? t.accent : t.ivoryDim.withValues(alpha: 0.4),
            fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      );
    }
    return Text(
      value as String,
      style: TextStyle(
          color: t.ivory, fontWeight: FontWeight.bold, fontSize: 13),
      textAlign: TextAlign.center,
    );
  }
}

// ---------------------------------------------------------------------------
class _BuyCard extends StatelessWidget {
  final ChessThemeDef theme;
  final ChessSettings settings;
  final StoreService store;
  final bool loading;
  final ChessAudio audio;
  const _BuyCard({
    required this.theme,
    required this.settings,
    required this.store,
    required this.loading,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final pro = store.proProduct;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: ChessMaterials.walnutPanel(t, radius: 14),
      child: Column(
        children: [
          Text('Unlock PRO', style: ChessType.display(t, size: 20)),
          const SizedBox(height: 8),
          if (settings.isPro)
            Text('You already own PRO — thank you!',
                style: ChessType.body(t), textAlign: TextAlign.center)
          else if (loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            )
          else if (!store.storeReady || pro == null)
            Text(
              store.error ?? 'Available after store setup.',
              style: ChessType.bodyDim(t),
              textAlign: TextAlign.center,
            )
          else ...[
            Text(
              'Every board, every piece style, the merciless Grandmaster — '
              'unlocked forever with one purchase.',
              style: ChessType.body(t).copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<bool>(
              valueListenable: store.purchaseInProgress,
              builder: (_, busy, _) => BrassButton(
                theme: t,
                width: 260,
                fontSize: 15,
                label: busy ? 'Working…' : 'Get PRO — ${pro.price}',
                onTap: busy
                    ? () {}
                    : () {
                        audio.click();
                        store.buyPro();
                      },
              ),
            ),
          ],
          ValueListenableBuilder<String?>(
            valueListenable: store.purchaseError,
            builder: (_, err, _) => err == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(err,
                        style: ChessType.body(t).copyWith(
                            fontSize: 13, color: const Color(0xFFE08A8A)),
                        textAlign: TextAlign.center),
                  ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              audio.click();
              store.restore();
            },
            child:
                Text('Restore purchases', style: TextStyle(color: t.accent)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
/// Consumable tips — pure support, with real store prices.
class _TipsCard extends StatelessWidget {
  final ChessThemeDef theme;
  final StoreService store;
  final bool loading;
  final ChessAudio audio;
  const _TipsCard({
    required this.theme,
    required this.store,
    required this.loading,
    required this.audio,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final tips = [
      store.coffeeProduct,
      store.chocolateProduct,
    ].whereType<ProductDetails>().toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: ChessMaterials.walnutPanel(t, radius: 14),
      child: Column(
        children: [
          Text('Tip the Maker', style: ChessType.display(t, size: 20)),
          const SizedBox(height: 8),
          Text(
            'Chess is free forever. A small tip keeps new games coming!',
            style: ChessType.body(t).copyWith(fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            )
          else if (!store.storeReady)
            Text(
              store.error ?? 'Available after store setup.',
              style: ChessType.bodyDim(t),
              textAlign: TextAlign.center,
            )
          else if (tips.isEmpty)
            Text('Tips coming soon.', style: ChessType.bodyDim(t))
          else
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final p in tips)
                  _TipChip(
                    theme: t,
                    product: p,
                    onTap: () {
                      audio.click();
                      store.buyTip(p);
                    },
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TipChip extends StatelessWidget {
  final ChessThemeDef theme;
  final ProductDetails product;
  final VoidCallback onTap;
  const _TipChip({
    required this.theme,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.black.withValues(alpha: 0.3),
          border: Border.all(
              color: t.accent.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              product.id == StoreService.chocolateId
                  ? Icons.cookie
                  : Icons.coffee,
              color: t.accent,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(product.price,
                style: TextStyle(
                    color: t.ivory,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
