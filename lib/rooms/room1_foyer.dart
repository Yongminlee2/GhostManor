import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/rub_scene.dart';
import '../core/scene_view.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──
// 리마스터: 전 플래그 foyer_r_ 접두어 (구세이브의 foyer_* 와 충돌 차단).

/// 시침 탭: 첫 탭은 1시, 이후 12시까지 순환. 3시 도달 시 서랍 해금.
void tapClockHand(GameState s) {
  final cur = s.flag('foyer_r_clock_hour');
  final next = cur >= 12 ? 1 : cur + 1;
  s.setFlag('foyer_r_clock_hour', next);
  // 정답 시각은 편지의 "셋째 시계"가 가리키는 3시. 12시 기준으로
  // 세 번 조작한 상태를 곧바로 3시로 보이게 한다.
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
        final hour = s.flag('foyer_r_clock_hour');
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              gameImage('assets/scenes/foyer_clock.png'),
              CustomPaint(painter: _HandPainter(hour)),
            ],
          ),
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
    final tip =
        center +
        Offset(math.sin(angle), -math.cos(angle)) * size.shortestSide * 0.28;
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = const Color(0xFFF5E6C8)
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
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
  Cond flagSet(String k) =>
      (s) => s.flag(k) >= 1;

  // 벽면 C(계단참) 핫스팟 rect — foyer_c.png 실측(우편함 좌중단, 거울 우측,
  // 초상화 2점 상단, 촛대 장식은 거울 아래, 중앙엔 어디로도 안 이어지는 장식 문).
  const mailboxArea = Rect.fromLTWH(0.06, 0.40, 0.19, 0.17);
  const mirrorArea = Rect.fromLTWH(0.70, 0.29, 0.24, 0.25);
  const portrait1Area = Rect.fromLTWH(0.10, 0.09, 0.24, 0.20);
  const portrait2Area = Rect.fromLTWH(0.65, 0.08, 0.24, 0.20);
  const candlestickArea = Rect.fromLTWH(0.72, 0.52, 0.19, 0.16);
  const consoleTableArea = Rect.fromLTWH(0.32, 0.40, 0.36, 0.33);
  const rugArea = Rect.fromLTWH(0.10, 0.76, 0.80, 0.20);

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
      Scene(
        id: 'foyer_a',
        image: 'assets/scenes/foyer_a.png',
        overlays: [
          SceneOverlay(
            image: 'assets/scenes/foyer_a_door_open.png',
            area: const Rect.fromLTWH(0.36, 0.28, 0.28, 0.44),
            when: flagSet('foyer_r_inner_door_open'),
            motion: OverlayMotion.grow,
          ),
        ],
        idles: [
          IdleSprite(
            image: 'assets/scenes/ghost_butler.png',
            area: const Rect.fromLTWH(0.02, 0.34, 0.20, 0.30),
            when: (s) => s.flag('foyer_r_done') == 0,
            bobPx: 7,
          ),
        ],
        hotspots: [
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
            },
          ),
          Hotspot(
            id: 'ghost',
            area: const Rect.fromLTWH(0.02, 0.34, 0.20, 0.30),
            when: (s) => s.flag('foyer_r_done') == 0,
            onTap: (c) {
              c.sfx('ghost_giggle');
              c.say(strFoyerGhostChat);
            },
          ),
          Hotspot(
            id: 'frame',
            area: const Rect.fromLTWH(0.66, 0.12, 0.24, 0.20),
            onTap: (c) => c.openCloseup('frame'),
          ),
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
            },
          ),
          Hotspot(
            id: 'umbrella_stand',
            area: const Rect.fromLTWH(0.02, 0.66, 0.14, 0.22),
            onTap: (c) => c.say(strFoyerUmbrella),
          ),
        ],
      ),
      // 벽면 B: 입구·외투·벽시계·신발장 (기존 아트)
      Scene(
        id: 'foyer_b',
        image: 'assets/scenes/foyer_b.png',
        hotspots: [
          Hotspot(
            id: 'coat',
            area: const Rect.fromLTWH(0.08, 0.28, 0.22, 0.36),
            onTap: (c) => c.openCloseup('coat'),
          ),
          Hotspot(
            id: 'clock',
            area: const Rect.fromLTWH(0.40, 0.08, 0.20, 0.16),
            onTap: (c) => c.openCloseup('clock'),
          ),
          // 리터치 4차에서 우측 신발장이 거울·스툴로 바뀌고 중앙에 대형
          // 벽장이 생겼다 — 구두 선반 클로즈업(foyer_shoes)은 이제 이 벽장
          // 안쪽이라는 설정으로 rect를 벽장에 얹는다.
          Hotspot(
            id: 'shoe_cabinet',
            area: const Rect.fromLTWH(0.29, 0.23, 0.40, 0.52),
            onTap: (c) {
              c.sfx('wood_slide');
              c.openCloseup('shoes');
            },
          ),
        ],
      ),
      // 벽면 C: 계단참 — 우편함은 함 클로즈업을 먼저 열고, 그 안의 편지를
      // 탭해야 편지 클로즈업(상호작용 밀도 + 납품된 foyer_mailbox.png 사용).
      Scene(
        id: 'foyer_c',
        image: 'assets/scenes/foyer_c.png',
        hotspots: [
          // 큰 풍미 rect(장식 문·깔개)를 먼저 — 뒤 선언이 겹침에서 이긴다.
          Hotspot(
            id: 'console_table',
            area: consoleTableArea,
            onTap: (c) => c.say(strFoyerRConsoleTable),
          ),
          Hotspot(id: 'rug', area: rugArea, onTap: (c) => c.say(strFoyerRRug)),
          Hotspot(
            id: 'portrait1',
            area: portrait1Area,
            onTap: (c) => c.say(strFoyerRPortrait1),
          ),
          Hotspot(
            id: 'portrait2',
            area: portrait2Area,
            onTap: (c) => c.say(strFoyerRPortrait2),
          ),
          Hotspot(
            id: 'candlestick_deco',
            area: candlestickArea,
            onTap: (c) => c.say(strFoyerRCandlestick),
          ),
          Hotspot(
            id: 'mirror',
            area: mirrorArea,
            onTap: (c) => c.say(strFoyerRMirror),
          ),
          Hotspot(
            id: 'mailbox',
            area: mailboxArea,
            onTap: (c) {
              c.sfx('wood_creak_open');
              c.openCloseup('mailbox');
            },
          ),
        ],
      ),
    ],
    closeups: {
      'mailbox': Scene(
        id: 'mailbox',
        image: 'assets/scenes/foyer_mailbox.png',
        overlays: [
          SceneOverlay(
            image: 'assets/scenes/foyer_mailbox_empty.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('foyer_r_got_letter'),
          ),
        ],
        hotspots: [
          Hotspot(
            id: 'letter_in_box',
            area: const Rect.fromLTWH(0.30, 0.32, 0.42, 0.26),
            onTap: (c) {
              if (c.s.flag('foyer_r_got_letter') == 0) {
                c.s.setFlag('foyer_r_got_letter', 1);
                c.give('letter1');
                c.sfx('paper_rustle');
              }
              c.openCloseup('letter1');
              c.say(strFoyerRLetter1);
            },
          ),
        ],
      ),
      'coat': Scene(
        id: 'coat',
        custom: (_, c) => c.s.flag('foyer_r_got_match') >= 1
            ? gameImage('assets/scenes/foyer_coat_empty.png')
            : RubbableScene(
                ctx: c,
                baseImage: 'assets/scenes/foyer_coat_clean.png',
                coverImage: 'assets/scenes/foyer_coat_dust.png',
                cleaned: (s) => false,
                onCleaned: (c) {
                  finishCoatRub(c.s);
                  c.sfx('sparkle');
                  c.say(strFoyerRCoatMatch);
                },
                gestureKey: const Key('coat_rub'),
              ),
      ),
      'shoes': Scene(
        id: 'shoes',
        image: 'assets/scenes/foyer_shoes.png',
        overlays: [
          SceneOverlay(
            image: 'assets/scenes/foyer_shoes_candle.png',
            area: shoe3CandleArea,
            when: (s) => s.flag('foyer_r_got_candle') == 0,
          ),
        ],
        hotspots: [
          Hotspot(
            id: 'shoe1',
            area: const Rect.fromLTWH(0.04, 0.30, 0.22, 0.36),
            onTap: (c) => c.say(strFoyerRShoe1),
          ),
          Hotspot(
            id: 'shoe2',
            area: const Rect.fromLTWH(0.28, 0.30, 0.22, 0.36),
            onTap: (c) => c.say(strFoyerRShoe2),
          ),
          Hotspot(
            id: 'shoe3_candle',
            area: shoe3CandleArea,
            when: (s) => s.flag('foyer_r_got_candle') == 0,
            onTap: (c) {
              c.s.setFlag('foyer_r_got_candle', 1);
              c.give('candle');
              c.say(strFoyerCandleFound);
            },
          ),
        ],
      ),
      'drawer': Scene(
        id: 'drawer',
        image: 'assets/scenes/foyer_drawer_dark.png',
        overlays: [
          SceneOverlay(
            image: 'assets/scenes/foyer_drawer_lit.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: (s) =>
                s.flag('foyer_r_drawer_lit') >= 1 &&
                s.flag('foyer_r_got_key') == 0,
            motion: OverlayMotion.grow,
          ),
          // 열쇠를 집은 뒤엔 열쇠가 지워진 버전 — 획득 후에도 그림에 열쇠가
          // 남아 있던 실기기 지적 반영.
          SceneOverlay(
            image: 'assets/scenes/foyer_drawer_empty.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: flagSet('foyer_r_got_key'),
          ),
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
            },
          ),
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
            },
          ),
        ],
      ),
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
        ),
      ),
      'clock': Scene(
        id: 'clock',
        custom: (_, c) => ClockCloseup(ctx: c),
      ),
      'letter1': Scene(id: 'letter1', image: 'assets/scenes/foyer_letter1.png'),
    },
    hints: [
      PuzzleHint(
        puzzleId: 'p_foyer_r_light',
        title: '어두운 서랍 속',
        steps: [
          '불빛이 필요해요. 걸려 있는 것과 신어 보는 것들을 뒤져보세요.',
          '외투를 문지르고, 신발장 구두를 하나씩 살펴보세요.',
          '정답: 성냥과 양초를 조합해 불 켠 초를 만드세요.',
        ],
        solved: (s) => s.flag('foyer_r_drawer_lit') >= 1,
      ),
      PuzzleHint(
        puzzleId: 'p_foyer_r_clock',
        title: '잠긴 서랍',
        steps: [
          '시계가 여럿 그려진 그림과 누군가의 편지 — 함께 읽어야 해요.',
          '편지의 "셋째"가 그림의 몇 번째 시계인지 세어 보세요.',
          '정답: 그림 속 셋째 시계는 3시 — 벽시계를 3시로 맞추세요.',
        ],
        solved: (s) => s.flag('foyer_r_drawer_unlocked') >= 1,
      ),
      PuzzleHint(
        puzzleId: 'p_foyer_r_door',
        title: '안쪽 문',
        steps: [
          '서랍 안이 너무 어두워요.',
          '불 켠 초를 선택해 서랍 안을 탭하세요.',
          '정답: 열쇠를 얻어 문에 사용하세요.',
        ],
        solved: (s) => s.flag('foyer_r_inner_door_open') >= 1,
      ),
    ],
  );
}
