import 'package:flutter/material.dart';
import '../core/dial_safe.dart';
import '../core/game_state.dart';
import '../core/memory_player.dart';
import '../core/models.dart';
import '../core/rub_scene.dart';
import '../core/scene_view.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──
// 챕터2 전 플래그 f2_lab_ 접두어.
//
// 스레드 구조(계획 Task 6): T1 축음기·관측 장치(실린더 3개 수집 → 축음기
// 클로즈업 축에 얹어 재생 — 각 실린더가 고유한 의성어 소리를 냄(청각 공정) →
// 소리 반복 횟수를 실린더 순서[1,2,3]대로 읽으면 241 → 관측 장치 다이얼
// (DialSafe) → 성공 시 장치 기동 + 벽 금고 노출 → 금고에서 key_f2seal) ‖
// T2 약병·숨은 잉크(칠판 문지르기[지식 — 게이트 아님]로 배합 그림 확인 →
// 약병 3개를 램프에 보라→초록→호박 순서로 투입 → 램프가 보랏빛으로 타오름
// → 빈 편지지에 글씨가 떠오르며 편지 전문 공개 → 재탭으로 회상4) → 교차:
// 실린더2는 책상 서랍 속인데 서랍은 잠겨 있고, 여는 열쇠고리는 T2 구역인
// 약병 선반 뒤에 있다 — T1을 완주하려면 T2 구역을 한 번은 들러야 한다.
// 문(방11)은 이 방이 스스로 생산한 key_f2seal로 연다(hall이 key_f2bed를,
// bed가 key_f2child를, child가 key_f2lab을 만들어 자기 문에 쓰는 것과 동일
// 관례 — 각 열쇠 이름은 "어느 방에서 났나"가 아니라 "어디로 가는가"를
// 가리킨다). 방10 자체의 입장은 room9의 문 통과로 이미 이뤄진 뒤라 이
// 파일은 key_f2lab을 전혀 참조하지 않는다.

/// 실린더 3개의 고유 재생 대사(청각 공정 — 숫자는 절대 아라비아로 쓰지 않고
/// 의성어 반복 횟수로만 표현: 종 2번/물방울 4번/새 1번). 인덱스는 실린더
/// 번호-1과 대응(cylinder1→종, cylinder2→물방울, cylinder3→새) — 거치대에
/// 각인된 점 1·2·3개 순서 그대로가 다이얼 코드 자릿값 순서다(라벨 순서 변환).
const _cylinderIds = ['cylinder1', 'cylinder2', 'cylinder3'];
const _cylinderPlayLines = [
  strF2LabCylinder1Play,
  strF2LabCylinder2Play,
  strF2LabCylinder3Play,
];

/// 관측 장치 다이얼 정답 확인 성공 시 1회 호출(DialSafe의 원샷 가드가 감싼다).
/// 코드 241 = [종2, 물4, 새1](실린더1·2·3 순서 그대로). 금고 자체는 여기서
/// 열리지 않는다 — 장치 기동이 벽 금고의 존재를 드러낼 뿐, 실제 수령은
/// 노출된 safe 핫스팟을 따로 탭해야 한다(계획 "다이얼 아님 — 장치 기동이
/// 곧 개방"을, 샹들리에→바닥 열쇠 줍기와 같은 이단계 수령으로 구현).
void awakenDevice(GameCtx c) {
  final s = c.s;
  s.setFlag('f2_lab_b_awake', 1);
  c.sfx('sparkle');
  c.say(strF2LabDeviceAwake);
}

/// RubbableScene의 onCleaned가 호출하는 순수 함수(room7 finishRugRoll과 동일
/// 관례). 칠판은 지식일 뿐 게이트가 아니다 — 안 닦아도 약병을 정순서로
/// 부으면 램프는 정상적으로 반응한다(부정 테스트로 별도 확인).
void finishBoardClean(GameState s) => s.setFlag('f2_lab_board_clean', 1);

const _vialOrder = ['vial_purple', 'vial_green', 'vial_amber'];

/// 램프에 약병 하나 투입(순서: 보라→초록→호박 — 순수 함수, room8
/// stitchThread와 동일 관례). 다음 순서와 일치하면 f2_lab_lamp_stage +1(3
/// 도달은 호출부가 f2_lab_c_lamp로 승격) 하고 true. 순서가 틀리면 0으로
/// 리셋하고 false. 약병이 아닌 아이템/미선택/이미 완성이면 아무 것도 바꾸지
/// 않고 false(그 경우의 반응은 호출부인 tapLamp의 몫).
bool pourVial(GameState s, String? itemId) {
  if (itemId == null || !_vialOrder.contains(itemId)) return false;
  final stage = s.flag('f2_lab_lamp_stage');
  if (stage >= _vialOrder.length) return false;
  if (itemId == _vialOrder[stage]) {
    s.setFlag('f2_lab_lamp_stage', stage + 1);
    return true;
  }
  // 오답이어도 단계 유지 — 정답 약병은 영구 소모(각 1병)라 리셋하면
  // 복구 불가 소프트락(주방 냄비·안방 자수와 동일 원칙).
  return false;
}

// ── 방 정의 ──

Room buildLab() {
  Cond flagSet(String k) => (s) => s.flag(k) >= 1;
  Cond flagZero(String k) => (s) => s.flag(k) == 0;

  // 벽면 A(책상+축음기+서랍+책장) 핫스팟 rect — 납품된 f2_lab_a.png 실측
  // 눈대중(정밀 재배선은 계획 Task 9 일괄 검수 몫): 좌상단에 작은 타원 초상과
  // 벽등, 중앙 상단에 큰 책장(실린더1이 숨은 항아리 자리), 우측에 축음기,
  // desk 표면에 펼친 책, 중앙에 자물쇠 걸린 서랍, 우하단에 스툴. 방11로 가는
  // 문은 벽 아트 어디에도 그려지지 않았다(art/chapter2-assets.md 방10 표에
  // 문 언급 없음 — hall/bed/child의 "빈 벽 자리를 문으로" 관례를 좌측 빈
  // 벽에 적용, 재배선은 Task 9 몫). 문을 가장 넓게 먼저 선언하고 그 안에
  // 겹치는 초상·벽등·촛불선반을 나중에 선언해 z순서로 우선권을 준다.
  // 실측 보정: 문은 우측 아치(축음기 뒤) — 이전 rect는 좌측 기둥·벽지를
  // 덮고 있어 문 탭이 그림과 어긋났다. 축음기 rect도 문과 안 겹치게 좁힘.
  const doorArea = Rect.fromLTWH(0.85, 0.26, 0.15, 0.52);
  const portraitArea = Rect.fromLTWH(0.04, 0.16, 0.11, 0.09);
  const sconceArea = Rect.fromLTWH(0.02, 0.26, 0.17, 0.14);
  const candleShelfArea = Rect.fromLTWH(0.0, 0.49, 0.11, 0.10);
  const bookshelfArea = Rect.fromLTWH(0.17, 0.04, 0.47, 0.48);
  const phonoArea = Rect.fromLTWH(0.63, 0.32, 0.23, 0.30);
  const deskArea = Rect.fromLTWH(0.02, 0.51, 0.59, 0.12);
  const drawerArea = Rect.fromLTWH(0.26, 0.63, 0.48, 0.10);
  const stoolArea = Rect.fromLTWH(0.80, 0.80, 0.19, 0.13);

  // 벽면 B(관측 장치+칠판) — f2_lab_b.png 실측: 상단 중앙에 다이얼 3개+렌즈
  // 로 이뤄진 관측 장치, 그 아래 큰 칠판(장치 기동 후엔 f2_lab_b_awake.png가
  // 벽 전체를 덮어 같은 자리에 금고가 대신 드러난다 — board/safe 핫스팟이
  // 같은 rect를 상호 배타 when으로 공유). 좌우로 책장 기둥과 촛대.
  const deviceArea = Rect.fromLTWH(0.19, 0.04, 0.62, 0.33);
  const leftShelfArea = Rect.fromLTWH(0.0, 0.14, 0.19, 0.53);
  const rightShelfArea = Rect.fromLTWH(0.81, 0.14, 0.19, 0.53);
  const leftSconceArea = Rect.fromLTWH(0.09, 0.38, 0.10, 0.14);
  const rightSconceArea = Rect.fromLTWH(0.82, 0.38, 0.10, 0.14);
  const boardSafeArea = Rect.fromLTWH(0.19, 0.38, 0.62, 0.28);
  const rugBArea = Rect.fromLTWH(0.15, 0.78, 0.70, 0.13);

  // 벽면 C(창+약병 선반+램프+편지) — f2_lab_c.png 실측: 상단 고딕 창(커튼
  // 좌우), 창 아래 선반에 약병 3병(좌→우: 보라·초록·호박)과 그 뒤로 살짝
  // 보이는 열쇠고리, 우측에 램프(정답 완성 시 f2_lab_c_lamp.png가 벽 전체를
  // 덮어 보랏빛으로 전환), 하단 데스크에 빈 편지지.
  const windowArea = Rect.fromLTWH(0.34, 0.08, 0.33, 0.40);
  const curtainLeftArea = Rect.fromLTWH(0.01, 0.03, 0.24, 0.48);
  const curtainRightArea = Rect.fromLTWH(0.74, 0.03, 0.25, 0.48);
  const vialPurpleArea = Rect.fromLTWH(0.24, 0.48, 0.14, 0.10);
  const vialGreenArea = Rect.fromLTWH(0.39, 0.49, 0.14, 0.09);
  const vialAmberArea = Rect.fromLTWH(0.53, 0.49, 0.14, 0.09);
  // 실측 보정: 열쇠꾸러미 왼쪽 절반이 램프 rect에 먹혀 탭이 어려웠다.
  const keyringArea = Rect.fromLTWH(0.655, 0.628, 0.155, 0.065);
  const lampArea = Rect.fromLTWH(0.73, 0.49, 0.19, 0.43);
  const letterArea = Rect.fromLTWH(0.32, 0.69, 0.39, 0.11);

  void tapBookshelf(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_lab_cyl1_taken') == 0) {
      s.setFlag('f2_lab_cyl1_taken', 1);
      c.sfx('book_flip');
      c.give('cylinder1');
      c.say(strF2LabBookshelfGive);
      return;
    }
    c.say(strF2LabBookshelfLook);
  }

  void tapKeyring(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_lab_keyring_taken') == 0) {
      s.setFlag('f2_lab_keyring_taken', 1);
      c.sfx('metal_click');
      c.give('keyring');
      c.say(strF2LabKeyringGive);
      return;
    }
    c.say(strF2LabKeyringEmpty);
  }

  void tapDrawer(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_lab_drawer_open') >= 1) {
      c.say(strF2LabDrawerEmpty);
      return;
    }
    if (!c.using('keyring')) {
      c.sfx('locked');
      c.say(strF2LabDrawerLocked);
      return;
    }
    c.consume('keyring');
    s.setFlag('f2_lab_drawer_open', 1);
    c.sfx('metal_key');
    c.give('cylinder2');
    c.say(strF2LabDrawerOpen);
  }

  void tapSpindle(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_lab_cyl3_taken') == 0) {
      s.setFlag('f2_lab_cyl3_taken', 1);
      c.sfx('metal_click');
      c.give('cylinder3');
      c.say(strF2LabSpindleExtract);
      return;
    }
    final idx = _cylinderIds.indexOf(s.selectedItem ?? '');
    if (idx == -1) {
      c.say(strF2LabSpindleEmpty);
      return;
    }
    c.sfx('phonograph');
    c.say(_cylinderPlayLines[idx]);
  }

  void tapDeviceWall(GameCtx c) {
    if (c.s.flag('f2_lab_b_awake') >= 1) {
      c.say(strF2LabDeviceAwakeLook);
      return;
    }
    c.openCloseup('device');
  }

  void tapSafe(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_lab_seal_taken') >= 1) {
      c.say(strF2LabSafeEmpty);
      return;
    }
    s.setFlag('f2_lab_seal_taken', 1);
    c.sfx('unlock');
    c.give('key_f2seal');
    c.say(strF2LabSafeOpen);
  }

  void tapBoardWall(GameCtx c) {
    if (c.s.flag('f2_lab_board_clean') >= 1) {
      c.say(strF2LabBoardAlreadyClean);
    } else {
      c.say(strF2LabBoardDusty);
      c.openCloseup('board');
    }
  }

  void tapVial(GameCtx c, String itemId, String flag, String giveText) {
    final s = c.s;
    if (s.flag(flag) >= 1) {
      c.say(strF2LabVialSlotEmpty);
      return;
    }
    s.setFlag(flag, 1);
    c.sfx('glass_clink');
    c.give(itemId);
    c.say(giveText);
  }

  void tapLamp(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_lab_c_lamp') >= 1) {
      c.say(strF2LabLampDone);
      return;
    }
    final item = s.selectedItem;
    if (!_vialOrder.contains(item)) {
      c.say(strF2LabLampLook);
      return;
    }
    if (pourVial(s, item)) {
      c.consume(item!);
      c.sfx('liquid_pour');
      final stage = s.flag('f2_lab_lamp_stage');
      if (stage >= _vialOrder.length) {
        s.setFlag('f2_lab_c_lamp', 1);
        c.sfx('fire_ignite');
        c.say(strF2LabLampLit);
      } else {
        c.say(stage == 1 ? strF2LabLampStage1 : strF2LabLampStage2);
      }
    } else {
      c.sfx('glass_clink');
      c.say(strF2LabLampWrong);
    }
  }

  void tapLetter(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_lab_letter_ink') >= 1) {
      if (s.flag('f2_lab_memory') == 0) s.setFlag('f2_lab_memory', 1);
      c.openCloseup('memory');
      return;
    }
    if (s.flag('f2_lab_c_lamp') >= 1) {
      s.setFlag('f2_lab_letter_ink', 1);
      c.sfx('paper_rustle');
      c.say(strF2LabLetterFull);
      c.openCloseup('letter');
      return;
    }
    c.openCloseup('letter');
    c.say(strF2LabLetterBlank);
  }

  void tapDoor(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_lab_door_open') >= 1) {
      c.sfx('door_open');
      if (s.flag('f2_lab_done') == 0) {
        s.setFlag('f2_lab_done', 1);
        c.give('emblem_lab');
      }
      return;
    }
    if (!c.using('key_f2seal')) {
      c.sfx('locked');
      c.say(strF2LabDoorLocked);
      return;
    }
    c.consume('key_f2seal');
    c.sfx('metal_key');
    s.setFlag('f2_lab_door_open', 1);
    c.say(strF2LabDoorOpened);
  }

  return Room(
    id: 'lab',
    name: '서고·작업실',
    onEnter: (c) => c.say(strF2LabIntro),
    cleared: flagSet('f2_lab_done'),
    walls: [
      // 벽면 A: 책상+축음기(T1) + 서랍(T1, T2의 열쇠고리로 개방) + 책장
      // (T1 실린더1) + 문.
      Scene(id: 'lab_a', image: 'assets/scenes/f2_lab_a.png', overlays: [
        // 머리핀으로 딴 서랍 자물쇠는 풀린 채로 남는다.
        SceneOverlay(
            image: 'assets/scenes/f2_lab_a_unlocked.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('f2_lab_drawer_open')),
        // 봉인의 방 열쇠로 연 문은 활짝 열린 그림으로 바뀐다(문 영역 크롭 —
        // 풀프레임인 unlocked 뒤 선언이라 서랍 상태와 공존).
        SceneOverlay(
            image: 'assets/scenes/f2_lab_a_door_open.png',
            area: const Rect.fromLTWH(0.8428, 0.2109, 0.1572, 0.3952),
            when: flagSet('f2_lab_door_open')),
      ], hotspots: [
        Hotspot(id: 'door', area: doorArea, onTap: tapDoor),
        Hotspot(id: 'portrait', area: portraitArea, onTap: (c) => c.say(strF2LabPortrait)),
        Hotspot(id: 'sconce', area: sconceArea, onTap: (c) => c.say(strF2LabSconce)),
        Hotspot(
            id: 'candle_shelf', area: candleShelfArea, onTap: (c) => c.say(strF2LabCandleShelf)),
        Hotspot(id: 'bookshelf', area: bookshelfArea, onTap: tapBookshelf),
        Hotspot(id: 'phono', area: phonoArea, onTap: (c) {
          c.openCloseup('phono');
          c.say(strF2LabPhonoLook);
        }),
        Hotspot(id: 'desk', area: deskArea, onTap: (c) => c.say(strF2LabDesk)),
        Hotspot(id: 'drawer', area: drawerArea, onTap: tapDrawer),
        Hotspot(id: 'stool', area: stoolArea, onTap: (c) => c.say(strF2LabStool)),
      ]),
      // 벽면 B: 관측 장치(T1 다이얼) + 칠판(T2 지식, RubbableScene) — 장치
      // 기동 후엔 b_awake 오버레이가 칠판 자리를 금고로 덮어(같은 rect를
      // board/safe가 상호 배타 when으로 공유).
      Scene(id: 'lab_b', image: 'assets/scenes/f2_lab_b.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/f2_lab_b_awake.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('f2_lab_b_awake')),
      ], hotspots: [
        Hotspot(id: 'device', area: deviceArea, onTap: tapDeviceWall),
        Hotspot(id: 'left_shelf', area: leftShelfArea, onTap: (c) => c.say(strF2LabShelfB)),
        Hotspot(id: 'right_shelf', area: rightShelfArea, onTap: (c) => c.say(strF2LabShelfB)),
        Hotspot(id: 'left_sconce', area: leftSconceArea, onTap: (c) => c.say(strF2LabSconceB)),
        Hotspot(id: 'right_sconce', area: rightSconceArea, onTap: (c) => c.say(strF2LabSconceB)),
        Hotspot(
            id: 'board',
            area: boardSafeArea,
            when: flagZero('f2_lab_b_awake'),
            onTap: tapBoardWall),
        Hotspot(id: 'safe', area: boardSafeArea, when: flagSet('f2_lab_b_awake'), onTap: tapSafe),
        Hotspot(id: 'rug_b', area: rugBArea, onTap: (c) => c.say(strF2LabRugB)),
      ]),
      // 벽면 C: 창+약병 선반(T2 핵심) + 열쇠고리(T1 교차) + 램프(T2) + 편지
      // (T2 기억 앵커) — 완성 시 c_lamp 오버레이가 벽 전체를 보랏빛으로 덮는다.
      Scene(id: 'lab_c', image: 'assets/scenes/f2_lab_c.png', overlays: [
        // 가져간 약병·열쇠꾸러미는 선반에서 사라진다(빈 선반 합성 패치).
        // 램프 점등 풀프레임이 아래(뒤 선언)라 켜진 뒤엔 그쪽이 덮는다.
        SceneOverlay(
            image: 'assets/scenes/f2_lab_c_no_purple.png',
            area: const Rect.fromLTWH(0.2412, 0.4434, 0.1279, 0.1510),
            when: flagSet('f2_lab_vial_purple_taken')),
        SceneOverlay(
            image: 'assets/scenes/f2_lab_c_no_green.png',
            area: const Rect.fromLTWH(0.3730, 0.4434, 0.1182, 0.1543),
            when: flagSet('f2_lab_vial_green_taken')),
        SceneOverlay(
            image: 'assets/scenes/f2_lab_c_no_amber.png',
            area: const Rect.fromLTWH(0.5010, 0.4434, 0.1416, 0.1510),
            when: flagSet('f2_lab_vial_amber_taken')),
        SceneOverlay(
            image: 'assets/scenes/f2_lab_c_no_keyring.png',
            area: const Rect.fromLTWH(0.6523, 0.6289, 0.1621, 0.0677),
            when: flagSet('f2_lab_keyring_taken')),
        SceneOverlay(
            image: 'assets/scenes/f2_lab_c_lamp.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('f2_lab_c_lamp')),
        // 점등 그림은 벽 전체를 덮는 풀프레임이라 위 제거 패치를 되돌린다 —
        // 약병은 램프에 붓는 재료라 점등 시점엔 반드시 소비된 뒤다. 같은
        // 자리를 점등 색조로 다시 비워 얹는다.
        SceneOverlay(
            image: 'assets/scenes/f2_lab_c_lamp_no_purple.png',
            area: const Rect.fromLTWH(0.2412, 0.4434, 0.1279, 0.1510),
            when: (s) =>
                s.flag('f2_lab_c_lamp') >= 1 &&
                s.flag('f2_lab_vial_purple_taken') >= 1),
        SceneOverlay(
            image: 'assets/scenes/f2_lab_c_lamp_no_green.png',
            area: const Rect.fromLTWH(0.3730, 0.4434, 0.1182, 0.1543),
            when: (s) =>
                s.flag('f2_lab_c_lamp') >= 1 &&
                s.flag('f2_lab_vial_green_taken') >= 1),
        SceneOverlay(
            image: 'assets/scenes/f2_lab_c_lamp_no_amber.png',
            area: const Rect.fromLTWH(0.5010, 0.4434, 0.1416, 0.1510),
            when: (s) =>
                s.flag('f2_lab_c_lamp') >= 1 &&
                s.flag('f2_lab_vial_amber_taken') >= 1),
        SceneOverlay(
            image: 'assets/scenes/f2_lab_c_lamp_no_keyring.png',
            area: const Rect.fromLTWH(0.6523, 0.6289, 0.1621, 0.0677),
            when: (s) =>
                s.flag('f2_lab_c_lamp') >= 1 &&
                s.flag('f2_lab_keyring_taken') >= 1),
      ], hotspots: [
        Hotspot(id: 'window', area: windowArea, onTap: (c) => c.say(strF2LabWindow)),
        Hotspot(id: 'curtain_left', area: curtainLeftArea, onTap: (c) => c.say(strF2LabCurtain)),
        Hotspot(
            id: 'curtain_right', area: curtainRightArea, onTap: (c) => c.say(strF2LabCurtain)),
        Hotspot(
            id: 'vial_purple',
            area: vialPurpleArea,
            onTap: (c) => tapVial(
                c, 'vial_purple', 'f2_lab_vial_purple_taken', strF2LabVialPurpleGive)),
        Hotspot(
            id: 'vial_green',
            area: vialGreenArea,
            onTap: (c) =>
                tapVial(c, 'vial_green', 'f2_lab_vial_green_taken', strF2LabVialGreenGive)),
        Hotspot(
            id: 'vial_amber',
            area: vialAmberArea,
            onTap: (c) =>
                tapVial(c, 'vial_amber', 'f2_lab_vial_amber_taken', strF2LabVialAmberGive)),
        Hotspot(id: 'keyring', area: keyringArea, onTap: tapKeyring),
        Hotspot(id: 'lamp', area: lampArea, onTap: tapLamp),
        Hotspot(id: 'letter', area: letterArea, onTap: tapLetter),
      ]),
    ],
    closeups: {
      'phono': Scene(id: 'phono', image: 'assets/scenes/f2_lab_phono.png', hotspots: [
        Hotspot(id: 'spindle', area: const Rect.fromLTWH(0.08, 0.18, 0.40, 0.58), onTap: tapSpindle),
      ]),
      'device': Scene(
          id: 'device',
          custom: (_, c) => Stack(fit: StackFit.expand, children: [
                gameImage('assets/scenes/f2_lab_device.png'),
                DialSafe(
                  ctx: c,
                  digits: 3,
                  code: '241',
                  flagPrefix: 'f2_lab_dial',
                  wrongSay: strF2LabDialWrong,
                  onOpened: awakenDevice,
                ),
              ])),
      'board': Scene(
          id: 'board',
          custom: (_, c) => RubbableScene(
                ctx: c,
                baseImage: 'assets/scenes/f2_lab_board_clean.png',
                coverImage: 'assets/scenes/f2_lab_board.png',
                cleaned: (s) => s.flag('f2_lab_board_clean') >= 1,
                onCleaned: (c) {
                  finishBoardClean(c.s);
                  c.sfx('cloth_rub');
                  c.say(strF2LabBoardCleanReveal);
                },
                progressFlag: 'f2_lab_board_rub_pct',
                gestureKey: const Key('board_rub'),
              )),
      'letter': Scene(
          id: 'letter',
          image: 'assets/scenes/f2_lab_letter.png',
          overlays: [
            SceneOverlay(
                image: 'assets/scenes/f2_lab_letter_ink.png',
                area: const Rect.fromLTWH(0, 0, 1, 1),
                when: flagSet('f2_lab_letter_ink')),
          ]),
      'memory': Scene(
          id: 'memory',
          custom: (_, c) => MemoryPlayer(
                ctx: c,
                pages: const [
                  MemoryPage('assets/scenes/f2_mem4.png', strF2Mem4p1),
                  MemoryPage('assets/scenes/f2_mem4.png', strF2Mem4p2),
                  MemoryPage('assets/scenes/f2_mem4.png', strF2Mem4p3),
                ],
                onDone: () => c.s.closeCloseup(),
              )),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_f2_lab_dial', title: '축음기의 소리 코드', steps: [
        '소리들이 숫자예요.',
        '거치대에 각인된 점 순서로 다시 배열해 보세요.',
        '정답: 241.',
      ], solved: (s) => s.flag('f2_lab_b_awake') >= 1),
      PuzzleHint(puzzleId: 'p_f2_lab_ink', title: '숨은 잉크', steps: [
        '칠판의 그림은 요리법이 아니에요.',
        '약병을 램프에 순서대로 부어보세요.',
        '정답: 보라 → 초록 → 호박색 순서로.',
      ], solved: (s) => s.flag('f2_lab_c_lamp') >= 1),
      PuzzleHint(puzzleId: 'p_f2_lab_safe', title: '벽 속의 금고', steps: [
        '벽의 관측 장치 아래, 뭔가 숨어 있는 것 같아요.',
        '장치가 살아나면 무언가 달라질지도 몰라요.',
        '정답: 다이얼을 맞혀 장치를 깨우세요.',
      ], solved: (s) => s.flag('f2_lab_seal_taken') >= 1),
    ],
  );
}
