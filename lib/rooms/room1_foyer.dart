import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/rub_scene.dart';
import '../core/scene_view.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──
// 리마스터: 전 플래그 foyer_r_ 접두어 (구세이브의 foyer_* 와 충돌 차단).

/// 시침 탭: 1→12 순환. 3시 도달 시 서랍 해금.
void tapClockHand(GameState s) {
  final cur = s.flag('foyer_r_clock_hour') == 0 ? 12 : s.flag('foyer_r_clock_hour');
  final next = cur % 12 + 1;
  s.setFlag('foyer_r_clock_hour', next);
  if (next == 3) s.setFlag('foyer_r_drawer_unlocked', 1);
}

/// 외투 먼지 문지르기 완료 → 성냥 지급 (RubbableScene.onCleaned가 감싸 호출).
void finishCoatRub(GameState s) {
  s.setFlag('foyer_r_got_match', 1);
  s.give('match');
}

/// 액자 먼지 문지르기 완료 → 시계 4개 그림 노출(셋째 시계가 단서).
void finishFrameRub(GameState s) => s.setFlag('foyer_r_dust_cleaned', 1);

// ── 커스텀 기믹 위젯 (escape hatch) ──

/// 벽시계 클로즈업: 탭할 때마다 시침이 한 칸 돈다.
class ClockCloseup extends StatelessWidget {
  final GameCtx ctx;
  const ClockCloseup({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final s = ctx.s;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final hour = s.flag('foyer_r_clock_hour') == 0 ? 12 : s.flag('foyer_r_clock_hour');
        return GestureDetector(
          key: const Key('clock_tap'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final before = s.flag('foyer_r_drawer_unlocked');
            tapClockHand(s);
            ctx.sfx('clock_tick');
            if (before == 0 && s.flag('foyer_r_drawer_unlocked') == 1) {
              ctx.sfx('unlock');
              ctx.say(strFoyerClockSet);
            }
          },
          child: Stack(fit: StackFit.expand, children: [
            gameImage('assets/scenes/foyer_clock.png'),
            CustomPaint(painter: _HandPainter(hour)),
          ]),
        );
      },
    );
  }
}

class _HandPainter extends CustomPainter {
  final int hour;
  _HandPainter(this.hour);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final angle = hour * 2 * math.pi / 12;
    final tip = center +
        Offset(math.sin(angle), -math.cos(angle)) * size.shortestSide * 0.28;
    canvas.drawLine(
        center,
        tip,
        Paint()
          ..color = const Color(0xFFF5E6C8)
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_HandPainter old) => old.hour != hour;
}

// ── 방 정의 ──
//
// 스레드 구조(브리프): T1 빛 만들기(외투 문지르기→성냥 / 신발장→양초 / 조합)
// ‖ T2 시계 코드(액자 문지르기→시계 4개 그림 / 우편함→편지 "셋째 시계의 시각" /
// 벽시계를 3시로) → 교차: 서랍은 어두워 T1의 불 켠 초가 필요 → 열쇠 → 문.
Room buildFoyer() {
  Cond flagSet(String k) => (s) => s.flag(k) >= 1;

  // 벽면 C(계단참) 핫스팟 rect — mailbox/mirror는 브리프 binding 좌표, 나머지는
  // 서로 겹치지 않게 배치(hotspot_resolution_test 예외 불필요하도록).
  const mailboxArea = Rect.fromLTWH(0.10, 0.30, 0.18, 0.16);
  const mirrorArea = Rect.fromLTWH(0.62, 0.24, 0.22, 0.30);
  const portrait1Area = Rect.fromLTWH(0.08, 0.04, 0.22, 0.18);
  const portrait2Area = Rect.fromLTWH(0.60, 0.04, 0.24, 0.18);
  const candlestickArea = Rect.fromLTWH(0.40, 0.14, 0.14, 0.20);
  const rugArea = Rect.fromLTWH(0.24, 0.70, 0.52, 0.22);

  // shoes 클로즈업의 양초 rect — 기존 실제 아트(foyer_shoes_candle.png) 위치 그대로
  // 재사용(신규 shoe1/shoe2는 그 왼쪽 빈 공간에 배치).
  const shoe3CandleArea = Rect.fromLTWH(0.52, 0.34, 0.28, 0.32);

  return Room(
    id: 'foyer',
    name: '현관',
    onEnter: (c) => c.say(strFoyerIntro),
    cleared: flagSet('foyer_r_done'),
    walls: [
      // 벽면 A: 안쪽 문·액자·콘솔(서랍)·우산꽂이 (기존 아트)
      Scene(id: 'foyer_a', image: 'assets/scenes/foyer_a.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/foyer_a_door_open.png',
            area: const Rect.fromLTWH(0.36, 0.28, 0.28, 0.44),
            when: flagSet('foyer_r_inner_door_open'),
            motion: OverlayMotion.grow),
      ], idles: [
        IdleSprite(
            image: 'assets/scenes/ghost_butler.png',
            area: const Rect.fromLTWH(0.02, 0.34, 0.20, 0.30),
            when: (s) => s.flag('foyer_r_done') == 0,
            bobPx: 7),
      ], hotspots: [
        Hotspot(
            id: 'inner_door',
            area: const Rect.fromLTWH(0.36, 0.28, 0.28, 0.44),
            onTap: (c) {
              final s = c.s;
              if (s.flag('foyer_r_inner_door_open') >= 1) {
                c.sfx('door_open');
                s.setFlag('foyer_r_done', 1);
              } else if (c.using('key_foyer')) {
                c.consume('key_foyer');
                c.sfx('metal_key');
                s.setFlag('foyer_r_inner_door_open', 1);
                c.say(strFoyerDoorOpened);
              } else {
                c.sfx('locked');
                c.say(strFoyerDoorLocked);
              }
            }),
        Hotspot(
            id: 'ghost',
            area: const Rect.fromLTWH(0.02, 0.34, 0.20, 0.30),
            when: (s) => s.flag('foyer_r_done') == 0,
            onTap: (c) {
              c.sfx('ghost_giggle');
              c.say(strFoyerGhostChat);
            }),
        Hotspot(
            id: 'frame',
            area: const Rect.fromLTWH(0.66, 0.12, 0.24, 0.20),
            onTap: (c) => c.openCloseup('frame')),
        Hotspot(
            id: 'drawer',
            area: const Rect.fromLTWH(0.64, 0.52, 0.28, 0.16),
            onTap: (c) {
              if (c.s.flag('foyer_r_drawer_unlocked') >= 1) {
                c.sfx('wood_slide');
                c.openCloseup('drawer');
              } else {
                c.sfx('locked');
                c.say(strFoyerRDrawerLocked);
              }
            }),
        Hotspot(
            id: 'umbrella_stand',
            area: const Rect.fromLTWH(0.02, 0.66, 0.14, 0.22),
            onTap: (c) => c.say(strFoyerUmbrella)),
      ]),
      // 벽면 B: 입구·외투·벽시계·신발장 (기존 아트)
      Scene(id: 'foyer_b', image: 'assets/scenes/foyer_b.png', hotspots: [
        Hotspot(
            id: 'coat',
            area: const Rect.fromLTWH(0.08, 0.28, 0.22, 0.36),
            onTap: (c) => c.openCloseup('coat')),
        Hotspot(
            id: 'clock',
            area: const Rect.fromLTWH(0.40, 0.08, 0.20, 0.16),
            onTap: (c) => c.openCloseup('clock')),
        Hotspot(
            id: 'front_door',
            area: const Rect.fromLTWH(0.36, 0.30, 0.28, 0.42),
            onTap: (c) => c.say(strFoyerFrontDoor)),
        Hotspot(
            id: 'shoe_cabinet',
            area: const Rect.fromLTWH(0.66, 0.56, 0.30, 0.26),
            onTap: (c) {
              c.sfx('wood_slide');
              c.openCloseup('shoes');
            }),
      ]),
      // 벽면 C: 계단참 (신규 — 아트 도착 전이라 라벨 블록으로 대체됨)
      Scene(id: 'foyer_c', image: 'assets/scenes/foyer_c.png', hotspots: [
        Hotspot(
            id: 'portrait1',
            area: portrait1Area,
            onTap: (c) => c.say(strFoyerRPortrait1)),
        Hotspot(
            id: 'portrait2',
            area: portrait2Area,
            onTap: (c) => c.say(strFoyerRPortrait2)),
        Hotspot(
            id: 'candlestick_deco',
            area: candlestickArea,
            onTap: (c) => c.say(strFoyerRCandlestick)),
        Hotspot(id: 'rug', area: rugArea, onTap: (c) => c.say(strFoyerRRug)),
        Hotspot(
            id: 'mirror',
            area: mirrorArea,
            onTap: (c) => c.say(strFoyerRMirror)),
        Hotspot(
            id: 'mailbox',
            area: mailboxArea,
            onTap: (c) {
              if (c.s.flag('foyer_r_got_letter') == 0) {
                c.s.setFlag('foyer_r_got_letter', 1);
                c.give('letter1');
                c.sfx('paper_rustle');
              }
              c.openCloseup('letter1');
              c.say(strFoyerRLetter1);
            }),
      ]),
    ],
    closeups: {
      'coat': Scene(
          id: 'coat',
          custom: (_, c) => RubbableScene(
                ctx: c,
                baseImage: 'assets/scenes/foyer_coat_clean.png',
                coverImage: 'assets/scenes/foyer_coat_dust.png',
                cleaned: (s) => s.flag('foyer_r_got_match') >= 1,
                onCleaned: (c) {
                  finishCoatRub(c.s);
                  c.sfx('sparkle');
                  c.say(strFoyerRCoatMatch);
                },
                gestureKey: const Key('coat_rub'),
              )),
      'shoes': Scene(
          id: 'shoes',
          image: 'assets/scenes/foyer_shoes.png',
          overlays: [
            SceneOverlay(
                image: 'assets/scenes/foyer_shoes_candle.png',
                area: shoe3CandleArea,
                when: (s) => s.flag('foyer_r_got_candle') == 0),
          ],
          hotspots: [
            Hotspot(
                id: 'shoe1',
                area: const Rect.fromLTWH(0.04, 0.30, 0.22, 0.36),
                onTap: (c) => c.say(strFoyerRShoe1)),
            Hotspot(
                id: 'shoe2',
                area: const Rect.fromLTWH(0.28, 0.30, 0.22, 0.36),
                onTap: (c) => c.say(strFoyerRShoe2)),
            Hotspot(
                id: 'shoe3_candle',
                area: shoe3CandleArea,
                when: (s) => s.flag('foyer_r_got_candle') == 0,
                onTap: (c) {
                  c.s.setFlag('foyer_r_got_candle', 1);
                  c.give('candle');
                  c.say(strFoyerCandleFound);
                }),
          ]),
      'drawer': Scene(
          id: 'drawer',
          image: 'assets/scenes/foyer_drawer_dark.png',
          overlays: [
            SceneOverlay(
                image: 'assets/scenes/foyer_drawer_lit.png',
                area: const Rect.fromLTWH(0, 0, 1, 1),
                when: flagSet('foyer_r_drawer_lit'),
                motion: OverlayMotion.grow),
          ],
          hotspots: [
            Hotspot(
                id: 'drawer_dark',
                area: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8),
                when: (s) => s.flag('foyer_r_drawer_lit') == 0,
                onTap: (c) {
                  if (c.using('lit_candle')) {
                    c.s.setFlag('foyer_r_drawer_lit', 1);
                    c.sfx('sparkle');
                  } else {
                    c.say(strFoyerDrawerDark);
                  }
                }),
            Hotspot(
                id: 'drawer_key',
                area: const Rect.fromLTWH(0.38, 0.42, 0.24, 0.16),
                when: (s) =>
                    s.flag('foyer_r_drawer_lit') >= 1 &&
                    s.flag('foyer_r_got_key') == 0,
                onTap: (c) {
                  c.s.setFlag('foyer_r_got_key', 1);
                  c.give('key_foyer');
                  c.sfx('metal_key');
                  c.say(strFoyerKeyFound);
                }),
          ]),
      'frame': Scene(
          id: 'frame',
          custom: (_, c) => RubbableScene(
                ctx: c,
                baseImage: 'assets/scenes/foyer_frame_clean2.png',
                coverImage: 'assets/scenes/foyer_frame_dust.png',
                cleaned: (s) => s.flag('foyer_r_dust_cleaned') >= 1,
                onCleaned: (c) {
                  finishFrameRub(c.s);
                  c.sfx('sparkle');
                },
                gestureKey: const Key('frame_rub'),
              )),
      'clock': Scene(id: 'clock', custom: (_, c) => ClockCloseup(ctx: c)),
      'letter1':
          Scene(id: 'letter1', image: 'assets/scenes/foyer_letter1.png'),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_foyer_r_light', title: '어두운 서랍 속', steps: [
        '불빛이 필요해요. 걸려 있는 것과 신어 보는 것들을 뒤져보세요.',
        '외투를 문지르고, 신발장 구두를 하나씩 살펴보세요.',
        '정답: 성냥과 양초를 조합해 불 켠 초를 만드세요.',
      ], solved: (s) => s.flag('foyer_r_drawer_lit') >= 1),
      PuzzleHint(puzzleId: 'p_foyer_r_clock', title: '잠긴 서랍', steps: [
        '시계가 여럿 그려진 그림과 누군가의 편지 — 함께 읽어야 해요.',
        '편지의 "셋째"가 그림의 몇 번째 시계인지 세어 보세요.',
        '정답: 그림 속 셋째 시계는 3시 — 벽시계를 3시로 맞추세요.',
      ], solved: (s) => s.flag('foyer_r_drawer_unlocked') >= 1),
      PuzzleHint(puzzleId: 'p_foyer_r_door', title: '안쪽 문', steps: [
        '서랍 안이 너무 어두워요.',
        '불 켠 초를 선택해 서랍 안을 탭하세요.',
        '정답: 열쇠를 얻어 문에 사용하세요.',
      ], solved: (s) => s.flag('foyer_r_inner_door_open') >= 1),
    ],
  );
}
