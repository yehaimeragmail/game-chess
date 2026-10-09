/// Brass plaque controls — the physical button language of Grand Chess Heritage.
library;

import 'package:flutter/material.dart';
import '../theme.dart';
import '../audio.dart';

/// A cold brushed-brass plaque button with engraved serif text.
class BrassButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final double width;
  final double fontSize;
  final IconData? icon;

  const BrassButton({
    super.key,
    required this.label,
    required this.onTap,
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
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        AudioService.I.click();
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.width,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        decoration: ChessMaterials.brassPlaque(pressed: _pressed),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // screw rivets
            _rivet(),
            const SizedBox(width: 10),
            if (widget.icon != null) ...[
              Icon(widget.icon, color: ChessPalette.onBrass, size: 20),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                widget.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: ChessType.plaqueTitle(context).copyWith(
                  fontSize: widget.fontSize,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _rivet(),
          ],
        ),
      ),
    );
  }

  Widget _rivet() => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFFf7e3ae), Color(0xFF8a6d35)],
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
  final String? tooltip;

  const BrassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: () {
          AudioService.I.click();
          onTap();
        },
        child: Container(
          width: 46,
          height: 46,
          decoration: ChessMaterials.brassPlaque(radius: 10),
          child: Icon(icon, color: ChessPalette.onBrass, size: 22),
        ),
      ),
    );
  }
}

/// Walnut panel card for grouping content.
class WalnutCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const WalnutCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: ChessMaterials.walnutPanel(),
      child: child,
    );
  }
}

/// Brass toggle switch (physical lever feel).
class BrassToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const BrassToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.I.click();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 58,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: value
                ? [ChessPalette.brass, ChessPalette.brassAged]
                : [const Color(0xFF2a2118), const Color(0xFF1a140d)],
          ),
          border: Border.all(color: const Color(0xFF8a6d35), width: 1.5),
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
              gradient: const RadialGradient(
                colors: [Color(0xFFf7e3ae), Color(0xFFc5a059)],
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
