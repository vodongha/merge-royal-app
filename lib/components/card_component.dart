import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../models/card_data.dart';
import '../theme/app_theme.dart';

/// Renders a single card purely with canvas (no image assets needed).
///
/// Layout is playing-card style: a small, clear value in the top-left corner
/// (always visible on the peeking strip when cards are stacked) and a big
/// emblem in the centre — a value chip for normal cards, the suit glyph for
/// special cards, or a "no-entry" sign for locked cards.
class CardComponent extends PositionComponent {
  CardComponent({required this.data, required Vector2 size})
      : super(size: size, anchor: Anchor.topLeft);

  CardData data;
  bool isFront = false;
  bool highlight = false;
  bool lifted = false;

  double get _radius => size.x * 0.13;

  @override
  void render(ui.Canvas canvas) {
    final rect = size.toRect();
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(_radius));

    if (lifted) {
      canvas.drawRRect(
        rrect.shift(const Offset(0, 10)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }

    // Body.
    final colors = data.locked
        ? const [Color(0xFFDDE1E4), Color(0xFFBBC0C4)]
        : AppTheme.cardGradient(data.value);
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader =
            ui.Gradient.linear(rect.topCenter, rect.bottomCenter, colors),
    );

    // Top sheen.
    canvas.save();
    canvas.clipRRect(rrect);
    final sheen = Path()
      ..moveTo(0, 0)
      ..lineTo(size.x, 0)
      ..lineTo(size.x, size.y * 0.26)
      ..quadraticBezierTo(size.x * 0.5, size.y * 0.10, 0, size.y * 0.36)
      ..close();
    canvas.drawPath(sheen, Paint()..color = Colors.white.withValues(alpha: 0.30));
    canvas.restore();

    // Border / highlight.
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
        ..color = highlight || lifted
            ? AppTheme.neon
            : Colors.black.withValues(alpha: 0.16),
    );

    if (data.locked) {
      _drawLocked(canvas, rect);
      return;
    }

    // Corner value — top-left plus a mirrored copy bottom-right, like a
    // playing card. The top-left one sits inside the peeking strip so stacked
    // cards stay readable.
    _drawCorner(canvas, data.label);
    _drawMirroredCorner(canvas, data.label);

    // Big centre emblem (suit for special cards, value emoji otherwise).
    _drawEmblem(canvas, rect);
  }

  void _drawEmblem(ui.Canvas canvas, Rect rect) {
    final c = Offset(rect.center.dx, rect.center.dy + size.y * 0.03);
    // Bonus (special) cards get a gold halo so they stand out.
    if (data.isSpecial) {
      canvas.drawCircle(
          c,
          size.x * 0.36,
          Paint()
            ..color = const Color(0xFFFFC64B).withValues(alpha: 0.85)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      canvas.drawCircle(
          c, size.x * 0.31, Paint()..color = Colors.white.withValues(alpha: 0.55));
    }
    final tp = TextPainter(
      text: TextSpan(
        text: data.centerSymbol,
        style: TextStyle(fontSize: size.x * 0.52, color: data.symbolColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  void _drawCorner(ui.Canvas canvas, String text) {
    _drawText(canvas, text,
        offset: Offset(size.x * 0.10, size.y * 0.03),
        fontSize: size.y * 0.11,
        color: AppTheme.cardInk(data.value),
        weight: FontWeight.w700);
  }

  void _drawMirroredCorner(ui.Canvas canvas, String text) {
    canvas.save();
    canvas.translate(size.x, size.y);
    canvas.rotate(3.14159265);
    _drawCorner(canvas, text);
    canvas.restore();
  }

  void _drawLocked(ui.Canvas canvas, Rect rect) {
    final c = rect.center;
    final r = size.x * 0.24;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.x * 0.07
      ..color = const Color(0xFFE53935);
    canvas.drawCircle(c, r, ring);
    canvas.drawLine(Offset(c.dx - r * 0.7, c.dy - r * 0.7),
        Offset(c.dx + r * 0.7, c.dy + r * 0.7), ring);
  }

  void _drawText(ui.Canvas canvas, String text,
      {required Offset offset,
      required double fontSize,
      required Color color,
      FontWeight weight = FontWeight.w600}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: AppTheme.arcade(size: fontSize, color: color, weight: weight),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }
}
