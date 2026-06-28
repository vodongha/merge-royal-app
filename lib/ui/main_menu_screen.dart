import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';
import 'neon_widgets.dart';
import 'overlays.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  bool _hasSave = false;
  bool _muted = false;
  bool _howTo = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final has = await GameController().hasSave();
    if (mounted) setState(() => _hasSave = has);
  }

  Future<void> _open(bool continueGame) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(continueGame: continueGame)),
    );
    _refresh(); // a finished game may have cleared the save
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(children: [
              const SizedBox(height: 70),
              const NeonText('MERGE ROYAL', size: 46),
              const SizedBox(height: 10),
              NeonText('MERGE TO WIN', size: 18, color: Colors.white70),
              const Spacer(flex: 3),
              if (_hasSave) ...[
                NeonButton(
                    label: 'CONTINUE',
                    onTap: () => _open(true),
                    width: double.infinity),
                const SizedBox(height: 22),
              ],
              NeonButton(
                  label: 'NEW GAME',
                  onTap: () => _open(false),
                  width: double.infinity),
              const Spacer(flex: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                NeonIconButton(
                  icon: _muted ? Icons.volume_off : Icons.volume_up,
                  onTap: () => setState(() => _muted = !_muted),
                  color: const Color(0xFF3D7BFF),
                  filled: true,
                  size: 52,
                ),
                const SizedBox(width: 24),
                NeonIconButton(
                  icon: Icons.info_outline,
                  onTap: () => setState(() => _howTo = true),
                  color: const Color(0xFF3D7BFF),
                  filled: true,
                  size: 52,
                ),
              ]),
              const SizedBox(height: 30),
            ]),
          ),
        ),
        if (_howTo) HowToPlayDialog(onClose: () => setState(() => _howTo = false)),
      ]),
    );
  }
}
