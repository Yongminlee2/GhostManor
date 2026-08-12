import 'package:flutter/widgets.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──

/// 촛대 i(1..4) 토글. 패턴(1끔·2켬·3끔·4켬)이 완성되면 벽난로 점화(한 번 켜지면 유지).
void toggleCandle(GameState s, int i) {
  final key = 'living_candle$i';
  s.setFlag(key, s.flag(key) >= 1 ? 0 : 1);
  final patternMatched = s.flag('living_candle1') == 0 &&
      s.flag('living_candle2') == 1 &&
      s.flag('living_candle3') == 0 &&
      s.flag('living_candle4') == 1;
  if (patternMatched) s.setFlag('living_fireplace_lit', 1);
}

// ── 방 정의 ──

Room buildLiving() {
  Cond flagSet(String k) => (s) => s.flag(k) >= 1;
  Cond flagZero(String k) => (s) => s.flag(k) == 0;

  const candle1Area = Rect.fromLTWH(0.06, 0.52, 0.10, 0.16);
  const candle2Area = Rect.fromLTWH(0.28, 0.52, 0.10, 0.16);
  const candle3Area = Rect.fromLTWH(0.62, 0.52, 0.10, 0.16);
  const candle4Area = Rect.fromLTWH(0.84, 0.52, 0.10, 0.16);
  const fireplaceArea = Rect.fromLTWH(0.30, 0.48, 0.40, 0.34);
  const nookArea = Rect.fromLTWH(0.36, 0.30, 0.28, 0.14);
  const tvArea = Rect.fromLTWH(0.10, 0.24, 0.24, 0.22);
  const doorArea = Rect.fromLTWH(0.62, 0.26, 0.26, 0.44);
  const booSofaArea = Rect.fromLTWH(0.34, 0.56, 0.18, 0.22);

  // 촛대 4개 공용: 토글 + 클릭음, 새로 점화됐으면 반짝임음+대사.
  void tapCandle(GameCtx c, int i) {
    final wasLit = c.s.flag('living_fireplace_lit') >= 1;
    toggleCandle(c.s, i);
    c.sfx('metal_click');
    if (!wasLit && c.s.flag('living_fireplace_lit') >= 1) {
      c.sfx('fire_ignite');
      c.say(strLivingFireLit);
    }
  }

  return Room(
    id: 'living',
    name: '거실',
    onEnter: (c) => c.say(strLivingIntro),
    cleared: flagSet('living_done'),
    walls: [
      // 벽면 A: 벽난로 벽
      Scene(id: 'living_a', image: 'assets/scenes/living_a.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/living_a_candle1_on.png',
            area: candle1Area,
            when: flagSet('living_candle1')),
        SceneOverlay(
            image: 'assets/scenes/living_a_candle2_on.png',
            area: candle2Area,
            when: flagSet('living_candle2')),
        SceneOverlay(
            image: 'assets/scenes/living_a_candle3_on.png',
            area: candle3Area,
            when: flagSet('living_candle3')),
        SceneOverlay(
            image: 'assets/scenes/living_a_candle4_on.png',
            area: candle4Area,
            when: flagSet('living_candle4')),
        SceneOverlay(
            image: 'assets/scenes/living_a_fire.png',
            area: fireplaceArea,
            when: flagSet('living_fireplace_lit')),
        SceneOverlay(
            image: 'assets/scenes/living_a_nook_open.png',
            area: nookArea,
            when: flagSet('living_fireplace_lit')),
      ], hotspots: [
        // fireplace는 큰 배경 rect라 목록 맨 앞(= 탭 우선순위 최하) 선언 —
        // 뒤에 오는 candle2/candle3와 겹쳐도 촛대가 항상 이긴다 (최종 리뷰 Finding 1).
        Hotspot(
            id: 'fireplace',
            area: fireplaceArea,
            onTap: (c) => c.say(c.s.flag('living_fireplace_lit') >= 1
                ? strLivingFireplaceLit
                : strLivingFireplaceCold)),
        Hotspot(
            id: 'candle1',
            area: candle1Area,
            when: flagZero('living_fireplace_lit'),
            onTap: (c) => tapCandle(c, 1)),
        Hotspot(
            id: 'candle2',
            area: candle2Area,
            when: flagZero('living_fireplace_lit'),
            onTap: (c) => tapCandle(c, 2)),
        Hotspot(
            id: 'candle3',
            area: candle3Area,
            when: flagZero('living_fireplace_lit'),
            onTap: (c) => tapCandle(c, 3)),
        Hotspot(
            id: 'candle4',
            area: candle4Area,
            when: flagZero('living_fireplace_lit'),
            onTap: (c) => tapCandle(c, 4)),
        Hotspot(
            id: 'secret_nook',
            area: nookArea,
            onTap: (c) {
              final s = c.s;
              if (s.flag('living_fireplace_lit') == 0) {
                c.say(strLivingMantel);
              } else if (s.flag('living_got_key') == 0) {
                c.sfx('wood_creak_open');
                c.give('key_living');
                c.give('note1');
                c.give('oil');
                s.setFlag('living_got_key', 1);
                c.say(strLivingSecretFound);
              } else {
                c.say(strLivingSecretEmpty);
              }
            }),
      ]),
      // 벽면 B: 소파·TV·문 벽
      Scene(id: 'living_b', image: 'assets/scenes/living_b.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/living_b_boo_door.png',
            area: const Rect.fromLTWH(0.60, 0.28, 0.24, 0.34),
            when: flagZero('living_tv_on')),
        SceneOverlay(
            image: 'assets/scenes/living_b_boo_sofa.png',
            area: booSofaArea,
            when: flagSet('living_tv_on')),
        SceneOverlay(
            image: 'assets/scenes/living_b_tv_on.png',
            area: tvArea,
            when: flagSet('living_tv_on')),
        SceneOverlay(
            image: 'assets/scenes/living_b_door_open.png',
            area: doorArea,
            when: flagSet('living_door_open')),
      ], hotspots: [
        Hotspot(
            id: 'cushion',
            area: const Rect.fromLTWH(0.08, 0.62, 0.18, 0.14),
            onTap: (c) {
              if (c.s.flag('living_got_remote') == 0) {
                c.s.setFlag('living_got_remote', 1);
                c.give('remote');
                c.sfx('cloth_rub');
                c.say(strLivingCushion);
              } else {
                c.say(strLivingCushionEmpty);
              }
            }),
        Hotspot(
            id: 'tv',
            area: tvArea,
            onTap: (c) {
              if (c.s.flag('living_tv_on') >= 1) {
                c.openCloseup('tv');
              } else if (c.using('remote')) {
                c.consume('remote');
                c.s.setFlag('living_tv_on', 1);
                c.sfx('tv_static');
                c.say(strLivingTvOn);
              } else {
                c.say(strLivingTvOff);
              }
            }),
        // door는 boo/boo_sofa를 감싸는 더 큰 rect라 그 앞에 선언 —
        // TV 끄고 켠 상태 각각에서 boo/boo_sofa(뒤 선언)가 자기 자리를 이기고,
        // 문 나머지 테두리는 door가 받는다 (최종 리뷰 Finding 3).
        Hotspot(
            id: 'door',
            area: doorArea,
            onTap: (c) {
              final s = c.s;
              if (s.flag('living_tv_on') == 0) {
                c.say(strLivingBooBlocks);
              } else if (s.flag('living_door_open') >= 1) {
                c.sfx('door_open');
                s.setFlag('living_done', 1);
              } else if (c.using('key_living')) {
                c.consume('key_living');
                c.sfx('metal_key');
                s.setFlag('living_door_open', 1);
                c.say(strLivingDoorOpened);
              } else {
                c.sfx('locked');
                c.say(strLivingDoorLocked);
              }
            }),
        Hotspot(
            id: 'boo',
            area: const Rect.fromLTWH(0.62, 0.30, 0.20, 0.30),
            when: flagZero('living_tv_on'),
            onTap: (c) {
              c.sfx('ghost_giggle');
              c.say(strLivingBooScare);
            }),
        Hotspot(
            id: 'boo_sofa',
            area: booSofaArea,
            when: flagSet('living_tv_on'),
            onTap: (c) {
              c.sfx('ghost_giggle');
              c.say(strLivingBooHappy);
            }),
      ]),
    ],
    closeups: {
      'tv': Scene(id: 'tv', image: 'assets/scenes/living_tv.png'),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_living_boo', title: '문을 막는 유령', steps: [
        '문을 막은 유령은 겁을 주고 싶은 게 아니라 뭔가 아쉬운 게 있어요. 대사를 잘 들어보세요.',
        '부우는 드라마 재방송을 놓쳐 시무룩해요. TV를 켜 줄 방법을 찾아보세요 — 소파 쿠션을 뒤져 보면?',
        '정답: 쿠션에서 리모컨을 얻고, 리모컨을 선택한 채 TV를 탭하면 부우가 비켜 줘요.',
      ], solved: (s) => s.flag('living_tv_on') >= 1),
      PuzzleHint(puzzleId: 'p_living_candles', title: '촛대와 벽난로', steps: [
        '촛대 네 개는 켜고 끌 수 있어요. 정답 배열이 이 방 어딘가에 그림으로 나와요.',
        '켜진 TV 화면을 자세히 보세요. 촛대 네 개 중 어떤 것에 불이 붙어 있나요?',
        '정답: 2번째와 4번째 촛대만 켜세요(1·3번은 끈 상태). 벽난로가 점화되고 비밀칸이 열려요.',
      ], solved: (s) => s.flag('living_fireplace_lit') >= 1),
      PuzzleHint(puzzleId: 'p_living_door', title: '잠긴 문', steps: [
        '문은 평범한 자물쇠예요. 열쇠는 이 방 안에 숨겨져 있어요.',
        '벽난로 위 열린 비밀칸을 살펴보세요.',
        '정답: 비밀칸의 거실 열쇠를 선택하고 문을 탭하세요.',
      ], solved: (s) => s.flag('living_door_open') >= 1),
    ],
  );
}
