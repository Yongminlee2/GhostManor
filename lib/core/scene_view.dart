import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'models.dart';

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
/// 씬 숨쉬기·핫스팟 글린트·탭 리플 같은 생동감 연출은 non-custom 씬에서만,
/// 4초 주기 Timer 하나로 구동한다(반복 AnimationController 없음 — pumpAndSettle 안전).
class SceneView extends StatefulWidget {
  final Room room;
  final GameCtx ctx;
  const SceneView({super.key, required this.room, required this.ctx});

  @override
  State<SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<SceneView> {
  final _rng = Random();
  Timer? _timer;
  bool _breatheIn = false;
  Rect? _glintRect;
  int _glintSeq = 0;
  Offset? _lastTapPos;
  int _rippleSeq = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), _onTick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTick(Timer _) {
    final s = widget.ctx.s;
    setState(() {
      _breatheIn = !_breatheIn;
      if (s.closeupId == null) {
        final scene = widget.room.walls[s.sceneIndex % widget.room.walls.length];
        if (scene.custom == null) {
          final active =
              scene.hotspots.where((h) => h.when?.call(s) ?? true).toList();
          if (active.isNotEmpty) {
            _glintSeq++;
            _glintRect = active[_rng.nextInt(active.length)].area;
          }
        }
      }
    });
  }

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
        return LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          Rect px(Rect r) =>
              Rect.fromLTWH(r.left * w, r.top * h, r.width * w, r.height * h);
          return Stack(children: [
            if (scene.custom != null)
              Positioned.fill(child: scene.custom!(context, ctx))
            else ...[
              Positioned.fill(
                child: AnimatedScale(
                  scale: _breatheIn ? 1.012 : 1.0,
                  alignment: Alignment.center,
                  // 스펙은 4초를 명시하지만 타이머 주기(4초)와 정확히 같으면
                  // 한 사이클이 끝나는 순간 다음 틱이 즉시 재시작시켜 유휴 프레임이
                  // 사라진다 — ..repeat()와 동급이라 pumpAndSettle이 절대 안 끝난다
                  // (app_shell_test.dart가 매 화면전환마다 씀). 주기보다 짧게 잡아
                  // 매 사이클 사이에 유휴 구간을 보장한다.
                  duration: const Duration(seconds: 3),
                  curve: Curves.easeInOut,
                  child: gameImage(scene.image!),
                ),
              ),
              for (final o in scene.overlays)
                if (o.when(s))
                  Positioned.fromRect(
                    rect: px(o.area),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 350),
                      builder: (context, t, child) =>
                          Opacity(opacity: t, child: child),
                      child: gameImage(o.image),
                    ),
                  ),
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
              if (_glintRect != null && s.closeupId == null)
                Positioned.fromRect(
                  rect: px(_glintRect!),
                  child: IgnorePointer(
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey(_glintSeq),
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 900),
                        builder: (context, t, child) => Opacity(
                          opacity: sin(t * pi).clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: 0.6 + 0.5 * t,
                            child: const Icon(Icons.auto_awesome,
                                color: Colors.white70, size: 22),
                          ),
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
            ],
            if (s.closeupId == null && room.walls.length > 1) ...[
              if (s.sceneIndex > 0)
                _arrow(left: true, onTap: () => s.goScene(s.sceneIndex - 1)),
              if (s.sceneIndex < room.walls.length - 1)
                _arrow(left: false, onTap: () => s.goScene(s.sceneIndex + 1)),
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
