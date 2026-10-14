import 'package:flutter/widgets.dart';
import '../core/dial_safe.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/scene_view.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──
// 리마스터: 전 플래그 living_r_ 접두어 (구세이브의 living_* 와 충돌 차단).
//
// 스레드 구조(브리프): T1 초상화 시선 금고(벽C) ‖ T2 촛대→벽난로(벽A) ‖
// T3 부우·TV(벽B, 단서 허브) → 교차: 금고를 돌릴 다이얼 손잡이가 T2 비밀칸에서
// 나옴, TV는 T1(나이 순서)·T2(촛불 패턴) 단서를 순환 표시.

/// 촛대 i(1..4) 토글. 패턴(1끔·2켬·3끔·4켬)이 완성되면 벽난로 점화(한 번 켜지면 유지).
void toggleCandle(GameState s, int i) {
  final key = 'living_r_candle$i';
  s.setFlag(key, s.flag(key) >= 1 ? 0 : 1);
  final patternMatched = s.flag('living_r_candle1') == 0 &&
      s.flag('living_r_candle2') == 1 &&
      s.flag('living_r_candle3') == 0 &&
      s.flag('living_r_candle4') == 1;
  if (patternMatched) s.setFlag('living_r_fireplace_lit', 1);
}

/// 금고 다이얼 정답 확인 성공 시 1회 호출(DialSafe의 원샷 가드가 감싼다).
/// 나이순(TV) × 그림 속 소품 개수(초상화 4점 대사가 소품 종류를 매핑) = 3274.
void openSafe(GameCtx c) {
  final s = c.s;
  s.setFlag('living_r_safe_open', 1);
  c.sfx('unlock');
  c.give('key_living');
  c.give('oil');
  c.give('note1');
  c.say(strLivingRSafeOpen);
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

  // 벽 C rect — living_c.png 실측으로 재조정 완료. 초상화→소품 매핑은
  // 그림이 시선을 구분해 주지 못해(4점 모두 같은 방향) 초상화 리액션이
  // "그림 속에 함께 그려진 물건"을 묘사하는 방식으로 전달한다(개수·순서는
  // 여전히 비공개 — 소품 탭 개수 × TV 나이순 조합은 그대로).
  const portraitBabyArea = Rect.fromLTWH(0.09, 0.04, 0.16, 0.15);
  const portraitYouthArea = Rect.fromLTWH(0.31, 0.04, 0.16, 0.15);
  const portraitMiddleArea = Rect.fromLTWH(0.53, 0.04, 0.16, 0.15);
  const portraitOldArea = Rect.fromLTWH(0.75, 0.04, 0.16, 0.15);
  // 초상화 아래 랜턴 4개 — 전부 같은 램프 리액션(어느 것을 세든 "셋").
  const lamp1Area = Rect.fromLTWH(0.12, 0.20, 0.09, 0.11);
  const lamp2Area = Rect.fromLTWH(0.34, 0.20, 0.09, 0.11);
  const lamp3Area = Rect.fromLTWH(0.56, 0.20, 0.10, 0.11);
  const lamp4Area = Rect.fromLTWH(0.78, 0.20, 0.10, 0.11);
  const safeArea = Rect.fromLTWH(0.06, 0.30, 0.24, 0.20);
  const vaseArea = Rect.fromLTWH(0.12, 0.50, 0.19, 0.14);
  const booksArea = Rect.fromLTWH(0.16, 0.69, 0.18, 0.12);
  const pendulumArea = Rect.fromLTWH(0.76, 0.42, 0.20, 0.28);

  // 촛대 4개 공용: 토글 + 클릭음, 새로 점화됐으면 반짝임음+대사.
  void tapCandle(GameCtx c, int i) {
    final wasLit = c.s.flag('living_r_fireplace_lit') >= 1;
    toggleCandle(c.s, i);
    c.sfx('metal_click');
    if (!wasLit && c.s.flag('living_r_fireplace_lit') >= 1) {
      c.sfx('fire_ignite');
      c.say(strLivingFireLit);
    }
  }

  return Room(
    id: 'living',
    name: '거실',
    onEnter: (c) => c.say(strLivingIntro),
    cleared: flagSet('living_r_done'),
    walls: [
      // 벽면 A: 벽난로 벽 (기존 아트 재사용)
      Scene(id: 'living_a', image: 'assets/scenes/living_a.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/living_a_candle1_on.png',
            area: const Rect.fromLTWH(0.04, 0.4837, 0.1387, 0.1966),
            when: flagSet('living_r_candle1'),
            motion: OverlayMotion.grow),
        SceneOverlay(
            image: 'assets/scenes/living_a_candle2_on.png',
            area: const Rect.fromLTWH(0.2607, 0.4837, 0.1387, 0.1966),
            when: flagSet('living_r_candle2'),
            motion: OverlayMotion.grow),
        SceneOverlay(
            image: 'assets/scenes/living_a_candle3_on.png',
            area: const Rect.fromLTWH(0.6006, 0.4837, 0.1387, 0.1966),
            when: flagSet('living_r_candle3'),
            motion: OverlayMotion.grow),
        SceneOverlay(
            image: 'assets/scenes/living_a_candle4_on.png',
            area: const Rect.fromLTWH(0.8203, 0.4837, 0.1387, 0.1966),
            when: flagSet('living_r_candle4'),
            motion: OverlayMotion.grow),
        SceneOverlay(
            image: 'assets/scenes/living_a_fire.png',
            area: const Rect.fromLTWH(0.332, 0.4557, 0.3418, 0.2474),
            when: flagSet('living_r_fireplace_lit'),
            motion: OverlayMotion.grow),
        SceneOverlay(
            image: 'assets/scenes/living_a_nook_open.png',
            area: nookArea,
            when: flagSet('living_r_fireplace_lit'),
            motion: OverlayMotion.slideDown),
      ], hotspots: [
        // fireplace는 큰 배경 rect라 목록 맨 앞(= 탭 우선순위 최하) 선언 —
        // 뒤에 오는 candle2/candle3와 겹쳐도 촛대가 항상 이긴다.
        Hotspot(
            id: 'fireplace',
            area: fireplaceArea,
            onTap: (c) => c.say(c.s.flag('living_r_fireplace_lit') >= 1
                ? strLivingFireplaceLit
                : strLivingFireplaceCold)),
        Hotspot(
            id: 'candle1',
            area: candle1Area,
            when: flagZero('living_r_fireplace_lit'),
            onTap: (c) => tapCandle(c, 1)),
        Hotspot(
            id: 'candle2',
            area: candle2Area,
            when: flagZero('living_r_fireplace_lit'),
            onTap: (c) => tapCandle(c, 2)),
        Hotspot(
            id: 'candle3',
            area: candle3Area,
            when: flagZero('living_r_fireplace_lit'),
            onTap: (c) => tapCandle(c, 3)),
        Hotspot(
            id: 'candle4',
            area: candle4Area,
            when: flagZero('living_r_fireplace_lit'),
            onTap: (c) => tapCandle(c, 4)),
        Hotspot(
            id: 'secret_nook',
            area: nookArea,
            onTap: (c) {
              final s = c.s;
              if (s.flag('living_r_fireplace_lit') == 0) {
                c.say(strLivingMantel);
              } else if (s.flag('living_r_got_knob') == 0) {
                c.sfx('wood_creak_open');
                c.give('knob');
                s.setFlag('living_r_got_knob', 1);
                c.say(strLivingRNookKnob);
              } else {
                c.say(strLivingSecretEmpty);
              }
            }),
      ]),
      // 벽면 B: 소파·TV·문 벽 (기존 아트 재사용)
      Scene(id: 'living_b', image: 'assets/scenes/living_b.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/living_b_tv_on.png',
            area: const Rect.fromLTWH(0.0742, 0.2357, 0.2559, 0.1406),
            when: flagSet('living_r_tv_on')),
        SceneOverlay(
            image: 'assets/scenes/living_b_door_open.png',
            area: const Rect.fromLTWH(0.5957, 0.2591, 0.2949, 0.4466),
            when: flagSet('living_r_door_open'),
            motion: OverlayMotion.grow),
      ], idles: [
        IdleSprite(
            image: 'assets/scenes/living_b_boo_door.png',
            area: const Rect.fromLTWH(0.60, 0.28, 0.24, 0.34),
            when: flagZero('living_r_tv_on'),
            bobPx: 8),
        IdleSprite(
            image: 'assets/scenes/living_b_boo_sofa.png',
            area: booSofaArea,
            when: flagSet('living_r_tv_on'),
            bobPx: 5),
      ], hotspots: [
        Hotspot(
            id: 'cushion',
            area: const Rect.fromLTWH(0.08, 0.62, 0.18, 0.14),
            onTap: (c) {
              if (c.s.flag('living_r_got_remote') == 0) {
                c.s.setFlag('living_r_got_remote', 1);
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
              if (c.s.flag('living_r_tv_on') >= 1) {
                c.openCloseup('tv');
              } else if (c.using('remote')) {
                c.consume('remote');
                c.s.setFlag('living_r_tv_on', 1);
                c.sfx('tv_static');
                c.say(strLivingTvOn);
              } else {
                c.say(strLivingTvOff);
              }
            }),
        // door는 boo/boo_sofa를 감싸는 더 큰 rect라 그 앞에 선언 —
        // TV 끄고 켠 상태 각각에서 boo/boo_sofa(뒤 선언)가 자기 자리를 이기고,
        // 문 나머지 테두리는 door가 받는다.
        Hotspot(
            id: 'door',
            area: doorArea,
            onTap: (c) {
              final s = c.s;
              if (s.flag('living_r_tv_on') == 0) {
                c.say(strLivingBooBlocks);
              } else if (s.flag('living_r_door_open') >= 1) {
                c.sfx('door_open');
                s.setFlag('living_r_done', 1);
              } else if (c.using('key_living')) {
                c.consume('key_living');
                c.sfx('metal_key');
                s.setFlag('living_r_door_open', 1);
                c.say(strLivingDoorOpened);
              } else {
                c.sfx('locked');
                c.say(strLivingDoorLocked);
              }
            }),
        Hotspot(
            id: 'boo',
            area: const Rect.fromLTWH(0.62, 0.30, 0.20, 0.30),
            when: flagZero('living_r_tv_on'),
            onTap: (c) {
              c.sfx('ghost_giggle');
              c.say(strLivingBooScare);
            }),
        Hotspot(
            id: 'boo_sofa',
            area: booSofaArea,
            when: flagSet('living_r_tv_on'),
            onTap: (c) {
              c.sfx('ghost_giggle');
              c.say(strLivingBooHappy);
            }),
      ]),
      // 벽면 C: 서가·금고 벽 (신규) — 초상화 4점(그림 속 소품이 매핑 단서),
      // 소품 개수 × 나이순(TV) = 금고 코드 3274.
      // safe_knob/safe_open은 원본 전체를 edit한 풀프레임(1024×1536)이라
      // 전체 rect로 깔아야 한다 — 소rect에 넣으면 벽 전체가 찌그러져 들어간다.
      Scene(id: 'living_c', image: 'assets/scenes/living_c.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/living_c_safe_knob.png',
            area: const Rect.fromLTWH(0.0293, 0.2865, 0.293, 0.2344),
            when: (s) =>
                s.flag('living_r_safe_knob') >= 1 &&
                s.flag('living_r_safe_open') == 0),
        SceneOverlay(
            image: 'assets/scenes/living_c_safe_open.png',
            area: const Rect.fromLTWH(0.0293, 0.2865, 0.293, 0.2344),
            when: flagSet('living_r_safe_open')),
      ], hotspots: [
        Hotspot(
            id: 'portrait_baby',
            area: portraitBabyArea,
            onTap: (c) => c.say(strLivingRPortraitBaby)),
        Hotspot(
            id: 'portrait_youth',
            area: portraitYouthArea,
            onTap: (c) => c.say(strLivingRPortraitYouth)),
        Hotspot(
            id: 'portrait_middle',
            area: portraitMiddleArea,
            onTap: (c) => c.say(strLivingRPortraitMiddle)),
        Hotspot(
            id: 'portrait_old',
            area: portraitOldArea,
            onTap: (c) => c.say(strLivingRPortraitOld)),
        Hotspot(
            id: 'lamp', area: lamp1Area, onTap: (c) => c.say(strLivingRLamp)),
        Hotspot(
            id: 'lamp2', area: lamp2Area, onTap: (c) => c.say(strLivingRLamp)),
        Hotspot(
            id: 'lamp3', area: lamp3Area, onTap: (c) => c.say(strLivingRLamp)),
        Hotspot(
            id: 'lamp4', area: lamp4Area, onTap: (c) => c.say(strLivingRLamp)),
        Hotspot(
            id: 'pendulum',
            area: pendulumArea,
            onTap: (c) => c.say(strLivingRPendulum)),
        Hotspot(id: 'vase', area: vaseArea, onTap: (c) => c.say(strLivingRVase)),
        Hotspot(
            id: 'books', area: booksArea, onTap: (c) => c.say(strLivingRBooks)),
        Hotspot(
            id: 'safe',
            area: safeArea,
            onTap: (c) {
              final s = c.s;
              if (s.flag('living_r_safe_open') >= 1) {
                c.say(strLivingRSafeEmpty);
              } else if (s.flag('living_r_safe_knob') >= 1) {
                c.openCloseup('safe');
              } else if (c.using('knob')) {
                c.consume('knob');
                s.setFlag('living_r_safe_knob', 1);
                c.sfx('metal_click');
                c.say(strLivingRSafeKnobAttached);
              } else {
                c.say(strLivingRSafeNoKnob);
              }
            }),
      ]),
    ],
    closeups: {
      // 탭마다 living_r_tv_scene 토글 — 촛불 패턴(기본, T2 단서) ↔ 나이 순서
      // 아이콘 행렬(living_tv2 오버레이, T1 단서) 순환.
      'tv': Scene(id: 'tv', image: 'assets/scenes/living_tv.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/living_tv2.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: (s) => s.flag('living_r_tv_scene') == 1),
      ], hotspots: [
        Hotspot(
            id: 'tv_scene_toggle',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            onTap: (c) {
              c.s.setFlag(
                  'living_r_tv_scene', c.s.flag('living_r_tv_scene') == 0 ? 1 : 0);
              c.sfx('tv_static');
            }),
      ]),
      // 다이얼 금고: 배경은 여기서 겹쳐 쌓고(DialSafe는 배경을 그리지 않음),
      // 위젯이 휠 4개+확인 버튼을 그 위에 올린다.
      'safe': Scene(
          id: 'safe',
          custom: (_, c) => Stack(fit: StackFit.expand, children: [
                gameImage('assets/scenes/living_c_safe_dial.png'),
                DialSafe(
                  ctx: c,
                  digits: 4,
                  code: '3274',
                  flagPrefix: 'living_r_safe',
                  wrongSay: strLivingRSafeWrong,
                  onOpened: openSafe,
                ),
              ])),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_living_r_safe', title: '초상화 속 물건', steps: [
        '금고 숫자는 이 방의 "그림"과 "세는 것"에서 나와요.',
        '초상화마다 함께 그려진 물건이 있어요 — 그 물건의 개수를 세요. 순서는 TV가 알려줘요.',
        '정답: 나이순 3·2·7·4 → 3274.',
      ], solved: (s) => s.flag('living_r_safe_open') >= 1),
      PuzzleHint(puzzleId: 'p_living_r_candle', title: '촛대와 벽난로', steps: [
        '촛대 네 개는 켜고 끌 수 있어요. 정답 배열이 이 방 어딘가에 그림으로 나와요.',
        'TV를 켜고 화면을 자세히 보세요 — 탭할 때마다 다른 그림이 나와요. 촛불이 그려진 장면을 찾으세요.',
        '정답: 2번째와 4번째 촛대만 켜세요(1·3번은 끈 상태). 벽난로가 점화되고 비밀칸이 열려요.',
      ], solved: (s) => s.flag('living_r_fireplace_lit') >= 1),
      PuzzleHint(puzzleId: 'p_living_r_boo', title: '문을 막는 유령', steps: [
        '문을 막은 유령은 겁을 주고 싶은 게 아니라 뭔가 아쉬운 게 있어요. 대사를 잘 들어보세요.',
        '부우는 TV를 못 봐서 시무룩해요. 소파 쿠션 속을 뒤져 보면 도움이 될 것이 나올지도.',
        '정답: 쿠션에서 리모컨을 얻고, 리모컨을 선택한 채 TV를 탭하면 부우가 비켜 줘요.',
      ], solved: (s) => s.flag('living_r_tv_on') >= 1),
    ],
  );
}
