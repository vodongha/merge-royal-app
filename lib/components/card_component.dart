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

  // Cached text painters. A TextPainter builds a native ui.Paragraph, so
  // rebuilding one every frame leaked off-heap memory and OOM-crashed long
  // (high-level) games. We keep them and only rebuild when the text/size that
  // actually feeds them changes (a merge changes the value, a resize the size).
  TextPainter? _cornerTp;
  String? _cornerKey;
  TextPainter? _emblemTp;
  String? _emblemKey;

  // Gradient shaders are native objects too; cache them the same way.
  ui.Shader? _bodyShader;
  String? _bodyKey;
  ui.Shader? _haloShader;
  String? _haloKey;

  @override
  void onRemove() {
    _cornerTp?.dispose();
    _emblemTp?.dispose();
    _bodyShader?.dispose();
    _haloShader?.dispose();
    super.onRemove();
  }

  ui.Shader _bodyGradient(Rect rect) {
    final key =
        '${size.x.toStringAsFixed(1)}x${size.y.toStringAsFixed(1)}|${data.locked ? 'L' : data.value}';
    if (_bodyKey != key) {
      _bodyShader?.dispose();
      final colors = data.locked
          ? const [Color(0xFFDDE1E4), Color(0xFFBBC0C4)]
          : AppTheme.cardGradient(data.value);
      _bodyShader =
          ui.Gradient.linear(rect.topCenter, rect.bottomCenter, colors);
      _bodyKey = key;
    }
    return _bodyShader!;
  }

  ui.Shader _haloGradient(Offset c, double glowR) {
    final key = glowR.toStringAsFixed(1);
    if (_haloKey != key) {
      _haloShader?.dispose();
      _haloShader = ui.Gradient.radial(
        c,
        glowR,
        const [
          Color(0xFFFFF3D0), // bright warm-gold core
          Color(0xFFFFDE95), // amber
          Color(0xFFF3BE55), // deeper amber
          Color(0x00F3BE55), // fade out to transparent
        ],
        const [0.0, 0.42, 0.7, 1.0],
      );
      _haloKey = key;
    }
    return _haloShader!;
  }

  TextPainter _cornerPainter() {
    final key = '${data.label}|${size.y.toStringAsFixed(1)}';
    if (_cornerKey != key) {
      _cornerTp?.dispose();
      _cornerTp = TextPainter(
        text: TextSpan(
          text: data.label,
          style: AppTheme.arcade(
              size: size.y * 0.11,
              color: AppTheme.cardInk(data.value),
              weight: FontWeight.w700),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _cornerKey = key;
    }
    return _cornerTp!;
  }

  TextPainter _emblemPainter() {
    final key =
        '${data.centerSymbol}|${size.x.toStringAsFixed(1)}|${data.value}|${data.suit.index}';
    if (_emblemKey != key) {
      _emblemTp?.dispose();
      _emblemTp = TextPainter(
        text: TextSpan(
          text: data.centerSymbol,
          style: TextStyle(fontSize: size.x * 0.52, color: data.symbolColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _emblemKey = key;
    }
    return _emblemTp!;
  }

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
    canvas.drawRRect(rrect, Paint()..shader = _bodyGradient(rect));

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
    _drawCorner(canvas);
    _drawMirroredCorner(canvas);

    // Big centre emblem (suit for special cards, value emoji otherwise).
    _drawEmblem(canvas, rect);
  }

  void _drawEmblem(ui.Canvas canvas, Rect rect) {
    final c = Offset(rect.center.dx, rect.center.dy + size.y * 0.03);
    // Bonus (special) cards get a soft amber halo — a warm radial gradient that
    // glows from a bright gold core and fades smoothly to transparent, so the
    // emblem sits in a soft pool of light rather than a hard disc.
    if (data.isSpecial) {
      final glowR = size.x * 0.46;
      canvas.drawCircle(c, glowR, Paint()..shader = _haloGradient(c, glowR));
    }
    final tp = _emblemPainter();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
  }

  void _drawCorner(ui.Canvas canvas) {
    _cornerPainter().paint(canvas, Offset(size.x * 0.10, size.y * 0.03));
  }

  void _drawMirroredCorner(ui.Canvas canvas) {
    canvas.save();
    canvas.translate(size.x, size.y);
    canvas.rotate(3.14159265);
    _drawCorner(canvas);
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
}
