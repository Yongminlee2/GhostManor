import 'package:flutter/material.dart';
import '../core/game_state.dart';
import '../core/memory_player.dart';
import '../core/models.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──
// 챕터2 전 플래그 f2_seal_ 접두어. 챕터2 마지막 콘텐츠 방 — 문(다음 방)이
// 없다: 이 방 자체가 저택의 마지막 봉인이라, "탈출"은 곧 엔딩 시퀀스다.
//
// 스레드 구조(계획 Task 7): T1 촛불 고리(벽C, 켜진 초 4개를 전부 끄면 —
// 챕터1 거실 촛대 토글 콜백의 단방향 변형, 재점화 없음 — 벽화가 깨어나
// 회상5 재생) ‖ T2 제단(벽A, emblem 4종을 회상 촛불 수 오름차순
// hall(1)→bed(2)→child(3)→lab(4) 순서로 배치) → 제단 완성 후 매듭 3개를
// 위→아래로 순서대로 풀어 봉인 문 개방 → 에드가 등장·대화·유령 작별·엔딩.
// 두 스레드는 서로 완전히 독립(교차 잠금 없음) — 회상5는 지식일 뿐, 제단은
// 회상을 안 보고도 순서만 맞으면 열린다(부정 테스트로 증명).
//
// 매듭 위젯 선택: 브리프가 "RubbableScene 3연속 또는 탭 시퀀스" 중 재량을
// 줬다 — RubbableScene은 매듭마다 별도의 "반쯤 풀린" 원본/오버레이 이미지
// 쌍이 필요한데 art/chapter2-assets.md 방11 표엔 a/a_full/a_open 세 장뿐
// (매듭별 중간 상태 아트 없음). 반면 탭 시퀀스는 attic의 OrganKeys·hall의
// 초상 정렬과 동일한 이미 검증된 패턴이라 신규 아트가 전혀 필요 없다 —
// 그래서 탭 시퀀스를 골랐다(rubKnot, tapOrganKey와 동일 모양).

/// 촛불 i(0~3, 좌상·우상·좌하·우하) 끄기 — 단방향(재점화 없음, 챕터1 거실
/// toggleCandle의 편도 변형). 이미 꺼졌으면 변화 없음. 네 개 모두 꺼지면
/// 촛불고리가 어두워지고(f2_seal_c_dark) 봉인 벽화가 동시에 깨어난다
/// (f2_seal_b_awake) — "봉인을 걸던 밤 촛불을 전부 껐다"는 회상5 내용의
/// 재현(계획 문구). 가운데 다섯째 초는 애초에 꺼져 있어(아트 자체가 4켜짐
/// +1꺼짐) 이 함수가 다루지 않는다.
void snuffCandle(GameState s, int i) {
  final key = 'f2_seal_candle$i';
  if (s.flag(key) >= 1) return;
  s.setFlag(key, 1);
  final allOut =
      List.generate(4, (j) => s.flag('f2_seal_candle$j')).every((v) => v >= 1);
  if (allOut) {
    s.setFlag('f2_seal_c_dark', 1);
    s.setFlag('f2_seal_b_awake', 1);
  }
}

/// 제단 배치 정답 순서 — 회상 촛불 수 오름차순(회상1=1…회상4=4)과 대응하는
/// 방 순서 그대로: hall→bed→child→lab. 상징 아이콘(제단 부조: 사진틀·매듭·
/// 톱니·실린더)도 f2_seal_altar.png에서 이 순서로 좌→우 배치돼 있다.
const _emblemOrder = ['emblem_hall', 'emblem_bed', 'emblem_child', 'emblem_lab'];

/// 제단 홈에 상징 하나 배치(순서 고정 — 순수 함수, room8 stitchThread/
/// room10 pourVial과 동일 관례). 다음 순서와 일치하면 f2_seal_altar_seq
/// +1(4 도달은 호출부가 f2_seal_altar_full로 승격)하고 true. 상징이지만
/// 순서가 틀리면 0으로 리셋하고 false. 상징이 아닌 아이템/미선택/이미
/// 완성이면 아무 것도 바꾸지 않고 false. emblem은 인벤토리에서 소모되지
/// 않는다 — 배치는 플래그일 뿐이라 오답 리셋에도 아이템을 돌려줄 필요가
/// 없고, 완성 시에만 호출부가 4개를 한꺼번에 소모한다(오순서 반환 로직을 없애는 설계 선택).
bool placeEmblem(GameState s, String? itemId) {
  final stage = s.flag('f2_seal_altar_seq');
  if (stage >= _emblemOrder.length) return false;
  if (itemId == null || !_emblemOrder.contains(itemId)) return false;
  if (itemId == _emblemOrder[stage]) {
    s.setFlag('f2_seal_altar_seq', stage + 1);
    return true;
  }
  s.setFlag('f2_seal_altar_seq', 0);
  return false;
}

/// 매듭 i(0=위,1=가운데,2=아래) 문지르기 — 위→아래 순서 고정(순수 함수).
/// 제단이 아직 안 채워졌거나 이미 열렸으면 아무 것도 바꾸지 않고 false
/// ("제단 미완성 매듭 무반응" 부정 테스트가 요구하는 동작). 순서가 맞으면
/// f2_seal_knot_seq +1(3 도달은 호출부가 f2_seal_a_open으로 승격)하고
/// true, 틀리면 0으로 리셋하고 false.
bool rubKnot(GameState s, int i) {
  if (s.flag('f2_seal_altar_full') == 0) return false;
  if (s.flag('f2_seal_a_open') >= 1) return false;
  final seq = s.flag('f2_seal_knot_seq');
  if (seq >= 3) return false;
  if (i == seq) {
    s.setFlag('f2_seal_knot_seq', seq + 1);
    return true;
  }
  s.setFlag('f2_seal_knot_seq', 0);
  return false;
}

/// 에드가 대화 4~5줄 — 마지막 줄은 계획 전문 그대로(스토리 바이블 고정
/// 대사), 앞 네 줄은 톤(다정·미안함·유머 한 스푼)만 지키고 이 구현이 작성.
const _edgarLines = [
  strF2SealEdgarLine1,
  strF2SealEdgarLine2,
  strF2SealEdgarLine3,
  strF2SealEdgarLine4,
  strF2SealEdgarLine5,
];

// ── 방 정의 ──

Room buildSeal() {
  Cond flagSet(String k) => (s) => s.flag(k) >= 1;

  // 벽면 A(제단·매듭·문) — f2_seal_a.png 실측 눈대중(정밀 재배선은 계획
  // Task 9 일괄 검수 몫): 상단 아치 문에 밧줄 매듭 3개(위·가운데·아래,
  // x중앙 정렬), 문 아래 열쇠구멍, 그 아래 돌 제단(홈 4개, 앞면 하단부).
  // 좌우로 5갈래 촛대와 빈 액자, 바닥 양쪽에 초 하나씩. 에드가는 매듭이
  // 풀린 뒤에만 문이 열린 자리(제단 위쪽 중앙)에 나타난다 — 매듭 rect와
  // 넓게 겹치므로 매듭들보다 뒤에 선언해 활성일 때 탭 우선권을 가진다
  // (z순서 규칙, room10 board/safe 상호배타와 동일 원리— 다만 여기는
  // when이 상호 배타가 아니라 시간상 이어지는 단계라 둘 다 true일 일이
  // 없다: 매듭 rect는 a_open 이후에도 계속 활성이라 에드가가 사라진 뒤엔
  // 다시 매듭 rect가 받는다).
  const altarArea = Rect.fromLTWH(0.14, 0.70, 0.72, 0.22);
  const knotTopArea = Rect.fromLTWH(0.28, 0.21, 0.44, 0.09);
  const knotMidArea = Rect.fromLTWH(0.28, 0.40, 0.44, 0.09);
  const knotBottomArea = Rect.fromLTWH(0.28, 0.58, 0.44, 0.09);
  const edgarArea = Rect.fromLTWH(0.34, 0.26, 0.32, 0.44);
  const candelabraLeftArea = Rect.fromLTWH(0.04, 0.46, 0.17, 0.16);
  const candelabraRightArea = Rect.fromLTWH(0.79, 0.46, 0.17, 0.16);
  const frameLeftArea = Rect.fromLTWH(0.0, 0.30, 0.14, 0.17);
  const frameRightArea = Rect.fromLTWH(0.84, 0.20, 0.16, 0.17);
  const floorCandleLeftArea = Rect.fromLTWH(0.0, 0.74, 0.15, 0.22);
  const floorCandleRightArea = Rect.fromLTWH(0.85, 0.72, 0.15, 0.22);
  const keyholeArea = Rect.fromLTWH(0.43, 0.705, 0.14, 0.06);

  // 벽면 B(봉인 벽화) — f2_seal_b.png 실측: 액자형 벽화가 중앙 대부분을
  // 차지(위쪽 절반=저택 실루엣, 아래쪽=다섯 인영), 좌측에 벽등 촛대 하나,
  // 우하단 구석에 이미 꺼진 초(연기만), 하단은 나무 판벽.
  const muralHouseArea = Rect.fromLTWH(0.18, 0.07, 0.68, 0.34);
  const muralFamilyArea = Rect.fromLTWH(0.18, 0.43, 0.68, 0.24);
  const sconceArea = Rect.fromLTWH(0.0, 0.42, 0.16, 0.26);
  const cornerCandleArea = Rect.fromLTWH(0.80, 0.68, 0.20, 0.26);
  const wainscotingArea = Rect.fromLTWH(0.14, 0.70, 0.66, 0.18);

  // 벽면 C(촛불 고리·기록 선반) — f2_seal_c.png 실측: 촛불 원형 고리 5개가
  // 마름모 배치(좌상·우상·가운데·좌하·우하), 가운데만 처음부터 꺼짐. 아래
  // 절반은 책·기록이 꽂힌 낮은 선반(우측에 낡은 음반 하나가 도드라짐).
  const candle0Area = Rect.fromLTWH(0.18, 0.12, 0.24, 0.17); // 좌상
  const candle1Area = Rect.fromLTWH(0.58, 0.12, 0.24, 0.17); // 우상
  const candleCenterArea = Rect.fromLTWH(0.40, 0.255, 0.20, 0.15); // 가운데(이미 꺼짐)
  const candle2Area = Rect.fromLTWH(0.18, 0.37, 0.24, 0.17); // 좌하
  const candle3Area = Rect.fromLTWH(0.58, 0.37, 0.24, 0.17); // 우하
  const shelfBooksArea = Rect.fromLTWH(0.16, 0.58, 0.68, 0.28);
  const shelfRecordArea = Rect.fromLTWH(0.62, 0.72, 0.17, 0.14);
  const rugArea = Rect.fromLTWH(0.05, 0.90, 0.90, 0.08);

  void tapAltarWall(GameCtx c) {
    c.openCloseup('altar');
    c.say(c.s.flag('f2_seal_altar_full') >= 1
        ? strF2SealAltarWallDone
        : strF2SealAltarWallLook);
  }

  void tapAltarGrooves(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_seal_altar_full') >= 1) {
      c.say(strF2SealAltarFullLook);
      return;
    }
    final item = s.selectedItem;
    if (placeEmblem(s, item)) {
      final stage = s.flag('f2_seal_altar_seq');
      if (stage >= _emblemOrder.length) {
        for (final id in _emblemOrder) {
          c.consume(id);
        }
        s.setFlag('f2_seal_altar_full', 1);
        c.sfx('sparkle');
        c.say(strF2SealAltarComplete);
      } else {
        c.sfx('metal_click');
        c.say(stage == 1
            ? strF2SealAltarPlace1
            : stage == 2
                ? strF2SealAltarPlace2
                : strF2SealAltarPlace3);
      }
    } else if (item != null && _emblemOrder.contains(item)) {
      c.sfx('locked');
      c.say(strF2SealAltarWrong);
    } else {
      c.say(strF2SealAltarNeedEmblem);
    }
  }

  void tapKnot(GameCtx c, int i) {
    final s = c.s;
    if (s.flag('f2_seal_a_open') >= 1) {
      c.say(strF2SealKnotAfterOpen);
      return;
    }
    if (s.flag('f2_seal_altar_full') == 0) {
      c.say(strF2SealKnotLocked);
      return;
    }
    if (rubKnot(s, i)) {
      final seq = s.flag('f2_seal_knot_seq');
      if (seq >= 3) {
        s.setFlag('f2_seal_a_open', 1);
        c.sfx('unlock');
        c.say(strF2SealKnotOpen);
      } else {
        c.sfx('cloth_rub');
        c.say(seq == 1 ? strF2SealKnotProgress1 : strF2SealKnotProgress2);
      }
    } else {
      c.sfx('locked');
      c.say(strF2SealKnotWrong);
    }
  }

  void tapEdgar(GameCtx c) {
    final s = c.s;
    final lines = s.flag('f2_seal_edgar_lines');
    if (lines >= _edgarLines.length) {
      c.openCloseup('farewell');
      return;
    }
    s.setFlag('f2_seal_edgar_lines', lines + 1);
    c.say(_edgarLines[lines]);
  }

  void tapMuralPart(GameCtx c, String dormantLine) {
    final s = c.s;
    if (s.flag('f2_seal_b_awake') >= 1) {
      if (s.flag('f2_seal_memory') == 0) s.setFlag('f2_seal_memory', 1);
      c.openCloseup('memory');
    } else {
      c.say(dormantLine);
    }
  }

  void tapCandleAt(GameCtx c, int i) {
    final s = c.s;
    if (s.flag('f2_seal_candle$i') >= 1) {
      c.say(strF2SealCandleAlreadyOut);
      return;
    }
    snuffCandle(s, i);
    if (s.flag('f2_seal_b_awake') >= 1) {
      c.sfx('sparkle');
      c.say(strF2SealMuralAwake);
    } else {
      c.sfx('metal_click');
      c.say(strF2SealCandleSnuff);
    }
  }

  void tapEndingContinue(GameCtx c) {
    c.sfx('door_open');
    c.s.setFlag('f2_seal_done', 1);
    c.s.closeCloseup();
  }

  return Room(
    id: 'seal',
    name: '봉인의 방',
    onEnter: (c) => c.say(strF2SealIntro),
    cleared: flagSet('f2_seal_done'),
    walls: [
      // 벽면 A: 제단(T2) + 매듭 3개(제단 완성 후) + 에드가(매듭 이후) + 장식.
      Scene(id: 'seal_a', image: 'assets/scenes/f2_seal_a.png', overlays: [
        // 상징 단계별 표시: 놓은 개수만큼 제단 팔각판에 새겨진다(완성본 크롭).
        // 4개째엔 full 전환이 덮으므로 1~3 진행 구간에만 살아 있다.
        for (var i = 0; i < 4; i++)
          SceneOverlay(
              image: 'assets/scenes/f2_seal_a_sym$i.png',
              area: [
                const Rect.fromLTWH(0.1992, 0.6803, 0.1230, 0.1042),
                const Rect.fromLTWH(0.3604, 0.6836, 0.1279, 0.1042),
                const Rect.fromLTWH(0.5215, 0.6868, 0.1182, 0.1009),
                const Rect.fromLTWH(0.6826, 0.6836, 0.1084, 0.1009),
              ][i],
              when: (s) =>
                  s.flag('f2_seal_altar_seq') > i &&
                  s.flag('f2_seal_altar_full') == 0),
        SceneOverlay(
            image: 'assets/scenes/f2_seal_a_full.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('f2_seal_altar_full')),
        SceneOverlay(
            image: 'assets/scenes/f2_seal_a_open.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('f2_seal_a_open')),
      ], idles: [
        IdleSprite(
            image: 'assets/scenes/edgar_ghost.png',
            area: edgarArea,
            when: (s) => s.flag('f2_seal_a_open') >= 1 && s.flag('f2_seal_done') == 0,
            bobPx: 6),
      ], hotspots: [
        Hotspot(id: 'altar', area: altarArea, onTap: tapAltarWall),
        Hotspot(id: 'knot_top', area: knotTopArea, onTap: (c) => tapKnot(c, 0)),
        Hotspot(id: 'knot_mid', area: knotMidArea, onTap: (c) => tapKnot(c, 1)),
        Hotspot(id: 'knot_bottom', area: knotBottomArea, onTap: (c) => tapKnot(c, 2)),
        Hotspot(
            id: 'edgar',
            area: edgarArea,
            when: (s) => s.flag('f2_seal_a_open') >= 1 && s.flag('f2_seal_done') == 0,
            onTap: tapEdgar),
        Hotspot(
            id: 'candelabra_left',
            area: candelabraLeftArea,
            onTap: (c) => c.say(strF2SealCandelabra)),
        Hotspot(
            id: 'candelabra_right',
            area: candelabraRightArea,
            onTap: (c) => c.say(strF2SealCandelabra)),
        Hotspot(id: 'frame_left', area: frameLeftArea, onTap: (c) => c.say(strF2SealFrameEmpty)),
        Hotspot(
            id: 'frame_right', area: frameRightArea, onTap: (c) => c.say(strF2SealFrameEmpty)),
        Hotspot(
            id: 'floor_candle_left',
            area: floorCandleLeftArea,
            onTap: (c) => c.say(strF2SealFloorCandle)),
        Hotspot(
            id: 'floor_candle_right',
            area: floorCandleRightArea,
            onTap: (c) => c.say(strF2SealFloorCandle)),
        Hotspot(id: 'keyhole', area: keyholeArea, onTap: (c) => c.say(strF2SealKeyhole)),
      ]),
      // 벽면 B: 봉인 벽화(T1 목적지) — 촛불 4개를 다 끄면 깨어나 회상5 앵커가 된다.
      Scene(id: 'seal_b', image: 'assets/scenes/f2_seal_b.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/f2_seal_b_awake.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('f2_seal_b_awake')),
      ], hotspots: [
        Hotspot(
            id: 'mural_house',
            area: muralHouseArea,
            onTap: (c) => tapMuralPart(c, strF2SealMuralHouseDormant)),
        Hotspot(
            id: 'mural_family',
            area: muralFamilyArea,
            onTap: (c) => tapMuralPart(c, strF2SealMuralFamilyDormant)),
        Hotspot(id: 'sconce', area: sconceArea, onTap: (c) => c.say(strF2SealSconce)),
        Hotspot(
            id: 'corner_candle', area: cornerCandleArea, onTap: (c) => c.say(strF2SealCornerCandle)),
        Hotspot(
            id: 'wainscoting', area: wainscotingArea, onTap: (c) => c.say(strF2SealWainscoting)),
      ]),
      // 벽면 C: 촛불 고리 5개(T1 핵심, 가운데는 이미 꺼짐) + 기록 선반(리액션).
      Scene(id: 'seal_c', image: 'assets/scenes/f2_seal_c.png', overlays: [
        // 개별 소등: 끈 초마다 즉시 꺼진 그림(완성본 크롭+페더)이 얹힌다 —
        // 3개까지 무반응이던 실기기 지적 해소. 4개째엔 전체 dark가 덮는다.
        for (var i = 0; i < 4; i++)
          SceneOverlay(
              image: 'assets/scenes/f2_seal_c_out$i.png',
              area: [
                const Rect.fromLTWH(0.18, 0.12, 0.24, 0.17),
                const Rect.fromLTWH(0.58, 0.12, 0.24, 0.17),
                const Rect.fromLTWH(0.18, 0.37, 0.24, 0.17),
                const Rect.fromLTWH(0.58, 0.37, 0.24, 0.17),
              ][i],
              when: (s) =>
                  s.flag('f2_seal_candle$i') >= 1 &&
                  s.flag('f2_seal_c_dark') == 0),
        SceneOverlay(
            image: 'assets/scenes/f2_seal_c_dark.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('f2_seal_c_dark')),
      ], hotspots: [
        Hotspot(id: 'candle0', area: candle0Area, onTap: (c) => tapCandleAt(c, 0)),
        Hotspot(id: 'candle1', area: candle1Area, onTap: (c) => tapCandleAt(c, 1)),
        Hotspot(
            id: 'candle_center',
            area: candleCenterArea,
            onTap: (c) => c.say(strF2SealCandleCenterOut)),
        Hotspot(id: 'candle2', area: candle2Area, onTap: (c) => tapCandleAt(c, 2)),
        Hotspot(id: 'candle3', area: candle3Area, onTap: (c) => tapCandleAt(c, 3)),
        Hotspot(id: 'shelf_books', area: shelfBooksArea, onTap: (c) => c.say(strF2SealShelfBooks)),
        Hotspot(
            id: 'shelf_record', area: shelfRecordArea, onTap: (c) => c.say(strF2SealShelfRecord)),
        Hotspot(id: 'rug', area: rugArea, onTap: (c) => c.say(strF2SealRug)),
      ]),
    ],
    closeups: {
      'altar': Scene(id: 'altar', image: 'assets/scenes/f2_seal_altar.png', hotspots: [
        Hotspot(id: 'grooves', area: const Rect.fromLTWH(0, 0, 1, 1), onTap: tapAltarGrooves),
      ]),
      'memory': Scene(
          id: 'memory',
          custom: (_, c) => MemoryPlayer(
                ctx: c,
                pages: const [
                  MemoryPage('assets/scenes/f2_mem5.png', strF2Mem5p1),
                  MemoryPage('assets/scenes/f2_mem5.png', strF2Mem5p2),
                  MemoryPage('assets/scenes/f2_mem5.png', strF2Mem5p3),
                ],
                onDone: () => c.s.closeCloseup(),
              )),
      // 유령들의 작별 — MemoryPlayer를 "회상"이 아니라 "탭마다 다음 인물"
      // 연출로 재사용(계획이 명시적으로 허용: "MemoryPlayer 재사용 재량").
      // 고스포·부우는 실제 투명 스프라이트가 있어 그대로 쓰고, 덜덜·국자·
      // 안경 쓴 유령은 챕터1에 전용 스프라이트가 없어(대사만 존재) 마지막
      // 페이지에서 깨어난 벽화(다섯 인영이 빛나는 f2_seal_b_awake.png)를
      // 배경 삼아 세 이름을 함께 호명한다 — 새 아트 파일을 지어내 라벨
      // 폴백으로 방치하는 대신, 이미 도착한 진짜 그림만 쓰는 선택.
      'farewell': Scene(
          id: 'farewell',
          custom: (_, c) => MemoryPlayer(
                ctx: c,
                pages: const [
                  MemoryPage('assets/scenes/ghost_butler.png', strF2SealFarewellGhospo),
                  MemoryPage('assets/scenes/living_b_boo_sofa.png', strF2SealFarewellBoo),
                  MemoryPage('assets/scenes/f2_seal_b_awake.png', strF2SealFarewellOthers),
                ],
                onDone: () => c.s.openCloseup('ending'),
              )),
      'ending': Scene(id: 'ending', image: 'assets/scenes/f2_ending_morning.png', hotspots: [
        Hotspot(id: 'continue', area: const Rect.fromLTWH(0, 0, 1, 1), onTap: tapEndingContinue),
      ]),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_f2_seal_candles', title: '벽화의 촛불', steps: [
        '이 방의 초는 켜는 게 아니에요.',
        '켜진 초 넷을 전부 꺼 보세요.',
        '정답: 촛불 네 개를 모두 소등하면 벽화가 깨어납니다.',
      ], solved: (s) => s.flag('f2_seal_b_awake') >= 1),
      PuzzleHint(puzzleId: 'p_f2_seal_altar', title: '제단의 상징', steps: [
        '상징들엔 순서가 있어요.',
        '회상 속 그림들의 촛불 개수를 세어보세요.',
        '정답: 사진틀 → 매듭 → 톱니 → 실린더 순서로 배치하세요.',
      ], solved: (s) => s.flag('f2_seal_altar_full') >= 1),
      PuzzleHint(puzzleId: 'p_f2_seal_knot', title: '봉인의 매듭', steps: [
        '제단이 채워지면 매듭을 풀 수 있어요.',
        '위에서부터 순서대로 문질러 보세요.',
        '정답: 위 → 가운데 → 아래 순서로 매듭을 문지르세요.',
      ], solved: (s) => s.flag('f2_seal_a_open') >= 1),
    ],
  );
}
