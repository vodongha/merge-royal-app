import 'package:flutter/material.dart';

/// Central place for the neon "Merge Royal" look & feel.
class AppTheme {
  AppTheme._();

  // Core palette ------------------------------------------------------------
  static const Color background = Color(0xFF050608);
  static const Color panel = Color(0xFF0B1014);
  static const Color neon = Color(0xFF4FF7E0); // primary teal/cyan glow
  static const Color neonDeep = Color(0xFF1FB9A6);
  static const Color neonText = Color(0xFF0A1A18);
  static const Color danger = Color(0xFFFF5A5F);
  static const Color warning = Color(0xFFF7C948);
  static const Color good = Color(0xFF4ADE80);
  static const Color purpleGlow = Color(0xFF8B7DFF);

  // Fonts -------------------------------------------------------------------
  /// Blocky arcade font used for titles & big numbers (close to the mock).
  /// Bundled offline (no network needed) — see pubspec `fonts:`.
  static TextStyle arcade({
    double size = 24,
    Color color = Colors.white,
    FontWeight weight = FontWeight.w400,
    double letterSpacing = 1.5,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: 'Silkscreen',
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      shadows: shadows,
    );
  }

  /// Softer rounded font for body copy. Bundled offline.
  static TextStyle body({
    double size = 16,
    Color color = Colors.white,
    FontWeight weight = FontWeight.w600,
    double letterSpacing = 0.5,
  }) {
    return TextStyle(
      fontFamily: 'Baloo2',
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacing,
    );
  }

  // Neon glow helpers -------------------------------------------------------
  static List<BoxShadow> glow(Color color, {double blur = 18, double spread = 1}) {
    return [
      BoxShadow(color: color.withValues(alpha: 0.85), blurRadius: blur, spreadRadius: spread),
      BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: blur * 2.2, spreadRadius: spread * 2),
    ];
  }

  static List<Shadow> textGlow(Color color, {double blur = 14}) {
    return [
      Shadow(color: color.withValues(alpha: 0.9), blurRadius: blur),
      Shadow(color: color.withValues(alpha: 0.5), blurRadius: blur * 2),
    ];
  }

  /// Color of a card given its 2048-style value. Mirrors the screenshots:
  /// light cards for small values, blue / pink / purple / orange for bigger.
  static List<Color> cardGradient(int value) {
    switch (value) {
      case 2:
        return const [Color(0xFFFDFDFB), Color(0xFFE9EAE6)];
      case 4:
        return const [Color(0xFFFBF4E6), Color(0xFFF2E6C9)];
      case 8:
        return const [Color(0xFFF6EAD8), Color(0xFFE8D2AE)];
      case 16:
        return const [Color(0xFFF3E1C8), Color(0xFFE2C39B)];
      case 32:
        return const [Color(0xFFF6D6BE), Color(0xFFEFBA98)];
      case 64:
        return const [Color(0xFFF4C9A8), Color(0xFFE9A878)];
      case 128:
        return const [Color(0xFFCFE0F2), Color(0xFFAFC7E8)];
      case 256:
        return const [Color(0xFFBBD2EE), Color(0xFF93B6E0)];
      case 512:
        return const [Color(0xFFCDBEF2), Color(0xFFAE97E6)];
      case 1024:
        return const [Color(0xFFF2C6E0), Color(0xFFE49ECB)];
      case 2048:
        return const [Color(0xFFF2B6D2), Color(0xFFE489BC)];
      case 4096:
        return const [Color(0xFFBFE3DA), Color(0xFF93D2C2)];
      default:
        return const [Color(0xFFB9F0E6), Color(0xFF7FD9C8)];
    }
  }

  /// Dark ink color used for the number printed on a card.
  static Color cardInk(int value) => const Color(0xFF1A1A1A);
}
