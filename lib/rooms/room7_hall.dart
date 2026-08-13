import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/game_state.dart';
import '../core/memory_player.dart';
import '../core/models.dart';
import '../core/rub_scene.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──
// 챕터2 전 플래그 f2_hall_ 접두어.
//
// 스레드 구조(계획 Task 3): T1 초상 정렬(카펫 다이아 무늬 2·4번째 채움이
// 지식 단서 → 액자 4점 탭 토글 → [정상,기울임,정상,기울임]) ‖ T2 마루판·태엽
// (카펫 드래그로 걷기 → 마루판 4장 두드리기[3 dull·1 hollow, 챕터1 찬장
// 콜백] → 삐걱 마루판 열기 → winder 획득 → 벽시계에 사용 → 종 3번(챕터1
// "저녁 식사" 3시 콜백, 텍스트로만 함의 — 사운드 파일은 Task 8) → 샹들리에
// 흔들려 열쇠 낙하 → 바닥에서 줍기) → 교차: 안방 문은 열쇠(T2)+액자 정렬
// (T1) 이중 게이트라 어느 한쪽만으론 못 나간다. 회상1은 T1 완료 후 가족사진
// 앵커를 탭할 때 재생(핵심 해결=문 개방이 아님 — 브리프 명시).

/// 초상 정렬 정답: [정상,기울임,정상,기울임] — 카펫 다이아 2·4번째 채움
/// 단서와 대응(단서를 안 봐도 배열만 맞으면 통과 — 지식-게이트 분리).
const hallPortraitTarget = [0, 1, 0, 1];

/// 4개 액자 상태(f2_hall_portrait0~3)가 전부 정답과 일치하는지 — 순수 함수.
bool hallPortraitsSolved(GameState s) {
  for (var i = 0; i < 4; i++) {
    if (s.flag('f2_hall_portrait$i') != hallPortraitTarget[i]) return false;
  }
  return true;
}

/// 초상 i(0~3) 탭: 기울임 상태 토글. 정답이 되는 순간 f2_hall_frames=1(한
/// 번 서면 이후 다시 흐트러져도 게이트는 되돌리지 않는다 — 문은 f2_hall_frames
/// 플래그만 본다).
void tapPortrait(GameState s, int i) {
  final key = 'f2_hall_portrait$i';
  s.setFlag(key, s.flag(key) == 0 ? 1 : 0);
  if (hallPortraitsSolved(s)) s.setFlag('f2_hall_frames', 1);
}

/// 문 오답 페널티(브리프 원문: "액자 하나가 삐걱, 스스로 기울어진다") — 무작위
/// 액자 하나를 강제로 기울임(1)으로 만든다. 리셋이 아니라 방해: 이미 기울인
/// 칸이 걸리면 변화 없음.
final _hallRng = math.Random();
void sabotageRandomPortrait(GameState s) {
  s.setFlag('f2_hall_portrait${_hallRng.nextInt(4)}', 1);
}

/// 카펫 드래그(RubbableScene)의 onCleaned가 호출하는 순수 함수 — room1의
/// finishCoatRub/finishFrameRub와 동일 관례. 헤드리스 solve는 위젯을 펌프하지
/// 않고 이 함수를 직접 호출한다.
void finishRugRoll(GameState s) => s.setFlag('f2_hall_rug_rolled', 1);

/// 마루판 4장 중 이 인덱스만 "삐걱"(hollow) — 나머지는 dull.
const hallHollowPlank = 2;

// ── 방 정의 ──

Room buildHall() {
  Cond flagSet(String k) => (s) => s.flag(k) >= 1;

  // 벽면 A(복도) 핫스팟 rect — 납품된 f2_hall_a.png 실측 눈대중(정밀 재배선은
  // 계획 Task 9 일괄 검수 몫 — task-3-report 기록): 왼쪽에 안방 문, 중앙~우측에
  // 초상 4점 가로 배열, 초상 위쪽 벽등 2.
  const doorArea = Rect.fromLTWH(0.04, 0.21, 0.28, 0.49);
  const portrait1Area = Rect.fromLTWH(0.36, 0.34, 0.13, 0.16);
  const portrait2Area = Rect.fromLTWH(0.51, 0.34, 0.12, 0.16);
  const portrait3Area = Rect.fromLTWH(0.66, 0.36, 0.12, 0.14);
  const portrait4Area = Rect.fromLTWH(0.81, 0.35, 0.13, 0.16);
  const sconce1Area = Rect.fromLTWH(0.29, 0.14, 0.09, 0.16);
  const sconce2Area = Rect.fromLTWH(0.83, 0.21, 0.11, 0.11);
  const portraitAreas = [portrait1Area, portrait2Area, portrait3Area, portrait4Area];

  // 벽면 B(계단참) 핫스팟 rect — f2_hall_b.png 실측 눈대중: 창+커튼은 좌측,
  // 괘종시계(바닥형)는 우측-중앙, 샹들리에는 상단 중앙, 난간은 좌하단.
  const curtainArea = Rect.fromLTWH(0.02, 0.10, 0.14, 0.50);
  const windowArea = Rect.fromLTWH(0.10, 0.15, 0.22, 0.42);
  const chandelierArea = Rect.fromLTWH(0.33, 0.0, 0.34, 0.21);
  const clockArea = Rect.fromLTWH(0.58, 0.27, 0.22, 0.41);
  const floorKeyArea = Rect.fromLTWH(0.42, 0.80, 0.16, 0.10);
  const railingArea = Rect.fromLTWH(0.0, 0.52, 0.32, 0.26);

  // 벽면 C(복도 끝) 핫스팟 rect — f2_hall_c.png 실측 눈대중: 콘솔·가족사진·
  // 괘종 소품은 우측 클러스터, 카펫은 하단 중앙(마루판 4장은 그 안, 소리로만
  // 구별하는 퍼즐이라 시각적으로 미묘한 위치 차는 무방).
  const rugArea = Rect.fromLTWH(0.15, 0.58, 0.65, 0.34);
  const photoArea = Rect.fromLTWH(0.66, 0.36, 0.19, 0.14);
  const pendulumArea = Rect.fromLTWH(0.85, 0.40, 0.13, 0.10);
  const plank1Area = Rect.fromLTWH(0.20, 0.68, 0.14, 0.22);
  const plank2Area = Rect.fromLTWH(0.36, 0.68, 0.14, 0.22);
  const plank3Area = Rect.fromLTWH(0.52, 0.68, 0.14, 0.22);
  const plank4Area = Rect.fromLTWH(0.68, 0.68, 0.14, 0.22);
  const plankAreas = [plank1Area, plank2Area, plank3Area, plank4Area];

  void tapPortraitAt(GameCtx c, int i) {
    final s = c.s;
    final before = s.flag('f2_hall_frames');
    tapPortrait(s, i);
    if (before == 0 && s.flag('f2_hall_frames') == 1) {
      c.sfx('metal_click');
      c.say(strF2HallFramesSet);
    }
  }

  void tapDoor(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_hall_door_open') >= 1) {
      c.sfx('door_open');
      if (s.flag('f2_hall_done') == 0) {
        s.setFlag('f2_hall_done', 1);
        c.give('emblem_hall');
      }
      return;
    }
    if (s.flag('f2_hall_frames') == 0) {
      c.say(strF2HallDoorFramesWrong);
      sabotageRandomPortrait(s);
      return;
    }
    if (!c.using('key_f2bed')) {
      c.sfx('locked');
      c.say(strF2HallDoorLocked);
      return;
    }
    c.consume('key_f2bed');
    c.sfx('metal_key');
    s.setFlag('f2_hall_door_open', 1);
    c.say(strF2HallDoorOpened);
  }

  void tapPhoto(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_hall_frames') >= 1) {
      if (s.flag('f2_hall_memory') == 0) s.setFlag('f2_hall_memory', 1);
      c.openCloseup('memory');
    } else {
      c.openCloseup('photo');
      c.say(strF2HallPhotoLook);
    }
  }

  void tapRugWall(GameCtx c) {
    if (c.s.flag('f2_hall_rug_rolled') >= 1) {
      c.say(strF2HallRugAlreadyRolled);
    } else {
      // 다이아 무늬 관찰 서술 — 단서 오브젝트를 탭하면 내용을 읽어주는
      // 기존 관례(거실 램프 "셋", 지하실 라벨)와 동일. 납품 아트의 무늬
      // 배치가 순서 대응으로 읽기 모호해 텍스트가 권위를 가진다.
      c.say(strF2HallRugPattern);
      c.openCloseup('rug');
    }
  }

  void tapPlank(GameCtx c, int i) {
    final s = c.s;
    if (i != hallHollowPlank) {
      c.sfx('wood_knock_dull');
      c.say(strF2HallPlankDull);
      return;
    }
    if (s.flag('f2_hall_plank_open') >= 1) {
      c.say(strF2HallPlankAlreadyOpen);
      return;
    }
    if (s.flag('f2_hall_plank_hollow_found') == 0) {
      s.setFlag('f2_hall_plank_hollow_found', 1);
      c.sfx('wood_knock_hollow');
      c.say(strF2HallPlankHollow);
      return;
    }
    s.setFlag('f2_hall_plank_open', 1);
    c.sfx('wood_creak_open');
    c.give('winder');
    c.say(strF2HallPlankOpen);
  }

  void tapWinderHole(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_hall_clock_wound') >= 1) {
      c.say(strF2HallClockAlreadyWound);
      return;
    }
    if (!c.using('winder')) {
      c.say(strF2HallClockNeedsWinder);
      return;
    }
    c.consume('winder');
    s.setFlag('f2_hall_clock_wound', 1);
    s.setFlag('f2_hall_b_alive', 1);
    // 종 3번(브리프 함의) — Task 8이 실제로 만든 clock_chime.wav는 3연타를
    // 파일 자체에 구워서 재생 측이 타이머 없이 1회 재생만 하면 되게 했다
    // (progress.md/커밋 94db27d). 여기서 3번 호출하면 겹쳐 울린다 — 1회만.
    c.sfx('clock_chime');
    c.say(strF2HallClockAlive);
  }

  void tapChandelier(GameCtx c) {
    final s = c.s;
    if (s.flag('f2_hall_b_alive') == 0) {
      c.say(strF2HallChandelierStill);
      return;
    }
    if (s.flag('f2_hall_key_dropped') >= 1) {
      c.say(strF2HallChandelierDone);
      return;
    }
    s.setFlag('f2_hall_key_dropped', 1);
    c.sfx('metal_drop');
    c.say(strF2HallKeyFalls);
  }

  return Room(
    id: 'hall',
    name: '계단홀·복도',
    onEnter: (c) => c.say(strF2HallIntro),
    cleared: flagSet('f2_hall_done'),
    walls: [
      // 벽면 A: 복도 — 안방 문 + 초상화 4점(T1) + 벽등 2(리액션).
      Scene(id: 'hall_a', image: 'assets/scenes/f2_hall_a.png', overlays: [
        for (var i = 0; i < 4; i++)
          SceneOverlay(
              image: 'assets/scenes/f2_hall_a_tilt${i + 1}.png',
              area: portraitAreas[i],
              when: (s) => s.flag('f2_hall_portrait$i') >= 1),
      ], hotspots: [
        Hotspot(id: 'door', area: doorArea, onTap: tapDoor),
        for (var i = 0; i < 4; i++)
          Hotspot(
              id: 'portrait${i + 1}',
              area: portraitAreas[i],
              onTap: (c) => tapPortraitAt(c, i)),
        Hotspot(id: 'sconce1', area: sconce1Area, onTap: (c) => c.say(strF2HallSconce1)),
        Hotspot(id: 'sconce2', area: sconce2Area, onTap: (c) => c.say(strF2HallSconce2)),
      ]),
      // 벽면 B: 계단참 — 벽시계·샹들리에(T2 후반) + 창·커튼·난간(리액션).
      Scene(id: 'hall_b', image: 'assets/scenes/f2_hall_b.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/f2_hall_b_alive.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('f2_hall_b_alive')),
      ], hotspots: [
        Hotspot(id: 'clock', area: clockArea, onTap: (c) => c.openCloseup('clock')),
        Hotspot(id: 'chandelier', area: chandelierArea, onTap: tapChandelier),
        Hotspot(id: 'window', area: windowArea, onTap: (c) => c.say(strF2HallWindow)),
        Hotspot(id: 'curtain', area: curtainArea, onTap: (c) => c.say(strF2HallCurtain)),
        Hotspot(id: 'railing', area: railingArea, onTap: (c) => c.say(strF2HallRailing)),
        Hotspot(
            id: 'floor_key',
            area: floorKeyArea,
            when: (s) => s.flag('f2_hall_key_dropped') >= 1 && !s.has('key_f2bed'),
            onTap: (c) {
              c.sfx('metal_key');
              c.give('key_f2bed');
              c.say(strF2HallKeyPicked);
            }),
      ]),
      // 벽면 C: 복도 끝 — 카펫(T2 시작, 다이아 무늬는 T1 지식 단서) + 콘솔·
      // 가족사진(기억 앵커) + 괘종 소품(리액션) + 마루판 4장(rolled 후 노출).
      Scene(id: 'hall_c', image: 'assets/scenes/f2_hall_c.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/f2_hall_c_rolled.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('f2_hall_rug_rolled')),
        SceneOverlay(
            image: 'assets/scenes/f2_hall_c_plank.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('f2_hall_plank_open')),
      ], hotspots: [
        Hotspot(id: 'rug', area: rugArea, onTap: tapRugWall),
        Hotspot(id: 'photo', area: photoArea, onTap: tapPhoto),
        Hotspot(id: 'pendulum', area: pendulumArea, onTap: (c) => c.say(strF2HallPendulum)),
        for (var i = 0; i < 4; i++)
          Hotspot(
              id: 'plank${i + 1}',
              area: plankAreas[i],
              when: flagSet('f2_hall_rug_rolled'),
              onTap: (c) => tapPlank(c, i)),
      ]),
    ],
    closeups: {
      'photo': Scene(id: 'photo', image: 'assets/scenes/f2_hall_photo.png'),
      'memory': Scene(
          id: 'memory',
          custom: (_, c) => MemoryPlayer(
                ctx: c,
                pages: const [
                  MemoryPage('assets/scenes/f2_mem1.png', strF2Mem1p1),
                  MemoryPage('assets/scenes/f2_mem1.png', strF2Mem1p2),
                  MemoryPage('assets/scenes/f2_mem1.png', strF2Mem1p3),
                ],
                onDone: () => c.s.closeCloseup(),
              )),
      'clock': Scene(id: 'clock', image: 'assets/scenes/f2_hall_clock.png', hotspots: [
        Hotspot(id: 'winder_hole', area: const Rect.fromLTWH(0, 0, 1, 1), onTap: tapWinderHole),
      ]),
      'rug': Scene(
          id: 'rug',
          custom: (_, c) => RubbableScene(
                ctx: c,
                baseImage: 'assets/scenes/f2_hall_c_rolled.png',
                coverImage: 'assets/scenes/f2_hall_c.png',
                cleaned: (s) => s.flag('f2_hall_rug_rolled') >= 1,
                onCleaned: (c) {
                  finishRugRoll(c.s);
                  c.sfx('wood_slide');
                  c.say(strF2HallRugRolled);
                },
                gestureKey: const Key('rug_rub'),
              )),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_f2_hall_frames', title: '비뚤어진 액자들', steps: [
        '복도 초상들이 미묘하게 비뚤어요.',
        '카펫 무늬의 채워진 칸과 액자 순서를 대조해 보세요.',
        '정답: 2번째와 4번째 액자만 기울이세요.',
      ], solved: (s) => s.flag('f2_hall_frames') >= 1),
      PuzzleHint(puzzleId: 'p_f2_hall_clock', title: '멈춘 벽시계', steps: [
        '시계가 멈춰 있어요 — 무언가 감아야 할 것 같아요.',
        '카펫 밑, 삐걱이는 마루판을 찾아보세요.',
        '정답: 태엽 손잡이를 시계에 사용한 뒤, 종소리가 끝나면 샹들리에를 보세요.',
      ], solved: (s) => s.flag('f2_hall_b_alive') >= 1),
      PuzzleHint(puzzleId: 'p_f2_hall_door', title: '안방 문', steps: [
        '문은 두 가지를 요구하는 것 같아요.',
        '열쇠, 그리고 복도의 "시선"들.',
        '정답: 열쇠와 함께 액자들을 올바르게 정렬하세요.',
      ], solved: (s) => s.flag('f2_hall_done') >= 1),
    ],
  );
}
