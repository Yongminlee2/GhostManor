import 'package:flutter/material.dart';
import '../core/game_state.dart';
import '../core/memory_player.dart';
import '../core/models.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──
// 챕터2 전 플래그 f2_bed_ 접두어.
//
// 스레드 구조(계획 Task 4): T1 거울 차이(화장대 거울 클로즈업=거울상 그림,
// 유령 물건 3개[브로치·머리핀·단추]는 실물 씬에만 있음 → 수집 → 보석함
// 3슬롯에 투입, 미끼 빗은 거부) ‖ T2 자수 완성(리본 서랍 배열[파·은·파]이
// 지식 단서 → 자수틀에 실 3타래를 그 순서로 투입) → 교차 잠금: T1(보석함)의
// 보상 은실이 T2(자수)의 2번째 실이라 T2를 끝내려면 T1을 먼저 마쳐야 한다.
// T2 완성 → 회상2(자수틀 재탭이 앵커). 문(방9)은 T1의 다른 보상 key_f2child로.

const _jewelItems = ['brooch', 'hairpin', 'button_gh'];

/// 보석함에 유령 물건 하나 투입(3슬롯 월드, 순서 무관 — 순수 함수). 유령
/// 물건(브로치·머리핀·단추) 중 아직 넣지 않은 것이면 `f2_bed_jewel_<id>`을 1로
/// 세우고 true. 미끼·미선택·이미 넣은 것은 아무 것도 바꾸지 않고 false —
/// "미끼를 넣으면 거부" 반응은 이 함수가 아니라 호출부(tapJewelbox)의 몫.
bool putJewel(GameState s, String? itemId) {
  if (itemId == null || !_jewelItems.contains(itemId)) return false;
  final key = 'f2_bed_jewel_$itemId';
  if (s.flag(key) >= 1) return false;
  s.setFlag(key, 1);
  return true;
}

/// 3슬롯이 전부 채워졌는지.
bool bedJewelboxFull(GameState s) =>
    _jewelItems.every((id) => s.flag('f2_bed_jewel_$id') >= 1);

const _stitchOrder = ['blue', 'silver', 'blue'];

/// 파란 실 2타래(반짇고리)는 인벤토리 id가 갈려 있어도(thread_blue1/2 —
/// InventoryBar Key 충돌 회피, items.dart의 fuse/fuse2와 동일 이유) 같은
/// "파랑"으로 취급한다 — 어느 쪽을 먼저 써도 무방하다.
String? _threadColor(String? item) {
  if (item == 'thread_blue1' || item == 'thread_blue2') return 'blue';
  if (item == 'silver_thread') return 'silver';
  return null;
}

/// 자수틀에 실 하나 투입(순서: 파랑→은→파랑 — 순수 함수). 다음 순서와 색이
/// 맞으면 f2_bed_stitch_stage +1(3 도달은 호출부가 f2_bed_stitch_done으로
/// 승격) 하고 true. 색이 다르면(실이지만 순서 오답) 0으로 리셋하고 false.
/// 실이 아닌 아이템/미선택/이미 완성이면 아무 것도 바꾸지 않고 false.
bool stitchThread(GameState s, String? item) {
  final stage = s.flag('f2_bed_stitch_stage');
  if (stage >= _stitchOrder.length) return false;
  final color = _threadColor(item);
  if (color == null) return false;
  if (color == _stitchOrder[stage]) {
    s.setFlag('f2_bed_stitch_stage', stage + 1);
    return true;
  }
  // 오답이어도 단계는 유지한다 — 정답 실은 영구 소모(파랑 2·은 1이 정확히
  // 재고)라 0으로 리셋하면 남은 실로는 복구 불가 소프트락이 된다(주방 냄비와
  // 동일한 부류, 실기기 검수에서 발견된 원칙).
  return false;
}

// ── 방 정의 ──

Room buildBed() {
  Cond flagSet(String k) => (s) => s.flag(k) >= 1;

  // 벽면 A(캐노피 침대) 핫스팟 rect — 납품된 f2_bed_a.png 실측 눈대중(정밀
  // 재배선은 계획 Task 9 일괄 검수 몫): 창+커튼 좌측, 캐노피 침대가 중앙~
  // 우측 대부분, 협탁은 침대 왼쪽 바닥(머리핀이 위에 놓여 있다), 벽등은
  // 침대 오른쪽 벽. 방9로 가는 문은 세 벽 아트 어디에도 그려지지 않았다
  // (아트 의뢰서 방 8 표에 문 언급 없음) — 벽등 아래 빈 벽 자리를 문으로
  // 쓴다(hall의 "벽 A=문" 관례 유지, 재배선은 Task 9 몫).
  const doorArea = Rect.fromLTWH(0.85, 0.05, 0.15, 0.90);
  const sconceArea = Rect.fromLTWH(0.85, 0.27, 0.13, 0.16);
  // 커튼=상단 드레이프 띠, 창=유리 — 겹치지 않게 분리(Task 9 정밀 재배선).
  const curtainArea = Rect.fromLTWH(0.02, 0.08, 0.20, 0.13);
  const windowArea = Rect.fromLTWH(0.06, 0.22, 0.16, 0.30);
  const canopyArea = Rect.fromLTWH(0.32, 0.12, 0.52, 0.20);
  const bedArea = Rect.fromLTWH(0.30, 0.48, 0.54, 0.42);
  const nightstandArea = Rect.fromLTWH(0.06, 0.53, 0.22, 0.19);

  // 벽면 B(화장대·거울) — f2_bed_b.png 실측: 큰 거울이 상단 중앙, 화장대
  // 위에 촛대·보석함·브로치가 좌→우로 나란히(빗은 그 옆 빈 자리), 의자는
  // 우측, 초상화 2점은 거울 좌우 벽.
  const chairArea = Rect.fromLTWH(0.60, 0.52, 0.30, 0.42);
  const candelabraArea = Rect.fromLTWH(0.09, 0.36, 0.20, 0.20);
  const frameLeftArea = Rect.fromLTWH(0.0, 0.10, 0.14, 0.14);
  const frameRightArea = Rect.fromLTWH(0.87, 0.12, 0.13, 0.20);
  const jewelboxArea = Rect.fromLTWH(0.22, 0.49, 0.17, 0.09);
  const broochArea = Rect.fromLTWH(0.40, 0.51, 0.12, 0.05);
  const combArea = Rect.fromLTWH(0.54, 0.50, 0.11, 0.05);
  const mirrorArea = Rect.fromLTWH(0.30, 0.11, 0.42, 0.40);

  // 벽면 C(옷장·자수 코너) — f2_bed_c.png 실측: 옷장이 좌측 절반, 손거울·
  // 초상화 2점이 중앙 벽, 자수틀+반짇고리가 중하단, 리본 서랍장(+촛대)이 우측.
  const wardrobeArea = Rect.fromLTWH(0.0, 0.07, 0.46, 0.70);
  const smallMirrorArea = Rect.fromLTWH(0.49, 0.18, 0.12, 0.12);
  const framePhoto1Area = Rect.fromLTWH(0.64, 0.17, 0.13, 0.12);
  const framePhoto2Area = Rect.fromLTWH(0.56, 0.31, 0.13, 0.12);
  const dresserCandlesArea = Rect.fromLTWH(0.79, 0.35, 0.16, 0.13);
  const embroideryArea = Rect.fromLTWH(0.44, 0.42, 0.28, 0.24);
  const sewingBasketArea = Rect.fromLTWH(0.47, 0.61, 0.22, 0.13);
  const ribbonDrawerArea = Rect.fromLTWH(0.72, 0.44, 0.26, 0.30);

  void tapDoor(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_bed_door_open') >= 1) {
      c.sfx('door_open');
      if (s.flag('f2_bed_done') == 0) {
        s.setFlag('f2_bed_done', 1);
        c.give('emblem_bed');
      }
      return;
    }
    if (!c.using('key_f2child')) {
      c.sfx('locked');
      c.say(strF2BedDoorLocked);
      return;
    }
    c.consume('key_f2child');
    c.sfx('metal_key');
    s.setFlag('f2_bed_door_open', 1);
    c.say(strF2BedDoorOpened);
  }

  void tapJewelbox(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_bed_jewelbox_open') >= 1) {
      c.say(strF2BedJewelboxDone);
      return;
    }
    final item = s.selectedItem;
    if (putJewel(s, item)) {
      c.consume(item!);
      c.sfx('metal_click');
      if (bedJewelboxFull(s)) {
        s.setFlag('f2_bed_jewelbox_open', 1);
        c.sfx('sparkle');
        c.give('silver_thread');
        c.give('key_f2child');
        c.say(strF2BedJewelboxOpen);
      } else {
        c.say(strF2BedJewelboxAccept);
      }
    } else if (item != null && !_jewelItems.contains(item)) {
      c.sfx('locked');
      c.say(strF2BedJewelboxWrong);
    } else {
      c.openCloseup('jewelbox');
    }
  }

  void tapWardrobeSearch(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_bed_wardrobe_done') >= 1) {
      c.say(strF2BedWardrobeEmpty);
      return;
    }
    final n = s.flag('f2_bed_wardrobe_search');
    if (n < 2) {
      s.setFlag('f2_bed_wardrobe_search', n + 1);
      c.sfx('cloth_rub');
      c.say(n == 0 ? strF2BedWardrobeSearch1 : strF2BedWardrobeSearch2);
      return;
    }
    s.setFlag('f2_bed_wardrobe_done', 1);
    c.sfx('sparkle');
    c.give('button_gh');
    c.say(strF2BedWardrobeFound);
  }

  void tapEmbroidery(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_bed_stitch_done') >= 1) {
      if (s.flag('f2_bed_memory') == 0) s.setFlag('f2_bed_memory', 1);
      c.openCloseup('memory');
      return;
    }
    final item = s.selectedItem;
    if (_threadColor(item) == null) {
      c.openCloseup('frame');
      return;
    }
    if (stitchThread(s, item)) {
      c.consume(item!);
      final stage = s.flag('f2_bed_stitch_stage');
      if (stage >= _stitchOrder.length) {
        s.setFlag('f2_bed_stitch_done', 1);
        c.sfx('sparkle');
        c.say(strF2BedStitchComplete);
      } else {
        c.sfx('cloth_rub');
        c.say(stage == 1 ? strF2BedStitchThread1 : strF2BedStitchThread2);
      }
    } else {
      c.sfx('locked');
      c.say(strF2BedStitchWrong);
    }
  }

  return Room(
    id: 'bed',
    name: '안방',
    onEnter: (c) => c.say(strF2BedIntro),
    cleared: flagSet('f2_bed_done'),
    walls: [
      // 벽면 A: 캐노피 침대·창·협탁(T1 머리핀) + 문.
      Scene(id: 'bed_a', image: 'assets/scenes/f2_bed_a.png', overlays: [
        // 머리핀을 가져가면 협탁 위에서 사라진다(잔존 소품 제거 합성).
        SceneOverlay(
            image: 'assets/scenes/f2_bed_a_no_hairpin.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('f2_bed_hairpin_got')),
        SceneOverlay(
            image: 'assets/scenes/f2_bed_a_door_open.png',
            area: const Rect.fromLTWH(0.8037, 0.2454, 0.1963, 0.4082),
            when: flagSet('f2_bed_door_open')),
      ], hotspots: [
        Hotspot(id: 'door', area: doorArea, onTap: tapDoor),
        Hotspot(id: 'sconce', area: sconceArea, onTap: (c) => c.say(strF2BedSconce)),
        Hotspot(id: 'curtain', area: curtainArea, onTap: (c) => c.say(strF2BedCurtain)),
        Hotspot(id: 'window', area: windowArea, onTap: (c) => c.say(strF2BedWindow)),
        Hotspot(id: 'canopy', area: canopyArea, onTap: (c) => c.say(strF2BedCanopy)),
        Hotspot(id: 'bed', area: bedArea, onTap: (c) => c.say(strF2BedBed)),
        Hotspot(
            id: 'nightstand',
            area: nightstandArea,
            onTap: (c) {
              final s = c.s;
              if (s.flag('f2_bed_hairpin_got') == 0) {
                s.setFlag('f2_bed_hairpin_got', 1);
                c.sfx('metal_click');
                c.give('hairpin');
                c.say(strF2BedNightstandGive);
              } else {
                c.say(strF2BedNightstandEmpty);
              }
            }),
      ]),
      // 벽면 B: 화장대·거울(T1 브로치+거울 클로즈업) + 보석함(T1 3슬롯).
      Scene(id: 'bed_b', image: 'assets/scenes/f2_bed_b.png', overlays: [
        // 브로치를 가져가면 화장대 위에서 사라진다.
        SceneOverlay(
            image: 'assets/scenes/f2_bed_b_no_brooch.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('f2_bed_brooch_got')),
      ], hotspots: [
        Hotspot(id: 'chair', area: chairArea, onTap: (c) => c.say(strF2BedChair)),
        Hotspot(
            id: 'candelabra', area: candelabraArea, onTap: (c) => c.say(strF2BedCandelabra)),
        Hotspot(id: 'frame_left', area: frameLeftArea, onTap: (c) => c.say(strF2BedFrameLeft)),
        Hotspot(
            id: 'frame_right', area: frameRightArea, onTap: (c) => c.say(strF2BedFrameRight)),
        Hotspot(id: 'jewelbox', area: jewelboxArea, onTap: tapJewelbox),
        Hotspot(
            id: 'brooch',
            area: broochArea,
            onTap: (c) {
              final s = c.s;
              if (s.flag('f2_bed_brooch_got') == 0) {
                s.setFlag('f2_bed_brooch_got', 1);
                c.sfx('metal_click');
                c.give('brooch');
                c.say(strF2BedBroochGive);
              } else {
                c.say(strF2BedVanityEmpty);
              }
            }),
        Hotspot(
            id: 'comb',
            area: combArea,
            onTap: (c) {
              final s = c.s;
              if (s.flag('f2_bed_comb_got') == 0) {
                s.setFlag('f2_bed_comb_got', 1);
                c.give('comb');
                c.say(strF2BedCombGive);
              } else {
                c.say(strF2BedVanityEmpty);
              }
            }),
        Hotspot(
            id: 'mirror',
            area: mirrorArea,
            onTap: (c) {
              c.openCloseup('mirror');
              c.say(strF2BedMirrorLook);
            }),
      ]),
      // 벽면 C: 옷장(T1 단추 뒤지기) + 자수 코너(T2) + 리본 서랍(T2 지식 단서).
      Scene(id: 'bed_c', image: 'assets/scenes/f2_bed_c.png', hotspots: [
        Hotspot(id: 'wardrobe', area: wardrobeArea, onTap: (c) => c.openCloseup('wardrobe')),
        Hotspot(
            id: 'small_mirror', area: smallMirrorArea, onTap: (c) => c.say(strF2BedSmallMirror)),
        Hotspot(
            id: 'frame_photo1',
            area: framePhoto1Area,
            onTap: (c) => c.say(strF2BedFramePhoto1)),
        Hotspot(
            id: 'frame_photo2',
            area: framePhoto2Area,
            onTap: (c) => c.say(strF2BedFramePhoto2)),
        Hotspot(
            id: 'dresser_candles',
            area: dresserCandlesArea,
            onTap: (c) => c.say(strF2BedDresserCandles)),
        Hotspot(id: 'embroidery', area: embroideryArea, onTap: tapEmbroidery),
        Hotspot(
            id: 'sewing_basket',
            area: sewingBasketArea,
            onTap: (c) {
              final s = c.s;
              final taken = s.flag('f2_bed_thread_taken');
              if (taken == 0) {
                s.setFlag('f2_bed_thread_taken', 1);
                c.sfx('cloth_rub');
                c.give('thread_blue1');
                c.say(strF2BedBasketThread1);
              } else if (taken == 1) {
                s.setFlag('f2_bed_thread_taken', 2);
                c.sfx('cloth_rub');
                c.give('thread_blue2');
                c.say(strF2BedBasketThread2);
              } else {
                c.say(strF2BedBasketEmpty);
              }
            }),
        Hotspot(
            id: 'ribbon_drawer', area: ribbonDrawerArea, onTap: (c) => c.openCloseup('ribbons')),
      ]),
    ],
    closeups: {
      'mirror': Scene(id: 'mirror', image: 'assets/scenes/f2_bed_mirror.png'),
      'ribbons': Scene(id: 'ribbons', image: 'assets/scenes/f2_bed_ribbons.png'),
      'wardrobe': Scene(
          id: 'wardrobe',
          image: 'assets/scenes/f2_bed_wardrobe.png',
          hotspots: [
            Hotspot(
                id: 'search',
                area: const Rect.fromLTWH(0, 0, 1, 1),
                onTap: tapWardrobeSearch),
          ]),
      'jewelbox': Scene(
          id: 'jewelbox',
          image: 'assets/scenes/f2_bed_jewelbox.png',
          overlays: [
            SceneOverlay(
                image: 'assets/scenes/f2_bed_jewelbox_open.png',
                area: const Rect.fromLTWH(0, 0, 1, 1),
                when: flagSet('f2_bed_jewelbox_open')),
          ]),
      'frame': Scene(
          id: 'frame',
          image: 'assets/scenes/f2_bed_frame.png',
          overlays: [
            // 실을 놓을 때마다 구름이 좌에서 우로 은사로 채워진다(완성본
            // 밴드 크롭). 세 번째 실은 stitch_done의 full 전환이 담당한다.
            for (var i = 0; i < 2; i++)
              SceneOverlay(
                  image: 'assets/scenes/f2_bed_frame_st$i.png',
                  area: [
                    const Rect.fromLTWH(0.3359, 0.6016, 0.1143, 0.2031),
                    const Rect.fromLTWH(0.4502, 0.6016, 0.1143, 0.2031),
                  ][i],
                  when: (s) =>
                      s.flag('f2_bed_stitch_stage') > i &&
                      s.flag('f2_bed_stitch_done') == 0),
            SceneOverlay(
                image: 'assets/scenes/f2_bed_frame_full.png',
                area: const Rect.fromLTWH(0, 0, 1, 1),
                when: flagSet('f2_bed_stitch_done')),
          ]),
      'memory': Scene(
          id: 'memory',
          custom: (_, c) => MemoryPlayer(
                ctx: c,
                pages: const [
                  MemoryPage('assets/scenes/f2_mem2.png', strF2Mem2p1),
                  MemoryPage('assets/scenes/f2_mem2.png', strF2Mem2p2),
                  MemoryPage('assets/scenes/f2_mem2.png', strF2Mem2p3),
                ],
                onDone: () => c.s.closeCloseup(),
              )),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_f2_bed_mirror', title: '거울 속 차이', steps: [
        '이 방엔 "거울에 없는 것"들이 있어요.',
        '실물과 거울상을 번갈아 보며 다른 곳 세 군데를 찾아보세요.',
        '정답: 브로치·머리핀·단추를 찾아 보석함에 넣으세요.',
      ], solved: (s) => s.flag('f2_bed_jewelbox_open') >= 1),
      PuzzleHint(puzzleId: 'p_f2_bed_stitch', title: '미완의 자수', steps: [
        '리본 서랍의 배열이 실을 넣는 순서의 단서예요.',
        '파랑, 은색, 파랑 — 서랍 속 리본 색을 확인해 보세요.',
        '정답: 파랑실 → 은실 → 파랑실 순서로 자수틀에 넣으세요.',
      ], solved: (s) => s.flag('f2_bed_stitch_done') >= 1),
      PuzzleHint(puzzleId: 'p_f2_bed_door', title: '아이 방으로 가는 문', steps: [
        '문은 잠겨 있고, 열쇠가 필요해요.',
        '열쇠는 이 방 어딘가의 함 속에 있을 거예요.',
        '정답: 보석함을 열어 작은 열쇠를 챙기세요.',
      ], solved: (s) => s.flag('f2_bed_done') >= 1),
    ],
  );
}
