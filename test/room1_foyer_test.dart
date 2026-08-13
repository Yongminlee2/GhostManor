import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/core/strings.dart';
import 'package:ghostmanor/rooms/items.dart';
import 'package:ghostmanor/rooms/room1_foyer.dart';
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
    room = buildFoyer();
  });

  test('정답 시퀀스로 클리어 가능 (스텝 ≥15, 하드코어 게이트)', () {
    expect(room.cleared(s), isFalse);
    final steps = solveFoyer(s, c, room);
    expect(steps, greaterThanOrEqualTo(15));
    expect(room.cleared(s), isTrue);
  });

  test('진입 직후 두 스레드 병렬 활성: coat(T1·벽B)·mailbox(T2·벽C) 둘 다 fresh 상태에서 탭 가능',
      () {
    final coat = findHotspot(room, 'foyer_b', 'coat');
    final mailbox = findHotspot(room, 'foyer_c', 'mailbox');
    expect(coat.when?.call(s) ?? true, isTrue);
    expect(mailbox.when?.call(s) ?? true, isTrue);
  });

  test('벽면 핫스팟 총수 ≥15 (하드코어 게이트)', () {
    final total = room.walls.fold<int>(0, (sum, w) => sum + w.hotspots.length);
    expect(total, greaterThanOrEqualTo(15));
  });

  test('부정: 촛불 없이 서랍 안을 탭하면 어둠 대사, drawer_lit은 0', () {
    s.setFlag('foyer_r_drawer_unlocked', 1);
    tap('foyer_a', 'drawer');
    expect(s.closeupId, 'drawer');
    tap('drawer', 'drawer_dark'); // lit_candle 미선택
    expect(s.flag('foyer_r_drawer_lit'), 0);
    expect(s.dialog, strFoyerDrawerDark);
  });

  test('부정: 시계가 3시가 아니면 서랍은 잠긴 채(오답 전문 대사)', () {
    tapClockHand(s); // 1시 — 3시 아님
    expect(s.flag('foyer_r_drawer_unlocked'), 0);
    tap('foyer_a', 'drawer');
    expect(s.closeupId, isNull); // 안 열림
    expect(s.dialog, strFoyerRDrawerLocked);
  });

  test('부정: 편지 없이도 시계만 3시면 서랍 열림 (편지는 지식 단서일 뿐, 기계적 게이트 아님)', () {
    expect(s.has('letter1'), isFalse);
    tapClockHand(s);
    tapClockHand(s);
    tapClockHand(s);
    expect(s.flag('foyer_r_clock_hour'), 3);
    expect(s.flag('foyer_r_drawer_unlocked'), 1);
    tap('foyer_a', 'drawer');
    expect(s.closeupId, 'drawer'); // 편지 없이도 열림
  });

  test('시계는 12시간 순환', () {
    for (var i = 0; i < 12; i++) {
      tapClockHand(s);
    }
    expect(s.flag('foyer_r_clock_hour'), 12);
    tapClockHand(s);
    expect(s.flag('foyer_r_clock_hour'), 1);
  });

  test('힌트 3개: p_foyer_r_ 접두어 + 단계 3개씩 + solved 조건 배선', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_foyer_r_light', 'p_foyer_r_clock', 'p_foyer_r_door']);
    for (final h in room.hints) {
      expect(h.steps.length, 3);
    }
    s.setFlag('foyer_r_drawer_lit', 1);
    expect(room.hints[0].solved!(s), isTrue);
    s.setFlag('foyer_r_drawer_unlocked', 1);
    expect(room.hints[1].solved!(s), isTrue);
    s.setFlag('foyer_r_inner_door_open', 1);
    expect(room.hints[2].solved!(s), isTrue);
  });

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in ['match', 'candle', 'lit_candle', 'key_foyer', 'letter1']) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });

  testWidgets('시계 위젯: 탭 3번이면 서랍 해금', (t) async {
    await t.pumpWidget(MaterialApp(
        home: SizedBox(width: 400, height: 400, child: ClockCloseup(ctx: c))));
    for (var i = 0; i < 3; i++) {
      await t.tap(find.byKey(const Key('clock_tap')));
      await t.pump();
    }
    expect(s.flag('foyer_r_drawer_unlocked'), 1);
  });

  testWidgets('외투 위젯(RubbableScene): 문지르면 성냥 획득', (t) async {
    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 400,
            child: Builder(
                builder: (context) =>
                    room.closeups['coat']!.custom!(context, c)))));
    for (var i = 0; i < 30; i++) {
      await t.drag(find.byKey(const Key('coat_rub')), const Offset(120, 0),
          warnIfMissed: false);
      await t.pump();
    }
    expect(s.has('match'), isTrue);
    expect(s.flag('foyer_r_got_match'), 1);
  });

  testWidgets('액자 위젯(RubbableScene): 문지르면 먼지 제거', (t) async {
    await t.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 400,
            child: Builder(
                builder: (context) =>
                    room.closeups['frame']!.custom!(context, c)))));
    for (var i = 0; i < 30; i++) {
      await t.drag(find.byKey(const Key('frame_rub')), const Offset(120, 0),
          warnIfMissed: false);
      await t.pump();
    }
    expect(s.flag('foyer_r_dust_cleaned'), 1);
  });
}
