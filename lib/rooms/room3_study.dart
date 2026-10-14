import 'package:flutter/widgets.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/rub_scene.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──
// 리마스터: 전 플래그 study_r_ 접두어 (구세이브의 study_* 와 충돌 차단).
//
// 스레드 구조(브리프): T1 별자리 관측(망원경 — 렌즈 필요 — → 별 배열 관측 →
// 지도 대조 → 지구본 3탭) ‖ T2 문양-색 변환 책 순서(잉크 종이의 문양 4개 순서
// → 책등 각인으로 색 순서 변환 → 색 책 탭) → 교차: T2 숨은공간에서 나오는
// 렌즈가 T1(망원경)의 전제 조건. 문: 열쇠(T1 지구본 보상) + 기름(거실에서
// 이어온 아이템, 기존 이중 잠금 유지).

/// 책 i(1=빨강,2=파랑,3=노랑,4=초록) 탭. 정답 순서(파→초→빨→노 = 2,4,1,3 —
/// 잉크 종이의 문양 순서 꽃→나무→새→뱀을 책등 각인(빨=새·파=꽃·노=뱀·초=나무)으로
/// 옮긴 것과 동일)대로면 study_r_book_seq +1, 틀리면 0으로 리셋.
/// 4단계 도달 시 study_r_nook_open=1. nook_open 후엔 no-op.
void tapBook(GameState s, int i) {
  if (s.flag('study_r_nook_open') >= 1) return;
  const order = [2, 4, 1, 3];
  final seq = s.flag('study_r_book_seq');
  if (order[seq] == i) {
    final next = seq + 1;
    s.setFlag('study_r_book_seq', next);
    if (next == 4) s.setFlag('study_r_nook_open', 1);
  } else {
    s.setFlag('study_r_book_seq', 0);
  }
}

/// 지구본 상단 화살표 탭(순수 로직). taps 1→2→3까지 증가하며 정확히 3이면
/// 개방 상태(SceneObject가 반쪽을 벌린다) — 이미 3인데 또 탭하면(=4번째,
/// 지도를 안 보고 무작정 연타한 경우) 0으로 리셋돼 다시 닫힌다. 열쇠를 이미
/// 얻었으면(study_r_got_key) no-op — 화살표는 더 이상 taps를 바꾸지 않는다.
void tapGlobeArrow(GameState s) {
  if (s.flag('study_r_got_key') >= 1) return;
  final next = s.flag('study_r_globe_taps') + 1;
  s.setFlag('study_r_globe_taps', next > 3 ? 0 : next);
}

// ── 방 정의 ──

Room buildStudy() {
  Cond flagSet(String k) => (s) => s.flag(k) >= 1;
  Cond flagZero(String k) => (s) => s.flag(k) == 0;
  bool always(GameState s) => true; // 책등 각인 오버레이 4장은 상시 표시

  const bookRedArea = Rect.fromLTWH(0.16, 0.22, 0.10, 0.11);
  const bookBlueArea = Rect.fromLTWH(0.35, 0.22, 0.10, 0.11);
  const bookYellowArea = Rect.fromLTWH(0.56, 0.22, 0.10, 0.11);
  const bookGreenArea = Rect.fromLTWH(0.75, 0.22, 0.10, 0.11);
  const nookArea = Rect.fromLTWH(0.40, 0.46, 0.20, 0.18);
  const nedArea = Rect.fromLTWH(0.72, 0.60, 0.18, 0.26);
  const lowerShelfArea = Rect.fromLTWH(0.02, 0.50, 0.24, 0.30);
  const paperArea = Rect.fromLTWH(0.02, 0.62, 0.26, 0.12);
  const doorArea = Rect.fromLTWH(0.62, 0.24, 0.26, 0.46);
  const deskArea = Rect.fromLTWH(0.04, 0.74, 0.24, 0.12);
  const shelfTopArea = Rect.fromLTWH(0.02, 0.04, 0.50, 0.14);
  // 벽 C rect — study_c.png 실측(망원경 좌중앙, 지도 액자 좌상단, 창 중앙,
  // 지구의 모형은 책상 위). 창은 큰 풍미 rect라 선언을 앞에 둔다(z순서).
  const telescopeArea = Rect.fromLTWH(0.19, 0.38, 0.30, 0.28);
  const starmapArea = Rect.fromLTWH(0.02, 0.13, 0.24, 0.25);
  const windowArea = Rect.fromLTWH(0.36, 0.08, 0.36, 0.48);
  const globeReplicaArea = Rect.fromLTWH(0.55, 0.46, 0.16, 0.15);

  // 지구본 반쪽 2개(SceneObject) — 닫힘 위치는 리마스터 전 지구본 핫스팟 rect
  // (0.16,0.40,0.26,0.22)에서 유도: 그 중심(x=0.29)에서 좌우로 스프라이트
  // 실측 비율(184×307px → 벽 1024×1536 기준 폭 0.18·높이 0.20)만큼 맞닿게
  // 배치한다. 개방(taps==3)되면 ±0.06 벌어져 study_b_plate.png에 미리 그려진
  // 열쇠가 틈으로 드러난다.
  // 아이폰판: 반쪽 스프라이트를 study_b.png(지구본 있음) - study_b_plate.png(없음)
  // 으로 잘라 다시 만들었다(tool/art_fix/remaster.py globe). 닫히면 원래 그림과
  // 픽셀까지 같고, 좌표도 그 잘라 낸 자리 그대로다.
  const globeCenterX = 0.3096;
  const globeTop = 0.3919;
  const globeLeftW = 0.1338;
  const globeRightW = 0.1357;
  const globeHalfH = 0.1829;
  const globeGapPx = 0.06;
  bool globeOpen(GameState s) => s.flag('study_r_globe_taps') == 3;
  Rect globeLeftRect(GameState s) => Rect.fromLTWH(
      globeCenterX - globeLeftW - (globeOpen(s) ? globeGapPx : 0),
      globeTop,
      globeLeftW,
      globeHalfH);
  Rect globeRightRect(GameState s) => Rect.fromLTWH(
      globeCenterX + (globeOpen(s) ? globeGapPx : 0),
      globeTop,
      globeRightW,
      globeHalfH);
  // 화살표(회전 탭) 핫스팟 — 반쪽 이동 범위 전체를 덮는 고정 영역(닫힘·열림
  // 어느 위치에서도 탭 가능).
  const globeArrowArea = Rect.fromLTWH(0.11, 0.40, 0.40, 0.08);
  // 열렸을 때(taps==3)만 드러나는 중앙 틈 — 여기를 탭해야 열쇠를 꺼낸다.
  // 화살표와 달리 이 탭은 taps를 건드리지 않아, 화살표를 한 번 더 눌러
  // "4번째"를 만들어 버리는 실수와 분리된다.
  const globeGapArea = Rect.fromLTWH(0.25, 0.43, 0.12, 0.15);

  // 책 4권 공용: tapBook 진행 + 클릭음, 리셋되면 대사, nook 완성 순간 추가 피드백.
  void tapBookSpot(GameCtx c, int i) {
    final beforeSeq = c.s.flag('study_r_book_seq');
    final wasOpen = c.s.flag('study_r_nook_open') >= 1;
    tapBook(c.s, i);
    c.sfx('book_flip');
    if (!wasOpen && c.s.flag('study_r_nook_open') >= 1) {
      c.sfx('unlock');
      c.say(strStudyNookOpen);
    } else if (c.s.flag('study_r_book_seq') == 0 && beforeSeq > 0) {
      c.say(strStudyBookReset);
    }
  }

  // 지구본 화살표 공용: 탭 카운트 + 클릭음, 3탭째 개방 대사, 4탭째(오차) 리셋 대사.
  void tapGlobeArrowSpot(GameCtx c) {
    final s = c.s;
    if (s.flag('study_r_got_key') >= 1) {
      c.say(strStudyRGlobeQuiet);
      return;
    }
    final before = s.flag('study_r_globe_taps');
    tapGlobeArrow(s);
    c.sfx('metal_click');
    final after = s.flag('study_r_globe_taps');
    if (after == 3) {
      c.say(strStudyGlobeOpen);
    } else if (before == 3 && after == 0) {
      c.say(strStudyRGlobeReset);
    }
  }

  return Room(
    id: 'study',
    name: '서재',
    onEnter: (c) => c.say(strStudyIntro),
    cleared: flagSet('study_r_done'),
    walls: [
      // 벽면 A: 책장 벽 (기존 아트 재사용 + 책등 문양 각인 오버레이 4장)
      Scene(id: 'study_a', image: 'assets/scenes/study_a.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/study_a_book_red.png',
            area: bookRedArea,
            when: always),
        SceneOverlay(
            image: 'assets/scenes/study_a_book_blue.png',
            area: bookBlueArea,
            when: always),
        SceneOverlay(
            image: 'assets/scenes/study_a_book_yellow.png',
            area: bookYellowArea,
            when: always),
        SceneOverlay(
            image: 'assets/scenes/study_a_book_green.png',
            area: bookGreenArea,
            when: always),
        SceneOverlay(
            image: 'assets/scenes/study_a_nook_open2.png',
            area: nookArea,
            when: flagSet('study_r_nook_open'),
            motion: OverlayMotion.slideDown),
      ], hotspots: [
        Hotspot(
            id: 'book_red',
            area: bookRedArea,
            when: flagZero('study_r_nook_open'),
            onTap: (c) => tapBookSpot(c, 1)),
        Hotspot(
            id: 'book_blue',
            area: bookBlueArea,
            when: flagZero('study_r_nook_open'),
            onTap: (c) => tapBookSpot(c, 2)),
        Hotspot(
            id: 'book_yellow',
            area: bookYellowArea,
            when: flagZero('study_r_nook_open'),
            onTap: (c) => tapBookSpot(c, 3)),
        Hotspot(
            id: 'book_green',
            area: bookGreenArea,
            when: flagZero('study_r_nook_open'),
            onTap: (c) => tapBookSpot(c, 4)),
        Hotspot(
            id: 'nook',
            area: nookArea,
            when: (s) =>
                s.flag('study_r_nook_open') >= 1 &&
                s.flag('study_r_got_lens') == 0,
            onTap: (c) {
              c.sfx('wood_slide');
              c.give('lens');
              c.give('note2');
              c.s.setFlag('study_r_got_lens', 1);
              c.say(strStudyRNookLoot);
            }),
        Hotspot(
            id: 'lower_shelf',
            area: lowerShelfArea,
            onTap: (c) => c.say(strStudyRLowerShelf)),
        Hotspot(
            id: 'ned',
            area: nedArea,
            onTap: (c) {
              c.sfx('ghost_giggle');
              c.say(strStudyNed);
            }),
      ]),
      // 벽면 B: 책상·지구본·문 벽 (배경판 study_b_plate.png — 지구본 몸통을
      // 제거하고 받침대만 유지, 갈라진 틈에 열쇠를 미리 그려 넣은 판)
      Scene(
          id: 'study_b',
          image: 'assets/scenes/study_b_plate.png',
          objects: [
            SceneObject(
                image: 'assets/scenes/study_globe_left.png',
                area: globeLeftRect),
            SceneObject(
                image: 'assets/scenes/study_globe_right.png',
                area: globeRightRect),
          ],
          overlays: [
            SceneOverlay(
                image: 'assets/scenes/study_b_door_open.png',
                area: const Rect.fromLTWH(0.5938, 0.1745, 0.3516, 0.4648),
                when: flagSet('study_r_done'),
                motion: OverlayMotion.grow),
          ],
          hotspots: [
            Hotspot(
                id: 'paper',
                area: paperArea,
                onTap: (c) {
                  c.sfx('paper_rustle');
                  c.openCloseup('paper');
                }),
            Hotspot(
                id: 'shelf_top',
                area: shelfTopArea,
                onTap: (c) => c.say(strStudyRShelfTop)),
            Hotspot(
                id: 'globe_arrow',
                area: globeArrowArea,
                onTap: tapGlobeArrowSpot),
            // gap은 arrow와 상단 구간이 겹친다 — 반드시 arrow보다 뒤에 선언해
            // 열림(taps==3) 상태에서 겹침 탭이 gap(열쇠 수령)으로 풀리게 한다
            // (z순서 의존 — room3_study_test의 열림 상태 히트테스트가 고정).
            Hotspot(
                id: 'globe_gap',
                area: globeGapArea,
                when: (s) =>
                    s.flag('study_r_globe_taps') == 3 &&
                    s.flag('study_r_got_key') == 0,
                onTap: (c) {
                  c.sfx('metal_key');
                  c.give('key_study');
                  c.s.setFlag('study_r_got_key', 1);
                  c.say(strStudyGlobeKey);
                }),
            Hotspot(
                id: 'door',
                area: doorArea,
                onTap: (c) {
                  final s = c.s;
                  final unlocked = s.flag('study_r_door_unlocked') >= 1;
                  final oiled = s.flag('study_r_door_oiled') >= 1;
                  if (unlocked && oiled) {
                    c.sfx('door_open');
                    s.setFlag('study_r_done', 1);
                  } else if (c.using('key_study')) {
                    c.consume('key_study');
                    c.sfx('metal_key');
                    s.setFlag('study_r_door_unlocked', 1);
                    c.say(strStudyDoorUnlocked);
                  } else if (c.using('oil')) {
                    c.consume('oil');
                    c.sfx('liquid_pour');
                    s.setFlag('study_r_door_oiled', 1);
                    c.say(strStudyDoorOiled);
                  } else if (unlocked && !oiled) {
                    c.sfx('locked');
                    c.say(strStudyDoorSqueak);
                  } else {
                    c.sfx('locked');
                    c.say(strStudyDoorLocked);
                  }
                }),
            Hotspot(
                id: 'desk', area: deskArea, onTap: (c) => c.say(strStudyDesk)),
          ]),
      // 벽면 C: 관측 창가 (신규)
      Scene(id: 'study_c', image: 'assets/scenes/study_c.png', hotspots: [
        // 창(큰 풍미 rect)을 먼저 — 뒤 선언인 망원경·지구의가 겹침에서 이긴다.
        Hotspot(
            id: 'window', area: windowArea, onTap: (c) => c.say(strStudyRWindow)),
        Hotspot(
            id: 'telescope',
            area: telescopeArea,
            onTap: (c) {
              final s = c.s;
              if (s.flag('study_r_telescope_lens') >= 1) {
                c.openCloseup('stars');
              } else if (c.using('lens')) {
                c.consume('lens');
                s.setFlag('study_r_telescope_lens', 1);
                c.sfx('metal_click');
                c.say(strStudyRTelescopeLensIn);
              } else {
                c.say(strStudyRTelescopeNoLens);
              }
            }),
        Hotspot(
            id: 'starmap_frame',
            area: starmapArea,
            onTap: (c) {
              c.sfx('paper_rustle');
              c.openCloseup('starmap');
            }),
        Hotspot(
            id: 'globe_replica',
            area: globeReplicaArea,
            onTap: (c) => c.say(strStudyRGlobeReplica)),
      ]),
    ],
    closeups: {
      'paper': Scene(
          id: 'paper',
          custom: (_, c) => RubbableScene(
                ctx: c,
                baseImage: 'assets/scenes/study_paper_clean2.png',
                coverImage: 'assets/scenes/study_paper_ink.png',
                cleaned: (s) => s.flag('study_r_paper_rubbed') >= 1,
                onCleaned: (c) {
                  c.s.setFlag('study_r_paper_rubbed', 1);
                  c.sfx('sparkle');
                },
                gestureKey: const Key('paper_rub'),
              )),
      'stars': Scene(id: 'stars', image: 'assets/scenes/study_stars.png'),
      'starmap':
          Scene(id: 'starmap', image: 'assets/scenes/study_starmap.png'),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_study_r_books', title: '문양과 책', steps: [
        '얼룩 종이의 문양들은 책과 연결돼요',
        '책등의 작은 각인과 대조 — 문양 순서를 색 순서로',
        '정답: 파→초→빨→노',
      ], solved: (s) => s.flag('study_r_nook_open') >= 1),
      PuzzleHint(puzzleId: 'p_study_r_stars', title: '별자리와 지구본', steps: [
        '망원경엔 빠진 부품이',
        '숨은공간의 렌즈. 관측한 별 모양을 지도에서 찾으면 옆에 조작법이',
        '정답: W자=여우자리, 화살표 셋 = 지구본 3탭',
      ], solved: (s) => s.flag('study_r_got_key') >= 1),
      PuzzleHint(puzzleId: 'p_study_r_door', title: '녹슨 문', steps: [
        '이 문은 자물쇠 말고도 문제가 하나 더 있어요',
        '열쇠로 잠금을 풀어도 경첩이 녹슬어 안 열려요. 지난 방에서 챙긴 물건 중에 도움이 될 것이?',
        '정답: 거실 비밀칸의 기름병을 문에 사용한 뒤, 서재 열쇠로 열기',
      ], solved: (s) => s.flag('study_r_done') >= 1),
    ],
  );
}
