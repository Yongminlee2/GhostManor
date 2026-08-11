import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/rooms/items.dart';
import 'package:ghostmanor/rooms/room1_foyer.dart';

void main() {
  late GameState s;
  late GameCtx c;
  late Room room;

  Hotspot findHotspot(String sceneId, String hotspotId) {
    final scenes = [...room.walls, ...room.closeups.values];
    final scene = scenes.firstWhere((sc) => sc.id == sceneId);
    return scene.hotspots.firstWhere((h) => h.id == hotspotId);
  }

  void tap(String sceneId, String hotspotId) {
    final h = findHotspot(sceneId, hotspotId);
    expect(h.when?.call(s) ?? true, isTrue,
        reason: '$hotspotId가 비활성 상태에서 탭됨');
    h.onTap(c);
  }

  setUp(() {
    s = GameState();
    c = GameCtx(s, AudioService(enabled: false));
    room = buildFoyer();
  });

  test('정답 시퀀스로 클리어 가능 (스펙 §8 최소 안전망)', () {
    expect(room.cleared(s), isFalse);

    tap('foyer_b', 'coat'); // 성냥
    expect(s.has('match'), isTrue);
    tap('foyer_b', 'coat'); // 두 번째는 빈 주머니 (중복 지급 없음)
    expect(s.inventory.where((i) => i == 'match').length, 1);

    tap('foyer_b', 'shoe_cabinet');
    expect(s.closeupId, 'shoes');
    tap('shoes', 'candle_in_shoe'); // 양초
    expect(s.has('candle'), isTrue);

    expect(tryCombine(s, 'candle', 'match'), isTrue);
    expect(s.has('lit_candle'), isTrue);

    // 잠긴 서랍은 아직 안 열림
    s.closeCloseup();
    tap('foyer_a', 'drawer');
    expect(s.closeupId, isNull);

    // 액자 먼지 → 시계 3시 단서 (제스처 로직 함수)
    tap('foyer_a', 'frame');
    expect(room.closeups.containsKey(s.closeupId), isTrue);
    s.closeCloseup();
    finishRubbing(s);
    expect(s.flag('foyer_dust_cleaned'), 1);

    // 벽시계 12→1→2→3
    tap('foyer_b', 'clock');
    expect(room.closeups.containsKey(s.closeupId), isTrue);
    s.closeCloseup();
    tapClockHand(s);
    tapClockHand(s);
    tapClockHand(s);
    expect(s.flag('foyer_clock_hour'), 3);
    expect(s.flag('foyer_drawer_unlocked'), 1);

    // 서랍: 열림 → 어두움 → 촛불 → 열쇠
    tap('foyer_a', 'drawer');
    expect(s.closeupId, 'drawer');
    s.select('lit_candle');
    tap('drawer', 'drawer_dark');
    expect(s.flag('foyer_drawer_lit'), 1);
    tap('drawer', 'drawer_key');
    expect(s.has('key_foyer'), isTrue);

    // 문: 잠김 → 열쇠 → 입장
    expect(room.cleared(s), isFalse);
    s.select('key_foyer');
    tap('foyer_a', 'inner_door');
    expect(s.flag('foyer_inner_door_open'), 1);
    expect(s.has('key_foyer'), isFalse); // 열쇠 소모
    tap('foyer_a', 'inner_door');
    expect(room.cleared(s), isTrue);
  });

  test('순서 강제: 촛불 없이 서랍 안은 안 보임, 열쇠 없인 문 안 열림', () {
    s.setFlag('foyer_drawer_unlocked', 1);
    tap('foyer_a', 'drawer');
    tap('drawer', 'drawer_dark'); // 촛불 미선택
    expect(s.flag('foyer_drawer_lit'), 0);
    tap('foyer_a', 'inner_door'); // 열쇠 없음
    expect(s.flag('foyer_inner_door_open'), 0);
  });

  test('시계는 12시간 순환', () {
    for (var i = 0; i < 12; i++) {
      tapClockHand(s);
    }
    expect(s.flag('foyer_clock_hour'), 12);
    tapClockHand(s);
    expect(s.flag('foyer_clock_hour'), 1);
  });

  test('힌트 3개: 단계 3개씩 + solved 조건 배선', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_foyer_light', 'p_foyer_clock', 'p_foyer_door']);
    s.setFlag('foyer_drawer_lit', 1);
    expect(room.hints[0].solved!(s), isTrue);
  });

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in ['match', 'candle', 'lit_candle', 'key_foyer']) {
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
    expect(s.flag('foyer_drawer_unlocked'), 1);
  });

  testWidgets('액자 위젯: 문지르면 먼지 제거', (t) async {
    await t.pumpWidget(MaterialApp(
        home: SizedBox(width: 400, height: 400, child: FrameCloseup(ctx: c))));
    for (var i = 0; i < 30; i++) {
      await t.drag(find.byKey(const Key('frame_rub')), const Offset(120, 0),
          warnIfMissed: false);
      await t.pump();
    }
    expect(s.flag('foyer_dust_cleaned'), 1);
  });
}
