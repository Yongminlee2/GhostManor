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

  test('정답 시퀀스로 클리어 가능', () {
    expect(room.cleared(s), isFalse);
    solveStudy(s, c, room);
    expect(room.cleared(s), isTrue);
  });

  test('부정: 틀린 책 순서(2,1)는 진행을 리셋한다', () {
    tapBook(s, 2);
    expect(s.flag('study_book_seq'), 1);
    tapBook(s, 1);
    expect(s.flag('study_book_seq'), 0);
  });

  // tapBook 직접 호출로는 tapBookSpot(onTap 래퍼)의 리셋 대사 분기가 한 번도
  // 실행되지 않는다 — 핫스팟 경유로 별도 검증(리뷰 지적, Important).
  test('책 핫스팟 경유: 틀린 순서는 리셋 + 리셋 대사', () {
    tap('study_a', 'book_blue'); // 정답 1단계(2)
    expect(s.flag('study_book_seq'), 1);

    tap('study_a', 'book_red'); // 오답(정답은 4=book_green)
    expect(s.flag('study_book_seq'), 0);
    expect(s.dialog, strStudyBookReset);
    expect(s.flag('study_nook_open'), 0);
  });

  test('부정: 기름 없이 열쇠만 쓰면 문이 열리지 않는다(경첩 삐걱)', () {
    s.take('oil'); // 이 케이스는 기름이 없는 상태를 검증
    s.give('key_study');
    s.select('key_study');
    tap('study_b', 'door');
    expect(s.flag('study_door_unlocked'), 1);
    expect(s.has('key_study'), isFalse); // 열쇠는 소모됨

    tap('study_b', 'door'); // 잠금은 풀렸지만 기름이 없어 안 열림(삐걱)
    expect(s.flag('study_done'), 0);
  });

  test('부정: 크랭크 없이 지구본을 탭하면 열리지 않는다', () {
    tap('study_b', 'globe');
    expect(s.flag('study_globe_open'), 0);
  });

  test('paper 핫스팟 탭 → paper 클로즈업이 열린다', () {
    tap('study_b', 'paper');
    expect(s.closeupId, 'paper');
  });

  group('tapBook', () {
    test('정답 순서(2,4,1,3)대로 탭하면 seq가 1씩 증가하고 4단계에서 nook_open', () {
      tapBook(s, 2);
      expect(s.flag('study_book_seq'), 1);
      tapBook(s, 4);
      expect(s.flag('study_book_seq'), 2);
      tapBook(s, 1);
      expect(s.flag('study_book_seq'), 3);
      tapBook(s, 3);
      expect(s.flag('study_book_seq'), 4);
      expect(s.flag('study_nook_open'), 1);
    });

    test('틀린 책을 탭하면 seq가 0으로 리셋된다', () {
      tapBook(s, 2);
      tapBook(s, 4);
      tapBook(s, 3); // 3번째 정답은 1인데 3을 탭 — 오답
      expect(s.flag('study_book_seq'), 0);
    });

    test('nook_open 후에는 no-op', () {
      tapBook(s, 2);
      tapBook(s, 4);
      tapBook(s, 1);
      tapBook(s, 3);
      expect(s.flag('study_nook_open'), 1);

      tapBook(s, 2); // 완료 후 재호출
      expect(s.flag('study_book_seq'), 4); // 그대로 — no-op
      expect(s.flag('study_nook_open'), 1);
    });
  });

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in ['crank', 'key_study', 'note2']) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });

  test('힌트 3개: 단계 3개씩 + solved 조건 배선', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_study_books', 'p_study_globe', 'p_study_door']);
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
              baseImage: 'assets/scenes/study_paper_clean.png',
              coverImage: 'assets/scenes/study_paper_ink.png',
              cleaned: (s) => s.flag('study_paper_rubbed') >= 1,
              onCleaned: (c) {
                cleanedCalls++;
                c.s.setFlag('study_paper_rubbed', 1);
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
