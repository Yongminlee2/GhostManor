// 테스트 전용 라이브러리 (main() 없음) — 각 방의 정답 시퀀스를 다른 테스트가 재사용 (스펙 §8).
import 'package:flutter_test/flutter_test.dart';
import 'package:ghostmanor/core/dial_safe.dart';
import 'package:ghostmanor/core/game_state.dart';
import 'package:ghostmanor/core/models.dart';
import 'package:ghostmanor/rooms/items.dart';
import 'package:ghostmanor/rooms/room1_foyer.dart';
import 'package:ghostmanor/rooms/room2_living.dart';
import 'package:ghostmanor/core/switch_panel.dart';
import 'package:ghostmanor/rooms/room5_cellar.dart';
import 'package:ghostmanor/rooms/room6_attic.dart';
import 'package:ghostmanor/rooms/room7_hall.dart';
import 'package:ghostmanor/rooms/room10_lab.dart';

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

/// 현관 정답 시퀀스 (리마스터판, room1_foyer_test.dart의 "정답 시퀀스로 클리어
/// 가능"과 동일 절차). 스텝 수(tapSpot·순수함수 호출 1회=1스텝)를 반환 —
/// 하드코어 게이트가 ≥15를 단언한다. 다른 방 테스트가 "현관은 이미
/// 클리어됐다"는 전제로 재사용한다(반환값은 무시해도 컴파일·동작에 지장 없음).
int solveFoyer(GameState s, GameCtx c, Room room) {
  var steps = 0;
  void tap(String sceneId, String hotspotId) {
    tapSpot(room, s, c, sceneId, hotspotId);
    steps++;
  }

  void pure(void Function() fn) {
    fn();
    steps++;
  }

  // T1 빛 만들기: 외투 문지르기 → 성냥, 신발장 구두 → 양초, 조합 → 불 켠 초
  tap('foyer_b', 'coat');
  expect(s.closeupId, 'coat');
  pure(() => finishCoatRub(s));
  expect(s.has('match'), isTrue);
  s.closeCloseup();

  tap('foyer_b', 'shoe_cabinet');
  expect(s.closeupId, 'shoes');
  tap('shoes', 'shoe3_candle'); // 양초
  expect(s.has('candle'), isTrue);
  s.closeCloseup();

  pure(() => expect(tryCombine(s, 'candle', 'match'), isTrue));
  expect(s.has('lit_candle'), isTrue);

  // T2 시계 코드: 액자 문지르기(시계 4개 그림) + 우편함(편지, 지식 단서) →
  // 벽시계를 3시로
  tap('foyer_a', 'frame');
  expect(s.closeupId, 'frame');
  pure(() => finishFrameRub(s));
  expect(s.flag('foyer_r_dust_cleaned'), 1);
  s.closeCloseup();

  tap('foyer_c', 'mailbox');
  expect(s.closeupId, 'mailbox');
  tap('mailbox', 'letter_in_box');
  expect(s.has('letter1'), isTrue);
  expect(s.closeupId, 'letter1');
  s.closeCloseup();

  tap('foyer_b', 'clock');
  expect(s.closeupId, 'clock');
  s.closeCloseup();
  pure(() => tapClockHand(s)); // 1시
  pure(() => tapClockHand(s)); // 2시
  pure(() => tapClockHand(s)); // 3시
  expect(s.flag('foyer_r_clock_hour'), 3);
  expect(s.flag('foyer_r_drawer_unlocked'), 0); // 돌리기만으론 잠김
  pure(() => confirmClockTime(s)); // 중앙 축으로 3시 고정
  expect(s.flag('foyer_r_drawer_unlocked'), 1);

  // 교차: 서랍은 어두워 T1의 불 켠 초가 필요 → 열쇠
  tap('foyer_a', 'drawer');
  expect(s.closeupId, 'drawer');
  s.select('lit_candle');
  tap('drawer', 'drawer_dark');
  expect(s.flag('foyer_r_drawer_lit'), 1);
  tap('drawer', 'drawer_key');
  expect(s.has('key_foyer'), isTrue);
  s.closeCloseup();

  // 문: 열쇠 → 입장
  s.select('key_foyer');
  tap('foyer_a', 'inner_door');
  expect(s.flag('foyer_r_inner_door_open'), 1);
  expect(s.has('key_foyer'), isFalse); // 열쇠 소모
  tap('foyer_a', 'inner_door');

  return steps;
}

/// 거실 정답 시퀀스 (room2_living_test.dart의 해피패스와 동일 절차, 스텝
/// 카운팅 — solveFoyer와 동일 관례). 다른 방 테스트가 "거실은 이미
/// 클리어됐다"는 전제로 재사용한다(반환값은 무시해도 컴파일·동작에 지장 없음).
int solveLiving(GameState s, GameCtx c, Room room) {
  var steps = 0;
  void tap(String sceneId, String hotspotId) {
    tapSpot(room, s, c, sceneId, hotspotId);
    steps++;
  }

  void pure(void Function() fn) {
    fn();
    steps++;
  }

  // T3 부우·TV(단서 허브): 쿠션→리모컨→TV 켬(부우 소파로 이동)→클로즈업이
  // 탭마다 촛불 패턴(T2 단서) ↔ 나이 순서(T1 단서) 순환.
  tap('living_b', 'cushion');
  expect(s.has('remote'), isTrue);

  s.select('remote');
  tap('living_b', 'tv');
  expect(s.flag('living_r_tv_on'), 1);
  expect(s.has('remote'), isFalse); // 리모컨 소모

  tap('living_b', 'tv'); // 켜진 TV 클로즈업
  expect(s.closeupId, 'tv');
  tap('tv', 'tv_scene_toggle'); // 나이 순서 장면으로 전환
  expect(s.flag('living_r_tv_scene'), 1);
  s.closeCloseup();

  // T2 촛대→벽난로: 정답 배열(2·4만 켬) → 점화 → 비밀칸에서 다이얼 손잡이.
  pure(() => toggleCandle(s, 2));
  pure(() => toggleCandle(s, 4));
  expect(s.flag('living_r_fireplace_lit'), 1);

  tap('living_a', 'secret_nook');
  expect(s.has('knob'), isTrue);

  // T1 초상화 시선 금고: 소품 개수 관찰(램프3·괘종2·꽃병7·책4, 나이순 = 3274).
  tap('living_c', 'lamp');
  tap('living_c', 'pendulum');
  tap('living_c', 'vase');
  tap('living_c', 'books');

  // 손잡이 장착 → 다이얼 클로즈업 → 나이순 3274 입력 → 확인.
  s.select('knob');
  tap('living_c', 'safe');
  expect(s.flag('living_r_safe_knob'), 1);
  expect(s.has('knob'), isFalse); // 손잡이 소모

  tap('living_c', 'safe');
  expect(s.closeupId, 'safe');

  void dialTo(int wheel, int times) {
    for (var i = 0; i < times; i++) {
      pure(() => tapDialWheel(s, 'living_r_safe', wheel));
    }
  }

  dialTo(0, 3);
  dialTo(1, 2);
  dialTo(2, 7);
  dialTo(3, 4);
  expect(checkDialCode(s, 'living_r_safe', '3274'), isTrue);

  pure(() => openSafe(c));
  expect(s.flag('living_r_safe_open'), 1);
  expect(s.has('key_living'), isTrue);
  expect(s.has('oil'), isTrue);
  expect(s.has('note1'), isTrue);
  s.closeCloseup();

  // 문: 열쇠 → 입장.
  s.select('key_living');
  tap('living_b', 'door');
  expect(s.flag('living_r_door_open'), 1);
  expect(s.has('key_living'), isFalse); // 열쇠 소모

  tap('living_b', 'door');
  expect(s.flag('living_r_done'), 1);

  return steps;
}

/// 서재 정답 시퀀스 (room3_study_test.dart의 해피패스와 동일 절차, 스텝
/// 카운팅 — solveFoyer/solveLiving과 동일 관례). 전제: 방 2(거실)를 클리어해
/// 기름병(oil)을 이미 보유한 상태 — 이 함수는 oil을 지급하지 않는다. 방 단독
/// 테스트는 setUp에서 s.give('oil') 후 이 함수를 호출한다. 다른 방 테스트가
/// "서재는 이미 클리어됐다"는 전제로 재사용한다(반환값은 무시해도 무방).
int solveStudy(GameState s, GameCtx c, Room room) {
  var steps = 0;
  void tap(String sceneId, String hotspotId) {
    tapSpot(room, s, c, sceneId, hotspotId);
    steps++;
  }

  void pure(void Function() fn) {
    fn();
    steps++;
  }

  // T2 문양-색 변환: 종이 문지르기 → 문양 순서 단서(꽃→나무→새→뱀, 책등
  // 각인으로 대조하면 파→초→빨→노). 제스처 로직은 위젯 테스트가 별도로
  // 검증하므로(원샷 가드), 여기서는 room1의 finishRubbing과 동일하게 플래그만
  // 직접 설정.
  tap('study_b', 'paper');
  expect(s.closeupId, 'paper');
  s.closeCloseup();
  pure(() => s.setFlag('study_r_paper_rubbed', 1));

  // 책 4권을 파(2)→초(4)→빨(1)→노(3) 순서로 탭 → 숨은 공간 개방
  tap('study_a', 'book_blue');
  tap('study_a', 'book_green');
  tap('study_a', 'book_red');
  tap('study_a', 'book_yellow');
  expect(s.flag('study_r_nook_open'), 1);

  // 숨은 공간 → 놋쇠 렌즈 + ♪별 카드 (렌즈가 T1의 교차 잠금)
  tap('study_a', 'nook');
  expect(s.has('lens'), isTrue);
  expect(s.has('note2'), isTrue);

  // T1 별자리 관측: 렌즈를 망원경에 장착 → 별 관측(W자) → 지도 대조(여우자리·
  // 화살표 셋)
  s.select('lens');
  tap('study_c', 'telescope'); // 렌즈 장착
  expect(s.flag('study_r_telescope_lens'), 1);
  expect(s.has('lens'), isFalse); // 렌즈 소모(망원경에 고정)

  tap('study_c', 'telescope'); // 관측 클로즈업
  expect(s.closeupId, 'stars');
  s.closeCloseup();

  tap('study_c', 'starmap_frame'); // 지도 클로즈업
  expect(s.closeupId, 'starmap');
  s.closeCloseup();

  // 지구본 상단 화살표를 정확히 3번 탭 → 반쪽이 벌어지고 중앙 틈에 열쇠 노출
  tap('study_b', 'globe_arrow');
  tap('study_b', 'globe_arrow');
  tap('study_b', 'globe_arrow');
  expect(s.flag('study_r_globe_taps'), 3);

  tap('study_b', 'globe_gap'); // 틈에서 서재 열쇠
  expect(s.has('key_study'), isTrue);

  // 문: 열쇠(잠금 해제) + 기름(경첩) 둘 다 필요 → 탈출
  s.select('key_study');
  tap('study_b', 'door');
  expect(s.flag('study_r_door_unlocked'), 1);
  expect(s.has('key_study'), isFalse); // 열쇠 소모

  s.select('oil');
  tap('study_b', 'door');
  expect(s.flag('study_r_door_oiled'), 1);
  expect(s.has('oil'), isFalse); // 기름 소모

  tap('study_b', 'door');
  expect(s.flag('study_r_done'), 1);

  return steps;
}

/// 주방 정답 시퀀스 (room4_kitchen_test.dart의 해피패스와 동일 절차, 스텝
/// 카운팅 — solveFoyer/solveLiving/solveStudy와 동일 관례). 두 스레드가
/// 교차 잠금(T2 보상 마른 약초가 T1의 3번째 재료)이라 T2를 먼저 끝내야 T1을
/// 완주할 수 있다. 다른 방 테스트가 "주방은 이미 클리어됐다"는 전제로
/// 재사용한다(반환값은 무시해도 컴파일·동작에 지장 없음).
int solveKitchen(GameState s, GameCtx c, Room room) {
  var steps = 0;
  void tap(String sceneId, String hotspotId) {
    tapSpot(room, s, c, sceneId, hotspotId);
    steps++;
  }

  void pure(void Function() fn) {
    fn();
    steps++;
  }

  // T1 재료 수집 시작: 레시피판은 지식일 뿐 게이트가 아니지만(현관 편지와
  // 동일 원칙), 정공법 플레이어라면 당연히 먼저 닦아본다.
  tap('kitchen_c', 'recipe_board');
  expect(s.closeupId, 'recipe');
  s.closeCloseup();
  pure(() => s.setFlag('kitchen_r_recipe_rubbed', 1));

  tap('kitchen_a', 'counter'); // 빈 병
  expect(s.has('empty_bottle'), isTrue);

  s.select('empty_bottle');
  tap('kitchen_b', 'sink'); // 이끼물 병
  expect(s.has('water_bottle'), isTrue);
  expect(s.has('empty_bottle'), isFalse); // 빈 병 소모

  tap('kitchen_a', 'jar'); // 말린 버섯
  expect(s.has('mushroom'), isTrue);

  tap('kitchen_b', 'cupboard2'); // 속 빈 울림 발견
  expect(s.flag('kitchen_r_hollow_found'), 1);
  tap('kitchen_b', 'cupboard2'); // 노래하는 주전자
  expect(s.has('kettle_singing'), isTrue);

  // T2 빙실: 부지깽이 획득 → 화덕에 달굼 → 언 자물쇠 3단계 해동 → 마른 약초+♪해
  tap('kitchen_c', 'poker_rack');
  expect(s.has('poker'), isTrue);

  s.select('poker');
  tap('kitchen_a', 'stove_poker_slot');
  expect(s.has('poker_hot'), isTrue);
  expect(s.has('poker'), isFalse); // 부지깽이 소모(달굼)

  s.select('poker_hot');
  tap('kitchen_c', 'icebox'); // 1단계
  expect(s.flag('kitchen_r_ice_stage'), 1);
  tap('kitchen_c', 'icebox'); // 2단계
  expect(s.flag('kitchen_r_ice_stage'), 2);
  tap('kitchen_c', 'icebox'); // 3단계 — 완전히 녹음, poker_hot 소모
  expect(s.flag('kitchen_r_ice_stage'), 3);
  expect(s.has('poker_hot'), isFalse);

  tap('kitchen_c', 'icebox'); // 함 개방 → 마른 약초 + ♪해
  expect(s.has('herb'), isTrue);
  expect(s.has('note3'), isTrue);

  // T1 완성: 냄비 클로즈업을 한 번 열어보고(빈 상태 확인), 물→버섯→약초→
  // 주전자의 노래 순서로 투입
  tap('kitchen_a', 'pot');
  expect(s.closeupId, 'pot');
  s.closeCloseup();

  s.select('water_bottle');
  tap('kitchen_a', 'pot');
  expect(s.flag('kitchen_r_pot_stage'), 1);
  expect(s.has('water_bottle'), isFalse);

  s.select('mushroom');
  tap('kitchen_a', 'pot');
  expect(s.flag('kitchen_r_pot_stage'), 2);

  s.select('herb');
  tap('kitchen_a', 'pot');
  expect(s.flag('kitchen_r_pot_stage'), 3);

  s.select('kettle_singing');
  tap('kitchen_a', 'pot');
  expect(s.flag('kitchen_r_pot_stage'), 4);

  // 완성 수프 → 국자에게 → 뒷문 열쇠
  tap('kitchen_a', 'gukja');
  expect(s.flag('kitchen_r_ghost_fed'), 1);
  expect(s.has('key_kitchen'), isTrue);

  s.select('key_kitchen');
  tap('kitchen_b', 'backdoor'); // 잠금 해제
  expect(s.flag('kitchen_r_door_open'), 1);
  expect(s.has('key_kitchen'), isFalse); // 열쇠 소모

  tap('kitchen_b', 'backdoor'); // 탈출
  expect(s.flag('kitchen_r_done'), 1);

  return steps;
}

/// 지하실 정답 시퀀스 (room5_cellar_test.dart의 해피패스와 동일 절차, 스텝
/// 카운팅 — solveFoyer/solveLiving/solveStudy/solveKitchen과 동일 관례).
/// barrel/shelf/switches 클로즈업은 커스텀 위젯이라 헤드리스 테스트에선 위젯을
/// 펌프하지 않고 그 안에서 호출되는 순수 함수(moveBarrel/dropShelfKey/
/// flipSwitch)를 직접 호출한다 — 위젯 자체의 제스처/센서 배선은
/// room5_cellar_test.dart의 별도 위젯 테스트가 검증한다(스펙 §8 헤드리스
/// 테스트 원칙). T1(전력)과 T2(와인)이 서로의 중간 결과를 필요로 하므로
/// (퓨즈1→기본 점등→와인 라벨 판독→퓨즈2→스위치 조작) 이 함수 안에서 자연히
/// 교차 진행된다. 배전반 옆 야광 순서를 다시 확인하러 잠깐 소등했다 재점등하는
/// 대목이 어둠 왕복 최소 2회(설계 §요구)를 시퀀스 안에 실재시킨다. 다른 방
/// 테스트가 "지하실은 이미 클리어됐다"는 전제로 재사용한다(반환값은 무시해도
/// 컴파일·동작에 지장 없음).
int solveCellar(GameState s, GameCtx c, Room room) {
  var steps = 0;
  void tap(String sceneId, String hotspotId) {
    tapSpot(room, s, c, sceneId, hotspotId);
    steps++;
  }

  void pure(void Function() fn) {
    fn();
    steps++;
  }

  // T1 전반: 어둠 속에서 야광 상자 → 퓨즈1(만) → 배전반에 장착 → 기본 점등.
  tap('cellar_a', 'glow_box');
  expect(s.has('fuse'), isTrue);
  expect(s.has('note4'), isFalse); // 리마스터: 구름 카드는 이제 상자B 보상

  s.select('fuse');
  tap('cellar_b', 'fusebox');
  expect(s.flag('cellar_r_fuse_count'), 1);
  expect(s.has('fuse'), isFalse); // 퓨즈1 소모

  tap('cellar_b', 'light_switch'); // 소등→점등 1회차
  expect(s.flag('cellar_r_light'), 1);

  // T2: 점등 후 병 라벨 판독 → 어둠 낙서(5→1→3) 순서로 탭 → 상자B: 퓨즈2+♪구름.
  tap('cellar_c', 'wine3'); // 촛불 5개
  expect(s.flag('cellar_r_wine_seq'), 1);
  tap('cellar_c', 'wine2'); // 촛불 1개
  expect(s.flag('cellar_r_wine_seq'), 2);
  tap('cellar_c', 'wine5'); // 촛불 3개(리터치 후 라벨은 4·1·5·2·3으로 유일)
  expect(s.flag('cellar_r_wine_seq'), 3);
  expect(s.flag('cellar_r_wine_open'), 1);

  tap('cellar_c', 'boxb');
  expect(s.has('fuse2'), isTrue);
  expect(s.has('note4'), isTrue); // 다락 체인 카드는 여기서 지급

  // T1 후반: 퓨즈2까지 장착 → 스위치 클로즈업 진입 전, 순서를 다시 확인하러
  // 잠깐 소등했다 재점등(어둠 왕복 2회차 — cellar_r_light가 1→0→1로 실제
  // 변화함을 아래 expect들이 직접 단언한다).
  s.select('fuse2');
  tap('cellar_b', 'fusebox');
  expect(s.flag('cellar_r_fuse_count'), 2);
  expect(s.has('fuse2'), isFalse); // 퓨즈2 소모

  tap('cellar_b', 'light_switch'); // 점등→소등
  expect(s.flag('cellar_r_light'), 0);
  tap('cellar_b', 'light_switch'); // 소등→점등 2회차
  expect(s.flag('cellar_r_light'), 1);

  tap('cellar_b', 'fusebox'); // 2개 다 있으니 이번엔 SwitchPanel 클로즈업
  expect(s.closeupId, 'switches');

  pure(() => flipSwitch(s, 'cellar_r_switch', 0)); // △
  pure(() => flipSwitch(s, 'cellar_r_switch', 1)); // ○
  pure(() => flipSwitch(s, 'cellar_r_switch', 2)); // □
  expect(s.flag('cellar_r_power'), 1);
  s.closeCloseup();

  // 통 실이동(SceneObject) → 쪽문 노출: 드래그로 밀기(moveBarrel 반복 호출).
  tap('cellar_b', 'barrel');
  expect(s.closeupId, 'barrel');
  pure(() {
    for (var i = 0; i < 10; i++) {
      moveBarrel(s, 60); // (60/6).round() = 10 * 10회 = 100
    }
  });
  expect(s.flag('cellar_r_barrel_moved'), 1);
  s.closeCloseup();

  // 선반 클로즈업 → 흔들기(센서 경로의 순수 함수 dropShelfKey 직접 호출)
  tap('cellar_a', 'shelf');
  expect(s.closeupId, 'shelf');
  pure(() => dropShelfKey(s));
  expect(s.flag('cellar_r_key_dropped'), 1);
  s.closeCloseup();

  // 바닥에 떨어진 열쇠 줍기
  tap('cellar_a', 'key_floor');
  expect(s.has('key_cellar'), isTrue);

  // 쪽문: 열쇠로 잠금 해제 → 전력 복구까지 확인된 상태로 탈출.
  s.select('key_cellar');
  tap('cellar_b', 'small_door');
  expect(s.flag('cellar_r_door_open'), 1);
  expect(s.has('key_cellar'), isFalse); // 열쇠 소모

  tap('cellar_b', 'small_door');
  expect(s.flag('cellar_r_done'), 1);

  return steps;
}

/// 다락방 정답 시퀀스 (room6_attic_test.dart의 해피패스와 동일 절차, 스텝
/// 카운팅 — solveFoyer/solveLiving/solveStudy/solveKitchen/solveCellar와 동일
/// 관례). 전제: 방 2~5(거실·서재·주방·지하실)를 모두 클리어해 note1~4를 이미
/// 보유한 상태 — 이 함수는 카드를 지급하지 않는다. 방 단독 테스트는 setUp에서
/// note1~4를 지급한 뒤 이 함수를 호출한다. T2(궤짝, 342) → shred 획득 → T1
/// 자수 액자에 장착(교차 잠금 실증)까지 정공법 그대로 거친 뒤 연주한다 — 두
/// 단서(쪽지·자수)가 게이트가 아님은 room6_attic_test.dart의 별도 부정
/// 테스트가 증명한다. 다른 방 테스트가 "다락은 이미 클리어됐다"는 전제로
/// 재사용한다(반환값은 무시해도 컴파일·동작에 지장 없음).
int solveAttic(GameState s, GameCtx c, Room room) {
  var steps = 0;
  void tap(String sceneId, String hotspotId) {
    tapSpot(room, s, c, sceneId, hotspotId);
    steps++;
  }

  void pure(void Function() fn) {
    fn();
    steps++;
  }

  // 카드 4장을 보면대에 배치(순서 무관 — 보면대는 개수만 센다)
  for (final note in ['note1', 'note2', 'note3', 'note4']) {
    s.select(note);
    tap('attic_a', 'music_stand');
    expect(s.has(note), isFalse); // 카드 소모
  }
  expect(s.flag('attic_r_cards_placed'), 4);

  // 오르간 클로즈업 확인(카드 완비 후에야 열림)
  tap('attic_a', 'organ');
  expect(s.closeupId, 'organ');
  s.closeCloseup();

  // T2 착수: 쪽지(지식) 확인 → 궤짝 다이얼 342 입력 → shred 획득
  tap('attic_c', 'old_note');
  expect(s.closeupId, 'old_note');
  s.closeCloseup();

  tap('attic_c', 'chest');
  expect(s.closeupId, 'chest');

  void dialTo(int wheel, int times) {
    for (var i = 0; i < times; i++) {
      pure(() => tapDialWheel(s, 'attic_r_chest', wheel));
    }
  }

  dialTo(0, 3);
  dialTo(1, 4);
  dialTo(2, 2);
  expect(checkDialCode(s, 'attic_r_chest', '342'), isTrue);

  pure(() => openChest(c));
  expect(s.flag('attic_r_chest_open'), 1);
  expect(s.has('shred'), isTrue);
  s.closeCloseup();

  // T1 완성: 자수 클로즈업(찢긴 상태) 확인 → shred를 액자에 장착(교차 잠금)
  tap('attic_b', 'embroidery');
  expect(s.closeupId, 'embroidery');
  s.closeCloseup();

  s.select('shred');
  tap('attic_b', 'embroidery');
  expect(s.flag('attic_r_embroidery_full'), 1);
  expect(s.has('shred'), isFalse); // 조각 소모

  // 정답 순서로 연주: 도미레파 = 건반 1,3,2,4
  pure(() => tapOrganKey(s, 1));
  pure(() => tapOrganKey(s, 3));
  pure(() => tapOrganKey(s, 2));
  pure(() => tapOrganKey(s, 4));
  expect(s.flag('attic_r_organ_played'), 1);

  // 트렁크: 첫 탭은 유언장, 두 번째 탭에 탈출
  tap('attic_b', 'trunk');
  expect(s.flag('attic_r_got_will'), 1);
  expect(s.flag('attic_r_done'), 0);

  tap('attic_b', 'trunk');
  expect(s.flag('attic_r_done'), 1);

  return steps;
}

/// 계단홀·복도(챕터2 방7) 정답 시퀀스 (room7_hall_test.dart의 해피패스와 동일
/// 절차, 스텝 카운팅 — solveFoyer 등과 동일 관례). 이 함수는 rooms.dart에
/// 아직 등록되지 않은 room7을 buildHall()로 직접 받아 단독 검증한다(챕터2
/// 계획 Task 7이 rooms.dart 일괄 등록+앱 셸 진입 연결을 맡는다 — task-3-report
/// 참조). T1(초상 정렬)과 T2(카펫→마루판→태엽→시계→샹들리에)는 서로 독립
/// 스레드라 순서를 바꿔도 무방하지만, 여기서는 T1을 먼저 끝내 프레임이 열린
/// 상태에서 가족사진 앵커를 탭해 회상1이 재생되는 것까지 확인한다. rug
/// 클로즈업은 커스텀 RubbableScene이라 헤드리스 테스트에선 위젯을 펌프하지
/// 않고 onCleaned가 호출하는 순수 함수 finishRugRoll을 직접 호출한다(room5
/// solveCellar의 moveBarrel 직접 호출과 동일 원칙 — 위젯 자체의 드래그 배선은
/// room7_hall_test.dart의 별도 위젯 테스트가 검증).
int solveHall(GameState s, GameCtx c, Room room) {
  var steps = 0;
  void tap(String sceneId, String hotspotId) {
    tapSpot(room, s, c, sceneId, hotspotId);
    steps++;
  }

  void pure(void Function() fn) {
    fn();
    steps++;
  }

  // T1 초상 정렬: 2·4번째만 기울이면 즉시 정답(카펫 다이아 단서는 안 봐도 됨).
  tap('hall_a', 'portrait2');
  tap('hall_a', 'portrait4');
  expect(s.flag('f2_hall_frames'), 1);

  // 회상1: 프레임 완료 후 가족사진 앵커를 탭하면 재생.
  tap('hall_c', 'photo');
  expect(s.closeupId, 'memory');
  expect(s.flag('f2_hall_memory'), 1);
  s.closeCloseup();

  // T2 전반: 카펫 드래그로 걷기(순수 함수로 완료 시뮬레이션) → 마루판 4장
  // 두드리기(3 dull + 1 hollow, 두 번째 탭에서 winder 획득).
  tap('hall_c', 'rug');
  expect(s.closeupId, 'rug');
  pure(() => finishRugRoll(s));
  expect(s.flag('f2_hall_rug_rolled'), 1);
  s.closeCloseup();

  tap('hall_c', 'plank1'); // dull
  tap('hall_c', 'plank2'); // dull
  tap('hall_c', 'plank3'); // hollow 1차 발견
  expect(s.has('winder'), isFalse);
  tap('hall_c', 'plank3'); // hollow 2차 — winder 획득
  expect(s.has('winder'), isTrue);
  tap('hall_c', 'plank4'); // dull

  // T2 후반: 태엽손잡이 → 벽시계(종 3번 함의) → 살아난 시계 → 샹들리에 →
  // 열쇠 낙하 → 바닥에서 줍기.
  tap('hall_b', 'clock');
  expect(s.closeupId, 'clock');
  s.select('winder');
  tap('clock', 'winder_hole');
  expect(s.flag('f2_hall_clock_wound'), 1);
  expect(s.flag('f2_hall_b_alive'), 1);
  expect(s.has('winder'), isFalse); // winder 소모
  s.closeCloseup();

  tap('hall_b', 'chandelier');
  expect(s.flag('f2_hall_key_dropped'), 1);
  tap('hall_b', 'floor_key');
  expect(s.has('key_f2bed'), isTrue);

  // 문: 열쇠 + 액자 정렬 이중 게이트 → 개방 → 탈출(emblem_hall 지급).
  s.select('key_f2bed');
  tap('hall_a', 'door');
  expect(s.flag('f2_hall_door_open'), 1);
  expect(s.has('key_f2bed'), isFalse); // 열쇠 소모

  tap('hall_a', 'door');
  expect(s.flag('f2_hall_done'), 1);
  expect(s.has('emblem_hall'), isTrue);

  return steps;
}

/// 안방(챕터2 방8) 정답 시퀀스 (room8_bed_test.dart의 해피패스와 동일 절차,
/// 스텝 카운팅 — solveHall과 동일 관례). rooms.dart에 아직 등록되지 않은
/// room8을 buildBed()로 직접 받아 단독 검증한다(챕터2 계획 Task 7이 rooms.dart
/// 일괄 등록을 맡는다). T1(거울 차이 → 유령 물건 3개 → 보석함 3슬롯)과 T2
/// (자수 3색 순서)는 교차 잠금이다 — 보석함 완성 보상(은실)이 자수의 2번째
/// 실이라 T2를 끝내려면 T1을 먼저 마쳐야 한다. 문은 T1의 다른 보상
/// (key_f2child)으로 연다. wardrobe/jewelbox/frame 클로즈업은 커스텀 위젯
/// 없는 일반 Hotspot이라(RubbableScene류가 아님) 헤드리스 tap만으로 전 과정을
/// 그대로 재현한다. 다른 방 테스트가 "안방은 이미 클리어됐다"는 전제로
/// 재사용한다(반환값은 무시해도 컴파일·동작에 지장 없음).
int solveBed(GameState s, GameCtx c, Room room) {
  var steps = 0;
  void tap(String sceneId, String hotspotId) {
    tapSpot(room, s, c, sceneId, hotspotId);
    steps++;
  }

  // T1 거울 차이: 거울상을 실물과 대조(관찰만, 상태 불변) → 유령 물건 3개.
  tap('bed_b', 'mirror');
  expect(s.closeupId, 'mirror');
  s.closeCloseup();

  tap('bed_a', 'nightstand'); // 머리핀
  expect(s.has('hairpin'), isTrue);

  tap('bed_b', 'brooch'); // 브로치
  expect(s.has('brooch'), isTrue);

  tap('bed_c', 'wardrobe');
  expect(s.closeupId, 'wardrobe');
  tap('wardrobe', 'search'); // 1차 허탕
  tap('wardrobe', 'search'); // 2차 허탕
  tap('wardrobe', 'search'); // 3차 — 단추
  expect(s.has('button_gh'), isTrue);
  s.closeCloseup();

  // 보석함 3슬롯 투입(순서 무관) → 완성 시 은실 + key_f2child.
  s.select('hairpin');
  tap('bed_b', 'jewelbox');
  expect(s.has('hairpin'), isFalse); // 소모

  s.select('brooch');
  tap('bed_b', 'jewelbox');

  s.select('button_gh');
  tap('bed_b', 'jewelbox');
  expect(s.flag('f2_bed_jewelbox_open'), 1);
  expect(s.has('silver_thread'), isTrue);
  expect(s.has('key_f2child'), isTrue);

  // T2 자수 완성: 리본 서랍(지식, 게이트 아님) → 반짇고리에서 파랑 2타래 →
  // 파랑→은→파랑 순서로 자수틀에.
  tap('bed_c', 'ribbon_drawer');
  expect(s.closeupId, 'ribbons');
  s.closeCloseup();

  tap('bed_c', 'sewing_basket'); // 파랑 1
  tap('bed_c', 'sewing_basket'); // 파랑 2
  expect(s.has('thread_blue1'), isTrue);
  expect(s.has('thread_blue2'), isTrue);

  s.select('thread_blue1');
  tap('bed_c', 'embroidery');
  expect(s.flag('f2_bed_stitch_stage'), 1);

  s.select('silver_thread');
  tap('bed_c', 'embroidery');
  expect(s.flag('f2_bed_stitch_stage'), 2);

  s.select('thread_blue2');
  tap('bed_c', 'embroidery');
  expect(s.flag('f2_bed_stitch_done'), 1);

  // 회상2: 자수틀 재탭(앵커).
  tap('bed_c', 'embroidery');
  expect(s.closeupId, 'memory');
  expect(s.flag('f2_bed_memory'), 1);
  s.closeCloseup();

  // 문: key_f2child → 입장.
  s.select('key_f2child');
  tap('bed_a', 'door');
  expect(s.flag('f2_bed_door_open'), 1);
  expect(s.has('key_f2child'), isFalse); // 소모

  tap('bed_a', 'door');
  expect(s.flag('f2_bed_done'), 1);
  expect(s.has('emblem_bed'), isTrue);

  return steps;
}

/// 아이 방(챕터2 방9) 정답 시퀀스 (room9_child_test.dart의 해피패스와 동일
/// 절차, 스텝 카운팅 — solveHall/solveBed와 동일 관례). rooms.dart에 아직
/// 등록되지 않은 room9를 buildChild()로 직접 받아 단독 검증한다(챕터2 계획
/// Task 7이 rooms.dart 일괄 등록을 맡는다). T1(기차 스위치)과 T2(오르골)는
/// 초반부가 서로 독립이라 진입 직후 병렬로 만질 수 있지만, T2의 완성(오르골
/// 수리)은 T1의 보상 gear_toy 없이는 불가능하다(교차 잠금) — 그래서 T1을
/// 먼저 끝낸다. 스위치 0·2(양 끝)를 일부러 한 번씩 잘못 넘겼다가 되돌리는
/// 대목은 브리프의 "스위치는 유지(리셋 아님, 재조정 가능)"을 실제로
/// 시연한다(cellar solveCellar가 어둠 왕복을 시퀀스 안에 실재시키는 것과
/// 동일한 이유) — 그 사이 기차 출발을 한 번 실패시켜 SceneObject가 원위치
/// (트랙을 떠난 적이 없으므로 rect가 그대로 trainStartArea)임을 확인한다.
/// 문은 T2의 다른 보상 key_f2lab으로. 다른 방 테스트가 "아이 방은 이미
/// 클리어됐다"는 전제로 재사용한다(반환값은 무시해도 컴파일·동작에 지장 없음).
int solveChild(GameState s, GameCtx c, Room room) {
  var steps = 0;
  void tap(String sceneId, String hotspotId) {
    tapSpot(room, s, c, sceneId, hotspotId);
    steps++;
  }

  // T1 전반: 모빌(지식 단서, 게이트 아님 — 정공법 플레이어는 그래도 먼저
  // 확인한다, kitchen recipe_board와 동일 원칙) → 스위치 0·2를 일부러
  // 틀리게 넘긴 채 기차를 출발시켜 실패를 확인 → 0·2를 되돌리고 가운데(1)만
  // 오른쪽으로 → 재출발 성공.
  tap('child_a', 'mobile');

  tap('child_b', 'switch1'); // 인덱스0: 0→1 (오답)
  tap('child_b', 'switch3'); // 인덱스2: 0→1 (오답)
  tap('child_b', 'train_start'); // 실패 — [1,0,1] != [0,1,0]
  expect(s.flag('f2_child_train'), 0);

  tap('child_b', 'switch1'); // 인덱스0: 1→0 (원복)
  tap('child_b', 'switch2'); // 인덱스1: 0→1 (정답)
  tap('child_b', 'switch3'); // 인덱스2: 1→0 (원복)
  tap('child_b', 'train_start'); // 성공 — [0,1,0]
  expect(s.flag('f2_child_train'), 1);

  tap('child_b', 'drawer'); // 1차: 반짝임 발견
  expect(s.has('gear_toy'), isFalse);
  tap('child_b', 'drawer'); // 2차: 톱니 획득
  expect(s.has('gear_toy'), isTrue);

  // T2: 오르골 태엽 감기(고장난 멜로디) → 내부 클로즈업 → gear_toy 장착 →
  // 완주 + key_f2lab → 재탭으로 회상3 재생(오르골 앵커).
  tap('child_c', 'music_box');
  expect(s.flag('f2_child_organ_wound'), 1);
  tap('child_c', 'music_box');
  expect(s.closeupId, 'organ');

  s.select('gear_toy');
  tap('organ', 'fix');
  expect(s.flag('f2_child_organ_fixed'), 1);
  expect(s.has('gear_toy'), isFalse); // 톱니 소모
  expect(s.has('key_f2lab'), isTrue);
  s.closeCloseup();

  tap('child_c', 'music_box');
  expect(s.closeupId, 'memory');
  expect(s.flag('f2_child_memory'), 1);
  s.closeCloseup();

  // 문: key_f2lab → 입장(emblem_child 지급).
  s.select('key_f2lab');
  tap('child_a', 'door');
  expect(s.flag('f2_child_door_open'), 1);
  expect(s.has('key_f2lab'), isFalse); // 열쇠 소모

  tap('child_a', 'door');
  expect(s.flag('f2_child_done'), 1);
  expect(s.has('emblem_child'), isTrue);

  return steps;
}

/// 서고·작업실(챕터2 방10) 정답 시퀀스 (room10_lab_test.dart의 해피패스와
/// 동일 절차, 스텝 카운팅 — solveHall/solveBed/solveChild와 동일 관례).
/// rooms.dart에 아직 등록되지 않은 room10을 buildLab()로 직접 받아 단독
/// 검증한다(챕터2 계획 Task 7이 rooms.dart 일괄 등록을 맡는다). T1(축음기
/// 실린더 3개 → 관측 장치 다이얼 241)과 T2(약병 3개를 램프에 순서대로 →
/// 편지)는 초반부(실린더1 획득, 칠판/약병 접근)가 서로 독립이라 진입 직후
/// 병렬로 만질 수 있지만, 실린더2는 잠긴 서랍 속이고 그 열쇠고리는 T2 구역
/// (약병 선반 뒤)에 있어 T1을 완주하려면 T2 구역을 한 번은 들러야 한다(교차).
/// 관측 장치를 깨우면(f2_lab_b_awake) 칠판 rect가 금고로 뒤덮이므로(같은
/// rect를 board/safe가 상호 배타 when으로 공유), 칠판 정리는 반드시 장치를
/// 깨우기 전에 끝낸다 — 이 함수의 순서가 그 제약을 그대로 지킨다. phono/
/// board/device 클로즈업은 각각 헤드리스 tap(스핀들)과 순수 함수 직접 호출
/// (finishBoardClean, awakenDevice — room7 solveHall의 finishRugRoll/room2
/// solveLiving의 openSafe와 동일 원칙)로 처리한다. 문은 이 방이 스스로 만든
/// key_f2seal로 연다. 다른 방 테스트가 "서고는 이미 클리어됐다"는 전제로
/// 재사용한다(반환값은 무시해도 컴파일·동작에 지장 없음).
int solveLab(GameState s, GameCtx c, Room room) {
  var steps = 0;
  void tap(String sceneId, String hotspotId) {
    tapSpot(room, s, c, sceneId, hotspotId);
    steps++;
  }

  void pure(void Function() fn) {
    fn();
    steps++;
  }

  // T1 전반: 책장에서 실린더1 → 약병 선반 뒤 열쇠고리(T2 구역 경유) → 서랍
  // 개방해 실린더2 → 축음기 스핀들에 꽂혀 있던 실린더3 꺼내기 → 실린더 셋을
  // 차례로 얹어 재생(청각 공정 — 종·물방울·새 소리, 사운드 재생 여부는
  // AudioService(enabled:false)라 검증하지 않는다).
  tap('lab_a', 'bookshelf');
  expect(s.has('cylinder1'), isTrue);

  tap('lab_c', 'keyring');
  expect(s.has('keyring'), isTrue);

  s.select('keyring');
  tap('lab_a', 'drawer');
  expect(s.has('cylinder2'), isTrue);
  expect(s.has('keyring'), isFalse); // 열쇠고리 소모

  tap('lab_a', 'phono');
  expect(s.closeupId, 'phono');

  tap('phono', 'spindle'); // 꽂혀 있던 실린더3 꺼내기
  expect(s.has('cylinder3'), isTrue);

  s.select('cylinder1');
  tap('phono', 'spindle');
  s.select('cylinder2');
  tap('phono', 'spindle');
  s.select('cylinder3');
  tap('phono', 'spindle');
  s.closeCloseup();

  // T2 전반: 칠판을 닦아 배합 그림 확인(장치를 깨우기 전에 반드시 끝내야
  // rect가 금고로 바뀌기 전에 접근 가능) → 약병 3개 수집 → 보라→초록→호박
  // 순서로 램프에 투입 → 램프 점등 → 편지 잉크 드러남(재탭으로 회상4).
  tap('lab_b', 'board');
  expect(s.closeupId, 'board');
  pure(() => finishBoardClean(s));
  expect(s.flag('f2_lab_board_clean'), 1);
  s.closeCloseup();

  tap('lab_c', 'vial_purple');
  tap('lab_c', 'vial_green');
  tap('lab_c', 'vial_amber');
  expect(s.has('vial_purple'), isTrue);
  expect(s.has('vial_green'), isTrue);
  expect(s.has('vial_amber'), isTrue);

  s.select('vial_purple');
  tap('lab_c', 'lamp');
  expect(s.flag('f2_lab_lamp_stage'), 1);

  s.select('vial_green');
  tap('lab_c', 'lamp');
  expect(s.flag('f2_lab_lamp_stage'), 2);

  s.select('vial_amber');
  tap('lab_c', 'lamp');
  expect(s.flag('f2_lab_c_lamp'), 1);

  tap('lab_c', 'letter'); // 잉크 드러남 + 편지 전문
  expect(s.flag('f2_lab_letter_ink'), 1);

  tap('lab_c', 'letter'); // 재탭 → 회상4(앵커)
  expect(s.closeupId, 'memory');
  expect(s.flag('f2_lab_memory'), 1);
  s.closeCloseup();

  // T1 후반: 관측 장치 다이얼을 241로 맞춰 확인 → 장치 기동 → 벽 금고 노출
  // → 금고에서 key_f2seal.
  tap('lab_b', 'device');
  expect(s.closeupId, 'device');

  void dialTo(int wheel, int times) {
    for (var i = 0; i < times; i++) {
      pure(() => tapDialWheel(s, 'f2_lab_dial', wheel));
    }
  }

  dialTo(0, 2);
  dialTo(1, 4);
  dialTo(2, 1);
  expect(checkDialCode(s, 'f2_lab_dial', '241'), isTrue);

  pure(() => awakenDevice(c));
  expect(s.flag('f2_lab_b_awake'), 1);
  s.closeCloseup();

  tap('lab_b', 'safe');
  expect(s.has('key_f2seal'), isTrue);

  // 문: 이 방이 스스로 만든 key_f2seal → 입장(emblem_lab 지급).
  s.select('key_f2seal');
  tap('lab_a', 'door');
  expect(s.flag('f2_lab_door_open'), 1);
  expect(s.has('key_f2seal'), isFalse); // 열쇠 소모

  tap('lab_a', 'door');
  expect(s.flag('f2_lab_done'), 1);
  expect(s.has('emblem_lab'), isTrue);

  return steps;
}

/// 봉인의 방(챕터2 방11, 마지막 콘텐츠 방) 정답 시퀀스 (room11_seal_test.dart의
/// 해피패스와 동일 절차, 스텝 카운팅 — solveHall~solveLab과 동일 관례).
/// rooms.dart에 이미 등록된 room11을 그대로 받는다(챕터2 계획 Task 7이
/// rooms.dart 일괄 등록도 함께 맡았다 — 이 방은 방7~10과 달리 buildAllRooms()
/// 경유 통합 테스트가 곧 이 방의 유일한 "전제 충족" 검증이기도 하다). T1
/// (촛불 고리)과 T2(제단)는 완전히 독립 스레드다 — 교차 잠금이 전혀 없다
/// (계획 Self-Review: "회상5는 지식일 뿐 게이트 아님"). 전제: emblem_hall/
/// bed/child/lab 4종을 이미 보유한 상태 — 이 함수는 상징을 지급하지 않는다
/// (solveStudy가 oil을 지급하지 않는 것과 동일 관례). 방 단독 테스트는
/// setUp에서 4종을 지급한 뒤 이 함수를 호출한다. farewell 클로즈업은
/// MemoryPlayer 커스텀 위젯이라 헤드리스 테스트에선 위젯을 펌프하지 않고
/// onDone이 하는 일(ending 클로즈업 열기)을 직접 재현한다(room10 solveLab의
/// RubbableScene/DialSafe 우회와 동일 원칙 — 위젯 자체의 탭-전진은
/// room11_seal_test.dart의 별도 위젯 테스트가 검증). 다른 방이 없으므로
/// "다음 방 열쇠"는 만들지 않는다 — 대신 f2_seal_done이 챕터 전체의 마지막
/// cleared 플래그다.
int solveSeal(GameState s, GameCtx c, Room room) {
  var steps = 0;
  void tap(String sceneId, String hotspotId) {
    tapSpot(room, s, c, sceneId, hotspotId);
    steps++;
  }

  void pure(void Function() fn) {
    fn();
    steps++;
  }

  // T1 촛불 고리: 켜진 초 4개를 전부 꺼서 벽화를 깨운다 → 회상5(가운데
  // 다섯째 초는 처음부터 꺼져 있어 손대지 않는다).
  tap('seal_c', 'candle0');
  tap('seal_c', 'candle1');
  tap('seal_c', 'candle2');
  tap('seal_c', 'candle3'); // 네 번째 — 벽화가 깨어난다
  expect(s.flag('f2_seal_b_awake'), 1);

  tap('seal_b', 'mural_family');
  expect(s.closeupId, 'memory');
  expect(s.flag('f2_seal_memory'), 1);
  s.closeCloseup();

  // T2 제단: emblem 4종을 hall→bed→child→lab 순서로 배치(회상 촛불 수
  // 오름차순과 대응 — 회상5를 안 봐도 순서만 맞으면 통과한다, 부정 테스트로
  // 별도 확인).
  tap('seal_a', 'altar');
  expect(s.closeupId, 'altar');

  s.select('emblem_hall');
  tap('altar', 'grooves');
  expect(s.flag('f2_seal_altar_seq'), 1);

  s.select('emblem_bed');
  tap('altar', 'grooves');
  expect(s.flag('f2_seal_altar_seq'), 2);

  s.select('emblem_child');
  tap('altar', 'grooves');
  expect(s.flag('f2_seal_altar_seq'), 3);

  s.select('emblem_lab');
  tap('altar', 'grooves');
  expect(s.flag('f2_seal_altar_full'), 1);
  expect(s.has('emblem_hall'), isFalse); // 완성 시에만 4개 한꺼번에 소모
  s.closeCloseup();

  // 매듭 3개를 위→아래 순서로 문질러 봉인 해제.
  tap('seal_a', 'knot_top');
  tap('seal_a', 'knot_mid');
  tap('seal_a', 'knot_bottom');
  expect(s.flag('f2_seal_a_open'), 1);

  // 에드가 등장 → 대화 5줄(탭마다 다음 줄, 마지막은 계획 원문 고정 대사) →
  // 유령 작별(farewell, MemoryPlayer 우회) → 아침 컷(ending) → 클리어.
  tap('seal_a', 'edgar'); // 1
  tap('seal_a', 'edgar'); // 2
  tap('seal_a', 'edgar'); // 3
  tap('seal_a', 'edgar'); // 4
  tap('seal_a', 'edgar'); // 5(고정 대사)
  expect(s.flag('f2_seal_edgar_lines'), 5);

  tap('seal_a', 'edgar'); // farewell 클로즈업 열기
  expect(s.closeupId, 'farewell');
  pure(() => s.openCloseup('ending')); // farewell onDone 재현

  tap('ending', 'continue');
  expect(s.flag('f2_seal_done'), 1);

  return steps;
}
