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

  @override
  int get priority => -10;

  @override
  void render(ui.Canvas canvas) {
    _drawColumnProgressBars(canvas);
    _drawEmptySlots(canvas);
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

  void _drawEmptySlots(ui.Canvas canvas) {
    for (int col = 0; col < kColumnCount; col++) {
      if (controller.columns[col].isNotEmpty) continue;
      final rect = Rect.fromLTWH(
          layout.cardX(col), layout.boardTop, layout.cardWidth, layout.cardHeight);
      final rrect = RRect.fromRectAndRadius(
          rect, Radius.circular(layout.cardWidth * 0.12));
      canvas.drawRRect(
          rrect,
          Paint()
            ..color = AppTheme.neon.withValues(alpha: 0.16)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      canvas.drawRRect(rrect, Paint()..color = AppTheme.neon.withValues(alpha: 0.10));
      canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = AppTheme.neon.withValues(alpha: 0.5));
    }
  }

  void _drawDashedLine(ui.Canvas canvas) {
    final y = layout.boardBottom + layout.cardHeight * 0.25;
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
