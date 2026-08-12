// 테스트 전용 라이브러리 (main() 없음) — 각 방의 정답 시퀀스를 다른 테스트가 재사용 (스펙 §8).
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/rooms/items.dart';
import 'package:ghostmanor/rooms/room1_foyer.dart';

/// room1_foyer_test.dart의 findHotspot 헬퍼를 일반화 — room을 인자로 받는다.
Hotspot findHotspot(Room room, String sceneId, String hotspotId) {
  final scenes = [...room.walls, ...room.closeups.values];
  final scene = scenes.firstWhere((sc) => sc.id == sceneId);
  return scene.hotspots.firstWhere((h) => h.id == hotspotId);
}

/// room1_foyer_test.dart의 tap 헬퍼를 일반화 — 활성 검사 expect 포함.
void tapSpot(Room room, GameState s, GameCtx c, String sceneId, String hotspotId) {
  final h = findHotspot(room, sceneId, hotspotId);
  expect(h.when?.call(s) ?? true, isTrue,
      reason: '$hotspotId가 비활성 상태에서 탭됨');
  h.onTap(c);
}

/// 현관 정답 시퀀스 (room1_foyer_test.dart의 "정답 시퀀스로 클리어 가능"과 동일 절차).
/// 다른 방 테스트가 "현관은 이미 클리어됐다"는 전제로 재사용한다.
void solveFoyer(GameState s, GameCtx c, Room room) {
  tapSpot(room, s, c, 'foyer_b', 'coat'); // 성냥
  expect(s.has('match'), isTrue);

  tapSpot(room, s, c, 'foyer_b', 'shoe_cabinet');
  expect(s.closeupId, 'shoes');
  tapSpot(room, s, c, 'shoes', 'candle_in_shoe'); // 양초
  expect(s.has('candle'), isTrue);

  expect(tryCombine(s, 'candle', 'match'), isTrue);
  expect(s.has('lit_candle'), isTrue);

  s.closeCloseup();

  // 액자 먼지 → 시계 3시 단서 (제스처 로직 함수)
  tapSpot(room, s, c, 'foyer_a', 'frame');
  expect(room.closeups.containsKey(s.closeupId), isTrue);
  s.closeCloseup();
  finishRubbing(s);
  expect(s.flag('foyer_dust_cleaned'), 1);

  // 벽시계 12→1→2→3
  tapSpot(room, s, c, 'foyer_b', 'clock');
  expect(room.closeups.containsKey(s.closeupId), isTrue);
  s.closeCloseup();
  tapClockHand(s);
  tapClockHand(s);
  tapClockHand(s);
  expect(s.flag('foyer_clock_hour'), 3);
  expect(s.flag('foyer_drawer_unlocked'), 1);

  // 서랍: 열림 → 어두움 → 촛불 → 열쇠
  tapSpot(room, s, c, 'foyer_a', 'drawer');
  expect(s.closeupId, 'drawer');
  s.select('lit_candle');
  tapSpot(room, s, c, 'drawer', 'drawer_dark');
  expect(s.flag('foyer_drawer_lit'), 1);
  tapSpot(room, s, c, 'drawer', 'drawer_key');
  expect(s.has('key_foyer'), isTrue);

  // 문: 잠김 → 열쇠 → 입장
  s.select('key_foyer');
  tapSpot(room, s, c, 'foyer_a', 'inner_door');
  expect(s.flag('foyer_inner_door_open'), 1);
  expect(s.has('key_foyer'), isFalse); // 열쇠 소모
  tapSpot(room, s, c, 'foyer_a', 'inner_door');
}
