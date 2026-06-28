import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../audio/audio_controller.dart';
import '../game/game_controller.dart';
import '../game/merge_royal_game.dart';
import '../theme/app_theme.dart';
import 'hud.dart';
import 'neon_widgets.dart';
import 'overlays.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.continueGame});
  final bool continueGame;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameController controller = GameController();
  late final MergeRoyalGame _game = MergeRoyalGame(controller);

  bool _ready = false;
  bool _paused = false;
  bool _howTo = false;
  bool _gameOver = false;

  _LevelUpInfo? _levelUp;
  String? _toast;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    controller.onLevelUp = (lvl) {
      AudioController.instance.levelUp();
      setState(() => _levelUp = _LevelUpInfo(lvl, controller.totalScore));
      Future.delayed(const Duration(milliseconds: 1700), () {
        if (mounted) setState(() => _levelUp = null);
      });
    };
    controller.onGameOver = () {
      AudioController.instance.gameOver();
      if (mounted) setState(() => _gameOver = true);
    };
    controller.onToast = _showToast;

    if (widget.continueGame) {
      final ok = await controller.loadSave();
      if (!ok) await controller.startNewGame();
    } else {
      await controller.startNewGame();
    }
    await AudioController.instance.startMusic();
    if (mounted) setState(() => _ready = true);
  }

  void _showToast(String msg) {
    _toastTimer?.cancel();
    setState(() => _toast = msg);
    _toastTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  void _setPaused(bool v) {
    setState(() {
      _paused = v;
      controller.isPaused = v;
    });
  }

  void _retry() {
    setState(() {
      _gameOver = false;
      _levelUp = null;
    });
    controller.startNewGame();
    _game.sync(animate: false);
  }

  void _goHome() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: !_ready
          ? const Center(child: CircularProgressIndicator(color: AppTheme.neon))
          : Stack(children: [
              Positioned.fill(child: GameWidget(game: _game)),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: TopHud(
                      controller: controller,
                      onInfo: () {
                        _setPaused(true);
                        setState(() => _howTo = true);
                      },
                      onPause: () => _setPaused(true),
                    ),
                  ),
                ),
              ),
              // Bottom labels + power bar.
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _CornerStat(
                                  value: '${controller.mistakesLeft}',
                                  label: 'MISTAKES\nLEFT'),
                              _CornerStat(
                                  value: '${controller.draggableCount}',
                                  label: 'DRAGGABLE\nAT A TIME',
                                  alignEnd: true,
                                  card: true),
                            ],
                          ),
                        ),
                        PowerBar(controller: controller),
                      ],
                    ),
                  ),
                ),
              ),
              if (_toast != null) _ToastBanner(message: _toast!),
              if (_levelUp != null)
                LevelUpOverlay(level: _levelUp!.level, points: _levelUp!.points),
              if (_paused && !_howTo)
                PauseDialog(
                  onResume: () => _setPaused(false),
                  onHome: _goHome,
                  muted: AudioController.instance.muted.value,
                  onToggleSound: () async {
                    await AudioController.instance.toggleMute();
                    if (mounted) setState(() {});
                  },
                ),
              if (_howTo)
                HowToPlayDialog(onClose: () {
                  setState(() => _howTo = false);
                  _setPaused(false);
                }),
              if (_gameOver)
                GameOverDialog(
                  score: controller.totalScore,
                  best: controller.bestScore,
                  level: controller.level,
                  onRetry: _retry,
                  onHome: _goHome,
                ),
            ]),
    );
  }
}

class _LevelUpInfo {
  _LevelUpInfo(this.level, this.points);
  final int level;
  final int points;
}

class _CornerStat extends StatelessWidget {
  const _CornerStat({
    required this.value,
    required this.label,
    this.alignEnd = false,
    this.card = false,
  });

  final String value;
  final String label;
  final bool alignEnd;
  final bool card;

  @override
  Widget build(BuildContext context) {
    final number = card
        ? Container(
            width: 58,
            height: 76,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: AppTheme.glow(Colors.white, blur: 8),
            ),
            child: Text(value,
                style: AppTheme.arcade(size: 30, color: Colors.black87, letterSpacing: 0)),
          )
        : NeonText(value, size: 44, color: Colors.white);

    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        number,
        const SizedBox(height: 4),
        Text(label,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: AppTheme.arcade(size: 13, color: AppTheme.neon, letterSpacing: 1)),
      ],
    );
  }
}

class _ToastBanner extends StatelessWidget {
  const _ToastBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, -0.15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.neon, width: 2),
          boxShadow: AppTheme.glow(AppTheme.neon, blur: 12),
        ),
        child: NeonText(message, size: 22),
      ),
    );
  }
}
