import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/dial_safe.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/core/strings.dart';
import 'package:ghostmanor/rooms/items.dart';
import 'package:ghostmanor/rooms/room2_living.dart';
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
    room = buildLiving();
  });

  test('정답 시퀀스로 클리어 가능 (스텝 ≥15, 하드코어 게이트)', () {
    expect(room.cleared(s), isFalse);
    final steps = solveLiving(s, c, room);
    expect(steps, greaterThanOrEqualTo(15));
    expect(room.cleared(s), isTrue);
  });

  test(
      '진입 직후 병렬 스레드 활성: cushion(T3·벽B)·초상화 4점/소품 4개(T1·벽C) 전부 프레시 상태에서 탭 가능',
      () {
    final cushion = findHotspot(room, 'living_b', 'cushion');
    expect(cushion.when?.call(s) ?? true, isTrue);
    for (final id in [
      'portrait_baby',
      'portrait_youth',
      'portrait_middle',
      'portrait_old',
      'lamp',
      'pendulum',
      'vase',
      'books',
    ]) {
      final h = findHotspot(room, 'living_c', id);
      expect(h.when?.call(s) ?? true, isTrue, reason: '$id는 프레시 상태에서 활성이어야 함');
    }
    // T2(촛대→벽난로)도 진입 직후 착수 가능해야 병렬 3스레드가 완성된다.
    for (var i = 1; i <= 4; i++) {
      final candle = findHotspot(room, 'living_a', 'candle$i');
      expect(candle.when?.call(s) ?? true, isTrue,
          reason: 'candle$i는 프레시 상태에서 활성이어야 함');
    }
  });

  test('벽면 핫스팟 총수 ≥15 (하드코어 게이트)', () {
    final total = room.walls.fold<int>(0, (sum, w) => sum + w.hotspots.length);
    expect(total, greaterThanOrEqualTo(15));
  });

  test('부정: TV 켜지기 전엔 부우가 문을 막아 열리지 않음', () {
    tap('living_b', 'door');
    expect(s.flag('living_r_door_open'), 0);
  });

  test('부정: 잘못된 촛불 패턴(1·2번만 켬)은 벽난로를 켜지 않음', () {
    toggleCandle(s, 1);
    toggleCandle(s, 2);
    expect(s.flag('living_r_fireplace_lit'), 0);
  });

  test('부정: 점화 전 비밀칸을 열어도 다이얼 손잡이가 없다', () {
    tap('living_a', 'secret_nook');
    expect(s.has('knob'), isFalse);
    expect(s.dialog, strLivingMantel);
  });

  test('부정: 점화 후 촛대 핫스팟은 모두 비활성', () {
    toggleCandle(s, 2);
    toggleCandle(s, 4);
    expect(s.flag('living_r_fireplace_lit'), 1);
    for (final id in ['candle1', 'candle2', 'candle3', 'candle4']) {
      final h = findHotspot(room, 'living_a', id);
      expect(h.when?.call(s) ?? true, isFalse,
          reason: '$id는 점화 후 비활성이어야 함');
    }
  });

  test('부정: 손잡이 없이 금고를 탭해도 클로즈업이 열리지 않는다', () {
    tap('living_c', 'safe');
    expect(s.closeupId, isNull);
    expect(s.dialog, strLivingRSafeNoKnob);
  });

  test('toggleCandle: 토글 왕복', () {
    expect(s.flag('living_r_candle1'), 0);
    toggleCandle(s, 1);
    expect(s.flag('living_r_candle1'), 1);
    toggleCandle(s, 1);
    expect(s.flag('living_r_candle1'), 0);
  });

  test('toggleCandle: 패턴 완성(2·4만 켬) 시 점화', () {
    toggleCandle(s, 2);
    toggleCandle(s, 4);
    expect(s.flag('living_r_fireplace_lit'), 1);
  });

  test('toggleCandle: 점화 후 재토글해도 lit 유지', () {
    toggleCandle(s, 2);
    toggleCandle(s, 4);
    expect(s.flag('living_r_fireplace_lit'), 1);
    toggleCandle(s, 2); // 패턴이 깨지도록 다시 토글
    expect(s.flag('living_r_candle2'), 0);
    expect(s.flag('living_r_fireplace_lit'), 1); // 그래도 유지
  });

  test('TV 클로즈업: 탭마다 living_r_tv_scene 토글(촛불 패턴 ↔ 나이 순서)', () {
    s.setFlag('living_r_tv_on', 1);
    tap('living_b', 'tv');
    expect(s.closeupId, 'tv');
    expect(s.flag('living_r_tv_scene'), 0);

    final tvScene = room.closeups['tv']!;
    final overlay = tvScene.overlays.single;
    expect(overlay.when(s), isFalse); // 기본: 촛불 패턴(오버레이 없음)

    tapSpot(room, s, c, 'tv', 'tv_scene_toggle');
    expect(s.flag('living_r_tv_scene'), 1);
    expect(overlay.when(s), isTrue); // 나이 순서 오버레이 표시

    tapSpot(room, s, c, 'tv', 'tv_scene_toggle');
    expect(s.flag('living_r_tv_scene'), 0);
    expect(overlay.when(s), isFalse);
  });

  group('DialSafe 순수 함수', () {
    test('tapDialWheel: 0~9 순환', () {
      expect(s.flag('p_d0'), 0);
      for (var i = 1; i <= 9; i++) {
        tapDialWheel(s, 'p', 0);
        expect(s.flag('p_d0'), i);
      }
      tapDialWheel(s, 'p', 0); // 9 다음은 다시 0
      expect(s.flag('p_d0'), 0);
    });

    test('tapDialWheel: 휠은 서로 독립적', () {
      tapDialWheel(s, 'p', 0);
      tapDialWheel(s, 'p', 1);
      tapDialWheel(s, 'p', 1);
      expect(s.flag('p_d0'), 1);
      expect(s.flag('p_d1'), 2);
    });

    test('checkDialCode: 전 자리 일치해야 true', () {
      s.setFlag('p_d0', 3);
      s.setFlag('p_d1', 2);
      s.setFlag('p_d2', 7);
      s.setFlag('p_d3', 4);
      expect(checkDialCode(s, 'p', '3274'), isTrue);
    });

    test('checkDialCode: 한 자리라도 다르면 false, 오답이어도 개방되지 않는다', () {
      s.setFlag('p_d0', 3);
      s.setFlag('p_d1', 2);
      s.setFlag('p_d2', 7);
      s.setFlag('p_d3', 5); // 마지막 자리만 오답
      expect(checkDialCode(s, 'p', '3274'), isFalse);
    });
  });

  testWidgets('오답 리액션(room 배선): 3274 아닌 코드로 확인 → 개방 안 되고 room의 오답 대사',
      (t) async {
    // living_c/safe 흐름 그대로: 손잡이 장착 → 다이얼 클로즈업 오픈.
    s.give('knob');
    s.select('knob');
    tap('living_c', 'safe');
    tap('living_c', 'safe');
    expect(s.closeupId, 'safe');

    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 400,
            child: Builder(
                builder: (context) =>
                    room.closeups['safe']!.custom!(context, c)))));

    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(const Key('dial_wheel_0')));
      await t.pump();
    } // 휠0=3, 나머지 0 → 정답(3274)이 아님
    await t.tap(find.byKey(const Key('dial_confirm')));
    await t.pump();

    expect(s.flag('living_r_safe_open'), 0);
    expect(s.has('key_living'), isFalse);
    expect(s.dialog, strLivingRSafeWrong);
    expect(s.flag('living_r_safe_d0'), 0); // 오답 후 리셋
  });

  test('힌트 3개: p_living_r_ 접두어 + 단계 3개씩 + solved 조건 배선(각 조건 실제 호출)', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_living_r_safe', 'p_living_r_candle', 'p_living_r_boo']);
    for (final h in room.hints) {
      expect(h.steps.length, 3);
    }

    s.setFlag('living_r_safe_open', 1);
    expect(room.hints[0].solved!(s), isTrue);

    s.setFlag('living_r_fireplace_lit', 1);
    expect(room.hints[1].solved!(s), isTrue);

    s.setFlag('living_r_tv_on', 1);
    expect(room.hints[2].solved!(s), isTrue);
  });

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in ['remote', 'key_living', 'note1', 'oil', 'knob']) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });

  testWidgets('DialSafe 위젯: 휠 4개를 정답(3274)으로 맞추고 확인 → onOpened 1회만 호출',
      (t) async {
    var openCount = 0;
    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 400,
            child: DialSafe(
              ctx: c,
              digits: 4,
              code: '3274',
              flagPrefix: 'test_safe',
              wrongSay: '오답이다',
              onOpened: (_) => openCount++,
            ))));

    const targets = [3, 2, 7, 4];
    for (var wheel = 0; wheel < targets.length; wheel++) {
      for (var n = 0; n < targets[wheel]; n++) {
        await t.tap(find.byKey(Key('dial_wheel_$wheel')));
        await t.pump();
      }
    }
    await t.tap(find.byKey(const Key('dial_confirm')));
    await t.pump();
    expect(openCount, 1);
    expect(s.flag('test_safe_d0'), 3);

    // 이미 열린 뒤 확인을 다시 눌러도 1회 가드로 재호출되지 않는다.
    await t.tap(find.byKey(const Key('dial_confirm')));
    await t.pump();
    expect(openCount, 1);
  });

  testWidgets('DialSafe 위젯: 오답 확인 → 열리지 않고 오답 대사 + 휠 전체 리셋', (t) async {
    var opened = false;
    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 400,
            child: DialSafe(
              ctx: c,
              digits: 4,
              code: '3274',
              flagPrefix: 'test_safe2',
              wrongSay: strLivingRSafeWrong,
              onOpened: (_) => opened = true,
            ))));

    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(const Key('dial_wheel_0')));
      await t.pump();
    }
    await t.tap(find.byKey(const Key('dial_confirm')));
    await t.pump();

    expect(opened, isFalse);
    expect(s.dialog, strLivingRSafeWrong);
    expect(s.flag('test_safe2_d0'), 0); // 오답 후 리셋
  });
}
