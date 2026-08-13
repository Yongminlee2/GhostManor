import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/dial_safe.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/core/strings.dart';
import 'package:ghostmanor/rooms/items.dart';
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

  test('정답 시퀀스로 클리어 가능 (스텝 ≥15, 하드코어 게이트)', () {
    expect(room.cleared(s), isFalse);
    final steps = solveAttic(s, c, room);
    expect(steps, greaterThanOrEqualTo(15));
    expect(room.cleared(s), isTrue);
  });

  test('병렬 단언: 진입 직후 쪽지(T2 단서)와 자수 액자(T1측 조사) 둘 다 반응한다', () {
    tap('attic_c', 'old_note');
    expect(s.closeupId, 'old_note');
    s.closeCloseup();

    tap('attic_b', 'embroidery');
    expect(s.closeupId, 'embroidery');
  });

  test('벽면 핫스팟 총수 ≥15 (하드코어 게이트)', () {
    final total = room.walls.fold<int>(0, (sum, w) => sum + w.hotspots.length);
    expect(total, greaterThanOrEqualTo(15));
  });

  // ── 부정 테스트 ──

  test('부정: 카드 3장에서 organ을 탭해도 클로즈업이 열리지 않는다', () {
    s.setFlag('attic_r_cards_placed', 3);
    tap('attic_a', 'organ');
    expect(s.closeupId, isNull);
  });

  test('부정: 카드 미완 상태에서 tapOrganKey는 no-op', () {
    tapOrganKey(s, 1);
    expect(s.flag('attic_r_organ_seq'), 0);
  });

  test('부정: 틀린 연주(1,2)는 진행을 리셋한다', () {
    s.setFlag('attic_r_cards_placed', 4);
    tapOrganKey(s, 1); // 정답 1단계
    expect(s.flag('attic_r_organ_seq'), 1);
    tapOrganKey(s, 2); // 오답(정답은 3)
    expect(s.flag('attic_r_organ_seq'), 0);
    expect(s.flag('attic_r_organ_played'), 0);
  });

  test('부정: organ_played 전에 trunk를 탭하면 잠겨 있다', () {
    tap('attic_b', 'trunk');
    expect(s.flag('attic_r_got_will'), 0);
    expect(s.flag('attic_r_done'), 0);
  });

  test('지식 게이트 아님: 자수 조각을 맞추지 않아도 카드 4장+정연주면 오르간이 성공한다', () {
    s.setFlag('attic_r_cards_placed', 4);
    tapOrganKey(s, 1);
    tapOrganKey(s, 3);
    tapOrganKey(s, 2);
    tapOrganKey(s, 4);
    expect(s.flag('attic_r_organ_played'), 1);
    expect(s.flag('attic_r_embroidery_full'), 0); // 끝까지 미완성 상태로도 성공
  });

  test('지식 게이트 아님: 쪽지(old_note)를 열어본 적 없어도 342 코드면 궤짝이 열린다', () {
    expect(s.closeupId, isNull); // old_note를 연 적 없음
    s.setFlag('attic_r_chest_d0', 3);
    s.setFlag('attic_r_chest_d1', 4);
    s.setFlag('attic_r_chest_d2', 2);
    expect(checkDialCode(s, 'attic_r_chest', '342'), isTrue);
    openChest(c);
    expect(s.flag('attic_r_chest_open'), 1);
    expect(s.has('shred'), isTrue);
  });

  test('궤짝: 이미 연 후 재탭하면 빈 궤짝 대사(클로즈업 다시 안 열림)', () {
    s.setFlag('attic_r_chest_open', 1);
    tap('attic_c', 'chest');
    expect(s.closeupId, isNull);
    expect(s.dialog, strAtticRChestEmpty);
  });

  test('DialSafe digits:3 재사용: attic_r_chest는 living_r_safe(4자리)와 플래그 네임스페이스가 분리된다',
      () {
    s.setFlag('living_r_safe_d0', 9); // 거실 금고 자리가 있어도 서로 영향 없음
    tapDialWheel(s, 'attic_r_chest', 0);
    tapDialWheel(s, 'attic_r_chest', 1);
    tapDialWheel(s, 'attic_r_chest', 1);
    expect(s.flag('attic_r_chest_d0'), 1);
    expect(s.flag('attic_r_chest_d1'), 2);
    expect(s.flag('living_r_safe_d0'), 9); // 그대로 — 접두어로 분리됨
    expect(s.flag('living_r_safe_d1'), 0); // 애초에 건드린 적 없음

    s.setFlag('attic_r_chest_d0', 3);
    s.setFlag('attic_r_chest_d1', 4);
    s.setFlag('attic_r_chest_d2', 2);
    expect(checkDialCode(s, 'attic_r_chest', '342'), isTrue); // 3자리만 비교
  });

  group('tapOrganKey', () {
    test('정답 순서 1,3,2,4대로 탭하면 seq가 1씩 증가하고 4단계에서 organ_played', () {
      s.setFlag('attic_r_cards_placed', 4);
      tapOrganKey(s, 1);
      expect(s.flag('attic_r_organ_seq'), 1);
      tapOrganKey(s, 3);
      expect(s.flag('attic_r_organ_seq'), 2);
      tapOrganKey(s, 2);
      expect(s.flag('attic_r_organ_seq'), 3);
      tapOrganKey(s, 4);
      expect(s.flag('attic_r_organ_seq'), 4);
      expect(s.flag('attic_r_organ_played'), 1);
    });

    test('틀린 건반을 탭하면 seq가 0으로 리셋된다', () {
      s.setFlag('attic_r_cards_placed', 4);
      tapOrganKey(s, 1);
      tapOrganKey(s, 3);
      tapOrganKey(s, 4); // 3번째 정답은 2인데 4를 탭 — 오답
      expect(s.flag('attic_r_organ_seq'), 0);
    });

    test('cards_placed<4면 게이트로 no-op', () {
      s.setFlag('attic_r_cards_placed', 3);
      tapOrganKey(s, 1);
      expect(s.flag('attic_r_organ_seq'), 0);
    });

    test('organ_played 후 재탭은 no-op(순서 배열 범위 밖 인덱스 방지)', () {
      s.setFlag('attic_r_cards_placed', 4);
      tapOrganKey(s, 1);
      tapOrganKey(s, 3);
      tapOrganKey(s, 2);
      tapOrganKey(s, 4);
      expect(s.flag('attic_r_organ_played'), 1);

      expect(() => tapOrganKey(s, 1), returnsNormally);
      expect(s.flag('attic_r_organ_seq'), 4); // 그대로 — no-op
    });
  });

  test('힌트 3개: p_attic_r_ 접두어 + 단계 3개씩 + solved 조건 배선(각 조건 실제 호출)', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_attic_r_chest', 'p_attic_r_order', 'p_attic_r_trunk']);
    for (final h in room.hints) {
      expect(h.steps.length, 3);
    }

    s.setFlag('attic_r_chest_open', 1);
    expect(room.hints[0].solved!(s), isTrue);

    s.setFlag('attic_r_organ_played', 1);
    expect(room.hints[1].solved!(s), isTrue);

    s.setFlag('attic_r_done', 1);
    expect(room.hints[2].solved!(s), isTrue);
  });

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in ['note1', 'note2', 'note3', 'note4', 'shred']) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });

  testWidgets('오르간 건반 위젯: 1,3,2,4 순서 탭 → organ_played + 완료 대사', (t) async {
    s.setFlag('attic_r_cards_placed', 4);
    await t.pumpWidget(MaterialApp(
        home: SizedBox(width: 400, height: 400, child: OrganKeys(ctx: c))));
    for (final i in [1, 3, 2, 4]) {
      await t.tap(find.byKey(Key('organ_key_$i')));
      await t.pump();
    }
    expect(s.flag('attic_r_organ_played'), 1);
    expect(s.dialog, strAtticOrganPlayed);
  });

  // tapOrganKey 직접 호출로는 OrganKeys._tapKey(위젯 래퍼)의 리셋 대사 분기가
  // 한 번도 실행되지 않는다 — 위젯 경유로 별도 검증(room3 tapBookSpot 리뷰 지적과
  // 동일한 함정, 선제 반영).
  testWidgets('오르간 건반 위젯: 틀린 순서 탭 → 리셋 + 경고 대사', (t) async {
    s.setFlag('attic_r_cards_placed', 4);
    await t.pumpWidget(MaterialApp(
        home: SizedBox(width: 400, height: 400, child: OrganKeys(ctx: c))));
    await t.tap(find.byKey(const Key('organ_key_1'))); // 정답 1단계
    await t.pump();
    expect(s.flag('attic_r_organ_seq'), 1);

    await t.tap(find.byKey(const Key('organ_key_2'))); // 오답(정답은 3)
    await t.pump();
    expect(s.flag('attic_r_organ_seq'), 0);
    expect(s.flag('attic_r_organ_played'), 0);
    expect(s.dialog, strAtticOrganWrong);
  });

  testWidgets('궤짝 위젯(room 배선): 정답 342 입력 → 열림 + shred 지급 + 성공 대사', (t) async {
    tap('attic_c', 'chest');
    expect(s.closeupId, 'chest');

    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 400,
            child: Builder(
                builder: (context) =>
                    room.closeups['chest']!.custom!(context, c)))));

    const targets = [3, 4, 2];
    for (var wheel = 0; wheel < targets.length; wheel++) {
      for (var n = 0; n < targets[wheel]; n++) {
        await t.tap(find.byKey(Key('dial_wheel_$wheel')));
        await t.pump();
      }
    }
    await t.tap(find.byKey(const Key('dial_confirm')));
    await t.pump();

    expect(s.flag('attic_r_chest_open'), 1);
    expect(s.has('shred'), isTrue);
    expect(s.dialog, strAtticRChestOpen);
  });

  testWidgets('궤짝 위젯(room 배선): 오답 확인 → 열리지 않고 브리프 대사 + 휠 전체 리셋', (t) async {
    tap('attic_c', 'chest');
    expect(s.closeupId, 'chest');

    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 400,
            child: Builder(
                builder: (context) =>
                    room.closeups['chest']!.custom!(context, c)))));

    for (var i = 0; i < 5; i++) {
      await t.tap(find.byKey(const Key('dial_wheel_0')));
      await t.pump();
    } // 휠0=5, 나머지 0 → 342가 아님

    await t.tap(find.byKey(const Key('dial_confirm')));
    await t.pump();

    expect(s.flag('attic_r_chest_open'), 0);
    expect(s.has('shred'), isFalse);
    expect(s.dialog, strAtticRChestWrong);
    expect(s.flag('attic_r_chest_d0'), 0); // 오답 후 리셋
  });
}
