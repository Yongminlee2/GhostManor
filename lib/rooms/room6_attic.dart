import 'package:flutter/material.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/scene_view.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──

/// 오르간 건반 i(1..4) 탭. cards_placed<4면 no-op(악보 미완성). 정답 순서
/// [1,3,2,4](도미레파)대로면 attic_organ_seq +1, 틀리면 0으로 리셋. 4단계
/// 도달 시 attic_organ_played=1. 완료 후 재탭은 no-op — order 배열 범위 밖
/// 인덱스 접근을 막는다(room3 tapBook의 nook_open 가드와 동일한 이유).
void tapOrganKey(GameState s, int i) {
  if (s.flag('attic_cards_placed') < 4) return;
  if (s.flag('attic_organ_played') >= 1) return;
  const order = [1, 3, 2, 4];
  final seq = s.flag('attic_organ_seq');
  if (order[seq] == i) {
    final next = seq + 1;
    s.setFlag('attic_organ_seq', next);
    if (next == 4) s.setFlag('attic_organ_played', 1);
  } else {
    s.setFlag('attic_organ_seq', 0);
  }
}

// ── 커스텀 기믹 위젯 (escape hatch) ──

/// 오르간 클로즈업: 하단 40%를 가로 4등분한 건반 4개. 탭마다 tapOrganKey +
/// 음별 효과음, 리셋되면 경고음+대사, 완료 순간 축하음+대사(원샷 가드는 room3
/// tapBookSpot과 동일하게 GameState 플래그 전/후 비교 — room5 패턴대로 캐시
/// bool 없이 라이브 플래그만 읽는다). 렌더 트리 자체는 상태에 의존하지 않아
/// room5 ShelfShake처럼 자체 AnimatedBuilder는 불필요(바깥 SceneView가 감쌈).
class OrganKeys extends StatelessWidget {
  final GameCtx ctx;
  const OrganKeys({super.key, required this.ctx});

  void _tapKey(int i) {
    final s = ctx.s;
    final beforeSeq = s.flag('attic_organ_seq');
    final wasPlayed = s.flag('attic_organ_played') >= 1;
    tapOrganKey(s, i);
    ctx.sfx('note$i');
    if (!wasPlayed && s.flag('attic_organ_played') >= 1) {
      ctx.sfx('organ_chord');
      ctx.say(strAtticOrganPlayed);
    } else if (s.flag('attic_organ_seq') == 0 && beforeSeq > 0) {
      ctx.sfx('organ_wrong');
      ctx.say(strAtticOrganWrong);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      return Stack(children: [
        Positioned.fill(
            child: gameImage('assets/scenes/attic_organ_close.png')),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: box.maxHeight * 0.4,
          child: Row(children: [
            for (var i = 1; i <= 4; i++)
              Expanded(
                child: GestureDetector(
                  key: Key('organ_key_$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _tapKey(i),
                ),
              ),
          ]),
        ),
      ]);
    });
  }
}

// ── 방 정의 ──

Room buildAttic() {
  Cond flagSet(String k) => (s) => s.flag(k) >= 1;

  return Room(
    id: 'attic',
    name: '다락방',
    onEnter: (c) => c.say(strAtticIntro),
    cleared: flagSet('attic_done'),
    walls: [
      // 벽면 A: 오르간 벽
      Scene(id: 'attic_a', image: 'assets/scenes/attic_a.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/attic_a_cards.png',
            area: const Rect.fromLTWH(0.36, 0.50, 0.28, 0.14),
            when: (s) => s.flag('attic_cards_placed') >= 4),
      ], hotspots: [
        Hotspot(
            id: 'organ',
            area: const Rect.fromLTWH(0.24, 0.44, 0.52, 0.34),
            onTap: (c) {
              if (c.s.flag('attic_cards_placed') < 4) {
                c.say(strAtticOrganNoCards);
              } else {
                c.openCloseup('organ');
              }
            }),
        Hotspot(
            id: 'music_stand',
            area: const Rect.fromLTWH(0.30, 0.50, 0.40, 0.10),
            onTap: (c) {
              final s = c.s;
              final note = const ['note1', 'note2', 'note3', 'note4']
                  .firstWhere((n) => c.using(n), orElse: () => '');
              if (note.isEmpty) {
                c.say(s.flag('attic_cards_placed') < 4
                    ? strAtticStandEmpty
                    : strAtticStandFull);
                return;
              }
              c.consume(note);
              s.addFlag('attic_cards_placed');
              c.sfx('paper_rustle');
              if (s.flag('attic_cards_placed') >= 4) {
                c.sfx('sparkle');
                c.say(strAtticCardsAll);
              } else {
                c.say(strAtticCardPlaced);
              }
            }),
        Hotspot(
            id: 'ghospo',
            area: const Rect.fromLTWH(0.78, 0.36, 0.18, 0.28),
            onTap: (c) {
              c.sfx('ghost_giggle');
              c.say(c.s.flag('attic_organ_played') == 1
                  ? strAtticGhospoProud
                  : strAtticGhospoHint);
            }),
      ]),
      // 벽면 B: 트렁크·창문·자수 벽
      Scene(id: 'attic_b', image: 'assets/scenes/attic_b.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/attic_b_trunk_open.png',
            area: const Rect.fromLTWH(0.36, 0.54, 0.34, 0.28),
            when: (s) => s.flag('attic_organ_played') == 1,
            motion: OverlayMotion.grow),
      ], hotspots: [
        Hotspot(
            id: 'embroidery',
            area: const Rect.fromLTWH(0.26, 0.19, 0.36, 0.28),
            onTap: (c) => c.openCloseup('embroidery')),
        Hotspot(
            id: 'trunk',
            area: const Rect.fromLTWH(0.36, 0.54, 0.34, 0.28),
            onTap: (c) {
              final s = c.s;
              if (s.flag('attic_organ_played') == 0) {
                c.sfx('locked');
                c.say(strAtticTrunkLocked);
              } else if (s.flag('attic_got_will') == 0) {
                s.setFlag('attic_got_will', 1);
                c.sfx('door_open');
                c.say(strAtticWill);
              } else {
                c.sfx('wood_creak_open');
                s.setFlag('attic_done', 1);
              }
            }),
        Hotspot(
            id: 'window',
            area: const Rect.fromLTWH(0.76, 0.28, 0.20, 0.26),
            onTap: (c) => c.say(strAtticWindow)),
      ]),
    ],
    closeups: {
      'embroidery': Scene(
          id: 'embroidery', image: 'assets/scenes/attic_embroidery.png'),
      'organ': Scene(id: 'organ', custom: (_, c) => OrganKeys(ctx: c)),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_attic_cards', title: '오르간과 카드', steps: [
        '여정에서 모은 음표 카드 네 장이 필요해요. 보면대에 놓으세요',
        '카드를 하나씩 선택해 보면대를 탭 — 네 장 전부',
        '정답: ♪달·♪별·♪해·♪구름 카드를 모두 보면대에.',
      ], solved: (s) => s.flag('attic_cards_placed') >= 4),
      PuzzleHint(puzzleId: 'p_attic_order', title: '연주 순서', steps: [
        '순서는 이 방의 오래된 물건에 수놓아져 있어요',
        '자수: 달→해→별→구름. 카드가 알려준 음 매핑과 합치면?',
        '정답: 도(달)→미(해)→레(별)→파(구름) — 건반 1·3·2·4 순서.',
      ], solved: (s) => s.flag('attic_organ_played') >= 1),
      PuzzleHint(puzzleId: 'p_attic_trunk', title: '삼촌의 트렁크', steps: [
        '이 트렁크엔 열쇠 구멍이 없어요. 음악으로 여는 자물쇠',
        '오르간을 올바로 연주하면 열려요',
        '정답: 연주 성공 후 트렁크를 탭 — 유언장을 읽고 한 번 더 탭하면 탈출.',
      ], solved: (s) => s.flag('attic_done') >= 1),
    ],
  );
}
