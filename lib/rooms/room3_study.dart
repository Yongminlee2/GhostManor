import 'package:flutter/widgets.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/rub_scene.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──

/// 책 i(1=빨강,2=파랑,3=노랑,4=초록) 탭. 정답 순서(파→초→빨→노 = 2,4,1,3)대로면
/// study_book_seq +1, 틀리면 0으로 리셋. 4단계 도달 시 study_nook_open=1.
/// nook_open 후엔 no-op.
void tapBook(GameState s, int i) {
  if (s.flag('study_nook_open') >= 1) return;
  const order = [2, 4, 1, 3];
  final seq = s.flag('study_book_seq');
  if (order[seq] == i) {
    final next = seq + 1;
    s.setFlag('study_book_seq', next);
    if (next == 4) s.setFlag('study_nook_open', 1);
  } else {
    s.setFlag('study_book_seq', 0);
  }
}

// ── 방 정의 ──

Room buildStudy() {
  Cond flagSet(String k) => (s) => s.flag(k) >= 1;
  Cond flagZero(String k) => (s) => s.flag(k) == 0;

  const bookRedArea = Rect.fromLTWH(0.16, 0.22, 0.10, 0.11);
  const bookBlueArea = Rect.fromLTWH(0.35, 0.22, 0.10, 0.11);
  const bookYellowArea = Rect.fromLTWH(0.56, 0.22, 0.10, 0.11);
  const bookGreenArea = Rect.fromLTWH(0.75, 0.22, 0.10, 0.11);
  const nookArea = Rect.fromLTWH(0.40, 0.46, 0.20, 0.18);
  const nedArea = Rect.fromLTWH(0.72, 0.60, 0.18, 0.26);
  const paperArea = Rect.fromLTWH(0.02, 0.62, 0.26, 0.12);
  const globeArea = Rect.fromLTWH(0.16, 0.40, 0.26, 0.22);
  const doorArea = Rect.fromLTWH(0.62, 0.24, 0.26, 0.46);
  const deskArea = Rect.fromLTWH(0.04, 0.74, 0.24, 0.12);

  // 책 4권 공용: tapBook 진행 + 클릭음, 리셋되면 대사, nook 완성 순간 추가 피드백.
  void tapBookSpot(GameCtx c, int i) {
    final beforeSeq = c.s.flag('study_book_seq');
    final wasOpen = c.s.flag('study_nook_open') >= 1;
    tapBook(c.s, i);
    c.sfx('book_flip');
    if (!wasOpen && c.s.flag('study_nook_open') >= 1) {
      c.sfx('unlock');
      c.say(strStudyNookOpen);
    } else if (c.s.flag('study_book_seq') == 0 && beforeSeq > 0) {
      c.say(strStudyBookReset);
    }
  }

  return Room(
    id: 'study',
    name: '서재',
    onEnter: (c) => c.say(strStudyIntro),
    cleared: flagSet('study_done'),
    walls: [
      // 벽면 A: 책장 벽
      Scene(id: 'study_a', image: 'assets/scenes/study_a.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/study_a_nook_open.png',
            area: nookArea,
            when: flagSet('study_nook_open')),
      ], hotspots: [
        Hotspot(
            id: 'book_red',
            area: bookRedArea,
            when: flagZero('study_nook_open'),
            onTap: (c) => tapBookSpot(c, 1)),
        Hotspot(
            id: 'book_blue',
            area: bookBlueArea,
            when: flagZero('study_nook_open'),
            onTap: (c) => tapBookSpot(c, 2)),
        Hotspot(
            id: 'book_yellow',
            area: bookYellowArea,
            when: flagZero('study_nook_open'),
            onTap: (c) => tapBookSpot(c, 3)),
        Hotspot(
            id: 'book_green',
            area: bookGreenArea,
            when: flagZero('study_nook_open'),
            onTap: (c) => tapBookSpot(c, 4)),
        Hotspot(
            id: 'nook',
            area: nookArea,
            when: (s) =>
                s.flag('study_nook_open') >= 1 &&
                s.flag('study_got_crank') == 0,
            onTap: (c) {
              c.sfx('wood_slide');
              c.give('crank');
              c.give('note2');
              c.s.setFlag('study_got_crank', 1);
              c.say(strStudyNookLoot);
            }),
        Hotspot(
            id: 'ned',
            area: nedArea,
            onTap: (c) {
              c.sfx('ghost_giggle');
              c.say(strStudyNed);
            }),
      ]),
      // 벽면 B: 책상·지구본·문 벽
      Scene(id: 'study_b', image: 'assets/scenes/study_b.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/study_b_globe_open.png',
            area: Rect.fromLTWH(0.17, 0.42, 0.18, 0.20),
            when: flagSet('study_globe_open')),
        SceneOverlay(
            image: 'assets/scenes/study_b_door_open.png',
            area: doorArea,
            when: flagSet('study_done')),
      ], hotspots: [
        Hotspot(
            id: 'paper',
            area: paperArea,
            onTap: (c) {
              c.sfx('paper_rustle');
              c.openCloseup('paper');
            }),
        Hotspot(
            id: 'globe',
            area: globeArea,
            onTap: (c) {
              final s = c.s;
              if (s.flag('study_globe_open') >= 1 &&
                  s.flag('study_got_key') == 0) {
                c.sfx('metal_key');
                c.give('key_study');
                s.setFlag('study_got_key', 1);
                c.say(strStudyGlobeKey);
              } else if (c.using('crank')) {
                c.consume('crank');
                c.sfx('metal_click');
                s.setFlag('study_globe_open', 1);
                c.say(strStudyGlobeOpen);
              } else {
                c.say(strStudyGlobe);
              }
            }),
        Hotspot(
            id: 'door',
            area: doorArea,
            onTap: (c) {
              final s = c.s;
              final unlocked = s.flag('study_door_unlocked') >= 1;
              final oiled = s.flag('study_door_oiled') >= 1;
              if (unlocked && oiled) {
                c.sfx('door_open');
                s.setFlag('study_done', 1);
              } else if (c.using('key_study')) {
                c.consume('key_study');
                c.sfx('metal_key');
                s.setFlag('study_door_unlocked', 1);
                c.say(strStudyDoorUnlocked);
              } else if (c.using('oil')) {
                c.consume('oil');
                c.sfx('liquid_pour');
                s.setFlag('study_door_oiled', 1);
                c.say(strStudyDoorOiled);
              } else if (unlocked && !oiled) {
                c.sfx('locked');
                c.say(strStudyDoorSqueak);
              } else {
                c.sfx('locked');
                c.say(strStudyDoorLocked);
              }
            }),
        Hotspot(id: 'desk', area: deskArea, onTap: (c) => c.say(strStudyDesk)),
      ]),
    ],
    closeups: {
      'paper': Scene(
          id: 'paper',
          custom: (_, c) => RubbableScene(
                ctx: c,
                baseImage: 'assets/scenes/study_paper_clean.png',
                coverImage: 'assets/scenes/study_paper_ink.png',
                cleaned: (s) => s.flag('study_paper_rubbed') >= 1,
                onCleaned: (c) {
                  c.s.setFlag('study_paper_rubbed', 1);
                  c.sfx('sparkle');
                },
                gestureKey: const Key('paper_rub'),
              )),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_study_books', title: '색깔 책들', steps: [
        '책 네 권은 뽑는 순서가 있어요. 순서는 이 방의 얼룩 속에 숨어 있어요',
        '책상 위 얼룩진 종이를 문질러 닦아 보세요. 색 순서가 나와요',
        '정답: 파랑→초록→빨강→노랑 순서로 탭',
      ], solved: (s) => s.flag('study_nook_open') >= 1),
      PuzzleHint(puzzleId: 'p_study_globe', title: '갈라지는 지구본', steps: [
        '지구본엔 뭔가 꽂는 구멍이 있어요',
        '숨은 공간에서 찾은 도구를 선택하고 지구본을 탭',
        '정답: 놋쇠 크랭크 사용 → 열쇠',
      ], solved: (s) => s.flag('study_globe_open') >= 1),
      PuzzleHint(puzzleId: 'p_study_door', title: '녹슨 문', steps: [
        '이 문은 자물쇠 말고도 문제가 하나 더 있어요',
        '열쇠로 잠금을 풀어도 경첩이 녹슬어 안 열려요. 지난 방에서 챙긴 물건 중에 도움이 될 것이?',
        '정답: 거실 비밀칸의 기름병을 문에 사용한 뒤, 서재 열쇠로 열기',
      ], solved: (s) => s.flag('study_done') >= 1),
    ],
  );
}
