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
