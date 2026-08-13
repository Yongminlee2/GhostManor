import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/memory_player.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/core/strings.dart';
import 'package:ghostmanor/rooms/items.dart';
import 'package:ghostmanor/rooms/room11_seal.dart';
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
    room = buildSeal();
    // 방7~10 클리어 전제(emblem 4종) — 방 단독 테스트라 여기서 직접 지급
    // (solveSeal은 지급 안 함, solveStudy의 oil과 동일 관례).
    s.give('emblem_hall');
    s.give('emblem_bed');
    s.give('emblem_child');
    s.give('emblem_lab');
  });

  test('정답 시퀀스로 클리어 가능 (스텝 ≥15, 하드코어 게이트)', () {
    expect(room.cleared(s), isFalse);
    final steps = solveSeal(s, c, room);
    expect(steps, greaterThanOrEqualTo(15));
    expect(room.cleared(s), isTrue);
  });

  test('병렬 단언: 진입 직후 T1(촛불고리 candle0)·T2(제단 altar) 둘 다 반응 가능', () {
    final candle0 = findHotspot(room, 'seal_c', 'candle0');
    final altar = findHotspot(room, 'seal_a', 'altar');
    expect(candle0.when?.call(s) ?? true, isTrue);
    expect(altar.when?.call(s) ?? true, isTrue);
    tap('seal_c', 'candle0');
    expect(s.flag('f2_seal_candle0'), 1);
  });

  test('벽면 핫스팟 총수 ≥15, 3벽 (하드코어 게이트)', () {
    expect(room.walls.length, 3);
    final total = room.walls.fold<int>(0, (sum, w) => sum + w.hotspots.length);
    expect(total, greaterThanOrEqualTo(15));
  });

  // ── 촛불 고리(T1) ──

  test('촛불: 이미 꺼진 초를 다시 탭하면 전용 리액션, 상태 변화 없음', () {
    tap('seal_c', 'candle0');
    tap('seal_c', 'candle0');
    expect(s.dialog, strF2SealCandleAlreadyOut);
    expect(s.flag('f2_seal_candle0'), 1);
  });

  test('촛불: 가운데(처음부터 꺼진) 초는 전용 리액션만, 게이트에 영향 없음', () {
    tap('seal_c', 'candle_center');
    expect(s.dialog, strF2SealCandleCenterOut);
    expect(s.flag('f2_seal_b_awake'), 0);
    expect(s.flag('f2_seal_c_dark'), 0);
  });

  test('촛불 4개를 순서 무관(역순)하게 꺼도 벽화가 깨어난다', () {
    tap('seal_c', 'candle3');
    tap('seal_c', 'candle2');
    tap('seal_c', 'candle1');
    tap('seal_c', 'candle0'); // 네 번째
    expect(s.flag('f2_seal_c_dark'), 1);
    expect(s.flag('f2_seal_b_awake'), 1);
    expect(s.dialog, strF2SealMuralAwake);
  });

  // ── 벽화·회상5 ──

  test('벽화가 잠든 상태(깨어나기 전)에 탭하면 반응만, 회상은 열리지 않는다', () {
    tap('seal_b', 'mural_house');
    expect(s.dialog, strF2SealMuralHouseDormant);
    expect(s.closeupId, isNull);
    tap('seal_b', 'mural_family');
    expect(s.dialog, strF2SealMuralFamilyDormant);
    expect(s.closeupId, isNull);
  });

  test('회상5: 벽화가 깨어난 뒤 첫 탭 → 1회 재생(f2_seal_memory=1) + 재열람 가능', () {
    s.setFlag('f2_seal_b_awake', 1);
    tap('seal_b', 'mural_house');
    expect(s.closeupId, 'memory');
    expect(s.flag('f2_seal_memory'), 1);
    s.closeCloseup();

    tap('seal_b', 'mural_family'); // 다른 절반을 탭해도 동일한 회상으로 재열람
    expect(s.closeupId, 'memory');
  });

  test('지식 게이트 아님: 회상5(벽화)를 안 봐도 emblem을 정순서로 배치하면 제단이 완성된다', () {
    expect(s.flag('f2_seal_memory'), 0);
    expect(s.flag('f2_seal_b_awake'), 0);
    tap('seal_a', 'altar');
    for (final id in ['emblem_hall', 'emblem_bed', 'emblem_child', 'emblem_lab']) {
      s.select(id);
      tap('altar', 'grooves');
    }
    expect(s.flag('f2_seal_altar_full'), 1);
    expect(s.flag('f2_seal_memory'), 0, reason: '회상은 여전히 안 본 상태');
  });

  // ── 제단(T2) 부정 테스트 ──

  test('부정: 제단 오순서 → 계획 원문 대사 + 배치 전체 리셋(상징 소모 없음)', () {
    tap('seal_a', 'altar');
    s.select('emblem_hall');
    tap('altar', 'grooves');
    expect(s.flag('f2_seal_altar_seq'), 1);

    s.select('emblem_lab'); // 오답 — 다음은 emblem_bed여야 함
    tap('altar', 'grooves');
    expect(s.flag('f2_seal_altar_seq'), 0);
    expect(s.dialog, strF2SealAltarWrong);
    expect(s.dialog, '제단이 웅— 낮게 울며 상징들을 밀어낸다. 순서가 있다.');
    expect(s.flag('f2_seal_altar_full'), 0);
    expect(s.has('emblem_hall'), isTrue, reason: '오답 시 상징은 소모되지 않는다');
    expect(s.has('emblem_lab'), isTrue);
  });

  test('부정: emblem을 3개만 정순서로 배치하면 제단은 미완성으로 남고(넷째 없이는 매듭도 무반응)', () {
    tap('seal_a', 'altar');
    s.select('emblem_hall');
    tap('altar', 'grooves');
    s.select('emblem_bed');
    tap('altar', 'grooves');
    s.select('emblem_child');
    tap('altar', 'grooves');
    expect(s.flag('f2_seal_altar_seq'), 3);
    expect(s.flag('f2_seal_altar_full'), 0);
    expect(s.has('emblem_hall'), isTrue); // 완성 전엔 소모되지 않는다
    expect(s.has('emblem_bed'), isTrue);
    expect(s.has('emblem_child'), isTrue);
    s.closeCloseup();

    tap('seal_a', 'knot_top');
    expect(s.flag('f2_seal_knot_seq'), 0);
    expect(s.dialog, strF2SealKnotLocked);
  });

  test('부정: 무관한 아이템/미선택으로 홈을 탭해도 진행은 리셋되지 않는다', () {
    tap('seal_a', 'altar');
    s.select('emblem_hall');
    tap('altar', 'grooves');
    expect(s.flag('f2_seal_altar_seq'), 1);

    s.select('key_f2seal'); // 무관한 아이템
    tap('altar', 'grooves');
    expect(s.flag('f2_seal_altar_seq'), 1, reason: '무관한 아이템은 리셋시키지 않는다');
    expect(s.dialog, strF2SealAltarNeedEmblem);
  });

  test('제단 완성 후 재탭은 전용 리액션만', () {
    tap('seal_a', 'altar');
    for (final id in ['emblem_hall', 'emblem_bed', 'emblem_child', 'emblem_lab']) {
      s.select(id);
      tap('altar', 'grooves');
    }
    tap('altar', 'grooves');
    expect(s.dialog, strF2SealAltarFullLook);
  });

  // ── 매듭 ──

  test('부정: 제단 미완성 상태로 매듭(위)을 문질러도 아무 진행 없이 무반응', () {
    expect(s.flag('f2_seal_altar_full'), 0);
    tap('seal_a', 'knot_top');
    expect(s.flag('f2_seal_knot_seq'), 0);
    expect(s.flag('f2_seal_a_open'), 0);
    expect(s.dialog, strF2SealKnotLocked);
  });

  test('매듭: 위→아래 순서로 3연속 성공하면 봉인 문이 열린다(unlock 사운드 경로)', () {
    s.setFlag('f2_seal_altar_full', 1);
    tap('seal_a', 'knot_top');
    expect(s.dialog, strF2SealKnotProgress1);
    tap('seal_a', 'knot_mid');
    expect(s.dialog, strF2SealKnotProgress2);
    tap('seal_a', 'knot_bottom');
    expect(s.flag('f2_seal_a_open'), 1);
    expect(s.dialog, strF2SealKnotOpen);
  });

  test('부정: 매듭 순서가 틀리면(아래를 먼저) 리셋 + 전용 대사', () {
    s.setFlag('f2_seal_altar_full', 1);
    tap('seal_a', 'knot_bottom');
    expect(s.flag('f2_seal_knot_seq'), 0);
    expect(s.dialog, strF2SealKnotWrong);
    expect(s.flag('f2_seal_a_open'), 0);
  });

  // ── 에드가·엔딩 ──

  test('에드가 대화: 탭마다 다음 줄(5줄), 5번째는 계획 원문 고정 대사, 6번째 탭에 작별 클로즈업', () {
    s.setFlag('f2_seal_a_open', 1);
    tap('seal_a', 'edgar');
    expect(s.dialog, strF2SealEdgarLine1);
    tap('seal_a', 'edgar');
    expect(s.dialog, strF2SealEdgarLine2);
    tap('seal_a', 'edgar');
    expect(s.dialog, strF2SealEdgarLine3);
    tap('seal_a', 'edgar');
    expect(s.dialog, strF2SealEdgarLine4);
    tap('seal_a', 'edgar');
    expect(s.dialog, strF2SealEdgarLine5);
    expect(s.dialog, '"오래 기다리게 했구나. …다들, 문 열렸다. 집에 가자."');
    expect(s.closeupId, isNull); // 아직 작별 클로즈업 전
    tap('seal_a', 'edgar');
    expect(s.closeupId, 'farewell');
  });

  test('에드가는 문이 열리기 전엔 등장하지 않는다(핫스팟 비활성)', () {
    final edgar = findHotspot(room, 'seal_a', 'edgar');
    expect(edgar.when!.call(s), isFalse);
  });

  test('아침 컷: 탭하면 f2_seal_done이 세워지고 클로즈업이 닫힌다(챕터 전체 완주)', () {
    s.openCloseup('ending');
    tap('ending', 'continue');
    expect(s.flag('f2_seal_done'), 1);
    expect(s.closeupId, isNull);
    expect(room.cleared(s), isTrue);
  });

  test('클리어 후 재진입: 에드가는 더 이상 나타나지 않고, 매듭 자리는 잔잔한 아침빛 대사를 준다', () {
    s.setFlag('f2_seal_a_open', 1);
    s.setFlag('f2_seal_done', 1);
    final edgar = findHotspot(room, 'seal_a', 'edgar');
    expect(edgar.when!.call(s), isFalse);
    tap('seal_a', 'knot_top');
    expect(s.dialog, strF2SealKnotAfterOpen);
    expect(room.cleared(s), isTrue); // 제단은 열린 채로 유지
  });

  // ── 순수 함수 단위 테스트 ──

  group('snuffCandle', () {
    test('4개를 다 끄면 c_dark와 b_awake가 동시에 켜진다', () {
      snuffCandle(s, 0);
      snuffCandle(s, 1);
      snuffCandle(s, 2);
      expect(s.flag('f2_seal_c_dark'), 0);
      snuffCandle(s, 3);
      expect(s.flag('f2_seal_c_dark'), 1);
      expect(s.flag('f2_seal_b_awake'), 1);
    });

    test('이미 꺼진 초는 다시 꺼도 변화 없음(멱등, 재점화 없음)', () {
      snuffCandle(s, 0);
      snuffCandle(s, 0);
      expect(s.flag('f2_seal_candle0'), 1);
    });
  });

  group('placeEmblem', () {
    test('hall→bed→child→lab 순서대로면 매번 true, 4단계에서 완성', () {
      expect(placeEmblem(s, 'emblem_hall'), isTrue);
      expect(placeEmblem(s, 'emblem_bed'), isTrue);
      expect(placeEmblem(s, 'emblem_child'), isTrue);
      expect(placeEmblem(s, 'emblem_lab'), isTrue);
      expect(s.flag('f2_seal_altar_seq'), 4);
    });

    test('첫 순서부터 틀리면 false + seq 0 유지', () {
      expect(placeEmblem(s, 'emblem_lab'), isFalse);
      expect(s.flag('f2_seal_altar_seq'), 0);
    });

    test('상징이 아닌 아이템/미선택은 false, 진행은 건드리지 않는다', () {
      placeEmblem(s, 'emblem_hall');
      expect(placeEmblem(s, 'key_f2seal'), isFalse);
      expect(placeEmblem(s, null), isFalse);
      expect(s.flag('f2_seal_altar_seq'), 1, reason: '관계없는 아이템은 진행을 리셋하지 않는다');
    });

    test('이미 4단계 완료 후 추가 배치는 false(변화 없음)', () {
      placeEmblem(s, 'emblem_hall');
      placeEmblem(s, 'emblem_bed');
      placeEmblem(s, 'emblem_child');
      placeEmblem(s, 'emblem_lab');
      expect(placeEmblem(s, 'emblem_hall'), isFalse);
      expect(s.flag('f2_seal_altar_seq'), 4);
    });
  });

  group('rubKnot', () {
    test('제단 미완성이면 항상 false, 진행 없음', () {
      expect(rubKnot(s, 0), isFalse);
      expect(s.flag('f2_seal_knot_seq'), 0);
    });

    test('제단 완성 후 0→1→2 순서대로면 매번 true, 3단계에서 seq=3', () {
      s.setFlag('f2_seal_altar_full', 1);
      expect(rubKnot(s, 0), isTrue);
      expect(rubKnot(s, 1), isTrue);
      expect(rubKnot(s, 2), isTrue);
      expect(s.flag('f2_seal_knot_seq'), 3);
    });

    test('순서가 틀리면 false + seq 0으로 리셋', () {
      s.setFlag('f2_seal_altar_full', 1);
      rubKnot(s, 0);
      expect(rubKnot(s, 2), isFalse);
      expect(s.flag('f2_seal_knot_seq'), 0);
    });

    test('이미 열린 뒤엔 false, 더 진행하지 않는다', () {
      s.setFlag('f2_seal_altar_full', 1);
      s.setFlag('f2_seal_a_open', 1);
      expect(rubKnot(s, 0), isFalse);
    });
  });

  // ── 등록·힌트 ──

  test('제단이 참조하는 모든 아이템 id는 레지스트리에 존재', () {
    for (final id in ['emblem_hall', 'emblem_bed', 'emblem_child', 'emblem_lab']) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });

  test('closeups의 key는 Scene.id와 일치(모델 assert가 이미 강제하지만 명시적으로도 확인)', () {
    for (final entry in room.closeups.entries) {
      expect(entry.key, entry.value.id);
    }
  });

  test('힌트 3개: p_f2_seal_ 접두어 + 단계 3개씩 + solved 조건 배선(각 조건 실제 호출)', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_f2_seal_candles', 'p_f2_seal_altar', 'p_f2_seal_knot']);
    for (final h in room.hints) {
      expect(h.steps.length, 3);
    }
    s.setFlag('f2_seal_b_awake', 1);
    expect(room.hints[0].solved!(s), isTrue);
    s.setFlag('f2_seal_altar_full', 1);
    expect(room.hints[1].solved!(s), isTrue);
    s.setFlag('f2_seal_a_open', 1);
    expect(room.hints[2].solved!(s), isTrue);
  });

  // ── 위젯 테스트 ──

  testWidgets('회상5 위젯: 벽화 앵커로 열린 MemoryPlayer가 3페이지를 넘기고 닫힌다', (t) async {
    s.setFlag('f2_seal_b_awake', 1);
    tap('seal_b', 'mural_house');
    expect(s.closeupId, 'memory');

    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 600,
            child: Builder(
                builder: (context) => room.closeups['memory']!.custom!(context, c)))));
    await t.pump();
    expect(find.text(strF2Mem5p1), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer));
    await t.pumpAndSettle();
    expect(find.text(strF2Mem5p2), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer));
    await t.pumpAndSettle();
    expect(find.text(strF2Mem5p3), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer)); // 마지막 페이지 탭 → onDone → closeCloseup
    await t.pump();
    expect(s.closeupId, isNull);
  });

  testWidgets('작별 위젯(MemoryPlayer 재사용): 유령 3명을 탭-전진 후 마지막 탭이 ending으로 이어진다',
      (t) async {
    s.setFlag('f2_seal_a_open', 1);
    for (var i = 0; i < 5; i++) {
      tap('seal_a', 'edgar');
    }
    tap('seal_a', 'edgar'); // farewell 열기
    expect(s.closeupId, 'farewell');

    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 600,
            child: Builder(
                builder: (context) => room.closeups['farewell']!.custom!(context, c)))));
    await t.pump();
    expect(find.text(strF2SealFarewellGhospo), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer));
    await t.pumpAndSettle();
    expect(find.text(strF2SealFarewellBoo), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer));
    await t.pumpAndSettle();
    expect(find.text(strF2SealFarewellOthers), findsOneWidget);

    await t.tap(find.byType(MemoryPlayer)); // 마지막 탭 → onDone → ending 클로즈업
    await t.pump();
    expect(s.closeupId, 'ending');
  });
}
