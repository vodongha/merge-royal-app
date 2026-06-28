import 'package:flutter_test/flutter_test.dart';

import 'package:merge_royal/game/game_controller.dart';
import 'package:merge_royal/models/card_data.dart';

void main() {
  test('matching front cards merge and double in value', () {
    final c = GameController();
    c.columns[0].add(CardData(value: 2));
    c.columns[1].add(CardData(value: 2));

    final result = c.moveGroup(0, 1, 1);

    expect(result, MoveResult.merged);
    expect(c.columns[1].last.value, 4);
  });

  test('a wrong drop costs a mistake', () {
    final c = GameController();
    c.mistakesLeft = 5;
    c.columns[0].add(CardData(value: 2));
    c.columns[1].add(CardData(value: 8));

    final result = c.moveGroup(0, 1, 1);

    expect(result, MoveResult.illegal);
    expect(c.mistakesLeft, 4);
  });

  test('staircase columns cascade into a combo', () {
    final c = GameController();
    // Column 1: 8, 4 (front). Dropping a 4 chains 4+4=8, 8+8=16.
    c.columns[1].addAll([CardData(value: 8), CardData(value: 4)]);
    c.columns[0].add(CardData(value: 4));

    final result = c.moveGroup(0, 1, 1);

    expect(result, MoveResult.merged);
    expect(c.columns[1].last.value, 16);
    expect(c.comboMultiplier, greaterThanOrEqualTo(2));
  });
}
