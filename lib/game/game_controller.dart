import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_data.dart';

/// Result of attempting to move a card group from one column to another.
enum MoveResult { merged, relocated, illegal, cancelled }

/// One-shot event emitted to the renderer for juice (particles / sound).
class MergeEvent {
  MergeEvent(this.column, this.value, this.combo, this.suit);
  final int column;
  final int value; // resulting value
  final int combo; // chain length / multiplier
  final Suit suit;
}

const int kColumnCount = 4;
const int kColumnCapacity = 6;
const String _kSaveKey = 'merge_royal_save_v1';

/// The single source of truth for the game. The Flame world and all the
/// Flutter overlays read from / drive this controller.
class GameController extends ChangeNotifier {
  GameController();

  final Random _rng = Random();

  // ---- State --------------------------------------------------------------
  final List<List<CardData>> columns =
      List.generate(kColumnCount, (_) => <CardData>[]);

  int level = 1;
  int levelScore = 0; // resets each level (the big number under the bar)
  int totalScore = 0;
  int mistakesLeft = 10;
  int draggableCount = 3;
  int bombs = 1;
  int shuffles = 1;
  int comboMultiplier = 1; // last combo, drives the "X2" flash
  bool bombArmed = false;
  bool gameOver = false;
  bool isPaused = false;
  int bestScore = 0;

  // ---- One-shot event hooks (set by the renderer) -------------------------
  void Function(MergeEvent event)? onMerge;
  void Function(int level)? onLevelUp;
  VoidCallback? onGameOver;
  void Function(String message)? onToast;
  void Function(int column)? onBomb;
  VoidCallback? onShuffle;
  VoidCallback? onMistake;

  int get levelTarget => 1000 + level * 900;
  double get levelProgress => (levelScore / levelTarget).clamp(0.0, 1.0);
  bool get hasBomb => bombs > 0;
  bool get hasShuffle => shuffles > 0;

  /// Fill ratio of a column (0..1) for its little progress bar.
  double columnFill(int col) => columns[col].length / kColumnCapacity;

  // ---- Lifecycle ----------------------------------------------------------
  Future<void> startNewGame() async {
    level = 1;
    levelScore = 0;
    totalScore = 0;
    mistakesLeft = 10;
    bombs = 1;
    shuffles = 1;
    comboMultiplier = 1;
    bombArmed = false;
    gameOver = false;
    isPaused = false;
    _applyLevelTuning();
    _dealInitialBoard();
    notifyListeners();
    await save();
  }

  void _applyLevelTuning() {
    draggableCount = 3 + min(2, level ~/ 4); // 3..5
  }

  /// Deal a fresh board with a few low cards per column.
  void _dealInitialBoard() {
    for (final c in columns) {
      c.clear();
    }
    for (int col = 0; col < kColumnCount; col++) {
      final n = 2 + _rng.nextInt(2); // 2..3 cards
      for (int i = 0; i < n; i++) {
        columns[col].add(_spawnCard(allowHazards: false));
      }
    }
  }

  CardData _spawnCard({bool allowHazards = true}) {
    // Base value grows slowly with level.
    final tier = min(4, 1 + level ~/ 3); // how many low values are in the bag
    final choices = <int>[2, 4, 8, 16, 32];
    final value = choices[_rng.nextInt(min(choices.length, 1 + tier))];

    if (allowHazards) {
      final lockChance = (0.04 + level * 0.012).clamp(0.0, 0.22);
      if (_rng.nextDouble() < lockChance) {
        return CardData(value: value, locked: true);
      }
      final specialChance = 0.12 + level * 0.006;
      if (_rng.nextDouble() < specialChance) {
        return CardData(value: value, suit: _randomSuit());
      }
    }
    return CardData(value: value);
  }

  Suit _randomSuit() {
    // Crown is rare (jackpot), the rest are common helpers.
    final roll = _rng.nextDouble();
    if (roll < 0.08) return Suit.crown;
    const common = [Suit.spade, Suit.heart, Suit.club, Suit.diamond];
    return common[_rng.nextInt(common.length)];
  }

  // ---- Grabbing -----------------------------------------------------------
  /// How many cards can be grabbed from the front of [col] as one group:
  /// a contiguous run of equal, movable cards, capped by [draggableCount].
  int grabbableCount(int col) {
    final c = columns[col];
    if (c.isEmpty) return 0;
    final front = c.last;
    if (front.locked) return 0; // locked cards can't be dragged
    if (front.isSpecial) return 1; // specials move one at a time
    int count = 1;
    for (int i = c.length - 2; i >= 0 && count < draggableCount; i--) {
      final card = c[i];
      if (card.locked || card.isSpecial || card.value != front.value) break;
      count++;
    }
    return count;
  }

  // ---- Moving -------------------------------------------------------------
  MoveResult moveGroup(int from, int to, int groupSize) {
    if (gameOver) return MoveResult.cancelled;
    if (from == to) return MoveResult.cancelled;
    final src = columns[from];
    if (src.isEmpty || groupSize <= 0) return MoveResult.cancelled;
    groupSize = min(groupSize, src.length);

    final dst = columns[to];
    final leading = src[src.length - groupSize]; // deepest card of the group

    // Empty destination -> free relocation (respect capacity).
    if (dst.isEmpty) {
      if (groupSize > kColumnCapacity) return MoveResult.illegal;
      _transfer(src, dst, groupSize);
      _afterMove(to, merged: false);
      return MoveResult.relocated;
    }

    final dstFront = dst.last;
    final canMerge = !dstFront.locked &&
        !leading.locked &&
        dstFront.value == leading.value;

    if (!canMerge) {
      // Wrong drop -> a mistake.
      _registerMistake();
      return MoveResult.illegal;
    }

    if (dst.length + groupSize > kColumnCapacity + 2) {
      return MoveResult.illegal;
    }

    _transfer(src, dst, groupSize);
    final combo = _collapse(to);
    _afterMove(to, merged: true, combo: combo);
    return MoveResult.merged;
  }

  void _transfer(List<CardData> src, List<CardData> dst, int n) {
    final moved = src.sublist(src.length - n);
    src.removeRange(src.length - n, src.length);
    dst.addAll(moved);
  }

  /// Greedy front cascade: while the two front cards match, merge them.
  /// Returns the combo length (number of merges performed).
  int _collapse(int col) {
    final c = columns[col];
    int combo = 0;
    while (c.length >= 2) {
      final a = c[c.length - 1];
      final b = c[c.length - 2];
      if (a.locked || b.locked || a.value != b.value) break;

      // Consume both, keep the deeper card as the merged one.
      c.removeLast();
      b.value *= 2;
      combo++;

      _applySuitBonus(a);
      _applySuitBonus(b);
      b.suit = Suit.none; // merged result becomes a plain card

      final gained = b.value * (combo); // later merges in a chain score more
      _addScore(gained);

      onMerge?.call(MergeEvent(col, b.value, combo, a.suit));
    }
    comboMultiplier = max(1, combo);
    return combo;
  }

  void _applySuitBonus(CardData card) {
    switch (card.suit) {
      case Suit.spade:
        _addScore(card.value * 4); // big score
        break;
      case Suit.heart:
        if (mistakesLeft < 99) mistakesLeft++;
        onToast?.call('+1 MISTAKE');
        break;
      case Suit.club:
        bombs++;
        onToast?.call('+1 BOMB');
        break;
      case Suit.diamond:
        shuffles++;
        onToast?.call('+1 SHUFFLE');
        break;
      case Suit.crown:
        _addScore(card.value * 10); // jackpot
        onToast?.call('JACKPOT!');
        break;
      case Suit.none:
        break;
    }
  }

  void _addScore(int amount) {
    levelScore += amount;
    totalScore += amount;
    if (totalScore > bestScore) bestScore = totalScore;
    while (levelScore >= levelTarget) {
      levelScore -= levelTarget;
      _levelUp();
    }
  }

  void _levelUp() {
    level++;
    mistakesLeft = min(99, mistakesLeft + 1);
    bombs++;
    _applyLevelTuning();
    onLevelUp?.call(level);
  }

  void _afterMove(int touchedCol, {required bool merged, int combo = 0}) {
    _spawnAfterMove();
    _checkGameOver();
    notifyListeners();
    save();
  }

  void _registerMistake() {
    mistakesLeft--;
    onMistake?.call();
    onToast?.call('MISTAKE!');
    if (mistakesLeft <= 0) {
      mistakesLeft = 0;
      _triggerGameOver();
    }
    notifyListeners();
    save();
  }

  void _spawnAfterMove() {
    // Drop a new card into the emptiest column.
    int target = -1;
    int best = 1 << 30;
    for (int i = 0; i < kColumnCount; i++) {
      if (columns[i].length < best) {
        best = columns[i].length;
        target = i;
      }
    }
    if (target >= 0 && columns[target].length < kColumnCapacity) {
      columns[target].add(_spawnCard());
    }
  }

  // ---- Power-ups ----------------------------------------------------------
  void armBomb() {
    if (!hasBomb || gameOver) return;
    bombArmed = !bombArmed;
    notifyListeners();
  }

  /// Detonate on the front card of [col]. Returns true if something blew up.
  bool detonate(int col) {
    if (!bombArmed || !hasBomb || gameOver) return false;
    final c = columns[col];
    if (c.isEmpty) {
      bombArmed = false;
      notifyListeners();
      return false;
    }
    c.removeLast();
    bombs--;
    bombArmed = false;
    onBomb?.call(col);
    onToast?.call('BOOM!');
    _checkGameOver();
    notifyListeners();
    save();
    return true;
  }

  void useShuffle() {
    if (!hasShuffle || gameOver) return;
    final all = <CardData>[];
    for (final c in columns) {
      all.addAll(c);
      c.clear();
    }
    all.shuffle(_rng);
    for (int i = 0; i < all.length; i++) {
      columns[i % kColumnCount].add(all[i]);
    }
    shuffles--;
    onShuffle?.call();
    onToast?.call('SHUFFLED');
    notifyListeners();
    save();
  }

  // ---- Game-over detection ------------------------------------------------
  bool _boardFull() => columns.every((c) => c.length >= kColumnCapacity);

  bool _hasLegalMerge() {
    for (int i = 0; i < kColumnCount; i++) {
      if (columns[i].isEmpty) return true; // can always relocate
      final fi = columns[i].last;
      if (fi.locked) continue;
      for (int j = 0; j < kColumnCount; j++) {
        if (i == j || columns[j].isEmpty) continue;
        final fj = columns[j].last;
        if (!fj.locked && fj.value == fi.value) return true;
      }
    }
    return false;
  }

  void _checkGameOver() {
    if (gameOver) return;
    if (mistakesLeft <= 0) {
      _triggerGameOver();
      return;
    }
    if (_boardFull() && !_hasLegalMerge() && !hasBomb && !hasShuffle) {
      _triggerGameOver();
    }
  }

  void _triggerGameOver() {
    gameOver = true;
    if (totalScore > bestScore) bestScore = totalScore;
    onGameOver?.call();
    clearSave();
  }

  // ---- Persistence --------------------------------------------------------
  Future<void> save() async {
    if (gameOver) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'level': level,
        'levelScore': levelScore,
        'totalScore': totalScore,
        'mistakesLeft': mistakesLeft,
        'draggableCount': draggableCount,
        'bombs': bombs,
        'shuffles': shuffles,
        'best': bestScore,
        'columns': columns
            .map((c) => c.map((card) => card.toJson()).toList())
            .toList(),
      };
      await prefs.setString(_kSaveKey, jsonEncode(data));
    } catch (_) {/* best effort */}
  }

  Future<bool> hasSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_kSaveKey);
    } catch (_) {
      return false;
    }
  }

  Future<bool> loadSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kSaveKey);
      if (raw == null) return false;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      level = data['level'] as int;
      levelScore = data['levelScore'] as int;
      totalScore = data['totalScore'] as int;
      mistakesLeft = data['mistakesLeft'] as int;
      draggableCount = data['draggableCount'] as int;
      bombs = data['bombs'] as int;
      shuffles = data['shuffles'] as int;
      bestScore = (data['best'] as int?) ?? totalScore;
      final cols = data['columns'] as List;
      for (int i = 0; i < kColumnCount; i++) {
        columns[i]
          ..clear()
          ..addAll((cols[i] as List)
              .map((j) => CardData.fromJson(j as Map<String, dynamic>)));
      }
      gameOver = false;
      isPaused = false;
      bombArmed = false;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSaveKey);
    } catch (_) {}
  }

  Future<int> loadBest() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      bestScore = prefs.getInt('merge_royal_best') ?? bestScore;
    } catch (_) {}
    return bestScore;
  }
}
