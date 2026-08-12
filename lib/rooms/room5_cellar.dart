import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/scene_view.dart';
import '../core/strings.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──

/// 와인통 드래그 진행도 누적. 불이 켜진 상태에서만 진행된다(어두우면 no-op).
/// dx(픽셀 이동량)를 진행도 0~100 정수로 환산해 누적하고 100에서 클램프,
/// 100 도달 시 cellar_barrel_moved=1.
void moveBarrel(GameState s, double dx) {
  if (s.flag('cellar_light') == 0) return;
  final raw = s.flag('cellar_barrel_px') + (dx / 6).round();
  final next = raw.clamp(0, 100).toInt();
  s.setFlag('cellar_barrel_px', next);
  if (next >= 100) s.setFlag('cellar_barrel_moved', 1);
}

/// 선반 흔들기(센서) 또는 연타 폴백 공통 도착지: 불이 켜져 있고 아직
/// 떨어뜨리지 않았을 때만 열쇠를 떨어뜨린다.
void dropShelfKey(GameState s) {
  if (s.flag('cellar_light') == 0) return;
  if (s.flag('cellar_key_dropped') >= 1) return;
  s.setFlag('cellar_key_dropped', 1);
}

/// 선반 연타 폴백(접근성 — 흔들기가 어려운 사용자용): 10회 누적 시 낙하.
void tapShelf(GameState s) {
  s.addFlag('cellar_shelf_taps');
  if (s.flag('cellar_shelf_taps') >= 10) dropShelfKey(s);
}

// ── 커스텀 기믹 위젯 (escape hatch) ──

/// 와인통 클로즈업: 드래그로 밀어 진행도를 쌓는다(양방향 허용). 100% 도달 시
/// 쪽문이 드러나는 순간 1회 sfx+대사. 완료 후엔 드래그 무시.
class BarrelDrag extends StatelessWidget {
  final GameCtx ctx;
  const BarrelDrag({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final s = ctx.s;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final moved = s.flag('cellar_barrel_moved') >= 1;
        final progress = s.flag('cellar_barrel_px') / 100;
        return LayoutBuilder(builder: (context, box) {
          return GestureDetector(
            key: const Key('barrel_drag'),
            behavior: HitTestBehavior.opaque,
            onPanUpdate: moved
                ? null
                : (d) {
                    final before = s.flag('cellar_barrel_moved');
                    moveBarrel(s, d.delta.dx.abs());
                    if (before == 0 && s.flag('cellar_barrel_moved') >= 1) {
                      ctx.sfx('door_open');
                      ctx.say(strCellarBarrelDone);
                    }
                  },
            child: Transform.translate(
              offset: Offset(progress * box.maxWidth * 0.2, 0),
              child: gameImage('assets/scenes/cellar_barrel_close.png'),
            ),
          );
        });
      },
    );
  }
}

/// 선반 클로즈업: 폰 흔들기(가속도 벡터 크기 > 12) 또는 10연타로 열쇠를
/// 떨어뜨린다. 센서 미지원 기기는 try/catch로 무시하고 연타 폴백만 남는다.
class ShelfShake extends StatefulWidget {
  final GameCtx ctx;
  const ShelfShake({super.key, required this.ctx});

  @override
  State<ShelfShake> createState() => _ShelfShakeState();
}

class _ShelfShakeState extends State<ShelfShake> {
  StreamSubscription<UserAccelerometerEvent>? _sub;

  @override
  void initState() {
    super.initState();
    try {
      _sub = userAccelerometerEventStream().listen((e) {
        final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        if (mag > 12) _fire(() => dropShelfKey(widget.ctx.s));
      }, onError: (_) {});
    } catch (_) {
      // 센서 미지원 기기 — 무시하고 연타 폴백으로 진행 (스펙 §7 정신)
    }
  }

  /// key_dropped가 이번 호출로 처음 1이 되는 순간에만 sfx+대사 1회.
  void _fire(void Function() action) {
    final s = widget.ctx.s;
    final before = s.flag('cellar_key_dropped');
    action();
    if (before == 0 && s.flag('cellar_key_dropped') >= 1) {
      widget.ctx.sfx('unlock');
      widget.ctx.say(strCellarKeyDrop);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('shelf_tap'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _fire(() => tapShelf(widget.ctx.s)),
      child: gameImage('assets/scenes/cellar_shelf_close.png'),
    );
  }
}

// ── 방 정의 ──

Room buildCellar() {
  Cond flagSet(String k) => (s) => s.flag(k) >= 1;

  return Room(
    id: 'cellar',
    name: '지하실',
    onEnter: (c) => c.say(strCellarIntro),
    cleared: flagSet('cellar_done'),
    walls: [
      // 벽면 A: 선반·상자들 벽
      Scene(id: 'cellar_a', image: 'assets/scenes/cellar_a.png', overlays: [
        // 선언 순서 중요 — 어둠막 먼저, 야광은 그 위에 그려져야 함.
        SceneOverlay(
            image: 'assets/scenes/cellar_a_dark.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: (s) => s.flag('cellar_light') == 0),
        SceneOverlay(
            image: 'assets/scenes/cellar_a_glow.png',
            area: const Rect.fromLTWH(0.08, 0.58, 0.24, 0.24),
            when: (s) => s.flag('cellar_light') == 0),
        SceneOverlay(
            image: 'assets/scenes/cellar_a_key_floor.png',
            area: const Rect.fromLTWH(0.36, 0.50, 0.12, 0.10),
            when: (s) =>
                s.flag('cellar_key_dropped') == 1 &&
                s.flag('cellar_got_key') == 0),
      ], hotspots: [
        Hotspot(
            id: 'glow_box',
            area: const Rect.fromLTWH(0.10, 0.62, 0.18, 0.16),
            when: (s) => s.flag('cellar_got_fuse') == 0,
            onTap: (c) {
              final s = c.s;
              if (s.flag('cellar_light') == 0) {
                s.setFlag('cellar_got_fuse', 1);
                c.give('fuse');
                c.give('note4');
                c.say(strCellarGlowBox);
              } else {
                c.say(strCellarBoxPlain);
              }
            }),
        Hotspot(
            id: 'box2',
            area: const Rect.fromLTWH(0.34, 0.64, 0.16, 0.14),
            onTap: (c) => c.say(strCellarBoxEmpty)),
        Hotspot(
            id: 'box3',
            area: const Rect.fromLTWH(0.56, 0.64, 0.16, 0.14),
            onTap: (c) => c.say(strCellarBoxEmpty)),
        Hotspot(
            id: 'shelf',
            area: const Rect.fromLTWH(0.34, 0.20, 0.40, 0.26),
            onTap: (c) => c.openCloseup('shelf')),
        Hotspot(
            id: 'deoldeol',
            area: const Rect.fromLTWH(0.78, 0.44, 0.16, 0.26),
            onTap: (c) {
              c.sfx('ghost_giggle');
              c.say(c.s.flag('cellar_light') >= 1
                  ? strCellarDeoldeolLight
                  : strCellarDeoldeolDark);
            }),
        Hotspot(
            id: 'key_floor',
            area: const Rect.fromLTWH(0.34, 0.48, 0.16, 0.14),
            when: (s) =>
                s.flag('cellar_key_dropped') == 1 &&
                s.flag('cellar_got_key') == 0,
            onTap: (c) {
              c.give('key_cellar');
              c.s.setFlag('cellar_got_key', 1);
              c.say(strCellarKeyTaken);
            }),
      ]),
      // 벽면 B: 와인통·배전반·쪽문 벽
      Scene(id: 'cellar_b', image: 'assets/scenes/cellar_b.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/cellar_b_dark.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: (s) => s.flag('cellar_light') == 0),
        SceneOverlay(
            image: 'assets/scenes/cellar_b_glow_arrow.png',
            area: const Rect.fromLTWH(0.44, 0.36, 0.20, 0.16),
            when: (s) => s.flag('cellar_light') == 0),
        SceneOverlay(
            image: 'assets/scenes/cellar_b_barrel_moved.png',
            area: const Rect.fromLTWH(0.50, 0.36, 0.34, 0.44),
            when: flagSet('cellar_barrel_moved')),
      ], hotspots: [
        Hotspot(
            id: 'fusebox',
            area: const Rect.fromLTWH(0.08, 0.28, 0.16, 0.18),
            onTap: (c) {
              if (c.using('fuse')) {
                c.consume('fuse');
                c.s.setFlag('cellar_fuse_installed', 1);
                c.sfx('unlock');
                c.say(strCellarFuseIn);
              } else {
                c.say(strCellarFusebox);
              }
            }),
        Hotspot(
            id: 'light_switch',
            area: const Rect.fromLTWH(0.30, 0.30, 0.10, 0.12),
            onTap: (c) {
              final s = c.s;
              if (s.flag('cellar_fuse_installed') == 0) {
                c.say(strCellarSwitchDead);
              } else {
                final turningOn = s.flag('cellar_light') == 0;
                s.setFlag('cellar_light', turningOn ? 1 : 0);
                c.sfx('clock_tick');
                if (turningOn) c.say(strCellarLightOn);
              }
            }),
        Hotspot(
            id: 'barrel',
            area: const Rect.fromLTWH(0.50, 0.44, 0.30, 0.36),
            onTap: (c) {
              final s = c.s;
              if (s.flag('cellar_light') == 0) {
                c.say(strCellarTooDark);
              } else if (s.flag('cellar_barrel_moved') >= 1) {
                c.say(strCellarBarrelMoved);
              } else {
                c.openCloseup('barrel');
              }
            }),
        Hotspot(
            id: 'small_door',
            area: const Rect.fromLTWH(0.56, 0.30, 0.20, 0.30),
            when: flagSet('cellar_barrel_moved'),
            onTap: (c) {
              final s = c.s;
              if (s.flag('cellar_door_open') >= 1) {
                c.sfx('door_open');
                s.setFlag('cellar_done', 1);
              } else if (c.using('key_cellar')) {
                c.consume('key_cellar');
                c.sfx('unlock');
                s.setFlag('cellar_door_open', 1);
                c.say(strCellarDoorOpened);
              } else {
                c.sfx('locked');
                c.say(strCellarDoorLocked);
              }
            }),
      ]),
    ],
    closeups: {
      'barrel': Scene(id: 'barrel', custom: (_, c) => BarrelDrag(ctx: c)),
      'shelf': Scene(id: 'shelf', custom: (_, c) => ShelfShake(ctx: c)),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_cellar_light', title: '어둠 밝히기', steps: [
        '어둠 속에서만 보이는 것이 있어요. 불을 켜기 전에 잘 둘러보세요',
        '야광 표시가 빛나는 상자 안에 배전반에 쓸 것이',
        '정답: 야광 상자의 퓨즈를 배전반에 사용 → 스위치.',
      ], solved: (s) => s.flag('cellar_light') >= 1),
      PuzzleHint(puzzleId: 'p_cellar_door', title: '숨은 쪽문', steps: [
        '불을 켜기 전 벽에 야광 화살표가 가리키던 것은?',
        '와인통을 열고(탭) 옆으로 밀어 보세요 — 손가락으로 계속 끄세요',
        '정답: 와인통 클로즈업에서 드래그로 끝까지 밀면 쪽문이 나와요.',
      ], solved: (s) => s.flag('cellar_barrel_moved') >= 1),
      PuzzleHint(puzzleId: 'p_cellar_key', title: '닿지 않는 열쇠', steps: [
        '선반 위 열쇠는 손이 닿지 않아요. 덜덜의 말을 다시 들어보세요 — '
            '"온 집이 흔들리지 않는 한!"',
        '폰을 흔들어 보세요! (또는 선반을 여러 번 두드려도 돼요)',
        '정답: 선반 클로즈업에서 기기를 흔들거나 10번 연타 → 열쇠가 바닥에 떨어져요.',
      ], solved: (s) => s.flag('cellar_got_key') >= 1),
    ],
  );
}
