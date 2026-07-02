import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/material.dart';

import '../audio/audio_controller.dart';
import '../components/background_component.dart';
import '../components/card_component.dart';
import '../theme/app_theme.dart';
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
  final Random _rng = Random();

  // Screen-shake state.
  double _shake = 0;
  final Vector2 _shakeOffset = Vector2.zero();

  // True during the sync right after a deal, so freshly dealt cards bounce in.
  bool _dealing = false;

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
    kColumnCapacity = layout.maxCards;
    _background = BackgroundComponent(layout: layout, controller: controller);
    add(_background);
    controller.addListener(_onControllerChanged);
    controller.onMerge = _onMerge;
    controller.onBomb = _onBomb;
    controller.onShuffle = () => AudioController.instance.shuffle();
    controller.onMistake = () {
      AudioController.instance.mistake();
      _addShake(7);
    };
    controller.onDeal = _onDeal;
    sync(animate: false);
  }

  void _onDeal() {
    _dealing = true;
    AudioController.instance.shuffle();
    // A soft sparkle pops over each column as its card lands — staggered
    // left-to-right to match the cascade in [sync].
    for (int col = 0; col < kColumnCount; col++) {
      final at = Vector2(
          layout.columnCenterX(col), layout.boardTop + layout.cardHeight * 0.2);
      Future.delayed(Duration(milliseconds: 130 + col * 60), () {
        if (isMounted) {
          _burst(at, const [AppTheme.neon, AppTheme.neonDeep, Colors.white],
              count: 8, speed: 90, radius: 2.5);
        }
      });
    }
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
    kColumnCapacity = layout.maxCards;
    if (isLoaded) sync(animate: false);
  }

  void _onControllerChanged() {
    if (isLoaded) sync();
  }

  // ---- Juice: shake + particles ------------------------------------------
  void _addShake(double amount) => _shake = min(16, _shake + amount);

  @override
  void update(double dt) {
    super.update(dt);
    if (_shake > 0) {
      _shake = max(0, _shake - dt * 40);
      _shakeOffset
        ..setValues(_rng.nextDouble() * 2 - 1, _rng.nextDouble() * 2 - 1)
        ..scale(_shake);
    } else {
      _shakeOffset.setZero();
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.translate(_shakeOffset.x, _shakeOffset.y);
    super.render(canvas);
    canvas.restore();
  }

  void _burst(Vector2 center, List<Color> colors,
      {int count = 16, double speed = 150, double radius = 4}) {
    add(ParticleSystemComponent(
      position: center,
      priority: 3000,
      particle: Particle.generate(
        count: count,
        lifespan: 0.62,
        generator: (i) {
          final angle = _rng.nextDouble() * 2 * pi;
          final spd = speed * (0.35 + _rng.nextDouble());
          final color = colors[_rng.nextInt(colors.length)];
          final r = radius * (0.6 + _rng.nextDouble());
          return AcceleratedParticle(
            acceleration: Vector2(0, 420),
            speed: Vector2(cos(angle), sin(angle)) * spd,
            child: ComputedParticle(
              renderer: (canvas, particle) {
                canvas.drawCircle(
                  Offset.zero,
                  r * (1 - particle.progress * 0.5),
                  Paint()..color = color.withValues(alpha: 1 - particle.progress),
                );
              },
            ),
          );
        },
      ),
    ));
  }

  Vector2 _columnCenter(int col) => Vector2(
        layout.columnCenterX(col),
        layout.boardTop + layout.cardHeight * 0.6,
      );

  // ---- Sync model -> components ------------------------------------------
  void sync({bool animate = true}) {
    // Consume the one-shot deal flag: the cards created in this sync are the
    // freshly dealt row, so they get a springy cascade instead of a plain drop.
    final dealing = _dealing;
    _dealing = false;
    final live = <int>{};
    for (int col = 0; col < kColumnCount; col++) {
      final cards = controller.columns[col];
      for (int i = 0; i < cards.length; i++) {
        final data = cards[i];
        live.add(data.id);
        final isFront = i == cards.length - 1;
        final targetPos = Vector2(layout.cardX(col), layout.cardY(i));
        var comp = _cards[data.id];
        final isNew = comp == null;
        if (comp == null) {
          comp = CardComponent(data: data, size: layout.cardSize());
          // Freshly dealt cards start further above so they bounce down in.
          comp.position = targetPos.clone()
            ..y -= layout.cardHeight * (dealing ? 1.7 : 1.0);
          comp.priority = i;
          _cards[data.id] = comp;
          add(comp);
        }
        comp.data = data;
        comp.size = layout.cardSize();
        comp.isFront = isFront;
        comp.priority = i;
        comp.highlight = false;
        comp.scale = Vector2.all(1); // clear any leftover animation scale

        if (animate) {
          final delay = col * 0.06;
          if (dealing && isNew) {
            // The freshly dealt card drops from above onto the teal holder,
            // arriving just after the pile has sunk to reveal it.
            comp.add(MoveToEffect(
                targetPos,
                EffectController(
                    duration: 0.34,
                    startDelay: delay + 0.13,
                    curve: Curves.easeOutBack)));
          } else if (dealing) {
            // Existing cards sink DOWN to uncover the teal holder at the top of
            // the column, then settle back up beneath the new card — so every
            // column reveals its holder on a deal, not just an empty one.
            final revealPos = targetPos.clone()..y += layout.cardHeight;
            comp.add(SequenceEffect([
              MoveToEffect(
                  revealPos,
                  EffectController(
                      duration: 0.13, startDelay: delay, curve: Curves.easeOut)),
              MoveToEffect(targetPos,
                  EffectController(duration: 0.32, curve: Curves.easeOutBack)),
            ]));
          } else {
            comp.add(MoveToEffect(
                targetPos, EffectController(duration: 0.16, curve: Curves.easeOut)));
          }
        } else {
          comp.position = targetPos;
        }
      }
    }

    // Remove cards that left the board (merged / bombed): quick shrink in place.
    final gone = _cards.keys.where((id) => !live.contains(id)).toList();
    for (final id in gone) {
      final comp = _cards.remove(id);
      if (comp == null) continue;
      comp.priority = 5000;
      comp.add(ScaleEffect.to(
        Vector2.zero(),
        EffectController(duration: 0.12, curve: Curves.easeIn),
        onComplete: comp.removeFromParent,
      ));
    }
  }

  void _onMerge(MergeEvent event) {
    AudioController.instance.merge(event.combo);
    _addShake(2.5 + event.combo * 2.0);

    final cards = controller.columns[event.column];
    if (cards.isEmpty) return;
    final comp = _cards[cards.last.id];
    // Survivor grows to show the value leveling up, then settles. Curves stay
    // monotonic so the card never dips below its normal size.
    comp?.add(SequenceEffect([
      ScaleEffect.to(Vector2.all(1.28),
          EffectController(duration: 0.10, curve: Curves.easeOut)),
      ScaleEffect.to(Vector2.all(1.0),
          EffectController(duration: 0.14, curve: Curves.easeInOut)),
    ]));

    final colors = AppTheme.cardGradient(event.value);
    final accent = event.combo > 1 ? [AppTheme.warning, AppTheme.neon] : colors;
    _burst(_columnCenter(event.column), [...colors, ...accent],
        count: 12 + event.combo * 6, speed: 130 + event.combo * 30);
  }

  void _onBomb(int col) {
    AudioController.instance.bomb();
    _addShake(12);
    _burst(_columnCenter(col),
        const [Color(0xFFFF7A3D), Color(0xFFFFC400), Color(0xFFB71C1C), Colors.white],
        count: 30, speed: 220, radius: 5);
  }

  // ---- Input --------------------------------------------------------------
  @override
  void onTapUp(TapUpEvent event) {
    if (controller.gameOver || controller.isPaused) return;
    final p = event.localPosition;
    if (controller.bombArmed) {
      controller.detonate(layout.columnAt(p.x));
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (controller.gameOver || controller.isPaused || controller.bombArmed) {
      return;
    }
    final p = event.localPosition;
    final col = _grabColumnAt(p);
    if (col == null) return;
    // The card the player touched (0 = back). They take that card plus
    // everything below it toward the front — so they decide how many.
    final len = controller.columns[col].length;
    final touched =
        ((p.y - layout.boardTop) / layout.stripOffset).floor().clamp(0, len - 1);
    final group = controller.grabCount(col, touched);
    if (group <= 0) return;

    _dragFrom = col;
    _dragGroup = group;
    // If the whole column is leaving, reveal its waiting slot immediately.
    if (group >= controller.columns[col].length) {
      _background.emptyingColumn = col;
    }
    _dragPos = p.clone();
    _dragged.clear();
    final cards = controller.columns[col];
    final start = cards.length - group;
    for (int i = start; i < cards.length; i++) {
      final comp = _cards[cards[i].id];
      if (comp != null) {
        comp.lifted = true;
        // Far above every other component (cards, consumed-card fx at 5000,
        // background) so the card in hand always renders on top.
        comp.priority = 100000 + (i - start);
        _dragged.add(comp);
      }
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_dragFrom < 0) return;
    final delta = event.localDelta;
    _dragPos.add(delta);
    for (int j = 0; j < _dragged.length; j++) {
      final comp = _dragged[j];
      comp.position.add(delta);
      comp.priority = 100000 + j; // keep the hand on top every frame
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
    _background.emptyingColumn = -1;
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

  /// Column the player is grabbing from. Anywhere within the column's
  /// vertical band counts, so the whole column is a generous hit target
  /// (no more dead zones between overlapping cards).
  int? _grabColumnAt(Vector2 p) {
    final top = layout.boardTop - layout.cardHeight * 0.5;
    final bottom = layout.boardBottom + layout.cardHeight * 0.6;
    if (p.y < top || p.y > bottom) return null;
    final col = layout.columnAt(p.x);
    if (!controller.canGrab(col)) return null;
    return col;
  }
}
