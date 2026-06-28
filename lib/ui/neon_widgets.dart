import 'package:flutter/material.dart';

import '../audio/audio_controller.dart';
import '../theme/app_theme.dart';

/// A glowing pill button in the Merge Royal style.
class NeonButton extends StatefulWidget {
  const NeonButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = AppTheme.neon,
    this.width,
    this.fontSize = 26,
    this.height = 64,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final double? width;
  final double fontSize;
  final double height;

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        AudioController.instance.tap();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [widget.color, widget.color.withValues(alpha: 0.78)],
            ),
            borderRadius: BorderRadius.circular(widget.height / 2),
            boxShadow: AppTheme.glow(widget.color, blur: 22, spread: 1),
          ),
          child: Text(
            widget.label,
            style: AppTheme.arcade(
              size: widget.fontSize,
              color: AppTheme.neonText,
              weight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// A round neon icon button (info, pause, sound, home…).
class NeonIconButton extends StatelessWidget {
  const NeonIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color = AppTheme.neon,
    this.size = 56,
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioController.instance.tap();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : AppTheme.panel.withValues(alpha: 0.85),
          border: Border.all(color: color.withValues(alpha: 0.85), width: 2),
          boxShadow: AppTheme.glow(color, blur: 12, spread: 0),
        ),
        child: Icon(icon,
            color: filled ? AppTheme.neonText : color, size: size * 0.5),
      ),
    );
  }
}

/// A bordered neon panel used for dialogs.
class NeonPanel extends StatelessWidget {
  const NeonPanel({super.key, required this.child, this.padding, this.color = AppTheme.neon});

  final Widget child;
  final EdgeInsets? padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF080D11).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color, width: 3),
        boxShadow: AppTheme.glow(color, blur: 26, spread: 2),
      ),
      child: child,
    );
  }
}

/// Glowing arcade text.
class NeonText extends StatelessWidget {
  const NeonText(
    this.text, {
    super.key,
    this.size = 28,
    this.color = AppTheme.neon,
    this.letterSpacing = 2,
  });

  final String text;
  final double size;
  final Color color;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppTheme.arcade(
        size: size,
        color: color,
        letterSpacing: letterSpacing,
        shadows: AppTheme.textGlow(color),
      ),
    );
  }
}
