import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/memory_player.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/core/strings.dart';
import 'package:ghostmanor/rooms/items.dart';
import 'package:ghostmanor/rooms/room7_hall.dart';
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
    room = buildHall();
  });

  test('정답 시퀀스로 클리어 가능 (스텝 ≥15, 하드코어 게이트)', () {
    expect(room.cleared(s), isFalse);
    final steps = solveHall(s, c, room);
    expect(steps, greaterThanOrEqualTo(15));
    expect(room.cleared(s), isTrue);
  });

  test('병렬 단언: 진입 직후 T1(초상 portrait1)·T2(카펫 rug) 둘 다 fresh 상태에서 탭 가능', () {
    final portrait1 = findHotspot(room, 'hall_a', 'portrait1');
    final rug = findHotspot(room, 'hall_c', 'rug');
    expect(portrait1.when?.call(s) ?? true, isTrue);
    expect(rug.when?.call(s) ?? true, isTrue);
  });

  test('벽면 핫스팟 총수 ≥15, 3벽 (하드코어 게이트)', () {
    expect(room.walls.length, 3);
    final total = room.walls.fold<int>(0, (sum, w) => sum + w.hotspots.length);
    expect(total, greaterThanOrEqualTo(15));
  });

  // ── 회상 (Task1 규약: T1 완료 후 사진 앵커 탭 → 재생, 재열람 가능) ──

  test('T1 전에는 사진 탭 시 정적 클로즈업만 열리고 회상은 재생되지 않는다', () {
    tap('hall_c', 'photo');
    expect(s.closeupId, 'photo');
    expect(s.flag('f2_hall_memory'), 0);
  });

  test('회상: T1 완료 후 사진 탭 → 1회 재생(f2_hall_memory=1) + 재열람 가능', () {
    tap('hall_a', 'portrait2');
    tap('hall_a', 'portrait4');
    expect(s.flag('f2_hall_frames'), 1);

    tap('hall_c', 'photo');
    expect(s.closeupId, 'memory');
    expect(s.flag('f2_hall_memory'), 1);
    s.closeCloseup();

    // 재열람: 다시 탭해도 memory로 열린다(사진 앵커).
    tap('hall_c', 'photo');
    expect(s.closeupId, 'memory');
  });

  // ── 부정 테스트 ──

  test('부정: 액자 상태가 틀린 채 문 탭 → 브리프 전문 대사 + 무작위 액자 정확히 1개가 기울임으로', () {
    tap('hall_a', 'door'); // 초기 상태(전부 정상)는 오답
    expect(s.dialog, strF2HallDoorFramesWrong);
    expect(s.flag('f2_hall_frames'), 0);
    final tilted =
        List.generate(4, (i) => s.flag('f2_hall_portrait$i')).fold<int>(0, (a, b) => a + b);
    expect(tilted, 1, reason: '무작위 액자 정확히 1개만 기울임으로 바뀌어야 한다');
  });

  test('부정: 액자는 정답인데 열쇠가 없으면 잠김 대사(문은 안 열림)', () {
    tap('hall_a', 'portrait2');
    tap('hall_a', 'portrait4');
    expect(s.flag('f2_hall_frames'), 1);

    tap('hall_a', 'door');
    expect(s.dialog, strF2HallDoorLocked);
    expect(s.flag('f2_hall_door_open'), 0);
  });

  test(
      '지식 게이트 아님: 카펫 다이아 단서(hall_c)를 한 번도 본 적 없어도 액자 정렬만 맞으면 통과'
      '(현관 편지와 동일 원칙)', () {
    tap('hall_a', 'portrait2');
    tap('hall_a', 'portrait4');
    expect(s.flag('f2_hall_frames'), 1);
    expect(s.flag('f2_hall_rug_rolled'), 0); // hall_c 관련 아무것도 안 건드림
  });

  test('부정: 태엽 없이 시계를 감으려 하면 실패(살아나지 않음)', () {
    tap('hall_b', 'clock');
    expect(s.closeupId, 'clock');
    tap('clock', 'winder_hole'); // winder 미선택
    expect(s.flag('f2_hall_clock_wound'), 0);
    expect(s.flag('f2_hall_b_alive'), 0);
    expect(s.dialog, strF2HallClockNeedsWinder);
  });

  test('부정: 시계가 살아나기 전엔 샹들리에를 탭해도 열쇠가 떨어지지 않는다', () {
    tap('hall_b', 'chandelier');
    expect(s.flag('f2_hall_key_dropped'), 0);
    expect(s.dialog, strF2HallChandelierStill);
  });

  test('부정: 열쇠 낙하 전에는 floor_key 핫스팟이 비활성', () {
    final h = findHotspot(room, 'hall_b', 'floor_key');
    expect(h.when?.call(s) ?? true, isFalse);
  });

  // ── 마루판(찬장 콜백 — 두 번째 탭에서 개방) ──

  test('마루판: dull 3장은 항상 같은 반응이고 플래그 변화가 없다', () {
    s.setFlag('f2_hall_rug_rolled', 1);
    tap('hall_c', 'plank1');
    expect(s.dialog, strF2HallPlankDull);
    expect(s.flag('f2_hall_plank_hollow_found'), 0);
    tap('hall_c', 'plank2');
    tap('hall_c', 'plank4');
    expect(s.flag('f2_hall_plank_hollow_found'), 0);
    expect(s.has('winder'), isFalse);
  });

  test('마루판: hollow(plank3) 1차 발견 → 2차 개방+winder → 3차는 이미 연 구멍', () {
    s.setFlag('f2_hall_rug_rolled', 1);
    tap('hall_c', 'plank3');
    expect(s.flag('f2_hall_plank_hollow_found'), 1);
    expect(s.dialog, strF2HallPlankHollow);
    expect(s.has('winder'), isFalse);

    tap('hall_c', 'plank3');
    expect(s.flag('f2_hall_plank_open'), 1);
    expect(s.has('winder'), isTrue);
    expect(s.dialog, strF2HallPlankOpen);

    tap('hall_c', 'plank3');
    expect(s.dialog, strF2HallPlankAlreadyOpen);
  });

  test('부정: 카펫을 걷기 전엔 마루판 핫스팟이 전부 비활성', () {
    for (final id in ['plank1', 'plank2', 'plank3', 'plank4']) {
      final h = findHotspot(room, 'hall_c', id);
      expect(h.when?.call(s) ?? true, isFalse, reason: id);
    }
  });

  // ── 순수 함수 단위 테스트 ──

  group('hallPortraitsSolved / tapPortrait', () {
    test('초기 상태(전부 정상)는 오답', () {
      expect(hallPortraitsSolved(s), isFalse);
    });

    test('2·4번째(인덱스 1,3)만 기울이면 정답 + f2_hall_frames=1', () {
      tapPortrait(s, 1);
      tapPortrait(s, 3);
      expect(hallPortraitsSolved(s), isTrue);
      expect(s.flag('f2_hall_frames'), 1);
    });

    test('토글이라 순서 무관 — 4번째 먼저 눌러도 동일하게 정답', () {
      tapPortrait(s, 3);
      tapPortrait(s, 1);
      expect(hallPortraitsSolved(s), isTrue);
    });

    test('한 번 정답이 되면 f2_hall_frames는 이후 흐트러져도 되돌아가지 않는다', () {
      tapPortrait(s, 1);
      tapPortrait(s, 3);
      expect(s.flag('f2_hall_frames'), 1);
      tapPortrait(s, 1); // 다시 0으로 — 라이브 상태는 오답이 됨
      expect(hallPortraitsSolved(s), isFalse);
      expect(s.flag('f2_hall_frames'), 1); // 게이트 플래그는 유지
    });
  });

  group('sabotageRandomPortrait', () {
    test('전부 정상 상태에서 호출하면 정확히 1개만 기울임으로 바뀐다', () {
      sabotageRandomPortrait(s);
      final tilted =
          List.generate(4, (i) => s.flag('f2_hall_portrait$i')).fold<int>(0, (a, b) => a + b);
      expect(tilted, 1);
    });
  });

  group('finishRugRoll', () {
    test('f2_hall_rug_rolled 플래그를 세운다', () {
      expect(s.flag('f2_hall_rug_rolled'), 0);
      finishRugRoll(s);
      expect(s.flag('f2_hall_rug_rolled'), 1);
    });
  });

  // ── 등록·힌트 ──

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in ['winder', 'key_f2bed', 'emblem_hall']) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });

  test('closeups의 key는 Scene.id와 일치(모델 assert가 이미 강제하지만 명시적으로도 확인)', () {
    for (final entry in room.closeups.entries) {
      expect(entry.key, entry.value.id);
    }
  });

  test('힌트 3개: p_f2_hall_ 접두어 + 단계 3개씩 + solved 조건 배선(각 조건 실제 호출)', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_f2_hall_frames', 'p_f2_hall_clock', 'p_f2_hall_door']);
    for (final h in room.hints) {
      expect(h.steps.length, 3);
    }
    s.setFlag('f2_hall_frames', 1);
    expect(room.hints[0].solved!(s), isTrue);
    s.setFlag('f2_hall_b_alive', 1);
    expect(room.hints[1].solved!(s), isTrue);
    s.setFlag('f2_hall_done', 1);
    expect(room.hints[2].solved!(s), isTrue);
  });

  // ── 위젯 테스트 ──

  testWidgets('카펫 위젯(RubbableScene): 드래그를 반복하면 걷힌다', (t) async {
    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 400,
            child: Builder(
                builder: (context) => room.closeups['rug']!.custom!(context, c)))));
    for (var i = 0; i < 30; i++) {
      await t.drag(find.byKey(const Key('rug_rub')), const Offset(120, 0),
          warnIfMissed: false);
      await t.pump();
    }
    expect(s.flag('f2_hall_rug_rolled'), 1);
  });

  testWidgets('회상 위젯: 사진 탭으로 열린 MemoryPlayer가 3페이지를 넘기고 닫힌다', (t) async {
    tap('hall_a', 'portrait2');
    tap('hall_a', 'portrait4');
    tap('hall_c', 'photo');
    expect(s.closeupId, 'memory');

    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 600,
            child: Builder(
                builder: (context) => room.closeups['memory']!.custom!(context, c)))));
    await t.pump();
    expect(find.text(strF2Mem1p1), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer));
    await t.pumpAndSettle();
    expect(find.text(strF2Mem1p2), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer));
    await t.pumpAndSettle();
    expect(find.text(strF2Mem1p3), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer)); // 마지막 페이지 탭 → onDone → closeCloseup
    await t.pump();
    expect(s.closeupId, isNull);
  });
}
