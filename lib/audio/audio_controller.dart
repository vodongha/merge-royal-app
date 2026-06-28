import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralised sound: preloads SFX, plays the looping music bed and exposes a
/// persisted [muted] flag shared by the menu, pause dialog and game.
class AudioController {
  AudioController._();
  static final AudioController instance = AudioController._();

  static const _kMutedKey = 'merge_royal_muted';
  static const _sfx = <String>[
    'tap.wav',
    'merge.wav',
    'combo.wav',
    'mistake.wav',
    'bomb.wav',
    'shuffle.wav',
    'levelup.wav',
    'gameover.wav',
  ];

  final ValueNotifier<bool> muted = ValueNotifier<bool>(false);
  bool _ready = false;
  bool _musicWanted = false;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      muted.value = prefs.getBool(_kMutedKey) ?? false;
      await FlameAudio.audioCache.loadAll(_sfx);
      _ready = true;
    } catch (_) {/* audio is best-effort */}
  }

  Future<void> toggleMute() => setMuted(!muted.value);

  Future<void> setMuted(bool value) async {
    muted.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kMutedKey, value);
    } catch (_) {}
    if (value) {
      _pauseMusic();
    } else if (_musicWanted) {
      _resumeMusic();
    }
  }

  void _play(String file, {double volume = 1.0}) {
    if (muted.value || !_ready) return;
    try {
      FlameAudio.play(file, volume: volume);
    } catch (_) {}
  }

  void tap() => _play('tap.wav', volume: 0.5);
  void mistake() => _play('mistake.wav', volume: 0.8);
  void bomb() => _play('bomb.wav', volume: 0.9);
  void shuffle() => _play('shuffle.wav', volume: 0.7);
  void levelUp() => _play('levelup.wav', volume: 0.9);
  void gameOver() => _play('gameover.wav', volume: 0.9);

  void merge(int combo) {
    _play('merge.wav', volume: 0.8);
    if (combo > 1) _play('combo.wav', volume: 0.7);
  }

  // ---- Background music ---------------------------------------------------
  Future<void> startMusic() async {
    _musicWanted = true;
    if (muted.value) return;
    try {
      await FlameAudio.bgm.play('music.wav', volume: 0.35);
    } catch (_) {}
  }

  void stopMusic() {
    _musicWanted = false;
    try {
      FlameAudio.bgm.stop();
    } catch (_) {}
  }

  void _pauseMusic() {
    try {
      FlameAudio.bgm.pause();
    } catch (_) {}
  }

  void _resumeMusic() {
    try {
      FlameAudio.bgm.resume();
    } catch (_) {}
  }
}
