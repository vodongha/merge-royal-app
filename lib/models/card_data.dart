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

  static const List<String> _valueSuits = ['♠', '♥', '♣', '♦'];

  /// Big centre suit, like a real playing card. Special cards show their bonus
  /// suit; normal cards cycle ♠♥♣♦ by value so adjacent values differ.
  String get centerSymbol {
    if (suit != Suit.none) return suit.glyph;
    final idx = (value.bitLength - 2) % 4; // 2->0, 4->1, 8->2, 16->3, 32->0…
    return _valueSuits[idx < 0 ? 0 : idx];
  }

  /// Traditional card colouring: hearts/diamonds red, spades/clubs black,
  /// crown pink.
  Color get symbolColor {
    switch (centerSymbol) {
      case '♥':
      case '♦':
        return const Color(0xFFD8324B);
      case '♛':
        return const Color(0xFFE0467A);
      default:
        return const Color(0xFF1B2432);
    }
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
