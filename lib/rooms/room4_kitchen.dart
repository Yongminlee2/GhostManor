import 'package:flutter/widgets.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/rub_scene.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──
// 리마스터: 전 플래그 kitchen_r_ 접두어 (구세이브의 kitchen_* 와 충돌 차단).
//
// 스레드 구조(브리프): T1 유령 수프(월드 냄비 슬롯, 화덕 위 — 물→버섯→약초→
// 주전자의 노래 순서로 재료 투입, 설계 §4-2) ‖ T2 빙실(부지깽이 획득→화덕에
// 달굼→언 자물쇠에 사용→3단계 해동) → 교차: T2 보상(마른 약초)이 T1의 3번째
// 재료. 완성 수프는 국자에게 → 뒷문 열쇠(음표 카드는 이제 빙실에서 나온다 —
// 국자는 열쇠만 준다).
//
// art/remaster-assets.md 확인 사항: kitchen_pot1~5/kitchen_pot_wrong.png는
// "클로즈업 전체"(1024×1024)로만 배치된다 — 즉 냄비 상태 그림은 냄비
// 클로즈업에서만 보이고, kitchen_a.png 벽면 자체는 수정하지 않는다(화덕
// 오버레이 없음). kitchen_c_ice1~3.png는 반대로 "오버레이(빙실 함 크기)"로
// 벽 C에 직접 배치된다.

const _potOrder = ['water_bottle', 'mushroom', 'herb', 'kettle_singing'];

/// 냄비에 재료 하나 투입(월드 조합 슬롯). 다음 순서(물→버섯→약초→노래하는
/// 주전자)와 일치하는 item이면 kitchen_r_pot_stage +1(true 반환). 순서가 틀린
/// 재료(넷 중 다른 것)면 0으로 리셋 + kitchen_r_pot_wrong=1(false 반환).
/// 무관한 아이템/미선택/이미 완성(stage 4)이면 아무 것도 진행하지 않되
/// wrong 플래그는 항상 이번 호출 결과로 다시 씀 — "1프레임"만 반짝이고 다음
/// 상호작용에서 지워지게 한다(타이머 없이, 스펙 §4-3).
bool usePotIngredient(GameState s, String? item) {
  final stage = s.flag('kitchen_r_pot_stage');
  if (stage < _potOrder.length && item == _potOrder[stage]) {
    s.setFlag('kitchen_r_pot_stage', stage + 1);
    s.setFlag('kitchen_r_pot_wrong', 0);
    return true;
  }
  final wrongIngredient =
      stage < _potOrder.length && item != null && _potOrder.contains(item);
  if (wrongIngredient) s.setFlag('kitchen_r_pot_stage', 0);
  s.setFlag('kitchen_r_pot_wrong', wrongIngredient ? 1 : 0);
  return false;
}

/// 빙실 자물쇠에 달군 부지깽이(poker_hot) 사용. 0→1→2→3 세 단계 모두 같은
/// poker_hot 하나를 계속 대고 있는 셈이라 매 탭 소모하지 않는다 — 소모는
/// 핫스팟이 3단계(완전히 녹음) 도달 순간에만 처리한다. 이미 3단계거나 다른
/// 아이템/미선택이면 no-op(false).
bool meltIce(GameState s, String? item) {
  final stage = s.flag('kitchen_r_ice_stage');
  if (stage >= 3 || item != 'poker_hot') return false;
  s.setFlag('kitchen_r_ice_stage', stage + 1);
  return true;
}

String _potStageSay(int stage) => switch (stage) {
      1 => strKitchenRPotWater,
      2 => strKitchenRPotMushroom,
      3 => strKitchenRPotHerb,
      _ => strKitchenRPotDone,
    };

// ── 방 정의 ──

Room buildKitchen() {
  Cond flagSet(String k) => (s) => s.flag(k) >= 1;

  const counterArea = Rect.fromLTWH(0.04, 0.48, 0.18, 0.18);
  const jarArea = Rect.fromLTWH(0.05, 0.12, 0.16, 0.14);
  const gukjaArea = Rect.fromLTWH(0.68, 0.34, 0.22, 0.36);
  // 화덕: 기존 rect(0.20,0.42,0.28,0.30)에서 폭만 0.28→0.24로 다듬었다 — 원래
  // 폭 그대로면 화덕 중심(x=0.34)이 브리프가 못박은 potArea의 왼쪽 경계와
  // 정확히 겹쳐(둘 다 0.34) 프레시 상태 히트테스트가 부동소수 반올림에 좌우되는
  // 위태로운 경계가 된다. potArea는 손댈 수 없는 값이라 화덕 쪽을 살짝
  // 줄여 중심을 0.34 왼쪽으로 확실히 밀어냈다(hotspot_resolution_test 통과,
  // 실제 화덕 그림 kitchen_a.png는 무수정이라 육안 정렬은 아트 검수 때 확인).
  const stoveArea = Rect.fromLTWH(0.20, 0.42, 0.24, 0.30);
  const potArea = Rect.fromLTWH(0.34, 0.42, 0.26, 0.22); // 브리프 binding 좌표
  // 부지깽이 거치(신규) — 화덕 하단 띠. stove/pot 어느 쪽 중심과도 안 겹치는
  // 자리로 골랐다(위 stove 주석과 동일한 이유).
  const stovePokerSlotArea = Rect.fromLTWH(0.20, 0.64, 0.24, 0.08);

  const sinkArea = Rect.fromLTWH(0.06, 0.52, 0.20, 0.18);
  const cupboard1Area = Rect.fromLTWH(0.34, 0.28, 0.10, 0.14);
  const cupboard2Area = Rect.fromLTWH(0.46, 0.28, 0.10, 0.14);
  const cupboard3Area = Rect.fromLTWH(0.58, 0.28, 0.10, 0.14);
  const cupboard4Area = Rect.fromLTWH(0.70, 0.28, 0.10, 0.14);
  const backdoorArea = Rect.fromLTWH(0.62, 0.52, 0.26, 0.40);

  // 벽 C(신규 저장실): 빙실 함·레시피판·부지깽이 걸이는 브리프 binding 좌표,
  // 소시지·항아리 3개는 리액션 전용이라 서로 겹치지 않는 빈 자리에 배치.
  // 벽 C — kitchen_c.png 실측: 빙실 함은 좌측 대형, 레시피판 중앙, 걸이 우측.
  // ice1~3은 리터치 2차에서 함 문 영역 크롭(가장자리 페더 알파)으로 재제작 —
  // 오버레이 rect는 크롭 창과 정확히 일치해야 픽셀이 이어진다.
  const iceArea = Rect.fromLTWH(0.04, 0.32, 0.37, 0.42);
  const iceCropArea = Rect.fromLTWH(0.040, 0.320, 0.420, 0.440);
  const recipeArea = Rect.fromLTWH(0.47, 0.30, 0.28, 0.22);
  const pokerRackArea = Rect.fromLTWH(0.76, 0.20, 0.17, 0.35);
  const sausagesArea = Rect.fromLTWH(0.36, 0.13, 0.40, 0.17);
  const jarPicklesArea = Rect.fromLTWH(0.45, 0.56, 0.20, 0.14);
  const jarFlourArea = Rect.fromLTWH(0.66, 0.56, 0.22, 0.14);

  // 속이 꽉 찬 찬장 문(1·3·4) 공용: 둔탁한 노크음+대사만 반복(스펙 §3.3-6 —
  // 소리로 구분되는 단서는 대사로도 묘사해 음소거 유저도 구분 가능해야 함).
  void knockDull(GameCtx c) {
    c.sfx('wood_knock_dull');
    c.say(strKitchenKnockDull);
  }

  void tapPot(GameCtx c) {
    final s = c.s;
    final stage = s.flag('kitchen_r_pot_stage');
    final item = s.selectedItem;
    final matched = usePotIngredient(s, item);
    if (matched) {
      final consumed = _potOrder[stage];
      c.consume(consumed);
      c.sfx(consumed == 'water_bottle' ? 'liquid_pour' : 'pot_stir');
      c.say(_potStageSay(stage + 1));
    } else if (stage < _potOrder.length &&
        item != null &&
        _potOrder.contains(item)) {
      c.sfx('locked');
      // 오답 프레임이 보이도록 클로즈업을 연다 — 여기서 안 열면
      // kitchen_pot_wrong 오버레이는 어떤 경로로도 화면에 못 나온다.
      c.openCloseup('pot');
      c.say(strKitchenRPotWrong);
    } else {
      c.openCloseup('pot');
    }
  }

  void tapIcebox(GameCtx c) {
    final s = c.s;
    final stage = s.flag('kitchen_r_ice_stage');
    if (stage >= 3) {
      if (s.flag('kitchen_r_ice_looted') == 0) {
        s.setFlag('kitchen_r_ice_looted', 1);
        c.give('herb');
        c.give('note3');
        c.sfx('sparkle');
        c.say(strKitchenRIceLoot);
      } else {
        c.say(strKitchenRIceEmpty);
      }
    } else if (meltIce(s, s.selectedItem)) {
      final now = s.flag('kitchen_r_ice_stage');
      c.sfx('liquid_pour');
      if (now >= 3) {
        c.consume('poker_hot');
        c.say(strKitchenRIceMelted);
      } else {
        c.say(now == 1 ? strKitchenRIceCrack1 : strKitchenRIceCrack2);
      }
    } else if (s.selectedItem == 'poker') {
      c.say(strKitchenRIceColdPoker);
    } else {
      c.say(strKitchenRIceFrozen);
    }
  }

  return Room(
    id: 'kitchen',
    name: '주방',
    onEnter: (c) => c.say(strKitchenIntro),
    cleared: flagSet('kitchen_r_done'),
    walls: [
      // 벽면 A: 화덕·조리대·국자 벽 (기존 아트 재사용, 무수정 — 냄비 상태는
      // 클로즈업에서만 그려진다)
      Scene(id: 'kitchen_a', image: 'assets/scenes/kitchen_a.png', hotspots: [
        Hotspot(
            id: 'counter',
            area: counterArea,
            onTap: (c) {
              if (c.s.flag('kitchen_r_got_bottle') == 0) {
                c.s.setFlag('kitchen_r_got_bottle', 1);
                c.give('empty_bottle');
                c.sfx('glass_clink');
                c.say(strKitchenBottle);
              } else {
                c.say(strKitchenCounterEmpty);
              }
            }),
        Hotspot(id: 'stove', area: stoveArea, onTap: (c) => c.say(strKitchenStove)),
        Hotspot(
            id: 'gukja',
            area: gukjaArea,
            onTap: (c) {
              final s = c.s;
              if (s.flag('kitchen_r_ghost_fed') >= 1) {
                c.say(strKitchenGukjaHappy);
              } else if (s.flag('kitchen_r_pot_stage') >= _potOrder.length) {
                s.setFlag('kitchen_r_ghost_fed', 1);
                c.give('key_kitchen');
                c.sfx('liquid_pour');
                c.sfx('sparkle');
                c.say(strKitchenRFed);
              } else {
                c.sfx('ghost_giggle');
                c.say(strKitchenRGukjaAsk);
              }
            }),
        Hotspot(
            id: 'jar',
            area: jarArea,
            onTap: (c) {
              if (c.s.flag('kitchen_r_got_mushroom') == 0) {
                c.s.setFlag('kitchen_r_got_mushroom', 1);
                c.give('mushroom');
                c.sfx('ceramic_clink');
                c.say(strKitchenJar);
              } else {
                c.say(strKitchenJarEmpty);
              }
            }),
        // pot/stove_poker_slot은 stove의 부분집합 rect라 뒤에 선언 — z순서상
        // 이 둘이 자기 영역에서 stove를 이긴다(§ 위 주석과 동일한 이유).
        Hotspot(id: 'pot', area: potArea, onTap: tapPot),
        Hotspot(
            id: 'stove_poker_slot',
            area: stovePokerSlotArea,
            onTap: (c) {
              if (c.using('poker')) {
                c.consume('poker');
                c.give('poker_hot');
                c.sfx('fire_ignite');
                c.say(strKitchenRPokerHeated);
              } else {
                c.say(strKitchenRPokerSlotEmpty);
              }
            }),
      ]),
      // 벽면 B: 찬장·싱크대·뒷문 벽 (기존 아트+로직 재사용, 플래그만 kitchen_r_)
      Scene(id: 'kitchen_b', image: 'assets/scenes/kitchen_b.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/kitchen_b_cup2_open.png',
            area: cupboard2Area,
            when: flagSet('kitchen_r_hollow_found'),
            motion: OverlayMotion.slideDown),
        SceneOverlay(
            image: 'assets/scenes/kitchen_b_door_open.png',
            area: backdoorArea,
            when: flagSet('kitchen_r_door_open'),
            motion: OverlayMotion.grow),
      ], hotspots: [
        Hotspot(
            id: 'sink',
            area: sinkArea,
            onTap: (c) {
              if (c.using('empty_bottle')) {
                c.consume('empty_bottle');
                c.give('water_bottle');
                c.sfx('bottle_fill');
                c.say(strKitchenFill);
              } else {
                c.say(strKitchenSink);
              }
            }),
        Hotspot(id: 'cupboard1', area: cupboard1Area, onTap: knockDull),
        Hotspot(
            id: 'cupboard2',
            area: cupboard2Area,
            onTap: (c) {
              final s = c.s;
              if (s.flag('kitchen_r_hollow_found') == 0) {
                s.setFlag('kitchen_r_hollow_found', 1);
                c.sfx('wood_knock_hollow');
                c.say(strKitchenKnockHollow);
              } else if (s.flag('kitchen_r_got_kettle') == 0) {
                s.setFlag('kitchen_r_got_kettle', 1);
                c.give('kettle_singing');
                c.sfx('metal_click');
                c.say(strKitchenKettle);
              } else {
                c.say(strKitchenCupboardEmpty);
              }
            }),
        Hotspot(id: 'cupboard3', area: cupboard3Area, onTap: knockDull),
        Hotspot(id: 'cupboard4', area: cupboard4Area, onTap: knockDull),
        Hotspot(
            id: 'backdoor',
            area: backdoorArea,
            onTap: (c) {
              final s = c.s;
              if (s.flag('kitchen_r_door_open') >= 1) {
                c.sfx('door_open');
                s.setFlag('kitchen_r_done', 1);
              } else if (c.using('key_kitchen')) {
                c.consume('key_kitchen');
                c.sfx('metal_key');
                s.setFlag('kitchen_r_door_open', 1);
                c.say(strKitchenDoorOpened);
              } else {
                c.sfx('locked');
                c.say(strKitchenDoorLocked);
              }
            }),
      ]),
      // 벽면 C: 저장실 (신규) — 빙실 함(T2), 레시피판(T1 지식·게이트 아님),
      // 부지깽이 걸이(T2 시작점), 소시지·항아리 리액션 3개.
      Scene(id: 'kitchen_c', image: 'assets/scenes/kitchen_c.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/kitchen_c_ice1.png',
            area: iceCropArea,
            when: (s) => s.flag('kitchen_r_ice_stage') == 1),
        SceneOverlay(
            image: 'assets/scenes/kitchen_c_ice2.png',
            area: iceCropArea,
            when: (s) => s.flag('kitchen_r_ice_stage') == 2),
        SceneOverlay(
            image: 'assets/scenes/kitchen_c_ice3.png',
            area: iceCropArea,
            when: (s) => s.flag('kitchen_r_ice_stage') >= 3),
      ], hotspots: [
        Hotspot(id: 'icebox', area: iceArea, onTap: tapIcebox),
        Hotspot(
            id: 'recipe_board',
            area: recipeArea,
            onTap: (c) {
              c.sfx('paper_rustle');
              c.openCloseup('recipe');
            }),
        Hotspot(
            id: 'poker_rack',
            area: pokerRackArea,
            onTap: (c) {
              if (c.s.flag('kitchen_r_got_poker') == 0) {
                c.s.setFlag('kitchen_r_got_poker', 1);
                c.give('poker');
                c.sfx('metal_click');
                c.say(strKitchenRPokerRack);
              } else {
                c.say(strKitchenRPokerRackEmpty);
              }
            }),
        Hotspot(
            id: 'sausages',
            area: sausagesArea,
            onTap: (c) => c.say(strKitchenRSausages)),
        Hotspot(
            id: 'jar_pickles',
            area: jarPicklesArea,
            onTap: (c) => c.say(strKitchenRJarPickles)),
        Hotspot(
            id: 'jar_flour',
            area: jarFlourArea,
            onTap: (c) => c.say(strKitchenRJarFlour)),
      ]),
    ],
    closeups: {
      // 냄비: 5단계 그림 시리즈. base=pot1(빈 냄비), stage 1~4가 각각 pot2~5를
      // 덮어씌운다. wrong=1이면(순서 오류 직후 1프레임) pot_wrong이 최상단에.
      'pot': Scene(
          id: 'pot',
          image: 'assets/scenes/kitchen_pot1.png',
          overlays: [
            SceneOverlay(
                image: 'assets/scenes/kitchen_pot2.png',
                area: const Rect.fromLTWH(0, 0, 1, 1),
                when: (s) => s.flag('kitchen_r_pot_stage') == 1),
            SceneOverlay(
                image: 'assets/scenes/kitchen_pot3.png',
                area: const Rect.fromLTWH(0, 0, 1, 1),
                when: (s) => s.flag('kitchen_r_pot_stage') == 2),
            SceneOverlay(
                image: 'assets/scenes/kitchen_pot4.png',
                area: const Rect.fromLTWH(0, 0, 1, 1),
                when: (s) => s.flag('kitchen_r_pot_stage') == 3),
            SceneOverlay(
                image: 'assets/scenes/kitchen_pot5.png',
                area: const Rect.fromLTWH(0, 0, 1, 1),
                when: (s) => s.flag('kitchen_r_pot_stage') >= 4,
                motion: OverlayMotion.grow),
            SceneOverlay(
                image: 'assets/scenes/kitchen_pot_wrong.png',
                area: const Rect.fromLTWH(0, 0, 1, 1),
                when: (s) => s.flag('kitchen_r_pot_wrong') >= 1),
          ]),
      'recipe': Scene(
          id: 'recipe',
          custom: (_, c) => RubbableScene(
                ctx: c,
                baseImage: 'assets/scenes/kitchen_recipe_clean.png',
                coverImage: 'assets/scenes/kitchen_recipe_stain.png',
                cleaned: (s) => s.flag('kitchen_r_recipe_rubbed') >= 1,
                onCleaned: (c) {
                  c.s.setFlag('kitchen_r_recipe_rubbed', 1);
                  c.sfx('sparkle');
                },
                gestureKey: const Key('recipe_rub'),
              )),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_kitchen_r_soup', title: '유령 수프', steps: [
        '레시피는 벽에 있어요 — 닦아야 보이지만',
        '그림 순서대로 냄비에. 세 번째 재료는 차가운 곳에',
        '정답: 물→버섯→약초(빙실)→주전자 노래',
      ], solved: (s) => s.flag('kitchen_r_pot_stage') >= 4),
      PuzzleHint(puzzleId: 'p_kitchen_r_ice', title: '언 자물쇠', steps: [
        '얼음은 뜨거운 것에 약해요',
        '부지깽이를 화덕에 달구세요',
        '정답: 달군 부지깽이를 자물쇠에',
      ], solved: (s) => s.flag('kitchen_r_ice_looted') >= 1),
      PuzzleHint(puzzleId: 'p_kitchen_r_door', title: '뒷문', steps: [
        '뒷문 열쇠는 국자가 갖고 있어요',
        '국자는 그냥 주지 않아요 — 뭔가 만들어 주길 바라는 눈치예요',
        '정답: 국자에게 완성 수프 → 열쇠',
      ], solved: (s) => s.flag('kitchen_r_done') >= 1),
    ],
  );
}
