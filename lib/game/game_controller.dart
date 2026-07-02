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
/// Max cards a column can hold before it overflows the dashed line and ends the
/// run. Set from the board geometry at load (how many cards fit above the line).
int kColumnCapacity = 12;
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
  int mistakeStreak = 0; // consecutive wrong drops, drives the red "-N" flash
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
  void Function(int combo)? onCombo;
  void Function(int streak)? onPenalty; // red "-N" flash on a wrong drop
  VoidCallback? onDeal;

  int get levelTarget => 200 + level * 150;
  double get levelProgress => (levelScore / levelTarget).clamp(0.0, 1.0);
  bool get hasBomb => bombs > 0;
  bool get hasShuffle => shuffles > 0;

  /// Fill ratio of a column (0..1) for its little progress bar.
  double columnFill(int col) =>
      (columns[col].length / kColumnCapacity).clamp(0.0, 1.0);

  // ---- Lifecycle ----------------------------------------------------------
  Future<void> startNewGame() async {
    level = 1;
    levelScore = 0;
    totalScore = 0;
    mistakesLeft = 10;
    bombs = 1;
    shuffles = 1;
    comboMultiplier = 1;
    mistakeStreak = 0;
    bombArmed = false;
    gameOver = false;
    isPaused = false;
    _applyLevelTuning();
    _dealInitialBoard();
    notifyListeners();
    await save();
  }

  void _applyLevelTuning() {
    // You can pick up any card in a column (touch it to take it plus everything
    // below), so the cap is the column height itself.
    draggableCount = kColumnCapacity;
  }

  /// Deal a fresh board with a few low cards per column.
  void _dealInitialBoard() {
    for (final c in columns) {
      c.clear();
    }
    for (int col = 0; col < kColumnCount; col++) {
      final n = 2 + _rng.nextInt(2); // 2..3 cards
      for (int i = 0; i < n; i++) {
        final prev = columns[col].isEmpty ? null : columns[col].last;
        columns[col].add(_spawnCard(
            allowHazards: false, avoid: prev == null || prev.locked ? null : prev.value));
      }
    }
  }

  /// Generates a card. [avoid] is the value of the card it will sit next to —
  /// the spawned value never matches it, so we never create two identical
  /// adjacent cards that just sit there without merging.
  CardData _spawnCard({bool allowHazards = true, int? avoid}) {
    // Base value grows slowly with level.
    final tier = min(4, 1 + level ~/ 3); // how many low values are in the bag
    final pool = <int>[2, 4, 8, 16, 32].take(min(5, 1 + tier)).toList();
    if (avoid != null) pool.removeWhere((v) => v == avoid);
    if (pool.isEmpty) pool.add(avoid == 2 ? 4 : 2);
    final value = pool[_rng.nextInt(pool.length)];

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
  /// Whether the front card of [col] can be picked up at all.
  bool canGrab(int col) {
    final c = columns[col];
    return c.isNotEmpty && !c.last.locked;
  }

  /// How many cards to pick up when the player grabs at [fromIndex] (the card
  /// they touched, 0 = back/top of the stack). They take that card plus every
  /// card below it toward the front, capped by [draggableCount]. The player
  /// decides the amount by choosing where in the stack to grab. Locked cards
  /// can't be carried, so the grab starts just below the deepest locked one.
  int grabCount(int col, int fromIndex) {
    final c = columns[col];
    if (c.isEmpty || c.last.locked) return 0;
    var start = fromIndex.clamp(0, c.length - 1);
    // Locked cards can't be carried; start just below the deepest locked one.
    for (int k = start; k < c.length; k++) {
      if (c[k].locked) start = k + 1;
    }
    return c.length - start;
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

    final willMerge = dst.isNotEmpty &&
        !dst.last.locked &&
        !leading.locked &&
        dst.last.value == leading.value;

    if (willMerge) {
      _transfer(src, dst, groupSize);
      mistakeStreak = 0; // a correct merge clears the wrong-drop streak
      _collapse(to);
      _checkGameOver();
      notifyListeners();
      save();
      return MoveResult.merged;
    }

    // Dropping onto an EMPTY column is a free relocation (no penalty) — as long
    // as it fits. It deals a fresh row to every column (extra pressure).
    if (dst.isEmpty) {
      if (dst.length + groupSize > kColumnCapacity) {
        _registerMistake();
        return MoveResult.illegal;
      }
      _transfer(src, dst, groupSize);
      comboMultiplier = 1;
      _dealRowOnTop();
      _checkGameOver();
      notifyListeners();
      save();
      return MoveResult.relocated;
    }

    // Dropping onto an occupied, non-matching column is an incorrect merge:
    // snap back and take a point penalty that grows with the wrong-drop streak.
    _registerMistake();
    return MoveResult.illegal;
  }

  void _transfer(List<CardData> src, List<CardData> dst, int n) {
    final moved = src.sublist(src.length - n);
    src.removeRange(src.length - n, src.length);
    dst.addAll(moved);
  }

  /// Full cascade: repeatedly merge any adjacent equal pair in the column
  /// until nothing matches, so runs and staircases resolve completely (no
  /// leftover single cards). Returns the combo length (number of merges).
  /// [announce] fires the merge/combo juice; pass false for tidy-up collapses
  /// (e.g. after a shuffle) so [sync] just animates the result cleanly.
  int _collapse(int col, {bool announce = true}) {
    final c = columns[col];
    int combo = 0;
    bool merged = true;
    while (merged) {
      merged = false;
      for (int i = c.length - 1; i >= 1; i--) {
        final a = c[i];
        final b = c[i - 1];
        if (a.locked || b.locked || a.value != b.value) continue;

        // Merge a into b (keep the deeper card as the result).
        c.removeAt(i);
        b.value *= 2;
        combo++;

        _applySuitBonus(a);
        _applySuitBonus(b);
        b.suit = Suit.none;

        _addScore(b.value * (combo + 1)); // combos score more
        if (announce) onMerge?.call(MergeEvent(col, b.value, combo, a.suit));
        merged = true;
        break; // restart the scan
      }
    }
    comboMultiplier = max(1, combo);
    if (announce && combo > 1) onCombo?.call(combo);
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

  void _registerMistake() {
    mistakeStreak++;
    mistakesLeft--;
    // Point penalty grows with the streak of consecutive wrong drops: -1, -2, …
    _subtractScore(mistakeStreak);
    onMistake?.call();
    onPenalty?.call(mistakeStreak);
    if (mistakesLeft <= 0) {
      mistakesLeft = 0;
      _triggerGameOver();
    }
    notifyListeners();
    save();
  }

  /// Removes points for a wrong drop. The score is allowed to go negative.
  void _subtractScore(int amount) {
    levelScore -= amount;
    totalScore -= amount;
  }

  /// Deals a fresh card to the TOP of every column (including empty slots) that
  /// still has room. No scoring — this is the cost of a non-merging move.
  void _dealRowOnTop() {
    for (int i = 0; i < kColumnCount; i++) {
      final top = columns[i].isEmpty ? null : columns[i].first;
      columns[i].insert(
          0, _spawnCard(avoid: top == null || top.locked ? null : top.value));
    }
    onDeal?.call();
  }

  /// Player-triggered draw: deal a fresh row of cards on demand (same as a
  /// non-merging move) — for when there is nothing left to merge. No scoring.
  void dealNow() {
    if (gameOver) return;
    comboMultiplier = 1;
    _dealRowOnTop();
    onToast?.call('DEAL');
    _checkGameOver();
    notifyListeners();
    save();
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
    // Merge any adjacent equal cards the shuffle lined up, so the board never
    // settles with obvious un-merged pairs. Silent: sync() animates the result.
    for (int col = 0; col < kColumnCount; col++) {
      _collapse(col, announce: false);
    }
    shuffles--;
    onShuffle?.call();
    onToast?.call('SHUFFLED');
    _checkGameOver();
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
    // A column filled past its capacity ends the run.
    if (columns.any((c) => c.length > kColumnCapacity)) {
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
