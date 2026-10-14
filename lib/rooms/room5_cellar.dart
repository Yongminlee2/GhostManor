import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../core/game_state.dart';
import '../core/models.dart';
import '../core/scene_view.dart';
import '../core/strings.dart';
import '../core/switch_panel.dart';

// ── 퍼즐 로직 (위젯과 분리 — 정답 시퀀스 테스트가 직접 호출, 스펙 §8) ──
// 리마스터: 전 플래그 cellar_r_ 접두어 (구세이브의 cellar_* 와 충돌 차단).
//
// 스레드 구조(브리프): T1 전력 복구(어둠 속 상자A → 퓨즈1 → 배전반 → 어둠 속
// 배전반 옆 낙서로 스위치 순서 학습 → [T2가 준 퓨즈2 필요] → SwitchPanel
// △○□ → 전력 복구) ‖ T2 와인 연도 코드(점등 후 병 5개 라벨 → 어둠 속 랙 옆
// 낙서로 촛불 순서 학습 → 병 5→1→3 탭 → 상자B: 퓨즈2+♪구름) → 교차: T2의
// 퓨즈2가 T1 후반(스위치 조작)의 전제 조건, T1 전반(퓨즈1→배전반 1개)이 만든
// 기본 점등이 T2(라벨 판독)의 전제 조건 — 서로 맞물려 어느 한쪽만으로는
// 끝까지 못 간다. 쪽문은 열쇠뿐 아니라 cellar_r_power(전력 복구 완료)도
// 요구해 SwitchPanel을 우회 불가능한 필수 관문으로 만든다(설계 판단 — 브리프가
// 명시하지 않은 빈칸, task-8-report.md에 기록).

/// 와인통 드래그 진행도 누적. 불이 켜진 상태에서만 진행된다(어두우면 no-op).
/// dx(픽셀 이동량)를 진행도 0~100 정수로 환산해 누적하고 100에서 클램프,
/// 100 도달 시 cellar_r_barrel_moved=1(벽의 SceneObject가 이 플래그로 실이동).
void moveBarrel(GameState s, double dx) {
  if (s.flag('cellar_r_light') == 0) return;
  final raw = s.flag('cellar_r_barrel_px') + (dx / 6).round();
  final next = raw.clamp(0, 100).toInt();
  s.setFlag('cellar_r_barrel_px', next);
  if (next >= 100) s.setFlag('cellar_r_barrel_moved', 1);
}

/// 선반 흔들기(센서) 또는 연타 폴백 공통 도착지: 불이 켜져 있고 아직
/// 떨어뜨리지 않았을 때만 열쇠를 떨어뜨린다.
void dropShelfKey(GameState s) {
  if (s.flag('cellar_r_light') == 0) return;
  if (s.flag('cellar_r_key_dropped') >= 1) return;
  s.setFlag('cellar_r_key_dropped', 1);
}

/// 선반 연타 폴백(접근성 — 흔들기가 어려운 사용자용): 10회 누적 시 낙하.
void tapShelf(GameState s) {
  s.addFlag('cellar_r_shelf_taps');
  if (s.flag('cellar_r_shelf_taps') >= 10) dropShelfKey(s);
}

/// 와인병 순서 정답(어둠 속 랙 옆 낙서 cellar_c_glow3.png가 보여주는 촛불
/// 개수 그림 순서 그대로): 다섯 → 하나 → 셋.
const wineOrder = [5, 1, 3];

/// 병 탭(count=그 병 라벨에 그려진 촛불 개수). 정답 순서(5→1→3)대로면
/// cellar_r_wine_seq +1, 3 도달 시 cellar_r_wine_open=1(상자B 잠금 해제).
/// 순서가 틀리면 0으로 리셋. 이미 열렸으면 no-op(room3 tapBook의 nook_open
/// 가드와 동일한 이유) — 라벨상 촛불 세 개인 병이 둘(1·5번)이라도 값만
/// 비교하므로 어느 쪽을 탭해도 동일하게 통과한다(라벨 두 병이 같은 개수를
/// 그리고 있는 납품 아트 특성을 흡수 — task-8-report.md 기록).
void tapWine(GameState s, int count) {
  if (s.flag('cellar_r_wine_open') >= 1) return;
  final seq = s.flag('cellar_r_wine_seq');
  if (wineOrder[seq] == count) {
    final next = seq + 1;
    s.setFlag('cellar_r_wine_seq', next);
    if (next == wineOrder.length) s.setFlag('cellar_r_wine_open', 1);
  } else {
    s.setFlag('cellar_r_wine_seq', 0);
  }
}

// ── 커스텀 기믹 위젯 (escape hatch) ──

/// 와인통 클로즈업: 드래그로 밀어 진행도를 쌓는다(양방향 허용). 100% 도달 시
/// 쪽문이 드러나는 순간 1회 sfx+대사(벽에서는 SceneObject가 실이동으로 이어
/// 받는다 — 스펙 §4-1). 완료 후엔 드래그 무시.
class BarrelDrag extends StatelessWidget {
  final GameCtx ctx;
  const BarrelDrag({super.key, required this.ctx});

  @override
  Widget build(BuildContext context) {
    final s = ctx.s;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final moved = s.flag('cellar_r_barrel_moved') >= 1;
        final progress = s.flag('cellar_r_barrel_px') / 100;
        return LayoutBuilder(builder: (context, box) {
          return GestureDetector(
            key: const Key('barrel_drag'),
            behavior: HitTestBehavior.opaque,
            onPanUpdate: moved
                ? null
                : (d) {
                    final before = s.flag('cellar_r_barrel_moved');
                    moveBarrel(s, d.delta.dx.abs());
                    if (before == 0 && s.flag('cellar_r_barrel_moved') >= 1) {
                      ctx.sfx('wood_slide');
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
    final before = s.flag('cellar_r_key_dropped');
    action();
    if (before == 0 && s.flag('cellar_r_key_dropped') >= 1) {
      widget.ctx.sfx('metal_drop');
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
  Cond flagZero(String k) => (s) => s.flag(k) == 0;
  bool dark(GameState s) => s.flag('cellar_r_light') == 0; // 오버레이 when에 반복 사용

  // 와인 랙 병 5개(왼쪽부터) — 실제 납품 아트(cellar_c.png) 라벨의 촛불 개수를
  // 그대로 옮긴 값. 정답을 그대로 보여주지 않으려 뒤섞여 있고(아트 의뢰서
  // 지시), 그중 1번·5번 라벨이 우연히 둘 다 "셋"이다 — tapWine은 인덱스가
  // 아니라 개수 값만 비교한다(리터치로 라벨이 4·1·5·2·3 유일해졌지만
  // 값 판정은 그대로 둔다 — 아트가 또 바뀌어도 코드는 흔들리지 않게).
  const wineCounts = [4, 1, 5, 2, 3];
  const wineLabels = [
    strCellarRWineBottle1,
    strCellarRWineBottle2,
    strCellarRWineBottle3,
    strCellarRWineBottle4,
    strCellarRWineBottle5,
  ];
  const barrelHomeArea = Rect.fromLTWH(0.2822, 0.3379, 0.5244, 0.4349);
  const barrelMovedArea = Rect.fromLTWH(0.86, 0.3379, 0.5244, 0.4349);
  const wine1Area = Rect.fromLTWH(0.25, 0.32, 0.09, 0.21);
  const wine2Area = Rect.fromLTWH(0.35, 0.32, 0.09, 0.21);
  const wine3Area = Rect.fromLTWH(0.45, 0.32, 0.09, 0.21);
  const wine4Area = Rect.fromLTWH(0.55, 0.32, 0.09, 0.21);
  const wine5Area = Rect.fromLTWH(0.65, 0.32, 0.09, 0.21);

  void tapWineBottle(GameCtx c, int i) {
    final s = c.s;
    // 라벨은 그림 단서 — 어두우면 판독 자체가 불가(이 방의 어둠 왕복 정체성).
    // 스위치(촉감 조작)와 달리 여기는 점등 필수.
    if (s.flag('cellar_r_light') == 0) {
      c.say(strCellarRWineDark);
      return;
    }
    final label = wineLabels[i];
    if (s.flag('cellar_r_wine_open') >= 1) {
      c.say(label); // 이미 풀렸어도 라벨 구경은 계속 가능
      return;
    }
    final before = s.flag('cellar_r_wine_seq');
    tapWine(s, wineCounts[i]);
    c.sfx('glass_clink');
    if (s.flag('cellar_r_wine_open') >= 1) {
      c.sfx('unlock');
      c.say(strCellarRWineUnlocked);
    } else if (s.flag('cellar_r_wine_seq') == 0 && before > 0) {
      c.say(strCellarRWineWrong);
    } else {
      c.say(label);
    }
  }

  // 배전반: using('fuse'|'fuse2')로 소켓을 하나씩 채우고, 2개 다 채워지면
  // 탭할 때마다 SwitchPanel 클로즈업을 연다(어둠 여부 무관 — 촉감으로 조작
  // 가능한 기계식 스위치라는 설정, 손잡이를 "봐야" 미는 와인통과는 다름).
  void tapFusebox(GameCtx c) {
    final s = c.s;
    final count = s.flag('cellar_r_fuse_count');
    if (count >= 2) {
      c.openCloseup('switches');
      return;
    }
    final usingFuse = c.using('fuse') || c.using('fuse2');
    if (!usingFuse) {
      c.say(count == 0 ? strCellarRFusebox : strCellarRFuseboxOneMore);
      return;
    }
    c.consume(c.using('fuse') ? 'fuse' : 'fuse2');
    s.addFlag('cellar_r_fuse_count');
    c.sfx('metal_click');
    c.say(s.flag('cellar_r_fuse_count') == 1 ? strCellarRFuse1In : strCellarRFuse2In);
  }

  void tapLightSwitch(GameCtx c) {
    final s = c.s;
    if (s.flag('cellar_r_fuse_count') == 0) {
      c.say(strCellarSwitchDead);
    } else {
      s.setFlag('cellar_r_light', s.flag('cellar_r_light') == 0 ? 1 : 0);
      c.sfx('switch_click');
    }
  }

  return Room(
    id: 'cellar',
    name: '지하실',
    onEnter: (c) => c.say(strCellarIntro),
    cleared: flagSet('cellar_r_done'),
    walls: [
      // 벽면 A: 선반·상자들 벽 (기존 아트+로직 재사용, 플래그만 cellar_r_)
      Scene(id: 'cellar_a', image: 'assets/scenes/cellar_a.png', overlays: [
        // 선언 순서 중요 — 어둠막 먼저, 야광은 그 위에 그려져야 함.
        SceneOverlay(
            image: 'assets/scenes/cellar_a_dark.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: dark),
        SceneOverlay(
            image: 'assets/scenes/cellar_a_glow.png',
            area: const Rect.fromLTWH(0.11, 0.50, 0.24, 0.24),
            when: dark),
        SceneOverlay(
            image: 'assets/scenes/cellar_a_key_floor.png',
            area: const Rect.fromLTWH(0.4004, 0.8066, 0.1201, 0.0456),
            when: (s) =>
                s.flag('cellar_r_key_dropped') == 1 &&
                s.flag('cellar_r_got_key') == 0),
      ], hotspots: [
        Hotspot(
            id: 'glow_box',
            area: const Rect.fromLTWH(0.10, 0.62, 0.18, 0.16),
            when: (s) => s.flag('cellar_r_got_fuse') == 0,
            onTap: (c) {
              final s = c.s;
              if (s.flag('cellar_r_light') == 0) {
                s.setFlag('cellar_r_got_fuse', 1);
                c.sfx('wood_creak_open');
                c.give('fuse');
                c.say(strCellarRGlowBox);
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
              c.say(c.s.flag('cellar_r_light') >= 1
                  ? strCellarDeoldeolLight
                  : strCellarDeoldeolDark);
            }),
        Hotspot(
            id: 'key_floor',
            area: const Rect.fromLTWH(0.36, 0.76, 0.20, 0.14),
            when: (s) =>
                s.flag('cellar_r_key_dropped') == 1 &&
                s.flag('cellar_r_got_key') == 0,
            onTap: (c) {
              c.sfx('metal_key');
              c.give('key_cellar');
              c.s.setFlag('cellar_r_got_key', 1);
              c.say(strCellarKeyTaken);
            }),
      ]),
      // 벽면 B: 배전반·와인통(SceneObject)·쪽문 벽. 배경판은 통을 제거하고
      // 쪽문을 온전히 노출한 cellar_b_plate.png(구 cellar_b.png/
      // cellar_b_barrel_moved.png 대체 — art/remaster-assets.md A그룹).
      Scene(
          id: 'cellar_b',
          image: 'assets/scenes/cellar_b_plate.png',
          objects: [
            SceneObject(
                image: 'assets/scenes/cellar_barrel_sprite.png',
                // 아이폰판: 통을 cellar_b.png 에서 그대로 오려 냈다(remaster.py barrel) —
                // 닫힘 자리는 그 오린 자리, 밀면 오른쪽 벽으로 비켜 스위치는 가리지 않는다.
                area: (s) => s.flag('cellar_r_barrel_moved') >= 1
                    ? barrelMovedArea
                    : barrelHomeArea),
          ],
          overlays: [
            // 배전반 소켓 상태는 어둠막보다 먼저 선언 — 불이 꺼지면 다른
            // 정상 디테일처럼 어둠에 덮인다(글로우류만 어둠 위에 그려짐).
            SceneOverlay(
                image: 'assets/scenes/cellar_b_fuse1.png',
                area: const Rect.fromLTWH(0.127, 0.2995, 0.1953, 0.1432),
                when: (s) => s.flag('cellar_r_fuse_count') == 1),
            SceneOverlay(
                image: 'assets/scenes/cellar_b_fuse2.png',
                area: const Rect.fromLTWH(0.127, 0.2995, 0.1953, 0.1432),
                when: (s) => s.flag('cellar_r_fuse_count') == 2),
            SceneOverlay(
                image: 'assets/scenes/cellar_b_dark.png',
                area: const Rect.fromLTWH(0, 0, 1, 1),
                when: dark),
            SceneOverlay(
                image: 'assets/scenes/cellar_b_glow2.png',
                area: const Rect.fromLTWH(0.26, 0.18, 0.16, 0.24),
                when: dark),
          ],
          hotspots: [
            Hotspot(id: 'fusebox', area: const Rect.fromLTWH(0.08, 0.28, 0.16, 0.18), onTap: tapFusebox),
            Hotspot(
                id: 'light_switch',
                area: const Rect.fromLTWH(0.80, 0.33, 0.16, 0.14),
                onTap: tapLightSwitch),
            Hotspot(
                id: 'barrel',
                area: const Rect.fromLTWH(0.30, 0.40, 0.50, 0.40),
                when: flagZero('cellar_r_barrel_moved'),
                onTap: (c) {
                  if (c.s.flag('cellar_r_light') == 0) {
                    c.say(strCellarTooDark);
                  } else {
                    c.openCloseup('barrel');
                  }
                }),
            Hotspot(
                id: 'small_door',
                area: const Rect.fromLTWH(0.37, 0.29, 0.39, 0.47),
                when: flagSet('cellar_r_barrel_moved'),
                onTap: (c) {
                  final s = c.s;
                  if (s.flag('cellar_r_door_open') >= 1) {
                    if (s.flag('cellar_r_power') >= 1) {
                      c.sfx('door_open');
                      s.setFlag('cellar_r_done', 1);
                    } else {
                      c.say(strCellarRExitNeedsPower);
                    }
                  } else if (c.using('key_cellar')) {
                    c.consume('key_cellar');
                    c.sfx('metal_key');
                    s.setFlag('cellar_r_door_open', 1);
                    c.say(strCellarDoorOpened);
                  } else {
                    c.sfx('locked');
                    c.say(strCellarDoorLocked);
                  }
                }),
          ]),
      // 벽면 C: 와인 랙 벽 (신규) — 병 5개(T2 핵심), 랙 하단 상자B, 야광
      // 낙서3(랙 옆, 어둠 전용), 소품 리액션 3개.
      Scene(id: 'cellar_c', image: 'assets/scenes/cellar_c.png', overlays: [
        SceneOverlay(
            image: 'assets/scenes/cellar_c_boxb_open.png',
            area: const Rect.fromLTWH(0.332, 0.5404, 0.3516, 0.1628),
            when: flagSet('cellar_r_wine_open')),
        SceneOverlay(
            image: 'assets/scenes/cellar_c_dark.png',
            area: const Rect.fromLTWH(0, 0, 1, 1),
            when: dark),
        SceneOverlay(
            image: 'assets/scenes/cellar_c_glow3.png',
            area: const Rect.fromLTWH(0.22, 0.03, 0.56, 0.19),
            when: dark),
      ], hotspots: [
        Hotspot(id: 'wine1', area: wine1Area, onTap: (c) => tapWineBottle(c, 0)),
        Hotspot(id: 'wine2', area: wine2Area, onTap: (c) => tapWineBottle(c, 1)),
        Hotspot(id: 'wine3', area: wine3Area, onTap: (c) => tapWineBottle(c, 2)),
        Hotspot(id: 'wine4', area: wine4Area, onTap: (c) => tapWineBottle(c, 3)),
        Hotspot(id: 'wine5', area: wine5Area, onTap: (c) => tapWineBottle(c, 4)),
        Hotspot(
            id: 'boxb',
            area: const Rect.fromLTWH(0.35, 0.58, 0.28, 0.13),
            onTap: (c) {
              final s = c.s;
              if (s.flag('cellar_r_wine_open') == 0) {
                c.say(strCellarRBoxbLocked);
              } else if (s.flag('cellar_r_boxb_looted') == 0) {
                s.setFlag('cellar_r_boxb_looted', 1);
                c.sfx('wood_creak_open');
                c.give('fuse2');
                c.give('note4');
                c.say(strCellarRBoxbOpen);
              } else {
                c.say(strCellarRBoxbEmpty);
              }
            }),
        Hotspot(
            id: 'sconce',
            area: const Rect.fromLTWH(0.02, 0.28, 0.15, 0.18),
            onTap: (c) => c.say(strCellarRSconce)),
        Hotspot(
            id: 'crate',
            area: const Rect.fromLTWH(0.0, 0.75, 0.20, 0.20),
            onTap: (c) => c.say(strCellarRCrate)),
        Hotspot(
            id: 'deoldeol_c',
            area: const Rect.fromLTWH(0.78, 0.45, 0.20, 0.30),
            onTap: (c) {
              c.sfx('ghost_giggle');
              c.say(strCellarRDeoldeolC);
            }),
      ]),
    ],
    closeups: {
      'barrel': Scene(id: 'barrel', custom: (_, c) => BarrelDrag(ctx: c)),
      'shelf': Scene(id: 'shelf', custom: (_, c) => ShelfShake(ctx: c)),
      'switches': Scene(id: 'switches', custom: (_, c) => SwitchPanel(ctx: c)),
    },
    hints: [
      PuzzleHint(puzzleId: 'p_cellar_r_power', title: '전력 복구', steps: [
        '퓨즈가 두 개 필요해요 — 하나는 빛나는 곳, 하나는 잠긴 상자',
        '배전반 옆 야광 기호가 스위치 순서',
        '정답: 퓨즈 2개 장착 후 △○□ 순서',
      ], solved: (s) => s.flag('cellar_r_power') >= 1),
      PuzzleHint(puzzleId: 'p_cellar_r_wine', title: '와인 라벨의 순서', steps: [
        '어둠 속 낙서와 병 라벨을 오가며 보세요',
        '촛불 개수 그림 = 병 순서',
        '정답: 5→1→3',
      ], solved: (s) => s.flag('cellar_r_wine_open') >= 1),
      PuzzleHint(puzzleId: 'p_cellar_r_exit', title: '통 뒤의 쪽문', steps: [
        '통 뒤가 수상해요 — 밀 수 있을 것 같은데',
        '통을 민 뒤 쪽문 — 쪽문 걸쇠는 전기가 들어와야 풀려요',
        '정답: 전력 복구 후, 셰이크(또는 선반 연타)로 열쇠 낙하 → 쪽문',
      ], solved: (s) => s.flag('cellar_r_done') >= 1),
    ],
  );
}
