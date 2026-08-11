import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/rooms/items.dart';

void main() {
  test('레지스트리: 아이콘 경로 규약', () {
    expect(itemsById['candle']!.icon, 'assets/items/candle.png');
    expect(itemsById['candle']!.name, '양초');
  });

  test('조합: 순서 무관, 없는 조합은 null', () {
    expect(combineResult('candle', 'match'), 'lit_candle');
    expect(combineResult('match', 'candle'), 'lit_candle');
    expect(combineResult('match', 'key_foyer'), isNull);
  });

  test('tryCombine: 재료 소모 + 결과 지급', () {
    final s = GameState();
    s.give('candle');
    s.give('match');
    expect(tryCombine(s, 'candle', 'match'), isTrue);
    expect(s.has('candle'), isFalse);
    expect(s.has('match'), isFalse);
    expect(s.has('lit_candle'), isTrue);
  });

  test('tryCombine 실패: 아무것도 변하지 않음', () {
    final s = GameState();
    s.give('candle');
    s.give('key_foyer');
    expect(tryCombine(s, 'candle', 'key_foyer'), isFalse);
    expect(s.inventory, ['candle', 'key_foyer']);
  });
}
