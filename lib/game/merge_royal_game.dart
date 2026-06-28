import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../components/background_component.dart';
import '../components/card_component.dart';
import 'board_layout.dart';
import 'game_controller.dart';

/// Flame game that renders the board from [GameController] and turns pointer
/// gestures into moves. All rules live in the controller.
class MergeRoyalGame extends FlameGame with DragCallbacks, TapCallbacks {
  MergeRoyalGame(this.controller);

  final GameController controller;
  final BoardLayout layout = BoardLayout();

  final Map<int, CardComponent> _cards = {};
  late BackgroundComponent _background;

  // Drag session ------------------------------------------------------------
  int _dragFrom = -1;
  int _dragGroup = 0;
  final List<CardComponent> _dragged = [];
  Vector2 _dragPos = Vector2.zero();
  int _hoverCol = -1;

  @override
  Color backgroundColor() => const Color(0xFF050608);

  @override
  Future<void> onLoad() async {
    layout.update(size);
    _background = BackgroundComponent(layout: layout, controller: controller);
    add(_background);
    controller.addListener(_onControllerChanged);
    controller.onMerge = _onMerge;
    sync(animate: false);
  }

  @override
  void onRemove() {
    controller.removeListener(_onControllerChanged);
    super.onRemove();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    layout.update(size);
    if (isLoaded) sync(animate: false);
  }

  void _onControllerChanged() {
    if (isLoaded) sync();
  }

  // ---- Sync model -> components ------------------------------------------
  void sync({bool animate = true}) {
    final live = <int>{};
    for (int col = 0; col < kColumnCount; col++) {
      final cards = controller.columns[col];
      for (int i = 0; i < cards.length; i++) {
        final data = cards[i];
        live.add(data.id);
        final isFront = i == cards.length - 1;
        final targetPos = Vector2(layout.cardX(col), layout.cardY(i));
        var comp = _cards[data.id];
        if (comp == null) {
          comp = CardComponent(data: data, size: layout.cardSize());
          comp.position = targetPos.clone()..y -= layout.cardHeight; // drop in
          comp.priority = i;
          _cards[data.id] = comp;
          add(comp);
        }
        comp.data = data;
        comp.size = layout.cardSize();
        comp.isFront = isFront;
        comp.priority = i;
        comp.highlight = false;
        if (animate) {
          comp.add(MoveToEffect(
              targetPos, EffectController(duration: 0.16, curve: Curves.easeOut)));
        } else {
          comp.position = targetPos;
        }
      }
    }

    // Remove cards that left the board (merged / bombed).
    final gone = _cards.keys.where((id) => !live.contains(id)).toList();
    for (final id in gone) {
      final comp = _cards.remove(id);
      if (comp == null) continue;
      comp.add(ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.14, curve: Curves.easeIn),
        onComplete: comp.removeFromParent,
      ));
    }
  }

  void _onMerge(MergeEvent event) {
    // Pulse the surviving front card of the merged column.
    final cards = controller.columns[event.column];
    if (cards.isEmpty) return;
    final comp = _cards[cards.last.id];
    comp?.add(SequenceEffect([
      ScaleEffect.to(Vector2.all(1.18), EffectController(duration: 0.08)),
      ScaleEffect.to(Vector2.all(1.0), EffectController(duration: 0.10)),
    ]));
  }

  // ---- Input --------------------------------------------------------------
  @override
  void onTapUp(TapUpEvent event) {
    if (controller.gameOver || controller.isPaused) return;
    final p = event.localPosition;
    if (controller.bombArmed) {
      final col = _columnUnderFront(p) ?? layout.columnAt(p.x);
      controller.detonate(col);
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (controller.gameOver || controller.isPaused || controller.bombArmed) {
      return;
    }
    final p = event.localPosition;
    final col = _columnUnderFront(p);
    if (col == null) return;
    final group = controller.grabbableCount(col);
    if (group <= 0) return;

    _dragFrom = col;
    _dragGroup = group;
    _dragPos = p.clone();
    _dragged.clear();
    final cards = controller.columns[col];
    for (int i = cards.length - group; i < cards.length; i++) {
      final comp = _cards[cards[i].id];
      if (comp != null) {
        comp.lifted = true;
        comp.priority = 1000 + i;
        _dragged.add(comp);
      }
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_dragFrom < 0) return;
    final delta = event.localDelta;
    _dragPos.add(delta);
    for (final comp in _dragged) {
      comp.position.add(delta);
    }
    final col = layout.columnAt(_dragPos.x);
    if (col != _hoverCol) {
      _hoverCol = col;
      _updateHover(col);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _finishDrag(layout.columnAt(_dragPos.x));
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _finishDrag(_dragFrom);
  }

  void _finishDrag(int target) {
    if (_dragFrom < 0) return;
    final from = _dragFrom;
    final group = _dragGroup;
    for (final comp in _dragged) {
      comp.lifted = false;
    }
    _dragged.clear();
    _dragFrom = -1;
    _dragGroup = 0;
    _hoverCol = -1;
    _clearHighlights();

    final result = controller.moveGroup(from, target, group);
    if (result == MoveResult.cancelled || result == MoveResult.illegal) {
      sync(); // snap back
    }
    // merged / relocated already notify -> sync via listener.
  }

  void _updateHover(int col) {
    _clearHighlights();
    if (col == _dragFrom) return;
    final cards = controller.columns[col];
    if (cards.isEmpty) return;
    final comp = _cards[cards.last.id];
    comp?.highlight = true;
  }

  void _clearHighlights() {
    for (final c in _cards.values) {
      c.highlight = false;
    }
  }

  /// Returns the column whose front card is under [p], or null.
  int? _columnUnderFront(Vector2 p) {
    for (int col = 0; col < kColumnCount; col++) {
      final cards = controller.columns[col];
      if (cards.isEmpty) continue;
      final comp = _cards[cards.last.id];
      if (comp == null) continue;
      final r = Rect.fromLTWH(
          comp.position.x, comp.position.y, comp.size.x, comp.size.y);
      if (r.contains(Offset(p.x, p.y))) return col;
    }
    return null;
  }
}
