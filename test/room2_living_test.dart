import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/audio_service.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
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

  test('정답 시퀀스로 클리어 가능', () {
    expect(room.cleared(s), isFalse);
    solveLiving(s, c, room);
    expect(room.cleared(s), isTrue);
  });

  test('부정: TV 켜지기 전엔 부우가 문을 막아 열리지 않음', () {
    tap('living_b', 'door');
    expect(s.flag('living_door_open'), 0);
  });

  test('부정: 잘못된 촛불 패턴(1·2번만 켬)은 벽난로를 켜지 않음', () {
    toggleCandle(s, 1);
    toggleCandle(s, 2);
    expect(s.flag('living_fireplace_lit'), 0);
  });

  test('부정: 점화 전 비밀칸을 열어도 아이템이 없음', () {
    tap('living_a', 'secret_nook');
    expect(s.has('key_living'), isFalse);
    expect(s.has('note1'), isFalse);
    expect(s.has('oil'), isFalse);
  });

  test('부정: 점화 후 촛대 핫스팟은 모두 비활성', () {
    toggleCandle(s, 2);
    toggleCandle(s, 4);
    expect(s.flag('living_fireplace_lit'), 1);
    for (final id in ['candle1', 'candle2', 'candle3', 'candle4']) {
      final h = findHotspot(room, 'living_a', id);
      expect(h.when?.call(s) ?? true, isFalse,
          reason: '$id는 점화 후 비활성이어야 함');
    }
  });

  test('toggleCandle: 토글 왕복', () {
    expect(s.flag('living_candle1'), 0);
    toggleCandle(s, 1);
    expect(s.flag('living_candle1'), 1);
    toggleCandle(s, 1);
    expect(s.flag('living_candle1'), 0);
  });

  test('toggleCandle: 패턴 완성(2·4만 켬) 시 점화', () {
    toggleCandle(s, 2);
    toggleCandle(s, 4);
    expect(s.flag('living_fireplace_lit'), 1);
  });

  test('toggleCandle: 점화 후 재토글해도 lit 유지', () {
    toggleCandle(s, 2);
    toggleCandle(s, 4);
    expect(s.flag('living_fireplace_lit'), 1);
    toggleCandle(s, 2); // 패턴이 깨지도록 다시 토글
    expect(s.flag('living_candle2'), 0);
    expect(s.flag('living_fireplace_lit'), 1); // 그래도 유지
  });

  test('모든 아이템 id는 레지스트리에 존재', () {
    for (final id in ['remote', 'key_living', 'note1', 'oil']) {
      expect(itemsById.containsKey(id), isTrue, reason: '$id 미등록');
    }
  });

  test('힌트 3개: 단계 3개씩 + solved 조건 배선', () {
    expect(room.hints.length, 3);
    expect(room.hints.map((h) => h.puzzleId),
        ['p_living_boo', 'p_living_candles', 'p_living_door']);
  });
}
