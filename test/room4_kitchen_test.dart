import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/core/strings.dart';
import 'package:ghostmanor/rooms/items.dart';
import 'package:ghostmanor/rooms/room4_kitchen.dart';
import 'solutions.dart';

void main() {
  late GameState s;
  late GameCtx c;
  late Room room;

  void tap(String sceneId, String hotspotId) =>
      tapSpot(room, s, c, sceneId, hotspotId);

  setUp(() {
    s = GameState();
    c = GameCtx(s, AudioService(enabled: false));
    room = buildKitchen();
  });

  test('정답 시퀀스로 클리어 가능', () {
    expect(room.cleared(s), isFalse);
    solveKitchen(s, c, room);
    expect(room.cleared(s), isTrue);
  });

  test('부정: 수프 없이 국자를 탭하면 열쇠를 주지 않는다', () {
    tap('kitchen_a', 'gukja');
    expect(s.has('key_kitchen'), isFalse);
  });

  test('부정: 빈 병 없이 싱크대를 탭해도 이끼물 병이 생기지 않는다', () {
    tap('kitchen_b', 'sink');
    expect(s.has('water_bottle'), isFalse);
  });

  test('부정: cupboard1/3/4를 두드려도 hollow_found는 0으로 유지된다', () {
    tap('kitchen_b', 'cupboard1');
    tap('kitchen_b', 'cupboard3');
    tap('kitchen_b', 'cupboard4');
    expect(s.flag('kitchen_hollow_found'), 0);
  });

  test('조합 순서를 뒤집어도 성립한다(combineResult 대칭)', () {
    expect(combineResult('mushroom', 'water_bottle'), 'soup_base');
    expect(combineResult('water_bottle', 'mushroom'), 'soup_base');
    expect(combineResult('kettle_singing', 'soup_base'), 'ghost_soup');
    expect(combineResult('soup_base', 'kettle_singing'), 'ghost_soup');
  });

  test('부정: 열쇠 없이 뒷문을 탭하면 잠긴 채다', () {
    tap('kitchen_b', 'backdoor');
    expect(s.flag('kitchen_door_open'), 0);
  });

  // 사운드 단서 공정성(브리프 §3.3-6): 음소거 유저도 구분 가능하도록 sfx뿐 아니라
  // 대사도 둔탁한 문/속 빈 문이 서로 달라야 한다.
  test('사운드 단서 공정성: 둔탁한 문과 속 빈 문은 대사가 다르다', () {
    tap('kitchen_b', 'cupboard1');
    final dull = s.dialog;
    tap('kitchen_b', 'cupboard2');
    final hollow = s.dialog;
    expect(dull, strKitchenKnockDull);
    expect(hollow, strKitchenKnockHollow);
    expect(dull, isNot(equals(hollow)));
  });

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in [
      'empty_bottle',
      'water_bottle',
      'mushroom',
      'kettle_singing',
      'soup_base',
      'ghost_soup',
      'key_kitchen',
      'note3',
    ]) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });

  test('힌트 3개: 단계 3개씩 + solved 조건 배선', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_kitchen_soup', 'p_kitchen_kettle', 'p_kitchen_door']);
  });
}
