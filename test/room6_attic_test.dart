import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/core/strings.dart';
import 'package:ghostmanor/rooms/room6_attic.dart';
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
    room = buildAttic();
    // 전제: 방 2~5(거실·서재·주방·지하실)를 클리어해 note1~4를 이미 보유한 상태
    // — solveAttic은 카드를 지급하지 않는다(브리프 명시). 방 단독 테스트라 여기서 지급.
    for (final note in ['note1', 'note2', 'note3', 'note4']) {
      s.give(note);
    }
  });

  test('정답 시퀀스로 클리어 가능', () {
    expect(room.cleared(s), isFalse);
    solveAttic(s, c, room);
    expect(room.cleared(s), isTrue);
  });

  test('부정: 카드 3장에서 organ을 탭해도 클로즈업이 열리지 않는다', () {
    s.setFlag('attic_cards_placed', 3);
    tap('attic_a', 'organ');
    expect(s.closeupId, isNull);
  });

  test('부정: 카드 미완 상태에서 tapOrganKey는 no-op', () {
    tapOrganKey(s, 1);
    expect(s.flag('attic_organ_seq'), 0);
  });

  test('부정: 틀린 연주(1,2)는 진행을 리셋한다', () {
    s.setFlag('attic_cards_placed', 4);
    tapOrganKey(s, 1); // 정답 1단계
    expect(s.flag('attic_organ_seq'), 1);
    tapOrganKey(s, 2); // 오답(정답은 3)
    expect(s.flag('attic_organ_seq'), 0);
    expect(s.flag('attic_organ_played'), 0);
  });

  test('부정: organ_played 전에 trunk를 탭하면 잠겨 있다', () {
    tap('attic_b', 'trunk');
    expect(s.flag('attic_got_will'), 0);
    expect(s.flag('attic_done'), 0);
  });

  group('tapOrganKey', () {
    test('정답 순서 1,3,2,4대로 탭하면 seq가 1씩 증가하고 4단계에서 organ_played', () {
      s.setFlag('attic_cards_placed', 4);
      tapOrganKey(s, 1);
      expect(s.flag('attic_organ_seq'), 1);
      tapOrganKey(s, 3);
      expect(s.flag('attic_organ_seq'), 2);
      tapOrganKey(s, 2);
      expect(s.flag('attic_organ_seq'), 3);
      tapOrganKey(s, 4);
      expect(s.flag('attic_organ_seq'), 4);
      expect(s.flag('attic_organ_played'), 1);
    });

    test('틀린 건반을 탭하면 seq가 0으로 리셋된다', () {
      s.setFlag('attic_cards_placed', 4);
      tapOrganKey(s, 1);
      tapOrganKey(s, 3);
      tapOrganKey(s, 4); // 3번째 정답은 2인데 4를 탭 — 오답
      expect(s.flag('attic_organ_seq'), 0);
    });

    test('cards_placed<4면 게이트로 no-op', () {
      s.setFlag('attic_cards_placed', 3);
      tapOrganKey(s, 1);
      expect(s.flag('attic_organ_seq'), 0);
    });

    test('organ_played 후 재탭은 no-op(순서 배열 범위 밖 인덱스 방지)', () {
      s.setFlag('attic_cards_placed', 4);
      tapOrganKey(s, 1);
      tapOrganKey(s, 3);
      tapOrganKey(s, 2);
      tapOrganKey(s, 4);
      expect(s.flag('attic_organ_played'), 1);

      expect(() => tapOrganKey(s, 1), returnsNormally);
      expect(s.flag('attic_organ_seq'), 4); // 그대로 — no-op
    });
  });

  test('힌트 3개: 단계 3개씩 + solved 조건 배선(각 조건 실제 호출)', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_attic_cards', 'p_attic_order', 'p_attic_trunk']);

    s.setFlag('attic_cards_placed', 4);
    expect(room.hints[0].solved!(s), isTrue);

    s.setFlag('attic_organ_played', 1);
    expect(room.hints[1].solved!(s), isTrue);

    s.setFlag('attic_done', 1);
    expect(room.hints[2].solved!(s), isTrue);
  });

  testWidgets('오르간 건반 위젯: 1,3,2,4 순서 탭 → organ_played + 완료 대사', (t) async {
    s.setFlag('attic_cards_placed', 4);
    await t.pumpWidget(MaterialApp(
        home: SizedBox(width: 400, height: 400, child: OrganKeys(ctx: c))));
    for (final i in [1, 3, 2, 4]) {
      await t.tap(find.byKey(Key('organ_key_$i')));
      await t.pump();
    }
    expect(s.flag('attic_organ_played'), 1);
    expect(s.dialog, strAtticOrganPlayed);
  });

  // tapOrganKey 직접 호출로는 OrganKeys._tapKey(위젯 래퍼)의 리셋 대사 분기가
  // 한 번도 실행되지 않는다 — 위젯 경유로 별도 검증(room3 tapBookSpot 리뷰 지적과
  // 동일한 함정, 선제 반영).
  testWidgets('오르간 건반 위젯: 틀린 순서 탭 → 리셋 + 경고 대사', (t) async {
    s.setFlag('attic_cards_placed', 4);
    await t.pumpWidget(MaterialApp(
        home: SizedBox(width: 400, height: 400, child: OrganKeys(ctx: c))));
    await t.tap(find.byKey(const Key('organ_key_1'))); // 정답 1단계
    await t.pump();
    expect(s.flag('attic_organ_seq'), 1);

    await t.tap(find.byKey(const Key('organ_key_2'))); // 오답(정답은 3)
    await t.pump();
    expect(s.flag('attic_organ_seq'), 0);
    expect(s.flag('attic_organ_played'), 0);
    expect(s.dialog, strAtticOrganWrong);
  });
}
