import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';

void main() {
  test('플래그: 기본 0, set/add, 변경 시 notify', () {
    final s = GameState();
    var notified = 0;
    s.addListener(() => notified++);
    expect(s.flag('x'), 0);
    s.setFlag('x', 2);
    s.addFlag('x');
    expect(s.flag('x'), 3);
    expect(notified, 2);
  });

  test('인벤토리: give/take/has, take는 선택 해제', () {
    final s = GameState();
    s.give('candle');
    expect(s.has('candle'), isTrue);
    s.select('candle');
    s.take('candle');
    expect(s.has('candle'), isFalse);
    expect(s.selectedItem, isNull);
  });

  test('내비게이션: goScene은 클로즈업 닫음, goRoom은 위치·대사 리셋', () {
    final s = GameState();
    s.openCloseup('drawer');
    s.goScene(1);
    expect(s.closeupId, isNull);
    expect(s.sceneIndex, 1);
    s.say('안녕');
    s.goRoom(2);
    expect(s.roomIndex, 2);
    expect(s.sceneIndex, 0);
    expect(s.dialog, isNull);
  });

  test('JSON 라운드트립 (일시 상태 closeup/dialog는 저장 제외)', () {
    final s = GameState();
    s.setFlag('got_key', 1);
    s.give('match');
    s.select('match');
    s.goRoom(1);
    s.goScene(2);
    final r = GameState.fromJson(s.toJson());
    expect(r.flag('got_key'), 1);
    expect(r.inventory, ['match']);
    expect(r.selectedItem, 'match');
    expect(r.roomIndex, 1);
    expect(r.sceneIndex, 2);
    expect(r.closeupId, isNull);
  });
}
