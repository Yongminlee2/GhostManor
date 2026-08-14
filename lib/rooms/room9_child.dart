import 'package:flutter/material.dart';
import '../core/game_state.dart';
import '../core/memory_player.dart';
import '../core/models.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──
// 챕터2 전 플래그 f2_child_ 접두어.
//
// 스레드 구조(계획 Task 5): T1 태엽 기차(분기 스위치 3개[좌/우 토글] → 기차
// 출발 → 정답이면 train_sprite.png SceneObject가 트랙을 따라 장난감장 터널로
// 실이동 + 서랍 오버레이 노출 → 서랍에서 gear_toy) ‖ T2 오르골(탭→태엽 감기+
// 고장난 멜로디 → 내부 클로즈업 → gear_toy 장착 → 완주 멜로디 + 뮤직서랍
// 개방 → key_f2lab) → 교차 잠금: T1의 보상 gear_toy가 없으면 T2를 끝낼 수
// 없다(오르골 내부에서 막힘) — 그 외 각 스레드의 초반부(스위치 토글 자체,
// 오르골 감기)는 서로 독립이라 진입 직후 병렬로 만질 수 있다. 분기 단서(침대
// 위 별 모빌 좌·우·좌)는 지식일 뿐 게이트가 아니다 — 모빌을 한 번도 안 봐도
// 스위치만 맞으면 기차는 간다(부정 테스트, 현관 편지·복도 카펫과 동일 원칙).
// 문(방10 서고)은 T2의 다른 보상 key_f2lab으로.

/// 분기 스위치 정답: [좌,우,좌] = [0,1,0] — 침대 위 별 모빌(위→아래 좌·우·좌)
/// 단서와 대응. 기본 그림이 이미 "왼쪽"이라 인덱스 1(가운데 스위치)만 오른쪽
/// (1)으로 넘기면 된다 — 나머지 둘은 손대지 않아야 정답(hall 초상 정렬과
/// 동일한 "성긴 정답 배열" 패턴).
const childSwitchTarget = [0, 1, 0];

/// 스위치 3개(f2_child_sw0~2)가 전부 정답과 일치하는지 — 순수 함수.
bool childSwitchesSolved(GameState s) {
  for (var i = 0; i < 3; i++) {
    if (s.flag('f2_child_sw$i') != childSwitchTarget[i]) return false;
  }
  return true;
}

/// 스위치 i(0~2) 토글. 성공/실패 판정은 기차 출발 시점에만 확인하므로(스위치
/// 자체는 판정하지 않음), 여기서는 상태만 뒤집는다 — 몇 번을 만지고 되돌려도
/// 자유(브리프: "스위치는 유지, 재조정 가능").
void tapChildSwitch(GameState s, int i) {
  final key = 'f2_child_sw$i';
  s.setFlag(key, s.flag(key) == 0 ? 1 : 0);
}

// ── 방 정의 ──

Room buildChild() {
  Cond flagSet(String k) => (s) => s.flag(k) >= 1;

  // 벽면 A(침대+별 모빌) 핫스팟 rect — 납품된 f2_child_a.png 실측 눈대중(정밀
  // 재배선은 계획 Task 9 일괄 검수 몫): 모빌은 천장 중앙, 침대는 하단 중앙,
  // 아이가 그린 액자들은 좌우 벽, 협탁(촛불+장난감집)은 우측. 방10으로 가는
  // 문은 벽 아트 어디에도 그려지지 않았다(아트 의뢰서 방 9 표에 문 언급
  // 없음 — room8의 "벽등 아래 빈 벽 자리를 문으로" 관례와 동일하게 우측
  // 빈 벽을 문으로 쓴다). door를 먼저 선언해 크게 깔고, 그 위 협탁 등
  // 구체적인 소품을 나중에 선언해 그 자리에서 탭 우선권을 갖게 한다(스펙
  // z순서 규칙, room8 door+sconce와 동일 패턴).
  const doorArea = Rect.fromLTWH(0.84, 0.02, 0.16, 0.96);
  const mobileArea = Rect.fromLTWH(0.34, 0.02, 0.34, 0.46);
  const bedArea = Rect.fromLTWH(0.27, 0.55, 0.48, 0.14);
  const blanketArea = Rect.fromLTWH(0.20, 0.69, 0.58, 0.24);
  const wallPicsLeftArea = Rect.fromLTWH(0.02, 0.27, 0.20, 0.36);
  const wallPicsRightArea = Rect.fromLTWH(0.70, 0.27, 0.14, 0.32);
  const nightstandArea = Rect.fromLTWH(0.70, 0.62, 0.29, 0.36);

  // 벽면 B(기차 트랙+장난감장) — f2_child_b_plate.png 실측: 트랙이 하단 중앙
  // (기차 시작 지점)에서 S자로 굽이치며 스위치 3개(교차점의 손잡이 기구)를
  // 지나 상단 중앙 장난감장 밑 터널로 이어진다. 스위치 위치는 원본 이미지에서
  // 오버레이 crop(f2_child_b_sw{1,2,3}r.png, 각 300×270px)이 촬영된 좌표를
  // 실측(스크립트로 후보 crop과 SSD 비교)해 대응시켰다 — 아래에서 위 순서로
  // sw1r(하단)·sw2r(중단)·sw3r(상단, 터널 근접).
  const switch0Area = Rect.fromLTWH(0.174, 0.647, 0.293, 0.176); // 하단 스위치(sw1r)
  const switch1Area = Rect.fromLTWH(0.398, 0.538, 0.293, 0.176); // 중단 스위치(sw2r)
  const switch2Area = Rect.fromLTWH(0.154, 0.447, 0.293, 0.176); // 상단 스위치(sw3r, 터널 근접)
  const switchAreas = [switch0Area, switch1Area, switch2Area];
  // 탭 영역은 크롭(오버레이) rect가 아니라 손잡이 중심으로 좁힌다 — 크롭끼리
  // 세로로 겹쳐 경계 탭이 엉뚱한 스위치를 토글하던 것을 분리(Task 9 재배선).
  const switchTapAreas = [
    Rect.fromLTWH(0.24, 0.685, 0.16, 0.10),
    Rect.fromLTWH(0.465, 0.576, 0.16, 0.10),
    Rect.fromLTWH(0.22, 0.485, 0.16, 0.10),
  ];
  const switchOverlayImages = [
    'assets/scenes/f2_child_b_sw1r.png',
    'assets/scenes/f2_child_b_sw2r.png',
    'assets/scenes/f2_child_b_sw3r.png',
  ];
  const trainStartArea = Rect.fromLTWH(0.30, 0.83, 0.293, 0.117); // 트랙 하단, 출발 지점
  const trainEndArea = Rect.fromLTWH(0.373, 0.342, 0.293, 0.117); // 장난감장 터널 입구
  const drawerArea = Rect.fromLTWH(0.44, 0.37, 0.16, 0.10); // 터널 바로 아래 서랍
  const rockingHorseArea = Rect.fromLTWH(0.02, 0.30, 0.26, 0.19);
  const ballArea = Rect.fromLTWH(0.16, 0.84, 0.12, 0.14);
  const shelfToysArea = Rect.fromLTWH(0.34, 0.13, 0.36, 0.12);
  const windowArea = Rect.fromLTWH(0.86, 0.30, 0.14, 0.20);

  // 벽면 C(책상+오르골+뮤직서랍) — f2_child_c.png 실측: 오르골(태엽 인형)이
  // 책상 중앙, 잠긴 뮤직서랍이 책상 아래 좌측, 촛불이 책상 좌단, 그림책은
  // 우측, 저택 실루엣 액자·작은 초상 2점은 벽 상단, 선반(토끼·인형·인형집)은
  // 좌상단, 곰인형은 바닥.
  const deskShelfArea = Rect.fromLTWH(0.03, 0.06, 0.40, 0.26);
  const manorPictureArea = Rect.fromLTWH(0.56, 0.03, 0.29, 0.25);
  const smallFramesArea = Rect.fromLTWH(0.53, 0.30, 0.32, 0.12);
  const candleDeskArea = Rect.fromLTWH(0.09, 0.48, 0.15, 0.15);
  const musicBoxArea = Rect.fromLTWH(0.28, 0.50, 0.25, 0.23);
  const booksArea = Rect.fromLTWH(0.58, 0.62, 0.29, 0.17);
  const musicDrawerArea = Rect.fromLTWH(0.10, 0.80, 0.39, 0.14);
  const floorToysArea = Rect.fromLTWH(0.0, 0.88, 0.16, 0.12);

  void tapChildSwitchAt(GameCtx c, int i) {
    tapChildSwitch(c.s, i);
    c.sfx('switch_click');
  }

  void tapTrainStart(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_child_train') >= 1) {
      c.say(strF2ChildTrainDone);
      return;
    }
    if (childSwitchesSolved(s)) {
      s.setFlag('f2_child_train', 1);
      c.sfx('wood_slide'); // 기차 주행(Task 8 자체 제작 슬롯)
      c.say(strF2ChildTrainSuccess);
    } else {
      // 실패: 스위치는 절대 건드리지 않는다(리셋 아님) — 기차는 애초에
      // 트랙을 떠난 적 없는 셈이라 rect가 계속 trainStartArea를 가리키는
      // 것 자체가 "SceneObject 원위치" 연출이다(브리프 문구 그대로).
      c.sfx('metal_drop');
      c.say(strF2ChildTrainFail);
    }
  }

  void tapDrawer(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_child_gear_found') == 0) {
      s.setFlag('f2_child_gear_found', 1);
      c.sfx('wood_creak_open');
      c.say(strF2ChildDrawerPeek);
      return;
    }
    if (s.flag('f2_child_gear_taken') >= 1) {
      c.say(strF2ChildDrawerEmpty);
      return;
    }
    s.setFlag('f2_child_gear_taken', 1);
    c.sfx('metal_click');
    c.give('gear_toy');
    c.say(strF2ChildDrawerGive);
  }

  void tapMusicBoxWall(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_child_organ_fixed') >= 1) {
      if (s.flag('f2_child_memory') == 0) s.setFlag('f2_child_memory', 1);
      c.openCloseup('memory');
      return;
    }
    if (s.flag('f2_child_organ_wound') == 0) {
      s.setFlag('f2_child_organ_wound', 1);
      c.sfx('music_box_broken');
      c.say(strF2ChildOrganWind);
      return;
    }
    c.openCloseup('organ');
  }

  void tapOrganFix(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_child_organ_fixed') >= 1) {
      c.say(strF2ChildOrganFixedLook);
      return;
    }
    if (!c.using('gear_toy')) {
      c.say(strF2ChildOrganNeedsGear);
      return;
    }
    c.consume('gear_toy');
    s.setFlag('f2_child_organ_fixed', 1);
    c.sfx('music_box'); // 완주 멜로디(Task 8 자체 제작 슬롯)
    c.give('key_f2lab');
    c.say(strF2ChildOrganFixed);
  }

  void tapMusicDrawer(GameCtx c) {
    c.say(c.s.flag('f2_child_organ_fixed') >= 1
        ? strF2ChildMusicDrawerOpen
        : strF2ChildMusicDrawerLocked);
  }

  void tapDoor(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_child_door_open') >= 1) {
      c.sfx('door_open');
      if (s.flag('f2_child_done') == 0) {
        s.setFlag('f2_child_done', 1);
        c.give('emblem_child');
      }
      return;
    }
    if (!c.using('key_f2lab')) {
      c.sfx('locked');
      c.say(strF2ChildDoorLocked);
      return;
    }
    c.consume('key_f2lab');
    c.sfx('metal_key');
    s.setFlag('f2_child_door_open', 1);
    c.say(strF2ChildDoorOpened);
  }

  return Room(
    id: 'child',
    name: '아이 방',
    onEnter: (c) => c.say(strF2ChildIntro),
    cleared: flagSet('f2_child_done'),
    walls: [
      // 벽면 A: 침대+별 모빌(T1 지식 단서, 게이트 아님) + 낙서 액자들(리액션) + 문.
      Scene(id: 'child_a', image: 'assets/scenes/f2_child_a.png', overlays: [
        // 문이 열리면 어두운 복도가 드러난 열림 그림으로 바뀐다.
        SceneOverlay(
            image: 'assets/scenes/f2_child_a_door_open.png',
            area: const Rect.fromLTWH(0.8262, 0.3783, 0.1738, 0.5521),
            when: flagSet('f2_child_door_open')),
      ], hotspots: [
        Hotspot(id: 'door', area: doorArea, onTap: tapDoor),
        Hotspot(id: 'mobile', area: mobileArea, onTap: (c) => c.say(strF2ChildMobile)),
        Hotspot(id: 'bed', area: bedArea, onTap: (c) => c.say(strF2ChildBed)),
        Hotspot(id: 'blanket', area: blanketArea, onTap: (c) => c.say(strF2ChildBlanket)),
        Hotspot(
            id: 'wall_pics_left',
            area: wallPicsLeftArea,
            onTap: (c) => c.say(strF2ChildWallPicsLeft)),
        Hotspot(
            id: 'wall_pics_right',
            area: wallPicsRightArea,
            onTap: (c) => c.say(strF2ChildWallPicsRight)),
        Hotspot(
            id: 'nightstand', area: nightstandArea, onTap: (c) => c.say(strF2ChildNightstand)),
      ]),
      // 벽면 B: 기차 트랙(T1 핵심) — 스위치 3개 + SceneObject 기차 + 서랍.
      Scene(id: 'child_b', image: 'assets/scenes/f2_child_b_plate.png', objects: [
        SceneObject(
            image: 'assets/scenes/train_sprite.png',
            area: (s) =>
                s.flag('f2_child_train') >= 1 ? trainEndArea : trainStartArea),
      ], overlays: [
        SceneOverlay(
            image: 'assets/scenes/f2_child_b_drawer.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('f2_child_train')),
        for (var i = 0; i < 3; i++)
          SceneOverlay(
              image: switchOverlayImages[i],
              area: switchAreas[i],
              when: (s) => s.flag('f2_child_sw$i') >= 1),
      ], hotspots: [
        Hotspot(
            id: 'rocking_horse',
            area: rockingHorseArea,
            onTap: (c) => c.say(strF2ChildRockingHorse)),
        Hotspot(id: 'ball', area: ballArea, onTap: (c) => c.say(strF2ChildBall)),
        Hotspot(id: 'shelf_toys', area: shelfToysArea, onTap: (c) => c.say(strF2ChildShelf)),
        Hotspot(id: 'window', area: windowArea, onTap: (c) => c.say(strF2ChildWindow)),
        for (var i = 0; i < 3; i++)
          Hotspot(
              id: 'switch${i + 1}',
              area: switchTapAreas[i],
              onTap: (c) => tapChildSwitchAt(c, i)),
        Hotspot(id: 'train_start', area: trainStartArea, onTap: tapTrainStart),
        Hotspot(
            id: 'drawer', area: drawerArea, when: flagSet('f2_child_train'), onTap: tapDrawer),
      ]),
      // 벽면 C: 오르골(T2 핵심) + 뮤직서랍(리액션, 개방은 오르골 수리가 자동
      // 처리) + 책상 소품(리액션).
      Scene(id: 'child_c', image: 'assets/scenes/f2_child_c.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/f2_child_c_open.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('f2_child_organ_fixed')),
      ], hotspots: [
        Hotspot(id: 'desk_shelf', area: deskShelfArea, onTap: (c) => c.say(strF2ChildDeskShelf)),
        Hotspot(
            id: 'manor_picture',
            area: manorPictureArea,
            onTap: (c) => c.say(strF2ChildManorPicture)),
        Hotspot(
            id: 'small_frames',
            area: smallFramesArea,
            onTap: (c) => c.say(strF2ChildSmallFrames)),
        Hotspot(id: 'candle_desk', area: candleDeskArea, onTap: (c) => c.say(strF2ChildCandleDesk)),
        Hotspot(id: 'books', area: booksArea, onTap: (c) => c.say(strF2ChildBooks)),
        Hotspot(id: 'floor_toys', area: floorToysArea, onTap: (c) => c.say(strF2ChildFloorToys)),
        Hotspot(id: 'music_drawer', area: musicDrawerArea, onTap: tapMusicDrawer),
        Hotspot(id: 'music_box', area: musicBoxArea, onTap: tapMusicBoxWall),
      ]),
    ],
    closeups: {
      'organ': Scene(
          id: 'organ',
          image: 'assets/scenes/f2_child_organ.png',
          overlays: [
            SceneOverlay(
                image: 'assets/scenes/f2_child_organ_fixed.png',
                area: const Rect.fromLTWH(0, 0, 1, 1),
                when: flagSet('f2_child_organ_fixed')),
          ],
          hotspots: [
            Hotspot(id: 'fix', area: const Rect.fromLTWH(0, 0, 1, 1), onTap: tapOrganFix),
          ]),
      'memory': Scene(
          id: 'memory',
          custom: (_, c) => MemoryPlayer(
                ctx: c,
                // 회상3은 스토리 바이블에 자막 2페이지만 정의돼 있다(다른
                // 방들은 3페이지) — strings.dart에 strF2Mem3p3는 존재하지
                // 않는다, 2장으로 맞다.
                pages: const [
                  MemoryPage('assets/scenes/f2_mem3.png', strF2Mem3p1),
                  MemoryPage('assets/scenes/f2_mem3.png', strF2Mem3p2),
                ],
                onDone: () => c.s.closeCloseup(),
              )),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_f2_child_train', title: '분기 스위치', steps: [
        '분기 셋을 정해야 해요.',
        '침대 위에서 도는 것들을 보세요.',
        '정답: 좌·우·좌.',
      ], solved: (s) => s.flag('f2_child_train') >= 1),
      PuzzleHint(puzzleId: 'p_f2_child_organ', title: '오르골의 빈 음', steps: [
        '한 음이 비어요.',
        '톱니는 기차가 아는 곳에 있어요.',
        '정답: 기차를 성공시켜 톱니를 얻고, 오르골 바닥에 끼우세요.',
      ], solved: (s) => s.flag('f2_child_organ_fixed') >= 1),
      PuzzleHint(puzzleId: 'p_f2_child_door', title: '서고로 가는 문', steps: [
        '문은 잠겨 있고, 열쇠가 필요해요.',
        '열쇠는 서랍 속에 있을 거예요.',
        '정답: 오르골을 고쳐 뮤직서랍을 열고, 열쇠를 챙기세요.',
      ], solved: (s) => s.flag('f2_child_done') >= 1),
    ],
  );
}
