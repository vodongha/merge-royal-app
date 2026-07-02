import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../game/board_layout.dart';
import '../game/game_controller.dart';
import '../theme/app_theme.dart';

/// Draws the static board: column progress bars, empty-slot glow and the
/// dashed "drop zone" line. Reads live state from the controller.
class BackgroundComponent extends PositionComponent {
  BackgroundComponent({required this.layout, required this.controller});

  final BoardLayout layout;
  final GameController controller;

  /// Column currently being fully dragged out. Unused for slot visibility now
  /// that every column shows a permanent teal holder, but still set by the game.
  int emptyingColumn = -1;

  @override
  int get priority => -10;

  @override
  void render(ui.Canvas canvas) {
    _drawColumnProgressBars(canvas);
    _drawColumnSlots(canvas);
    _drawDashedLine(canvas);
  }

  void _drawColumnProgressBars(ui.Canvas canvas) {
    for (int col = 0; col < kColumnCount; col++) {
      final fill = controller.columnFill(col);
      final x = layout.cardX(col);
      final w = layout.cardWidth;
      final y = layout.progressBarY;
      const h = 7.0;
      final track = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h), const Radius.circular(4));
      canvas.drawRRect(track, Paint()..color = const Color(0xFF2A2F33));

      final color = fill < 0.6
          ? AppTheme.good
          : (fill < 0.85 ? AppTheme.warning : AppTheme.danger);
      if (fill > 0) {
        final fillRect = RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w * fill, h), const Radius.circular(4));
        canvas.drawRRect(
            fillRect,
            Paint()
              ..color = color
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        canvas.drawRRect(fillRect, Paint()..color = color);
      }
    }
  }

  /// The teal "holder" at the top of every column. It is always drawn (a fixed
  /// one-card slot), so an emptied column shows it and, during a deal, it stays
  /// put until the incoming card lands on top of it — no black flash. Cards are
  /// drawn over it because this component sits at priority -10.
  void _drawColumnSlots(ui.Canvas canvas) {
    final radius = Radius.circular(layout.cardWidth * 0.14);
    for (int col = 0; col < kColumnCount; col++) {
      final rect = Rect.fromLTWH(layout.cardX(col), layout.boardTop,
          layout.cardWidth, layout.cardHeight);
      final rrect = RRect.fromRectAndRadius(rect, radius);
      // Outer glow.
      canvas.drawRRect(
          rrect.inflate(2),
          Paint()
            ..color = AppTheme.neon.withValues(alpha: 0.40)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
      // Solid teal fill with a soft vertical gradient.
      canvas.drawRRect(
          rrect,
          Paint()
            ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
              AppTheme.neon.withValues(alpha: 0.85),
              AppTheme.neonDeep.withValues(alpha: 0.85),
            ]));
      // Top sheen — sized to a card, not the whole column.
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  rect.left, rect.top, rect.width, layout.cardHeight * 0.35),
              radius),
          Paint()..color = Colors.white.withValues(alpha: 0.22));
      canvas.restore();
    }
  }

  void _drawDashedLine(ui.Canvas canvas) {
    final y = layout.dashedLineY;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const dash = 26.0;
    const gap = 22.0;
    double x = layout.leftPad;
    final end = layout.gameSize.x - layout.leftPad;
    while (x < end) {
      canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(0, end), y), paint);
      x += dash + gap;
    }
  }
}
