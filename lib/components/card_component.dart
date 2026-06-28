import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../models/card_data.dart';
import '../theme/app_theme.dart';

/// Renders a single card purely with canvas (no image assets needed).
class CardComponent extends PositionComponent {
  CardComponent({required this.data, required Vector2 size})
      : super(size: size, anchor: Anchor.topLeft);

  CardData data;

  /// Whether this is the playable, fully-visible card of its column.
  bool isFront = false;

  /// Glow target highlight (drop target / grabbed).
  bool highlight = false;

  /// Lifted while being dragged.
  bool lifted = false;

  double get _radius => size.x * 0.12;

  @override
  void render(ui.Canvas canvas) {
    final rect = size.toRect();
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(_radius));

    // Drop shadow when lifted.
    if (lifted) {
      canvas.drawRRect(
        rrect.shift(const Offset(0, 8)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // Body gradient.
    final colors =
        data.locked ? const [Color(0xFFD8DBDD), Color(0xFFB9BEC2)] : AppTheme.cardGradient(data.value);
    final bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        colors,
      );
    canvas.drawRRect(rrect, bodyPaint);

    // Soft top sheen.
    canvas.save();
    canvas.clipRRect(rrect);
    final sheen = Path()
      ..moveTo(0, 0)
      ..lineTo(size.x, 0)
      ..lineTo(size.x, size.y * 0.30)
      ..quadraticBezierTo(size.x * 0.5, size.y * 0.12, 0, size.y * 0.42)
      ..close();
    canvas.drawPath(
        sheen, Paint()..color = Colors.white.withValues(alpha: 0.28));
    canvas.restore();

    // Border.
    final borderColor = highlight
        ? AppTheme.neon
        : (lifted ? AppTheme.neon : Colors.black.withValues(alpha: 0.18));
    if (highlight || lifted) {
      canvas.drawRRect(
        rrect.deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = AppTheme.neon
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }
    canvas.drawRRect(
      rrect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = borderColor,
    );

    if (data.locked) {
      _drawLocked(canvas, rect);
      return;
    }

    // Value, top-left.
    _drawText(canvas, data.label,
        offset: Offset(size.x * 0.12, size.y * 0.06),
        fontSize: size.x * 0.26,
        color: AppTheme.cardInk(data.value));

    // Front cards show the big suit emblem + mirrored value (playing-card look).
    if (isFront) {
      if (data.isSpecial) {
        _drawSuit(canvas, rect, data.suit);
      }
      _drawMirroredText(canvas, data.label,
          offset: Offset(size.x * 0.12, size.y * 0.06),
          fontSize: size.x * 0.26,
          color: data.isSpecial ? data.suit.color : AppTheme.cardInk(data.value));
    }
  }

  void _drawLocked(ui.Canvas canvas, Rect rect) {
    final c = rect.center;
    final r = size.x * 0.22;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.x * 0.06
      ..color = const Color(0xFFE53935);
    canvas.drawCircle(c, r, ring);
    final a = Offset(c.dx - r * 0.7, c.dy - r * 0.7);
    final b = Offset(c.dx + r * 0.7, c.dy + r * 0.7);
    canvas.drawLine(a, b, ring);
  }

  void _drawSuit(ui.Canvas canvas, Rect rect, Suit suit) {
    final tp = TextPainter(
      text: TextSpan(
        text: suit.glyph,
        style: TextStyle(fontSize: size.x * 0.5, color: suit.color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2));
  }

  void _drawText(ui.Canvas canvas, String text,
      {required Offset offset, required double fontSize, required Color color}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTheme.body(
            size: fontSize, color: color, weight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  void _drawMirroredText(ui.Canvas canvas, String text,
      {required Offset offset, required double fontSize, required Color color}) {
    canvas.save();
    canvas.translate(size.x, size.y);
    canvas.rotate(3.14159265);
    _drawText(canvas, text, offset: offset, fontSize: fontSize, color: color);
    canvas.restore();
  }
}
