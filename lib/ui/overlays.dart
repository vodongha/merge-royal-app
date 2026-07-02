import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'neon_widgets.dart';

/// Dimmed backdrop shared by modal dialogs.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        child: Container(
          color: Colors.black.withValues(alpha: 0.72),
          alignment: Alignment.center,
          child: GestureDetector(onTap: () {}, child: child),
        ),
      ),
    );
  }
}

/// PAUSE dialog: resume / mute / home.
class PauseDialog extends StatelessWidget {
  const PauseDialog({
    super.key,
    required this.onResume,
    required this.onHome,
    required this.onToggleSound,
    required this.muted,
  });

  final VoidCallback onResume;
  final VoidCallback onHome;
  final VoidCallback onToggleSound;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return _Scrim(
      child: NeonPanel(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 34),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const NeonText('PAUSE', size: 44, color: Colors.white),
          const SizedBox(height: 26),
          NeonButton(label: 'RESUME', onTap: onResume, width: 240),
          const SizedBox(height: 26),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            NeonIconButton(
              icon: muted ? Icons.volume_off : Icons.volume_up,
              onTap: onToggleSound,
              color: const Color(0xFF3D7BFF),
              filled: true,
            ),
            const SizedBox(width: 28),
            NeonIconButton(
                icon: Icons.home, onTap: onHome, color: AppTheme.danger, filled: true),
          ]),
        ]),
      ),
    );
  }
}

/// LEVEL UP! celebratory overlay (auto-dismisses).
class LevelUpOverlay extends StatefulWidget {
  const LevelUpOverlay({super.key, required this.level, required this.points});
  final int level;
  final int points;

  @override
  State<LevelUpOverlay> createState() => _LevelUpOverlayState();
}

class _LevelUpOverlayState extends State<LevelUpOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))
        ..forward();
  final List<_Confetto> _confetti =
      List.generate(60, (_) => _Confetto.random());

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ac,
                builder: (context, _) => CustomPaint(
                  painter: _ConfettiPainter(_confetti, _ac.value),
                ),
              ),
            ),
            ScaleTransition(
              scale: CurvedAnimation(
                  parent: _ac, curve: const Interval(0, 0.28, curve: Curves.elasticOut)),
              child: NeonPanel(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 34),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 120,
              height: 120,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.good.withValues(alpha: 0.15),
                border: Border.all(color: AppTheme.good, width: 4),
                boxShadow: AppTheme.glow(AppTheme.good, blur: 24),
              ),
              child: NeonText('${widget.level}', size: 52, color: Colors.white),
            ),
            const SizedBox(height: 18),
            const NeonText('LEVEL UP!', size: 34),
            const SizedBox(height: 18),
            Container(
              width: 240,
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.good.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.good, width: 2),
              ),
              child: NeonText('${widget.points} POINTS',
                  size: 20, color: AppTheme.good),
            ),
          ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Confetto {
  _Confetto(this.x, this.color, this.size, this.drift, this.rot, this.delay, this.fall);
  final double x; // start x as fraction of width
  final Color color;
  final double size;
  final double drift; // horizontal drift fraction
  final double rot; // rotations over the animation
  final double delay; // 0..0.3 start delay
  final double fall; // fall speed factor

  static final _r = Random();
  static const _palette = [
    AppTheme.neon,
    AppTheme.good,
    AppTheme.warning,
    AppTheme.danger,
    AppTheme.purpleGlow,
    Colors.white,
  ];

  factory _Confetto.random() => _Confetto(
        _r.nextDouble(),
        _palette[_r.nextInt(_palette.length)],
        6 + _r.nextDouble() * 8,
        (_r.nextDouble() - 0.5) * 0.4,
        (_r.nextDouble() - 0.5) * 8,
        _r.nextDouble() * 0.3,
        0.7 + _r.nextDouble() * 0.6,
      );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Confetto> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = (-0.1 + local * p.fall * 1.2) * size.height;
      final x = (p.x + p.drift * local) * size.width;
      final fade = local > 0.85 ? (1 - (local - 0.85) / 0.15) : 1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot * local * 2 * pi);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
        Paint()..color = p.color.withValues(alpha: fade.clamp(0.0, 1.0)),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Big centre flash that pops in then fades away. Shows a green/amber combo
/// multiplier (×2, ×3 …) on a merge, or a red point penalty (-1, -2 …) on a
/// wrong drop when [penalty] is true.
class ComboPopup extends StatefulWidget {
  const ComboPopup(
      {super.key,
      required this.combo,
      required this.onDone,
      this.penalty = false});
  final int combo;
  final VoidCallback onDone;
  final bool penalty;

  @override
  State<ComboPopup> createState() => _ComboPopupState();
}

class _ComboPopupState extends State<ComboPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 850))
    ..forward();

  @override
  void initState() {
    super.initState();
    _ac.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  // Score-up popups (×2, ×3 …) are always amber; penalty popups (-1, -2 …) red.
  Color get _color => widget.penalty ? AppTheme.danger : AppTheme.warning;

  String get _label => widget.penalty ? '-${widget.combo}' : '×${widget.combo}';

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _ac,
            builder: (context, _) {
              final t = _ac.value;
              final scale = t < 0.35
                  ? Curves.elasticOut.transform(t / 0.35)
                  : 1.0 + (t - 0.35) / 0.65 * 0.5;
              final opacity = t < 0.65 ? 1.0 : (1 - (t - 0.65) / 0.35);
              return Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale.clamp(0.0, 2.0),
                  child: Text(
                    _label,
                    style: AppTheme.arcade(
                      size: 110,
                      color: _color,
                      weight: FontWeight.w700,
                      shadows: AppTheme.textGlow(_color, blur: 28),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// GAME OVER dialog.
class GameOverDialog extends StatelessWidget {
  const GameOverDialog({
    super.key,
    required this.score,
    required this.best,
    required this.level,
    required this.onRetry,
    required this.onHome,
  });

  final int score;
  final int best;
  final int level;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    return _Scrim(
      child: NeonPanel(
        color: AppTheme.danger,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 30),
        // Constrain to the button width so the stat rows (space-between) don't
        // stretch the panel to full screen width and clip its neon border.
        child: SizedBox(
          width: 240,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const NeonText('GAME OVER', size: 34, color: AppTheme.danger),
            const SizedBox(height: 22),
            _stat('SCORE', '$score'),
            const SizedBox(height: 10),
            _stat('BEST', '$best'),
            const SizedBox(height: 10),
            _stat('LEVEL', '$level'),
            const SizedBox(height: 26),
            NeonButton(label: 'RETRY', onTap: onRetry, width: 240),
            const SizedBox(height: 16),
            NeonButton(
                label: 'HOME',
                onTap: onHome,
                width: 240,
                color: const Color(0xFF3D7BFF)),
          ]),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: AppTheme.body(size: 18, color: Colors.white70)),
      const SizedBox(width: 30),
      Text(value, style: AppTheme.arcade(size: 22, color: Colors.white)),
    ]);
  }
}

/// Full HOW TO PLAY screen (objective / controls / tip).
class HowToPlayDialog extends StatelessWidget {
  const HowToPlayDialog({super.key, required this.onClose});
  final VoidCallback onClose;

  static const _blue = Color(0xFF3D8BFF);
  static const _pink = Color(0xFFE0467A);
  static const _orange = Color(0xFFFF8A3D);
  static const _dark = Color(0xFF1B2432);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF05080B),
        child: SafeArea(
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
              child: Row(children: [
                const Expanded(child: NeonText('HOW TO PLAY', size: 26)),
                NeonIconButton(icon: Icons.close, onTap: onClose, size: 46),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                children: [
                  _section(
                    accent: AppTheme.neon,
                    icon: Icons.emoji_events_rounded,
                    title: 'GOAL',
                    body:
                        'Merge cards of the same number to grow them (2+2 = 4, 4+4 = 8 …) and score as high as you can. Keep a column from stacking down to the dashed line or it\'s game over.',
                  ),
                  _section(
                    accent: _blue,
                    icon: Icons.touch_app_rounded,
                    title: 'HOW TO MERGE',
                    body:
                        'Drag the front card of a column onto a matching card. Chain a staircase (2 → 4 → 8 …) to set off a combo.',
                    child: _mergeExample(),
                  ),
                  _section(
                    accent: AppTheme.warning,
                    icon: Icons.bolt_rounded,
                    title: 'COMBOS',
                    body:
                        'When cards cascade in one move you get a combo — an amber ×2, ×3 … flash and bonus points.',
                  ),
                  _section(
                    accent: _pink,
                    icon: Icons.style_rounded,
                    title: 'SPECIAL CARDS',
                    body: 'Merge a suit card (amber halo) to trigger its bonus:',
                    child: _cardLegend(),
                  ),
                  _section(
                    accent: AppTheme.danger,
                    icon: Icons.warning_amber_rounded,
                    title: 'PENALTY',
                    body:
                        'Dropping on a card that does NOT match is a wrong merge — it costs a MISTAKE and points (red −1, −2 … rising with each wrong drop in a row). Moving onto an empty slot is always free.',
                  ),
                  _section(
                    accent: _orange,
                    icon: Icons.whatshot_rounded,
                    title: 'POWER-UPS',
                    body:
                        'BOMB destroys a 🚫 locked card. SHUFFLE rearranges the whole board. Tap one, then tap a column to use it.',
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _section({
    required Color accent,
    required IconData icon,
    required String title,
    required String body,
    Widget? child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E151B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.18),
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 12),
          Text(title, style: AppTheme.arcade(size: 17, color: accent)),
        ]),
        const SizedBox(height: 12),
        Text(body,
            style: AppTheme.body(
                size: 14.5, color: Colors.white70, weight: FontWeight.w500)),
        if (child != null) ...[const SizedBox(height: 14), child],
      ]),
    );
  }

  Widget _mergeExample() {
    Widget arrow(IconData i) =>
        Icon(i, color: Colors.white38, size: 22);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _miniCard('2', '♠', _dark),
      const SizedBox(width: 6),
      arrow(Icons.add_rounded),
      const SizedBox(width: 6),
      _miniCard('2', '♠', _dark),
      const SizedBox(width: 8),
      arrow(Icons.arrow_forward_rounded),
      const SizedBox(width: 8),
      _miniCard('4', '♥', const Color(0xFFD8324B)),
    ]);
  }

  Widget _cardLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _legend('♠', _dark, '+Score'),
        _legend('♥', const Color(0xFFD8324B), '+Life'),
        _legend('♣', _dark, '+Bomb'),
        _legend('♦', const Color(0xFFD8324B), '+Shuffle'),
        _legend('♛', _pink, 'Jackpot'),
        _legend('🚫', _dark, 'Locked', locked: true),
      ],
    );
  }

  Widget _legend(String sym, Color symColor, String label,
      {bool locked = false}) {
    return SizedBox(
      width: 62,
      child: Column(children: [
        _miniCard('', sym, symColor, locked: locked),
        const SizedBox(height: 5),
        Text(label,
            textAlign: TextAlign.center,
            style: AppTheme.body(
                size: 11.5, color: Colors.white60, weight: FontWeight.w600)),
      ]),
    );
  }

  Widget _miniCard(String num, String sym, Color symColor,
      {bool locked = false}) {
    return Container(
      width: 46,
      height: 62,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: locked
              ? const [Color(0xFFDDE1E4), Color(0xFFBBC0C4)]
              : const [Color(0xFFFDFDFB), Color(0xFFE9EAE6)],
        ),
        borderRadius: BorderRadius.circular(9),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(children: [
        if (num.isNotEmpty)
          Positioned(
            top: 3,
            left: 6,
            child: Text(num,
                style: AppTheme.arcade(size: 12, color: _dark)),
          ),
        Center(
          child: locked
              ? const Icon(Icons.block_rounded,
                  color: Color(0xFFE53935), size: 24)
              : Text(sym, style: TextStyle(fontSize: 24, color: symColor)),
        ),
      ]),
    );
  }
}
