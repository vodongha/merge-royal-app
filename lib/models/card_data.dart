import 'package:flutter/material.dart';

/// Special suit printed on a card. Suit cards grant bonuses when merged,
/// which is how you "speed up the score".
enum Suit {
  none,
  spade, // ♠ big score multiplier on this merge
  heart, // ♥ refund a mistake
  club, // ♣ grants a bomb
  diamond, // ♦ grants a shuffle
  crown; // ♛ jackpot score

  String get glyph {
    switch (this) {
      case Suit.spade:
        return '♠';
      case Suit.heart:
        return '♥';
      case Suit.club:
        return '♣';
      case Suit.diamond:
        return '♦';
      case Suit.crown:
        return '♛';
      case Suit.none:
        return '';
    }
  }

  Color get color {
    switch (this) {
      case Suit.heart:
      case Suit.diamond:
        return const Color(0xFFE0467A);
      case Suit.spade:
      case Suit.club:
        return const Color(0xFF2BA89A);
      case Suit.crown:
        return const Color(0xFFE0467A);
      case Suit.none:
        return const Color(0xFF1A1A1A);
    }
  }
}

/// A single playing card on the board.
class CardData {
  CardData({
    required this.value,
    this.suit = Suit.none,
    this.locked = false,
  }) : id = _nextId++;

  static int _nextId = 1;

  /// Unique, stable id so the renderer can animate the same card object.
  final int id;

  /// 2048-style power-of-two value. Ignored for [locked] cards.
  int value;

  /// Special suit, if any.
  Suit suit;

  /// A blocked card (🚫). Cannot merge; must be destroyed with a bomb.
  bool locked;

  bool get isSpecial => suit != Suit.none;

  // Escalating emblems — "Merge Royal": card suits for the low cards, a star
  // and a gem for the mid cards, then chess royalty (pawn → king) for the big
  // ones, each with its own colour so high values feel distinct and prestigious.
  static const Map<int, String> _emblem = {
    2: '♠', 4: '♥', 8: '♣', 16: '♦',
    32: '★', 64: '✦',
    128: '♟', 256: '♞', 512: '♝', 1024: '♜', 2048: '♛', 4096: '♚',
  };
  static const Map<int, int> _emblemColor = {
    2: 0xFF1B2432, 4: 0xFFD8324B, 8: 0xFF1B2432, 16: 0xFFD8324B,
    32: 0xFFF0A020, 64: 0xFF17A594,
    128: 0xFF3D7BD6, 256: 0xFF6B53D8, 512: 0xFF9A3FD0,
    1024: 0xFFD0562A, 2048: 0xFFE0327A, 4096: 0xFFF0B429,
  };

  /// Big centre emblem. Special cards show their bonus suit; normal cards use
  /// the escalating emblem set above (very high values fall back to the king).
  String get centerSymbol =>
      suit != Suit.none ? suit.glyph : (_emblem[value] ?? '♚');

  /// Colour of the centre emblem.
  Color get symbolColor {
    // Bonus cards share a warm amber tone to match their golden halo.
    if (suit != Suit.none) {
      return suit == Suit.crown
          ? const Color(0xFFCE8B12)
          : const Color(0xFFC87E1C);
    }
    return Color(_emblemColor[value] ?? 0xFFF0B429);
  }

  /// Short label shown on the card face (e.g. 4096 -> "4,1K").
  String get label {
    if (locked) return '';
    if (value >= 1000) {
      final k = value / 1000.0;
      // 4096 -> 4,1K  (comma like the original art)
      final s = k.toStringAsFixed(1).replaceAll('.', ',');
      return '${s}K';
    }
    return '$value';
  }

  CardData copy() => CardData(value: value, suit: suit, locked: locked);

  Map<String, dynamic> toJson() => {
        'v': value,
        's': suit.index,
        'l': locked,
      };

  factory CardData.fromJson(Map<String, dynamic> json) => CardData(
        value: json['v'] as int,
        suit: Suit.values[json['s'] as int],
        locked: json['l'] as bool,
      );
}
