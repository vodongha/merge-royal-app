import 'package:flutter/material.dart';

import '../audio/audio_controller.dart';
import '../game/game_controller.dart';
import '../theme/app_theme.dart';
import 'neon_widgets.dart';

/// Top status bar: level pips, progress, score and combo flash.
class TopHud extends StatelessWidget {
  const TopHud({super.key, required this.controller, required this.onInfo, required this.onPause});

  final GameController controller;
  final VoidCallback onInfo;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          children: [
            Row(
              children: [
                NeonIconButton(icon: Icons.info_outline, onTap: onInfo, size: 50),
                const Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _GameTitle(),
                    ),
                  ),
                ),
                NeonIconButton(icon: Icons.pause, onTap: onPause, size: 50),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _LevelPip(level: controller.level),
                const SizedBox(width: 10),
                Expanded(child: _ProgressBar(value: controller.levelProgress)),
                const SizedBox(width: 10),
                _LevelPip(level: controller.level + 1, dim: true),
              ],
            ),
            // Pull the score up toward the level bar (higher on screen).
            Transform.translate(
              offset: const Offset(0, -14),
              child: _ScoreLine(score: controller.levelScore),
            ),
          ],
        );
      },
    );
  }
}

/// Compact "MERGE ROYAL" wordmark shown between the info and pause buttons.
class _GameTitle extends StatelessWidget {
  const _GameTitle();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(children: [
        TextSpan(
          text: 'MERGE ',
          style: AppTheme.arcade(
            size: 32,
            color: Colors.white,
            letterSpacing: 2,
            shadows: AppTheme.textGlow(Colors.white, blur: 10),
          ),
        ),
        TextSpan(
          text: 'ROYAL',
          style: AppTheme.arcade(
            size: 32,
            color: AppTheme.neon,
            letterSpacing: 2,
            shadows: AppTheme.textGlow(AppTheme.neon, blur: 12),
          ),
        ),
      ]),
    );
  }
}

class _LevelPip extends StatelessWidget {
  const _LevelPip({required this.level, this.dim = false});
  final int level;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final c = dim ? Colors.white54 : Colors.white;
    return Container(
      width: 54,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF14191D),
        border: Border.all(color: c, width: 2.5),
        boxShadow: dim ? null : AppTheme.glow(Colors.white, blur: 10),
      ),
      child: Text('$level',
          style: AppTheme.arcade(size: 20, color: c, letterSpacing: 0)),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF14191D),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white24, width: 2),
      ),
      child: LayoutBuilder(builder: (context, c) {
        return Stack(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: (c.maxWidth * value).clamp(0, c.maxWidth),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.neonDeep, AppTheme.neon]),
              borderRadius: BorderRadius.circular(9),
              boxShadow: AppTheme.glow(AppTheme.neon, blur: 10),
            ),
          ),
        ]);
      }),
    );
  }
}

class _ScoreLine extends StatelessWidget {
  const _ScoreLine({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return NeonText('$score', size: 38, color: Colors.white, letterSpacing: 2);
  }
}

/// Bottom power-up bar with bomb + shuffle.
class PowerBar extends StatelessWidget {
  const PowerBar({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.neonDeep.withValues(alpha: 0.9),
              AppTheme.neon.withValues(alpha: 0.85),
            ]),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: AppTheme.glow(AppTheme.neon, blur: 18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          // DEAL sits on the left; the bomb + shuffle pair is centered in the
          // full bar (a Stack keeps them centered regardless of the deal button).
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _DealButton(onTap: () {
                  AudioController.instance.tap();
                  controller.dealNow();
                }),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PowerIcon(
                    icon: Icons.local_fire_department,
                    bg: const [Color(0xFFFF7A3D), Color(0xFFB71C1C)],
                    count: controller.bombs,
                    armed: controller.bombArmed,
                    onTap: controller.armBomb,
                  ),
                  const SizedBox(width: 22),
                  _PowerIcon(
                    icon: Icons.shuffle,
                    bg: const [Color(0xFF3D5BFF), Color(0xFF1A237E)],
                    count: controller.shuffles,
                    armed: false,
                    onTap: controller.useShuffle,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Deck button — tap to deal a fresh row of cards on demand. Presses in with a
/// springy scale so the tap feels responsive.
class _DealButton extends StatefulWidget {
  const _DealButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_DealButton> createState() => _DealButtonState();
}

class _DealButtonState extends State<_DealButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) {
        _setPressed(false);
        widget.onTap();
      },
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.84 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutBack,
        // Same 62×62 footprint as the bomb / shuffle power icons, no label.
        child: SizedBox(
          width: 62,
          height: 62,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Transform.rotate(angle: -0.20, child: _miniCard()),
              Transform.rotate(angle: 0.10, child: _miniCard()),
              AnimatedContainer(
                duration: const Duration(milliseconds: 110),
                curve: Curves.easeOut,
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.neonDeep,
                  shape: BoxShape.circle,
                  boxShadow:
                      _pressed ? AppTheme.glow(Colors.white, blur: 10) : null,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniCard() => Container(
        width: 40,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.black26, width: 1.5),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
      );
}

class _PowerIcon extends StatelessWidget {
  const _PowerIcon({
    required this.icon,
    required this.bg,
    required this.count,
    required this.armed,
    required this.onTap,
  });

  final IconData icon;
  final List<Color> bg;
  final int count;
  final bool armed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = count > 0;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: enabled ? bg : const [Color(0xFF555555), Color(0xFF333333)]),
            border: Border.all(
                color: armed ? Colors.white : Colors.black26, width: armed ? 3 : 2),
            boxShadow: armed ? AppTheme.glow(Colors.white, blur: 14) : null,
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: Color(0xFF14191D), shape: BoxShape.circle),
            child: Text('$count',
                style: AppTheme.arcade(size: 13, color: Colors.white, letterSpacing: 0)),
          ),
        ),
      ]),
    );
  }
}
