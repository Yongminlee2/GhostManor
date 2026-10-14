import 'package:flutter/material.dart';
import '../core/dial_safe.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/scene_view.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──
// 리마스터: 전 플래그 attic_r_ 접두어 (구세이브의 attic_* 와 충돌 차단).
//
// 스레드 구조(브리프): T1 오르간 연주(카드 4장 배치 + 순서 단서 = 자수 반쪽
// [달→해, 벽B] + T2가 준 찢긴 조각[별·구름]을 자수에 맞춰 완성) ‖ T2 작은
// 궤짝 3자리(벽C, 다락 소품 개수: 촛대 양초3·창문 칸4·책더미2 = 342, 단서는
// 낡은 쪽지) → 교차: T2(궤짝)의 보상 shred가 T1(자수 완성)의 재료. 두 단서
// (쪽지·자수)는 지식일 뿐 게이트가 아니다 — 궤짝은 342만 알면 열리고, 연주는
// 카드 4장+정확한 순서만 있으면 자수 완성 여부와 무관하게 성공한다(기존
// OrganKeys/tapOrganKey는 고정 순서 [1,3,2,4]만 검사 — 자수 상태를 아예 읽지
// 않는다). 성공 → 트렁크 → 유언장 → 엔딩(엔딩 흐름·대사는 원본 그대로 유지).

/// 오르간 건반 i(1..4) 탭. cards_placed<4면 no-op(악보 미완성). 정답 순서
/// [1,3,2,4](도미레파)대로면 attic_r_organ_seq +1, 틀리면 0으로 리셋. 4단계
/// 도달 시 attic_r_organ_played=1. 완료 후 재탭은 no-op — order 배열 범위 밖
/// 인덱스 접근을 막는다(room3 tapBook의 nook_open 가드와 동일한 이유).
void tapOrganKey(GameState s, int i) {
  if (s.flag('attic_r_cards_placed') < 4) return;
  if (s.flag('attic_r_organ_played') >= 1) return;
  const order = [1, 3, 2, 4];
  final seq = s.flag('attic_r_organ_seq');
  if (order[seq] == i) {
    final next = seq + 1;
    s.setFlag('attic_r_organ_seq', next);
    if (next == 4) s.setFlag('attic_r_organ_played', 1);
  } else {
    s.setFlag('attic_r_organ_seq', 0);
  }
}

/// 궤짝 다이얼 정답 확인 성공 시 1회 호출(DialSafe의 원샷 가드가 감싼다).
/// 자수 조각(shred)을 지급 — T1(자수 완성→연주 순서 확신)의 재료가 되는
/// 교차 잠금(브리프: "T2의 보상이 T1의 재료").
void openChest(GameCtx c) {
  final s = c.s;
  s.setFlag('attic_r_chest_open', 1);
  c.sfx('uncork'); // 걸쇠가 튀는 소리
  c.sfx('wood_creak_open'); // 이어서 나무 뚜껑이 열리는 소리
  c.give('shred');
  c.say(strAtticRChestOpen);
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
    final beforeSeq = s.flag('attic_r_organ_seq');
    final wasPlayed = s.flag('attic_r_organ_played') >= 1;
    tapOrganKey(s, i);
    ctx.sfx('note$i');
    if (!wasPlayed && s.flag('attic_r_organ_played') >= 1) {
      ctx.sfx('organ_chord');
      ctx.say(strAtticOrganPlayed);
    } else if (s.flag('attic_r_organ_seq') == 0 && beforeSeq > 0) {
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
        // 건반 판마다 그 음을 내는 음표 카드 그림(아이폰판: 원래 빈 양피지라 어느 건반이
        // 무슨 카드인지 알 수 없었다). 건반 i = 카드 note i(달·별·해·구름 = 도·레·미·파).
        Positioned(
          left: box.maxWidth * 0.035,
          right: box.maxWidth * 0.035,
          bottom: box.maxHeight * 0.06,
          height: box.maxHeight * 0.3,
          child: IgnorePointer(
            child: Row(children: [
              for (var i = 1; i <= 4; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: box.maxWidth * 0.03),
                    child: Opacity(
                        opacity: 0.85,
                        child: Image.asset('assets/items/note$i.png', fit: BoxFit.contain)),
                  ),
                ),
            ]),
          ),
        ),
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

  // 벽C 잡동사니 다락 — 브리프 binding 좌표(궤짝·쪽지)는 그대로, 나머지
  // 소품은 좌표 미정(아트 의뢰서 비고)이라 서로 겹치지 않게 배치
  // (hotspot_resolution_test 예외 불필요하도록).
  // 벽 C rect — attic_c.png 실측: 궤짝(다이얼 자물쇠)은 좌하단, 쪽지는 바닥
  // 종이, 촛대(양초 셋)는 좌중단, 책 2권은 우하단. 아트에 없는 소품(거울·
  // 모자상자·오르골·목마)은 실물(달 창·자수틀·둥근 탁자·깔개)로 교체.
  const chestArea = Rect.fromLTWH(0.16, 0.70, 0.28, 0.19);
  const oldNoteArea = Rect.fromLTWH(0.02, 0.79, 0.17, 0.10);
  const candleHolderArea = Rect.fromLTWH(0.01, 0.44, 0.19, 0.20);
  const booksPileArea = Rect.fromLTWH(0.71, 0.77, 0.22, 0.13);
  const dollArea = Rect.fromLTWH(0.01, 0.10, 0.14, 0.14);
  const roundWindowArea = Rect.fromLTWH(0.66, 0.04, 0.32, 0.40);
  const stitchFrameArea = Rect.fromLTWH(0.27, 0.18, 0.32, 0.34);
  const roundTableArea = Rect.fromLTWH(0.79, 0.55, 0.20, 0.20);
  const rugArea = Rect.fromLTWH(0.12, 0.86, 0.30, 0.11);
  // 고스포는 attic_c.png에 그려져 있지 않다 — 궤짝과 책 더미 사이 빈 바닥을
  // "서성이는 기척" 영역으로 쓴다(잡동사니 사이라는 대사와 지형이 맞는 자리).
  const ghospoCArea = Rect.fromLTWH(0.46, 0.68, 0.18, 0.20);

  return Room(
    id: 'attic',
    name: '다락방',
    onEnter: (c) => c.say(strAtticIntro),
    cleared: flagSet('attic_r_done'),
    walls: [
      // 벽면 A: 오르간 벽 (기존 아트+로직 재사용, 플래그만 attic_r_)
      Scene(id: 'attic_a', image: 'assets/scenes/attic_a.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/attic_a_cards.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: (s) => s.flag('attic_r_cards_placed') >= 4,
            motion: OverlayMotion.fade),
      ], hotspots: [
        Hotspot(
            id: 'organ',
            area: const Rect.fromLTWH(0.24, 0.44, 0.52, 0.34),
            onTap: (c) {
              if (c.s.flag('attic_r_cards_placed') < 4) {
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
                c.say(s.flag('attic_r_cards_placed') < 4
                    ? strAtticStandEmpty
                    : strAtticStandFull);
                return;
              }
              c.consume(note);
              s.addFlag('attic_r_cards_placed');
              c.sfx('paper_rustle');
              if (s.flag('attic_r_cards_placed') >= 4) {
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
              c.say(c.s.flag('attic_r_organ_played') == 1
                  ? strAtticGhospoProud
                  : strAtticGhospoHint);
            }),
      ]),
      // 벽면 B: 트렁크·창문·자수 벽 (기존 아트+로직 재사용, 플래그만
      // attic_r_ — 자수 클로즈업만 찢긴 버전으로 교체, 창은 리액션 추가)
      Scene(id: 'attic_b', image: 'assets/scenes/attic_b.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/attic_b_trunk_open.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: (s) => s.flag('attic_r_organ_played') == 1,
            motion: OverlayMotion.fade),
        // 벽 액자 천 — 클로즈업과 같은 자수(아이폰판: 원래 나무 자수라 클로즈업과 달랐다)
        SceneOverlay(
            image: 'assets/scenes/attic_b_stitch.png',
            area: const Rect.fromLTWH(0.3359, 0.2357, 0.207, 0.2122),
            when: (s) => s.flag('attic_r_embroidery_full') == 0),
        SceneOverlay(
            image: 'assets/scenes/attic_b_stitch_full.png',
            area: const Rect.fromLTWH(0.3359, 0.2357, 0.207, 0.2122),
            when: flagSet('attic_r_embroidery_full')),
      ], hotspots: [
        Hotspot(
            id: 'embroidery',
            area: const Rect.fromLTWH(0.26, 0.19, 0.36, 0.28),
            onTap: (c) {
              final s = c.s;
              // 월드 조합 슬롯 패턴(설계 §4-2): 조각을 든 채 액자를 탭하면
              // 바로 장착. 이미 완성됐거나 조각이 없으면 그냥 구경만.
              if (s.flag('attic_r_embroidery_full') == 0 && c.using('shred')) {
                c.consume('shred');
                s.setFlag('attic_r_embroidery_full', 1);
                c.sfx('sparkle');
                c.say(strAtticREmbroideryFull);
              } else {
                c.openCloseup('embroidery');
              }
            }),
        Hotspot(
            id: 'trunk',
            area: const Rect.fromLTWH(0.36, 0.54, 0.34, 0.28),
            onTap: (c) {
              final s = c.s;
              if (s.flag('attic_r_organ_played') == 0) {
                c.sfx('locked');
                c.say(strAtticTrunkLocked);
              } else if (s.flag('attic_r_got_will') == 0) {
                s.setFlag('attic_r_got_will', 1);
                c.sfx('door_open');
                c.say(strAtticWill);
              } else {
                c.sfx('wood_creak_open');
                s.setFlag('attic_r_done', 1);
              }
            }),
        Hotspot(
            id: 'window',
            area: const Rect.fromLTWH(0.76, 0.28, 0.20, 0.26),
            onTap: (c) => c.say(strAtticWindow)),
      ]),
      // 벽면 C: 잡동사니 다락 (신규) — T2 궤짝·쪽지 + 소품 개수 단서(촛대·책
      // 더미) + 조사 전용 잡동사니(정답 정보 없음, 고스포 톤 유지).
      Scene(id: 'attic_c', image: 'assets/scenes/attic_c.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/attic_c_stitch.png',
            area: const Rect.fromLTWH(0.3359, 0.2357, 0.207, 0.2122),
            when: (s) => s.flag('attic_r_embroidery_full') == 0),
        SceneOverlay(
            image: 'assets/scenes/attic_c_stitch_full.png',
            area: const Rect.fromLTWH(0.3359, 0.2357, 0.207, 0.2122),
            when: flagSet('attic_r_embroidery_full')),
        SceneOverlay(
            image: 'assets/scenes/attic_c_chest_open.png',
            area: const Rect.fromLTWH(0.1465, 0.651, 0.3223, 0.1953),
            when: flagSet('attic_r_chest_open'),
            motion: OverlayMotion.grow),
      ], hotspots: [
        Hotspot(
            id: 'chest',
            area: chestArea,
            onTap: (c) {
              if (c.s.flag('attic_r_chest_open') >= 1) {
                c.say(strAtticRChestEmpty);
              } else {
                c.openCloseup('chest');
              }
            }),
        Hotspot(
            id: 'old_note',
            area: oldNoteArea,
            onTap: (c) {
              c.sfx('paper_rustle');
              c.openCloseup('old_note');
            }),
        Hotspot(
            id: 'candle_holder',
            area: candleHolderArea,
            onTap: (c) => c.say(strAtticRCandleHolder)),
        Hotspot(
            id: 'books_pile',
            area: booksPileArea,
            onTap: (c) => c.say(strAtticRBooksPile)),
        Hotspot(
            id: 'round_window',
            area: roundWindowArea,
            onTap: (c) => c.say(strAtticRWindowMoon)),
        Hotspot(
            id: 'stitch_frame',
            area: stitchFrameArea,
            onTap: (c) => c.say(strAtticRStitchFrame)),
        Hotspot(
            id: 'round_table',
            area: roundTableArea,
            onTap: (c) => c.say(strAtticRRoundTable)),
        Hotspot(id: 'rug', area: rugArea, onTap: (c) => c.say(strAtticRRug)),
        Hotspot(id: 'doll', area: dollArea, onTap: (c) => c.say(strAtticRDoll)),
        Hotspot(
            id: 'ghospo_c',
            area: ghospoCArea,
            onTap: (c) {
              c.sfx('ghost_giggle');
              c.say(strAtticRGhospoC);
            }),
      ]),
    ],
    closeups: {
      // 클로즈업 배경 자체가 "찢긴" 상태 — 완성되면 attic_embroidery_full.png가
      // 그 위를 덮는다(오버레이, living TV 장면전환과 동일 패턴).
      'embroidery': Scene(
          id: 'embroidery',
          image: 'assets/scenes/attic_embroidery2.png',
          overlays: [
            SceneOverlay(
                image: 'assets/scenes/attic_embroidery_full.png',
                area: const Rect.fromLTWH(0, 0, 1, 1),
                when: flagSet('attic_r_embroidery_full'),
                motion: OverlayMotion.fade),
          ]),
      'organ': Scene(id: 'organ', custom: (_, c) => OrganKeys(ctx: c)),
      'old_note':
          Scene(id: 'old_note', image: 'assets/scenes/attic_note.png'),
      // 다이얼 궤짝: 배경은 여기서 겹쳐 쌓고(DialSafe는 배경을 그리지 않음),
      // 위젯이 휠 3개+확인 버튼을 그 위에 올린다(거실 4자리 금고와 동일
      // 패턴 — digits만 3으로, flagPrefix가 달라 플래그 네임스페이스도 분리).
      'chest': Scene(
          id: 'chest',
          custom: (_, c) => Stack(fit: StackFit.expand, children: [
                gameImage('assets/scenes/attic_c_chest_dial.png'),
                DialSafe(
                  ctx: c,
                  digits: 3,
                  code: '342',
                  flagPrefix: 'attic_r_chest',
                  wrongSay: strAtticRChestWrong,
                  onOpened: openChest,
                ),
              ])),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_attic_r_chest', title: '작은 궤짝', steps: [
        '쪽지의 세 그림이 이 다락 어딘가의 "개수"예요',
        '촛불·창문 칸·책 더미를 세어보세요',
        '정답: 3-4-2',
      ], solved: (s) => s.flag('attic_r_chest_open') >= 1),
      PuzzleHint(puzzleId: 'p_attic_r_order', title: '연주 순서', steps: [
        '자수가 찢겨 있어요 — 나머지 반쪽이 어딘가에',
        '궤짝 속 조각을 자수에 맞추면 순서 완성',
        '정답: 달해별구름 = 도미레파 = 건반 1·3·2·4',
      ], solved: (s) => s.flag('attic_r_organ_played') >= 1),
      PuzzleHint(puzzleId: 'p_attic_r_trunk', title: '삼촌의 트렁크', steps: [
        '이 트렁크엔 열쇠 구멍이 없어요. 음악으로 여는 자물쇠',
        '오르간을 올바로 연주하면 열려요',
        '정답: 연주 성공 후 트렁크를 탭 — 유언장을 읽고 한 번 더 탭하면 탈출.',
      ], solved: (s) => s.flag('attic_r_done') >= 1),
    ],
  );
}
