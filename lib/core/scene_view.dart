import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'models.dart';
import '../rooms/items.dart';

/// 에셋 없으면 파일명 라벨 색 블록 — 아트 도착 전에도 게임 동작 (스펙 §7).
Widget gameImage(String path) => Image.asset(
      path,
      fit: BoxFit.fill,
      errorBuilder: (_, _, _) => Container(
        color: const Color(0xFF3A2E4F),
        alignment: Alignment.center,
        child: Text(path.split('/').last,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ),
    );

/// 벽면/클로즈업 렌더 + 비율 좌표 히트테스트. 부모가 2:3 박스를 보장한다.
/// 씬 숨쉬기·탭 리플·유령 둥실 같은 생동감 연출은 non-custom 씬에서만,
/// 4초 주기 Timer 하나로 구동한다(반복 AnimationController 없음 —
/// pumpAndSettle 안전). 벽 전환은 슬라이드, 클로즈업 여닫기는 줌으로 넘어가고
/// (둘 다 finite AnimatedSwitcher), 오버레이는 등장 모션 타입별로, 오브젝트는
/// area(s) 변화에 AnimatedPositioned로 실이동, 지급받은 아이템은 탭 지점에서
/// 인벤토리 쪽으로 짧게 날아간다 — 전부 유한 애니메이션.
class SceneView extends StatefulWidget {
  final Room room;
  final GameCtx ctx;
  const SceneView({super.key, required this.room, required this.ctx});

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView> {
  Timer? _timer;
  bool _breatheIn = false;
  Offset? _lastTapPos;
  int _rippleSeq = 0;
  int _navDir = 1; // 마지막 화살표 방향(+1 오른쪽/-1 왼쪽) — 슬라이드 방향 결정
  int _seenFlySeq = 0;
  int? _flyingSeq;
  Offset? _flyStart;

  @override
  void initState() {
    super.initState();
    _seenFlySeq = widget.ctx.s.flySeq;
    _timer = Timer.periodic(const Duration(seconds: 4), _onTick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTick(Timer _) => setState(() => _breatheIn = !_breatheIn);

  /// 오버레이 등장 모션(스펙 §3): fade/slideDown/grow 공통 350→450ms 트윈.
  Widget _overlayContent(SceneOverlay o, Rect rectPx) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          final content = switch (o.motion) {
            OverlayMotion.fade => child!,
            OverlayMotion.slideDown => Transform.translate(
                offset: Offset(0, (1 - t) * -0.15 * rectPx.height), child: child),
            OverlayMotion.grow => Transform.scale(
                scale: 0.85 + 0.15 * t, alignment: Alignment.center, child: child),
          };
          return Opacity(opacity: t, child: content);
        },
        child: gameImage(o.image),
      );

  /// 유령 둥실(스펙 §4): 4초 타이머의 _breatheIn을 그대로 재사용해 ±bobPx로
  /// 흔든다 — 별도 컨트롤러 없이 기존 settle-safe 패턴에 올라탄다.
  Widget _idleContent(IdleSprite idle, Rect rectPx) => IgnorePointer(
        child: AnimatedSlide(
          offset: Offset(
              0, rectPx.height == 0 ? 0 : (_breatheIn ? idle.bobPx : -idle.bobPx) / rectPx.height),
          duration: const Duration(milliseconds: 3400),
          curve: Curves.easeInOut,
          child: gameImage(idle.image),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final ctx = widget.ctx;
    final s = ctx.s;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        final scene = s.closeupId != null
            ? room.closeups[s.closeupId]!
            : room.walls[s.sceneIndex % room.walls.length];

        // 아이템 지급 감지: flySeq가 새로 바뀌었고 직전 탭 위치를 알 때만 비행
        // 시작(스펙 §5). build 도중 필드만 갱신 — 이번 프레임에 바로 반영되고
        // setState는 필요 없다(이미 notifyListeners가 리빌드를 유발한 상태).
        if (s.flySeq != _seenFlySeq) {
          _seenFlySeq = s.flySeq;
          if (_lastTapPos != null) {
            _flyingSeq = s.flySeq;
            _flyStart = _lastTapPos;
          }
        }

        return LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          Rect px(Rect r) =>
              Rect.fromLTWH(r.left * w, r.top * h, r.width * w, r.height * h);

          Widget overlayItem(SceneOverlay o) {
            final r = px(o.area);
            return Positioned.fromRect(rect: r, child: _overlayContent(o, r));
          }

          Widget idleItem(IdleSprite idle) {
            final r = px(idle.area);
            return Positioned.fromRect(rect: r, child: _idleContent(idle, r));
          }

          Widget objectItem(SceneObject o) => AnimatedPositioned.fromRect(
                rect: px(o.area(s)),
                duration: o.duration,
                curve: Curves.easeInOut,
                child: IgnorePointer(child: gameImage(o.image)),
              );

          Widget wallBody() {
            if (scene.custom != null) return scene.custom!(context, ctx);
            return Stack(children: [
              Positioned.fill(
                child: AnimatedScale(
                  scale: _breatheIn ? 1.012 : 1.0,
                  alignment: Alignment.center,
                  // 타이머 주기(4초)와 정확히 같으면 한 사이클이 끝나는 순간
                  // 다음 틱이 즉시 재시작시켜 유휴 프레임이 사라진다 — ..repeat()와
                  // 동급이라 pumpAndSettle이 절대 안 끝난다. 주기보다 짧게 잡아
                  // 매 사이클 사이에 유휴 구간을 보장한다.
                  duration: const Duration(seconds: 3),
                  curve: Curves.easeInOut,
                  child: gameImage(scene.image!),
                ),
              ),
              for (final o in scene.objects)
                if (o.visible?.call(s) ?? true) objectItem(o),
              for (final o in scene.overlays)
                if (o.when(s)) overlayItem(o),
              for (final idle in scene.idles)
                if (idle.when?.call(s) ?? true) idleItem(idle),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) {
                    setState(() {
                      _lastTapPos = d.localPosition;
                      _rippleSeq++;
                    });
                    final p = Offset(
                        d.localPosition.dx / w, d.localPosition.dy / h);
                    for (final hs in scene.hotspots.reversed) {
                      if ((hs.when?.call(s) ?? true) && hs.area.contains(p)) {
                        hs.onTap(ctx);
                        return;
                      }
                    }
                  },
                ),
              ),
            ]);
          }

          return Stack(children: [
            // 클로즈업 여닫기 = 줌(0.88→1 + 페이드, 260ms). 그 안에 벽 전환 =
            // 슬라이드(±0.25폭 + 페이드, 300ms) 중첩 — 스펙 §1·§2.
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: Tween<double>(begin: 0.88, end: 1.0)
                      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: SizedBox(
                  key: ValueKey(s.closeupId ?? 'walls'),
                  width: w,
                  height: h,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => SlideTransition(
                      position: Tween<Offset>(begin: Offset(_navDir * 0.25, 0), end: Offset.zero)
                          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: SizedBox(
                      key: ValueKey('wall${s.sceneIndex}'),
                      width: w,
                      height: h,
                      child: wallBody(),
                    ),
                  ),
                ),
              ),
            ),
            if (_lastTapPos != null)
              TweenAnimationBuilder<double>(
                key: ValueKey(_rippleSeq),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 350),
                builder: (context, t, child) {
                  final size = 10 + 46 * t;
                  // Positioned는 Stack의 직계 자식 슬롯에서만 동작하므로
                  // IgnorePointer는 그 안(child)에 둔다 — 밖에 두면
                  // "Incorrect use of ParentDataWidget" 예외가 난다.
                  return Positioned(
                    left: _lastTapPos!.dx - size / 2,
                    top: _lastTapPos!.dy - size / 2,
                    width: size,
                    height: size,
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                Colors.white.withValues(alpha: (1 - t) * 0.5),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            if (_flyingSeq != null && _flyStart != null)
              TweenAnimationBuilder<double>(
                // 문자열 접두어로 네임스페이스 — 같은 탭에서 _rippleSeq와 숫자가
                // 우연히 겹치면(둘 다 탭 횟수 기반 카운터) Stack 형제 간 ValueKey
                // 중복으로 크래시한다. bare int 키는 절대 쓰지 않는다.
                key: ValueKey('fly_$_flyingSeq'),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeInCubic,
                onEnd: () => setState(() => _flyingSeq = null),
                builder: (context, t, child) {
                  final target = Offset(w / 2, h);
                  final pos = Offset.lerp(_flyStart!, target, t)!;
                  final lift = -40 * sin(t * pi);
                  final scale = 1.0 - 0.5 * t;
                  final opacity = t < 0.8 ? 1.0 : (1 - (t - 0.8) / 0.2);
                  return Positioned(
                    left: pos.dx - 22,
                    top: pos.dy + lift - 22,
                    width: 44,
                    height: 44,
                    child: IgnorePointer(
                      child: Opacity(
                        // t는 0~1 보장이라도 여기 opacity는 나눗셈으로 다시 계산한
                        // 값이라 부동소수점 오차로 살짝 범위를 벗어날 수 있다 —
                        // Opacity 위젯은 assert(0<=opacity<=1)라 clamp 필수.
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Transform.scale(scale: scale, child: child),
                      ),
                    ),
                  );
                },
                child: _flyIcon(s.flyItem),
              ),
            if (s.closeupId == null && room.walls.length > 1) ...[
              if (s.sceneIndex > 0)
                _arrow(
                    left: true,
                    onTap: () {
                      _navDir = -1;
                      s.goScene(s.sceneIndex - 1);
                    }),
              if (s.sceneIndex < room.walls.length - 1)
                _arrow(
                    left: false,
                    onTap: () {
                      _navDir = 1;
                      s.goScene(s.sceneIndex + 1);
                    }),
            ],
            if (s.closeupId != null)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  key: const Key('closeup_close'),
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: s.closeCloseup,
                ),
              ),
            if (s.dialog != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 250),
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(0, (1 - t) * 12),
                      child: child,
                    ),
                  ),
                  child: GestureDetector(
                    onTap: () => s.say(null),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xE6241B36),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF7C5CC4)),
                      ),
                      child: Text(s.dialog!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15)),
                    ),
                  ),
                ),
              ),
          ]);
        });
      },
    );
  }

  Widget _flyIcon(String? itemId) {
    final item = itemsById[itemId];
    if (item == null) return const SizedBox(width: 44, height: 44);
    return Image.asset(
      item.icon,
      width: 44,
      height: 44,
      errorBuilder: (_, _, _) => SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Text(item.name,
              style: const TextStyle(color: Colors.white70, fontSize: 9),
              textAlign: TextAlign.center),
        ),
      ),
    );
  }

  Widget _arrow({required bool left, required VoidCallback onTap}) => Positioned(
        left: left ? 0 : null,
        right: left ? null : 0,
        top: 0,
        bottom: 0,
        child: Center(
          child: IconButton(
            key: Key(left ? 'arrow_left' : 'arrow_right'),
            icon: Icon(left ? Icons.chevron_left : Icons.chevron_right,
                color: Colors.white70, size: 40),
            onPressed: onTap,
          ),
        ),
      );
}
