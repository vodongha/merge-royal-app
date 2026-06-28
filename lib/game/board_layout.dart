import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'game_controller.dart';

/// Geometry of the board, recomputed whenever the game is resized.
class BoardLayout {
  late Vector2 gameSize;

  double leftPad = 0;
  double slotWidth = 0;
  double cardWidth = 0;
  double cardHeight = 0;
  double stripOffset = 0;
  double boardTop = 0;
  double boardBottom = 0;
  double progressBarY = 0;

  void update(Vector2 size) {
    gameSize = size;
    leftPad = size.x * 0.035;
    final usable = size.x - leftPad * 2;
    slotWidth = usable / kColumnCount;
    cardWidth = slotWidth * 0.84;
    cardHeight = cardWidth * 1.42;
    stripOffset = cardHeight * 0.17;
    boardTop = size.y * 0.225;
    boardBottom = size.y * 0.72;
    progressBarY = boardTop - cardHeight * 0.12;
  }

  /// Center x of a column.
  double columnCenterX(int col) => leftPad + slotWidth * (col + 0.5);

  /// Top-left x of a card in a column.
  double cardX(int col) => columnCenterX(col) - cardWidth / 2;

  /// Top-left y of the card at [index] within a column of [count] cards.
  double cardY(int index) => boardTop + index * stripOffset;

  Vector2 cardSize() => Vector2(cardWidth, cardHeight);

  /// Which column a horizontal position falls into (clamped to 0..count-1).
  int columnAt(double x) {
    final rel = (x - leftPad) / slotWidth;
    return rel.floor().clamp(0, kColumnCount - 1);
  }

  Rect columnRect(int col) =>
      Rect.fromLTWH(cardX(col), boardTop, cardWidth, boardBottom - boardTop);
}
