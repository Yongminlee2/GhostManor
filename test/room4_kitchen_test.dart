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

  test('정답 시퀀스로 클리어 가능 (스텝 ≥15, 하드코어 게이트)', () {
    expect(room.cleared(s), isFalse);
    final steps = solveKitchen(s, c, room);
    expect(steps, greaterThanOrEqualTo(15));
    expect(room.cleared(s), isTrue);
  });

  test(
    '진입 직후 두 스레드 병렬 활성: recipe_board(T1·벽C)·poker_rack(T2·벽C) 둘 다 fresh 상태에서 탭 가능',
    () {
      final recipe = findHotspot(room, 'kitchen_c', 'recipe_board');
      final rack = findHotspot(room, 'kitchen_c', 'poker_rack');
      expect(recipe.when?.call(s) ?? true, isTrue);
      expect(rack.when?.call(s) ?? true, isTrue);
    },
  );

  test('벽면 핫스팟 총수 ≥15 (하드코어 게이트)', () {
    final total = room.walls.fold<int>(0, (sum, w) => sum + w.hotspots.length);
    expect(total, greaterThanOrEqualTo(15));
  });

  // ── 부정 테스트 (지시문 4종) ──

  test('부정: 순서 틀림(2번째로 kettle_singing) → 리셋 + 오답 대사', () {
    s.give('water_bottle');
    s.give('kettle_singing');
    s.select('water_bottle');
    tap('kitchen_a', 'pot');
    expect(s.flag('kitchen_r_pot_stage'), 1);

    s.select('kettle_singing'); // 2번째는 mushroom이어야 함 — 순서 위반
    tap('kitchen_a', 'pot');
    // 오답이어도 진행 단계는 유지된다 — 정답 재료(물병 등)는 영구 소모라
    // 0으로 리셋하면 복구 불가 소프트락이 되기 때문(실기기 검수에서 발견).
    expect(s.flag('kitchen_r_pot_stage'), 1);
    expect(s.flag('kitchen_r_pot_wrong'), 1);
    expect(s.closeupId, 'pot', reason: '오답 프레임이 보이려면 오답 탭이 클로즈업을 열어야 한다');
    expect(s.dialog, strKitchenRPotWrong);

    // 다음 냄비 상호작용(선택 없음 재탭)에서 오답 프레임은 해제된다
    s.select(null);
    s.closeCloseup();
    tap('kitchen_a', 'pot');
    expect(s.flag('kitchen_r_pot_wrong'), 0);
    expect(s.closeupId, 'pot');
  });

  test('부정: 안 달군 부지깽이로 언 자물쇠를 문질러도 전용 리액션만(진행 없음)', () {
    s.give('poker');
    s.select('poker');
    tap('kitchen_c', 'icebox');
    expect(s.flag('kitchen_r_ice_stage'), 0);
    expect(s.dialog, strKitchenRIceColdPoker);
  });

  test('부정: 레시피판을 안 닦아도 순서만 맞으면 냄비가 완성된다(현관 편지와 동일 원칙)', () {
    s.give('water_bottle');
    s.give('mushroom');
    s.give('herb');
    s.give('kettle_singing');
    for (final item in ['water_bottle', 'mushroom', 'herb', 'kettle_singing']) {
      s.select(item);
      tap('kitchen_a', 'pot');
    }
    expect(s.flag('kitchen_r_pot_stage'), 4);
    expect(s.flag('kitchen_r_recipe_rubbed'), 0); // 레시피판을 아예 안 건드림
  });

  test('부정: 미완성 수프인 채로 국자를 탭하면 열쇠를 주지 않는다', () {
    tap('kitchen_a', 'gukja');
    expect(s.has('key_kitchen'), isFalse);
    expect(s.flag('kitchen_r_ghost_fed'), 0);
  });

  // ── 기존 회귀 유지(플래그명만 kitchen_r_) ──

  test('부정: 빈 병 없이 싱크대를 탭해도 이끼물 병이 생기지 않는다', () {
    tap('kitchen_b', 'sink');
    expect(s.has('water_bottle'), isFalse);
  });

  test('부정: cupboard1/3/4를 두드려도 hollow_found는 0으로 유지된다', () {
    tap('kitchen_b', 'cupboard1');
    tap('kitchen_b', 'cupboard3');
    tap('kitchen_b', 'cupboard4');
    expect(s.flag('kitchen_r_hollow_found'), 0);
  });

  test('부정: 열쇠 없이 뒷문을 탭하면 잠긴 채다', () {
    tap('kitchen_b', 'backdoor');
    expect(s.flag('kitchen_r_door_open'), 0);
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

  test('저장실 리액션 3종은 대사만 표시(진행에 영향 없음)', () {
    tap('kitchen_c', 'sausages');
    expect(s.dialog, strKitchenRSausages);
    tap('kitchen_c', 'jar_pickles');
    expect(s.dialog, strKitchenRJarPickles);
    tap('kitchen_c', 'jar_flour');
    expect(s.dialog, strKitchenRJarFlour);
    expect(s.flag('kitchen_r_pot_stage'), 0); // 진행 무관
  });

  test('pot 핫스팟: 재료 없이 탭하면 클로즈업만 연다(진행 불변)', () {
    tap('kitchen_a', 'pot');
    expect(s.closeupId, 'pot');
    expect(s.flag('kitchen_r_pot_stage'), 0);
  });

  test('냄비 재료를 선택해 넣어도 선택 없이 볼 때와 같은 단계 클로즈업을 즉시 표시', () {
    s.give('water_bottle');
    s.select('water_bottle');
    tap('kitchen_a', 'pot');
    expect(s.flag('kitchen_r_pot_stage'), 1);
    expect(s.closeupId, 'pot');
    expect(s.selectedItem, isNull); // 소비 후 선택 상태도 함께 해제

    s.closeCloseup();
    tap('kitchen_a', 'pot');
    expect(s.flag('kitchen_r_pot_stage'), 1);
    expect(s.closeupId, 'pot');
  });

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in [
      'empty_bottle',
      'water_bottle',
      'mushroom',
      'kettle_singing',
      'poker',
      'poker_hot',
      'herb',
      'key_kitchen',
      'note3',
    ]) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });

  test('힌트 3개: p_kitchen_r_ 접두어 + 단계 3개씩 + solved 조건 배선', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId), [
      'p_kitchen_r_soup',
      'p_kitchen_r_ice',
      'p_kitchen_r_door',
    ]);
    for (final h in room.hints) {
      expect(h.steps.length, 3);
    }
    s.setFlag('kitchen_r_pot_stage', 4);
    expect(room.hints[0].solved!(s), isTrue);
    s.setFlag('kitchen_r_ice_looted', 1);
    expect(room.hints[1].solved!(s), isTrue);
    s.setFlag('kitchen_r_done', 1);
    expect(room.hints[2].solved!(s), isTrue);
  });

  group('usePotIngredient', () {
    test(
      '정답 순서(water_bottle→mushroom→herb→kettle_singing)대로면 매번 true + stage +1',
      () {
        expect(usePotIngredient(s, 'water_bottle'), isTrue);
        expect(s.flag('kitchen_r_pot_stage'), 1);
        expect(usePotIngredient(s, 'mushroom'), isTrue);
        expect(s.flag('kitchen_r_pot_stage'), 2);
        expect(usePotIngredient(s, 'herb'), isTrue);
        expect(s.flag('kitchen_r_pot_stage'), 3);
        expect(usePotIngredient(s, 'kettle_singing'), isTrue);
        expect(s.flag('kitchen_r_pot_stage'), 4);
      },
    );

    test('순서가 틀린 재료는 현재 stage 유지 + wrong=1', () {
      usePotIngredient(s, 'water_bottle'); // stage 1
      expect(usePotIngredient(s, 'kettle_singing'), isFalse); // 2번째가 아님
      expect(s.flag('kitchen_r_pot_stage'), 1);
      expect(s.flag('kitchen_r_pot_wrong'), 1);
    });

    test('무관한 아이템/미선택은 진행도 안 바뀌고 wrong도 안 켜진다', () {
      expect(usePotIngredient(s, 'oil'), isFalse);
      expect(s.flag('kitchen_r_pot_stage'), 0);
      expect(s.flag('kitchen_r_pot_wrong'), 0);
      expect(usePotIngredient(s, null), isFalse);
      expect(s.flag('kitchen_r_pot_wrong'), 0);
    });

    test('wrong 플래그는 다음 호출에서 지워진다("1프레임")', () {
      usePotIngredient(s, 'water_bottle');
      usePotIngredient(s, 'kettle_singing'); // 오답 → wrong=1
      expect(s.flag('kitchen_r_pot_wrong'), 1);
      usePotIngredient(s, 'mushroom'); // 보존된 다음 단계 정답
      expect(s.flag('kitchen_r_pot_wrong'), 0);
    });

    test('완성(stage 4) 후에는 no-op', () {
      for (final item in [
        'water_bottle',
        'mushroom',
        'herb',
        'kettle_singing',
      ]) {
        usePotIngredient(s, item);
      }
      expect(s.flag('kitchen_r_pot_stage'), 4);
      expect(usePotIngredient(s, 'water_bottle'), isFalse);
      expect(s.flag('kitchen_r_pot_stage'), 4); // 불변
    });
  });

  group('meltIce', () {
    test('poker_hot으로 3번 호출하면 매번 true + stage 1씩 증가', () {
      expect(meltIce(s, 'poker_hot'), isTrue);
      expect(s.flag('kitchen_r_ice_stage'), 1);
      expect(meltIce(s, 'poker_hot'), isTrue);
      expect(s.flag('kitchen_r_ice_stage'), 2);
      expect(meltIce(s, 'poker_hot'), isTrue);
      expect(s.flag('kitchen_r_ice_stage'), 3);
    });

    test('poker(안 달굼) 또는 무관한 아이템/미선택은 진행 없음', () {
      expect(meltIce(s, 'poker'), isFalse);
      expect(s.flag('kitchen_r_ice_stage'), 0);
      expect(meltIce(s, null), isFalse);
      expect(meltIce(s, 'oil'), isFalse);
    });

    test('3단계 도달 후에는 no-op', () {
      meltIce(s, 'poker_hot');
      meltIce(s, 'poker_hot');
      meltIce(s, 'poker_hot');
      expect(meltIce(s, 'poker_hot'), isFalse);
      expect(s.flag('kitchen_r_ice_stage'), 3); // 불변
    });
  });
}
