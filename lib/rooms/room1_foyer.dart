import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/rub_scene.dart';
import '../core/scene_view.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──

/// 시침 탭: 1→12 순환. 3시 도달 시 서랍 해금.
void tapClockHand(GameState s) {
  final cur = s.flag('foyer_clock_hour') == 0 ? 12 : s.flag('foyer_clock_hour');
  final next = cur % 12 + 1;
  s.setFlag('foyer_clock_hour', next);
  if (next == 3) s.setFlag('foyer_drawer_unlocked', 1);
}

/// 액자 먼지 닦기 완료.
void finishRubbing(GameState s) => s.setFlag('foyer_dust_cleaned', 1);

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
        final hour = s.flag('foyer_clock_hour') == 0 ? 12 : s.flag('foyer_clock_hour');
        return GestureDetector(
          key: const Key('clock_tap'),
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final before = s.flag('foyer_drawer_unlocked');
            tapClockHand(s);
            ctx.sfx('clock_tick');
            if (before == 0 && s.flag('foyer_drawer_unlocked') == 1) {
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

/// 액자 클로즈업: 먼지를 문질러 닦는다. 실제 문지르기 로직은 RubbableScene으로
/// 추출됐다 — 이 클래스는 room1_foyer_test.dart가 직접 위젯 생성해 테스트하므로
/// (회귀 그물, 수정 금지) 얇은 위임 래퍼로만 남긴다.
class FrameCloseup extends StatelessWidget {
  final GameCtx ctx;
  const FrameCloseup({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) => RubbableScene(
        ctx: ctx,
        baseImage: 'assets/scenes/foyer_frame_clean.png',
        coverImage: 'assets/scenes/foyer_frame_dust.png',
        cleaned: (s) => s.flag('foyer_dust_cleaned') >= 1,
        onCleaned: (c) {
          finishRubbing(c.s);
          c.sfx('sparkle');
        },
        gestureKey: const Key('frame_rub'),
      );
}

// ── 방 정의 ──

Room buildFoyer() {
  Cond flagSet(String k) => (s) => s.flag(k) >= 1;

  return Room(
    id: 'foyer',
    name: '현관',
    onEnter: (c) => c.say(strFoyerIntro),
    cleared: flagSet('foyer_done'),
    walls: [
      // 벽면 A: 안쪽 문
      Scene(id: 'foyer_a', image: 'assets/scenes/foyer_a.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/foyer_a_door_open.png',
            area: const Rect.fromLTWH(0.36, 0.28, 0.28, 0.44),
            when: flagSet('foyer_inner_door_open')),
        SceneOverlay(
            image: 'assets/scenes/ghost_butler.png',
            area: const Rect.fromLTWH(0.02, 0.34, 0.20, 0.30),
            when: (s) => s.flag('foyer_done') == 0),
      ], hotspots: [
        Hotspot(
            id: 'inner_door',
            area: const Rect.fromLTWH(0.36, 0.28, 0.28, 0.44),
            onTap: (c) {
              final s = c.s;
              if (s.flag('foyer_inner_door_open') >= 1) {
                c.sfx('door_open');
                s.setFlag('foyer_done', 1);
              } else if (c.using('key_foyer')) {
                c.consume('key_foyer');
                c.sfx('unlock');
                s.setFlag('foyer_inner_door_open', 1);
                c.say(strFoyerDoorOpened);
              } else {
                c.sfx('locked');
                c.say(strFoyerDoorLocked);
              }
            }),
        Hotspot(
            id: 'ghost',
            area: const Rect.fromLTWH(0.02, 0.34, 0.20, 0.30),
            when: (s) => s.flag('foyer_done') == 0,
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
              if (c.s.flag('foyer_drawer_unlocked') >= 1) {
                c.openCloseup('drawer');
              } else {
                c.sfx('locked');
                c.say(strFoyerDrawerLocked);
              }
            }),
        Hotspot(
            id: 'umbrella_stand',
            area: const Rect.fromLTWH(0.02, 0.66, 0.14, 0.22),
            onTap: (c) => c.say(strFoyerUmbrella)),
      ]),
      // 벽면 B: 입구
      Scene(id: 'foyer_b', image: 'assets/scenes/foyer_b.png', hotspots: [
        Hotspot(
            id: 'coat',
            area: const Rect.fromLTWH(0.08, 0.28, 0.22, 0.36),
            onTap: (c) {
              if (c.s.flag('foyer_got_match') == 0) {
                c.s.setFlag('foyer_got_match', 1);
                c.give('match');
                c.say(strFoyerCoatMatch);
              } else {
                c.say(strFoyerCoatEmpty);
              }
            }),
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
            onTap: (c) => c.openCloseup('shoes')),
      ]),
    ],
    closeups: {
      'shoes': Scene(id: 'shoes', image: 'assets/scenes/foyer_shoes.png',
          overlays: [
            SceneOverlay(
                image: 'assets/scenes/foyer_shoes_candle.png',
                area: const Rect.fromLTWH(0.52, 0.34, 0.28, 0.32),
                when: (s) => s.flag('foyer_got_candle') == 0),
          ],
          hotspots: [
            Hotspot(
                id: 'candle_in_shoe',
                area: const Rect.fromLTWH(0.52, 0.34, 0.28, 0.32),
                when: (s) => s.flag('foyer_got_candle') == 0,
                onTap: (c) {
                  c.s.setFlag('foyer_got_candle', 1);
                  c.give('candle');
                  c.say(strFoyerCandleFound);
                }),
          ]),
      'drawer': Scene(id: 'drawer', image: 'assets/scenes/foyer_drawer_dark.png',
          overlays: [
            SceneOverlay(
                image: 'assets/scenes/foyer_drawer_lit.png',
                area: const Rect.fromLTWH(0, 0, 1, 1),
                when: flagSet('foyer_drawer_lit')),
          ],
          hotspots: [
            Hotspot(
                id: 'drawer_dark',
                area: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8),
                when: (s) => s.flag('foyer_drawer_lit') == 0,
                onTap: (c) {
                  if (c.using('lit_candle')) {
                    c.s.setFlag('foyer_drawer_lit', 1);
                    c.sfx('sparkle');
                  } else {
                    c.say(strFoyerDrawerDark);
                  }
                }),
            Hotspot(
                id: 'drawer_key',
                area: const Rect.fromLTWH(0.38, 0.42, 0.24, 0.16),
                when: (s) => s.flag('foyer_drawer_lit') >= 1 && s.flag('foyer_got_key') == 0,
                onTap: (c) {
                  c.s.setFlag('foyer_got_key', 1);
                  c.give('key_foyer');
                  c.say(strFoyerKeyFound);
                }),
          ]),
      'frame': Scene(
          id: 'frame',
          custom: (_, c) => RubbableScene(
                ctx: c,
                baseImage: 'assets/scenes/foyer_frame_clean.png',
                coverImage: 'assets/scenes/foyer_frame_dust.png',
                cleaned: (s) => s.flag('foyer_dust_cleaned') >= 1,
                onCleaned: (c) {
                  finishRubbing(c.s);
                  c.sfx('sparkle');
                },
                gestureKey: const Key('frame_rub'),
              )),
      'clock': Scene(id: 'clock', custom: (_, c) => ClockCloseup(ctx: c)),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_foyer_light', title: '어두운 서랍 속', steps: [
        '어둠 속을 보려면 불빛이 필요해요. 불을 만들 재료 두 가지가 이 현관 어딘가에 있어요.',
        '외투 주머니와 신발장 안을 살펴보세요. 인벤토리에서 두 아이템을 차례로 탭하면 조합할 수 있어요.',
        '정답: 외투에서 성냥, 신발장의 신발 속에서 양초를 얻어 조합하면 "불 켠 초". 서랍을 연 뒤 불 켠 초를 선택하고 서랍 안을 탭하세요.',
      ], solved: (s) => s.flag('foyer_drawer_lit') >= 1),
      PuzzleHint(puzzleId: 'p_foyer_clock', title: '잠긴 서랍', steps: [
        '서랍의 잠금은 이 방의 다른 물건과 연결돼 있어요. 벽에 걸린 것들을 잘 보세요.',
        '액자의 먼지를 손가락으로 문질러 닦으면 그림이 드러나요. 그림 속 시계가 가리키는 시각은?',
        '정답: 액자 그림의 시계는 3시. 입구 쪽 벽시계를 탭해 시침을 3시에 맞추면 서랍이 열려요.',
      ], solved: (s) => s.flag('foyer_drawer_unlocked') >= 1),
      PuzzleHint(puzzleId: 'p_foyer_door', title: '안쪽 문', steps: [
        '문을 열려면 열쇠가 필요해요. 아직 들여다보지 못한 곳이 있지 않나요?',
        '콘솔 서랍 깊은 곳 — 불을 비추면 반짝이는 게 보여요.',
        '정답: 서랍 안의 낡은 열쇠를 선택한 채 안쪽 문을 탭하면 열려요. 열린 문을 다시 탭하면 입장!',
      ], solved: (s) => s.flag('foyer_inner_door_open') >= 1),
    ],
  );
}
