// 테스트 전용 라이브러리 (main() 없음) — 각 방의 정답 시퀀스를 다른 테스트가 재사용 (스펙 §8).
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/rooms/items.dart';
import 'package:ghostmanor/rooms/room1_foyer.dart';
import 'package:ghostmanor/rooms/room2_living.dart';
import 'package:ghostmanor/rooms/room5_cellar.dart';
import 'package:ghostmanor/rooms/room6_attic.dart';

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

/// 거실 정답 시퀀스 (room2_living_test.dart의 해피패스와 동일 절차).
/// 다른 방 테스트가 "거실은 이미 클리어됐다"는 전제로 재사용한다.
void solveLiving(GameState s, GameCtx c, Room room) {
  tapSpot(room, s, c, 'living_b', 'cushion'); // 리모컨
  expect(s.has('remote'), isTrue);

  s.select('remote');
  tapSpot(room, s, c, 'living_b', 'tv'); // 리모컨으로 TV 켬 → 부우 비킴
  expect(s.flag('living_tv_on'), 1);
  expect(s.has('remote'), isFalse); // 리모컨 소모

  tapSpot(room, s, c, 'living_b', 'tv'); // 켜진 TV 클로즈업 → 촛대 단서
  expect(s.closeupId, 'tv');
  s.closeCloseup();

  toggleCandle(s, 2);
  toggleCandle(s, 4);
  expect(s.flag('living_fireplace_lit'), 1);

  tapSpot(room, s, c, 'living_a', 'secret_nook');
  expect(s.has('key_living'), isTrue);
  expect(s.has('note1'), isTrue);
  expect(s.has('oil'), isTrue);

  s.select('key_living');
  tapSpot(room, s, c, 'living_b', 'door');
  expect(s.flag('living_door_open'), 1);
  expect(s.has('key_living'), isFalse); // 열쇠 소모

  tapSpot(room, s, c, 'living_b', 'door');
  expect(s.flag('living_done'), 1);
}

/// 서재 정답 시퀀스 (room3_study_test.dart의 해피패스와 동일 절차).
/// 전제: 방 2(거실)를 클리어해 기름병(oil)을 이미 보유한 상태 — 이 함수는 oil을
/// 지급하지 않는다. 방 단독 테스트는 setUp에서 s.give('oil') 후 이 함수를 호출한다.
void solveStudy(GameState s, GameCtx c, Room room) {
  // 종이 문지르기 → 색 순서 단서(파→초→빨→노). 제스처 로직은 위젯 테스트가 별도로
  // 검증하므로(원샷 가드), 여기서는 room1의 finishRubbing과 동일하게 플래그만 직접 설정.
  tapSpot(room, s, c, 'study_b', 'paper');
  expect(s.closeupId, 'paper');
  s.closeCloseup();
  s.setFlag('study_paper_rubbed', 1);

  // 책 4권을 파(2)→초(4)→빨(1)→노(3) 순서로 탭 → 숨은 공간 개방
  tapSpot(room, s, c, 'study_a', 'book_blue');
  tapSpot(room, s, c, 'study_a', 'book_green');
  tapSpot(room, s, c, 'study_a', 'book_red');
  tapSpot(room, s, c, 'study_a', 'book_yellow');
  expect(s.flag('study_nook_open'), 1);

  // 숨은 공간 → 크랭크 + ♪별 카드
  tapSpot(room, s, c, 'study_a', 'nook');
  expect(s.has('crank'), isTrue);
  expect(s.has('note2'), isTrue);

  // 크랭크로 지구본 개방 → 서재 열쇠
  s.select('crank');
  tapSpot(room, s, c, 'study_b', 'globe');
  expect(s.flag('study_globe_open'), 1);
  expect(s.has('crank'), isFalse); // 크랭크 소모

  tapSpot(room, s, c, 'study_b', 'globe');
  expect(s.has('key_study'), isTrue);

  // 문: 열쇠(잠금 해제) + 기름(경첩) 둘 다 필요 → 탈출
  s.select('key_study');
  tapSpot(room, s, c, 'study_b', 'door');
  expect(s.flag('study_door_unlocked'), 1);
  expect(s.has('key_study'), isFalse); // 열쇠 소모

  s.select('oil');
  tapSpot(room, s, c, 'study_b', 'door');
  expect(s.flag('study_door_oiled'), 1);
  expect(s.has('oil'), isFalse); // 기름 소모

  tapSpot(room, s, c, 'study_b', 'door');
  expect(s.flag('study_done'), 1);
}

/// 주방 정답 시퀀스 (room4_kitchen_test.dart의 해피패스와 동일 절차).
/// 이 방은 클로즈업이 전혀 없다(전부 벽 핫스팟+오버레이) — 그래서 다른 solve* 함수와
/// 달리 구체 closeupId 단언이 없다.
void solveKitchen(GameState s, GameCtx c, Room room) {
  tapSpot(room, s, c, 'kitchen_a', 'counter'); // 빈 병
  expect(s.has('empty_bottle'), isTrue);

  s.select('empty_bottle');
  tapSpot(room, s, c, 'kitchen_b', 'sink'); // 싱크대 물 채움 → 이끼물 병
  expect(s.has('water_bottle'), isTrue);
  expect(s.has('empty_bottle'), isFalse); // 빈 병 소모(직접 교환, 조합 아님)

  tapSpot(room, s, c, 'kitchen_a', 'jar'); // 말린 버섯
  expect(s.has('mushroom'), isTrue);

  // 찬장 문 두드리기: 2번째 문의 첫 탭이 곧 발견 판정 → 재탭에서 주전자 획득
  tapSpot(room, s, c, 'kitchen_b', 'cupboard2'); // 속 빈 울림 발견
  expect(s.flag('kitchen_hollow_found'), 1);
  tapSpot(room, s, c, 'kitchen_b', 'cupboard2'); // 노래하는 주전자
  expect(s.has('kettle_singing'), isTrue);

  // 다단계 조합: 버섯+이끼물 병 = 수프 베이스, 수프 베이스+주전자 = 유령 수프
  expect(tryCombine(s, 'mushroom', 'water_bottle'), isTrue);
  expect(s.has('soup_base'), isTrue);
  expect(tryCombine(s, 'kettle_singing', 'soup_base'), isTrue);
  expect(s.has('ghost_soup'), isTrue);

  s.select('ghost_soup');
  tapSpot(room, s, c, 'kitchen_a', 'gukja'); // 국자에게 수프를 먹임
  expect(s.flag('kitchen_ghost_fed'), 1);
  expect(s.has('key_kitchen'), isTrue);
  expect(s.has('note3'), isTrue);
  expect(s.has('ghost_soup'), isFalse); // 수프 소모

  s.select('key_kitchen');
  tapSpot(room, s, c, 'kitchen_b', 'backdoor'); // 잠금 해제
  expect(s.flag('kitchen_door_open'), 1);
  expect(s.has('key_kitchen'), isFalse); // 열쇠 소모

  tapSpot(room, s, c, 'kitchen_b', 'backdoor'); // 탈출
  expect(s.flag('kitchen_done'), 1);
}

/// 지하실 정답 시퀀스 (room5_cellar_test.dart의 해피패스와 동일 절차).
/// barrel/shelf 클로즈업은 커스텀 위젯(BarrelDrag/ShelfShake)이라 헤드리스 테스트에선
/// 위젯을 펌프하지 않고 그 안에서 호출되는 순수 함수(moveBarrel/dropShelfKey)를 직접
/// 호출한다 — 위젯 자체의 제스처/센서 배선은 room5_cellar_test.dart의 별도 위젯
/// 테스트가 검증한다(스펙 §8 헤드리스 테스트 원칙).
void solveCellar(GameState s, GameCtx c, Room room) {
  // 어둠 속에서 야광 상자 → 퓨즈 + 구름 음표 카드
  tapSpot(room, s, c, 'cellar_a', 'glow_box');
  expect(s.has('fuse'), isTrue);
  expect(s.has('note4'), isTrue);

  // 퓨즈를 배전반에 끼우고 스위치로 점등
  s.select('fuse');
  tapSpot(room, s, c, 'cellar_b', 'fusebox');
  expect(s.flag('cellar_fuse_installed'), 1);
  expect(s.has('fuse'), isFalse); // 퓨즈 소모

  tapSpot(room, s, c, 'cellar_b', 'light_switch');
  expect(s.flag('cellar_light'), 1);

  // 와인통 클로즈업 → 드래그로 밀기(moveBarrel 반복 호출)
  tapSpot(room, s, c, 'cellar_b', 'barrel');
  expect(s.closeupId, 'barrel');
  for (var i = 0; i < 10; i++) {
    moveBarrel(s, 60); // (60/6).round() = 10 * 10회 = 100
  }
  expect(s.flag('cellar_barrel_moved'), 1);
  s.closeCloseup();

  // 선반 클로즈업 → 흔들기(센서 경로의 순수 함수 dropShelfKey 직접 호출)
  tapSpot(room, s, c, 'cellar_a', 'shelf');
  expect(s.closeupId, 'shelf');
  dropShelfKey(s);
  expect(s.flag('cellar_key_dropped'), 1);
  s.closeCloseup();

  // 바닥에 떨어진 열쇠 줍기
  tapSpot(room, s, c, 'cellar_a', 'key_floor');
  expect(s.has('key_cellar'), isTrue);

  // 쪽문: 열쇠로 열기 → 탈출
  s.select('key_cellar');
  tapSpot(room, s, c, 'cellar_b', 'small_door');
  expect(s.flag('cellar_door_open'), 1);
  expect(s.has('key_cellar'), isFalse); // 열쇠 소모

  tapSpot(room, s, c, 'cellar_b', 'small_door');
  expect(s.flag('cellar_done'), 1);
}

/// 다락방 정답 시퀀스 (room6_attic_test.dart의 해피패스와 동일 절차).
/// 전제: 방 2~5(거실·서재·주방·지하실)를 모두 클리어해 note1~4를 이미 보유한
/// 상태 — 이 함수는 카드를 지급하지 않는다. 방 단독 테스트는 setUp에서
/// note1~4를 지급한 뒤 이 함수를 호출한다.
void solveAttic(GameState s, GameCtx c, Room room) {
  // 카드 4장을 보면대에 배치(순서 무관 — 보면대는 개수만 센다)
  for (final note in ['note1', 'note2', 'note3', 'note4']) {
    s.select(note);
    tapSpot(room, s, c, 'attic_a', 'music_stand');
    expect(s.has(note), isFalse); // 카드 소모
  }
  expect(s.flag('attic_cards_placed'), 4);

  // 자수 클로즈업(관찰 전용) 확인
  tapSpot(room, s, c, 'attic_b', 'embroidery');
  expect(s.closeupId, 'embroidery');
  s.closeCloseup();

  // 오르간 클로즈업 확인
  tapSpot(room, s, c, 'attic_a', 'organ');
  expect(s.closeupId, 'organ');
  s.closeCloseup();

  // 정답 순서로 연주: 도미레파 = 건반 1,3,2,4
  tapOrganKey(s, 1);
  tapOrganKey(s, 3);
  tapOrganKey(s, 2);
  tapOrganKey(s, 4);
  expect(s.flag('attic_organ_played'), 1);

  // 트렁크: 첫 탭은 유언장, 두 번째 탭에 탈출
  tapSpot(room, s, c, 'attic_b', 'trunk');
  expect(s.flag('attic_got_will'), 1);
  expect(s.flag('attic_done'), 0);

  tapSpot(room, s, c, 'attic_b', 'trunk');
  expect(s.flag('attic_done'), 1);
}
