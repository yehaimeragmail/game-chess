/// Brass plaque controls — the physical button language of Grand Chess Heritage.
/// Theme-aware; audio clicks are played by the owning screen, not the widget.
library;

import 'package:flutter/material.dart';
import '../theme.dart';
import '../theme/chess_themes.dart';

/// A cold brushed-metal plaque button with engraved serif text.
class BrassButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final ChessThemeDef theme;
  final double width;
  final double fontSize;
  final IconData? icon;

  const BrassButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.theme,
    this.width = 260,
    this.fontSize = 17,
    this.icon,
  });

  @override
  State<BrassButton> createState() => _BrassButtonState();
}

class _BrassButtonState extends State<BrassButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        decoration: ChessMaterials.brassPlaque(t, pressed: _pressed),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _rivet(t),
            const SizedBox(width: 10),
            if (widget.icon != null) ...[
              Icon(widget.icon, color: t.onAccent, size: 20),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: ChessType.plaqueTitle(t, size: widget.fontSize),
              ),
            ),
            const SizedBox(width: 10),
            _rivet(t),
          ],
        ),
      ),
    );
  }

  Widget _rivet(ChessThemeDef t) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [t.accentLight, t.accentDark],
          ),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 2, offset: Offset(0, 1)),
          ],
        ),
      );
}

/// Small brass icon button (pause, restart, settings…).
class BrassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ChessThemeDef theme;
  final String? tooltip;
  final bool highlighted;

  const BrassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.theme,
    this.tooltip,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: highlighted
              ? ChessMaterials.brassPlaque(t, radius: 10).copyWith(
                  boxShadow: [
                    BoxShadow(
                      color: t.selGold.withValues(alpha: 0.7),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                )
              : ChessMaterials.brassPlaque(t, radius: 10),
          child: Icon(icon, color: t.onAccent, size: 22),
        ),
      ),
    );
  }
}

/// Walnut panel card for grouping content.
class WalnutCard extends StatelessWidget {
  final Widget child;
  final ChessThemeDef theme;
  final EdgeInsets padding;

  const WalnutCard({
    super.key,
    required this.child,
    required this.theme,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: ChessMaterials.walnutPanel(theme),
      child: child,
    );
  }
}

/// Brass toggle switch (physical lever feel).
class BrassToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final ChessThemeDef theme;

  const BrassToggle(
      {super.key,
      required this.value,
      required this.onChanged,
      required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 58,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: value
                ? [t.accentLight, t.accent, t.accentDark]
                : [t.surfaceRaised, t.surface],
          ),
          border: Border.all(color: t.accentDark, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 26,
            height: 26,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [t.accentLight, t.accentDark],
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
