import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/core/rub_scene.dart';
import 'package:ghostmanor/core/strings.dart';
import 'package:ghostmanor/rooms/items.dart';
import 'package:ghostmanor/rooms/room3_study.dart';
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
    room = buildStudy();
    // 방 2(거실) 진행분 전제 — 방 단독 테스트라 여기서 직접 지급(solveStudy는 지급 안 함).
    s.give('oil');
  });

  test('정답 시퀀스로 클리어 가능 (스텝 ≥15, 하드코어 게이트)', () {
    expect(room.cleared(s), isFalse);
    final steps = solveStudy(s, c, room);
    expect(steps, greaterThanOrEqualTo(15));
    expect(room.cleared(s), isTrue);
  });

  test('진입 직후 두 스레드 병렬 활성: paper(T2·벽B)·telescope(T1·벽C) 둘 다 fresh 상태에서 탭 가능',
      () {
    final paper = findHotspot(room, 'study_b', 'paper');
    final telescope = findHotspot(room, 'study_c', 'telescope');
    expect(paper.when?.call(s) ?? true, isTrue);
    expect(telescope.when?.call(s) ?? true, isTrue);
  });

  test('벽면 핫스팟 총수 ≥15 (하드코어 게이트)', () {
    final total = room.walls.fold<int>(0, (sum, w) => sum + w.hotspots.length);
    expect(total, greaterThanOrEqualTo(15));
  });

  test('부정: 렌즈 없이 망원경을 탭하면 관측할 수 없다(브리프 대사)', () {
    tap('study_c', 'telescope');
    expect(s.closeupId, isNull);
    expect(s.flag('study_r_telescope_lens'), 0);
    expect(s.dialog, strStudyRTelescopeNoLens);
  });

  test('지식 게이트 아님: 지도(starmap)를 열어본 적 없어도 정확히 3탭이면 지구본이 열린다(현관 편지와 동일 원칙)',
      () {
    expect(s.closeupId, isNull); // starmap을 연 적 없음
    tap('study_b', 'globe_arrow');
    tap('study_b', 'globe_arrow');
    tap('study_b', 'globe_arrow');
    expect(s.flag('study_r_globe_taps'), 3);
    final gap = findHotspot(room, 'study_b', 'globe_gap');
    expect(gap.when?.call(s) ?? true, isTrue); // 열려서 틈 핫스팟이 활성화됨
  });

  test('열림 상태 히트테스트: arrow·gap 겹침 구간 탭은 gap(열쇠 수령)으로 풀린다(z순서 의존 고정)',
      () {
    tap('study_b', 'globe_arrow');
    tap('study_b', 'globe_arrow');
    tap('study_b', 'globe_arrow');
    final wallB = room.walls.firstWhere((w) => w.id == 'study_b');
    final arrow = findHotspot(room, 'study_b', 'globe_arrow');
    final gap = findHotspot(room, 'study_b', 'globe_gap');
    final overlap = arrow.area.intersect(gap.area);
    expect(overlap.isEmpty, isFalse,
        reason: '전제: 두 rect는 실제로 겹친다(안 겹치면 이 테스트 자체가 무의미)');
    // SceneView onTapUp과 동일 규칙(hotspot_resolution_test와 같은 로직) —
    // 겹침 구간에서는 뒤에 선언된 gap이 이겨야 4번째-탭 실수 방지가 성립한다.
    String? resolve(Offset p) {
      for (final hs in wallB.hotspots.reversed) {
        if ((hs.when?.call(s) ?? true) && hs.area.contains(p)) return hs.id;
      }
      return null;
    }

    expect(resolve(overlap.center), 'globe_gap');
  });

  test('부정: 지구본 화살표를 4번째 탭하면(연타) taps가 0으로 리셋된다', () {
    tap('study_b', 'globe_arrow');
    tap('study_b', 'globe_arrow');
    tap('study_b', 'globe_arrow');
    expect(s.flag('study_r_globe_taps'), 3);
    tap('study_b', 'globe_arrow'); // 4번째
    expect(s.flag('study_r_globe_taps'), 0);
    expect(s.dialog, strStudyRGlobeReset);
  });

  test('지구본 화살표 핫스팟 경유: 3탭째 개방 대사, 4탭째 리셋 대사', () {
    tap('study_b', 'globe_arrow');
    tap('study_b', 'globe_arrow');
    tap('study_b', 'globe_arrow');
    expect(s.dialog, strStudyGlobeOpen);

    tap('study_b', 'globe_arrow');
    expect(s.dialog, strStudyRGlobeReset);
  });

  test('부정: taps가 3이 아니면 지구본 중앙 틈 핫스팟은 비활성', () {
    final gap = findHotspot(room, 'study_b', 'globe_gap');
    expect(gap.when?.call(s) ?? true, isFalse);
    tap('study_b', 'globe_arrow');
    tap('study_b', 'globe_arrow'); // taps=2, 아직 3 아님
    expect(gap.when?.call(s) ?? true, isFalse);
  });

  test('부정: 기름 없이 열쇠만 쓰면 문이 열리지 않는다(경첩 삐걱)', () {
    s.take('oil'); // 이 케이스는 기름이 없는 상태를 검증
    s.give('key_study');
    s.select('key_study');
    tap('study_b', 'door');
    expect(s.flag('study_r_door_unlocked'), 1);
    expect(s.has('key_study'), isFalse); // 열쇠는 소모됨

    tap('study_b', 'door'); // 잠금은 풀렸지만 기름이 없어 안 열림(삐걱)
    expect(s.flag('study_r_done'), 0);
    expect(s.dialog, strStudyDoorSqueak);
  });

  test('paper 핫스팟 탭 → paper 클로즈업이 열린다', () {
    tap('study_b', 'paper');
    expect(s.closeupId, 'paper');
  });

  test('책 핫스팟 경유: 틀린 순서는 리셋 + 리셋 대사', () {
    tap('study_a', 'book_blue'); // 정답 1단계(2)
    expect(s.flag('study_r_book_seq'), 1);

    tap('study_a', 'book_red'); // 오답(정답은 4=book_green)
    expect(s.flag('study_r_book_seq'), 0);
    expect(s.dialog, strStudyBookReset);
    expect(s.flag('study_r_nook_open'), 0);
  });

  group('tapBook', () {
    test('정답 순서(2,4,1,3)대로 탭하면 seq가 1씩 증가하고 4단계에서 nook_open', () {
      tapBook(s, 2);
      expect(s.flag('study_r_book_seq'), 1);
      tapBook(s, 4);
      expect(s.flag('study_r_book_seq'), 2);
      tapBook(s, 1);
      expect(s.flag('study_r_book_seq'), 3);
      tapBook(s, 3);
      expect(s.flag('study_r_book_seq'), 4);
      expect(s.flag('study_r_nook_open'), 1);
    });

    test('틀린 책을 탭하면 seq가 0으로 리셋된다', () {
      tapBook(s, 2);
      tapBook(s, 4);
      tapBook(s, 3); // 3번째 정답은 1인데 3을 탭 — 오답
      expect(s.flag('study_r_book_seq'), 0);
    });

    test('nook_open 후에는 no-op', () {
      tapBook(s, 2);
      tapBook(s, 4);
      tapBook(s, 1);
      tapBook(s, 3);
      expect(s.flag('study_r_nook_open'), 1);

      tapBook(s, 2); // 완료 후 재호출
      expect(s.flag('study_r_book_seq'), 4); // 그대로 — no-op
      expect(s.flag('study_r_nook_open'), 1);
    });
  });

  group('tapGlobeArrow', () {
    test('1~3탭: taps가 1씩 증가, 정확히 3에서 개방 상태(taps==3)', () {
      tapGlobeArrow(s);
      expect(s.flag('study_r_globe_taps'), 1);
      tapGlobeArrow(s);
      expect(s.flag('study_r_globe_taps'), 2);
      tapGlobeArrow(s);
      expect(s.flag('study_r_globe_taps'), 3);
    });

    test('4번째 탭(오차)은 0으로 리셋된다', () {
      tapGlobeArrow(s);
      tapGlobeArrow(s);
      tapGlobeArrow(s);
      tapGlobeArrow(s); // 4번째
      expect(s.flag('study_r_globe_taps'), 0);
    });

    test('열쇠 획득 후에는 no-op(taps 불변)', () {
      tapGlobeArrow(s);
      tapGlobeArrow(s);
      tapGlobeArrow(s);
      s.setFlag('study_r_got_key', 1);
      tapGlobeArrow(s);
      expect(s.flag('study_r_globe_taps'), 3); // 그대로
    });
  });

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in ['lens', 'key_study', 'note2']) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });

  test('힌트 3개: p_study_r_ 접두어 + 단계 3개씩 + solved 조건 배선', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_study_r_books', 'p_study_r_stars', 'p_study_r_door']);
    for (final h in room.hints) {
      expect(h.steps.length, 3);
    }
    s.setFlag('study_r_nook_open', 1);
    expect(room.hints[0].solved!(s), isTrue);
    s.setFlag('study_r_got_key', 1);
    expect(room.hints[1].solved!(s), isTrue);
    s.setFlag('study_r_done', 1);
    expect(room.hints[2].solved!(s), isTrue);
  });

  // RubbableScene은 Task 1에서 이미 구현된 공유 위젯 — room1_foyer_test.dart의
  // "액자 위젯" 테스트는 최종 flag 상태만 확인해 원샷 가드(리빌드 전 연속 pan에도
  // onCleaned 1회)를 실제로 증명하지 못한다(finishRubbing이 멱등이라 가드 유무와
  // 무관하게 통과). 여기서 pump() 없이 raw pointer moveBy를 연속 전송해 그 레이스를
  // 직접 재현하는 가드 테스트 1개만 추가한다(브리프 지시).
  testWidgets('paper 위젯: 리빌드 전 연속 pan에도 onCleaned은 1회만 호출(원샷 가드)',
      (t) async {
    var cleanedCalls = 0;
    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 400,
            child: RubbableScene(
              ctx: c,
              baseImage: 'assets/scenes/study_paper_clean2.png',
              coverImage: 'assets/scenes/study_paper_ink.png',
              cleaned: (s) => s.flag('study_r_paper_rubbed') >= 1,
              onCleaned: (c) {
                cleanedCalls++;
                c.s.setFlag('study_r_paper_rubbed', 1);
              },
              gestureKey: const Key('paper_rub'),
            ))));

    final center = t.getCenter(find.byKey(const Key('paper_rub')));
    final gesture = await t.startGesture(center);
    // progressPerPx 기본값(1/2500) 기준 거리 3000px면 단일 이동으로 progress>=1 도달.
    // pump() 없이 3회 연속 이동 — 가드 없으면 매 이동마다 onCleaned가 재호출된다.
    await gesture.moveBy(const Offset(3000, 0));
    await gesture.moveBy(const Offset(3000, 0));
    await gesture.moveBy(const Offset(3000, 0));
    await gesture.up();
    await t.pump();

    expect(cleanedCalls, 1);
  });
}
